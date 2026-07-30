import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/household_member_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/household_member_dto.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';

import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  group('ProviderHouseholdMemberRepository', () {
    test('maps one minimized roster with exactly one current Owner', () async {
      final _FakeMemberDataSource dataSource = _FakeMemberDataSource(
        rosterResult: HouseholdMemberDataSucceeded(_validRosterRows()),
      );
      final ProviderHouseholdMemberRepository repository =
          ProviderHouseholdMemberRepository(dataSource);

      final LoadHouseholdMemberRosterResult result = await repository
          .loadRoster(householdIdFixture());

      expect(result, isA<HouseholdMemberRosterLoaded>());
      final HouseholdMemberRoster roster =
          (result as HouseholdMemberRosterLoaded).roster;
      expect(roster.householdName, 'Kim Home');
      expect(roster.householdVersion, 3);
      expect(roster.members, hasLength(2));
      expect(roster.currentMember.role, HouseholdMemberRole.owner);
      expect(dataSource.lastHouseholdId, householdIdFixture().value);
    });

    test(
      'rejects mixed, duplicate-current, and missing-Owner rosters',
      () async {
        final List<List<HouseholdMemberRosterRowDto>> invalidCases =
            <List<HouseholdMemberRosterRowDto>>[
              <HouseholdMemberRosterRowDto>[
                ..._validRosterRows(),
                _row(
                  memberId: '33333333-3333-4333-8333-333333333335',
                  displayName: 'Taylor',
                  role: 'member',
                  isCurrentUser: true,
                ),
              ],
              <HouseholdMemberRosterRowDto>[
                _row(role: 'admin', isCurrentUser: true),
                _row(
                  memberId: '33333333-3333-4333-8333-333333333334',
                  displayName: 'Sam',
                  role: 'member',
                ),
              ],
              <HouseholdMemberRosterRowDto>[
                _row(isCurrentUser: true),
                _row(
                  householdId: '22222222-2222-4222-8222-222222222223',
                  memberId: '33333333-3333-4333-8333-333333333334',
                  displayName: 'Sam',
                  role: 'member',
                ),
              ],
            ];

        for (final List<HouseholdMemberRosterRowDto> rows in invalidCases) {
          final ProviderHouseholdMemberRepository repository =
              ProviderHouseholdMemberRepository(
                _FakeMemberDataSource(
                  rosterResult: HouseholdMemberDataSucceeded(rows),
                ),
              );
          final result = await repository.loadRoster(householdIdFixture());
          expect(
            (result as LoadHouseholdMemberRosterFailed).failure.kind,
            HouseholdMemberFailureKind.invalidPayload,
          );
        }
      },
    );

    test(
      'forwards recent proof and requires exact role response correlation',
      () async {
        final _FakeMemberDataSource dataSource = _FakeMemberDataSource(
          roleResult: const HouseholdMemberDataSucceeded(
            HouseholdMemberRoleMutationDto(
              householdId: '22222222-2222-4222-8222-222222222222',
              memberId: '33333333-3333-4333-8333-333333333334',
              role: 'admin',
              version: 5,
            ),
          ),
        );
        final ProviderHouseholdMemberRepository repository =
            ProviderHouseholdMemberRepository(dataSource);

        final HouseholdMemberCommandResult result = await repository.changeRole(
          _changeRoleCommand(),
        );

        expect(result, isA<HouseholdMemberCommandCompleted>());
        expect(
          dataSource.lastIdempotencyKey,
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        );
        expect(dataSource.lastProof, 'fresh-supabase-access-token');
        expect(dataSource.lastRole, 'admin');
        expect(dataSource.lastExpectedVersion, 4);

        dataSource.roleResult = const HouseholdMemberDataSucceeded(
          HouseholdMemberRoleMutationDto(
            householdId: '22222222-2222-4222-8222-222222222222',
            memberId: '33333333-3333-4333-8333-333333333334',
            role: 'admin',
            version: 6,
          ),
        );
        final HouseholdMemberCommandResult mismatched = await repository
            .changeRole(_changeRoleCommand());
        expect(
          (mismatched as HouseholdMemberCommandFailed).failure.kind,
          HouseholdMemberFailureKind.invalidPayload,
        );
      },
    );

    test(
      'validates removal timestamp, target, and expected next version',
      () async {
        final _FakeMemberDataSource dataSource = _FakeMemberDataSource(
          removalResult: const HouseholdMemberDataSucceeded(
            HouseholdMemberRemovalDto(
              householdId: '22222222-2222-4222-8222-222222222222',
              memberId: '33333333-3333-4333-8333-333333333334',
              version: 5,
              removedAt: '2026-07-30T00:00:00Z',
            ),
          ),
        );
        final ProviderHouseholdMemberRepository repository =
            ProviderHouseholdMemberRepository(dataSource);

        expect(
          await repository.removeMember(_removeCommand()),
          isA<HouseholdMemberCommandCompleted>(),
        );

        dataSource.removalResult = const HouseholdMemberDataSucceeded(
          HouseholdMemberRemovalDto(
            householdId: '22222222-2222-4222-8222-222222222222',
            memberId: '33333333-3333-4333-8333-333333333334',
            version: 5,
            removedAt: 'not-a-timestamp',
          ),
        );
        final HouseholdMemberCommandResult invalid = await repository
            .removeMember(_removeCommand());
        expect(
          (invalid as HouseholdMemberCommandFailed).failure.kind,
          HouseholdMemberFailureKind.invalidPayload,
        );
      },
    );

    test('leave accepts only a paired nullable fallback selection', () async {
      final _FakeMemberDataSource dataSource = _FakeMemberDataSource(
        leaveResult: const HouseholdMemberDataSucceeded(
          LeaveHouseholdDto(
            householdId: '22222222-2222-4222-8222-222222222222',
            memberId: '33333333-3333-4333-8333-333333333333',
            version: 2,
            removedAt: '2026-07-30T00:00:00Z',
            activeHouseholdId: '22222222-2222-4222-8222-222222222223',
            activeMemberId: '33333333-3333-4333-8333-333333333335',
          ),
        ),
      );
      final ProviderHouseholdMemberRepository repository =
          ProviderHouseholdMemberRepository(dataSource);

      expect(
        await repository.leaveHousehold(_leaveCommand()),
        isA<HouseholdMemberCommandCompleted>(),
      );

      dataSource.leaveResult = const HouseholdMemberDataSucceeded(
        LeaveHouseholdDto(
          householdId: '22222222-2222-4222-8222-222222222222',
          memberId: '33333333-3333-4333-8333-333333333333',
          version: 2,
          removedAt: '2026-07-30T00:00:00Z',
          activeHouseholdId: '22222222-2222-4222-8222-222222222223',
          activeMemberId: null,
        ),
      );
      final HouseholdMemberCommandResult invalid = await repository
          .leaveHousehold(_leaveCommand());
      expect(
        (invalid as HouseholdMemberCommandFailed).failure.kind,
        HouseholdMemberFailureKind.invalidPayload,
      );
    });

    test(
      'Owner transfer requires the requested target and next version',
      () async {
        final _FakeMemberDataSource dataSource = _FakeMemberDataSource(
          transferResult: const HouseholdMemberDataSucceeded(
            HouseholdOwnerTransferDto(
              householdId: '22222222-2222-4222-8222-222222222222',
              ownerMemberId: '33333333-3333-4333-8333-333333333334',
              version: 4,
            ),
          ),
        );
        final ProviderHouseholdMemberRepository repository =
            ProviderHouseholdMemberRepository(dataSource);

        expect(
          await repository.transferOwner(_transferCommand()),
          isA<HouseholdMemberCommandCompleted>(),
        );

        dataSource.transferResult = const HouseholdMemberDataSucceeded(
          HouseholdOwnerTransferDto(
            householdId: '22222222-2222-4222-8222-222222222222',
            ownerMemberId: '33333333-3333-4333-8333-333333333333',
            version: 4,
          ),
        );
        final HouseholdMemberCommandResult invalid = await repository
            .transferOwner(_transferCommand());
        expect(
          (invalid as HouseholdMemberCommandFailed).failure.kind,
          HouseholdMemberFailureKind.invalidPayload,
        );
      },
    );

    test('maps provider failures to stable domain failures', () async {
      const Map<HouseholdMemberDataFailureKind, HouseholdMemberFailureKind>
      cases = <HouseholdMemberDataFailureKind, HouseholdMemberFailureKind>{
        HouseholdMemberDataFailureKind.unauthenticated:
            HouseholdMemberFailureKind.unauthenticated,
        HouseholdMemberDataFailureKind.permissionDenied:
            HouseholdMemberFailureKind.permissionDenied,
        HouseholdMemberDataFailureKind.roleNotAllowed:
            HouseholdMemberFailureKind.roleNotAllowed,
        HouseholdMemberDataFailureKind.ownerTransferRequired:
            HouseholdMemberFailureKind.ownerTransferRequired,
        HouseholdMemberDataFailureKind.recentAuthenticationRequired:
            HouseholdMemberFailureKind.recentAuthenticationRequired,
        HouseholdMemberDataFailureKind.versionConflict:
            HouseholdMemberFailureKind.versionConflict,
        HouseholdMemberDataFailureKind.idempotencyConflict:
            HouseholdMemberFailureKind.idempotencyConflict,
        HouseholdMemberDataFailureKind.unknown:
            HouseholdMemberFailureKind.internal,
      };
      for (final entry in cases.entries) {
        final ProviderHouseholdMemberRepository repository =
            ProviderHouseholdMemberRepository(
              _FakeMemberDataSource(
                rosterResult: HouseholdMemberDataFailed(entry.key),
              ),
            );
        final result = await repository.loadRoster(householdIdFixture());
        expect(
          (result as LoadHouseholdMemberRosterFailed).failure.kind,
          entry.value,
          reason: entry.key.name,
        );
      }
    });
  });
}

final class _FakeMemberDataSource implements HouseholdMemberDataSource {
  _FakeMemberDataSource({
    this.rosterResult = const HouseholdMemberDataFailed(
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    ),
    this.roleResult = const HouseholdMemberDataFailed(
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    ),
    this.removalResult = const HouseholdMemberDataFailed(
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    ),
    this.leaveResult = const HouseholdMemberDataFailed(
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    ),
    this.transferResult = const HouseholdMemberDataFailed(
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    ),
  });

  HouseholdMemberDataResult<List<HouseholdMemberRosterRowDto>> rosterResult;
  HouseholdMemberDataResult<HouseholdMemberRoleMutationDto> roleResult;
  HouseholdMemberDataResult<HouseholdMemberRemovalDto> removalResult;
  HouseholdMemberDataResult<LeaveHouseholdDto> leaveResult;
  HouseholdMemberDataResult<HouseholdOwnerTransferDto> transferResult;
  String? lastHouseholdId;
  String? lastIdempotencyKey;
  String? lastProof;
  String? lastRole;
  int? lastExpectedVersion;

  @override
  Future<HouseholdMemberDataResult<List<HouseholdMemberRosterRowDto>>>
  loadRoster({required String householdId}) async {
    lastHouseholdId = householdId;
    return rosterResult;
  }

  @override
  Future<HouseholdMemberDataResult<HouseholdMemberRoleMutationDto>> changeRole({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String memberId,
    required String role,
    required int expectedVersion,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    lastProof = recentAuthenticationProof;
    lastRole = role;
    lastExpectedVersion = expectedVersion;
    return roleResult;
  }

  @override
  Future<HouseholdMemberDataResult<HouseholdMemberRemovalDto>> removeMember({
    required String idempotencyKey,
    required String householdId,
    required String memberId,
    required int expectedVersion,
  }) async => removalResult;

  @override
  Future<HouseholdMemberDataResult<LeaveHouseholdDto>> leaveHousehold({
    required String idempotencyKey,
    required String householdId,
    required int expectedVersion,
  }) async => leaveResult;

  @override
  Future<HouseholdMemberDataResult<HouseholdOwnerTransferDto>> transferOwner({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String newOwnerMemberId,
    required int expectedVersion,
  }) async => transferResult;
}

List<HouseholdMemberRosterRowDto> _validRosterRows() {
  return <HouseholdMemberRosterRowDto>[
    _row(isCurrentUser: true),
    _row(
      memberId: '33333333-3333-4333-8333-333333333334',
      displayName: 'Sam',
      role: 'member',
    ),
  ];
}

HouseholdMemberRosterRowDto _row({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String memberId = '33333333-3333-4333-8333-333333333333',
  String displayName = 'Alex',
  String role = 'owner',
  bool isCurrentUser = false,
}) {
  return HouseholdMemberRosterRowDto(
    householdId: householdId,
    householdName: 'Kim Home',
    householdVersion: 3,
    memberId: memberId,
    displayName: displayName,
    role: role,
    memberVersion: role == 'owner' ? 1 : 4,
    isCurrentUser: isCurrentUser,
  );
}

ChangeHouseholdMemberRoleCommand _changeRoleCommand() {
  return ChangeHouseholdMemberRoleCommand(
    idempotencyKey: FakeHouseholdCommandIdGenerator().generate(),
    householdId: householdIdFixture(),
    memberId: householdMemberIdFixture('33333333-3333-4333-8333-333333333334'),
    role: HouseholdMemberRole.admin,
    expectedVersion: 4,
    recentAuthenticationProof: recentAuthenticationProofFixture(),
  );
}

RemoveHouseholdMemberCommand _removeCommand() {
  return RemoveHouseholdMemberCommand(
    idempotencyKey: FakeHouseholdCommandIdGenerator().generate(),
    householdId: householdIdFixture(),
    memberId: householdMemberIdFixture('33333333-3333-4333-8333-333333333334'),
    expectedVersion: 4,
  );
}

LeaveHouseholdCommand _leaveCommand() {
  return LeaveHouseholdCommand(
    idempotencyKey: FakeHouseholdCommandIdGenerator().generate(),
    householdId: householdIdFixture(),
    expectedVersion: 1,
  );
}

TransferHouseholdOwnerCommand _transferCommand() {
  return TransferHouseholdOwnerCommand(
    idempotencyKey: FakeHouseholdCommandIdGenerator().generate(),
    householdId: householdIdFixture(),
    newOwnerMemberId: householdMemberIdFixture(
      '33333333-3333-4333-8333-333333333334',
    ),
    expectedVersion: 3,
    recentAuthenticationProof: recentAuthenticationProofFixture(),
  );
}
