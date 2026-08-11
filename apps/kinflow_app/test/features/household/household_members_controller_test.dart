import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/application/household_members_controller.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';

import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  test('loads the active household roster before accepting actions', () async {
    final FakeHouseholdMemberRepository repository =
        FakeHouseholdMemberRepository();
    final HouseholdMembersController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load(householdIdFixture());

    expect(controller.state, isA<HouseholdMembersReady>());
    expect(repository.loadedHouseholds, <Object>[householdIdFixture()]);
  });

  test(
    'Owner role change obtains recent proof and reloads server state',
    () async {
      final FakeHouseholdMemberRepository repository =
          FakeHouseholdMemberRepository();
      final FakeRecentAuthenticationService recent =
          FakeRecentAuthenticationService();
      final FakeHouseholdCommandIdGenerator generator =
          FakeHouseholdCommandIdGenerator();
      final HouseholdMembersController controller = HouseholdMembersController(
        repository,
        generator,
        recent,
        FakeActiveHouseholdDepartureCommitter(),
      );
      addTearDown(controller.dispose);
      await controller.load(householdIdFixture());
      final HouseholdMember target = repository.defaultRoster.members.last;

      await controller.changeRole(target, HouseholdMemberRole.admin);

      expect(repository.changeRoleCommands, hasLength(1));
      final command = repository.changeRoleCommands.single;
      expect(command.memberId, target.id);
      expect(command.role, HouseholdMemberRole.admin);
      expect(command.expectedVersion, target.version);
      expect(
        command.recentAuthenticationProof.toString(),
        contains('redacted'),
      );
      expect(recent.authenticateCount, 1);
      expect(generator.generateCount, 1);
      expect(repository.loadedHouseholds, hasLength(2));
      expect(controller.state, isA<HouseholdMembersReady>());
    },
  );

  test(
    'cancelled recent authentication stops mutation with a stable failure',
    () async {
      final FakeHouseholdMemberRepository repository =
          FakeHouseholdMemberRepository();
      final HouseholdMembersController controller = HouseholdMembersController(
        repository,
        FakeHouseholdCommandIdGenerator(),
        FakeRecentAuthenticationService(
          results: const <RecentAuthenticationResult>[
            RecentAuthenticationFailed(
              RecentAuthenticationFailureKind.cancelled,
            ),
          ],
        ),
        FakeActiveHouseholdDepartureCommitter(),
      );
      addTearDown(controller.dispose);
      await controller.load(householdIdFixture());

      await controller.changeRole(
        repository.defaultRoster.members.last,
        HouseholdMemberRole.admin,
      );

      expect(repository.changeRoleCommands, isEmpty);
      final HouseholdMembersReady state =
          controller.state as HouseholdMembersReady;
      expect(
        state.failure?.kind,
        HouseholdMemberFailureKind.recentAuthenticationCancelled,
      );
    },
  );

  test('safe retry reuses command ID and success clears retry state', () async {
    final FakeHouseholdMemberRepository repository =
        FakeHouseholdMemberRepository(
          changeRoleResults: const <HouseholdMemberCommandResult>[
            HouseholdMemberCommandFailed(
              HouseholdMemberFailure(
                HouseholdMemberFailureKind.temporarilyUnavailable,
              ),
            ),
            HouseholdMemberCommandCompleted(),
          ],
        );
    final FakeHouseholdCommandIdGenerator generator =
        FakeHouseholdCommandIdGenerator();
    final HouseholdMembersController controller = HouseholdMembersController(
      repository,
      generator,
      FakeRecentAuthenticationService(),
      FakeActiveHouseholdDepartureCommitter(),
    );
    addTearDown(controller.dispose);
    await controller.load(householdIdFixture());
    final HouseholdMember target = repository.defaultRoster.members.last;

    await controller.changeRole(target, HouseholdMemberRole.admin);
    await controller.changeRole(target, HouseholdMemberRole.admin);

    expect(repository.changeRoleCommands, hasLength(2));
    expect(
      repository.changeRoleCommands.first.idempotencyKey,
      repository.changeRoleCommands.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    expect((controller.state as HouseholdMembersReady).failure, isNull);

    await controller.removeMember(target);
    expect(generator.generateCount, 2);
  });

  test('Admin cannot target a peer and Owner cannot leave', () async {
    final FakeHouseholdMemberRepository adminRepository =
        FakeHouseholdMemberRepository(
          roster: householdMemberRosterFixture(
            currentRole: HouseholdMemberRole.admin,
            otherRole: HouseholdMemberRole.admin,
          ),
        );
    final HouseholdMembersController adminController = _controller(
      adminRepository,
    );
    addTearDown(adminController.dispose);
    await adminController.load(householdIdFixture());
    await adminController.removeMember(
      adminRepository.defaultRoster.members.last,
    );
    expect(adminRepository.removeCommands, isEmpty);
    expect(
      (adminController.state as HouseholdMembersReady).failure?.kind,
      HouseholdMemberFailureKind.permissionDenied,
    );

    final FakeHouseholdMemberRepository ownerRepository =
        FakeHouseholdMemberRepository();
    final HouseholdMembersController ownerController = _controller(
      ownerRepository,
    );
    addTearDown(ownerController.dispose);
    await ownerController.load(householdIdFixture());
    await ownerController.leaveHousehold();
    expect(ownerRepository.leaveCommands, isEmpty);
    expect(
      (ownerController.state as HouseholdMembersReady).failure?.kind,
      HouseholdMemberFailureKind.ownerTransferRequired,
    );
  });

  test(
    'non-Owner leaves once and duplicate taps share the pending command',
    () async {
      final Completer<HouseholdMemberCommandResult> response =
          Completer<HouseholdMemberCommandResult>();
      final FakeHouseholdMemberRepository repository =
          FakeHouseholdMemberRepository(
            roster: householdMemberRosterFixture(
              currentRole: HouseholdMemberRole.member,
            ),
            leaveCallback: (_) => response.future,
          );
      final ActiveHousehold fallback = ActiveHousehold(
        householdId: householdIdFixture('22222222-2222-4222-8222-222222222223'),
        memberId: householdMemberIdFixture(
          '33333333-3333-4333-8333-333333333335',
        ),
      );
      final FakeActiveHouseholdDepartureCommitter committer =
          FakeActiveHouseholdDepartureCommitter();
      final HouseholdMembersController controller = _controller(
        repository,
        committer: committer,
      );
      addTearDown(controller.dispose);
      await controller.load(householdIdFixture());

      final Future<void> first = controller.leaveHousehold();
      final Future<void> duplicate = controller.leaveHousehold();
      expect(identical(first, duplicate), isTrue);
      expect(repository.leaveCommands, hasLength(1));

      response.complete(HouseholdLeaveCompleted(fallback));
      await first;
      expect(
        repository.leaveCommands.single.memberId,
        repository.defaultRoster.currentMember.id,
      );
      expect(committer.nextHouseholds, <ActiveHousehold?>[fallback]);
      expect(controller.state, isA<HouseholdMembersLeft>());
    },
  );

  test(
    'no fallback commits authenticated no-household before leaving',
    () async {
      final FakeHouseholdMemberRepository repository =
          FakeHouseholdMemberRepository(
            roster: householdMemberRosterFixture(
              currentRole: HouseholdMemberRole.member,
            ),
            leaveResults: const <HouseholdMemberCommandResult>[
              HouseholdLeaveCompleted(null),
            ],
          );
      final FakeActiveHouseholdDepartureCommitter committer =
          FakeActiveHouseholdDepartureCommitter();
      final HouseholdMembersController controller = _controller(
        repository,
        committer: committer,
      );
      addTearDown(controller.dispose);
      await controller.load(householdIdFixture());

      await controller.leaveHousehold();

      expect(committer.nextHouseholds, <ActiveHousehold?>[null]);
      expect(controller.state, isA<HouseholdMembersLeft>());
    },
  );

  test('local handoff failure never restores the departed roster', () async {
    final FakeHouseholdMemberRepository repository =
        FakeHouseholdMemberRepository(
          roster: householdMemberRosterFixture(
            currentRole: HouseholdMemberRole.member,
          ),
        );
    final HouseholdMembersController controller = _controller(
      repository,
      committer: FakeActiveHouseholdDepartureCommitter(result: false),
    );
    addTearDown(controller.dispose);
    await controller.load(householdIdFixture());

    await controller.leaveHousehold();

    expect(controller.state, isA<HouseholdMembersDepartureFailed>());
    expect(controller.state, isNot(isA<HouseholdMembersReady>()));
    expect(
      (controller.state as HouseholdMembersDepartureFailed).failure.kind,
      HouseholdMemberFailureKind.localStateUnavailable,
    );
  });

  test(
    'generic leave success is rejected as an invalid contract state',
    () async {
      final FakeHouseholdMemberRepository repository =
          FakeHouseholdMemberRepository(
            roster: householdMemberRosterFixture(
              currentRole: HouseholdMemberRole.member,
            ),
            leaveResults: const <HouseholdMemberCommandResult>[
              HouseholdMemberCommandCompleted(),
            ],
          );
      final FakeActiveHouseholdDepartureCommitter committer =
          FakeActiveHouseholdDepartureCommitter();
      final HouseholdMembersController controller = _controller(
        repository,
        committer: committer,
      );
      addTearDown(controller.dispose);
      await controller.load(householdIdFixture());

      await controller.leaveHousehold();

      expect(committer.nextHouseholds, isEmpty);
      expect(controller.state, isA<HouseholdMembersDepartureFailed>());
      expect(
        (controller.state as HouseholdMembersDepartureFailed).failure.kind,
        HouseholdMemberFailureKind.invalidPayload,
      );
    },
  );
}

HouseholdMembersController _controller(
  FakeHouseholdMemberRepository repository, {
  FakeActiveHouseholdDepartureCommitter? committer,
}) {
  return HouseholdMembersController(
    repository,
    FakeHouseholdCommandIdGenerator(),
    FakeRecentAuthenticationService(),
    committer ?? FakeActiveHouseholdDepartureCommitter(),
  );
}
