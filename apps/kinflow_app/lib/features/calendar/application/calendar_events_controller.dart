import 'dart:async';

import 'package:kinflow_app/features/calendar/application/calendar_sync_session.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_state.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_occurrence_locator.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class CalendarEventsController {
  factory CalendarEventsController({
    required CalendarRepository repository,
    required CalendarCommandIdGenerator idGenerator,
    required CalendarTimeResolver timeResolver,
    CalendarSyncRepository? syncRepository,
  }) => CalendarEventsController._(
    repository,
    idGenerator,
    timeResolver,
    syncRepository,
  );

  CalendarEventsController._(
    this._repository,
    this._idGenerator,
    this._timeResolver,
    CalendarSyncRepository? syncRepository,
  ) {
    _syncSession = CalendarSyncSession(
      syncRepository,
      _synchronize,
      _setSyncStatus,
    );
  }

  final CalendarRepository _repository;
  final CalendarCommandIdGenerator _idGenerator;
  final CalendarTimeResolver _timeResolver;
  late final CalendarSyncSession _syncSession;
  final StreamController<CalendarEventsState> _states =
      StreamController<CalendarEventsState>.broadcast(sync: true);

  CalendarEventsState _state = const CalendarEventsInitial();
  Future<void> _pendingLoad = Future<void>.value();
  Future<void> _pendingAction = Future<void>.value();
  HouseholdId? _householdId;
  HouseholdId? _syncedHouseholdId;
  CalendarEventPageRequest? _currentPageRequest;
  CalendarMonthSummaryRequest? _currentMonthRequest;
  CalendarViewMode _currentViewMode = CalendarViewMode.agenda;
  CalendarLocalDate? _focusedDate;
  CalendarEventOccurrenceId? _highlightedOccurrenceId;
  CalendarSyncConnectionStatus _syncStatus =
      CalendarSyncConnectionStatus.disabled;
  String? _retryFingerprint;
  CalendarEventCommandId? _retryId;
  UndoableRecurringCalendarSeriesCancellation? _undoableSeriesCancellation;
  var _loadBusy = false;
  var _actionBusy = false;
  var _disposed = false;

  CalendarEventsState get state => _state;

  Stream<CalendarEventsState> get states => _states.stream;

  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) {
    return _repository.previewOverlaps(request);
  }

  Future<void> load(HouseholdId householdId) async {
    if (_householdId != householdId) {
      _undoableSeriesCancellation = null;
      _clearRetryState();
    }
    _highlightedOccurrenceId = null;
    await _startSelection(
      viewMode: CalendarViewMode.agenda,
      focusedDate: null,
      pageRequest: CalendarEventPageRequest.initialAgenda(householdId),
      monthRequest: null,
      preserveContent: false,
    );
    await _ensureSync(householdId);
  }

  Future<void> refresh() {
    final HouseholdId? householdId = _householdId;
    final CalendarEventOccurrenceId? highlighted = _highlightedOccurrenceId;
    if (householdId != null && highlighted != null) {
      return openOccurrence(householdId, highlighted);
    }
    final CalendarEventPageRequest? request = _currentPageRequest;
    final CalendarLocalDate? focusedDate = _focusedDate;
    if (request == null || focusedDate == null) {
      return Future<void>.value();
    }
    return _startSelection(
      viewMode: _currentViewMode,
      focusedDate: focusedDate,
      pageRequest: request.firstPage,
      monthRequest: _currentMonthRequest,
      preserveContent: true,
    );
  }

  Future<void> resume() => _syncSession.resume();

  Future<void> reconnect() => _syncSession.reconnect();

  Future<void> openOccurrence(
    HouseholdId householdId,
    CalendarEventOccurrenceId occurrenceId,
  ) async {
    if (_disposed) {
      return;
    }
    if (_householdId != householdId) {
      _undoableSeriesCancellation = null;
      _clearRetryState();
    }
    if (_actionBusy) {
      await _pendingAction;
    }
    if (_loadBusy) {
      await _pendingLoad;
    }
    if (_disposed) {
      return;
    }
    _householdId = householdId;
    _highlightedOccurrenceId = occurrenceId;
    _loadBusy = true;
    _pendingLoad = _loadOccurrence(
      householdId,
      occurrenceId,
    ).whenComplete(() => _loadBusy = false);
    await _pendingLoad;
    await _ensureSync(householdId);
  }

  Future<void> setView(CalendarViewMode viewMode) {
    final CalendarEventsReady? ready = _readyState;
    if (ready == null || ready.viewMode == viewMode) {
      return Future<void>.value();
    }
    return switch (viewMode) {
      CalendarViewMode.agenda => showAgenda(ready.focusedDate),
      CalendarViewMode.day => showDay(ready.focusedDate),
      CalendarViewMode.month => showMonth(
        ready.focusedDate.firstDayOfMonth,
        selectedDate: ready.focusedDate,
      ),
    };
  }

  Future<void> showAgenda(CalendarLocalDate startDate) {
    final HouseholdId? householdId = _householdId;
    if (householdId == null) {
      return Future<void>.value();
    }
    _highlightedOccurrenceId = null;
    final CalendarAllDayRange range = CalendarAllDayRange.tryCreate(
      startDate: startDate,
      endDateExclusive: startDate.addDays(90),
    )!;
    final CalendarEventPageRequest request = CalendarEventPageRequest.tryCreate(
      householdId: householdId,
      view: CalendarViewMode.agenda,
      range: range,
    )!;
    return _startSelection(
      viewMode: CalendarViewMode.agenda,
      focusedDate: startDate,
      pageRequest: request,
      monthRequest: null,
      preserveContent: false,
    );
  }

  Future<void> showDay(CalendarLocalDate date) {
    final HouseholdId? householdId = _householdId;
    if (householdId == null) {
      return Future<void>.value();
    }
    _highlightedOccurrenceId = null;
    return _startSelection(
      viewMode: CalendarViewMode.day,
      focusedDate: date,
      pageRequest: _dayRequest(householdId, date),
      monthRequest: null,
      preserveContent: false,
    );
  }

  Future<void> showMonth(
    CalendarLocalDate monthStartDate, {
    CalendarLocalDate? selectedDate,
  }) {
    final HouseholdId? householdId = _householdId;
    if (householdId == null || monthStartDate.day != 1) {
      return Future<void>.value();
    }
    _highlightedOccurrenceId = null;
    final CalendarLocalDate focusedDate =
        selectedDate == null || selectedDate.firstDayOfMonth != monthStartDate
        ? monthStartDate
        : selectedDate;
    final CalendarMonthSummaryRequest monthRequest =
        CalendarMonthSummaryRequest.tryCreate(
          householdId: householdId,
          monthStartDate: monthStartDate,
        )!;
    return _startSelection(
      viewMode: CalendarViewMode.month,
      focusedDate: focusedDate,
      pageRequest: _dayRequest(householdId, focusedDate),
      monthRequest: monthRequest,
      preserveContent: false,
    );
  }

  Future<void> selectMonthDate(CalendarLocalDate date) {
    final CalendarEventsReady? ready = _readyState;
    final CalendarMonthSummary? summary = ready?.monthSummary;
    if (ready == null ||
        ready.viewMode != CalendarViewMode.month ||
        summary == null ||
        date.firstDayOfMonth != summary.request.monthStartDate ||
        date == ready.focusedDate) {
      return Future<void>.value();
    }
    return _startSelection(
      viewMode: CalendarViewMode.month,
      focusedDate: date,
      pageRequest: _dayRequest(ready.page.householdId, date),
      monthRequest: summary.request,
      preserveContent: false,
      retainedMonthSummary: summary,
    );
  }

  Future<void> shiftRange(int delta) {
    final CalendarEventsReady? ready = _readyState;
    if (ready == null || delta == 0) {
      return Future<void>.value();
    }
    return switch (ready.viewMode) {
      CalendarViewMode.agenda => showAgenda(
        ready.page.range.startDate.addDays(ready.page.range.dayCount * delta),
      ),
      CalendarViewMode.day => showDay(ready.focusedDate.addDays(delta)),
      CalendarViewMode.month => showMonth(
        ready.focusedDate.firstDayOfMonth.addMonthsClamped(delta),
        selectedDate: ready.focusedDate.addMonthsClamped(delta),
      ),
    };
  }

  Future<void> goToToday() {
    final CalendarEventsReady? ready = _readyState;
    if (ready == null) {
      return Future<void>.value();
    }
    final CalendarLocalDate today = ready.page.householdLocalDate;
    return switch (ready.viewMode) {
      CalendarViewMode.agenda => showAgenda(today),
      CalendarViewMode.day => showDay(today),
      CalendarViewMode.month => showMonth(
        today.firstDayOfMonth,
        selectedDate: today,
      ),
    };
  }

  Future<void> loadMore() {
    if (_disposed || _actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final CalendarEventsReady? ready = _readyState;
    final CalendarPageCursor? cursor = ready?.page.nextCursor;
    final CalendarEventPageRequest? continuation =
        ready == null || cursor == null || !ready.page.hasMore
        ? null
        : ready.page.request.continuation(cursor);
    if (ready == null || continuation == null) {
      return Future<void>.value();
    }
    _loadBusy = true;
    _emitReady(ready, loadingMore: true);
    _pendingLoad = _loadContinuation(
      ready,
      continuation,
    ).whenComplete(() => _loadBusy = false);
    return _pendingLoad;
  }

  Future<void> create(OneTimeCalendarEventDraft draft) {
    final CalendarEventsReady? ready = _readyFor(draft.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final CalendarFailure? validationFailure = _validateTime(draft);
    if (validationFailure != null) {
      _emitReady(ready, actionFailure: validationFailure);
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint = 'create:${draft.fingerprint}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, creating: true);
    _pendingAction = _create(
      ready,
      draft.createRequest(commandId),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> createRecurring(RecurringCalendarEventDraft draft) {
    final CalendarEventsReady? ready = _readyFor(draft.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final CalendarFailure? validationFailure = _validateTime(draft.event);
    if (validationFailure != null) {
      _emitReady(ready, actionFailure: validationFailure);
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint = 'create-recurring:${draft.fingerprint}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, creating: true);
    _pendingAction = _createRecurring(
      ready,
      draft.createRequest(commandId),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<RecurringCalendarSeriesDetail?> loadSeriesForEdit(
    OneTimeCalendarEvent current,
  ) async {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null || _actionBusy || _loadBusy) {
      return null;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventBySeries(
      current.seriesId,
    );
    if (latest == null ||
        !latest.isRecurring ||
        latest.version != current.version) {
      await _startConflictRecovery(ready, current.occurrenceId);
      return null;
    }
    _undoableSeriesCancellation = null;
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    try {
      final LoadRecurringCalendarSeriesResult result = await _repository
          .loadRecurringSeries(
            householdId: current.householdId,
            seriesId: current.seriesId,
          );
      switch (result) {
        case RecurringCalendarSeriesLoaded(:final detail)
            when detail.version == latest.version:
          _emitReady(ready);
          return detail;
        case RecurringCalendarSeriesLoaded():
          await _handleMutationFailure(
            ready,
            const CalendarFailure(CalendarFailureKind.staleVersion),
            current.occurrenceId,
          );
          return null;
        case LoadRecurringCalendarSeriesFailed(:final failure):
          await _handleMutationFailure(ready, failure, current.occurrenceId);
          return null;
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
      return null;
    } finally {
      _actionBusy = false;
    }
  }

  Future<void> updateSeries({
    required RecurringCalendarSeriesDetail current,
    required RecurringCalendarEventDraft draft,
  }) {
    final CalendarEventsReady? ready = _readyFor(draft.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventBySeries(
      current.seriesId,
    );
    if (current.householdId != draft.householdId ||
        latest == null ||
        !latest.isRecurring ||
        latest.version != current.version) {
      return _startConflictRecovery(ready, latest?.occurrenceId);
    }
    final CalendarRecurrenceEnd recurrenceEnd = draft.recurrenceRule.end;
    if (recurrenceEnd is CalendarRecurrenceUntilEnd &&
        recurrenceEnd.localDate.compareTo(current.householdLocalDate) < 0) {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    final CalendarFailure? validationFailure = _validateTime(draft.event);
    if (validationFailure != null) {
      _emitReady(ready, actionFailure: validationFailure);
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'update-series:${current.seriesId.value}:${current.version}:'
        '${draft.fingerprint}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _updateSeries(
      ready,
      current.updateRequest(idempotencyKey: commandId, updatedDraft: draft),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> updateSeriesFromOccurrence({
    required OneTimeCalendarEvent current,
    required RecurringCalendarSeriesDetail series,
    required RecurringCalendarEventDraft draft,
  }) {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventByOccurrence(
      current.occurrenceId,
    );
    if (series.householdId != current.householdId ||
        series.seriesId != current.seriesId ||
        series.version != current.version ||
        latest == null ||
        !latest.isRecurring ||
        latest.isException ||
        latest.seriesId != current.seriesId ||
        latest.version != current.version ||
        latest.occurrenceVersion != current.occurrenceVersion ||
        latest.revisionNumber != series.revisionNumber) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    final RecurringCalendarSeriesFromOccurrenceUpdateDraft? update =
        RecurringCalendarSeriesFromOccurrenceUpdateDraft.tryCreate(
          householdId: current.householdId,
          seriesId: current.seriesId,
          effectiveOccurrenceId: current.occurrenceId,
          effectiveLocalDate: current.recurrenceLocalStartDate,
          householdLocalDate: ready.page.householdLocalDate,
          expectedVersion: current.version,
          draft: draft,
        );
    final CalendarFailure? validationFailure = _validateTime(draft.event);
    if (update == null || validationFailure != null) {
      _emitReady(
        ready,
        actionFailure:
            validationFailure ??
            const CalendarFailure(CalendarFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint = update.fingerprint;
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _updateSeriesFromOccurrence(
      ready,
      update.withId(commandId),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> cancelSeries(OneTimeCalendarEvent current) {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventBySeries(
      current.seriesId,
    );
    if (latest == null ||
        !latest.isRecurring ||
        latest.version != current.version) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'cancel-series:${current.householdId.value}:'
        '${current.seriesId.value}:${current.version}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _cancelSeries(
      ready,
      CancelRecurringCalendarSeriesRequest(
        idempotencyKey: commandId,
        householdId: current.householdId,
        seriesId: current.seriesId,
        expectedVersion: current.version,
      ),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> cancelSeriesFromOccurrence({
    required OneTimeCalendarEvent current,
    required RecurringCalendarSeriesDetail series,
  }) {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventByOccurrence(
      current.occurrenceId,
    );
    if (series.householdId != current.householdId ||
        series.seriesId != current.seriesId ||
        series.version != current.version ||
        latest == null ||
        !latest.isRecurring ||
        latest.isException ||
        latest.seriesId != current.seriesId ||
        latest.version != current.version ||
        latest.occurrenceVersion != current.occurrenceVersion ||
        latest.revisionNumber != series.revisionNumber) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    final RecurringCalendarSeriesFromOccurrenceCancellationDraft? draft =
        RecurringCalendarSeriesFromOccurrenceCancellationDraft.tryCreate(
          householdId: current.householdId,
          seriesId: current.seriesId,
          effectiveOccurrenceId: current.occurrenceId,
          effectiveLocalDate: current.recurrenceLocalStartDate,
          householdLocalDate: ready.page.householdLocalDate,
          expectedVersion: current.version,
        );
    if (draft == null) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    _undoableSeriesCancellation = null;
    final String fingerprint = draft.fingerprint;
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _cancelSeriesFromOccurrence(
      ready,
      draft.withId(commandId),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> resumeSeriesCancellation({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
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
    final CalendarEventsReady? ready = _readyFor(householdId);
    final UndoableRecurringCalendarSeriesCancellation? undoable =
        _undoableSeriesCancellation;
    if (ready == null ||
        undoable == null ||
        undoable.householdId != householdId ||
        undoable.seriesId != seriesId) {
      return Future<void>.value();
    }
    final ResumeRecurringCalendarSeriesCancellationDraft? draft =
        ResumeRecurringCalendarSeriesCancellationDraft.tryCreate(
          householdId: householdId,
          seriesId: seriesId,
          cancellationIdempotencyKey: undoable.cancellationIdempotencyKey,
          expectedVersion: undoable.cancellationVersion,
        );
    if (draft == null) {
      _undoableSeriesCancellation = null;
      _clearRetryState();
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: seriesId);
    _pendingAction = _resumeSeriesCancellation(
      ready,
      draft,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> update({
    required OneTimeCalendarEvent current,
    required OneTimeCalendarEventDraft draft,
  }) {
    final CalendarEventsReady? ready = _readyFor(draft.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventBySeries(
      current.seriesId,
    );
    if (latest == null || latest.version != current.version) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    final CalendarFailure? validationFailure = _validateTime(draft);
    if (validationFailure != null) {
      _emitReady(ready, actionFailure: validationFailure);
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'update:${current.seriesId.value}:${current.version}:'
        '${draft.fingerprint}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _update(
      ready,
      draft.updateRequest(
        idempotencyKey: commandId,
        seriesId: current.seriesId,
        occurrenceId: current.occurrenceId,
        expectedVersion: current.version,
      ),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> updateOccurrence({
    required OneTimeCalendarEvent current,
    required OneTimeCalendarEventDraft draft,
  }) {
    final CalendarEventsReady? ready = _readyFor(draft.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventByOccurrence(
      current.occurrenceId,
    );
    if (latest == null ||
        !latest.isRecurring ||
        latest.occurrenceVersion != current.occurrenceVersion) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    final CalendarFailure? validationFailure = _validateTime(draft);
    if (validationFailure != null) {
      _emitReady(ready, actionFailure: validationFailure);
      return Future<void>.value();
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'update-occurrence:${current.seriesId.value}:'
        '${current.occurrenceId.value}:${current.occurrenceVersion}:'
        '${draft.fingerprint}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingOccurrenceId: current.occurrenceId);
    _pendingAction = _updateOccurrence(
      ready,
      draft.updateOccurrenceRequest(
        idempotencyKey: commandId,
        seriesId: current.seriesId,
        occurrenceId: current.occurrenceId,
        expectedOccurrenceVersion: current.occurrenceVersion,
      ),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> cancelOccurrence(OneTimeCalendarEvent current) {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventByOccurrence(
      current.occurrenceId,
    );
    if (latest == null ||
        !latest.isRecurring ||
        latest.occurrenceVersion != current.occurrenceVersion) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'cancel-occurrence:${current.householdId.value}:'
        '${current.seriesId.value}:${current.occurrenceId.value}:'
        '${current.occurrenceVersion}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingOccurrenceId: current.occurrenceId);
    _pendingAction = _cancelOccurrence(
      ready,
      CancelRecurringCalendarOccurrenceRequest(
        idempotencyKey: commandId,
        householdId: current.householdId,
        seriesId: current.seriesId,
        occurrenceId: current.occurrenceId,
        expectedOccurrenceVersion: current.occurrenceVersion,
      ),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> delete(OneTimeCalendarEvent current) {
    final CalendarEventsReady? ready = _readyFor(current.householdId);
    if (_disposed || ready == null) {
      return Future<void>.value();
    }
    if (_actionBusy) {
      return _pendingAction;
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    final OneTimeCalendarEvent? latest = ready.page.eventBySeries(
      current.seriesId,
    );
    if (latest == null || latest.version != current.version) {
      return _startConflictRecovery(ready, current.occurrenceId);
    }
    _undoableSeriesCancellation = null;
    final String fingerprint =
        'delete:${current.householdId.value}:${current.seriesId.value}:'
        '${current.version}';
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    _actionBusy = true;
    _emitReady(ready, pendingSeriesId: current.seriesId);
    _pendingAction = _delete(
      ready,
      DeleteOneTimeCalendarEventRequest(
        idempotencyKey: commandId,
        householdId: current.householdId,
        seriesId: current.seriesId,
        occurrenceId: current.occurrenceId,
        expectedVersion: current.version,
      ),
      fingerprint,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  CalendarEventPageRequest _dayRequest(
    HouseholdId householdId,
    CalendarLocalDate date, {
    int limit = 30,
  }) {
    return CalendarEventPageRequest.tryCreate(
      householdId: householdId,
      view: CalendarViewMode.day,
      range: CalendarAllDayRange.tryCreate(
        startDate: date,
        endDateExclusive: date.addDays(1),
      ),
      limit: limit,
    )!;
  }

  Future<void> _loadOccurrence(
    HouseholdId householdId,
    CalendarEventOccurrenceId occurrenceId,
  ) async {
    final CalendarEventsReady? previous = _readyState;
    if (previous == null || previous.page.householdId != householdId) {
      _emit(const CalendarEventsLoading(CalendarViewMode.day));
    } else {
      _emitReady(previous, refreshing: true);
    }

    final LoadCalendarOccurrenceLocatorResult locatorResult;
    try {
      locatorResult = await _repository.loadOccurrenceLocator(
        householdId: householdId,
        occurrenceId: occurrenceId,
      );
    } on Object {
      _emitOccurrenceLoadFailure(
        previous,
        occurrenceId,
        const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    if (locatorResult case LoadCalendarOccurrenceLocatorFailed(
      :final failure,
    )) {
      _emitOccurrenceLoadFailure(previous, occurrenceId, failure);
      return;
    }
    final CalendarOccurrenceLocator locator =
        (locatorResult as CalendarOccurrenceLocatorLoaded).locator;
    final CalendarEventPageRequest request = _dayRequest(
      householdId,
      locator.viewLocalDate,
      limit: 100,
    );
    final _CalendarSelectionResult selection = await _fetchSelection(
      viewMode: CalendarViewMode.day,
      focusedDate: locator.viewLocalDate,
      pageRequest: request,
      monthRequest: null,
    );
    final CalendarEventPage? selectedPage = selection.page;
    if (selection.failure != null || selectedPage == null) {
      _emitOccurrenceLoadFailure(
        previous,
        occurrenceId,
        selection.failure ??
            const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    CalendarEventPage page = selectedPage;
    if (page.householdTimeZone != locator.householdTimeZone ||
        page.householdLocalDate != locator.householdLocalDate) {
      _emitOccurrenceLoadFailure(
        previous,
        occurrenceId,
        const CalendarFailure(CalendarFailureKind.invalidPayload),
      );
      return;
    }
    var loadedCount = page.items.length;
    while (page.eventByOccurrence(occurrenceId) == null &&
        page.hasMore &&
        loadedCount < 500) {
      final CalendarPageCursor? cursor = page.nextCursor;
      final CalendarEventPageRequest? continuation = cursor == null
          ? null
          : page.request.continuation(cursor);
      if (continuation == null) {
        _emitOccurrenceLoadFailure(
          previous,
          occurrenceId,
          const CalendarFailure(CalendarFailureKind.invalidPayload),
        );
        return;
      }
      final LoadCalendarEventPageResult continuationResult;
      try {
        continuationResult = await _repository.loadEventPage(continuation);
      } on Object {
        _emitOccurrenceLoadFailure(
          previous,
          occurrenceId,
          const CalendarFailure(CalendarFailureKind.internal),
        );
        return;
      }
      if (continuationResult case LoadCalendarEventPageFailed(:final failure)) {
        _emitOccurrenceLoadFailure(previous, occurrenceId, failure);
        return;
      }
      final CalendarEventPage? merged = page.appendPage(
        (continuationResult as CalendarEventPageLoaded).page,
      );
      if (merged == null) {
        _emitOccurrenceLoadFailure(
          previous,
          occurrenceId,
          const CalendarFailure(CalendarFailureKind.invalidPayload),
        );
        return;
      }
      page = merged;
      loadedCount = page.items.length;
    }
    if (page.eventByOccurrence(occurrenceId) == null) {
      if (page.hasMore) {
        _emitOccurrenceLoadFailure(
          previous,
          occurrenceId,
          const CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      } else {
        _emit(CalendarEventsTargetUnavailable(occurrenceId));
      }
      return;
    }
    _currentViewMode = CalendarViewMode.day;
    _focusedDate = locator.viewLocalDate;
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = null;
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: CalendarViewMode.day,
        focusedDate: locator.viewLocalDate,
        monthSummary: null,
        syncStatus: _syncStatus,
        highlightedOccurrenceId: occurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  void _emitOccurrenceLoadFailure(
    CalendarEventsReady? previous,
    CalendarEventOccurrenceId occurrenceId,
    CalendarFailure failure,
  ) {
    if (failure.kind == CalendarFailureKind.notFoundOrForbidden) {
      _emit(CalendarEventsTargetUnavailable(occurrenceId));
    } else if (previous != null) {
      _emitReady(previous, refreshFailure: failure);
    } else {
      _emit(CalendarEventsLoadFailed(failure, CalendarViewMode.day));
    }
  }

  Future<void> _startSelection({
    required CalendarViewMode viewMode,
    required CalendarLocalDate? focusedDate,
    required CalendarEventPageRequest pageRequest,
    required CalendarMonthSummaryRequest? monthRequest,
    required bool preserveContent,
    CalendarMonthSummary? retainedMonthSummary,
  }) {
    if (_disposed || _actionBusy) {
      return _actionBusy ? _pendingAction : Future<void>.value();
    }
    if (_loadBusy) {
      return _pendingLoad;
    }
    _householdId = pageRequest.householdId;
    _loadBusy = true;
    _pendingLoad = _loadSelection(
      viewMode: viewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest.firstPage,
      monthRequest: monthRequest,
      preserveContent: preserveContent,
      retainedMonthSummary: retainedMonthSummary,
    ).whenComplete(() => _loadBusy = false);
    return _pendingLoad;
  }

  Future<void> _loadSelection({
    required CalendarViewMode viewMode,
    required CalendarLocalDate? focusedDate,
    required CalendarEventPageRequest pageRequest,
    required CalendarMonthSummaryRequest? monthRequest,
    required bool preserveContent,
    CalendarMonthSummary? retainedMonthSummary,
  }) async {
    final CalendarEventsReady? previous = preserveContent ? _readyState : null;
    if (previous == null) {
      _emit(CalendarEventsLoading(viewMode));
    } else {
      _emitReady(previous, refreshing: true);
    }
    final _CalendarSelectionResult result = await _fetchSelection(
      viewMode: viewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest,
      monthRequest: monthRequest,
      retainedMonthSummary: retainedMonthSummary,
    );
    final CalendarFailure? failure = result.failure;
    final CalendarEventPage? page = result.page;
    final CalendarLocalDate? resolvedFocus = result.focusedDate;
    if (failure != null || page == null || resolvedFocus == null) {
      final CalendarFailure resolvedFailure =
          failure ?? const CalendarFailure(CalendarFailureKind.internal);
      if (previous == null || resolvedFailure.invalidatesRetainedContent) {
        _emit(CalendarEventsLoadFailed(resolvedFailure, viewMode));
      } else {
        _emitReady(previous, refreshFailure: resolvedFailure);
      }
      return;
    }
    _currentViewMode = viewMode;
    _focusedDate = resolvedFocus;
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = result.monthSummary?.request;
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: viewMode,
        focusedDate: resolvedFocus,
        monthSummary: result.monthSummary,
        syncStatus: _syncStatus,
        highlightedOccurrenceId: _highlightedOccurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  Future<_CalendarSelectionResult> _fetchSelection({
    required CalendarViewMode viewMode,
    required CalendarLocalDate? focusedDate,
    required CalendarEventPageRequest pageRequest,
    required CalendarMonthSummaryRequest? monthRequest,
    CalendarMonthSummary? retainedMonthSummary,
  }) async {
    final LoadCalendarEventPageResult pageResult;
    try {
      pageResult = await _repository.loadEventPage(pageRequest);
    } on Object {
      return const _CalendarSelectionResult.failure(
        CalendarFailure(CalendarFailureKind.internal),
      );
    }
    final CalendarEventPage page;
    switch (pageResult) {
      case CalendarEventPageLoaded(page: final loadedPage):
        page = loadedPage;
      case LoadCalendarEventPageFailed(:final failure):
        return _CalendarSelectionResult.failure(failure);
    }
    final CalendarLocalDate resolvedFocus = focusedDate ?? page.range.startDate;
    final bool pageShapeValid = switch (viewMode) {
      CalendarViewMode.agenda =>
        page.request.view == CalendarViewMode.agenda &&
            page.range.contains(resolvedFocus),
      CalendarViewMode.day || CalendarViewMode.month =>
        page.request.view == CalendarViewMode.day &&
            page.range.dayCount == 1 &&
            page.range.startDate == resolvedFocus,
    };
    if (!pageShapeValid || page.householdId != pageRequest.householdId) {
      return const _CalendarSelectionResult.failure(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    CalendarMonthSummary? monthSummary = retainedMonthSummary;
    if (viewMode == CalendarViewMode.month && monthSummary == null) {
      if (monthRequest == null) {
        return const _CalendarSelectionResult.failure(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      final LoadCalendarMonthSummaryResult monthResult;
      try {
        monthResult = await _repository.loadMonthSummary(monthRequest);
      } on Object {
        return const _CalendarSelectionResult.failure(
          CalendarFailure(CalendarFailureKind.internal),
        );
      }
      switch (monthResult) {
        case CalendarMonthSummaryLoaded(:final summary):
          monthSummary = summary;
        case LoadCalendarMonthSummaryFailed(:final failure):
          return _CalendarSelectionResult.failure(failure);
      }
    }
    if (viewMode == CalendarViewMode.month) {
      if (monthSummary == null ||
          monthSummary.request.householdId != page.householdId ||
          monthSummary.request.monthStartDate !=
              resolvedFocus.firstDayOfMonth ||
          monthSummary.householdTimeZone != page.householdTimeZone ||
          monthSummary.householdLocalDate != page.householdLocalDate) {
        return const _CalendarSelectionResult.failure(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
    } else if (monthSummary != null || monthRequest != null) {
      return const _CalendarSelectionResult.failure(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    return _CalendarSelectionResult.success(
      page: page,
      focusedDate: resolvedFocus,
      monthSummary: monthSummary,
    );
  }

  Future<void> _loadContinuation(
    CalendarEventsReady ready,
    CalendarEventPageRequest request,
  ) async {
    final LoadCalendarEventPageResult result;
    try {
      result = await _repository.loadEventPage(request);
    } on Object {
      _emitReady(
        ready,
        loadMoreFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case CalendarEventPageLoaded(:final page):
        final CalendarEventPage? merged = ready.page.appendPage(page);
        if (merged == null) {
          _emitReady(
            ready,
            loadMoreFailure: const CalendarFailure(
              CalendarFailureKind.invalidPayload,
            ),
          );
        } else {
          _emitReady(ready, page: merged);
        }
      case LoadCalendarEventPageFailed(:final failure):
        if (failure.invalidatesRetainedContent) {
          _emit(CalendarEventsLoadFailed(failure, ready.viewMode));
        } else {
          _emitReady(ready, loadMoreFailure: failure);
        }
    }
  }

  Future<void> _create(
    CalendarEventsReady ready,
    CreateOneTimeCalendarEventRequest request,
    String fingerprint,
  ) async {
    try {
      final CreateOneTimeCalendarEventResult result = await _repository
          .createOneTimeEvent(request);
      switch (result) {
        case OneTimeCalendarEventCreated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case CreateOneTimeCalendarEventFailed(:final failure):
          _emitReady(ready, actionFailure: failure);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _createRecurring(
    CalendarEventsReady ready,
    CreateRecurringCalendarEventRequest request,
    String fingerprint,
  ) async {
    try {
      final CreateRecurringCalendarEventResult result = await _repository
          .createRecurringEvent(request);
      switch (result) {
        case RecurringCalendarEventCreated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case CreateRecurringCalendarEventFailed(:final failure):
          _emitReady(ready, actionFailure: failure);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _updateSeries(
    CalendarEventsReady ready,
    UpdateRecurringCalendarSeriesRequest request,
    String fingerprint,
  ) async {
    try {
      final UpdateRecurringCalendarSeriesResult result = await _repository
          .updateRecurringSeries(request);
      switch (result) {
        case RecurringCalendarSeriesUpdated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case UpdateRecurringCalendarSeriesFailed(:final failure):
          await _handleMutationFailure(
            ready,
            failure,
            ready.page.eventBySeries(request.seriesId)!.occurrenceId,
          );
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _cancelSeries(
    CalendarEventsReady ready,
    CancelRecurringCalendarSeriesRequest request,
    String fingerprint,
  ) async {
    try {
      final CancelRecurringCalendarSeriesResult result = await _repository
          .cancelRecurringSeries(request);
      switch (result) {
        case RecurringCalendarSeriesCancelled():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case CancelRecurringCalendarSeriesFailed(:final failure):
          await _handleMutationFailure(
            ready,
            failure,
            ready.page.eventBySeries(request.seriesId)!.occurrenceId,
          );
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _cancelSeriesFromOccurrence(
    CalendarEventsReady ready,
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
    String fingerprint,
  ) async {
    try {
      final CancelRecurringCalendarSeriesFromOccurrenceResult result =
          await _repository.cancelRecurringSeriesFromOccurrence(request);
      switch (result) {
        case RecurringCalendarSeriesCancelledFromOccurrence(:final snapshot):
          _undoableSeriesCancellation =
              UndoableRecurringCalendarSeriesCancellation(
                householdId: snapshot.householdId,
                seriesId: snapshot.seriesId,
                cancellationIdempotencyKey: request.idempotencyKey,
                cancellationVersion: snapshot.version,
                effectiveLocalDate: snapshot.effectiveLocalDate,
              );
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case CancelRecurringCalendarSeriesFromOccurrenceFailed(:final failure):
          await _handleMutationFailure(
            ready,
            failure,
            request.effectiveOccurrenceId,
          );
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _resumeSeriesCancellation(
    CalendarEventsReady ready,
    ResumeRecurringCalendarSeriesCancellationDraft draft,
  ) async {
    final String fingerprint = draft.fingerprint;
    final CalendarEventCommandId commandId = _commandId(fingerprint);
    final ResumeRecurringCalendarSeriesCancellationResult result;
    try {
      result = await _repository.resumeRecurringSeriesCancellation(
        draft.withId(commandId),
      );
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }

    switch (result) {
      case RecurringCalendarSeriesCancellationResumed():
        await _refreshAfterSeriesCancellationResumeSuccess(ready, fingerprint);
      case ResumeRecurringCalendarSeriesCancellationFailed(:final failure)
          when failure.kind == CalendarFailureKind.staleVersion ||
              failure.kind == CalendarFailureKind.transitionNotAllowed ||
              failure.kind == CalendarFailureKind.notFoundOrForbidden ||
              failure.kind == CalendarFailureKind.idempotencyConflict ||
              failure.kind == CalendarFailureKind.unauthenticated ||
              failure.kind == CalendarFailureKind.invalidInput:
        _undoableSeriesCancellation = null;
        _clearRetryState();
        await _reconcileSeriesCancellationResumeFailure(ready, failure);
      case ResumeRecurringCalendarSeriesCancellationFailed(:final failure):
        _emitReady(ready, actionFailure: failure);
    }
  }

  Future<void> _updateSeriesFromOccurrence(
    CalendarEventsReady ready,
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
    String fingerprint,
  ) async {
    try {
      final UpdateRecurringCalendarSeriesResult result = await _repository
          .updateRecurringSeriesFromOccurrence(request);
      switch (result) {
        case RecurringCalendarSeriesUpdated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case UpdateRecurringCalendarSeriesFailed(:final failure):
          await _handleMutationFailure(
            ready,
            failure,
            request.effectiveOccurrenceId,
          );
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _update(
    CalendarEventsReady ready,
    UpdateOneTimeCalendarEventRequest request,
    String fingerprint,
  ) async {
    try {
      final UpdateOneTimeCalendarEventResult result = await _repository
          .updateOneTimeEvent(request);
      switch (result) {
        case OneTimeCalendarEventUpdated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case UpdateOneTimeCalendarEventFailed(:final failure):
          await _handleMutationFailure(ready, failure, request.occurrenceId);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _delete(
    CalendarEventsReady ready,
    DeleteOneTimeCalendarEventRequest request,
    String fingerprint,
  ) async {
    try {
      final DeleteOneTimeCalendarEventResult result = await _repository
          .deleteOneTimeEvent(request);
      switch (result) {
        case OneTimeCalendarEventDeleted():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case DeleteOneTimeCalendarEventFailed(:final failure):
          await _handleMutationFailure(ready, failure, request.occurrenceId);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _updateOccurrence(
    CalendarEventsReady ready,
    UpdateRecurringCalendarOccurrenceRequest request,
    String fingerprint,
  ) async {
    try {
      final UpdateRecurringCalendarOccurrenceResult result = await _repository
          .updateRecurringOccurrence(request);
      switch (result) {
        case RecurringCalendarOccurrenceUpdated():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case UpdateRecurringCalendarOccurrenceFailed(:final failure):
          await _handleMutationFailure(ready, failure, request.occurrenceId);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  Future<void> _cancelOccurrence(
    CalendarEventsReady ready,
    CancelRecurringCalendarOccurrenceRequest request,
    String fingerprint,
  ) async {
    try {
      final CancelRecurringCalendarOccurrenceResult result = await _repository
          .cancelRecurringOccurrence(request);
      switch (result) {
        case RecurringCalendarOccurrenceCancelled():
          _clearRetry(fingerprint);
          await _refreshAfterMutation(ready);
        case CancelRecurringCalendarOccurrenceFailed(:final failure):
          await _handleMutationFailure(ready, failure, request.occurrenceId);
      }
    } on Object {
      _emitReady(
        ready,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
    }
  }

  bool _isRecoverableMutationFailure(CalendarFailure failure) {
    return failure.kind == CalendarFailureKind.staleVersion ||
        failure.kind == CalendarFailureKind.notFoundOrForbidden;
  }

  Future<void> _handleMutationFailure(
    CalendarEventsReady fallback,
    CalendarFailure failure,
    CalendarEventOccurrenceId? occurrenceId,
  ) async {
    if (!_isRecoverableMutationFailure(failure)) {
      _emitReady(fallback, actionFailure: failure);
      return;
    }
    final CalendarEventPageRequest? pageRequest = _currentPageRequest;
    final CalendarLocalDate? focusedDate = _focusedDate;
    if (pageRequest == null || focusedDate == null) {
      _emitReady(fallback, actionFailure: failure);
      return;
    }
    _emitReady(fallback, refreshing: true);
    final CalendarConflictResolution resolution;
    if (occurrenceId == null) {
      resolution = CalendarConflictResolution.targetUnavailable;
    } else {
      final LoadCalendarOccurrenceLocatorResult locatorResult;
      try {
        locatorResult = await _repository.loadOccurrenceLocator(
          householdId: fallback.page.householdId,
          occurrenceId: occurrenceId,
        );
      } on Object {
        _emitReady(
          fallback,
          actionFailure: failure,
          refreshFailure: const CalendarFailure(CalendarFailureKind.internal),
        );
        return;
      }
      switch (locatorResult) {
        case CalendarOccurrenceLocatorLoaded():
          resolution = CalendarConflictResolution.latestReloaded;
        case LoadCalendarOccurrenceLocatorFailed(
          failure: CalendarFailure(
            kind: CalendarFailureKind.notFoundOrForbidden,
          ),
        ):
          resolution = CalendarConflictResolution.targetUnavailable;
        case LoadCalendarOccurrenceLocatorFailed(failure: final locatorFailure):
          if (locatorFailure.invalidatesRetainedContent) {
            _emit(CalendarEventsLoadFailed(locatorFailure, _currentViewMode));
            return;
          }
          _emitReady(
            fallback,
            actionFailure: failure,
            refreshFailure: locatorFailure,
          );
          return;
      }
    }
    final _CalendarSelectionResult selection = await _fetchSelection(
      viewMode: _currentViewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest.firstPage,
      monthRequest: _currentMonthRequest,
    );
    final CalendarEventPage? page = selection.page;
    final CalendarLocalDate? resolvedFocus = selection.focusedDate;
    if (selection.failure != null || page == null || resolvedFocus == null) {
      final CalendarFailure refreshFailure =
          selection.failure ??
          const CalendarFailure(CalendarFailureKind.internal);
      if (refreshFailure.invalidatesRetainedContent) {
        _emit(CalendarEventsLoadFailed(refreshFailure, _currentViewMode));
        return;
      }
      _emitReady(
        fallback,
        actionFailure: failure,
        refreshFailure: refreshFailure,
      );
      return;
    }
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = selection.monthSummary?.request;
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: _currentViewMode,
        focusedDate: resolvedFocus,
        monthSummary: selection.monthSummary,
        syncStatus: _syncStatus,
        conflictResolution: resolution,
        highlightedOccurrenceId: _highlightedOccurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  Future<void> _startConflictRecovery(
    CalendarEventsReady ready,
    CalendarEventOccurrenceId? occurrenceId,
  ) {
    if (_actionBusy) {
      return _pendingAction;
    }
    _actionBusy = true;
    _pendingAction = _handleMutationFailure(
      ready,
      const CalendarFailure(CalendarFailureKind.staleVersion),
      occurrenceId,
    ).whenComplete(() => _actionBusy = false);
    return _pendingAction;
  }

  Future<void> _refreshAfterSeriesCancellationResumeSuccess(
    CalendarEventsReady fallback,
    String fingerprint,
  ) async {
    final CalendarEventPageRequest? pageRequest = _currentPageRequest;
    final CalendarLocalDate? focusedDate = _focusedDate;
    if (pageRequest == null || focusedDate == null) {
      _emitReady(
        fallback,
        actionFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    _emitReady(fallback, refreshing: true);
    final _CalendarSelectionResult result = await _fetchSelection(
      viewMode: _currentViewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest.firstPage,
      monthRequest: _currentMonthRequest,
    );
    final CalendarEventPage? page = result.page;
    final CalendarLocalDate? resolvedFocus = result.focusedDate;
    if (result.failure != null || page == null || resolvedFocus == null) {
      _emitReady(
        fallback,
        actionFailure:
            result.failure ??
            const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = result.monthSummary?.request;
    _undoableSeriesCancellation = null;
    _clearRetry(fingerprint);
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: _currentViewMode,
        focusedDate: resolvedFocus,
        monthSummary: result.monthSummary,
        syncStatus: _syncStatus,
        highlightedOccurrenceId: _highlightedOccurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  Future<void> _reconcileSeriesCancellationResumeFailure(
    CalendarEventsReady fallback,
    CalendarFailure failure,
  ) async {
    final CalendarEventPageRequest? pageRequest = _currentPageRequest;
    final CalendarLocalDate? focusedDate = _focusedDate;
    if (pageRequest == null || focusedDate == null) {
      _emitReady(fallback, actionFailure: failure);
      return;
    }
    _emitReady(fallback, refreshing: true, actionFailure: failure);
    final _CalendarSelectionResult result = await _fetchSelection(
      viewMode: _currentViewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest.firstPage,
      monthRequest: _currentMonthRequest,
    );
    final CalendarEventPage? page = result.page;
    final CalendarLocalDate? resolvedFocus = result.focusedDate;
    if (result.failure != null || page == null || resolvedFocus == null) {
      final CalendarFailure refreshFailure =
          result.failure ?? const CalendarFailure(CalendarFailureKind.internal);
      if (refreshFailure.invalidatesRetainedContent) {
        _emit(CalendarEventsLoadFailed(refreshFailure, _currentViewMode));
        return;
      }
      _emitReady(
        fallback,
        actionFailure: failure,
        refreshFailure: refreshFailure,
      );
      return;
    }
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = result.monthSummary?.request;
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: _currentViewMode,
        focusedDate: resolvedFocus,
        monthSummary: result.monthSummary,
        actionFailure: failure,
        syncStatus: _syncStatus,
        highlightedOccurrenceId: _highlightedOccurrenceId,
      ),
    );
  }

  Future<void> _refreshAfterMutation(CalendarEventsReady fallback) async {
    final CalendarEventPageRequest? pageRequest = _currentPageRequest;
    final CalendarLocalDate? focusedDate = _focusedDate;
    if (pageRequest == null || focusedDate == null) {
      _emitReady(
        fallback,
        refreshFailure: const CalendarFailure(CalendarFailureKind.internal),
      );
      return;
    }
    _emitReady(fallback, refreshing: true);
    final _CalendarSelectionResult result = await _fetchSelection(
      viewMode: _currentViewMode,
      focusedDate: focusedDate,
      pageRequest: pageRequest.firstPage,
      monthRequest: _currentMonthRequest,
    );
    final CalendarEventPage? page = result.page;
    final CalendarLocalDate? resolvedFocus = result.focusedDate;
    if (result.failure != null || page == null || resolvedFocus == null) {
      final CalendarFailure refreshFailure =
          result.failure ?? const CalendarFailure(CalendarFailureKind.internal);
      if (refreshFailure.invalidatesRetainedContent) {
        _emit(CalendarEventsLoadFailed(refreshFailure, _currentViewMode));
        return;
      }
      _emitReady(fallback, refreshFailure: refreshFailure);
      return;
    }
    _currentPageRequest = page.request.firstPage;
    _currentMonthRequest = result.monthSummary?.request;
    _emit(
      CalendarEventsReady(
        page: page,
        viewMode: _currentViewMode,
        focusedDate: resolvedFocus,
        monthSummary: result.monthSummary,
        syncStatus: _syncStatus,
        highlightedOccurrenceId: _highlightedOccurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  CalendarFailure? _validateTime(OneTimeCalendarEventDraft draft) {
    if (draft.isAllDay) {
      return null;
    }
    final CalendarZonedDateTimeIntent? intent = draft.timedIntent;
    if (intent == null) {
      return const CalendarFailure(CalendarFailureKind.invalidInput);
    }
    return switch (_timeResolver.resolve(intent)) {
      ResolvedCalendarTime() => null,
      NonexistentCalendarLocalTime() => const CalendarFailure(
        CalendarFailureKind.nonexistentLocalTime,
      ),
      UnsupportedCalendarTimeZone() => const CalendarFailure(
        CalendarFailureKind.invalidInput,
      ),
    };
  }

  CalendarEventsReady? get _readyState {
    final CalendarEventsState current = _state;
    return current is CalendarEventsReady ? current : null;
  }

  CalendarEventsReady? _readyFor(HouseholdId householdId) {
    final CalendarEventsReady? current = _readyState;
    return current != null &&
            current.page.householdId == householdId &&
            !current.refreshing &&
            !current.loadingMore
        ? current
        : null;
  }

  CalendarEventCommandId _commandId(String fingerprint) {
    if (_retryFingerprint == fingerprint && _retryId != null) {
      return _retryId!;
    }
    final CalendarEventCommandId id = _idGenerator.generate();
    _retryFingerprint = fingerprint;
    _retryId = id;
    return id;
  }

  void _clearRetry(String fingerprint) {
    if (_retryFingerprint == fingerprint) {
      _retryFingerprint = null;
      _retryId = null;
    }
  }

  void _clearRetryState() {
    _retryFingerprint = null;
    _retryId = null;
  }

  void _emitReady(
    CalendarEventsReady base, {
    CalendarEventPage? page,
    bool creating = false,
    CalendarEventSeriesId? pendingSeriesId,
    CalendarEventOccurrenceId? pendingOccurrenceId,
    bool refreshing = false,
    bool loadingMore = false,
    CalendarFailure? actionFailure,
    CalendarFailure? refreshFailure,
    CalendarFailure? loadMoreFailure,
    CalendarConflictResolution? conflictResolution,
    CalendarEventOccurrenceId? highlightedOccurrenceId,
  }) {
    _emit(
      CalendarEventsReady(
        page: page ?? base.page,
        viewMode: base.viewMode,
        focusedDate: base.focusedDate,
        monthSummary: base.monthSummary,
        pendingSeriesId: pendingSeriesId,
        pendingOccurrenceId: pendingOccurrenceId,
        creating: creating,
        refreshing: refreshing,
        loadingMore: loadingMore,
        actionFailure: actionFailure,
        refreshFailure: refreshFailure,
        loadMoreFailure: loadMoreFailure,
        syncStatus: _syncStatus,
        conflictResolution: conflictResolution,
        highlightedOccurrenceId:
            highlightedOccurrenceId ?? base.highlightedOccurrenceId,
        undoableSeriesCancellation: _undoableSeriesCancellation,
      ),
    );
  }

  Future<void> _ensureSync(HouseholdId householdId) async {
    if (_disposed || _readyState?.page.householdId != householdId) {
      return;
    }
    if (_syncedHouseholdId == householdId) {
      return;
    }
    _syncedHouseholdId = householdId;
    await _syncSession.start(householdId);
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
    final HouseholdId? householdId = _householdId;
    final CalendarEventOccurrenceId? highlighted = _highlightedOccurrenceId;
    if (householdId != null && highlighted != null) {
      await openOccurrence(householdId, highlighted);
    } else {
      await refresh();
    }
  }

  void _setSyncStatus(CalendarSyncConnectionStatus status) {
    if (_disposed || _syncStatus == status) {
      return;
    }
    _syncStatus = status;
    final CalendarEventsReady? current = _readyState;
    if (current != null) {
      _emit(
        CalendarEventsReady(
          page: current.page,
          viewMode: current.viewMode,
          focusedDate: current.focusedDate,
          monthSummary: current.monthSummary,
          pendingSeriesId: current.pendingSeriesId,
          pendingOccurrenceId: current.pendingOccurrenceId,
          creating: current.creating,
          refreshing: current.refreshing,
          loadingMore: current.loadingMore,
          actionFailure: current.actionFailure,
          refreshFailure: current.refreshFailure,
          loadMoreFailure: current.loadMoreFailure,
          syncStatus: status,
          conflictResolution: current.conflictResolution,
          highlightedOccurrenceId: current.highlightedOccurrenceId,
          undoableSeriesCancellation: current.undoableSeriesCancellation,
        ),
      );
    }
  }

  void _emit(CalendarEventsState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    _states.add(state);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _syncSession.dispose();
    await _states.close();
  }
}

final class _CalendarSelectionResult {
  const _CalendarSelectionResult.success({
    required this.page,
    required this.focusedDate,
    required this.monthSummary,
  }) : failure = null;

  const _CalendarSelectionResult.failure(this.failure)
    : page = null,
      focusedDate = null,
      monthSummary = null;

  final CalendarEventPage? page;
  final CalendarLocalDate? focusedDate;
  final CalendarMonthSummary? monthSummary;
  final CalendarFailure? failure;
}
