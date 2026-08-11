import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test(
    'refresh preserves the last successful filtered page as stale',
    () async {
      var callCount = 0;
      final ChoreOccurrence upcoming = choreOccurrenceFixture(
        dueLocalDate: _date('2026-08-07'),
      );
      final ChoreListRequest request = ChoreListRequest.tryCreate(
        householdId: activeHouseholdFixture().householdId,
        view: ChoreListView.upcoming,
      )!;
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (_) async {
          callCount += 1;
          return callCount == 1
              ? TodayChoresLoaded(
                  todayChoresFixture(
                    occurrences: <ChoreOccurrence>[upcoming],
                    view: ChoreListView.upcoming,
                    generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
                  ),
                )
              : const LoadTodayChoresFailed(
                  ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
                );
        },
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      final List<TodayChoresState> emitted = <TodayChoresState>[];
      final StreamSubscription<TodayChoresState> subscription = controller
          .states
          .listen(emitted.add);
      addTearDown(subscription.cancel);

      await controller.loadQuery(request);
      await controller.refresh();

      final TodayChoresReady state = controller.state as TodayChoresReady;
      expect(state.today.occurrences.single, same(upcoming));
      expect(
        state.refreshFailure?.kind,
        ChoreFailureKind.temporarilyUnavailable,
      );
      expect(state.today.generatedAt, DateTime.parse('2026-08-06T10:30:00Z'));
      expect(
        emitted.whereType<TodayChoresReady>().any(
          (TodayChoresReady state) => state.refreshing,
        ),
        isTrue,
      );
      expect(repository.listRequests, hasLength(2));
      expect(repository.listRequests.last.cursor, isNull);
    },
  );

  test(
    'load more coalesces calls and merges one strict continuation',
    () async {
      final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
      final ChoreOccurrence first = choreOccurrenceFixture(
        occurrenceId: '55555555-5555-4555-8555-555555555551',
        dueLocalDate: _date('2026-08-07'),
      );
      final ChoreOccurrence second = choreOccurrenceFixture(
        occurrenceId: '55555555-5555-4555-8555-555555555552',
        dueLocalDate: _date('2026-08-08'),
      );
      final Completer<LoadTodayChoresResult> continuation =
          Completer<LoadTodayChoresResult>();
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) {
          return request.cursor == null
              ? Future<LoadTodayChoresResult>.value(
                  TodayChoresLoaded(
                    todayChoresFixture(
                      occurrences: <ChoreOccurrence>[first],
                      view: ChoreListView.upcoming,
                      generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
                      pageLimit: 1,
                      hasMore: true,
                      nextCursor: cursor,
                    ),
                  ),
                )
              : continuation.future;
        },
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      final ChoreListRequest request = ChoreListRequest.tryCreate(
        householdId: activeHouseholdFixture().householdId,
        view: ChoreListView.upcoming,
        limit: 1,
      )!;
      await controller.loadQuery(request);

      final Future<void> firstLoadMore = controller.loadMore();
      final Future<void> duplicateLoadMore = controller.loadMore();

      expect(identical(firstLoadMore, duplicateLoadMore), isTrue);
      expect((controller.state as TodayChoresReady).loadingMore, isTrue);
      expect(repository.listRequests, hasLength(2));
      expect(repository.listRequests.last.cursor, cursor);

      continuation.complete(
        TodayChoresLoaded(
          todayChoresFixture(
            occurrences: <ChoreOccurrence>[second],
            view: ChoreListView.upcoming,
            generatedAt: DateTime.parse('2026-08-06T10:31:00Z'),
            pageLimit: 1,
          ),
        ),
      );
      await firstLoadMore;

      final TodayChoresReady state = controller.state as TodayChoresReady;
      expect(state.today.occurrences, <ChoreOccurrence>[first, second]);
      expect(state.today.hasMore, isFalse);
      expect(state.loadingMore, isFalse);
      expect(state.loadMoreFailure, isNull);
    },
  );

  test(
    'continuation failure preserves rows and retries the same cursor',
    () async {
      final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
      final ChoreOccurrence first = choreOccurrenceFixture(
        dueLocalDate: _date('2026-08-07'),
      );
      var continuationCalls = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async {
          if (request.cursor == null) {
            return TodayChoresLoaded(
              todayChoresFixture(
                occurrences: <ChoreOccurrence>[first],
                view: ChoreListView.upcoming,
                pageLimit: 1,
                hasMore: true,
                nextCursor: cursor,
              ),
            );
          }
          continuationCalls += 1;
          return const LoadTodayChoresFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          );
        },
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
          limit: 1,
        )!,
      );

      await controller.loadMore();
      await controller.loadMore();

      final TodayChoresReady state = controller.state as TodayChoresReady;
      expect(state.today.occurrences, <ChoreOccurrence>[first]);
      expect(
        state.loadMoreFailure?.kind,
        ChoreFailureKind.temporarilyUnavailable,
      );
      expect(continuationCalls, 2);
      expect(repository.listRequests[1].cursor, cursor);
      expect(repository.listRequests[2].cursor, cursor);
    },
  );

  test(
    'optimistic completion removes work that leaves the selected view',
    () async {
      final ChoreOccurrence upcoming = choreOccurrenceFixture(
        dueLocalDate: _date('2026-08-07'),
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[upcoming],
          view: ChoreListView.upcoming,
        ),
        completionCallback: (SetChoreCompletionRequest request) async {
          return ChoreCompletionSet(
            ChoreCompletionSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              status: ChoreOccurrenceStatus.completed,
              version: request.expectedVersion + 1,
              completedByMemberId: activeHouseholdFixture().memberId,
              completedAt: DateTime.parse('2026-08-06T10:30:00Z'),
              changed: true,
            ),
          );
        },
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      await controller.setCompleted(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: upcoming.id,
        completed: true,
      );

      expect((controller.state as TodayChoresReady).today.occurrences, isEmpty);
      expect(repository.completionRequests, hasLength(1));
    },
  );

  test(
    'one-time update coalesces and replaces state from authoritative reload',
    () async {
      final original = choreOccurrenceFixture(
        description: 'Blue bin',
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
        version: 7,
        seriesVersion: 4,
      );
      final otherMember = activeHouseholdFixture(
        memberId: '33333333-3333-4333-8333-333333333334',
      ).memberId;
      final updated = choreOccurrenceFixture(
        title: 'Updated recycling',
        description: 'Use the blue bin',
        assigneeMemberId: otherMember,
        assigneeDisplayName: 'Sam',
        dueLocalTime: ChoreLocalTime.tryParse('18:30'),
        dueAt: DateTime.parse('2026-08-06T09:30:00Z'),
        version: 8,
        seriesVersion: 5,
      );
      final Completer<UpdateOneTimeChoreResult> command =
          Completer<UpdateOneTimeChoreResult>();
      var loads = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (_) async {
          loads += 1;
          return TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[loads == 1 ? original : updated],
            ),
          );
        },
        oneTimeUpdateCallback: (_) => command.future,
      );
      final FakeChoreCommandIdGenerator idGenerator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: idGenerator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);

      final Future<void> first = controller.updateOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: original.id,
        title: '  Updated recycling  ',
        description: '  Use the blue bin  ',
        assigneeMemberId: otherMember,
        dueLocalDate: original.dueLocalDate,
        dueLocalTime: ChoreLocalTime.tryParse('18:30'),
      );
      final Future<void> duplicate = controller.updateOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: original.id,
        title: 'Updated recycling',
        description: 'Use the blue bin',
        assigneeMemberId: otherMember,
        dueLocalDate: original.dueLocalDate,
        dueLocalTime: ChoreLocalTime.tryParse('18:30'),
      );

      expect(identical(first, duplicate), isTrue);
      expect(
        (controller.state as TodayChoresReady).pendingOccurrenceId,
        original.id,
      );
      expect(repository.oneTimeUpdateRequests, hasLength(1));
      final UpdateOneTimeChoreRequest request =
          repository.oneTimeUpdateRequests.single;
      expect(request.expectedSeriesVersion, 4);
      expect(request.expectedOccurrenceVersion, 7);
      expect(request.title, 'Updated recycling');
      expect(request.description, 'Use the blue bin');
      expect(request.assigneeMemberId, otherMember);
      expect(request.dueLocalTime?.value, '18:30');
      expect(idGenerator.generateCount, 1);

      command.complete(
        OneTimeChoreUpdated(
          OneTimeChoreUpdateSnapshot(
            householdId: request.householdId,
            seriesId: request.seriesId,
            occurrenceId: request.occurrenceId,
            revisionId: ChoreRevisionId.tryParse(
              '77777777-7777-4777-8777-777777777777',
            )!,
            revisionNumber: 5,
            dueLocalDate: request.dueLocalDate,
            dueLocalTime: request.dueLocalTime,
            dueAt: DateTime.parse('2026-08-06T09:30:00Z'),
            assigneeMemberId: request.assigneeMemberId,
            seriesVersion: 5,
            occurrenceVersion: 8,
            changed: true,
          ),
        ),
      );
      await first;

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(ready.today.occurrences.single, same(updated));
      expect(ready.pendingOccurrenceId, isNull);
      expect(ready.actionFailure, isNull);
      expect(repository.listRequests, hasLength(2));
    },
  );

  test('one-time deletion reloads the current query without the row', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      version: 7,
      seriesVersion: 4,
    );
    var loads = 0;
    final FakeChoreRepository repository = FakeChoreRepository(
      listCallback: (_) async {
        loads += 1;
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: loads == 1
                ? <ChoreOccurrence>[occurrence]
                : const <ChoreOccurrence>[],
          ),
        );
      },
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.deleteOneTimeChore(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
    );

    final DeleteOneTimeChoreRequest request =
        repository.oneTimeDeletionRequests.single;
    expect(request.seriesId, occurrence.seriesId);
    expect(request.expectedSeriesVersion, 4);
    expect(request.expectedOccurrenceVersion, 7);
    expect((controller.state as TodayChoresReady).today.occurrences, isEmpty);
    expect(repository.listRequests, hasLength(2));
  });

  test(
    'immediate one-time deletion undo restores and reloads authority',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        version: 7,
        seriesVersion: 4,
      );
      final ChoreOccurrence restored = choreOccurrenceFixture(
        occurrenceId: occurrence.id.value,
        seriesId: occurrence.seriesId.value,
        version: 9,
        seriesVersion: 6,
      );
      var loads = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (_) async {
          loads += 1;
          return TodayChoresLoaded(
            todayChoresFixture(
              occurrences: switch (loads) {
                1 => <ChoreOccurrence>[occurrence],
                2 => const <ChoreOccurrence>[],
                _ => <ChoreOccurrence>[restored],
              },
            ),
          );
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
      await controller.deleteOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(ready.undoableDeletion?.occurrence, same(occurrence));
      expect(ready.undoableDeletion?.deletedSeriesVersion, 5);
      expect(ready.undoableDeletion?.deletedOccurrenceVersion, 8);

      await controller.undoDeleteOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      ready = controller.state as TodayChoresReady;
      expect(ready.undoableDeletion, isNull);
      expect(ready.restoredDeletionOccurrenceId, occurrence.id);
      expect(ready.today.occurrences.single, same(restored));
      expect(repository.oneTimeRestoreRequests, hasLength(1));
      final RestoreOneTimeChoreRequest request =
          repository.oneTimeRestoreRequests.single;
      expect(request.expectedSeriesVersion, 5);
      expect(request.expectedOccurrenceVersion, 8);
      expect(repository.listRequests, hasLength(3));
      expect(generator.generateCount, 2);
    },
  );

  test('dismissal clears only the matching deletion undo receipt', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    var loads = 0;
    final FakeChoreRepository repository = FakeChoreRepository(
      listCallback: (_) async {
        loads += 1;
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: loads == 1
                ? <ChoreOccurrence>[occurrence]
                : const <ChoreOccurrence>[],
          ),
        );
      },
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);
    await controller.deleteOneTimeChore(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: occurrence.id,
    );

    controller.dismissDeleteOneTimeChoreUndo(
      ChoreOccurrenceId.tryParse('55555555-5555-4555-8555-555555555599')!,
    );
    expect((controller.state as TodayChoresReady).undoableDeletion, isNotNull);
    controller.dismissDeleteOneTimeChoreUndo(occurrence.id);

    expect((controller.state as TodayChoresReady).undoableDeletion, isNull);
    expect(repository.oneTimeRestoreRequests, isEmpty);
  });

  test('stale one-time update reconciles before exposing failure', () async {
    final ChoreOccurrence original = choreOccurrenceFixture();
    final ChoreOccurrence concurrent = choreOccurrenceFixture(
      title: 'Changed elsewhere',
      version: 2,
      seriesVersion: 2,
    );
    var loads = 0;
    final FakeChoreRepository repository = FakeChoreRepository(
      listCallback: (_) async {
        loads += 1;
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: <ChoreOccurrence>[loads == 1 ? original : concurrent],
          ),
        );
      },
      oneTimeUpdateResults: const <UpdateOneTimeChoreResult>[
        UpdateOneTimeChoreFailed(ChoreFailure(ChoreFailureKind.staleVersion)),
      ],
    );
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    await controller.updateOneTimeChore(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
      title: 'My update',
      description: '',
      assigneeMemberId: original.assigneeMemberId,
      dueLocalDate: original.dueLocalDate,
      dueLocalTime: original.dueLocalTime,
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(ready.today.occurrences.single, same(concurrent));
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
    expect(repository.listRequests, hasLength(2));
  });

  test(
    'cached pages are read-only and never dispatch mutations or pagination',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        dueLocalDate: _date('2026-08-07'),
      );
      final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
      final ReadCacheMetadata metadata = ReadCacheMetadata(
        validatedAt: DateTime.parse('2026-08-06T10:30:00.000Z'),
        expiresAt: DateTime.parse('2026-08-06T12:30:00.000Z'),
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (_) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: <ChoreOccurrence>[occurrence],
            view: ChoreListView.upcoming,
            pageLimit: 1,
            hasMore: true,
            nextCursor: cursor,
          ),
          cacheMetadata: metadata,
        ),
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
          limit: 1,
        )!,
      );

      await controller.loadMore();
      await controller.setCompleted(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        completed: true,
      );
      await controller.updateOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        title: 'Updated recycling',
        description: '',
        assigneeMemberId: occurrence.assigneeMemberId,
        dueLocalDate: occurrence.dueLocalDate,
        dueLocalTime: occurrence.dueLocalTime,
      );
      await controller.deleteOneTimeChore(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
      );

      final TodayChoresReady state = controller.state as TodayChoresReady;
      expect(state.isReadOnlyCache, isTrue);
      expect(state.cacheMetadata, metadata);
      expect(
        state.today.occurrences.single.status,
        ChoreOccurrenceStatus.scheduled,
      );
      expect(state.actionFailure?.kind, ChoreFailureKind.offlineReadOnly);
      expect(repository.listRequests, hasLength(1));
      expect(repository.completionRequests, isEmpty);
      expect(repository.oneTimeUpdateRequests, isEmpty);
      expect(repository.oneTimeDeletionRequests, isEmpty);
    },
  );

  test(
    'a successful refresh leaves read-only mode and re-enables mutations',
    () async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final ReadCacheMetadata metadata = ReadCacheMetadata(
        validatedAt: DateTime.parse('2026-08-06T10:30:00.000Z'),
        expiresAt: DateTime.parse('2026-08-06T12:30:00.000Z'),
      );
      var listCalls = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        listCallback: (_) async {
          listCalls += 1;
          return TodayChoresLoaded(
            todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
            cacheMetadata: listCalls == 1 ? metadata : null,
          );
        },
        completionCallback: (SetChoreCompletionRequest request) async {
          return ChoreCompletionSet(
            ChoreCompletionSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              status: ChoreOccurrenceStatus.completed,
              version: request.expectedVersion + 1,
              completedByMemberId: activeHouseholdFixture().memberId,
              completedAt: DateTime.parse('2026-08-06T10:31:00.000Z'),
              changed: true,
            ),
          );
        },
      );
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      expect((controller.state as TodayChoresReady).isReadOnlyCache, isTrue);

      await controller.refresh();
      expect((controller.state as TodayChoresReady).isReadOnlyCache, isFalse);
      await controller.setCompleted(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        completed: true,
      );

      expect(repository.listRequests, hasLength(2));
      expect(repository.completionRequests, hasLength(1));
      expect(
        (controller.state as TodayChoresReady).today.occurrences.single.status,
        ChoreOccurrenceStatus.completed,
      );
    },
  );
}

ChoreLocalDate _date(String value) {
  return ChoreLocalDate.tryParse(value)!;
}
