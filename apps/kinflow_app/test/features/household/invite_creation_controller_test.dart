import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/invite_creation_controller.dart';
import 'package:kinflow_app/features/household/application/invite_creation_state.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';

import '../../support/fakes/fake_invite_dependencies.dart';

void main() {
  test(
    'normalizes optional email and reuses command ID for a safe retry',
    () async {
      final FakeInviteRepository repository = FakeInviteRepository(
        createResults: <CreateHouseholdInviteResult>[
          const CreateHouseholdInviteFailed(
            InviteFailure(InviteFailureKind.temporarilyUnavailable),
          ),
          HouseholdInviteCreated(householdInviteFixture()),
        ],
      );
      final FakeInviteCommandIdGenerator generator =
          FakeInviteCommandIdGenerator();
      final InviteCreationController controller = InviteCreationController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);

      await controller.create(
        householdId: householdIdFixture(),
        targetEmail: ' Adult@Example.COM ',
      );
      expect(controller.state, isA<InviteCreationFailed>());

      await controller.create(
        householdId: householdIdFixture(),
        targetEmail: 'adult@example.com',
      );

      expect(controller.state, isA<InviteCreationSucceeded>());
      expect(repository.createRequests, hasLength(2));
      expect(repository.createRequests.first.targetEmail, 'adult@example.com');
      expect(repository.createRequests.first.expiresInHours, 168);
      expect(repository.createRequests.first.role.name, 'member');
      expect(
        repository.createRequests.first.idempotencyKey,
        repository.createRequests.last.idempotencyKey,
      );
      expect(generator.generateCount, 1);
    },
  );

  test('changed command input gets a new idempotency key', () async {
    final FakeInviteRepository repository = FakeInviteRepository(
      createResults: const <CreateHouseholdInviteResult>[
        CreateHouseholdInviteFailed(
          InviteFailure(InviteFailureKind.temporarilyUnavailable),
        ),
        CreateHouseholdInviteFailed(
          InviteFailure(InviteFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeInviteCommandIdGenerator generator =
        FakeInviteCommandIdGenerator();
    final InviteCreationController controller = InviteCreationController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);

    await controller.create(
      householdId: householdIdFixture(),
      targetEmail: 'first@example.com',
    );
    await controller.create(
      householdId: householdIdFixture(),
      targetEmail: 'second@example.com',
    );

    expect(generator.generateCount, 2);
    expect(
      repository.createRequests.first.idempotencyKey,
      isNot(repository.createRequests.last.idempotencyKey),
    );
  });

  test(
    'rejects malformed email before generating or sending a command',
    () async {
      final FakeInviteRepository repository = FakeInviteRepository();
      final FakeInviteCommandIdGenerator generator =
          FakeInviteCommandIdGenerator();
      final InviteCreationController controller = InviteCreationController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);

      await controller.create(
        householdId: householdIdFixture(),
        targetEmail: 'not-an-email',
      );

      expect(
        (controller.state as InviteCreationFailed).failure.kind,
        InviteFailureKind.invalidInput,
      );
      expect(repository.createRequests, isEmpty);
      expect(generator.generateCount, 0);
    },
  );

  test('coalesces duplicate taps while a create command is pending', () async {
    final Completer<CreateHouseholdInviteResult> response =
        Completer<CreateHouseholdInviteResult>();
    final FakeInviteRepository repository = FakeInviteRepository(
      createCallback: (_) => response.future,
    );
    final InviteCreationController controller = InviteCreationController(
      repository: repository,
      idGenerator: FakeInviteCommandIdGenerator(),
    );
    addTearDown(controller.dispose);

    final Future<void> first = controller.create(
      householdId: householdIdFixture(),
      targetEmail: '',
    );
    final Future<void> duplicate = controller.create(
      householdId: householdIdFixture(),
      targetEmail: '',
    );
    expect(identical(first, duplicate), isTrue);
    expect(repository.createRequests, hasLength(1));

    response.complete(HouseholdInviteCreated(householdInviteFixture()));
    await first;
    expect(controller.state, isA<InviteCreationSucceeded>());
  });

  test(
    'revoke uses a fresh command ID and removes the displayed link',
    () async {
      final FakeInviteRepository repository = FakeInviteRepository();
      final FakeInviteCommandIdGenerator generator =
          FakeInviteCommandIdGenerator();
      final InviteCreationController controller = InviteCreationController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);

      await controller.create(
        householdId: householdIdFixture(),
        targetEmail: '',
      );
      await controller.revoke();

      expect(repository.revokeRequests, hasLength(1));
      expect(generator.generateCount, 2);
      expect(controller.state, isA<InviteCreationIdle>());
    },
  );
}
