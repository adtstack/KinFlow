import 'dart:async';

import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/application/chore_sync_session.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

typedef TodayChoresClock = DateTime Function();

final class TodayChoresController {
  factory TodayChoresController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
    ChoreCompletionOutbox completionOutbox =
        const UnavailableChoreCompletionOutbox(),
    ChoreSyncRepository? syncRepository,
    TodayChoresClock clock = DateTime.now,
  }) => TodayChoresController._(
    repository,
    idGenerator,
    completionOutbox,
    syncRepository,
    clock,
  );

  TodayChoresController._(
    this._repository,
    this._idGenerator,
    this._completionOutbox,
    ChoreSyncRepository? syncRepository,
    this._clock,
  ) {
    _syncSession = ChoreSyncSession(
      syncRepository,
      _synchronize,
      _setSyncStatus,
    );
  }

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final ChoreCompletionOutbox _completionOutbox;
  final TodayChoresClock _clock;
  late final ChoreSyncSession _syncSession;
  final StreamController<TodayChoresState> _states =
      StreamController<TodayChoresState>.broadcast(sync: true);

  TodayChoresState _state = const TodayChoresInitial();
  Future<void> _pendingLoad = Future<void>.value();
  Future<void> _pendingAction = Future<void>.value();
  String? _retryFingerprint;
  ChoreCommandId? _retryId;
  UndoableChoreSkip? _undoableSkip;
  UndoableOneTimeChoreDeletion? _undoableDeletion;
  UndoableRepeatingChoreSeriesCancellation? _undoableSeriesCancellation;
  ChoreListRequest? _currentRequest;
  HouseholdId? _syncedHouseholdId;
  ReadCacheMetadata? _cacheMetadata;
  HouseholdMemberId? _currentActorMemberId;
  PendingChoreCompletion? _queuedCompletion;
  TodayChoreCompletionSync? _completionSync;
  ChoreSyncConnectionStatus _syncStatus = ChoreSyncConnectionStatus.disabled;
  var _loadBusy = false;
  var _actionBusy = false;
  var _disposed = false;

  TodayChoresState get state => _state;

  Stream<TodayChoresState> get states => _states.stream;

  Future<void> load(HouseholdId householdId) {
    final ChoreListRequest request = ChoreListRequest.tryCreate(
      householdId: householdId,
    )!;
    return loadQuery(request);
  }

  Future<void> loadQuery(
    ChoreListRequest request, {
    bool preserveContent = false,
    HouseholdMemberId? actorMemberId,
  }) {
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy || _disposed) {
      return _pendingLoad;
    }
    final bool householdChanged =
        _currentRequest != null &&
        _currentRequest!.householdId != request.householdId;
    _loadBusy = true;
    if (householdChanged) {
      _queuedCompletion = null;
      _completionSync = null;
      _syncedHouseholdId = null;
      _cacheMetadata = null;
      _undoableSkip = null;
      _undoableDeletion = null;
      _undoableSeriesCancellation = null;
      _clearRetry();
      // Do not retain content from the previously selected household while
      // its channel is being removed.
      _emit(const TodayChoresLoading());
    }
    _currentActorMemberId = actorMemberId;
    _currentRequest = request.firstPage;
    _pendingLoad =
        (householdChanged
                ? _stopSyncAndLoad(request.firstPage)
                : _loadRequest(
                    request.firstPage,
                    preserveContent: preserveContent,
                  ))
            .whenComplete(() => _loadBusy = false);
    return _pendingLoad;
  }

  Future<void> refresh() {
    final ChoreListRequest? request = _currentRequest;
    if (request == null) {
      return Future<void>.value();
    }
    return loadQuery(
      request,
      preserveContent: true,
      actorMemberId: _currentActorMemberId,
    );
  }

  Future<void> resume() => _syncSession.resume();

  Future<void> reconnect() => _syncSession.reconnect();

  Future<void> prepareCompletionOutbox({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required bool allowReplay,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    _currentActorMemberId = actorMemberId;
    _actionBusy = true;
    _pendingAction = _prepareCompletionOutbox(
      householdId: householdId,
      actorMemberId: actorMemberId,
      allowReplay: allowReplay,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<bool> discardCompletionOutbox() async {
    if (_disposed || _actionBusy || _loadBusy) {
      return false;
    }
    _actionBusy = true;
    var cleared = false;
    _pendingAction = (() async {
      cleared = await _completionOutbox.clear();
      if (cleared) {
        _queuedCompletion = null;
        _completionSync = null;
      } else if (_queuedCompletion != null) {
        _setCompletionSync(
          TodayChoreCompletionSyncKind.needsAttention,
          _queuedCompletion!.occurrenceId,
        );
      }
      _emitCompletionSyncIfReady();
    })().whenComplete(() => _actionBusy = false);
    await _pendingAction;
    return cleared;
  }

  Future<void> loadMore() {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreListRequest? currentRequest = _currentRequest;
    final ChoreListCursor? cursor = ready?.today.nextCursor;
    if (ready == null ||
        currentRequest == null ||
        !ready.today.hasMore ||
        cursor == null) {
      return Future<void>.value();
    }
    if (ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    final ChoreListRequest? request = currentRequest.continuation(cursor);
    if (request == null) {
      return Future<void>.value();
    }
    _loadBusy = true;
    _pendingLoad = _loadContinuation(
      ready,
      request,
    ).whenComplete(() => _loadBusy = false);
    return _pendingLoad;
  }

  Future<void> setCompleted({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required bool completed,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      if (occurrence == null ||
          !completed ||
          !occurrence.canSetCompletion ||
          occurrence.status != ChoreOccurrenceStatus.scheduled ||
          _currentActorMemberId == null ||
          !_completionOutbox.isAvailable) {
        _rejectCachedMutation(ready);
        return Future<void>.value();
      }
      final ChoreCompletionDraft? draft = ChoreCompletionDraft.tryCreate(
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: occurrence.version,
        completed: true,
      );
      if (draft == null) {
        _emitReady(
          ready.today,
          actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
        );
        return Future<void>.value();
      }
      _undoableDeletion = null;
      _undoableSeriesCancellation = null;
      _actionBusy = true;
      _pendingAction = _queueCachedCompletion(
        ready.today,
        occurrence,
        draft,
        _currentActorMemberId!,
      ).whenComplete(() => _actionBusy = false);
      return _pendingAction;
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    final ChoreCompletionDraft? draft = ChoreCompletionDraft.tryCreate(
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: occurrence.version,
      completed: completed,
    );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _setCompletion(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> skipOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (occurrence.recurrenceFrequency == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final ChoreOccurrenceSkipDraft? draft = ChoreOccurrenceSkipDraft.tryCreate(
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: occurrence.version,
    );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _actionBusy = true;
    _pendingAction = _skipOccurrence(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> rescheduleOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (occurrence.recurrenceFrequency == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled ||
        occurrence.dueLocalDate == dueLocalDate &&
            occurrence.dueLocalTime == dueLocalTime) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final ChoreOccurrenceRescheduleDraft? draft =
        ChoreOccurrenceRescheduleDraft.tryCreate(
          householdId: householdId,
          occurrenceId: occurrenceId,
          expectedVersion: occurrence.version,
          dueLocalDate: dueLocalDate,
          dueLocalTime: dueLocalTime,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _rescheduleOccurrence(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> reassignOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required HouseholdMemberId assigneeMemberId,
    required String assigneeDisplayName,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (occurrence.recurrenceFrequency == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled ||
        occurrence.assigneeMemberId == assigneeMemberId) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final String normalizedDisplayName = assigneeDisplayName.trim();
    if (normalizedDisplayName.isEmpty ||
        normalizedDisplayName.length > 80 ||
        normalizedDisplayName != assigneeDisplayName) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    final ChoreOccurrenceReassignmentDraft? draft =
        ChoreOccurrenceReassignmentDraft.tryCreate(
          householdId: householdId,
          occurrenceId: occurrenceId,
          expectedVersion: occurrence.version,
          assigneeMemberId: assigneeMemberId,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _reassignOccurrence(
      ready.today,
      occurrence,
      draft,
      normalizedDisplayName,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> updateOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (!occurrence.canManageOneTime) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final OneTimeChoreUpdateDraft? draft = OneTimeChoreUpdateDraft.tryCreate(
      householdId: householdId,
      seriesId: occurrence.seriesId,
      occurrenceId: occurrence.id,
      expectedSeriesVersion: occurrence.seriesVersion,
      expectedOccurrenceVersion: occurrence.version,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    if (draft.title == occurrence.title &&
        draft.description == occurrence.description &&
        draft.assigneeMemberId == occurrence.assigneeMemberId &&
        draft.dueLocalDate == occurrence.dueLocalDate &&
        draft.dueLocalTime == occurrence.dueLocalTime) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _updateOneTimeChore(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> deleteOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (!occurrence.canManageOneTime) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final OneTimeChoreDeletionDraft? draft =
        OneTimeChoreDeletionDraft.tryCreate(
          householdId: householdId,
          seriesId: occurrence.seriesId,
          occurrenceId: occurrence.id,
          expectedSeriesVersion: occurrence.seriesVersion,
          expectedOccurrenceVersion: occurrence.version,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _deleteOneTimeChore(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> undoDeleteOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    final UndoableOneTimeChoreDeletion? undoable = _undoableDeletion;
    if (ready == null ||
        ready.today.householdId != householdId ||
        undoable == null ||
        undoable.occurrence.id != occurrenceId ||
        _findOccurrence(ready.today, occurrenceId) != null) {
      return Future<void>.value();
    }
    final OneTimeChoreRestoreDraft? draft = OneTimeChoreRestoreDraft.tryCreate(
      householdId: householdId,
      seriesId: undoable.occurrence.seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: undoable.deletedSeriesVersion,
      expectedOccurrenceVersion: undoable.deletedOccurrenceVersion,
    );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _undoDeleteOneTimeChore(
      ready.today,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  void dismissDeleteOneTimeChoreUndo(ChoreOccurrenceId occurrenceId) {
    if (_actionBusy || _loadBusy || _disposed) {
      return;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    if (ready == null || _undoableDeletion?.occurrence.id != occurrenceId) {
      return;
    }
    _undoableDeletion = null;
    _emitReady(ready.today);
  }

  Future<void> updateRepeatingSeries({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    final ChoreRecurrenceRule? currentRule = occurrence.recurrenceRule;
    if (!occurrence.canManageSeries ||
        occurrence.recurrenceFrequency == null ||
        occurrence.seriesDefaultAssigneeMemberId == null ||
        currentRule == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final RepeatingChoreSeriesUpdateDraft? draft =
        RepeatingChoreSeriesUpdateDraft.tryCreate(
          householdId: householdId,
          seriesId: occurrence.seriesId,
          expectedVersion: occurrence.seriesVersion,
          effectiveLocalDate: ready.today.localDate,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalTime: dueLocalTime,
          recurrenceRule: recurrenceRule,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    if (draft.title == occurrence.title &&
        draft.description == occurrence.description &&
        draft.assigneeMemberId == occurrence.seriesDefaultAssigneeMemberId &&
        draft.dueLocalTime == occurrence.seriesDueLocalTime &&
        draft.recurrenceRule.fingerprint == currentRule.fingerprint) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _updateRepeatingSeries(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> updateRepeatingSeriesFromOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    final ChoreRecurrenceRule? currentRule = occurrence.recurrenceRule;
    if (ready.today.view != ChoreListView.upcoming ||
        !occurrence.canManageSeries ||
        occurrence.recurrenceFrequency == null ||
        occurrence.seriesDefaultAssigneeMemberId == null ||
        currentRule == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final RepeatingChoreSeriesFromOccurrenceUpdateDraft? draft =
        RepeatingChoreSeriesFromOccurrenceUpdateDraft.tryCreate(
          householdId: householdId,
          seriesId: occurrence.seriesId,
          effectiveOccurrenceId: occurrence.id,
          expectedVersion: occurrence.seriesVersion,
          minimumLocalDate: occurrence.dueLocalDate,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalTime: dueLocalTime,
          recurrenceRule: recurrenceRule,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    if (draft.title == occurrence.title &&
        draft.description == occurrence.description &&
        draft.assigneeMemberId == occurrence.seriesDefaultAssigneeMemberId &&
        draft.dueLocalTime == occurrence.seriesDueLocalTime &&
        draft.recurrenceRule.fingerprint == currentRule.fingerprint) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _updateRepeatingSeriesFromOccurrence(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> cancelRepeatingSeries({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (!occurrence.canManageSeries ||
        occurrence.recurrenceFrequency == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final RepeatingChoreSeriesCancellationDraft? draft =
        RepeatingChoreSeriesCancellationDraft.tryCreate(
          householdId: householdId,
          seriesId: occurrence.seriesId,
          expectedVersion: occurrence.seriesVersion,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _cancelRepeatingSeries(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> cancelRepeatingSeriesFromOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final ChoreOccurrence? occurrence =
        ready == null || ready.today.householdId != householdId
        ? null
        : _findOccurrence(ready.today, occurrenceId);
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    if (ready == null || occurrence == null) {
      return Future<void>.value();
    }
    if (ready.today.view != ChoreListView.upcoming ||
        occurrence.dueLocalDate.value.compareTo(ready.today.localDate.value) <=
            0 ||
        !occurrence.canManageSeries ||
        occurrence.recurrenceFrequency == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidTransition),
      );
      return Future<void>.value();
    }
    final RepeatingChoreSeriesFromOccurrenceCancellationDraft? draft =
        RepeatingChoreSeriesFromOccurrenceCancellationDraft.tryCreate(
          householdId: householdId,
          seriesId: occurrence.seriesId,
          effectiveOccurrenceId: occurrence.id,
          expectedVersion: occurrence.seriesVersion,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _cancelRepeatingSeriesFromOccurrence(
      ready.today,
      occurrence,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> resumeRepeatingSeriesCancellation({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    final UndoableRepeatingChoreSeriesCancellation? undoable =
        _undoableSeriesCancellation;
    if (ready == null ||
        ready.today.householdId != householdId ||
        undoable == null ||
        undoable.householdId != householdId ||
        undoable.seriesId != seriesId) {
      return Future<void>.value();
    }
    final ResumeRepeatingChoreSeriesCancellationDraft? draft =
        ResumeRepeatingChoreSeriesCancellationDraft.tryCreate(
          householdId: householdId,
          seriesId: seriesId,
          cancellationIdempotencyKey: undoable.cancellationIdempotencyKey,
          expectedVersion: undoable.cancellationVersion,
        );
    if (draft == null) {
      _undoableSeriesCancellation = null;
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSkip = null;
    _undoableDeletion = null;
    _actionBusy = true;
    _pendingAction = _resumeRepeatingSeriesCancellation(
      ready.today,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> restoreSkippedOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_actionBusy || _disposed) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    if (ready != null && ready.isReadOnlyCache) {
      _rejectCachedMutation(ready);
      return Future<void>.value();
    }
    final UndoableChoreSkip? undoable = _undoableSkip;
    if (ready == null ||
        ready.today.householdId != householdId ||
        undoable == null ||
        undoable.occurrence.id != occurrenceId ||
        _findOccurrence(ready.today, occurrenceId) != null) {
      return Future<void>.value();
    }
    final ChoreOccurrenceRestoreDraft? draft =
        ChoreOccurrenceRestoreDraft.tryCreate(
          householdId: householdId,
          occurrenceId: occurrenceId,
          expectedVersion: undoable.skippedVersion,
        );
    if (draft == null) {
      _emitReady(
        ready.today,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableDeletion = null;
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _pendingAction = _restoreSkippedOccurrence(
      ready.today,
      undoable,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> _loadRequest(
    ChoreListRequest request, {
    required bool preserveContent,
    bool loadingAlreadyEmitted = false,
  }) async {
    final TodayChoresReady? previous = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    final bool canPreserve =
        preserveContent &&
        previous != null &&
        previous.today.householdId == request.householdId &&
        previous.today.view == request.view &&
        previous.today.assigneeFilterMemberId == request.assigneeMemberId &&
        previous.today.pageLimit == request.limit;
    _cacheMetadata = canPreserve ? previous.cacheMetadata : null;
    if (!canPreserve) {
      _undoableSkip = null;
      _undoableDeletion = null;
      _undoableSeriesCancellation = null;
      _clearRetry();
      if (!loadingAlreadyEmitted) {
        _emit(const TodayChoresLoading());
      }
    } else {
      _emitReady(previous.today, refreshing: true);
    }
    final LoadTodayChoresResult result;
    try {
      result = await _repository.loadChoreList(request);
    } on Object {
      const ChoreFailure failure = ChoreFailure(ChoreFailureKind.internal);
      if (canPreserve) {
        _emitReady(previous.today, refreshFailure: failure);
      } else {
        _emit(const TodayChoresLoadFailed(failure));
      }
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _undoableSkip = null;
        _undoableDeletion = null;
        _undoableSeriesCancellation = null;
        _clearRetry();
        _cacheMetadata = cacheMetadata;
        final TodayChores presented = await _restoreQueuedCompletion(today);
        _emitReady(presented);
        await _ensureSync(request.householdId);
      case LoadTodayChoresFailed(:final failure):
        if (failure.invalidatesRetainedContent) {
          _cacheMetadata = null;
          _emit(TodayChoresLoadFailed(failure));
          await _stopSyncAfterAuthorizationFailure();
        } else if (canPreserve) {
          _emitReady(previous.today, refreshFailure: failure);
        } else {
          _emit(TodayChoresLoadFailed(failure));
        }
    }
  }

  Future<void> _loadContinuation(
    TodayChoresReady ready,
    ChoreListRequest request,
  ) async {
    _emitReady(ready.today, loadingMore: true);
    final LoadTodayChoresResult result;
    try {
      result = await _repository.loadChoreList(request);
    } on Object {
      _emitReady(
        ready.today,
        loadMoreFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        if (cacheMetadata != null) {
          _emitReady(
            ready.today,
            loadMoreFailure: const ChoreFailure(
              ChoreFailureKind.offlineReadOnly,
            ),
          );
          return;
        }
        final TodayChores? merged = ready.today.appendPage(today);
        if (merged == null) {
          _emitReady(
            ready.today,
            loadMoreFailure: const ChoreFailure(
              ChoreFailureKind.invalidPayload,
            ),
          );
          return;
        }
        _emitReady(merged);
      case LoadTodayChoresFailed(:final failure):
        if (failure.invalidatesRetainedContent) {
          _cacheMetadata = null;
          _emit(TodayChoresLoadFailed(failure));
          await _stopSyncAfterAuthorizationFailure();
        } else {
          _emitReady(ready.today, loadMoreFailure: failure);
        }
    }
  }

  Future<void> _prepareCompletionOutbox({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required bool allowReplay,
  }) async {
    if (!_completionOutbox.isAvailable) {
      _queuedCompletion = null;
      return;
    }
    if (_completionSync != null && !_completionSync!.hasStoredIntent) {
      _completionSync = null;
    }
    final PendingChoreCompletion? previous = _queuedCompletion;
    final PendingChoreCompletion? item;
    try {
      item = await _completionOutbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      );
    } on Object {
      if (previous != null) {
        _setCompletionSync(
          TodayChoreCompletionSyncKind.needsAttention,
          previous.occurrenceId,
        );
        _emitCompletionSyncIfReady();
      }
      return;
    }
    if (item == null) {
      if (previous != null) {
        final TodayChoreCompletionSyncKind kind =
            _clock().toUtc().isBefore(previous.expiresAt)
            ? TodayChoreCompletionSyncKind.needsAttention
            : TodayChoreCompletionSyncKind.expired;
        _queuedCompletion = null;
        _setCompletionSync(kind, previous.occurrenceId);
        _emitCompletionSyncIfReady();
      }
      return;
    }
    _queuedCompletion = item;
    if (_completionSync?.kind == TodayChoreCompletionSyncKind.needsAttention &&
        previous == item) {
      _emitCompletionSyncIfReady();
      return;
    }
    if (!allowReplay) {
      _setCompletionSync(
        TodayChoreCompletionSyncKind.paused,
        item.occurrenceId,
      );
      _emitCompletionSyncIfReady();
      return;
    }
    if (!item.canAttemptAutomatically) {
      _setCompletionSync(
        TodayChoreCompletionSyncKind.needsAttention,
        item.occurrenceId,
      );
      _emitCompletionSyncIfReady();
      return;
    }
    final PendingChoreCompletion? attempted = await _completionOutbox
        .markNextAttempt(item);
    if (attempted == null) {
      _setCompletionSync(
        TodayChoreCompletionSyncKind.needsAttention,
        item.occurrenceId,
      );
      _emitCompletionSyncIfReady();
      return;
    }
    _queuedCompletion = attempted;
    _setCompletionSync(
      TodayChoreCompletionSyncKind.syncing,
      attempted.occurrenceId,
    );
    _emitCompletionSyncIfReady();

    final LoadChoreOccurrenceTargetResult targetResult;
    try {
      targetResult = await _repository.loadOccurrenceTarget(
        householdId: attempted.householdId,
        occurrenceId: attempted.occurrenceId,
      );
    } on Object {
      _retainQueuedCompletion(attempted);
      return;
    }
    switch (targetResult) {
      case ChoreOccurrenceTargetLoaded(:final occurrence):
        if (occurrence.id != attempted.occurrenceId) {
          await _discardQueuedCompletion(attempted.occurrenceId);
          return;
        }
        if (occurrence.status == ChoreOccurrenceStatus.completed &&
            occurrence.version == attempted.expectedVersion + 1) {
          await _finishQueuedCompletion(
            attempted.occurrenceId,
            TodayChoreCompletionSyncKind.reconciled,
          );
          return;
        }
        if (occurrence.status != ChoreOccurrenceStatus.scheduled ||
            occurrence.version != attempted.expectedVersion ||
            !occurrence.canSetCompletion) {
          await _discardQueuedCompletion(attempted.occurrenceId);
          return;
        }
        await _replayQueuedCompletion(attempted);
      case LoadChoreOccurrenceTargetFailed(:final failure)
          when failure.kind == ChoreFailureKind.temporarilyUnavailable:
        _retainQueuedCompletion(attempted);
      case LoadChoreOccurrenceTargetFailed():
        await _discardQueuedCompletion(attempted.occurrenceId);
    }
  }

  Future<void> _replayQueuedCompletion(PendingChoreCompletion item) async {
    final SetChoreCompletionResult result;
    try {
      result = await _repository.setOccurrenceCompletion(item.request);
    } on Object {
      _retainQueuedCompletion(item);
      return;
    }
    switch (result) {
      case ChoreCompletionSet(:final snapshot)
          when snapshot.householdId == item.householdId &&
              snapshot.occurrenceId == item.occurrenceId &&
              snapshot.status == ChoreOccurrenceStatus.completed &&
              snapshot.version == item.expectedVersion + 1:
        await _finishQueuedCompletion(
          item.occurrenceId,
          TodayChoreCompletionSyncKind.reconciled,
        );
      case ChoreCompletionSet():
        await _discardQueuedCompletion(item.occurrenceId);
      case SetChoreCompletionFailed(:final failure)
          when failure.kind == ChoreFailureKind.temporarilyUnavailable:
        _retainQueuedCompletion(item);
      case SetChoreCompletionFailed():
        await _discardQueuedCompletion(item.occurrenceId);
    }
  }

  void _retainQueuedCompletion(PendingChoreCompletion item) {
    _queuedCompletion = item;
    _setCompletionSync(
      item.canAttemptAutomatically
          ? TodayChoreCompletionSyncKind.queued
          : TodayChoreCompletionSyncKind.needsAttention,
      item.occurrenceId,
    );
    _emitCompletionSyncIfReady();
  }

  Future<void> _discardQueuedCompletion(ChoreOccurrenceId occurrenceId) {
    return _finishQueuedCompletion(
      occurrenceId,
      TodayChoreCompletionSyncKind.discarded,
    );
  }

  Future<void> _finishQueuedCompletion(
    ChoreOccurrenceId occurrenceId,
    TodayChoreCompletionSyncKind successKind,
  ) async {
    final PendingChoreCompletion? pending = _queuedCompletion;
    final bool cleared = await _completionOutbox.clear();
    if (cleared) {
      _queuedCompletion = null;
      _setCompletionSync(successKind, occurrenceId);
    } else {
      final PendingChoreCompletion? exhausted = pending == null
          ? null
          : await _completionOutbox.exhaustAutomaticAttempts(pending);
      if (exhausted != null) {
        _queuedCompletion = exhausted;
      }
      _setCompletionSync(
        TodayChoreCompletionSyncKind.needsAttention,
        occurrenceId,
      );
    }
    _emitCompletionSyncIfReady();
  }

  Future<TodayChores> _restoreQueuedCompletion(TodayChores today) async {
    final HouseholdMemberId? actorMemberId = _currentActorMemberId;
    if (!_completionOutbox.isAvailable || actorMemberId == null) {
      return today;
    }
    final PendingChoreCompletion? item;
    try {
      item = await _completionOutbox.read(
        expectedHouseholdId: today.householdId,
        expectedActorMemberId: actorMemberId,
      );
    } on Object {
      return today;
    }
    if (item == null) {
      final PendingChoreCompletion? previous = _queuedCompletion;
      if (previous != null) {
        _queuedCompletion = null;
        if (!_clock().toUtc().isBefore(previous.expiresAt)) {
          _setCompletionSync(
            TodayChoreCompletionSyncKind.expired,
            previous.occurrenceId,
          );
        } else if (_completionSync?.hasStoredIntent ?? false) {
          _completionSync = null;
        }
      }
      return today;
    }
    _queuedCompletion = item;
    if (_completionSync == null || !_completionSync!.hasStoredIntent) {
      _setCompletionSync(
        item.canAttemptAutomatically
            ? TodayChoreCompletionSyncKind.queued
            : TodayChoreCompletionSyncKind.needsAttention,
        item.occurrenceId,
      );
    }
    if (!item.canAttemptAutomatically ||
        _completionSync?.kind == TodayChoreCompletionSyncKind.needsAttention) {
      return today;
    }
    final ChoreOccurrence? occurrence = _findOccurrence(
      today,
      item.occurrenceId,
    );
    if (occurrence == null ||
        occurrence.status != ChoreOccurrenceStatus.scheduled ||
        occurrence.version != item.expectedVersion ||
        !occurrence.canSetCompletion) {
      return today;
    }
    return today.applyOccurrence(
      occurrence.copyWith(status: ChoreOccurrenceStatus.completed),
    );
  }

  Future<void> _queueCachedCompletion(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    ChoreCompletionDraft draft,
    HouseholdMemberId actorMemberId,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: draft.occurrenceId);
    final ChoreCompletionOutboxEnqueueResult result = await _completionOutbox
        .enqueue(
          householdId: draft.householdId,
          actorMemberId: actorMemberId,
          occurrenceId: draft.occurrenceId,
          expectedVersion: draft.expectedVersion,
          idempotencyKey: _retryId!,
        );
    switch (result) {
      case ChoreCompletionOutboxEnqueued(:final item):
        _queuedCompletion = item;
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queued,
          item.occurrenceId,
        );
        _clearRetry();
        _emitReady(
          originalToday.applyOccurrence(
            originalOccurrence.copyWith(
              status: ChoreOccurrenceStatus.completed,
            ),
          ),
        );
      case ChoreCompletionOutboxOccupied(:final item):
        _queuedCompletion = item;
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queueOccupied,
          item.occurrenceId,
        );
        _emitReady(originalToday);
      case ChoreCompletionOutboxUnavailable():
        _queuedCompletion = null;
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queueUnavailable,
          draft.occurrenceId,
        );
        _emitReady(originalToday);
    }
  }

  Future<bool> _queueCompletionAfterTransientFailure({
    required TodayChores originalToday,
    required TodayChores optimisticToday,
    required ChoreCompletionDraft draft,
    required ChoreCommandId commandId,
    required HouseholdMemberId actorMemberId,
  }) async {
    final ChoreCompletionOutboxEnqueueResult result = await _completionOutbox
        .enqueue(
          householdId: draft.householdId,
          actorMemberId: actorMemberId,
          occurrenceId: draft.occurrenceId,
          expectedVersion: draft.expectedVersion,
          idempotencyKey: commandId,
        );
    switch (result) {
      case ChoreCompletionOutboxEnqueued(:final item):
        _queuedCompletion = item;
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queued,
          item.occurrenceId,
        );
        _clearRetry();
        _emitReady(optimisticToday);
        return true;
      case ChoreCompletionOutboxOccupied(:final item):
        _queuedCompletion = item;
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queueOccupied,
          item.occurrenceId,
        );
        return false;
      case ChoreCompletionOutboxUnavailable():
        _setCompletionSync(
          TodayChoreCompletionSyncKind.queueUnavailable,
          draft.occurrenceId,
        );
        return false;
    }
  }

  Future<void> _setCompletion(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    ChoreCompletionDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    final ChoreOccurrence optimisticOccurrence = originalOccurrence.copyWith(
      status: draft.completed
          ? ChoreOccurrenceStatus.completed
          : ChoreOccurrenceStatus.scheduled,
    );
    final TodayChores optimisticToday = originalToday.applyOccurrence(
      optimisticOccurrence,
    );
    _emitReady(optimisticToday, pendingOccurrenceId: draft.occurrenceId);
    final ChoreCommandId commandId = _retryId!;

    final SetChoreCompletionResult result;
    try {
      result = await _repository.setOccurrenceCompletion(
        draft.withId(commandId),
      );
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case ChoreCompletionSet(:final snapshot):
        final ChoreOccurrence reconciled = optimisticOccurrence.copyWith(
          status: snapshot.status,
          version: snapshot.version,
        );
        _clearRetry();
        _emitReady(originalToday.applyOccurrence(reconciled));
      case SetChoreCompletionFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case SetChoreCompletionFailed(:final failure)
          when failure.kind == ChoreFailureKind.temporarilyUnavailable &&
              draft.completed &&
              originalOccurrence.canSetCompletion &&
              _currentActorMemberId != null &&
              _completionOutbox.isAvailable:
        final bool queued = await _queueCompletionAfterTransientFailure(
          originalToday: originalToday,
          optimisticToday: optimisticToday,
          draft: draft,
          commandId: commandId,
          actorMemberId: _currentActorMemberId!,
        );
        if (!queued) {
          _emitReady(originalToday, actionFailure: failure);
        }
      case SetChoreCompletionFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _skipOccurrence(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    ChoreOccurrenceSkipDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: draft.occurrenceId);

    final SkipChoreOccurrenceResult result;
    try {
      result = await _repository.skipOccurrence(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case ChoreOccurrenceSkipped(:final snapshot):
        _clearRetry();
        _undoableSkip = UndoableChoreSkip(
          occurrence: originalOccurrence,
          skippedVersion: snapshot.version,
          insertionIndex: originalToday.occurrences.indexOf(originalOccurrence),
        );
        _emitReady(originalToday.removeOccurrence(snapshot.occurrenceId));
      case SkipChoreOccurrenceFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case SkipChoreOccurrenceFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _restoreSkippedOccurrence(
    TodayChores skippedToday,
    UndoableChoreSkip undoable,
    ChoreOccurrenceRestoreDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    final ChoreOccurrence optimisticOccurrence = undoable.occurrence.copyWith(
      status: ChoreOccurrenceStatus.scheduled,
      version: undoable.skippedVersion,
    );
    final TodayChores optimisticToday = skippedToday.insertOccurrenceAt(
      optimisticOccurrence,
      index: undoable.insertionIndex,
    );
    _emitReady(optimisticToday, pendingOccurrenceId: draft.occurrenceId);

    final RestoreSkippedChoreOccurrenceResult result;
    try {
      result = await _repository.restoreSkippedOccurrence(
        draft.withId(_retryId!),
      );
    } on Object {
      _emitReady(
        skippedToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case ChoreOccurrenceRestored(:final snapshot):
        final ChoreOccurrence reconciled = optimisticOccurrence.copyWith(
          version: snapshot.version,
        );
        _clearRetry();
        _undoableSkip = null;
        _emitReady(optimisticToday.replaceOccurrence(reconciled));
      case RestoreSkippedChoreOccurrenceFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        _clearRetry();
        await _reconcileRestoreFailure(
          skippedToday,
          draft.householdId,
          draft.occurrenceId,
          failure,
        );
      case RestoreSkippedChoreOccurrenceFailed(:final failure):
        _emitReady(skippedToday, actionFailure: failure);
    }
  }

  Future<void> _rescheduleOccurrence(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    ChoreOccurrenceRescheduleDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    final ChoreOccurrence optimisticOccurrence = originalOccurrence.rescheduled(
      dueLocalDate: draft.dueLocalDate,
      dueLocalTime: draft.dueLocalTime,
      dueAt: _optimisticDueAt(draft.dueLocalDate, draft.dueLocalTime),
    );
    final TodayChores optimisticToday = originalToday.applyReschedule(
      optimisticOccurrence,
    );
    _emitReady(optimisticToday, pendingOccurrenceId: draft.occurrenceId);

    final RescheduleChoreOccurrenceResult result;
    try {
      result = await _repository.rescheduleOccurrence(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case ChoreOccurrenceRescheduled(:final snapshot):
        final ChoreOccurrence reconciled = originalOccurrence.rescheduled(
          dueLocalDate: snapshot.dueLocalDate,
          dueLocalTime: snapshot.dueLocalTime,
          dueAt: snapshot.dueAt,
          version: snapshot.version,
        );
        _clearRetry();
        _emitReady(originalToday.applyReschedule(reconciled));
      case RescheduleChoreOccurrenceFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case RescheduleChoreOccurrenceFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _reassignOccurrence(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    ChoreOccurrenceReassignmentDraft draft,
    String assigneeDisplayName,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    final ChoreOccurrence optimisticOccurrence = originalOccurrence.reassigned(
      assigneeMemberId: draft.assigneeMemberId,
      assigneeDisplayName: assigneeDisplayName,
    );
    final TodayChores optimisticToday = originalToday.applyOccurrence(
      optimisticOccurrence,
    );
    _emitReady(optimisticToday, pendingOccurrenceId: draft.occurrenceId);

    final ReassignChoreOccurrenceResult result;
    try {
      result = await _repository.reassignOccurrence(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case ChoreOccurrenceReassigned(:final snapshot):
        final ChoreOccurrence reconciled = originalOccurrence.reassigned(
          assigneeMemberId: snapshot.assigneeMemberId,
          assigneeDisplayName: snapshot.assigneeDisplayName,
          version: snapshot.version,
        );
        _clearRetry();
        _emitReady(originalToday.applyOccurrence(reconciled));
      case ReassignChoreOccurrenceFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case ReassignChoreOccurrenceFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _updateRepeatingSeries(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    RepeatingChoreSeriesUpdateDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final UpdateRepeatingChoreSeriesResult result;
    try {
      result = await _repository.updateRepeatingSeries(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RepeatingChoreSeriesUpdated():
        await _reloadAfterSeriesSuccess(originalToday, draft.householdId);
      case UpdateRepeatingChoreSeriesFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case UpdateRepeatingChoreSeriesFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _updateRepeatingSeriesFromOccurrence(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    RepeatingChoreSeriesFromOccurrenceUpdateDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final UpdateRepeatingChoreSeriesResult result;
    try {
      result = await _repository.updateRepeatingSeriesFromOccurrence(
        draft.withId(_retryId!),
      );
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RepeatingChoreSeriesUpdated():
        await _reloadAfterSeriesSuccess(originalToday, draft.householdId);
      case UpdateRepeatingChoreSeriesFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case UpdateRepeatingChoreSeriesFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _updateOneTimeChore(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    OneTimeChoreUpdateDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final UpdateOneTimeChoreResult result;
    try {
      result = await _repository.updateOneTimeChore(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case OneTimeChoreUpdated():
        await _reloadAfterSeriesSuccess(originalToday, draft.householdId);
      case UpdateOneTimeChoreFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case UpdateOneTimeChoreFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _deleteOneTimeChore(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    OneTimeChoreDeletionDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final DeleteOneTimeChoreResult result;
    try {
      result = await _repository.deleteOneTimeChore(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case OneTimeChoreDeleted(:final snapshot):
        _clearRetry();
        _undoableDeletion = UndoableOneTimeChoreDeletion(
          occurrence: originalOccurrence,
          deletedSeriesVersion: snapshot.seriesVersion,
          deletedOccurrenceVersion: snapshot.occurrenceVersion,
        );
        await _reloadAfterDeletionSuccess(
          originalToday.removeOccurrence(snapshot.occurrenceId),
          draft.householdId,
        );
      case DeleteOneTimeChoreFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case DeleteOneTimeChoreFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _undoDeleteOneTimeChore(
    TodayChores deletedToday,
    OneTimeChoreRestoreDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(deletedToday, pendingOccurrenceId: draft.occurrenceId);

    final RestoreOneTimeChoreResult result;
    try {
      result = await _repository.restoreOneTimeChore(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        deletedToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case OneTimeChoreRestored():
        _clearRetry();
        _undoableDeletion = null;
        await _reloadAfterDeletionRestore(
          deletedToday,
          draft.householdId,
          draft.occurrenceId,
        );
      case RestoreOneTimeChoreFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        _clearRetry();
        _undoableDeletion = null;
        await _reconcileDeletionRestoreFailure(
          deletedToday,
          draft.householdId,
          draft.occurrenceId,
          failure,
        );
      case RestoreOneTimeChoreFailed(:final failure):
        _emitReady(deletedToday, actionFailure: failure);
    }
  }

  Future<void> _cancelRepeatingSeries(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    RepeatingChoreSeriesCancellationDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final CancelRepeatingChoreSeriesResult result;
    try {
      result = await _repository.cancelRepeatingSeries(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RepeatingChoreSeriesCancelled():
        await _reloadAfterSeriesSuccess(originalToday, draft.householdId);
      case CancelRepeatingChoreSeriesFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case CancelRepeatingChoreSeriesFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _cancelRepeatingSeriesFromOccurrence(
    TodayChores originalToday,
    ChoreOccurrence originalOccurrence,
    RepeatingChoreSeriesFromOccurrenceCancellationDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday, pendingOccurrenceId: originalOccurrence.id);

    final CancelRepeatingChoreSeriesFromOccurrenceResult result;
    try {
      result = await _repository.cancelRepeatingSeriesFromOccurrence(
        draft.withId(_retryId!),
      );
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RepeatingChoreSeriesCancelledFromOccurrence(:final snapshot):
        _undoableSeriesCancellation = UndoableRepeatingChoreSeriesCancellation(
          householdId: snapshot.householdId,
          seriesId: snapshot.seriesId,
          cancellationIdempotencyKey: _retryId!,
          cancellationVersion: snapshot.version,
          effectiveLocalDate: snapshot.effectiveLocalDate,
        );
        await _reloadAfterSeriesSuccess(originalToday, draft.householdId);
      case CancelRepeatingChoreSeriesFromOccurrenceFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition ||
              failure.kind == ChoreFailureKind.notFoundOrForbidden:
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case CancelRepeatingChoreSeriesFromOccurrenceFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _resumeRepeatingSeriesCancellation(
    TodayChores originalToday,
    ResumeRepeatingChoreSeriesCancellationDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(originalToday);

    final ResumeRepeatingChoreSeriesCancellationResult result;
    try {
      result = await _repository.resumeRepeatingSeriesCancellation(
        draft.withId(_retryId!),
      );
    } on Object {
      _emitReady(
        originalToday,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RepeatingChoreSeriesCancellationResumed():
        await _reloadAfterSeriesCancellationResumeSuccess(
          originalToday,
          draft.householdId,
        );
      case ResumeRepeatingChoreSeriesCancellationFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition ||
              failure.kind == ChoreFailureKind.notFoundOrForbidden ||
              failure.kind == ChoreFailureKind.idempotencyConflict ||
              failure.kind == ChoreFailureKind.unauthenticated ||
              failure.kind == ChoreFailureKind.invalidInput:
        _undoableSeriesCancellation = null;
        _clearRetry();
        await _reconcileFailure(originalToday, draft.householdId, failure);
      case ResumeRepeatingChoreSeriesCancellationFailed(:final failure):
        _emitReady(originalToday, actionFailure: failure);
    }
  }

  Future<void> _reloadAfterSeriesCancellationResumeSuccess(
    TodayChores fallback,
    HouseholdId householdId,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _emitReady(
        fallback,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _undoableSeriesCancellation = null;
        _clearRetry();
        _cacheMetadata = cacheMetadata;
        _emitReady(today);
      case LoadTodayChoresFailed(:final failure):
        _emitReady(fallback, actionFailure: failure);
    }
  }

  Future<void> _reloadAfterSeriesSuccess(
    TodayChores fallback,
    HouseholdId householdId,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _emitReady(
        fallback,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _clearRetry();
        _cacheMetadata = cacheMetadata;
        _emitReady(today);
      case LoadTodayChoresFailed(:final failure):
        _emitReady(fallback, actionFailure: failure);
    }
  }

  Future<void> _reloadAfterDeletionSuccess(
    TodayChores fallback,
    HouseholdId householdId,
  ) {
    return _reloadAfterSeriesSuccess(fallback, householdId);
  }

  Future<void> _reloadAfterDeletionRestore(
    TodayChores fallback,
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _emitReady(
        fallback,
        restoredDeletionOccurrenceId: occurrenceId,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _cacheMetadata = cacheMetadata;
        _emitReady(today, restoredDeletionOccurrenceId: occurrenceId);
      case LoadTodayChoresFailed(:final failure):
        _emitReady(
          fallback,
          restoredDeletionOccurrenceId: occurrenceId,
          actionFailure: failure,
        );
    }
  }

  Future<void> _reconcileFailure(
    TodayChores fallback,
    HouseholdId householdId,
    ChoreFailure actionFailure,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _emitReady(fallback, actionFailure: actionFailure);
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _cacheMetadata = cacheMetadata;
        _emitReady(today, actionFailure: actionFailure);
      case LoadTodayChoresFailed():
        _emitReady(fallback, actionFailure: actionFailure);
    }
  }

  Future<void> _reconcileRestoreFailure(
    TodayChores fallback,
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
    ChoreFailure actionFailure,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _undoableSkip = null;
      _emitReady(fallback, actionFailure: actionFailure);
      return;
    }
    _undoableSkip = null;
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _cacheMetadata = cacheMetadata;
        final ChoreOccurrence? occurrence = _findOccurrence(
          today,
          occurrenceId,
        );
        if (occurrence?.status == ChoreOccurrenceStatus.scheduled) {
          _emitReady(today);
        } else {
          _emitReady(today, actionFailure: actionFailure);
        }
      case LoadTodayChoresFailed():
        _emitReady(fallback, actionFailure: actionFailure);
    }
  }

  Future<void> _reconcileDeletionRestoreFailure(
    TodayChores fallback,
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
    ChoreFailure actionFailure,
  ) async {
    final LoadTodayChoresResult result;
    try {
      result = await _loadAuthoritative(householdId);
    } on Object {
      _emitReady(fallback, actionFailure: actionFailure);
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        _cacheMetadata = cacheMetadata;
        final ChoreOccurrence? occurrence = _findOccurrence(
          today,
          occurrenceId,
        );
        if (occurrence?.status == ChoreOccurrenceStatus.scheduled) {
          _emitReady(today, restoredDeletionOccurrenceId: occurrenceId);
        } else {
          _emitReady(today, actionFailure: actionFailure);
        }
      case LoadTodayChoresFailed():
        _emitReady(fallback, actionFailure: actionFailure);
    }
  }

  ChoreOccurrence? _findOccurrence(
    TodayChores today,
    ChoreOccurrenceId occurrenceId,
  ) {
    for (final ChoreOccurrence occurrence in today.occurrences) {
      if (occurrence.id == occurrenceId) {
        return occurrence;
      }
    }
    return null;
  }

  Future<LoadTodayChoresResult> _loadAuthoritative(HouseholdId householdId) {
    final ChoreListRequest? request = _currentRequest;
    return request != null && request.householdId == householdId
        ? _repository.loadChoreList(request.firstPage)
        : _repository.loadToday(householdId);
  }

  DateTime? _optimisticDueAt(
    ChoreLocalDate dueLocalDate,
    ChoreLocalTime? dueLocalTime,
  ) {
    if (dueLocalTime == null) {
      return null;
    }
    final DateTime date = dueLocalDate.toDateTime();
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      dueLocalTime.hour,
      dueLocalTime.minute,
    );
  }

  Future<void> _stopSyncAndLoad(ChoreListRequest request) async {
    await _syncSession.stop();
    if (_disposed || _currentRequest?.householdId != request.householdId) {
      return;
    }
    await _loadRequest(
      request,
      preserveContent: false,
      loadingAlreadyEmitted: true,
    );
  }

  Future<void> _ensureSync(HouseholdId householdId) async {
    if (_disposed ||
        _currentRequest?.householdId != householdId ||
        _state is! TodayChoresReady ||
        (_state as TodayChoresReady).today.householdId != householdId ||
        _syncedHouseholdId == householdId) {
      return;
    }
    _syncedHouseholdId = householdId;
    await _syncSession.start(householdId);
  }

  Future<void> _stopSyncAfterAuthorizationFailure() async {
    _syncedHouseholdId = null;
    await _syncSession.stop();
  }

  Future<void> _synchronize() async {
    if (_actionBusy) {
      await _pendingAction;
    }
    if (_loadBusy) {
      await _pendingLoad;
    }
    if (_disposed) {
      return;
    }
    await refresh();
  }

  void _setSyncStatus(ChoreSyncConnectionStatus status) {
    if (_disposed || _syncStatus == status) {
      return;
    }
    _syncStatus = status;
    final TodayChoresState current = _state;
    if (current case TodayChoresReady(
      :final today,
      :final pendingOccurrenceId,
      :final actionFailure,
      :final undoableSkip,
      :final undoableDeletion,
      :final undoableSeriesCancellation,
      :final restoredDeletionOccurrenceId,
      :final refreshing,
      :final refreshFailure,
      :final loadingMore,
      :final loadMoreFailure,
      :final cacheMetadata,
      :final completionSync,
    )) {
      _emit(
        TodayChoresReady(
          today,
          pendingOccurrenceId: pendingOccurrenceId,
          actionFailure: actionFailure,
          undoableSkip: undoableSkip,
          undoableDeletion: undoableDeletion,
          undoableSeriesCancellation: undoableSeriesCancellation,
          restoredDeletionOccurrenceId: restoredDeletionOccurrenceId,
          refreshing: refreshing,
          refreshFailure: refreshFailure,
          loadingMore: loadingMore,
          loadMoreFailure: loadMoreFailure,
          cacheMetadata: cacheMetadata,
          completionSync: completionSync,
          syncStatus: status,
        ),
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _syncSession.dispose();
    await Future.wait<void>(<Future<void>>[_pendingLoad, _pendingAction]);
    await _states.close();
  }

  void _clearRetry() {
    _retryFingerprint = null;
    _retryId = null;
  }

  void _rejectCachedMutation(TodayChoresReady ready) {
    _cacheMetadata = ready.cacheMetadata;
    _emitReady(
      ready.today,
      actionFailure: const ChoreFailure(ChoreFailureKind.offlineReadOnly),
    );
  }

  void _setCompletionSync(
    TodayChoreCompletionSyncKind kind,
    ChoreOccurrenceId occurrenceId,
  ) {
    _completionSync = TodayChoreCompletionSync(
      kind: kind,
      occurrenceId: occurrenceId,
    );
  }

  void _emitCompletionSyncIfReady() {
    final TodayChoresReady? ready = _state is TodayChoresReady
        ? _state as TodayChoresReady
        : null;
    if (ready == null) {
      return;
    }
    _cacheMetadata = ready.cacheMetadata;
    _emitReady(ready.today);
  }

  void _emitReady(
    TodayChores today, {
    ChoreOccurrenceId? pendingOccurrenceId,
    ChoreOccurrenceId? restoredDeletionOccurrenceId,
    ChoreFailure? actionFailure,
    bool refreshing = false,
    ChoreFailure? refreshFailure,
    bool loadingMore = false,
    ChoreFailure? loadMoreFailure,
  }) {
    _emit(
      TodayChoresReady(
        today,
        pendingOccurrenceId: pendingOccurrenceId,
        actionFailure: actionFailure,
        undoableSkip: _undoableSkip,
        undoableDeletion: _undoableDeletion,
        undoableSeriesCancellation: _undoableSeriesCancellation,
        restoredDeletionOccurrenceId: restoredDeletionOccurrenceId,
        refreshing: refreshing,
        refreshFailure: refreshFailure,
        loadingMore: loadingMore,
        loadMoreFailure: loadMoreFailure,
        cacheMetadata: _cacheMetadata,
        completionSync: _completionSync,
        syncStatus: _syncStatus,
      ),
    );
  }

  void _emit(TodayChoresState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
