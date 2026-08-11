import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/recurring_chore_creation_controller.dart';
import 'package:kinflow_app/features/chores/application/recurring_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('normalizes input and reuses the command ID for a safe retry', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      recurringResults: <CreateRecurringChoreResult>[
        const CreateRecurringChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        RecurringChoreCreated(_snapshot()),
      ],
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final RecurringChoreCreationController controller =
        RecurringChoreCreationController(
          repository: repository,
          idGenerator: generator,
        );
    addTearDown(controller.dispose);

    await controller.create(
      householdId: activeHouseholdFixture().householdId,
      title: '  Take out recycling ',
      description: '  Blue bin ',
      assigneeMemberId: activeHouseholdFixture().memberId,
      startLocalDate: '2026-08-06',
      dueLocalTime: '19:30',
      recurrenceRule: _rule(),
    );
    expect(controller.state, isA<RecurringChoreCreationFailed>());

    await controller.create(
      householdId: activeHouseholdFixture().householdId,
      title: 'Take out recycling',
      description: 'Blue bin',
      assigneeMemberId: activeHouseholdFixture().memberId,
      startLocalDate: '2026-08-06',
      dueLocalTime: '19:30:00',
      recurrenceRule: _rule(),
    );

    expect(controller.state, isA<RecurringChoreCreationSucceeded>());
    expect(repository.recurringRequests, hasLength(2));
    expect(repository.recurringRequests.first.title, 'Take out recycling');
    expect(repository.recurringRequests.first.description, 'Blue bin');
    expect(
      repository.recurringRequests.first.idempotencyKey,
      repository.recurringRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
  });

  test('changed recurrence receives a fresh idempotency key', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      recurringResults: const <CreateRecurringChoreResult>[
        CreateRecurringChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        CreateRecurringChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final RecurringChoreCreationController controller =
        RecurringChoreCreationController(
          repository: repository,
          idGenerator: generator,
        );
    addTearDown(controller.dispose);

    await _create(controller, recurrenceRule: _rule());
    await _create(
      controller,
      recurrenceRule: _rule(interval: 2, end: const ChoreRecurrenceCountEnd(6)),
    );

    expect(generator.generateCount, 2);
    expect(
      repository.recurringRequests.first.idempotencyKey,
      isNot(repository.recurringRequests.last.idempotencyKey),
    );
    expect(repository.recurringRequests.last.recurrenceRule.interval, 2);
    expect(
      repository.recurringRequests.last.recurrenceRule.end.toJson(),
      <String, Object?>{'type': 'count', 'count': 6},
    );
  });

  test(
    'weekly weekday changes rotate the key and exact retries reuse it',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository(
        recurringResults: const <CreateRecurringChoreResult>[
          CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final RecurringChoreCreationController controller =
          RecurringChoreCreationController(
            repository: repository,
            idGenerator: generator,
          );
      addTearDown(controller.dispose);
      final ChoreLocalDate start = ChoreLocalDate.tryParse('2026-08-06')!;
      final ChoreRecurrenceRule weekly = _rule(
        frequency: ChoreRecurrenceFrequency.weekly,
      );
      final ChoreRecurrenceRule mondayAndThursday = weekly
          .tryWithWeeklyWeekdays(
            weekdays: const <ChoreWeekday>[
              ChoreWeekday.thursday,
              ChoreWeekday.monday,
            ],
            interval: 1,
            end: const ChoreRecurrenceNeverEnds(),
            minimumLocalDate: start,
            requiredStartLocalDate: start,
          )!;

      await _create(controller, recurrenceRule: weekly);
      await _create(controller, recurrenceRule: mondayAndThursday);
      await _create(controller, recurrenceRule: mondayAndThursday);

      expect(generator.generateCount, 2);
      expect(
        repository.recurringRequests.first.idempotencyKey,
        isNot(repository.recurringRequests[1].idempotencyKey),
      );
      expect(
        repository.recurringRequests[1].idempotencyKey,
        repository.recurringRequests.last.idempotencyKey,
      );
      expect(
        repository.recurringRequests.last.recurrenceRule.weekdays,
        const <ChoreWeekday>[ChoreWeekday.monday, ChoreWeekday.thursday],
      );
    },
  );

  test(
    'invalid details stop before ID generation or repository access',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository();
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final RecurringChoreCreationController controller =
          RecurringChoreCreationController(
            repository: repository,
            idGenerator: generator,
          );
      addTearDown(controller.dispose);

      await controller.create(
        householdId: activeHouseholdFixture().householdId,
        title: '',
        description: '',
        assigneeMemberId: activeHouseholdFixture().memberId,
        startLocalDate: '2026-02-30',
        dueLocalTime: '24:00',
        recurrenceRule: _rule(frequency: ChoreRecurrenceFrequency.monthly),
      );

      expect(
        (controller.state as RecurringChoreCreationFailed).failure.kind,
        ChoreFailureKind.invalidInput,
      );
      expect(repository.recurringRequests, isEmpty);
      expect(generator.generateCount, 0);
    },
  );

  test('coalesces duplicate taps while the command is pending', () async {
    final Completer<CreateRecurringChoreResult> response =
        Completer<CreateRecurringChoreResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      recurringCallback: (_) => response.future,
    );
    final RecurringChoreCreationController controller =
        RecurringChoreCreationController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );
    addTearDown(controller.dispose);

    final Future<void> first = _create(
      controller,
      recurrenceRule: _rule(frequency: ChoreRecurrenceFrequency.monthly),
    );
    final Future<void> duplicate = _create(
      controller,
      recurrenceRule: _rule(frequency: ChoreRecurrenceFrequency.monthly),
    );
    expect(identical(first, duplicate), isTrue);
    expect(repository.recurringRequests, hasLength(1));

    response.complete(RecurringChoreCreated(_snapshot()));
    await first;
    expect(controller.state, isA<RecurringChoreCreationSucceeded>());
  });
}

Future<void> _create(
  RecurringChoreCreationController controller, {
  required ChoreRecurrenceRule recurrenceRule,
}) {
  return controller.create(
    householdId: activeHouseholdFixture().householdId,
    title: 'Laundry',
    description: '',
    assigneeMemberId: activeHouseholdFixture().memberId,
    startLocalDate: '2026-08-06',
    dueLocalTime: null,
    recurrenceRule: recurrenceRule,
  );
}

ChoreRecurrenceRule _rule({
  ChoreRecurrenceFrequency frequency = ChoreRecurrenceFrequency.daily,
  int interval = 1,
  ChoreRecurrenceEnd end = const ChoreRecurrenceNeverEnds(),
}) {
  return ChoreRecurrenceRule.tryAnchored(
    frequency: frequency,
    startLocalDate: ChoreLocalDate.tryParse('2026-08-06')!,
    interval: interval,
    end: end,
  )!;
}

RecurringChoreSnapshot _snapshot() {
  final ChoreLocalDate start = ChoreLocalDate.tryParse('2026-08-06')!;
  return RecurringChoreSnapshot(
    householdId: activeHouseholdFixture().householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    firstOccurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.daily,
      startLocalDate: start,
    ),
    materializedThrough: start,
    materializedCount: 1,
    created: true,
  );
}
