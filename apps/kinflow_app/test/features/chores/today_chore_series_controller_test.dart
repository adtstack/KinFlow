import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('coalesces a series update and reloads authoritative Today', () async {
    final Completer<UpdateRepeatingChoreSeriesResult> response =
        Completer<UpdateRepeatingChoreSeriesResult>();
    addTearDown(() {
      if (!response.isCompleted) {
        response.complete(
          const UpdateRepeatingChoreSeriesFailed(
            ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
    });
    final ChoreOccurrence original = _manageableOccurrence();
    final ChoreOccurrence authoritative = _updatedOccurrence(original);
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[original]),
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[authoritative]),
        ),
      ],
      seriesUpdateCallback: (_) => response.future,
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    final ChoreRecurrenceRule targetRule = authoritative.recurrenceRule!;
    final Future<void> first = controller.updateRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
      title: authoritative.title,
      description: authoritative.description!,
      assigneeMemberId: authoritative.seriesDefaultAssigneeMemberId!,
      dueLocalTime: authoritative.seriesDueLocalTime,
      recurrenceRule: targetRule,
    );
    final Future<void> duplicate = controller.updateRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
      title: authoritative.title,
      description: authoritative.description!,
      assigneeMemberId: authoritative.seriesDefaultAssigneeMemberId!,
      dueLocalTime: authoritative.seriesDueLocalTime,
      recurrenceRule: targetRule,
    );

    expect(identical(first, duplicate), isTrue);
    expect(repository.seriesUpdateRequests, hasLength(1));
    expect(generator.generateCount, 1);
    final TodayChoresReady pending = controller.state as TodayChoresReady;
    expect(pending.pendingOccurrenceId, original.id);
    expect(pending.today.occurrences.single.title, original.title);
    final UpdateRepeatingChoreSeriesRequest request =
        repository.seriesUpdateRequests.single;
    expect(request.expectedVersion, 1);
    expect(request.effectiveLocalDate, todayChoresFixture().localDate);

    response.complete(RepeatingChoreSeriesUpdated(_updateSnapshot(request)));
    await first;

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.pendingOccurrenceId, isNull);
    expect(ready.actionFailure, isNull);
    expect(ready.today.occurrences.single.title, authoritative.title);
    expect(ready.today.occurrences.single.seriesVersion, 2);
  });

  test('reuses a series-update command ID after a transient failure', () async {
    var attempts = 0;
    final ChoreOccurrence original = _manageableOccurrence();
    final ChoreOccurrence authoritative = _updatedOccurrence(original);
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[original]),
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[authoritative]),
        ),
      ],
      seriesUpdateCallback: (UpdateRepeatingChoreSeriesRequest request) async {
        attempts += 1;
        return attempts == 1
            ? const UpdateRepeatingChoreSeriesFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : RepeatingChoreSeriesUpdated(_updateSnapshot(request));
      },
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    Future<void> update() => controller.updateRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
      title: authoritative.title,
      description: authoritative.description!,
      assigneeMemberId: authoritative.seriesDefaultAssigneeMemberId!,
      dueLocalTime: authoritative.seriesDueLocalTime,
      recurrenceRule: authoritative.recurrenceRule!,
    );
    await update();
    expect(
      (controller.state as TodayChoresReady).actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );
    await update();

    expect(repository.seriesUpdateRequests, hasLength(2));
    expect(
      repository.seriesUpdateRequests.first.idempotencyKey,
      repository.seriesUpdateRequests.last.idempotencyKey,
    );
    expect(generator.generateCount, 1);
    expect(
      (controller.state as TodayChoresReady)
          .today
          .occurrences
          .single
          .seriesVersion,
      2,
    );
  });

  test(
    'monthly day changes rotate the key and exact retries reuse it',
    () async {
      final ChoreOccurrence original = _manageableOccurrence();
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[original]),
        seriesUpdateResults: const <UpdateRepeatingChoreSeriesResult>[
          UpdateRepeatingChoreSeriesFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          UpdateRepeatingChoreSeriesFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          UpdateRepeatingChoreSeriesFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.load(activeHouseholdFixture().householdId);
      final ChoreLocalDate today = todayChoresFixture().localDate;
      final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.monthly,
        startLocalDate: today,
      );
      final ChoreRecurrenceRule day31 = monthly.tryWithMonthlyDay(
        monthDay: 31,
        interval: 1,
        end: const ChoreRecurrenceNeverEnds(),
        minimumLocalDate: today,
      )!;

      Future<void> update(ChoreRecurrenceRule rule) =>
          controller.updateRepeatingSeries(
            householdId: activeHouseholdFixture().householdId,
            occurrenceId: original.id,
            title: original.title,
            description: original.description ?? '',
            assigneeMemberId: original.seriesDefaultAssigneeMemberId!,
            dueLocalTime: original.seriesDueLocalTime,
            recurrenceRule: rule,
          );
      await update(monthly);
      await update(monthly);
      await update(day31);

      expect(repository.seriesUpdateRequests, hasLength(3));
      expect(
        repository.seriesUpdateRequests[0].idempotencyKey,
        repository.seriesUpdateRequests[1].idempotencyKey,
      );
      expect(
        repository.seriesUpdateRequests[1].idempotencyKey,
        isNot(repository.seriesUpdateRequests[2].idempotencyKey),
      );
      expect(generator.generateCount, 2);
      expect(repository.seriesUpdateRequests.last.recurrenceRule.monthDay, 31);
    },
  );

  test('reloads authoritative Today after a stale series version', () async {
    final ChoreOccurrence original = _manageableOccurrence();
    final ChoreOccurrence authoritative = _updatedOccurrence(original);
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[original]),
        ),
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[authoritative]),
        ),
      ],
      seriesUpdateResults: const <UpdateRepeatingChoreSeriesResult>[
        UpdateRepeatingChoreSeriesFailed(
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

    await controller.updateRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
      title: 'A local edit',
      description: original.description ?? '',
      assigneeMemberId: original.seriesDefaultAssigneeMemberId!,
      dueLocalTime: original.seriesDueLocalTime,
      recurrenceRule: original.recurrenceRule!,
    );

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(repository.loadedHouseholds, hasLength(2));
    expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
    expect(ready.today.occurrences.single.seriesVersion, 2);
  });

  test(
    'coalesces an occurrence-bound update and preserves the Upcoming query',
    () async {
      final Completer<UpdateRepeatingChoreSeriesResult> response =
          Completer<UpdateRepeatingChoreSeriesResult>();
      addTearDown(() {
        if (!response.isCompleted) {
          response.complete(
            const UpdateRepeatingChoreSeriesFailed(
              ChoreFailure(ChoreFailureKind.internal),
            ),
          );
        }
      });
      final ChoreOccurrence original = _manageableUpcomingOccurrence();
      final ChoreOccurrence authoritative = _updatedUpcomingOccurrence(
        original,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[original],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[authoritative],
              view: ChoreListView.upcoming,
            ),
          ),
        ],
        seriesFromOccurrenceUpdateCallback: (_) => response.future,
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      Future<void> update() => controller.updateRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: original.id,
        title: authoritative.title,
        description: authoritative.description!,
        assigneeMemberId: authoritative.seriesDefaultAssigneeMemberId!,
        dueLocalTime: authoritative.seriesDueLocalTime,
        recurrenceRule: authoritative.recurrenceRule!,
      );
      final Future<void> first = update();
      final Future<void> duplicate = update();

      expect(identical(first, duplicate), isTrue);
      expect(repository.seriesFromOccurrenceUpdateRequests, hasLength(1));
      expect(generator.generateCount, 1);
      final UpdateRepeatingChoreSeriesFromOccurrenceRequest request =
          repository.seriesFromOccurrenceUpdateRequests.single;
      expect(request.effectiveOccurrenceId, original.id);
      expect(request.expectedVersion, original.seriesVersion);
      expect(
        (controller.state as TodayChoresReady).pendingOccurrenceId,
        original.id,
      );

      response.complete(
        RepeatingChoreSeriesUpdated(
          _fromOccurrenceUpdateSnapshot(request, original.dueLocalDate),
        ),
      );
      await first;

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(ready.actionFailure, isNull);
      expect(ready.today.view, ChoreListView.upcoming);
      expect(ready.today.occurrences.single.title, authoritative.title);
      expect(ready.today.occurrences.single.seriesVersion, 2);
      expect(repository.listRequests, hasLength(2));
      expect(
        repository.listRequests.every(
          (ChoreListRequest request) => request.view == ChoreListView.upcoming,
        ),
        isTrue,
      );
    },
  );

  test(
    'occurrence-bound retries reuse a key and another target rotates it',
    () async {
      final ChoreOccurrence firstOccurrence = _manageableUpcomingOccurrence();
      final ChoreOccurrence secondOccurrence = _manageableUpcomingOccurrence(
        occurrenceId: '55555555-5555-4555-8555-555555555556',
        dueLocalDate: '2026-08-13',
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[firstOccurrence, secondOccurrence],
          view: ChoreListView.upcoming,
        ),
        seriesFromOccurrenceUpdateResults:
            const <UpdateRepeatingChoreSeriesResult>[
              UpdateRepeatingChoreSeriesFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              UpdateRepeatingChoreSeriesFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              UpdateRepeatingChoreSeriesFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      Future<void> update(ChoreOccurrence occurrence) =>
          controller.updateRepeatingSeriesFromOccurrence(
            householdId: activeHouseholdFixture().householdId,
            occurrenceId: occurrence.id,
            title: 'Future recycling',
            description: occurrence.description ?? '',
            assigneeMemberId: occurrence.seriesDefaultAssigneeMemberId!,
            dueLocalTime: occurrence.seriesDueLocalTime,
            recurrenceRule: occurrence.recurrenceRule!,
          );
      await update(firstOccurrence);
      await update(firstOccurrence);
      await update(secondOccurrence);

      expect(repository.seriesFromOccurrenceUpdateRequests, hasLength(3));
      expect(
        repository.seriesFromOccurrenceUpdateRequests[0].idempotencyKey,
        repository.seriesFromOccurrenceUpdateRequests[1].idempotencyKey,
      );
      expect(
        repository.seriesFromOccurrenceUpdateRequests[1].idempotencyKey,
        isNot(repository.seriesFromOccurrenceUpdateRequests[2].idempotencyKey),
      );
      expect(
        repository.seriesFromOccurrenceUpdateRequests[2].effectiveOccurrenceId,
        secondOccurrence.id,
      );
      expect(generator.generateCount, 2);
    },
  );

  test(
    'occurrence-bound edit rejects Today and no-op Upcoming calls',
    () async {
      for (final ChoreListView view in <ChoreListView>[
        ChoreListView.today,
        ChoreListView.upcoming,
      ]) {
        final ChoreOccurrence occurrence = view == ChoreListView.today
            ? _manageableOccurrence()
            : _manageableUpcomingOccurrence();
        final FakeChoreRepository repository = FakeChoreRepository(
          today: todayChoresFixture(
            occurrences: <ChoreOccurrence>[occurrence],
            view: view,
          ),
        );
        final FakeChoreCommandIdGenerator generator =
            FakeChoreCommandIdGenerator();
        final TodayChoresController controller = TodayChoresController(
          repository: repository,
          idGenerator: generator,
        );
        addTearDown(controller.dispose);
        await controller.loadQuery(
          ChoreListRequest.tryCreate(
            householdId: activeHouseholdFixture().householdId,
            view: view,
          )!,
        );

        await controller.updateRepeatingSeriesFromOccurrence(
          householdId: activeHouseholdFixture().householdId,
          occurrenceId: occurrence.id,
          title: view == ChoreListView.today ? 'Changed' : occurrence.title,
          description: occurrence.description ?? '',
          assigneeMemberId: occurrence.seriesDefaultAssigneeMemberId!,
          dueLocalTime: occurrence.seriesDueLocalTime,
          recurrenceRule: occurrence.recurrenceRule!,
        );

        expect(repository.seriesFromOccurrenceUpdateRequests, isEmpty);
        expect(generator.generateCount, 0);
        expect(
          (controller.state as TodayChoresReady).actionFailure?.kind,
          ChoreFailureKind.invalidTransition,
        );
      }
    },
  );

  test(
    'selected-occurrence cancellation exposes Undo and restores Upcoming',
    () async {
      final Completer<CancelRepeatingChoreSeriesFromOccurrenceResult> response =
          Completer<CancelRepeatingChoreSeriesFromOccurrenceResult>();
      addTearDown(() {
        if (!response.isCompleted) {
          response.complete(
            const CancelRepeatingChoreSeriesFromOccurrenceFailed(
              ChoreFailure(ChoreFailureKind.internal),
            ),
          );
        }
      });
      final ChoreOccurrence retained = _manageableUpcomingOccurrence(
        occurrenceId: '55555555-5555-4555-8555-555555555554',
        dueLocalDate: '2026-08-10',
      );
      final ChoreOccurrence target = _manageableUpcomingOccurrence();
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[retained, target],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[retained],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[retained, target],
              view: ChoreListView.upcoming,
            ),
          ),
        ],
        seriesFromOccurrenceCancellationCallback: (_) => response.future,
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      Future<void> cancel() => controller.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );
      final Future<void> first = cancel();
      final Future<void> duplicate = cancel();

      expect(identical(first, duplicate), isTrue);
      expect(repository.seriesFromOccurrenceCancellationRequests, hasLength(1));
      final CancelRepeatingChoreSeriesFromOccurrenceRequest request =
          repository.seriesFromOccurrenceCancellationRequests.single;
      expect(request.effectiveOccurrenceId, target.id);
      expect(request.expectedVersion, target.seriesVersion);
      expect(
        (controller.state as TodayChoresReady).pendingOccurrenceId,
        target.id,
      );

      response.complete(
        RepeatingChoreSeriesCancelledFromOccurrence(
          _fromOccurrenceCancellationSnapshot(request, target.dueLocalDate),
        ),
      );
      await first;

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(ready.actionFailure, isNull);
      expect(ready.today.view, ChoreListView.upcoming);
      expect(ready.today.occurrences.single.id, retained.id);
      final UndoableRepeatingChoreSeriesCancellation undoable =
          ready.undoableSeriesCancellation!;
      expect(undoable.householdId, request.householdId);
      expect(undoable.seriesId, request.seriesId);
      expect(undoable.cancellationIdempotencyKey, request.idempotencyKey);
      expect(undoable.cancellationVersion, request.expectedVersion + 1);
      expect(repository.listRequests, hasLength(2));
      expect(
        repository.listRequests.every(
          (ChoreListRequest item) => item.view == ChoreListView.upcoming,
        ),
        isTrue,
      );
      expect(generator.generateCount, 1);

      await controller.resumeRepeatingSeriesCancellation(
        householdId: undoable.householdId,
        seriesId: undoable.seriesId,
      );

      final TodayChoresReady restored = controller.state as TodayChoresReady;
      expect(restored.actionFailure, isNull);
      expect(restored.undoableSeriesCancellation, isNull);
      expect(restored.today.occurrences, hasLength(2));
      expect(repository.seriesCancellationResumeRequests, hasLength(1));
      final ResumeRepeatingChoreSeriesCancellationRequest resumeRequest =
          repository.seriesCancellationResumeRequests.single;
      expect(resumeRequest.cancellationIdempotencyKey, request.idempotencyKey);
      expect(resumeRequest.expectedVersion, request.expectedVersion + 1);
      expect(resumeRequest.idempotencyKey, isNot(request.idempotencyKey));
      expect(repository.listRequests, hasLength(3));
      expect(generator.generateCount, 2);
    },
  );

  test(
    'cancellation Undo retries reuse a key and terminal failure clears receipt',
    () async {
      final ChoreOccurrence target = _manageableUpcomingOccurrence();
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[target],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(todayChoresFixture(view: ChoreListView.upcoming)),
          TodayChoresLoaded(todayChoresFixture(view: ChoreListView.upcoming)),
        ],
        seriesCancellationResumeResults:
            const <ResumeRepeatingChoreSeriesCancellationResult>[
              ResumeRepeatingChoreSeriesCancellationFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              ResumeRepeatingChoreSeriesCancellationFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              ResumeRepeatingChoreSeriesCancellationFailed(
                ChoreFailure(ChoreFailureKind.staleVersion),
              ),
            ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );
      await controller.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );
      final UndoableRepeatingChoreSeriesCancellation undoable =
          (controller.state as TodayChoresReady).undoableSeriesCancellation!;

      Future<void> resume() => controller.resumeRepeatingSeriesCancellation(
        householdId: undoable.householdId,
        seriesId: undoable.seriesId,
      );
      await resume();
      await resume();

      expect(repository.seriesCancellationResumeRequests, hasLength(2));
      expect(
        repository.seriesCancellationResumeRequests[0].idempotencyKey,
        repository.seriesCancellationResumeRequests[1].idempotencyKey,
      );
      expect(
        (controller.state as TodayChoresReady).undoableSeriesCancellation,
        isNotNull,
      );
      expect(generator.generateCount, 2);

      await resume();

      final TodayChoresReady terminal = controller.state as TodayChoresReady;
      expect(terminal.undoableSeriesCancellation, isNull);
      expect(terminal.actionFailure?.kind, ChoreFailureKind.staleVersion);
      expect(repository.listRequests, hasLength(3));
      expect(generator.generateCount, 2);
    },
  );

  test(
    'cancellation Undo keeps its receipt when authoritative reload fails',
    () async {
      final ChoreOccurrence target = _manageableUpcomingOccurrence();
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[target],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(todayChoresFixture(view: ChoreListView.upcoming)),
          const LoadTodayChoresFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[target],
              view: ChoreListView.upcoming,
            ),
          ),
        ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );
      await controller.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );
      final UndoableRepeatingChoreSeriesCancellation undoable =
          (controller.state as TodayChoresReady).undoableSeriesCancellation!;

      Future<void> resume() => controller.resumeRepeatingSeriesCancellation(
        householdId: undoable.householdId,
        seriesId: undoable.seriesId,
      );
      await resume();

      final TodayChoresReady retryable = controller.state as TodayChoresReady;
      expect(
        retryable.actionFailure?.kind,
        ChoreFailureKind.temporarilyUnavailable,
      );
      expect(retryable.undoableSeriesCancellation, same(undoable));

      await resume();

      final TodayChoresReady restored = controller.state as TodayChoresReady;
      expect(restored.actionFailure, isNull);
      expect(restored.undoableSeriesCancellation, isNull);
      expect(restored.today.occurrences.single.id, target.id);
      expect(repository.seriesCancellationResumeRequests, hasLength(2));
      expect(
        repository.seriesCancellationResumeRequests[0].idempotencyKey,
        repository.seriesCancellationResumeRequests[1].idempotencyKey,
      );
      expect(repository.listRequests, hasLength(4));
      expect(generator.generateCount, 2);
    },
  );

  test(
    'selected-occurrence cancellation retries reuse a key and targets rotate it',
    () async {
      final ChoreOccurrence firstOccurrence = _manageableUpcomingOccurrence();
      final ChoreOccurrence secondOccurrence = _manageableUpcomingOccurrence(
        occurrenceId: '55555555-5555-4555-8555-555555555556',
        dueLocalDate: '2026-08-13',
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[firstOccurrence, secondOccurrence],
          view: ChoreListView.upcoming,
        ),
        seriesFromOccurrenceCancellationResults:
            const <CancelRepeatingChoreSeriesFromOccurrenceResult>[
              CancelRepeatingChoreSeriesFromOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              CancelRepeatingChoreSeriesFromOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
              CancelRepeatingChoreSeriesFromOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController controller = TodayChoresController(
        repository: repository,
        idGenerator: generator,
      );
      addTearDown(controller.dispose);
      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      Future<void> cancel(ChoreOccurrence occurrence) =>
          controller.cancelRepeatingSeriesFromOccurrence(
            householdId: activeHouseholdFixture().householdId,
            occurrenceId: occurrence.id,
          );
      await cancel(firstOccurrence);
      await cancel(firstOccurrence);
      await cancel(secondOccurrence);

      expect(repository.seriesFromOccurrenceCancellationRequests, hasLength(3));
      expect(
        repository.seriesFromOccurrenceCancellationRequests[0].idempotencyKey,
        repository.seriesFromOccurrenceCancellationRequests[1].idempotencyKey,
      );
      expect(
        repository.seriesFromOccurrenceCancellationRequests[1].idempotencyKey,
        isNot(
          repository.seriesFromOccurrenceCancellationRequests[2].idempotencyKey,
        ),
      );
      expect(
        repository
            .seriesFromOccurrenceCancellationRequests[2]
            .effectiveOccurrenceId,
        secondOccurrence.id,
      );
      expect(generator.generateCount, 2);
    },
  );

  test(
    'selected-occurrence unavailable target reloads the authoritative query',
    () async {
      final ChoreOccurrence target = _manageableUpcomingOccurrence();
      final FakeChoreRepository repository = FakeChoreRepository(
        loadResults: <LoadTodayChoresResult>[
          TodayChoresLoaded(
            todayChoresFixture(
              occurrences: <ChoreOccurrence>[target],
              view: ChoreListView.upcoming,
            ),
          ),
          TodayChoresLoaded(todayChoresFixture(view: ChoreListView.upcoming)),
        ],
        seriesFromOccurrenceCancellationResults:
            const <CancelRepeatingChoreSeriesFromOccurrenceResult>[
              CancelRepeatingChoreSeriesFromOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
              ),
            ],
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

      await controller.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );

      final TodayChoresReady ready = controller.state as TodayChoresReady;
      expect(repository.listRequests, hasLength(2));
      expect(ready.today.occurrences, isEmpty);
      expect(ready.actionFailure?.kind, ChoreFailureKind.notFoundOrForbidden);
    },
  );

  test(
    'selected-occurrence cancellation rejects Today and read-only Upcoming',
    () async {
      final ChoreOccurrence todayTarget = _manageableOccurrence();
      final ChoreOccurrence target = _manageableUpcomingOccurrence();
      final FakeChoreRepository todayRepository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[todayTarget],
          view: ChoreListView.today,
        ),
      );
      final FakeChoreCommandIdGenerator todayGenerator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController todayController = TodayChoresController(
        repository: todayRepository,
        idGenerator: todayGenerator,
      );
      addTearDown(todayController.dispose);
      await todayController.load(activeHouseholdFixture().householdId);

      await todayController.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: todayTarget.id,
      );

      expect(todayRepository.seriesFromOccurrenceCancellationRequests, isEmpty);
      expect(todayGenerator.generateCount, 0);
      expect(
        (todayController.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.invalidTransition,
      );

      final ReadCacheMetadata metadata = ReadCacheMetadata(
        validatedAt: DateTime.parse('2026-08-10T10:30:00Z'),
        expiresAt: DateTime.parse('2026-08-10T12:30:00Z'),
      );
      final FakeChoreRepository cachedRepository = FakeChoreRepository(
        listCallback: (_) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: <ChoreOccurrence>[target],
            view: ChoreListView.upcoming,
          ),
          cacheMetadata: metadata,
        ),
      );
      final FakeChoreCommandIdGenerator cachedGenerator =
          FakeChoreCommandIdGenerator();
      final TodayChoresController cachedController = TodayChoresController(
        repository: cachedRepository,
        idGenerator: cachedGenerator,
      );
      addTearDown(cachedController.dispose);
      await cachedController.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
          view: ChoreListView.upcoming,
        )!,
      );

      await cachedController.cancelRepeatingSeriesFromOccurrence(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: target.id,
      );

      expect(
        cachedRepository.seriesFromOccurrenceCancellationRequests,
        isEmpty,
      );
      expect(cachedGenerator.generateCount, 0);
      expect(
        (cachedController.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.offlineReadOnly,
      );
    },
  );

  test('coalesces series cancellation and removes it after reload', () async {
    final Completer<CancelRepeatingChoreSeriesResult> response =
        Completer<CancelRepeatingChoreSeriesResult>();
    addTearDown(() {
      if (!response.isCompleted) {
        response.complete(
          const CancelRepeatingChoreSeriesFailed(
            ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
    });
    final ChoreOccurrence original = _manageableOccurrence();
    final FakeChoreRepository repository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          todayChoresFixture(occurrences: <ChoreOccurrence>[original]),
        ),
        TodayChoresLoaded(todayChoresFixture()),
      ],
      seriesCancellationCallback: (_) => response.future,
    );
    final FakeChoreCommandIdGenerator generator = FakeChoreCommandIdGenerator();
    final TodayChoresController controller = TodayChoresController(
      repository: repository,
      idGenerator: generator,
    );
    addTearDown(controller.dispose);
    await controller.load(activeHouseholdFixture().householdId);

    final Future<void> first = controller.cancelRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
    );
    final Future<void> duplicate = controller.cancelRepeatingSeries(
      householdId: activeHouseholdFixture().householdId,
      occurrenceId: original.id,
    );

    expect(identical(first, duplicate), isTrue);
    expect(repository.seriesCancellationRequests, hasLength(1));
    final CancelRepeatingChoreSeriesRequest request =
        repository.seriesCancellationRequests.single;
    response.complete(
      RepeatingChoreSeriesCancelled(_cancellationSnapshot(request)),
    );
    await first;

    final TodayChoresReady ready = controller.state as TodayChoresReady;
    expect(ready.actionFailure, isNull);
    expect(ready.today.occurrences, isEmpty);
    expect(repository.loadedHouseholds, hasLength(2));
    expect(generator.generateCount, 1);
  });

  test('rejects unauthorized and no-op series edits locally', () async {
    final ChoreOccurrence manageable = _manageableOccurrence();
    final ChoreOccurrence unauthorized = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    for (final ChoreOccurrence occurrence in <ChoreOccurrence>[
      unauthorized,
      manageable,
    ]) {
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

      await controller.updateRepeatingSeries(
        householdId: activeHouseholdFixture().householdId,
        occurrenceId: occurrence.id,
        title: occurrence.title,
        description: occurrence.description ?? '',
        assigneeMemberId: occurrence.seriesDefaultAssigneeMemberId ?? _memberId,
        dueLocalTime: occurrence.seriesDueLocalTime,
        recurrenceRule:
            occurrence.recurrenceRule ??
            ChoreRecurrenceRule.anchored(
              frequency: ChoreRecurrenceFrequency.daily,
              startLocalDate: todayChoresFixture().localDate,
            ),
      );

      expect(repository.seriesUpdateRequests, isEmpty);
      expect(generator.generateCount, 0);
      expect(
        (controller.state as TodayChoresReady).actionFailure?.kind,
        ChoreFailureKind.invalidTransition,
      );
    }
  });
}

final HouseholdMemberId _memberId = HouseholdMemberId.tryParse(
  '33333333-3333-4333-8333-333333333333',
)!;

final HouseholdMemberId _otherMemberId = HouseholdMemberId.tryParse(
  '33333333-3333-4333-8333-333333333334',
)!;

ChoreOccurrence _manageableOccurrence() {
  final ChoreLocalDate today = todayChoresFixture().localDate;
  final ChoreLocalTime dueTime = ChoreLocalTime.tryParse('19:30')!;
  final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
    frequency: ChoreRecurrenceFrequency.daily,
    startLocalDate: today,
  );
  return choreOccurrenceFixture(
    description: 'Blue bin',
    dueLocalTime: dueTime,
    dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
    recurrenceFrequency: rule.frequency,
    seriesVersion: 1,
    seriesDefaultAssigneeMemberId: _memberId,
    seriesDueLocalTime: dueTime,
    recurrenceRule: rule,
    canManageSeries: true,
  );
}

ChoreOccurrence _updatedOccurrence(ChoreOccurrence original) {
  final ChoreLocalTime dueTime = ChoreLocalTime.tryParse('20:00')!;
  final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
    frequency: ChoreRecurrenceFrequency.weekly,
    startLocalDate: todayChoresFixture().localDate,
  );
  return choreOccurrenceFixture(
    occurrenceId: original.id.value,
    seriesId: original.seriesId.value,
    title: 'Updated recycling',
    description: 'Use the blue bin',
    assigneeMemberId: _otherMemberId,
    assigneeDisplayName: 'Sam',
    dueLocalTime: dueTime,
    dueAt: DateTime.parse('2026-08-06T11:00:00Z'),
    version: original.version,
    recurrenceFrequency: rule.frequency,
    seriesVersion: 2,
    seriesDefaultAssigneeMemberId: _otherMemberId,
    seriesDueLocalTime: dueTime,
    recurrenceRule: rule,
    canManageSeries: true,
  );
}

ChoreOccurrence _manageableUpcomingOccurrence({
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String dueLocalDate = '2026-08-12',
}) {
  final ChoreLocalDate selectedDate = ChoreLocalDate.tryParse(dueLocalDate)!;
  final DateTime selectedDateTime = selectedDate.toDateTime();
  final ChoreLocalTime dueTime = ChoreLocalTime.tryParse('19:30')!;
  final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
    frequency: ChoreRecurrenceFrequency.daily,
    startLocalDate: todayChoresFixture().localDate,
  );
  return choreOccurrenceFixture(
    occurrenceId: occurrenceId,
    description: 'Blue bin',
    dueLocalDate: selectedDate,
    dueLocalTime: dueTime,
    dueAt: DateTime.utc(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      10,
      30,
    ),
    recurrenceFrequency: rule.frequency,
    seriesVersion: 1,
    seriesDefaultAssigneeMemberId: _memberId,
    seriesDueLocalTime: dueTime,
    recurrenceRule: rule,
    canManageSeries: true,
  );
}

ChoreOccurrence _updatedUpcomingOccurrence(ChoreOccurrence original) {
  final ChoreLocalTime dueTime = ChoreLocalTime.tryParse('20:00')!;
  final DateTime selectedDateTime = original.dueLocalDate.toDateTime();
  final ChoreRecurrenceRule rule = ChoreRecurrenceRule.anchored(
    frequency: ChoreRecurrenceFrequency.weekly,
    startLocalDate: original.dueLocalDate,
  );
  return choreOccurrenceFixture(
    occurrenceId: original.id.value,
    seriesId: original.seriesId.value,
    title: 'Updated future recycling',
    description: 'Use the blue bin',
    assigneeMemberId: _otherMemberId,
    assigneeDisplayName: 'Sam',
    dueLocalDate: original.dueLocalDate,
    dueLocalTime: dueTime,
    dueAt: DateTime.utc(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
      11,
    ),
    version: original.version,
    recurrenceFrequency: rule.frequency,
    seriesVersion: 2,
    seriesDefaultAssigneeMemberId: _otherMemberId,
    seriesDueLocalTime: dueTime,
    recurrenceRule: rule,
    canManageSeries: true,
  );
}

RepeatingChoreSeriesUpdateSnapshot _updateSnapshot(
  UpdateRepeatingChoreSeriesRequest request,
) {
  return RepeatingChoreSeriesUpdateSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    revisionId: ChoreRevisionId.tryParse(
      '77777777-7777-4777-8777-777777777777',
    )!,
    revisionNumber: request.expectedVersion + 1,
    effectiveLocalDate: request.effectiveLocalDate,
    version: request.expectedVersion + 1,
    rebuiltCount: 53,
    cancelledCount: 313,
    preservedCompletedCount: 0,
    changed: true,
  );
}

RepeatingChoreSeriesUpdateSnapshot _fromOccurrenceUpdateSnapshot(
  UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  ChoreLocalDate effectiveLocalDate,
) {
  return RepeatingChoreSeriesUpdateSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    revisionId: ChoreRevisionId.tryParse(
      '77777777-7777-4777-8777-777777777777',
    )!,
    revisionNumber: request.expectedVersion + 1,
    effectiveLocalDate: effectiveLocalDate,
    version: request.expectedVersion + 1,
    rebuiltCount: 47,
    cancelledCount: 307,
    preservedCompletedCount: 1,
    changed: true,
  );
}

RepeatingChoreSeriesCancellationSnapshot _cancellationSnapshot(
  CancelRepeatingChoreSeriesRequest request,
) {
  return RepeatingChoreSeriesCancellationSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    effectiveLocalDate: todayChoresFixture().localDate,
    version: request.expectedVersion + 1,
    cancelledCount: 366,
    preservedCompletedCount: 0,
    changed: true,
  );
}

RepeatingChoreSeriesFromOccurrenceCancellationSnapshot
_fromOccurrenceCancellationSnapshot(
  CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  ChoreLocalDate effectiveLocalDate,
) {
  return RepeatingChoreSeriesFromOccurrenceCancellationSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: request.expectedVersion + 1,
    cancelledCount: 19,
    preservedCompletedCount: 2,
    terminalRevisionId: ChoreRevisionId.tryParse(
      '77777777-7777-4777-8777-777777777778',
    ),
    terminalRevisionNumber: request.expectedVersion + 1,
    changed: true,
  );
}
