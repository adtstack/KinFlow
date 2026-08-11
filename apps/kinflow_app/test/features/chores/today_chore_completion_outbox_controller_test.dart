import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  final HouseholdId householdId = activeHouseholdFixture().householdId;
  final HouseholdMemberId actorMemberId = activeHouseholdFixture().memberId;
  final DateTime now = DateTime.parse('2026-08-09T03:00:00.000Z');
  final ReadCacheMetadata cacheMetadata = ReadCacheMetadata(
    validatedAt: now.subtract(const Duration(minutes: 5)),
    expiresAt: now.add(const Duration(minutes: 20)),
  );

  test(
    'writes cached completion before presenting the optimistic state',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final Completer<void> writeGate = Completer<void>();
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
        now: now,
        enqueueGate: writeGate,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
            cacheMetadata: cacheMetadata,
          ),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        _request(householdId),
        actorMemberId: actorMemberId,
      );

      final Future<void> action = controller.setCompleted(
        householdId: householdId,
        occurrenceId: occurrence.id,
        completed: true,
      );

      final TodayChoresReady writing = controller.state as TodayChoresReady;
      expect(writing.pendingOccurrenceId, occurrence.id);
      expect(
        writing.today.occurrences.single.status,
        ChoreOccurrenceStatus.scheduled,
      );
      expect(repository.completionRequests, isEmpty);

      writeGate.complete();
      await action;

      final TodayChoresReady queued = controller.state as TodayChoresReady;
      expect(queued.pendingOccurrenceId, isNull);
      expect(
        queued.today.occurrences.single.status,
        ChoreOccurrenceStatus.completed,
      );
      expect(queued.completionSync?.kind, TodayChoreCompletionSyncKind.queued);
      expect(outbox.item?.occurrenceId, occurrence.id);
      expect(outbox.item?.actorMemberId, actorMemberId);
      expect(outbox.enqueueCount, 1);
    },
  );

  test('keeps reopen and unauthorized cached completion read-only', () async {
    for (final ChoreOccurrence occurrence in <ChoreOccurrence>[
      choreOccurrenceFixture(
        status: ChoreOccurrenceStatus.completed,
        version: 2,
      ),
      choreOccurrenceFixture(canSetCompletion: false),
    ]) {
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(now: now);
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
            cacheMetadata: cacheMetadata,
          ),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        _request(householdId),
        actorMemberId: actorMemberId,
      );

      await controller.setCompleted(
        householdId: householdId,
        occurrenceId: occurrence.id,
        completed: occurrence.status != ChoreOccurrenceStatus.completed,
      );

      expect(outbox.enqueueCount, 0);
      expect(repository.completionRequests, isEmpty);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.offlineReadOnly,
      );
    }
  });

  test(
    'fails closed when encrypted outbox composition is unavailable',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
        now: now,
        available: false,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
            cacheMetadata: cacheMetadata,
          ),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        _request(householdId),
        actorMemberId: actorMemberId,
      );

      await controller.setCompleted(
        householdId: householdId,
        occurrenceId: occurrence.id,
        completed: true,
      );

      expect(outbox.enqueueCount, 0);
      expect(repository.completionRequests, isEmpty);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.offlineReadOnly,
      );
    },
  );

  test('does not reuse an actor omitted by a later cached load', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(now: now);
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
          cacheMetadata: cacheMetadata,
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
          cacheMetadata: cacheMetadata,
        ),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
      completionOutbox: outbox,
    );
    addTearDown(controller.dispose);
    await controller.loadQuery(
      _request(householdId),
      actorMemberId: actorMemberId,
    );
    await controller.loadQuery(_request(householdId));

    await controller.setCompleted(
      householdId: householdId,
      occurrenceId: occurrence.id,
      completed: true,
    );

    expect(outbox.enqueueCount, 0);
    expect(repository.completionRequests, isEmpty);
    expect(
      (controller.state as TodayChoresReady).actionFailure?.kind,
      ChoreFailureKind.offlineReadOnly,
    );
  });

  test(
    'queues an online transient completion with the original command ID',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(now: now);
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        completionResults: const <SetChoreCompletionResult>[
          SetChoreCompletionFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        _request(householdId),
        actorMemberId: actorMemberId,
      );

      await controller.setCompleted(
        householdId: householdId,
        occurrenceId: occurrence.id,
        completed: true,
      );

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(
        outbox.item?.idempotencyKey,
        repository.completionRequests.single.idempotencyKey,
      );
      expect(ready.actionFailure, isNull);
      expect(
        ready.today.occurrences.single.status,
        ChoreOccurrenceStatus.completed,
      );
      expect(ready.completionSync?.kind, TodayChoreCompletionSyncKind.queued);
    },
  );

  test('revalidates target and replays the exact durable request', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final PendingChoreCompletion pending = _pending(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrence.id,
      now: now,
    );
    final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
      now: now,
      item: pending,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
      completionOutbox: outbox,
      clock: () => now,
    );
    addTearDown(controller.dispose);

    await controller.prepareCompletionOutbox(
      householdId: householdId,
      actorMemberId: actorMemberId,
      allowReplay: true,
    );

    expect(repository.occurrenceTargetRequests, hasLength(1));
    expect(repository.completionRequests, hasLength(1));
    expect(
      repository.completionRequests.single.idempotencyKey,
      pending.idempotencyKey,
    );
    expect(
      repository.completionRequests.single.expectedVersion,
      pending.expectedVersion,
    );
    expect(outbox.markAttemptCount, 1);
    expect(outbox.item, isNull);

    await controller.loadQuery(
      _request(householdId),
      actorMemberId: actorMemberId,
    );
    expect(
      (controller.state as TodayChoresReady).completionSync?.kind,
      TodayChoreCompletionSyncKind.reconciled,
    );
  });

  test(
    'reconciles an already-applied response-loss completion without mutation',
    () async {
      final ChoreOccurrence completed = choreOccurrenceFixture(
        status: ChoreOccurrenceStatus.completed,
        version: 2,
      );
      final PendingChoreCompletion pending = _pending(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: completed.id,
        now: now,
      );
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
        now: now,
        item: pending,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(completed),
        ],
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
      );
      addTearDown(controller.dispose);

      await controller.prepareCompletionOutbox(
        householdId: householdId,
        actorMemberId: actorMemberId,
        allowReplay: true,
      );

      expect(repository.completionRequests, isEmpty);
      expect(outbox.clearCount, 1);
      expect(outbox.item, isNull);
    },
  );

  test('bounds transient replay at three persisted attempts', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
      now: now,
      item: _pending(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrence.id,
        now: now,
      ),
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetCallback: (_, _) async =>
          const LoadChoreOccurrenceTargetFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
      completionOutbox: outbox,
    );
    addTearDown(controller.dispose);

    for (var run = 0; run < 4; run += 1) {
      await controller.prepareCompletionOutbox(
        householdId: householdId,
        actorMemberId: actorMemberId,
        allowReplay: true,
      );
    }

    expect(outbox.markAttemptCount, 3);
    expect(repository.occurrenceTargetRequests, hasLength(3));
    expect(outbox.item?.attemptCount, 3);
    await controller.loadQuery(
      _request(householdId),
      actorMemberId: actorMemberId,
    );
    expect(
      (controller.state as TodayChoresReady).completionSync?.kind,
      TodayChoreCompletionSyncKind.needsAttention,
    );
  });

  test('pauses replay under runtime policy and discards explicitly', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
      now: now,
      item: _pending(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrence.id,
        now: now,
      ),
    );
    final FakeChoreRepository repository = FakeChoreRepository();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
      completionOutbox: outbox,
    );
    addTearDown(controller.dispose);

    await controller.prepareCompletionOutbox(
      householdId: householdId,
      actorMemberId: actorMemberId,
      allowReplay: false,
    );
    await controller.loadQuery(
      _request(householdId),
      actorMemberId: actorMemberId,
    );

    expect(repository.occurrenceTargetRequests, isEmpty);
    expect(outbox.markAttemptCount, 0);
    expect(
      (controller.state as TodayChoresReady).completionSync?.kind,
      TodayChoreCompletionSyncKind.paused,
    );
    expect(await controller.discardCompletionOutbox(), isTrue);
    expect(outbox.item, isNull);
  });

  test('clears terminal authorization changes without replaying', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
      now: now,
      item: _pending(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrence.id,
        now: now,
      ),
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: const <LoadChoreOccurrenceTargetResult>[
        LoadChoreOccurrenceTargetFailed(
          ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
        ),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
      completionOutbox: outbox,
    );
    addTearDown(controller.dispose);

    await controller.prepareCompletionOutbox(
      householdId: householdId,
      actorMemberId: actorMemberId,
      allowReplay: true,
    );
    await controller.loadQuery(
      _request(householdId),
      actorMemberId: actorMemberId,
    );

    expect(repository.completionRequests, isEmpty);
    expect(outbox.item, isNull);
    expect(
      (controller.state as TodayChoresReady).completionSync?.kind,
      TodayChoreCompletionSyncKind.discarded,
    );
  });

  test(
    'terminal clear failure durably exhausts replay and shows server state',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(
        now: now,
        item: _pending(
          householdId: householdId,
          actorMemberId: actorMemberId,
          occurrenceId: occurrence.id,
          now: now,
        ),
        clearSucceeds: false,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        occurrenceTargetCallback: (_, _) async =>
            const LoadChoreOccurrenceTargetFailed(
              ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
            ),
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
      );
      addTearDown(controller.dispose);

      await controller.prepareCompletionOutbox(
        householdId: householdId,
        actorMemberId: actorMemberId,
        allowReplay: true,
      );
      await controller.prepareCompletionOutbox(
        householdId: householdId,
        actorMemberId: actorMemberId,
        allowReplay: true,
      );
      await controller.loadQuery(
        _request(householdId),
        actorMemberId: actorMemberId,
      );

      expect(repository.occurrenceTargetRequests, hasLength(1));
      expect(repository.completionRequests, isEmpty);
      expect(outbox.clearCount, 1);
      expect(outbox.exhaustCount, 1);
      expect(outbox.item?.attemptCount, 3);
      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(
        ready.today.occurrences.single.status,
        ChoreOccurrenceStatus.scheduled,
      );
      expect(
        ready.completionSync?.kind,
        TodayChoreCompletionSyncKind.needsAttention,
      );
    },
  );

  test(
    'shared replay clears stale queued state from the overdue controller',
    () async {
      final ChoreOccurrence overdueOccurrence = choreOccurrenceFixture(
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-05'),
      );
      final _MemoryCompletionOutbox outbox = _MemoryCompletionOutbox(now: now);
      final FakeChoreRepository overdueRepository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[overdueOccurrence],
              view: ChoreListView.overdue,
            ),
            cacheMetadata: cacheMetadata,
          ),
          TodayChoresLoaded(todayChoresFixture(view: ChoreListView.overdue)),
        ],
      );
      final TodayChoresController overdueController = TodayChoresController(
        repository: overdueRepository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
        clock: () => now,
      );
      addTearDown(overdueController.dispose);
      final ChoreListRequest overdueRequest = ChoreListRequest.tryCreate(
        householdId: householdId,
        view: ChoreListView.overdue,
      )!;
      await overdueController.loadQuery(
        overdueRequest,
        actorMemberId: actorMemberId,
      );
      await overdueController.setCompleted(
        householdId: householdId,
        occurrenceId: overdueOccurrence.id,
        completed: true,
      );
      expect(
        (overdueController.state as TodayChoresReady).completionSync?.kind,
        TodayChoreCompletionSyncKind.queued,
      );

      final FakeChoreRepository primaryRepository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[overdueOccurrence],
        ),
      );
      final TodayChoresController primaryController = TodayChoresController(
        repository: primaryRepository,
        idGenerator: FakeChoreCommandIdGenerator(),
        completionOutbox: outbox,
        clock: () => now,
      );
      addTearDown(primaryController.dispose);
      await primaryController.prepareCompletionOutbox(
        householdId: householdId,
        actorMemberId: actorMemberId,
        allowReplay: true,
      );
      expect(outbox.item, isNull);

      await overdueController.refresh();

      final TodayChoresReady refreshed =
          overdueController.state as TodayChoresReady;
      expect(refreshed.today.occurrences, isEmpty);
      expect(refreshed.completionSync, isNull);
    },
  );
}

ChoreListRequest _request(HouseholdId householdId) {
  return ChoreListRequest.tryCreate(householdId: householdId)!;
}

PendingChoreCompletion _pending({
  required HouseholdId householdId,
  required HouseholdMemberId actorMemberId,
  required ChoreOccurrenceId occurrenceId,
  required DateTime now,
}) {
  return PendingChoreCompletion.tryCreate(
    householdId: householdId,
    actorMemberId: actorMemberId,
    occurrenceId: occurrenceId,
    expectedVersion: 1,
    idempotencyKey: ChoreCommandId.tryParse(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    )!,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 30)),
    attemptCount: 0,
  )!;
}

final class _MemoryCompletionOutbox implements ChoreCompletionOutbox {
  _MemoryCompletionOutbox({
    required this.now,
    this.item,
    this.enqueueGate,
    this.available = true,
    this.clearSucceeds = true,
  });

  final DateTime now;
  final Completer<void>? enqueueGate;
  final bool available;
  final bool clearSucceeds;
  PendingChoreCompletion? item;
  var enqueueCount = 0;
  var markAttemptCount = 0;
  var exhaustCount = 0;
  var clearCount = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<PendingChoreCompletion?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  }) async {
    final PendingChoreCompletion? current = item;
    if (current == null ||
        current.householdId != expectedHouseholdId ||
        current.actorMemberId != expectedActorMemberId) {
      item = null;
      return null;
    }
    return current;
  }

  @override
  Future<ChoreCompletionOutboxEnqueueResult> enqueue({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
  }) async {
    enqueueCount += 1;
    if (!available) {
      return const ChoreCompletionOutboxUnavailable();
    }
    final PendingChoreCompletion? current = item;
    if (current != null) {
      return current.occurrenceId == occurrenceId &&
              current.expectedVersion == expectedVersion &&
              current.idempotencyKey == idempotencyKey
          ? ChoreCompletionOutboxEnqueued(current, created: false)
          : ChoreCompletionOutboxOccupied(current);
    }
    final PendingChoreCompletion created = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      attemptCount: 0,
    )!;
    if (enqueueGate != null) {
      await enqueueGate!.future;
    }
    item = created;
    return ChoreCompletionOutboxEnqueued(created, created: true);
  }

  @override
  Future<PendingChoreCompletion?> markNextAttempt(
    PendingChoreCompletion expected,
  ) async {
    final PendingChoreCompletion? current = item;
    if (current != expected) {
      return null;
    }
    final PendingChoreCompletion? next = current?.nextAttempt();
    if (next == null) {
      return null;
    }
    markAttemptCount += 1;
    item = next;
    return next;
  }

  @override
  Future<PendingChoreCompletion?> exhaustAutomaticAttempts(
    PendingChoreCompletion expected,
  ) async {
    if (item != expected) {
      return null;
    }
    exhaustCount += 1;
    final PendingChoreCompletion exhausted = expected
        .exhaustAutomaticAttempts();
    item = exhausted;
    return exhausted;
  }

  @override
  Future<bool> clear() async {
    clearCount += 1;
    if (clearSucceeds) {
      item = null;
    }
    return clearSucceeds;
  }
}
