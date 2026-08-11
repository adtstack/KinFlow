import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_occurrence_locator.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class CalendarRepository {
  Future<LoadCalendarEventPageResult> loadEventPage(
    CalendarEventPageRequest request,
  );

  Future<LoadCalendarMonthSummaryResult> loadMonthSummary(
    CalendarMonthSummaryRequest request,
  );

  Future<LoadCalendarOccurrenceLocatorResult> loadOccurrenceLocator({
    required HouseholdId householdId,
    required CalendarEventOccurrenceId occurrenceId,
  });

  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  );

  Future<LoadOneTimeCalendarEventsResult> loadOneTimeEvents(
    HouseholdId householdId,
  );

  Future<CreateOneTimeCalendarEventResult> createOneTimeEvent(
    CreateOneTimeCalendarEventRequest request,
  );

  Future<CreateRecurringCalendarEventResult> createRecurringEvent(
    CreateRecurringCalendarEventRequest request,
  );

  Future<LoadRecurringCalendarSeriesResult> loadRecurringSeries({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  });

  Future<UpdateRecurringCalendarSeriesResult> updateRecurringSeries(
    UpdateRecurringCalendarSeriesRequest request,
  );

  Future<UpdateRecurringCalendarSeriesResult>
  updateRecurringSeriesFromOccurrence(
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
  );

  Future<CancelRecurringCalendarSeriesResult> cancelRecurringSeries(
    CancelRecurringCalendarSeriesRequest request,
  );

  Future<CancelRecurringCalendarSeriesFromOccurrenceResult>
  cancelRecurringSeriesFromOccurrence(
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  );

  Future<ResumeRecurringCalendarSeriesCancellationResult>
  resumeRecurringSeriesCancellation(
    ResumeRecurringCalendarSeriesCancellationRequest request,
  );

  Future<UpdateOneTimeCalendarEventResult> updateOneTimeEvent(
    UpdateOneTimeCalendarEventRequest request,
  );

  Future<DeleteOneTimeCalendarEventResult> deleteOneTimeEvent(
    DeleteOneTimeCalendarEventRequest request,
  );

  Future<UpdateRecurringCalendarOccurrenceResult> updateRecurringOccurrence(
    UpdateRecurringCalendarOccurrenceRequest request,
  );

  Future<CancelRecurringCalendarOccurrenceResult> cancelRecurringOccurrence(
    CancelRecurringCalendarOccurrenceRequest request,
  );
}

sealed class PreviewCalendarOverlapsResult {
  const PreviewCalendarOverlapsResult();
}

final class CalendarOverlapsPreviewed extends PreviewCalendarOverlapsResult {
  const CalendarOverlapsPreviewed(this.preview);

  final CalendarOverlapPreview preview;
}

final class PreviewCalendarOverlapsFailed
    extends PreviewCalendarOverlapsResult {
  const PreviewCalendarOverlapsFailed(this.failure);

  final CalendarFailure failure;
}

sealed class LoadCalendarEventPageResult {
  const LoadCalendarEventPageResult();
}

final class CalendarEventPageLoaded extends LoadCalendarEventPageResult {
  const CalendarEventPageLoaded(this.page);

  final CalendarEventPage page;
}

final class LoadCalendarEventPageFailed extends LoadCalendarEventPageResult {
  const LoadCalendarEventPageFailed(this.failure);

  final CalendarFailure failure;
}

sealed class LoadCalendarMonthSummaryResult {
  const LoadCalendarMonthSummaryResult();
}

final class CalendarMonthSummaryLoaded extends LoadCalendarMonthSummaryResult {
  const CalendarMonthSummaryLoaded(this.summary);

  final CalendarMonthSummary summary;
}

final class LoadCalendarMonthSummaryFailed
    extends LoadCalendarMonthSummaryResult {
  const LoadCalendarMonthSummaryFailed(this.failure);

  final CalendarFailure failure;
}

sealed class LoadCalendarOccurrenceLocatorResult {
  const LoadCalendarOccurrenceLocatorResult();
}

final class CalendarOccurrenceLocatorLoaded
    extends LoadCalendarOccurrenceLocatorResult {
  const CalendarOccurrenceLocatorLoaded(this.locator);

  final CalendarOccurrenceLocator locator;
}

final class LoadCalendarOccurrenceLocatorFailed
    extends LoadCalendarOccurrenceLocatorResult {
  const LoadCalendarOccurrenceLocatorFailed(this.failure);

  final CalendarFailure failure;
}

sealed class LoadOneTimeCalendarEventsResult {
  const LoadOneTimeCalendarEventsResult();
}

final class OneTimeCalendarEventsLoaded
    extends LoadOneTimeCalendarEventsResult {
  const OneTimeCalendarEventsLoaded(this.eventList);

  final OneTimeCalendarEventList eventList;
}

final class LoadOneTimeCalendarEventsFailed
    extends LoadOneTimeCalendarEventsResult {
  const LoadOneTimeCalendarEventsFailed(this.failure);

  final CalendarFailure failure;
}

sealed class CreateOneTimeCalendarEventResult {
  const CreateOneTimeCalendarEventResult();
}

final class OneTimeCalendarEventCreated
    extends CreateOneTimeCalendarEventResult {
  const OneTimeCalendarEventCreated(this.event);

  final OneTimeCalendarEvent event;
}

final class CreateOneTimeCalendarEventFailed
    extends CreateOneTimeCalendarEventResult {
  const CreateOneTimeCalendarEventFailed(this.failure);

  final CalendarFailure failure;
}

sealed class CreateRecurringCalendarEventResult {
  const CreateRecurringCalendarEventResult();
}

final class RecurringCalendarEventCreated
    extends CreateRecurringCalendarEventResult {
  const RecurringCalendarEventCreated(this.snapshot);

  final RecurringCalendarEventSnapshot snapshot;
}

final class CreateRecurringCalendarEventFailed
    extends CreateRecurringCalendarEventResult {
  const CreateRecurringCalendarEventFailed(this.failure);

  final CalendarFailure failure;
}

sealed class LoadRecurringCalendarSeriesResult {
  const LoadRecurringCalendarSeriesResult();
}

final class RecurringCalendarSeriesLoaded
    extends LoadRecurringCalendarSeriesResult {
  const RecurringCalendarSeriesLoaded(this.detail);

  final RecurringCalendarSeriesDetail detail;
}

final class LoadRecurringCalendarSeriesFailed
    extends LoadRecurringCalendarSeriesResult {
  const LoadRecurringCalendarSeriesFailed(this.failure);

  final CalendarFailure failure;
}

sealed class UpdateRecurringCalendarSeriesResult {
  const UpdateRecurringCalendarSeriesResult();
}

final class RecurringCalendarSeriesUpdated
    extends UpdateRecurringCalendarSeriesResult {
  const RecurringCalendarSeriesUpdated(this.snapshot);

  final RecurringCalendarSeriesUpdateSnapshot snapshot;
}

final class UpdateRecurringCalendarSeriesFailed
    extends UpdateRecurringCalendarSeriesResult {
  const UpdateRecurringCalendarSeriesFailed(this.failure);

  final CalendarFailure failure;
}

sealed class CancelRecurringCalendarSeriesResult {
  const CancelRecurringCalendarSeriesResult();
}

final class RecurringCalendarSeriesCancelled
    extends CancelRecurringCalendarSeriesResult {
  const RecurringCalendarSeriesCancelled(this.snapshot);

  final RecurringCalendarSeriesCancellationSnapshot snapshot;
}

final class CancelRecurringCalendarSeriesFailed
    extends CancelRecurringCalendarSeriesResult {
  const CancelRecurringCalendarSeriesFailed(this.failure);

  final CalendarFailure failure;
}

sealed class CancelRecurringCalendarSeriesFromOccurrenceResult {
  const CancelRecurringCalendarSeriesFromOccurrenceResult();
}

final class RecurringCalendarSeriesCancelledFromOccurrence
    extends CancelRecurringCalendarSeriesFromOccurrenceResult {
  const RecurringCalendarSeriesCancelledFromOccurrence(this.snapshot);

  final RecurringCalendarSeriesFromOccurrenceCancellationSnapshot snapshot;
}

final class CancelRecurringCalendarSeriesFromOccurrenceFailed
    extends CancelRecurringCalendarSeriesFromOccurrenceResult {
  const CancelRecurringCalendarSeriesFromOccurrenceFailed(this.failure);

  final CalendarFailure failure;
}

sealed class ResumeRecurringCalendarSeriesCancellationResult {
  const ResumeRecurringCalendarSeriesCancellationResult();
}

final class RecurringCalendarSeriesCancellationResumed
    extends ResumeRecurringCalendarSeriesCancellationResult {
  const RecurringCalendarSeriesCancellationResumed(this.snapshot);

  final RecurringCalendarSeriesCancellationResumeSnapshot snapshot;
}

final class ResumeRecurringCalendarSeriesCancellationFailed
    extends ResumeRecurringCalendarSeriesCancellationResult {
  const ResumeRecurringCalendarSeriesCancellationFailed(this.failure);

  final CalendarFailure failure;
}

sealed class UpdateOneTimeCalendarEventResult {
  const UpdateOneTimeCalendarEventResult();
}

final class OneTimeCalendarEventUpdated
    extends UpdateOneTimeCalendarEventResult {
  const OneTimeCalendarEventUpdated(this.event);

  final OneTimeCalendarEvent event;
}

final class UpdateOneTimeCalendarEventFailed
    extends UpdateOneTimeCalendarEventResult {
  const UpdateOneTimeCalendarEventFailed(this.failure);

  final CalendarFailure failure;
}

sealed class DeleteOneTimeCalendarEventResult {
  const DeleteOneTimeCalendarEventResult();
}

final class OneTimeCalendarEventDeleted
    extends DeleteOneTimeCalendarEventResult {
  const OneTimeCalendarEventDeleted({
    required this.seriesId,
    required this.version,
  });

  final CalendarEventSeriesId seriesId;
  final int version;
}

final class DeleteOneTimeCalendarEventFailed
    extends DeleteOneTimeCalendarEventResult {
  const DeleteOneTimeCalendarEventFailed(this.failure);

  final CalendarFailure failure;
}

sealed class UpdateRecurringCalendarOccurrenceResult {
  const UpdateRecurringCalendarOccurrenceResult();
}

final class RecurringCalendarOccurrenceUpdated
    extends UpdateRecurringCalendarOccurrenceResult {
  const RecurringCalendarOccurrenceUpdated(this.snapshot);

  final RecurringCalendarOccurrenceCommandSnapshot snapshot;
}

final class UpdateRecurringCalendarOccurrenceFailed
    extends UpdateRecurringCalendarOccurrenceResult {
  const UpdateRecurringCalendarOccurrenceFailed(this.failure);

  final CalendarFailure failure;
}

sealed class CancelRecurringCalendarOccurrenceResult {
  const CancelRecurringCalendarOccurrenceResult();
}

final class RecurringCalendarOccurrenceCancelled
    extends CancelRecurringCalendarOccurrenceResult {
  const RecurringCalendarOccurrenceCancelled(this.snapshot);

  final RecurringCalendarOccurrenceCommandSnapshot snapshot;
}

final class CancelRecurringCalendarOccurrenceFailed
    extends CancelRecurringCalendarOccurrenceResult {
  const CancelRecurringCalendarOccurrenceFailed(this.failure);

  final CalendarFailure failure;
}
