import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

abstract interface class ChoreRepository {
  Future<LoadTodayChoresResult> loadToday(HouseholdId householdId);

  Future<LoadHouseholdActivationProgressResult> loadHouseholdActivationProgress(
    HouseholdId householdId,
  );

  Future<LoadHouseholdWeeklyReportResult> loadHouseholdWeeklyReport(
    HouseholdWeeklyReportRequest request,
  );

  Future<LoadTodayChoresResult> loadChoreList(ChoreListRequest request);

  Future<LoadChoreOccurrenceTargetResult> loadOccurrenceTarget({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  });

  Future<LoadChoreOccurrenceHistoryResult> loadOccurrenceHistory(
    ChoreOccurrenceHistoryRequest request,
  );

  Future<LoadDeletedOneTimeChoresResult> loadDeletedOneTimeChores(
    DeletedOneTimeChoreListRequest request,
  );

  Future<CreateOneTimeChoreResult> createOneTimeChore(
    CreateOneTimeChoreRequest request,
  );

  Future<UpdateOneTimeChoreResult> updateOneTimeChore(
    UpdateOneTimeChoreRequest request,
  );

  Future<DeleteOneTimeChoreResult> deleteOneTimeChore(
    DeleteOneTimeChoreRequest request,
  );

  Future<RestoreOneTimeChoreResult> restoreOneTimeChore(
    RestoreOneTimeChoreRequest request,
  );

  Future<CreateRecurringChoreResult> createRecurringChore(
    CreateRecurringChoreRequest request,
  );

  Future<SetChoreCompletionResult> setOccurrenceCompletion(
    SetChoreCompletionRequest request,
  );

  Future<SkipChoreOccurrenceResult> skipOccurrence(
    SkipChoreOccurrenceRequest request,
  );

  Future<RestoreSkippedChoreOccurrenceResult> restoreSkippedOccurrence(
    RestoreSkippedChoreOccurrenceRequest request,
  );

  Future<RescheduleChoreOccurrenceResult> rescheduleOccurrence(
    RescheduleChoreOccurrenceRequest request,
  );

  Future<ReassignChoreOccurrenceResult> reassignOccurrence(
    ReassignChoreOccurrenceRequest request,
  );

  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeries(
    UpdateRepeatingChoreSeriesRequest request,
  );

  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeriesFromOccurrence(
    UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  );

  Future<CancelRepeatingChoreSeriesResult> cancelRepeatingSeries(
    CancelRepeatingChoreSeriesRequest request,
  );

  Future<CancelRepeatingChoreSeriesFromOccurrenceResult>
  cancelRepeatingSeriesFromOccurrence(
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  );

  Future<ResumeRepeatingChoreSeriesCancellationResult>
  resumeRepeatingSeriesCancellation(
    ResumeRepeatingChoreSeriesCancellationRequest request,
  );
}

sealed class LoadHouseholdActivationProgressResult {
  const LoadHouseholdActivationProgressResult();
}

final class HouseholdActivationProgressLoaded
    extends LoadHouseholdActivationProgressResult {
  const HouseholdActivationProgressLoaded(this.progress);

  final HouseholdActivationProgress progress;
}

final class LoadHouseholdActivationProgressFailed
    extends LoadHouseholdActivationProgressResult {
  const LoadHouseholdActivationProgressFailed(this.failure);

  final ChoreFailure failure;
}

sealed class LoadHouseholdWeeklyReportResult {
  const LoadHouseholdWeeklyReportResult();
}

final class HouseholdWeeklyReportLoaded
    extends LoadHouseholdWeeklyReportResult {
  const HouseholdWeeklyReportLoaded(this.report);

  final HouseholdWeeklyReport report;
}

final class LoadHouseholdWeeklyReportFailed
    extends LoadHouseholdWeeklyReportResult {
  const LoadHouseholdWeeklyReportFailed(this.failure);

  final ChoreFailure failure;
}

sealed class LoadChoreOccurrenceHistoryResult {
  const LoadChoreOccurrenceHistoryResult();
}

sealed class LoadChoreOccurrenceTargetResult {
  const LoadChoreOccurrenceTargetResult();
}

final class ChoreOccurrenceTargetLoaded
    extends LoadChoreOccurrenceTargetResult {
  const ChoreOccurrenceTargetLoaded(this.occurrence);

  final ChoreOccurrence occurrence;
}

final class LoadChoreOccurrenceTargetFailed
    extends LoadChoreOccurrenceTargetResult {
  const LoadChoreOccurrenceTargetFailed(this.failure);

  final ChoreFailure failure;
}

final class ChoreOccurrenceHistoryLoaded
    extends LoadChoreOccurrenceHistoryResult {
  const ChoreOccurrenceHistoryLoaded(this.page);

  final ChoreOccurrenceHistoryPage page;
}

final class LoadChoreOccurrenceHistoryFailed
    extends LoadChoreOccurrenceHistoryResult {
  const LoadChoreOccurrenceHistoryFailed(this.failure);

  final ChoreFailure failure;
}

sealed class LoadDeletedOneTimeChoresResult {
  const LoadDeletedOneTimeChoresResult();
}

final class DeletedOneTimeChoresLoaded extends LoadDeletedOneTimeChoresResult {
  const DeletedOneTimeChoresLoaded(this.page);

  final DeletedOneTimeChorePage page;
}

final class LoadDeletedOneTimeChoresFailed
    extends LoadDeletedOneTimeChoresResult {
  const LoadDeletedOneTimeChoresFailed(this.failure);

  final ChoreFailure failure;
}

sealed class LoadTodayChoresResult {
  const LoadTodayChoresResult();
}

final class TodayChoresLoaded extends LoadTodayChoresResult {
  const TodayChoresLoaded(this.today, {this.cacheMetadata});

  final TodayChores today;
  final ReadCacheMetadata? cacheMetadata;
}

final class LoadTodayChoresFailed extends LoadTodayChoresResult {
  const LoadTodayChoresFailed(this.failure);

  final ChoreFailure failure;
}

sealed class CreateOneTimeChoreResult {
  const CreateOneTimeChoreResult();
}

final class OneTimeChoreCreated extends CreateOneTimeChoreResult {
  const OneTimeChoreCreated(this.occurrence);

  final ChoreOccurrence occurrence;
}

final class CreateOneTimeChoreFailed extends CreateOneTimeChoreResult {
  const CreateOneTimeChoreFailed(this.failure);

  final ChoreFailure failure;
}

sealed class UpdateOneTimeChoreResult {
  const UpdateOneTimeChoreResult();
}

final class OneTimeChoreUpdated extends UpdateOneTimeChoreResult {
  const OneTimeChoreUpdated(this.snapshot);

  final OneTimeChoreUpdateSnapshot snapshot;
}

final class UpdateOneTimeChoreFailed extends UpdateOneTimeChoreResult {
  const UpdateOneTimeChoreFailed(this.failure);

  final ChoreFailure failure;
}

sealed class DeleteOneTimeChoreResult {
  const DeleteOneTimeChoreResult();
}

final class OneTimeChoreDeleted extends DeleteOneTimeChoreResult {
  const OneTimeChoreDeleted(this.snapshot);

  final OneTimeChoreDeletionSnapshot snapshot;
}

final class DeleteOneTimeChoreFailed extends DeleteOneTimeChoreResult {
  const DeleteOneTimeChoreFailed(this.failure);

  final ChoreFailure failure;
}

sealed class RestoreOneTimeChoreResult {
  const RestoreOneTimeChoreResult();
}

final class OneTimeChoreRestored extends RestoreOneTimeChoreResult {
  const OneTimeChoreRestored(this.snapshot);

  final OneTimeChoreRestoreSnapshot snapshot;
}

final class RestoreOneTimeChoreFailed extends RestoreOneTimeChoreResult {
  const RestoreOneTimeChoreFailed(this.failure);

  final ChoreFailure failure;
}

sealed class CreateRecurringChoreResult {
  const CreateRecurringChoreResult();
}

final class RecurringChoreCreated extends CreateRecurringChoreResult {
  const RecurringChoreCreated(this.snapshot);

  final RecurringChoreSnapshot snapshot;
}

final class CreateRecurringChoreFailed extends CreateRecurringChoreResult {
  const CreateRecurringChoreFailed(this.failure);

  final ChoreFailure failure;
}

sealed class SetChoreCompletionResult {
  const SetChoreCompletionResult();
}

final class ChoreCompletionSet extends SetChoreCompletionResult {
  const ChoreCompletionSet(this.snapshot);

  final ChoreCompletionSnapshot snapshot;
}

final class SetChoreCompletionFailed extends SetChoreCompletionResult {
  const SetChoreCompletionFailed(this.failure);

  final ChoreFailure failure;
}

sealed class SkipChoreOccurrenceResult {
  const SkipChoreOccurrenceResult();
}

final class ChoreOccurrenceSkipped extends SkipChoreOccurrenceResult {
  const ChoreOccurrenceSkipped(this.snapshot);

  final ChoreOccurrenceSkipSnapshot snapshot;
}

final class SkipChoreOccurrenceFailed extends SkipChoreOccurrenceResult {
  const SkipChoreOccurrenceFailed(this.failure);

  final ChoreFailure failure;
}

sealed class RestoreSkippedChoreOccurrenceResult {
  const RestoreSkippedChoreOccurrenceResult();
}

final class ChoreOccurrenceRestored
    extends RestoreSkippedChoreOccurrenceResult {
  const ChoreOccurrenceRestored(this.snapshot);

  final ChoreOccurrenceRestoreSnapshot snapshot;
}

final class RestoreSkippedChoreOccurrenceFailed
    extends RestoreSkippedChoreOccurrenceResult {
  const RestoreSkippedChoreOccurrenceFailed(this.failure);

  final ChoreFailure failure;
}

sealed class RescheduleChoreOccurrenceResult {
  const RescheduleChoreOccurrenceResult();
}

final class ChoreOccurrenceRescheduled extends RescheduleChoreOccurrenceResult {
  const ChoreOccurrenceRescheduled(this.snapshot);

  final ChoreOccurrenceRescheduleSnapshot snapshot;
}

final class RescheduleChoreOccurrenceFailed
    extends RescheduleChoreOccurrenceResult {
  const RescheduleChoreOccurrenceFailed(this.failure);

  final ChoreFailure failure;
}

sealed class ReassignChoreOccurrenceResult {
  const ReassignChoreOccurrenceResult();
}

final class ChoreOccurrenceReassigned extends ReassignChoreOccurrenceResult {
  const ChoreOccurrenceReassigned(this.snapshot);

  final ChoreOccurrenceReassignmentSnapshot snapshot;
}

final class ReassignChoreOccurrenceFailed
    extends ReassignChoreOccurrenceResult {
  const ReassignChoreOccurrenceFailed(this.failure);

  final ChoreFailure failure;
}

sealed class UpdateRepeatingChoreSeriesResult {
  const UpdateRepeatingChoreSeriesResult();
}

final class RepeatingChoreSeriesUpdated
    extends UpdateRepeatingChoreSeriesResult {
  const RepeatingChoreSeriesUpdated(this.snapshot);

  final RepeatingChoreSeriesUpdateSnapshot snapshot;
}

final class UpdateRepeatingChoreSeriesFailed
    extends UpdateRepeatingChoreSeriesResult {
  const UpdateRepeatingChoreSeriesFailed(this.failure);

  final ChoreFailure failure;
}

sealed class CancelRepeatingChoreSeriesResult {
  const CancelRepeatingChoreSeriesResult();
}

final class RepeatingChoreSeriesCancelled
    extends CancelRepeatingChoreSeriesResult {
  const RepeatingChoreSeriesCancelled(this.snapshot);

  final RepeatingChoreSeriesCancellationSnapshot snapshot;
}

final class CancelRepeatingChoreSeriesFailed
    extends CancelRepeatingChoreSeriesResult {
  const CancelRepeatingChoreSeriesFailed(this.failure);

  final ChoreFailure failure;
}

sealed class CancelRepeatingChoreSeriesFromOccurrenceResult {
  const CancelRepeatingChoreSeriesFromOccurrenceResult();
}

final class RepeatingChoreSeriesCancelledFromOccurrence
    extends CancelRepeatingChoreSeriesFromOccurrenceResult {
  const RepeatingChoreSeriesCancelledFromOccurrence(this.snapshot);

  final RepeatingChoreSeriesFromOccurrenceCancellationSnapshot snapshot;
}

final class CancelRepeatingChoreSeriesFromOccurrenceFailed
    extends CancelRepeatingChoreSeriesFromOccurrenceResult {
  const CancelRepeatingChoreSeriesFromOccurrenceFailed(this.failure);

  final ChoreFailure failure;
}

sealed class ResumeRepeatingChoreSeriesCancellationResult {
  const ResumeRepeatingChoreSeriesCancellationResult();
}

final class RepeatingChoreSeriesCancellationResumed
    extends ResumeRepeatingChoreSeriesCancellationResult {
  const RepeatingChoreSeriesCancellationResumed(this.snapshot);

  final RepeatingChoreSeriesCancellationResumeSnapshot snapshot;
}

final class ResumeRepeatingChoreSeriesCancellationFailed
    extends ResumeRepeatingChoreSeriesCancellationResult {
  const ResumeRepeatingChoreSeriesCancellationFailed(this.failure);

  final ChoreFailure failure;
}
