import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class CalendarEventsState {
  const CalendarEventsState();
}

enum CalendarConflictResolution { latestReloaded, targetUnavailable }

final class CalendarEventsInitial extends CalendarEventsState {
  const CalendarEventsInitial();
}

final class CalendarEventsLoading extends CalendarEventsState {
  const CalendarEventsLoading(this.viewMode);

  final CalendarViewMode viewMode;
}

final class CalendarEventsLoadFailed extends CalendarEventsState {
  const CalendarEventsLoadFailed(this.failure, this.viewMode);

  final CalendarFailure failure;
  final CalendarViewMode viewMode;
}

final class CalendarEventsTargetUnavailable extends CalendarEventsState {
  const CalendarEventsTargetUnavailable(this.occurrenceId);

  final CalendarEventOccurrenceId occurrenceId;
}

final class CalendarEventsReady extends CalendarEventsState {
  const CalendarEventsReady({
    required this.page,
    required this.viewMode,
    required this.focusedDate,
    required this.monthSummary,
    this.pendingSeriesId,
    this.pendingOccurrenceId,
    this.creating = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.actionFailure,
    this.refreshFailure,
    this.loadMoreFailure,
    this.syncStatus = CalendarSyncConnectionStatus.disabled,
    this.conflictResolution,
    this.highlightedOccurrenceId,
    this.undoableSeriesCancellation,
  });

  final CalendarEventPage page;
  final CalendarViewMode viewMode;
  final CalendarLocalDate focusedDate;
  final CalendarMonthSummary? monthSummary;
  final CalendarEventSeriesId? pendingSeriesId;
  final CalendarEventOccurrenceId? pendingOccurrenceId;
  final bool creating;
  final bool refreshing;
  final bool loadingMore;
  final CalendarFailure? actionFailure;
  final CalendarFailure? refreshFailure;
  final CalendarFailure? loadMoreFailure;
  final CalendarSyncConnectionStatus syncStatus;
  final CalendarConflictResolution? conflictResolution;
  final CalendarEventOccurrenceId? highlightedOccurrenceId;
  final UndoableRecurringCalendarSeriesCancellation? undoableSeriesCancellation;

  bool get actionPending =>
      creating || pendingSeriesId != null || pendingOccurrenceId != null;

  bool get busy => actionPending || refreshing || loadingMore;
}

final class UndoableRecurringCalendarSeriesCancellation {
  const UndoableRecurringCalendarSeriesCancellation({
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.cancellationVersion,
    required this.effectiveLocalDate,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventCommandId cancellationIdempotencyKey;
  final int cancellationVersion;
  final CalendarLocalDate effectiveLocalDate;
}
