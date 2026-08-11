import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableChoreRepository implements ChoreRepository {
  const UnavailableChoreRepository();

  @override
  Future<LoadTodayChoresResult> loadToday(HouseholdId householdId) async {
    return const LoadTodayChoresFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadHouseholdActivationProgressResult> loadHouseholdActivationProgress(
    HouseholdId householdId,
  ) async {
    return const LoadHouseholdActivationProgressFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadHouseholdWeeklyReportResult> loadHouseholdWeeklyReport(
    HouseholdWeeklyReportRequest request,
  ) async {
    return const LoadHouseholdWeeklyReportFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadTodayChoresResult> loadChoreList(ChoreListRequest request) async {
    return const LoadTodayChoresFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadChoreOccurrenceTargetResult> loadOccurrenceTarget({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) async {
    return const LoadChoreOccurrenceTargetFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadChoreOccurrenceHistoryResult> loadOccurrenceHistory(
    ChoreOccurrenceHistoryRequest request,
  ) async {
    return const LoadChoreOccurrenceHistoryFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<LoadDeletedOneTimeChoresResult> loadDeletedOneTimeChores(
    DeletedOneTimeChoreListRequest request,
  ) async {
    return const LoadDeletedOneTimeChoresFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<CreateOneTimeChoreResult> createOneTimeChore(
    CreateOneTimeChoreRequest request,
  ) async {
    return const CreateOneTimeChoreFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<UpdateOneTimeChoreResult> updateOneTimeChore(
    UpdateOneTimeChoreRequest request,
  ) async {
    return const UpdateOneTimeChoreFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<DeleteOneTimeChoreResult> deleteOneTimeChore(
    DeleteOneTimeChoreRequest request,
  ) async {
    return const DeleteOneTimeChoreFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<RestoreOneTimeChoreResult> restoreOneTimeChore(
    RestoreOneTimeChoreRequest request,
  ) async {
    return const RestoreOneTimeChoreFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<CreateRecurringChoreResult> createRecurringChore(
    CreateRecurringChoreRequest request,
  ) async {
    return const CreateRecurringChoreFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<SetChoreCompletionResult> setOccurrenceCompletion(
    SetChoreCompletionRequest request,
  ) async {
    return const SetChoreCompletionFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<SkipChoreOccurrenceResult> skipOccurrence(
    SkipChoreOccurrenceRequest request,
  ) async {
    return const SkipChoreOccurrenceFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<RestoreSkippedChoreOccurrenceResult> restoreSkippedOccurrence(
    RestoreSkippedChoreOccurrenceRequest request,
  ) async {
    return const RestoreSkippedChoreOccurrenceFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<RescheduleChoreOccurrenceResult> rescheduleOccurrence(
    RescheduleChoreOccurrenceRequest request,
  ) async {
    return const RescheduleChoreOccurrenceFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<ReassignChoreOccurrenceResult> reassignOccurrence(
    ReassignChoreOccurrenceRequest request,
  ) async {
    return const ReassignChoreOccurrenceFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeries(
    UpdateRepeatingChoreSeriesRequest request,
  ) async {
    return const UpdateRepeatingChoreSeriesFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeriesFromOccurrence(
    UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    return const UpdateRepeatingChoreSeriesFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<CancelRepeatingChoreSeriesResult> cancelRepeatingSeries(
    CancelRepeatingChoreSeriesRequest request,
  ) async {
    return const CancelRepeatingChoreSeriesFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<CancelRepeatingChoreSeriesFromOccurrenceResult>
  cancelRepeatingSeriesFromOccurrence(
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    return const CancelRepeatingChoreSeriesFromOccurrenceFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }

  @override
  Future<ResumeRepeatingChoreSeriesCancellationResult>
  resumeRepeatingSeriesCancellation(
    ResumeRepeatingChoreSeriesCancellationRequest request,
  ) async {
    return const ResumeRepeatingChoreSeriesCancellationFailed(
      ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
    );
  }
}
