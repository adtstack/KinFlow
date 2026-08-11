import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableCalendarRepository implements CalendarRepository {
  const UnavailableCalendarRepository();

  static const CalendarFailure _failure = CalendarFailure(
    CalendarFailureKind.temporarilyUnavailable,
  );

  @override
  Future<LoadOneTimeCalendarEventsResult> loadOneTimeEvents(
    HouseholdId householdId,
  ) async => const LoadOneTimeCalendarEventsFailed(_failure);

  @override
  Future<CreateOneTimeCalendarEventResult> createOneTimeEvent(
    CreateOneTimeCalendarEventRequest request,
  ) async => const CreateOneTimeCalendarEventFailed(_failure);

  @override
  Future<CreateRecurringCalendarEventResult> createRecurringEvent(
    CreateRecurringCalendarEventRequest request,
  ) async => const CreateRecurringCalendarEventFailed(_failure);

  @override
  Future<LoadRecurringCalendarSeriesResult> loadRecurringSeries({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  }) async => const LoadRecurringCalendarSeriesFailed(_failure);

  @override
  Future<UpdateRecurringCalendarSeriesResult> updateRecurringSeries(
    UpdateRecurringCalendarSeriesRequest request,
  ) async => const UpdateRecurringCalendarSeriesFailed(_failure);

  @override
  Future<UpdateRecurringCalendarSeriesResult>
  updateRecurringSeriesFromOccurrence(
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async => const UpdateRecurringCalendarSeriesFailed(_failure);

  @override
  Future<CancelRecurringCalendarSeriesResult> cancelRecurringSeries(
    CancelRecurringCalendarSeriesRequest request,
  ) async => const CancelRecurringCalendarSeriesFailed(_failure);

  @override
  Future<CancelRecurringCalendarSeriesFromOccurrenceResult>
  cancelRecurringSeriesFromOccurrence(
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async => const CancelRecurringCalendarSeriesFromOccurrenceFailed(_failure);

  @override
  Future<ResumeRecurringCalendarSeriesCancellationResult>
  resumeRecurringSeriesCancellation(
    ResumeRecurringCalendarSeriesCancellationRequest request,
  ) async => const ResumeRecurringCalendarSeriesCancellationFailed(_failure);

  @override
  Future<UpdateOneTimeCalendarEventResult> updateOneTimeEvent(
    UpdateOneTimeCalendarEventRequest request,
  ) async => const UpdateOneTimeCalendarEventFailed(_failure);

  @override
  Future<DeleteOneTimeCalendarEventResult> deleteOneTimeEvent(
    DeleteOneTimeCalendarEventRequest request,
  ) async => const DeleteOneTimeCalendarEventFailed(_failure);

  @override
  Future<UpdateRecurringCalendarOccurrenceResult> updateRecurringOccurrence(
    UpdateRecurringCalendarOccurrenceRequest request,
  ) async => const UpdateRecurringCalendarOccurrenceFailed(_failure);

  @override
  Future<CancelRecurringCalendarOccurrenceResult> cancelRecurringOccurrence(
    CancelRecurringCalendarOccurrenceRequest request,
  ) async => const CancelRecurringCalendarOccurrenceFailed(_failure);

  @override
  Future<LoadCalendarEventPageResult> loadEventPage(
    CalendarEventPageRequest request,
  ) async => const LoadCalendarEventPageFailed(_failure);

  @override
  Future<LoadCalendarMonthSummaryResult> loadMonthSummary(
    CalendarMonthSummaryRequest request,
  ) async => const LoadCalendarMonthSummaryFailed(_failure);

  @override
  Future<LoadCalendarOccurrenceLocatorResult> loadOccurrenceLocator({
    required HouseholdId householdId,
    required CalendarEventOccurrenceId occurrenceId,
  }) async => const LoadCalendarOccurrenceLocatorFailed(_failure);

  @override
  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) async => const PreviewCalendarOverlapsFailed(_failure);
}
