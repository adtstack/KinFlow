import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('optimistically completes and coalesces duplicate taps', () async {
    final Completer<SetChoreCompletionResult> response =
        Completer<SetChoreCompletionResult>();
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      completionCallback: (_) => response.future,
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    final Future<void> first = controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      completed: true,
    );
    final Future<void> duplicate = controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      completed: true,
    );

    expect(identical(first, duplicate), isTrue);
    expect(repository.completionRequests, hasLength(1));
    expect(generator.generateCount, 1);
    final TodayChoresReady optimistic = controller.state as TodayChoresReady;
    expect(optimistic.pendingOccurrenceId, occurrence.id);
    expect(
      optimistic.today.occurrences.single.status,
      ChoreOccurrenceStatus.completed,
    );
    expect(optimistic.today.occurrences.single.version, 1);

    response.complete(
      ChoreCompletionSet(_snapshot(repository.completionRequests.single)),
    );
    await first;

    final TodayChoresReady reconciled = controller.state as TodayChoresReady;
    expect(reconciled.pendingOccurrenceId, isNull);
    expect(reconciled.actionFailure, isNull);
    expect(
      reconciled.today.occurrences.single.status,
      ChoreOccurrenceStatus.completed,
    );
    expect(reconciled.today.occurrences.single.version, 2);
  });

  test('rolls back failures and safely reuses the command ID', () async {
    var attempts = 0;
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      completionCallback: (SetChoreCompletionRequest request) async {
        attempts += 1;
        return attempts == 1
            ? const SetChoreCompletionFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : ChoreCompletionSet(_snapshot(request));
      },
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      completed: true,
    );

    final TodayChoresReady rolledBack = controller.state as TodayChoresReady;
    expect(
      rolledBack.today.occurrences.single.status,
      ChoreOccurrenceStatus.scheduled,
    );
    expect(
      rolledBack.actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );

    await controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      completed: true,
    );

    expect(repository.completionRequests, hasLength(2));
    expect(
      repository.completionRequests.first.idempotencyKey,
      repository.completionRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    final TodayChoresReady completed = controller.state as TodayChoresReady;
    expect(completed.actionFailure, isNull);
    expect(
      completed.today.occurrences.single.status,
      ChoreOccurrenceStatus.completed,
    );
    expect(completed.today.occurrences.single.version, 2);
  });

  test('reloads authoritative Today after a stale version', () async {
    final ChoreOccurrence scheduled = choreOccurrenceFixture();
    final ChoreOccurrence authoritative = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.completed,
      version: 2,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[scheduled]),
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[authoritative]),
        ),
      ],
      completionResults: const <SetChoreCompletionResult>[
        SetChoreCompletionFailed(ChoreFailure(ChoreFailureKind.staleVersion)),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);

    await controller.load(activeHouseholdFixture().householdId);
    await controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: scheduled.id,
      completed: true,
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
    expect(
      ready.today.occurrences.single.status,
      ChoreOccurrenceStatus.completed,
    );
    expect(ready.today.occurrences.single.version, 2);
  });

  test('reopens a completed occurrence with its current version', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.completed,
      version: 2,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.setCompleted(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      completed: false,
    );

    expect(repository.completionRequests.single.completed, isFalse);
    expect(repository.completionRequests.single.expectedVersion, 2);
    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(
      ready.today.occurrences.single.status,
      ChoreOccurrenceStatus.scheduled,
    );
    expect(ready.today.occurrences.single.version, 3);
  });

  test(
    'keeps a skip target pending then removes only that occurrence',
    () async {
      final Completer<SkipChoreOccurrenceResult> response =
          Completer<SkipChoreOccurrenceResult>();
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrence sibling = choreOccurrenceFixture(
        occurrenceId: '66666666-6666-4666-8666-666666666666',
        seriesId: occurrence.seriesId.value,
        title: 'Sibling occurrence',
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[occurrence, sibling],
        ),
        skipCallback: (_) => response.future,
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);

      final Future<void> first = controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );
      final Future<void> duplicate = controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      expect(identical(first, duplicate), isTrue);
      expect(repository.skipRequests, hasLength(1));
      expect(generator.generateCount, 1);
      final TodayChoresReady pending = controller.state as TodayChoresReady;
      expect(pending.pendingOccurrenceId, occurrence.id);
      expect(pending.today.occurrences, hasLength(2));

      response.complete(
        ChoreOccurrenceSkipped(_skipSnapshot(repository.skipRequests.single)),
      );
      await first;

      final TodayChoresReady skipped = controller.state as TodayChoresReady;
      expect(skipped.pendingOccurrenceId, isNull);
      expect(skipped.actionFailure, isNull);
      expect(skipped.today.occurrences.single.id, sibling.id);
    },
  );

  test('rolls back skip failure and safely reuses the command ID', () async {
    var attempts = 0;
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      skipCallback: (SkipChoreOccurrenceRequest request) async {
        attempts += 1;
        return attempts == 1
            ? const SkipChoreOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : ChoreOccurrenceSkipped(_skipSnapshot(request));
      },
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.skipOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
    );
    final TodayChoresReady rolledBack = controller.state as TodayChoresReady;
    expect(rolledBack.today.occurrences.single.id, occurrence.id);
    expect(
      rolledBack.actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );

    await controller.skipOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
    );

    expect(repository.skipRequests, hasLength(2));
    expect(
      repository.skipRequests.first.idempotencyKey,
      repository.skipRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    expect((controller.state as TodayChoresReady).today.occurrences, isEmpty);
  });

  test('reloads authoritative Today after a stale skip version', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.monthly,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        ),
        TodayChoresLoaded(todayChoresFixture()),
      ],
      skipResults: const <SkipChoreOccurrenceResult>[
        SkipChoreOccurrenceFailed(ChoreFailure(ChoreFailureKind.staleVersion)),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);

    await controller.load(activeHouseholdFixture().householdId);
    await controller.skipOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.today.occurrences, isEmpty);
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
  });

  test(
    'rejects skip for a one-time occurrence before repository access',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);

      await controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      expect(repository.skipRequests, isEmpty);
      expect(generator.generateCount, 0);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.invalidTransition,
      );
    },
  );

  test(
    'optimistically restores at the original index and coalesces Undo taps',
    () async {
      final Completer<RestoreSkippedChoreOccurrenceResult> response =
          Completer<RestoreSkippedChoreOccurrenceResult>();
      final ChoreOccurrence before = choreOccurrenceFixture(
        occurrenceId: '44444444-4444-4444-8444-444444444441',
        title: 'Before target',
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrence target = choreOccurrenceFixture(
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrence after = choreOccurrenceFixture(
        occurrenceId: '66666666-6666-4666-8666-666666666666',
        title: 'After target',
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[before, target, after],
        ),
        restoreCallback: (_) => response.future,
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      await controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );

      final TodayChoresReady skipped = controller.state as TodayChoresReady;
      expect(skipped.undoableSkip?.occurrence.id, target.id);
      expect(skipped.undoableSkip?.skippedVersion, 2);
      expect(skipped.undoableSkip?.insertionIndex, 1);

      final Future<void> first = controller.restoreSkippedOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );
      final Future<void> duplicate = controller.restoreSkippedOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );

      expect(identical(first, duplicate), isTrue);
      expect(repository.restoreRequests, hasLength(1));
      expect(repository.restoreRequests.single.expectedVersion, 2);
      expect(generator.generateCount, 2);
      final TodayChoresReady pending = controller.state as TodayChoresReady;
      expect(pending.pendingOccurrenceId, target.id);
      expect(
        pending.today.occurrences.map((ChoreOccurrence item) => item.id),
        <ChoreOccurrenceId>[before.id, target.id, after.id],
      );
      expect(pending.today.occurrences[1].version, 2);

      response.complete(
        ChoreOccurrenceRestored(
          _restoreSnapshot(repository.restoreRequests.single),
        ),
      );
      await first;

      final TodayChoresReady restored = controller.state as TodayChoresReady;
      expect(restored.pendingOccurrenceId, isNull);
      expect(restored.actionFailure, isNull);
      expect(restored.undoableSkip, isNull);
      expect(restored.today.occurrences[1].id, target.id);
      expect(restored.today.occurrences[1].version, 3);
    },
  );

  test(
    'rolls back failed Undo and safely reuses the restore command ID',
    () async {
      var attempts = 0;
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        restoreCallback: (RestoreSkippedChoreOccurrenceRequest request) async {
          attempts += 1;
          return attempts == 1
              ? const RestoreSkippedChoreOccurrenceFailed(
                  ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
                )
              : ChoreOccurrenceRestored(_restoreSnapshot(request));
        },
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      await controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      await controller.restoreSkippedOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );
      final TodayChoresReady rolledBack = controller.state as TodayChoresReady;
      expect(rolledBack.today.occurrences, isEmpty);
      expect(rolledBack.undoableSkip?.occurrence.id, occurrence.id);
      expect(
        rolledBack.actionFailure?.kind,
        ChoreFailureKind.temporarilyUnavailable,
      );

      await controller.restoreSkippedOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      expect(repository.restoreRequests, hasLength(2));
      expect(
        repository.restoreRequests.first.idempotencyKey,
        repository.restoreRequests.last.idempotencyKey,
      );
      expect(generator.generateCount, 2);
      final TodayChoresReady restored = controller.state as TodayChoresReady;
      expect(restored.today.occurrences.single.version, 3);
      expect(restored.undoableSkip, isNull);
    },
  );

  test(
    'treats authoritative scheduled state as successful stale Undo',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        recurrenceFrequency: ChoreRecurrenceFrequency.monthly,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
          ),
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[occurrence.copyWith(version: 3)],
            ),
          ),
        ],
        restoreResults: const <RestoreSkippedChoreOccurrenceResult>[
          RestoreSkippedChoreOccurrenceFailed(
            ChoreFailure(ChoreFailureKind.staleVersion),
          ),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      await controller.skipOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      await controller.restoreSkippedOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(repository.loadedHouseholds, hasLength(2));
      expect(ready.today.occurrences.single.version, 3);
      expect(ready.actionFailure, isNull);
      expect(ready.undoableSkip, isNull);
    },
  );

  test(
    'optimistically removes a moved occurrence and coalesces duplicate saves',
    () async {
      final Completer<RescheduleChoreOccurrenceResult> response =
          Completer<RescheduleChoreOccurrenceResult>();
      addTearDown(() {
        if (!response.isCompleted) {
          response.complete(
            const RescheduleChoreOccurrenceFailed(
              ChoreFailure(ChoreFailureKind.internal),
            ),
          );
        }
      });
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrence sibling = choreOccurrenceFixture(
        occurrenceId: '66666666-6666-4666-8666-666666666666',
        title: 'Sibling occurrence',
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[occurrence, sibling],
        ),
        rescheduleCallback: (_) => response.future,
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      final ChoreLocalDate tomorrow = ChoreLocalDate.tryParse('2026-08-07')!;
      final ChoreLocalTime targetTime = ChoreLocalTime.tryParse('18:30')!;

      final Future<void> first = controller.rescheduleOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        dueLocalDate: tomorrow,
        dueLocalTime: targetTime,
      );
      final Future<void> duplicate = controller.rescheduleOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        dueLocalDate: tomorrow,
        dueLocalTime: targetTime,
      );

      expect(identical(first, duplicate), isTrue);
      expect(repository.rescheduleRequests, hasLength(1));
      expect(generator.generateCount, 1);
      final TodayChoresReady pending = controller.state as TodayChoresReady;
      expect(pending.pendingOccurrenceId, occurrence.id);
      expect(pending.today.occurrences.single.id, sibling.id);

      response.complete(
        ChoreOccurrenceRescheduled(
          _rescheduleSnapshot(
            repository.rescheduleRequests.single,
            dueAt: DateTime.parse('2026-08-07T09:30:00Z'),
          ),
        ),
      );
      await first;

      final TodayChoresReady reconciled = controller.state as TodayChoresReady;
      expect(reconciled.pendingOccurrenceId, isNull);
      expect(reconciled.actionFailure, isNull);
      expect(reconciled.today.occurrences.single.id, sibling.id);
    },
  );

  test(
    'reorders a same-day reschedule during optimistic reconciliation',
    () async {
      final Completer<RescheduleChoreOccurrenceResult> response =
          Completer<RescheduleChoreOccurrenceResult>();
      addTearDown(() {
        if (!response.isCompleted) {
          response.complete(
            const RescheduleChoreOccurrenceFailed(
              ChoreFailure(ChoreFailureKind.internal),
            ),
          );
        }
      });
      final ChoreOccurrence target = choreOccurrenceFixture(
        title: 'Late target',
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
        recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
      );
      final ChoreOccurrence sibling = choreOccurrenceFixture(
        occurrenceId: '66666666-6666-4666-8666-666666666666',
        title: 'Morning sibling',
        dueLocalTime: ChoreLocalTime.tryParse('10:00'),
        dueAt: DateTime.parse('2026-08-06T01:00:00Z'),
        recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[sibling, target],
        ),
        rescheduleCallback: (_) => response.future,
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);

      final Future<void> action = controller.rescheduleOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
        dueLocalDate: todayChoresFixture().localDate,
        dueLocalTime: ChoreLocalTime.tryParse('08:00'),
      );

      expect(
        (controller.state as TodayChoresReady).today.occurrences.map(
          (ChoreOccurrence item) => item.id,
        ),
        <ChoreOccurrenceId>[target.id, sibling.id],
      );

      response.complete(
        ChoreOccurrenceRescheduled(
          _rescheduleSnapshot(
            repository.rescheduleRequests.single,
            dueAt: DateTime.parse('2026-08-05T23:00:00Z'),
          ),
        ),
      );
      await action;

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(
        ready.today.occurrences.map((ChoreOccurrence item) => item.id),
        <ChoreOccurrenceId>[target.id, sibling.id],
      );
      expect(ready.today.occurrences.first.dueLocalTime?.value, '08:00');
      expect(ready.today.occurrences.first.version, 2);
    },
  );

  test('rolls back reschedule failure and reuses the command ID', () async {
    var attempts = 0;
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.monthly,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      rescheduleCallback: (RescheduleChoreOccurrenceRequest request) async {
        attempts += 1;
        return attempts == 1
            ? const RescheduleChoreOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : ChoreOccurrenceRescheduled(_rescheduleSnapshot(request));
      },
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);
    final ChoreLocalTime targetTime = ChoreLocalTime.tryParse('18:30')!;

    await controller.rescheduleOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      dueLocalDate: todayChoresFixture().localDate,
      dueLocalTime: targetTime,
    );
    final TodayChoresReady rolledBack = controller.state as TodayChoresReady;
    expect(rolledBack.today.occurrences.single.dueLocalTime, isNull);
    expect(
      rolledBack.actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );

    await controller.rescheduleOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      dueLocalDate: todayChoresFixture().localDate,
      dueLocalTime: targetTime,
    );

    expect(repository.rescheduleRequests, hasLength(2));
    expect(
      repository.rescheduleRequests.first.idempotencyKey,
      repository.rescheduleRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(ready.actionFailure, isNull);
    expect(ready.today.occurrences.single.dueLocalTime, targetTime);
    expect(ready.today.occurrences.single.version, 2);
  });

  test('reloads authoritative Today after a stale reschedule', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        ),
        TodayChoresLoaded(todayChoresFixture()),
      ],
      rescheduleResults: const <RescheduleChoreOccurrenceResult>[
        RescheduleChoreOccurrenceFailed(
          ChoreFailure(ChoreFailureKind.staleVersion),
        ),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.rescheduleOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
      dueLocalTime: null,
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.today.occurrences, isEmpty);
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
  });

  test('rejects no-op, one-time, and completed reschedules locally', () async {
    final ChoreLocalTime currentTime = ChoreLocalTime.tryParse('19:30')!;
    final List<({ChoreOccurrence occurrence, ChoreLocalTime? targetTime})>
    cases = <({ChoreOccurrence occurrence, ChoreLocalTime? targetTime})>[
      (
        occurrence: choreOccurrenceFixture(
          dueLocalTime: currentTime,
          recurrenceFrequency: ChoreRecurrenceFrequency.daily,
        ),
        targetTime: currentTime,
      ),
      (occurrence: choreOccurrenceFixture(), targetTime: currentTime),
      (
        occurrence: choreOccurrenceFixture(
          status: ChoreOccurrenceStatus.completed,
          recurrenceFrequency: ChoreRecurrenceFrequency.daily,
        ),
        targetTime: currentTime,
      ),
    ];

    for (final testCase in cases) {
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[testCase.occurrence],
        ),
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);

      await controller.rescheduleOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: testCase.occurrence.id,
        dueLocalDate: todayChoresFixture().localDate,
        dueLocalTime: testCase.targetTime,
      );

      expect(repository.rescheduleRequests, isEmpty);
      expect(generator.generateCount, 0);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.invalidTransition,
      );
    }
  });

  test('optimistically reassigns and coalesces duplicate saves', () async {
    final Completer<ReassignChoreOccurrenceResult> response =
        Completer<ReassignChoreOccurrenceResult>();
    addTearDown(() {
      if (!response.isCompleted) {
        response.complete(
          const ReassignChoreOccurrenceFailed(
            ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
    });
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      reassignmentCallback: (_) => response.future,
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    final Future<void> first = controller.reassignOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
    );
    final Future<void> duplicate = controller.reassignOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
    );

    expect(identical(first, duplicate), isTrue);
    expect(repository.reassignmentRequests, hasLength(1));
    expect(repository.reassignmentRequests.single.expectedVersion, 1);
    expect(
      repository.reassignmentRequests.single.assigneeMemberId,
      _otherMemberId(),
    );
    expect(generator.generateCount, 1);
    final TodayChoresReady optimistic = controller.state as TodayChoresReady;
    expect(optimistic.pendingOccurrenceId, occurrence.id);
    expect(
      optimistic.today.occurrences.single.assigneeMemberId,
      _otherMemberId(),
    );
    expect(optimistic.today.occurrences.single.assigneeDisplayName, 'Sam');
    expect(optimistic.today.occurrences.single.version, 1);

    response.complete(
      ChoreOccurrenceReassigned(
        _reassignmentSnapshot(
          repository.reassignmentRequests.single,
          displayName: 'Samuel',
        ),
      ),
    );
    await first;

    final TodayChoresReady reconciled = controller.state as TodayChoresReady;
    expect(reconciled.pendingOccurrenceId, isNull);
    expect(reconciled.actionFailure, isNull);
    expect(
      reconciled.today.occurrences.single.assigneeMemberId,
      _otherMemberId(),
    );
    expect(reconciled.today.occurrences.single.assigneeDisplayName, 'Samuel');
    expect(reconciled.today.occurrences.single.version, 2);
  });

  test('rolls back reassignment failure and reuses the command ID', () async {
    var attempts = 0;
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      reassignmentCallback: (ReassignChoreOccurrenceRequest request) async {
        attempts += 1;
        return attempts == 1
            ? const ReassignChoreOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : ChoreOccurrenceReassigned(_reassignmentSnapshot(request));
      },
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.reassignOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
    );
    final TodayChoresReady rolledBack = controller.state as TodayChoresReady;
    expect(
      rolledBack.today.occurrences.single.assigneeMemberId,
      occurrence.assigneeMemberId,
    );
    expect(rolledBack.today.occurrences.single.assigneeDisplayName, 'Alex');
    expect(
      rolledBack.actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );

    await controller.reassignOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
    );

    expect(repository.reassignmentRequests, hasLength(2));
    expect(
      repository.reassignmentRequests.first.idempotencyKey,
      repository.reassignmentRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(ready.actionFailure, isNull);
    expect(ready.today.occurrences.single.assigneeMemberId, _otherMemberId());
    expect(ready.today.occurrences.single.version, 2);
  });

  test('reloads authoritative Today after a stale reassignment', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.monthly,
    );
    final ChoreOccurrence authoritative = occurrence.reassigned(
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
      version: 2,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[authoritative]),
        ),
      ],
      reassignmentResults: const <ReassignChoreOccurrenceResult>[
        ReassignChoreOccurrenceFailed(
          ChoreFailure(ChoreFailureKind.staleVersion),
        ),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.reassignOccurrence(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
      assigneeMemberId: _otherMemberId(),
      assigneeDisplayName: 'Sam',
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.today.occurrences.single.assigneeMemberId, _otherMemberId());
    expect(ready.today.occurrences.single.version, 2);
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
  });

  test(
    'rejects no-op, one-time, completed, and malformed reassignments',
    () async {
      final List<({ChoreOccurrence occurrence, HouseholdMemberId target})>
      cases = <({ChoreOccurrence occurrence, HouseholdMemberId target})>[
        (
          occurrence: choreOccurrenceFixture(
            recurrenceFrequency: ChoreRecurrenceFrequency.daily,
          ),
          target: activeHouseholdFixture().memberId,
        ),
        (occurrence: choreOccurrenceFixture(), target: _otherMemberId()),
        (
          occurrence: choreOccurrenceFixture(
            status: ChoreOccurrenceStatus.completed,
            recurrenceFrequency: ChoreRecurrenceFrequency.daily,
          ),
          target: _otherMemberId(),
        ),
      ];

      for (final testCase in cases) {
        final FakeChoreRepository repository = FakeChoreRepository(
          today: todayChoresFixture(
            occurrences: <ChoreOccurrence>[testCase.occurrence],
          ),
        );
        final FakeChoreCommandIdGenerator generator =
            FakeChoreCommandIdGenerator();
        final TodayChoresController controller = TodayChoresController(
          repository: repository,
          idGenerator: generator,
        );
        addTearDown(controller.dispose);
        await controller.load(activeHouseholdFixture().householdId);

        await controller.reassignOccurrence(
          householdId: activeHouseholdFixture().householdId,
          occurrenceId: testCase.occurrence.id,
          assigneeMemberId: testCase.target,
          assigneeDisplayName: 'Sam',
        );

        expect(repository.reassignmentRequests, isEmpty);
        expect(generator.generateCount, 0);
        expect(
          (controller.state as TodayChoresReady).actionFailure?.kind,
          ChoreFailureKind.invalidTransition,
        );
      }

      final ChoreOccurrence recurring = choreOccurrenceFixture(
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[recurring]),
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      await controller.reassignOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: recurring.id,
        assigneeMemberId: _otherMemberId(),
        assigneeDisplayName: ' Sam ',
      );
      expect(repository.reassignmentRequests, isEmpty);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.invalidInput,
      );
    },
  );
}

ChoreCompletionSnapshot _snapshot(SetChoreCompletionRequest request) {
  return ChoreCompletionSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    status: request.completed
        ? ChoreOccurrenceStatus.completed
        : ChoreOccurrenceStatus.scheduled,
    version: request.expectedVersion + 1,
    completedByMemberId: request.completed
        ? activeHouseholdFixture().memberId
        : null,
    completedAt: request.completed
        ? DateTime.parse('2026-08-06T10:30:00Z')
        : null,
    changed: true,
  );
}

ChoreOccurrenceSkipSnapshot _skipSnapshot(SkipChoreOccurrenceRequest request) {
  return ChoreOccurrenceSkipSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    version: request.expectedVersion + 1,
    changed: true,
  );
}

ChoreOccurrenceRestoreSnapshot _restoreSnapshot(
  RestoreSkippedChoreOccurrenceRequest request,
) {
  return ChoreOccurrenceRestoreSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    version: request.expectedVersion + 1,
    changed: true,
  );
}

ChoreOccurrenceRescheduleSnapshot _rescheduleSnapshot(
  RescheduleChoreOccurrenceRequest request, {
  DateTime? dueAt,
}) {
  return ChoreOccurrenceRescheduleSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    dueLocalDate: request.dueLocalDate,
    dueLocalTime: request.dueLocalTime,
    dueAt: request.dueLocalTime == null
        ? null
        : dueAt ?? DateTime.parse('2026-08-06T09:30:00Z'),
    version: request.expectedVersion + 1,
    changed: true,
  );
}

HouseholdMemberId _otherMemberId() {
  return HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333334')!;
}

ChoreOccurrenceReassignmentSnapshot _reassignmentSnapshot(
  ReassignChoreOccurrenceRequest request, {
  String displayName = 'Sam',
}) {
  return ChoreOccurrenceReassignmentSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    assigneeMemberId: request.assigneeMemberId,
    assigneeDisplayName: displayName,
    version: request.expectedVersion + 1,
    changed: true,
  );
}
