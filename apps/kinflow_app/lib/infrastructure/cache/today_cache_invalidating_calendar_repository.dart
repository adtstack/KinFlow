import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';

final class TodayCacheInvalidatingCalendarRepository
    implements CalendarRepository {
  const TodayCacheInvalidatingCalendarRepository(this._delegate, this._cache);

  final CalendarRepository _delegate;
  final TodayCalendarSnapshotCache _cache;

  @override
  Future<LoadCalendarEventPageResult> loadEventPage(
    CalendarEventPageRequest request,
  ) {
    return _delegate.loadEventPage(request);
  }

  @override
  Future<LoadCalendarMonthSummaryResult> loadMonthSummary(
    CalendarMonthSummaryRequest request,
  ) {
    return _delegate.loadMonthSummary(request);
  }

  @override
  Future<LoadCalendarOccurrenceLocatorResult> loadOccurrenceLocator({
    required HouseholdId householdId,
    required CalendarEventOccurrenceId occurrenceId,
  }) {
    return _delegate.loadOccurrenceLocator(
      householdId: householdId,
      occurrenceId: occurrenceId,
    );
  }

  @override
  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) {
    return _delegate.previewOverlaps(request);
  }

  @override
  Future<LoadOneTimeCalendarEventsResult> loadOneTimeEvents(
    HouseholdId householdId,
  ) {
    return _delegate.loadOneTimeEvents(householdId);
  }

  @override
  Future<LoadRecurringCalendarSeriesResult> loadRecurringSeries({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  }) {
    return _delegate.loadRecurringSeries(
      householdId: householdId,
      seriesId: seriesId,
    );
  }

  @override
  Future<CreateOneTimeCalendarEventResult> createOneTimeEvent(
    CreateOneTimeCalendarEventRequest request,
  ) async {
    final CreateOneTimeCalendarEventResult result = await _delegate
        .createOneTimeEvent(request);
    await _applyPolicy(
      succeeded: result is OneTimeCalendarEventCreated,
      failure: switch (result) {
        CreateOneTimeCalendarEventFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<CreateRecurringCalendarEventResult> createRecurringEvent(
    CreateRecurringCalendarEventRequest request,
  ) async {
    final CreateRecurringCalendarEventResult result = await _delegate
        .createRecurringEvent(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarEventCreated,
      failure: switch (result) {
        CreateRecurringCalendarEventFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<UpdateRecurringCalendarSeriesResult> updateRecurringSeries(
    UpdateRecurringCalendarSeriesRequest request,
  ) async {
    final UpdateRecurringCalendarSeriesResult result = await _delegate
        .updateRecurringSeries(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarSeriesUpdated,
      failure: switch (result) {
        UpdateRecurringCalendarSeriesFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<UpdateRecurringCalendarSeriesResult>
  updateRecurringSeriesFromOccurrence(
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    final UpdateRecurringCalendarSeriesResult result = await _delegate
        .updateRecurringSeriesFromOccurrence(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarSeriesUpdated,
      failure: switch (result) {
        UpdateRecurringCalendarSeriesFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<CancelRecurringCalendarSeriesResult> cancelRecurringSeries(
    CancelRecurringCalendarSeriesRequest request,
  ) async {
    final CancelRecurringCalendarSeriesResult result = await _delegate
        .cancelRecurringSeries(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarSeriesCancelled,
      failure: switch (result) {
        CancelRecurringCalendarSeriesFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<CancelRecurringCalendarSeriesFromOccurrenceResult>
  cancelRecurringSeriesFromOccurrence(
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    final CancelRecurringCalendarSeriesFromOccurrenceResult result =
        await _delegate.cancelRecurringSeriesFromOccurrence(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarSeriesCancelledFromOccurrence,
      failure: switch (result) {
        CancelRecurringCalendarSeriesFromOccurrenceFailed(:final failure) =>
          failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<ResumeRecurringCalendarSeriesCancellationResult>
  resumeRecurringSeriesCancellation(
    ResumeRecurringCalendarSeriesCancellationRequest request,
  ) async {
    final ResumeRecurringCalendarSeriesCancellationResult result =
        await _delegate.resumeRecurringSeriesCancellation(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarSeriesCancellationResumed,
      failure: switch (result) {
        ResumeRecurringCalendarSeriesCancellationFailed(:final failure) =>
          failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<UpdateOneTimeCalendarEventResult> updateOneTimeEvent(
    UpdateOneTimeCalendarEventRequest request,
  ) async {
    final UpdateOneTimeCalendarEventResult result = await _delegate
        .updateOneTimeEvent(request);
    await _applyPolicy(
      succeeded: result is OneTimeCalendarEventUpdated,
      failure: switch (result) {
        UpdateOneTimeCalendarEventFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<DeleteOneTimeCalendarEventResult> deleteOneTimeEvent(
    DeleteOneTimeCalendarEventRequest request,
  ) async {
    final DeleteOneTimeCalendarEventResult result = await _delegate
        .deleteOneTimeEvent(request);
    await _applyPolicy(
      succeeded: result is OneTimeCalendarEventDeleted,
      failure: switch (result) {
        DeleteOneTimeCalendarEventFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<UpdateRecurringCalendarOccurrenceResult> updateRecurringOccurrence(
    UpdateRecurringCalendarOccurrenceRequest request,
  ) async {
    final UpdateRecurringCalendarOccurrenceResult result = await _delegate
        .updateRecurringOccurrence(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarOccurrenceUpdated,
      failure: switch (result) {
        UpdateRecurringCalendarOccurrenceFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  @override
  Future<CancelRecurringCalendarOccurrenceResult> cancelRecurringOccurrence(
    CancelRecurringCalendarOccurrenceRequest request,
  ) async {
    final CancelRecurringCalendarOccurrenceResult result = await _delegate
        .cancelRecurringOccurrence(request);
    await _applyPolicy(
      succeeded: result is RecurringCalendarOccurrenceCancelled,
      failure: switch (result) {
        CancelRecurringCalendarOccurrenceFailed(:final failure) => failure,
        _ => null,
      },
    );
    return result;
  }

  Future<void> _applyPolicy({
    required bool succeeded,
    required CalendarFailure? failure,
  }) async {
    if (succeeded) {
      await _cache.delete();
    } else if (failure?.invalidatesRetainedContent ?? false) {
      await _cache.clearAll();
    }
  }
}
