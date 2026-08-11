import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_creation_controller.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('normalizes input and reuses the command ID for a safe retry', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      createResults: <CreateOneTimeChoreResult>[
        const CreateOneTimeChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        OneTimeChoreCreated(choreOccurrenceFixture()),
      ],
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final OneTimeChoreCreationController controller =
        OneTimeChoreCreationController(
          repository: repository,
          idGenerator: generator,
        );
    addTearDown(controller.dispose);

    await controller.create(
      householdId: activeHouseholdFixture().householdId,
      title: '  Take out recycling ',
      description: '  Blue bin ',
      assigneeMemberId: activeHouseholdFixture().memberId,
      dueLocalDate: '2026-08-06',
      dueLocalTime: '19:30',
    );
    expect(controller.state, isA<OneTimeChoreCreationFailed>());

    await controller.create(
      householdId: activeHouseholdFixture().householdId,
      title: 'Take out recycling',
      description: 'Blue bin',
      assigneeMemberId: activeHouseholdFixture().memberId,
      dueLocalDate: '2026-08-06',
      dueLocalTime: '19:30:00',
    );

    expect(controller.state, isA<OneTimeChoreCreationSucceeded>());
    expect(repository.createRequests, hasLength(2));
    expect(repository.createRequests.first.title, 'Take out recycling');
    expect(repository.createRequests.first.description, 'Blue bin');
    expect(
      repository.createRequests.first.idempotencyKey,
      repository.createRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
  });

  test('changed details receive a fresh idempotency key', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      createResults: const <CreateOneTimeChoreResult>[
        CreateOneTimeChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        CreateOneTimeChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final OneTimeChoreCreationController controller =
        OneTimeChoreCreationController(
          repository: repository,
          idGenerator: generator,
        );
    addTearDown(controller.dispose);

    await _create(controller, title: 'First');
    await _create(controller, title: 'Second');

    expect(generator.generateCount, 2);
    expect(
      repository.createRequests.first.idempotencyKey,
      isNot(repository.createRequests.last.idempotencyKey),
    );
  });

  test(
    'invalid details stop before ID generation or repository access',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository();
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final OneTimeChoreCreationController controller =
          OneTimeChoreCreationController(
            repository: repository,
            idGenerator: generator,
          );
      addTearDown(controller.dispose);

      await controller.create(
        householdId: activeHouseholdFixture().householdId,
        title: '',
        description: '',
        assigneeMemberId: activeHouseholdFixture().memberId,
        dueLocalDate: '2026-02-30',
        dueLocalTime: null,
      );

      expect(
        (controller.state as OneTimeChoreCreationFailed).failure.kind,
        ChoreFailureKind.invalidInput,
      );
      expect(repository.createRequests, isEmpty);
      expect(generator.generateCount, 0);
    },
  );

  test('coalesces duplicate taps while the command is pending', () async {
    final Completer<CreateOneTimeChoreResult> response =
        Completer<CreateOneTimeChoreResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      createCallback: (_) => response.future,
    );
    final OneTimeChoreCreationController controller =
        OneTimeChoreCreationController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );
    addTearDown(controller.dispose);

    final Future<void> first = _create(controller, title: 'Laundry');
    final Future<void> duplicate = _create(controller, title: 'Laundry');
    expect(identical(first, duplicate), isTrue);
    expect(repository.createRequests, hasLength(1));

    response.complete(OneTimeChoreCreated(choreOccurrenceFixture()));
    await first;
    expect(controller.state, isA<OneTimeChoreCreationSucceeded>());
  });
}

Future<void> _create(
  OneTimeChoreCreationController controller, {
  required String title,
}) {
  return controller.create(
    householdId: activeHouseholdFixture().householdId,
    title: title,
    description: '',
    assigneeMemberId: activeHouseholdFixture().memberId,
    dueLocalDate: '2026-08-06',
    dueLocalTime: null,
  );
}
