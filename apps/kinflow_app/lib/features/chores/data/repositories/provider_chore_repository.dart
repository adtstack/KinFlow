import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

final class ProviderChoreRepository implements ChoreRepository {
  const ProviderChoreRepository(this._dataSource);

  final ChoreDataSource _dataSource;

  @override
  Future<LoadTodayChoresResult> loadToday(HouseholdId householdId) async {
    final ChoreDataResult<TodayChoresDataRecord> result = await _dataSource
        .loadToday(householdId: householdId.value);
    return switch (result) {
      ChoreDataSucceeded<TodayChoresDataRecord>(
        :final value,
        :final cacheMetadata,
      ) =>
        _mapToday(value, householdId, cacheMetadata: cacheMetadata),
      ChoreDataFailed<TodayChoresDataRecord>(:final kind) =>
        LoadTodayChoresFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadHouseholdActivationProgressResult> loadHouseholdActivationProgress(
    HouseholdId householdId,
  ) async {
    final ChoreDataResult<HouseholdActivationProgressDataRecord> result =
        await _dataSource.loadHouseholdActivationProgress(
          householdId: householdId.value,
        );
    return switch (result) {
      ChoreDataSucceeded<HouseholdActivationProgressDataRecord>(:final value) =>
        _mapHouseholdActivationProgress(value, householdId),
      ChoreDataFailed<HouseholdActivationProgressDataRecord>(:final kind) =>
        LoadHouseholdActivationProgressFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadHouseholdWeeklyReportResult> loadHouseholdWeeklyReport(
    HouseholdWeeklyReportRequest request,
  ) async {
    final ChoreDataResult<HouseholdWeeklyReportDataRecord> result =
        await _dataSource.loadHouseholdWeeklyReport(
          householdId: request.householdId.value,
          weekOffset: request.weekOffset,
        );
    return switch (result) {
      ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>(:final value) =>
        _mapHouseholdWeeklyReport(value, request),
      ChoreDataFailed<HouseholdWeeklyReportDataRecord>(:final kind) =>
        LoadHouseholdWeeklyReportFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadTodayChoresResult> loadChoreList(ChoreListRequest request) async {
    final ChoreDataResult<ChoreListPageDataRecord> result = await _dataSource
        .loadChoreList(
          householdId: request.householdId.value,
          view: request.view.wireName,
          assigneeMemberId: request.assigneeMemberId?.value,
          limit: request.limit,
          afterCursor: request.cursor?.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreListPageDataRecord>(
        :final value,
        :final cacheMetadata,
      ) =>
        _mapChoreList(value, request, cacheMetadata: cacheMetadata),
      ChoreDataFailed<ChoreListPageDataRecord>(:final kind) =>
        LoadTodayChoresFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadChoreOccurrenceTargetResult> loadOccurrenceTarget({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) async {
    final ChoreDataResult<ChoreOccurrenceDataRecord> result = await _dataSource
        .loadOccurrenceTarget(
          householdId: householdId.value,
          occurrenceId: occurrenceId.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceDataRecord>(:final value) =>
        _mapOccurrenceTarget(value, householdId, occurrenceId),
      ChoreDataFailed<ChoreOccurrenceDataRecord>(:final kind) =>
        LoadChoreOccurrenceTargetFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadChoreOccurrenceHistoryResult> loadOccurrenceHistory(
    ChoreOccurrenceHistoryRequest request,
  ) async {
    final ChoreOccurrenceHistoryCursor? cursor = request.cursor;
    final ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord> result =
        await _dataSource.loadOccurrenceHistory(
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          limit: request.limit,
          beforeOccurredAt: cursor?.occurredAt.toIso8601String(),
          beforeEntryId: cursor?.entryId.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceHistoryPageDataRecord>(:final value) =>
        _mapOccurrenceHistory(value, request),
      ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(:final kind) =>
        LoadChoreOccurrenceHistoryFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadDeletedOneTimeChoresResult> loadDeletedOneTimeChores(
    DeletedOneTimeChoreListRequest request,
  ) async {
    final ChoreDataResult<DeletedOneTimeChorePageDataRecord> result =
        await _dataSource.loadDeletedOneTimeChores(
          householdId: request.householdId.value,
          limit: request.limit,
          beforeCursor: request.cursor?.value,
        );
    return switch (result) {
      ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>(:final value) =>
        _mapDeletedOneTimeChores(value, request),
      ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(:final kind) =>
        LoadDeletedOneTimeChoresFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CreateOneTimeChoreResult> createOneTimeChore(
    CreateOneTimeChoreRequest request,
  ) async {
    final ChoreDataResult<ChoreOccurrenceDataRecord> result = await _dataSource
        .createOneTimeChore(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId.value,
          dueLocalDate: request.dueLocalDate.value,
          dueLocalTime: request.dueLocalTime?.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceDataRecord>(:final value) =>
        _mapCreated(value, request.householdId),
      ChoreDataFailed<ChoreOccurrenceDataRecord>(:final kind) =>
        CreateOneTimeChoreFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<UpdateOneTimeChoreResult> updateOneTimeChore(
    UpdateOneTimeChoreRequest request,
  ) async {
    final ChoreDataResult<OneTimeChoreUpdateDataRecord> result =
        await _dataSource.updateOneTimeChore(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          expectedSeriesVersion: request.expectedSeriesVersion,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId.value,
          dueLocalDate: request.dueLocalDate.value,
          dueLocalTime: request.dueLocalTime?.value,
        );
    return switch (result) {
      ChoreDataSucceeded<OneTimeChoreUpdateDataRecord>(:final value) =>
        _mapOneTimeUpdated(value, request),
      ChoreDataFailed<OneTimeChoreUpdateDataRecord>(:final kind) =>
        UpdateOneTimeChoreFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<DeleteOneTimeChoreResult> deleteOneTimeChore(
    DeleteOneTimeChoreRequest request,
  ) async {
    final ChoreDataResult<OneTimeChoreDeletionDataRecord> result =
        await _dataSource.deleteOneTimeChore(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          expectedSeriesVersion: request.expectedSeriesVersion,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
        );
    return switch (result) {
      ChoreDataSucceeded<OneTimeChoreDeletionDataRecord>(:final value) =>
        _mapOneTimeDeleted(value, request),
      ChoreDataFailed<OneTimeChoreDeletionDataRecord>(:final kind) =>
        DeleteOneTimeChoreFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<RestoreOneTimeChoreResult> restoreOneTimeChore(
    RestoreOneTimeChoreRequest request,
  ) async {
    final ChoreDataResult<OneTimeChoreRestoreDataRecord> result =
        await _dataSource.restoreOneTimeChore(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          expectedSeriesVersion: request.expectedSeriesVersion,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
        );
    return switch (result) {
      ChoreDataSucceeded<OneTimeChoreRestoreDataRecord>(:final value) =>
        _mapOneTimeRestored(value, request),
      ChoreDataFailed<OneTimeChoreRestoreDataRecord>(:final kind) =>
        RestoreOneTimeChoreFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CreateRecurringChoreResult> createRecurringChore(
    CreateRecurringChoreRequest request,
  ) async {
    final ChoreDataResult<RecurringChoreDataRecord> result = await _dataSource
        .createRepeatingChore(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId.value,
          startLocalDate: request.startLocalDate.value,
          dueLocalTime: request.dueLocalTime?.value,
          recurrenceRule: request.recurrenceRule.toJson(),
        );
    return switch (result) {
      ChoreDataSucceeded<RecurringChoreDataRecord>(:final value) =>
        _mapRecurringCreated(value, request),
      ChoreDataFailed<RecurringChoreDataRecord>(:final kind) =>
        CreateRecurringChoreFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<SetChoreCompletionResult> setOccurrenceCompletion(
    SetChoreCompletionRequest request,
  ) async {
    final ChoreDataResult<ChoreCompletionDataRecord> result = await _dataSource
        .setCompletion(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          expectedVersion: request.expectedVersion,
          completed: request.completed,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreCompletionDataRecord>(:final value) =>
        _mapCompletion(value, request),
      ChoreDataFailed<ChoreCompletionDataRecord>(:final kind) =>
        SetChoreCompletionFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<SkipChoreOccurrenceResult> skipOccurrence(
    SkipChoreOccurrenceRequest request,
  ) async {
    final ChoreDataResult<ChoreOccurrenceSkipDataRecord> result =
        await _dataSource.skipOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          expectedVersion: request.expectedVersion,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceSkipDataRecord>(:final value) =>
        _mapSkipped(value, request),
      ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(:final kind) =>
        SkipChoreOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<RestoreSkippedChoreOccurrenceResult> restoreSkippedOccurrence(
    RestoreSkippedChoreOccurrenceRequest request,
  ) async {
    final ChoreDataResult<ChoreOccurrenceRestoreDataRecord> result =
        await _dataSource.restoreSkippedOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          expectedVersion: request.expectedVersion,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceRestoreDataRecord>(:final value) =>
        _mapRestored(value, request),
      ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(:final kind) =>
        RestoreSkippedChoreOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<RescheduleChoreOccurrenceResult> rescheduleOccurrence(
    RescheduleChoreOccurrenceRequest request,
  ) async {
    final ChoreDataResult<ChoreOccurrenceRescheduleDataRecord> result =
        await _dataSource.rescheduleOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          expectedVersion: request.expectedVersion,
          dueLocalDate: request.dueLocalDate.value,
          dueLocalTime: request.dueLocalTime?.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceRescheduleDataRecord>(:final value) =>
        _mapRescheduled(value, request),
      ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(:final kind) =>
        RescheduleChoreOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<ReassignChoreOccurrenceResult> reassignOccurrence(
    ReassignChoreOccurrenceRequest request,
  ) async {
    final ChoreDataResult<ChoreOccurrenceReassignmentDataRecord> result =
        await _dataSource.reassignOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          occurrenceId: request.occurrenceId.value,
          expectedVersion: request.expectedVersion,
          assigneeMemberId: request.assigneeMemberId.value,
        );
    return switch (result) {
      ChoreDataSucceeded<ChoreOccurrenceReassignmentDataRecord>(:final value) =>
        _mapReassigned(value, request),
      ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(:final kind) =>
        ReassignChoreOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeries(
    UpdateRepeatingChoreSeriesRequest request,
  ) async {
    final ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord> result =
        await _dataSource.updateRepeatingSeries(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          expectedVersion: request.expectedVersion,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId.value,
          dueLocalTime: request.dueLocalTime?.value,
          recurrenceRule: request.recurrenceRule.toJson(),
        );
    return switch (result) {
      ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(:final value) =>
        _mapSeriesUpdated(
          value,
          householdId: request.householdId,
          seriesId: request.seriesId,
          expectedVersion: request.expectedVersion,
          minimumEffectiveLocalDate: request.effectiveLocalDate,
        ),
      ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(:final kind) =>
        UpdateRepeatingChoreSeriesFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeriesFromOccurrence(
    UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    final ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord> result =
        await _dataSource.updateRepeatingSeriesFromOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          effectiveOccurrenceId: request.effectiveOccurrenceId.value,
          expectedVersion: request.expectedVersion,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId.value,
          dueLocalTime: request.dueLocalTime?.value,
          recurrenceRule: request.recurrenceRule.toJson(),
        );
    return switch (result) {
      ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(:final value) =>
        _mapSeriesUpdated(
          value,
          householdId: request.householdId,
          seriesId: request.seriesId,
          expectedVersion: request.expectedVersion,
        ),
      ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(:final kind) =>
        UpdateRepeatingChoreSeriesFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CancelRepeatingChoreSeriesResult> cancelRepeatingSeries(
    CancelRepeatingChoreSeriesRequest request,
  ) async {
    final ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord> result =
        await _dataSource.cancelRepeatingSeries(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          expectedVersion: request.expectedVersion,
        );
    return switch (result) {
      ChoreDataSucceeded<RepeatingChoreSeriesCancellationDataRecord>(
        :final value,
      ) =>
        _mapSeriesCancelled(value, request),
      ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
        :final kind,
      ) =>
        CancelRepeatingChoreSeriesFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CancelRepeatingChoreSeriesFromOccurrenceResult>
  cancelRepeatingSeriesFromOccurrence(
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    final ChoreDataResult<
      RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
    >
    result = await _dataSource.cancelRepeatingSeriesFromOccurrence(
      idempotencyKey: request.idempotencyKey.value,
      householdId: request.householdId.value,
      seriesId: request.seriesId.value,
      effectiveOccurrenceId: request.effectiveOccurrenceId.value,
      expectedVersion: request.expectedVersion,
    );
    return switch (result) {
      ChoreDataSucceeded<
        RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
      >(
        :final value,
      ) =>
        _mapSeriesCancelledFromOccurrence(value, request),
      ChoreDataFailed<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>(
        :final kind,
      ) =>
        CancelRepeatingChoreSeriesFromOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<ResumeRepeatingChoreSeriesCancellationResult>
  resumeRepeatingSeriesCancellation(
    ResumeRepeatingChoreSeriesCancellationRequest request,
  ) async {
    final ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>
    result = await _dataSource.resumeRepeatingSeriesCancellation(
      idempotencyKey: request.idempotencyKey.value,
      householdId: request.householdId.value,
      seriesId: request.seriesId.value,
      cancellationIdempotencyKey: request.cancellationIdempotencyKey.value,
      expectedVersion: request.expectedVersion,
    );
    return switch (result) {
      ChoreDataSucceeded<RepeatingChoreSeriesCancellationResumeDataRecord>(
        :final value,
      ) =>
        _mapSeriesCancellationResumed(value, request),
      ChoreDataFailed<RepeatingChoreSeriesCancellationResumeDataRecord>(
        :final kind,
      ) =>
        ResumeRepeatingChoreSeriesCancellationFailed(_mapFailure(kind)),
    };
  }

  LoadTodayChoresResult _mapToday(
    TodayChoresDataRecord record,
    HouseholdId expectedHouseholdId, {
    ReadCacheMetadata? cacheMetadata,
  }) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreLocalDate? localDate = ChoreLocalDate.tryParse(
      record.householdLocalDate,
    );
    if (householdId != expectedHouseholdId ||
        localDate == null ||
        !_isPlausibleTimezone(record.householdTimezone)) {
      return const LoadTodayChoresFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    final List<ChoreOccurrence> occurrences = <ChoreOccurrence>[];
    for (final ChoreOccurrenceDataRecord item in record.occurrences) {
      final ChoreOccurrence? occurrence = _mapOccurrence(
        item,
        expectedHouseholdId,
      );
      if (occurrence == null || occurrence.dueLocalDate != localDate) {
        return const LoadTodayChoresFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      occurrences.add(occurrence);
    }
    return TodayChoresLoaded(
      TodayChores(
        householdId: householdId!,
        householdTimezone: record.householdTimezone,
        localDate: localDate,
        occurrences: occurrences,
      ),
      cacheMetadata: cacheMetadata,
    );
  }

  LoadHouseholdActivationProgressResult _mapHouseholdActivationProgress(
    HouseholdActivationProgressDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    if (householdId != expectedHouseholdId) {
      return const LoadHouseholdActivationProgressFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    final HouseholdActivationProgress? progress =
        HouseholdActivationProgress.tryCreate(
          householdId: householdId!,
          adultParticipantProgress: record.adultParticipantProgress,
          choreCreationProgress: record.choreCreationProgress,
          distinctAdultCompleterProgress: record.distinctAdultCompleterProgress,
          returnAfterFirstDayReached: record.returnAfterFirstDayReached,
        );
    return progress == null
        ? const LoadHouseholdActivationProgressFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : HouseholdActivationProgressLoaded(progress);
  }

  LoadHouseholdWeeklyReportResult _mapHouseholdWeeklyReport(
    HouseholdWeeklyReportDataRecord record,
    HouseholdWeeklyReportRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final DateTime? generatedAt = DateTime.tryParse(record.generatedAt);
    final ChoreLocalDate? weekStart = ChoreLocalDate.tryParse(record.weekStart);
    final ChoreLocalDate? weekEnd = ChoreLocalDate.tryParse(record.weekEnd);
    if (householdId != request.householdId ||
        generatedAt == null ||
        !generatedAt.isUtc ||
        weekStart == null ||
        weekEnd == null ||
        record.weekOffset != request.weekOffset ||
        !_isPlausibleTimezone(record.householdTimezone) ||
        record.members.length > HouseholdWeeklyReport.maximumNamedMembers) {
      return const LoadHouseholdWeeklyReportFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }

    final List<HouseholdWeeklyReportMember> members =
        <HouseholdWeeklyReportMember>[];
    String? previousDisplayName;
    String? previousMemberId;
    for (final HouseholdWeeklyReportMemberDataRecord item in record.members) {
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
        item.memberId,
      );
      if (memberId == null) {
        return const LoadHouseholdWeeklyReportFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      final String normalizedDisplayName = item.displayName.toLowerCase();
      if (previousDisplayName != null &&
          (normalizedDisplayName.compareTo(previousDisplayName) < 0 ||
              normalizedDisplayName == previousDisplayName &&
                  item.memberId.compareTo(previousMemberId!) <= 0)) {
        return const LoadHouseholdWeeklyReportFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      final HouseholdWeeklyReportMember? member =
          HouseholdWeeklyReportMember.tryCreate(
            memberId: memberId,
            displayName: item.displayName,
            completedCount: item.completedCount,
            completedByWeekEndCount: item.completedByWeekEndCount,
            isViewer: item.isViewer,
          );
      if (member == null) {
        return const LoadHouseholdWeeklyReportFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      members.add(member);
      previousDisplayName = normalizedDisplayName;
      previousMemberId = item.memberId;
    }

    final HouseholdWeeklyReport? report = HouseholdWeeklyReport.tryCreate(
      householdId: householdId!,
      householdTimezone: record.householdTimezone,
      generatedAt: generatedAt.toUtc(),
      weekOffset: record.weekOffset,
      weekStart: weekStart,
      weekEnd: weekEnd,
      dueCount: record.dueCount,
      completedCount: record.completedCount,
      completedByWeekEndCount: record.completedByWeekEndCount,
      completedAfterWeekEndCount: record.completedAfterWeekEndCount,
      openCount: record.openCount,
      skippedCount: record.skippedCount,
      viewerCompletedCount: record.viewerCompletedCount,
      members: members,
      otherMemberCompletedCount: record.otherMemberCompletedCount,
      memberBreakdownTruncated: record.memberBreakdownTruncated,
    );
    return report == null
        ? const LoadHouseholdWeeklyReportFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : HouseholdWeeklyReportLoaded(report);
  }

  LoadTodayChoresResult _mapChoreList(
    ChoreListPageDataRecord record,
    ChoreListRequest request, {
    ReadCacheMetadata? cacheMetadata,
  }) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreLocalDate? localDate = ChoreLocalDate.tryParse(
      record.householdLocalDate,
    );
    final DateTime? generatedAt = DateTime.tryParse(record.generatedAt);
    final ChoreListView? view = ChoreListView.tryParse(record.listView);
    final HouseholdMemberId? assigneeFilterMemberId =
        record.assigneeFilterMemberId == null
        ? null
        : HouseholdMemberId.tryParse(record.assigneeFilterMemberId!);
    final ChoreListCursor? nextCursor = record.pageCursor == null
        ? null
        : ChoreListCursor.tryParse(record.pageCursor!);
    if (householdId != request.householdId ||
        localDate == null ||
        generatedAt == null ||
        !generatedAt.isUtc ||
        view != request.view ||
        (record.assigneeFilterMemberId != null &&
            assigneeFilterMemberId == null) ||
        assigneeFilterMemberId != request.assigneeMemberId ||
        record.pageLimit != request.limit ||
        record.occurrences.length > request.limit ||
        (record.pageCursor != null && nextCursor == null) ||
        (record.hasMore && nextCursor == null) ||
        (!record.hasMore && nextCursor != null) ||
        nextCursor != null && nextCursor == request.cursor ||
        !_isPlausibleTimezone(record.householdTimezone)) {
      return const LoadTodayChoresFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    final List<ChoreOccurrence> occurrences = <ChoreOccurrence>[];
    final Set<ChoreOccurrenceId> occurrenceIds = <ChoreOccurrenceId>{};
    ChoreOccurrence? previous;
    for (final ChoreOccurrenceDataRecord item in record.occurrences) {
      final ChoreOccurrence? occurrence = _mapOccurrence(
        item,
        request.householdId,
      );
      if (occurrence == null ||
          !occurrenceIds.add(occurrence.id) ||
          !_occurrenceMatchesQuery(
            occurrence,
            localDate: localDate,
            view: view!,
            assigneeMemberId: assigneeFilterMemberId,
          ) ||
          previous != null &&
              _compareChoreListOccurrences(view, previous, occurrence) >= 0) {
        return const LoadTodayChoresFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      occurrences.add(occurrence);
      previous = occurrence;
    }
    return TodayChoresLoaded(
      TodayChores(
        householdId: householdId!,
        householdTimezone: record.householdTimezone,
        localDate: localDate,
        occurrences: occurrences,
        view: view!,
        assigneeFilterMemberId: assigneeFilterMemberId,
        generatedAt: generatedAt.toUtc(),
        pageLimit: record.pageLimit,
        hasMore: record.hasMore,
        nextCursor: nextCursor,
      ),
      cacheMetadata: cacheMetadata,
    );
  }

  LoadChoreOccurrenceHistoryResult _mapOccurrenceHistory(
    ChoreOccurrenceHistoryPageDataRecord record,
    ChoreOccurrenceHistoryRequest request,
  ) {
    if (record.events.length > request.limit) {
      return const LoadChoreOccurrenceHistoryFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    final List<ChoreOccurrenceHistoryEvent> events =
        <ChoreOccurrenceHistoryEvent>[];
    for (final ChoreOccurrenceHistoryDataRecord item in record.events) {
      final HouseholdId? householdId = HouseholdId.tryParse(item.householdId);
      final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
        item.occurrenceId,
      );
      final ChoreHistoryEntryId? entryId = ChoreHistoryEntryId.tryParse(
        item.historyEntryId,
      );
      final ChoreOccurrenceHistoryEventType? type = switch (item.eventType) {
        'completed' => ChoreOccurrenceHistoryEventType.completed,
        'reopened' => ChoreOccurrenceHistoryEventType.reopened,
        'skipped' => ChoreOccurrenceHistoryEventType.skipped,
        'restored' => ChoreOccurrenceHistoryEventType.restored,
        'rescheduled' => ChoreOccurrenceHistoryEventType.rescheduled,
        'reassigned' => ChoreOccurrenceHistoryEventType.reassigned,
        _ => null,
      };
      final HouseholdMemberId? actorMemberId = HouseholdMemberId.tryParse(
        item.actorMemberId,
      );
      final HouseholdMemberId? actingMemberId = item.actingMemberId == null
          ? null
          : HouseholdMemberId.tryParse(item.actingMemberId!);
      final DateTime? occurredAt = DateTime.tryParse(item.occurredAt);
      final ChoreLocalDate? previousDueLocalDate =
          item.previousDueLocalDate == null
          ? null
          : ChoreLocalDate.tryParse(item.previousDueLocalDate!);
      final ChoreLocalTime? previousDueLocalTime =
          item.previousDueLocalTime == null
          ? null
          : ChoreLocalTime.tryParse(item.previousDueLocalTime!);
      final ChoreLocalDate? newDueLocalDate = item.newDueLocalDate == null
          ? null
          : ChoreLocalDate.tryParse(item.newDueLocalDate!);
      final ChoreLocalTime? newDueLocalTime = item.newDueLocalTime == null
          ? null
          : ChoreLocalTime.tryParse(item.newDueLocalTime!);
      final HouseholdMemberId? previousAssigneeMemberId =
          item.previousAssigneeMemberId == null
          ? null
          : HouseholdMemberId.tryParse(item.previousAssigneeMemberId!);
      final HouseholdMemberId? newAssigneeMemberId =
          item.newAssigneeMemberId == null
          ? null
          : HouseholdMemberId.tryParse(item.newAssigneeMemberId!);
      if (householdId != request.householdId ||
          occurrenceId != request.occurrenceId ||
          entryId == null ||
          type == null ||
          actorMemberId == null ||
          (item.actingMemberId != null && actingMemberId == null) ||
          occurredAt == null ||
          !occurredAt.isUtc ||
          (item.previousDueLocalDate != null && previousDueLocalDate == null) ||
          (item.previousDueLocalTime != null && previousDueLocalTime == null) ||
          (item.newDueLocalDate != null && newDueLocalDate == null) ||
          (item.newDueLocalTime != null && newDueLocalTime == null) ||
          (item.previousAssigneeMemberId != null &&
              previousAssigneeMemberId == null) ||
          (item.newAssigneeMemberId != null && newAssigneeMemberId == null)) {
        return const LoadChoreOccurrenceHistoryFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      final ChoreOccurrenceHistoryEvent? event =
          ChoreOccurrenceHistoryEvent.tryCreate(
            id: entryId,
            type: type,
            actorMemberId: actorMemberId,
            actorDisplayName: item.actorDisplayName,
            actingMemberId: actingMemberId,
            actingDisplayName: item.actingDisplayName,
            occurredAt: occurredAt.toUtc(),
            occurrenceVersion: item.occurrenceVersion,
            previousDueLocalDate: previousDueLocalDate,
            previousDueLocalTime: previousDueLocalTime,
            newDueLocalDate: newDueLocalDate,
            newDueLocalTime: newDueLocalTime,
            previousAssigneeMemberId: previousAssigneeMemberId,
            previousAssigneeDisplayName: item.previousAssigneeDisplayName,
            newAssigneeMemberId: newAssigneeMemberId,
            newAssigneeDisplayName: item.newAssigneeDisplayName,
          );
      if (event == null ||
          request.cursor != null && !_isBeforeCursor(event, request.cursor!)) {
        return const LoadChoreOccurrenceHistoryFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      events.add(event);
    }
    final ChoreOccurrenceHistoryPage? page =
        ChoreOccurrenceHistoryPage.tryCreate(
          householdId: request.householdId,
          occurrenceId: request.occurrenceId,
          events: events,
          hasMore: record.hasMore,
        );
    return page == null
        ? const LoadChoreOccurrenceHistoryFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : ChoreOccurrenceHistoryLoaded(page);
  }

  LoadDeletedOneTimeChoresResult _mapDeletedOneTimeChores(
    DeletedOneTimeChorePageDataRecord record,
    DeletedOneTimeChoreListRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final DateTime? generatedAt = DateTime.tryParse(record.generatedAt);
    final DeletedOneTimeChoreCursor? nextCursor = record.pageCursor == null
        ? null
        : DeletedOneTimeChoreCursor.tryParse(record.pageCursor!);
    if (householdId != request.householdId ||
        generatedAt == null ||
        !generatedAt.isUtc ||
        !_isPlausibleTimezone(record.householdTimezone) ||
        record.pageLimit != request.limit ||
        record.items.length > request.limit ||
        (record.pageCursor != null && nextCursor == null) ||
        record.hasMore != (nextCursor != null) ||
        record.hasMore && record.items.length != request.limit ||
        nextCursor != null && nextCursor == request.cursor) {
      return const LoadDeletedOneTimeChoresFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    final List<DeletedOneTimeChore> items = <DeletedOneTimeChore>[];
    for (final DeletedOneTimeChoreDataRecord item in record.items) {
      final HouseholdId? itemHouseholdId = HouseholdId.tryParse(
        item.householdId,
      );
      final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(item.seriesId);
      final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
        item.occurrenceId,
      );
      final HouseholdMemberId? assigneeMemberId = HouseholdMemberId.tryParse(
        item.assigneeMemberId,
      );
      final ChoreLocalDate? dueLocalDate = ChoreLocalDate.tryParse(
        item.dueLocalDate,
      );
      final ChoreLocalTime? dueLocalTime = item.dueLocalTime == null
          ? null
          : ChoreLocalTime.tryParse(item.dueLocalTime!);
      final DateTime? dueAt = item.dueAt == null
          ? null
          : DateTime.tryParse(item.dueAt!);
      final DateTime? deletedAt = DateTime.tryParse(item.deletedAt);
      if (itemHouseholdId != request.householdId ||
          seriesId == null ||
          occurrenceId == null ||
          assigneeMemberId == null ||
          dueLocalDate == null ||
          (item.dueLocalTime != null && dueLocalTime == null) ||
          (item.dueAt != null && (dueAt == null || !dueAt.isUtc)) ||
          deletedAt == null ||
          !deletedAt.isUtc) {
        return const LoadDeletedOneTimeChoresFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      final DeletedOneTimeChore? deleted = DeletedOneTimeChore.tryCreate(
        householdId: itemHouseholdId!,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        title: item.title,
        description: item.description,
        assigneeMemberId: assigneeMemberId,
        assigneeDisplayName: item.assigneeDisplayName,
        dueLocalDate: dueLocalDate,
        dueLocalTime: dueLocalTime,
        dueAt: dueAt?.toUtc(),
        deletedAt: deletedAt.toUtc(),
        seriesVersion: item.seriesVersion,
        occurrenceVersion: item.occurrenceVersion,
      );
      if (deleted == null) {
        return const LoadDeletedOneTimeChoresFailed(
          ChoreFailure(ChoreFailureKind.invalidPayload),
        );
      }
      items.add(deleted);
    }
    final DeletedOneTimeChorePage? page = DeletedOneTimeChorePage.tryCreate(
      householdId: householdId!,
      householdTimezone: record.householdTimezone,
      generatedAt: generatedAt.toUtc(),
      pageLimit: record.pageLimit,
      hasMore: record.hasMore,
      nextCursor: nextCursor,
      items: items,
    );
    return page == null
        ? const LoadDeletedOneTimeChoresFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : DeletedOneTimeChoresLoaded(page);
  }

  CreateOneTimeChoreResult _mapCreated(
    ChoreOccurrenceDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final ChoreOccurrence? occurrence = _mapOccurrence(
      record,
      expectedHouseholdId,
    );
    return occurrence == null
        ? const CreateOneTimeChoreFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : OneTimeChoreCreated(occurrence);
  }

  LoadChoreOccurrenceTargetResult _mapOccurrenceTarget(
    ChoreOccurrenceDataRecord record,
    HouseholdId expectedHouseholdId,
    ChoreOccurrenceId expectedOccurrenceId,
  ) {
    final ChoreOccurrence? occurrence = _mapOccurrence(
      record,
      expectedHouseholdId,
    );
    return occurrence == null || occurrence.id != expectedOccurrenceId
        ? const LoadChoreOccurrenceTargetFailed(
            ChoreFailure(ChoreFailureKind.invalidPayload),
          )
        : ChoreOccurrenceTargetLoaded(occurrence);
  }

  UpdateOneTimeChoreResult _mapOneTimeUpdated(
    OneTimeChoreUpdateDataRecord record,
    UpdateOneTimeChoreRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    final ChoreRevisionId? revisionId = ChoreRevisionId.tryParse(
      record.revisionId,
    );
    final ChoreLocalDate? dueLocalDate = ChoreLocalDate.tryParse(
      record.dueLocalDate,
    );
    final ChoreLocalTime? dueLocalTime = record.dueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(record.dueLocalTime!);
    final DateTime? dueAt = record.dueAt == null
        ? null
        : DateTime.tryParse(record.dueAt!);
    final HouseholdMemberId? assigneeMemberId = HouseholdMemberId.tryParse(
      record.assigneeMemberId,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        occurrenceId != request.occurrenceId ||
        revisionId == null ||
        dueLocalDate != request.dueLocalDate ||
        dueLocalTime != request.dueLocalTime ||
        (record.dueLocalTime != null && dueLocalTime == null) ||
        (record.dueAt != null && (dueAt == null || !dueAt.isUtc)) ||
        (dueLocalTime == null) != (dueAt == null) ||
        assigneeMemberId != request.assigneeMemberId ||
        record.revisionNumber < 2 ||
        record.revisionNumber != record.seriesVersion ||
        record.seriesVersion != request.expectedSeriesVersion + 1 ||
        record.occurrenceVersion != request.expectedOccurrenceVersion + 1) {
      return const UpdateOneTimeChoreFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return OneTimeChoreUpdated(
      OneTimeChoreUpdateSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        occurrenceId: occurrenceId!,
        revisionId: revisionId,
        revisionNumber: record.revisionNumber,
        dueLocalDate: dueLocalDate!,
        dueLocalTime: dueLocalTime,
        dueAt: dueAt?.toUtc(),
        assigneeMemberId: assigneeMemberId!,
        seriesVersion: record.seriesVersion,
        occurrenceVersion: record.occurrenceVersion,
        changed: record.changed,
      ),
    );
  }

  DeleteOneTimeChoreResult _mapOneTimeDeleted(
    OneTimeChoreDeletionDataRecord record,
    DeleteOneTimeChoreRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        occurrenceId != request.occurrenceId ||
        record.status != 'cancelled' ||
        record.seriesVersion != request.expectedSeriesVersion + 1 ||
        record.occurrenceVersion != request.expectedOccurrenceVersion + 1) {
      return const DeleteOneTimeChoreFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return OneTimeChoreDeleted(
      OneTimeChoreDeletionSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        occurrenceId: occurrenceId!,
        seriesVersion: record.seriesVersion,
        occurrenceVersion: record.occurrenceVersion,
        changed: record.changed,
      ),
    );
  }

  RestoreOneTimeChoreResult _mapOneTimeRestored(
    OneTimeChoreRestoreDataRecord record,
    RestoreOneTimeChoreRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        occurrenceId != request.occurrenceId ||
        record.status != 'scheduled' ||
        record.seriesVersion != request.expectedSeriesVersion + 1 ||
        record.occurrenceVersion != request.expectedOccurrenceVersion + 1) {
      return const RestoreOneTimeChoreFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return OneTimeChoreRestored(
      OneTimeChoreRestoreSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        occurrenceId: occurrenceId!,
        seriesVersion: record.seriesVersion,
        occurrenceVersion: record.occurrenceVersion,
        changed: record.changed,
      ),
    );
  }

  CreateRecurringChoreResult _mapRecurringCreated(
    RecurringChoreDataRecord record,
    CreateRecurringChoreRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreOccurrenceId? firstOccurrenceId = ChoreOccurrenceId.tryParse(
      record.firstOccurrenceId,
    );
    final ChoreRecurrenceRule? recurrenceRule = ChoreRecurrenceRule.tryParse(
      record.recurrenceRule,
    );
    final ChoreLocalDate? materializedThrough = ChoreLocalDate.tryParse(
      record.materializedThrough,
    );
    final ChoreLocalDate maximumThrough = ChoreLocalDate.fromDateTime(
      request.startLocalDate.toDateTime().add(const Duration(days: 365)),
    );
    final ChoreRecurrenceEnd end = request.recurrenceRule.end;
    final bool endBoundaryValid = switch (end) {
      ChoreRecurrenceCountEnd(:final count) =>
        record.materializedCount <= count,
      ChoreRecurrenceUntilEnd(:final localDate) =>
        materializedThrough != null &&
            materializedThrough.value.compareTo(localDate.value) <= 0,
      ChoreRecurrenceNeverEnds() => true,
    };
    if (householdId != request.householdId ||
        seriesId == null ||
        firstOccurrenceId == null ||
        recurrenceRule == null ||
        recurrenceRule.fingerprint != request.recurrenceRule.fingerprint ||
        materializedThrough == null ||
        materializedThrough.value.compareTo(request.startLocalDate.value) < 0 ||
        materializedThrough.value.compareTo(maximumThrough.value) > 0 ||
        record.materializedCount < 1 ||
        record.materializedCount > 366 ||
        !endBoundaryValid) {
      return const CreateRecurringChoreFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return RecurringChoreCreated(
      RecurringChoreSnapshot(
        householdId: householdId!,
        seriesId: seriesId,
        firstOccurrenceId: firstOccurrenceId,
        recurrenceRule: recurrenceRule,
        materializedThrough: materializedThrough,
        materializedCount: record.materializedCount,
        created: record.created,
      ),
    );
  }

  SetChoreCompletionResult _mapCompletion(
    ChoreCompletionDataRecord record,
    SetChoreCompletionRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    final ChoreOccurrenceStatus? status = switch (record.status) {
      'scheduled' => ChoreOccurrenceStatus.scheduled,
      'completed' => ChoreOccurrenceStatus.completed,
      _ => null,
    };
    final HouseholdMemberId? completedByMemberId =
        record.completedByMemberId == null
        ? null
        : HouseholdMemberId.tryParse(record.completedByMemberId!);
    final DateTime? completedAt = record.completedAt == null
        ? null
        : DateTime.tryParse(record.completedAt!);
    final ChoreOccurrenceStatus expectedStatus = request.completed
        ? ChoreOccurrenceStatus.completed
        : ChoreOccurrenceStatus.scheduled;
    final bool completionFieldsValid = status == ChoreOccurrenceStatus.completed
        ? completedByMemberId != null &&
              completedAt != null &&
              completedAt.isUtc
        : completedByMemberId == null && completedAt == null;
    if (householdId != request.householdId ||
        occurrenceId != request.occurrenceId ||
        status != expectedStatus ||
        record.version != request.expectedVersion + 1 ||
        !completionFieldsValid) {
      return const SetChoreCompletionFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return ChoreCompletionSet(
      ChoreCompletionSnapshot(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        status: status!,
        version: record.version,
        completedByMemberId: completedByMemberId,
        completedAt: completedAt?.toUtc(),
        changed: record.changed,
      ),
    );
  }

  SkipChoreOccurrenceResult _mapSkipped(
    ChoreOccurrenceSkipDataRecord record,
    SkipChoreOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    if (householdId != request.householdId ||
        occurrenceId != request.occurrenceId ||
        record.status != 'skipped' ||
        record.version != request.expectedVersion + 1) {
      return const SkipChoreOccurrenceFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return ChoreOccurrenceSkipped(
      ChoreOccurrenceSkipSnapshot(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        version: record.version,
        changed: record.changed,
      ),
    );
  }

  RestoreSkippedChoreOccurrenceResult _mapRestored(
    ChoreOccurrenceRestoreDataRecord record,
    RestoreSkippedChoreOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    if (householdId != request.householdId ||
        occurrenceId != request.occurrenceId ||
        record.status != 'scheduled' ||
        record.version != request.expectedVersion + 1) {
      return const RestoreSkippedChoreOccurrenceFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return ChoreOccurrenceRestored(
      ChoreOccurrenceRestoreSnapshot(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        version: record.version,
        changed: record.changed,
      ),
    );
  }

  RescheduleChoreOccurrenceResult _mapRescheduled(
    ChoreOccurrenceRescheduleDataRecord record,
    RescheduleChoreOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    final ChoreLocalDate? dueLocalDate = ChoreLocalDate.tryParse(
      record.dueLocalDate,
    );
    final ChoreLocalTime? dueLocalTime = record.dueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(record.dueLocalTime!);
    final DateTime? dueAt = record.dueAt == null
        ? null
        : DateTime.tryParse(record.dueAt!);
    if (householdId != request.householdId ||
        occurrenceId != request.occurrenceId ||
        dueLocalDate != request.dueLocalDate ||
        dueLocalTime != request.dueLocalTime ||
        (record.dueLocalTime != null && dueLocalTime == null) ||
        (record.dueAt != null && (dueAt == null || !dueAt.isUtc)) ||
        (dueLocalTime == null) != (dueAt == null) ||
        record.status != 'scheduled' ||
        record.version != request.expectedVersion + 1) {
      return const RescheduleChoreOccurrenceFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return ChoreOccurrenceRescheduled(
      ChoreOccurrenceRescheduleSnapshot(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        dueLocalDate: dueLocalDate!,
        dueLocalTime: dueLocalTime,
        dueAt: dueAt?.toUtc(),
        version: record.version,
        changed: record.changed,
      ),
    );
  }

  ReassignChoreOccurrenceResult _mapReassigned(
    ChoreOccurrenceReassignmentDataRecord record,
    ReassignChoreOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    final HouseholdMemberId? assigneeMemberId = HouseholdMemberId.tryParse(
      record.assigneeMemberId,
    );
    final String assigneeDisplayName = record.assigneeDisplayName.trim();
    if (householdId != request.householdId ||
        occurrenceId != request.occurrenceId ||
        assigneeMemberId != request.assigneeMemberId ||
        assigneeDisplayName.isEmpty ||
        assigneeDisplayName.length > 80 ||
        assigneeDisplayName != record.assigneeDisplayName ||
        record.status != 'scheduled' ||
        record.version != request.expectedVersion + 1) {
      return const ReassignChoreOccurrenceFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return ChoreOccurrenceReassigned(
      ChoreOccurrenceReassignmentSnapshot(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        assigneeMemberId: assigneeMemberId!,
        assigneeDisplayName: assigneeDisplayName,
        version: record.version,
        changed: record.changed,
      ),
    );
  }

  UpdateRepeatingChoreSeriesResult _mapSeriesUpdated(
    RepeatingChoreSeriesUpdateDataRecord record, {
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required int expectedVersion,
    ChoreLocalDate? minimumEffectiveLocalDate,
  }) {
    final HouseholdId? parsedHouseholdId = HouseholdId.tryParse(
      record.householdId,
    );
    final ChoreSeriesId? parsedSeriesId = ChoreSeriesId.tryParse(
      record.seriesId,
    );
    final ChoreRevisionId? revisionId = ChoreRevisionId.tryParse(
      record.revisionId,
    );
    final ChoreLocalDate? effectiveLocalDate = ChoreLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    if (parsedHouseholdId != householdId ||
        parsedSeriesId != seriesId ||
        revisionId == null ||
        effectiveLocalDate == null ||
        minimumEffectiveLocalDate != null &&
            effectiveLocalDate.value.compareTo(
                  minimumEffectiveLocalDate.value,
                ) <
                0 ||
        record.revisionNumber < 2 ||
        record.version != expectedVersion + 1 ||
        record.rebuiltCount < 0 ||
        record.rebuiltCount > 366 ||
        record.cancelledCount < 0 ||
        record.preservedCompletedCount < 0) {
      return const UpdateRepeatingChoreSeriesFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return RepeatingChoreSeriesUpdated(
      RepeatingChoreSeriesUpdateSnapshot(
        householdId: parsedHouseholdId!,
        seriesId: parsedSeriesId!,
        revisionId: revisionId,
        revisionNumber: record.revisionNumber,
        effectiveLocalDate: effectiveLocalDate,
        version: record.version,
        rebuiltCount: record.rebuiltCount,
        cancelledCount: record.cancelledCount,
        preservedCompletedCount: record.preservedCompletedCount,
        changed: record.changed,
      ),
    );
  }

  CancelRepeatingChoreSeriesResult _mapSeriesCancelled(
    RepeatingChoreSeriesCancellationDataRecord record,
    CancelRepeatingChoreSeriesRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreLocalDate? effectiveLocalDate = ChoreLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        effectiveLocalDate == null ||
        record.version != request.expectedVersion + 1 ||
        record.cancelledCount < 0 ||
        record.preservedCompletedCount < 0) {
      return const CancelRepeatingChoreSeriesFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return RepeatingChoreSeriesCancelled(
      RepeatingChoreSeriesCancellationSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        effectiveLocalDate: effectiveLocalDate,
        version: record.version,
        cancelledCount: record.cancelledCount,
        preservedCompletedCount: record.preservedCompletedCount,
        changed: record.changed,
      ),
    );
  }

  CancelRepeatingChoreSeriesFromOccurrenceResult
  _mapSeriesCancelledFromOccurrence(
    RepeatingChoreSeriesFromOccurrenceCancellationDataRecord record,
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreLocalDate? effectiveLocalDate = ChoreLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    final ChoreRevisionId? terminalRevisionId =
        record.terminalRevisionId == null
        ? null
        : ChoreRevisionId.tryParse(record.terminalRevisionId!);
    final bool terminalPairIsValid =
        record.terminalRevisionId == null &&
            record.terminalRevisionNumber == null ||
        terminalRevisionId != null &&
            record.terminalRevisionNumber != null &&
            record.terminalRevisionNumber! > 0;
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        effectiveLocalDate == null ||
        record.version != request.expectedVersion + 1 ||
        record.cancelledCount < 1 ||
        record.preservedCompletedCount < 0 ||
        !terminalPairIsValid) {
      return const CancelRepeatingChoreSeriesFromOccurrenceFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return RepeatingChoreSeriesCancelledFromOccurrence(
      RepeatingChoreSeriesFromOccurrenceCancellationSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        effectiveLocalDate: effectiveLocalDate,
        version: record.version,
        cancelledCount: record.cancelledCount,
        preservedCompletedCount: record.preservedCompletedCount,
        terminalRevisionId: terminalRevisionId,
        terminalRevisionNumber: record.terminalRevisionNumber,
        changed: record.changed,
      ),
    );
  }

  ResumeRepeatingChoreSeriesCancellationResult _mapSeriesCancellationResumed(
    RepeatingChoreSeriesCancellationResumeDataRecord record,
    ResumeRepeatingChoreSeriesCancellationRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreLocalDate? effectiveLocalDate = ChoreLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    final ChoreRevisionId? revisionId = ChoreRevisionId.tryParse(
      record.revisionId,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        effectiveLocalDate == null ||
        record.version != request.expectedVersion + 1 ||
        record.restoredCount < 1 ||
        record.preservedCompletedCount < 0 ||
        revisionId == null ||
        record.revisionNumber < 1) {
      return const ResumeRepeatingChoreSeriesCancellationFailed(
        ChoreFailure(ChoreFailureKind.invalidPayload),
      );
    }
    return RepeatingChoreSeriesCancellationResumed(
      RepeatingChoreSeriesCancellationResumeSnapshot(
        householdId: householdId!,
        seriesId: seriesId!,
        effectiveLocalDate: effectiveLocalDate,
        version: record.version,
        restoredCount: record.restoredCount,
        preservedCompletedCount: record.preservedCompletedCount,
        revisionId: revisionId,
        revisionNumber: record.revisionNumber,
        changed: record.changed,
      ),
    );
  }

  ChoreOccurrence? _mapOccurrence(
    ChoreOccurrenceDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final ChoreSeriesId? seriesId = ChoreSeriesId.tryParse(record.seriesId);
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      record.occurrenceId,
    );
    final HouseholdMemberId? assigneeMemberId = HouseholdMemberId.tryParse(
      record.assigneeMemberId,
    );
    final ChoreLocalDate? dueLocalDate = ChoreLocalDate.tryParse(
      record.dueLocalDate,
    );
    final ChoreLocalTime? dueLocalTime = record.dueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(record.dueLocalTime!);
    final DateTime? dueAt = record.dueAt == null
        ? null
        : DateTime.tryParse(record.dueAt!);
    final ChoreOccurrenceStatus? status = switch (record.status) {
      'scheduled' => ChoreOccurrenceStatus.scheduled,
      'completed' => ChoreOccurrenceStatus.completed,
      _ => null,
    };
    final ChoreRecurrenceFrequency? recurrenceFrequency =
        record.recurrenceFrequency == null
        ? null
        : ChoreRecurrenceFrequency.tryParse(record.recurrenceFrequency!);
    final HouseholdMemberId? seriesDefaultAssigneeMemberId =
        record.seriesDefaultAssigneeMemberId == null
        ? null
        : HouseholdMemberId.tryParse(record.seriesDefaultAssigneeMemberId!);
    final ChoreLocalTime? seriesDueLocalTime = record.seriesDueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(record.seriesDueLocalTime!);
    final ChoreRecurrenceRule? recurrenceRule = record.recurrenceRule == null
        ? null
        : ChoreRecurrenceRule.tryParse(record.recurrenceRule!);
    final int seriesVersion = record.seriesVersion ?? 1;
    final bool repeatingContractValid = recurrenceFrequency == null
        ? recurrenceRule == null && !record.canManageSeries
        : recurrenceRule != null &&
              recurrenceRule.frequency == recurrenceFrequency &&
              seriesDefaultAssigneeMemberId != null;
    if (householdId != expectedHouseholdId ||
        seriesId == null ||
        occurrenceId == null ||
        assigneeMemberId == null ||
        dueLocalDate == null ||
        (record.dueLocalTime != null && dueLocalTime == null) ||
        (record.dueAt != null && dueAt == null) ||
        (record.dueAt != null && !dueAt!.isUtc) ||
        (dueLocalTime == null) != (dueAt == null) ||
        (record.recurrenceFrequency != null && recurrenceFrequency == null) ||
        record.seriesVersion != null && seriesVersion < 1 ||
        (record.seriesDefaultAssigneeMemberId != null &&
            seriesDefaultAssigneeMemberId == null) ||
        (record.seriesDueLocalTime != null && seriesDueLocalTime == null) ||
        (record.recurrenceRule != null && recurrenceRule == null) ||
        !repeatingContractValid ||
        status == null ||
        record.title.trim().isEmpty ||
        record.title != record.title.trim() ||
        record.title.length > 160 ||
        record.assigneeDisplayName.trim().isEmpty ||
        record.assigneeDisplayName != record.assigneeDisplayName.trim() ||
        record.version < 1) {
      return null;
    }
    return ChoreOccurrence(
      id: occurrenceId,
      seriesId: seriesId,
      title: record.title,
      description: record.description,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: record.assigneeDisplayName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt?.toUtc(),
      recurrenceFrequency: recurrenceFrequency,
      status: status,
      version: record.version,
      seriesVersion: seriesVersion,
      seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
      seriesDueLocalTime: seriesDueLocalTime,
      recurrenceRule: recurrenceRule,
      canManageSeries: record.canManageSeries,
      canSetCompletion: record.canSetCompletion,
    );
  }

  ChoreFailure _mapFailure(ChoreDataFailureKind kind) {
    return ChoreFailure(switch (kind) {
      ChoreDataFailureKind.unauthenticated => ChoreFailureKind.unauthenticated,
      ChoreDataFailureKind.invalidInput => ChoreFailureKind.invalidInput,
      ChoreDataFailureKind.notFoundOrForbidden =>
        ChoreFailureKind.notFoundOrForbidden,
      ChoreDataFailureKind.idempotencyConflict =>
        ChoreFailureKind.idempotencyConflict,
      ChoreDataFailureKind.invalidRecurrence =>
        ChoreFailureKind.invalidRecurrence,
      ChoreDataFailureKind.staleVersion => ChoreFailureKind.staleVersion,
      ChoreDataFailureKind.invalidTransition =>
        ChoreFailureKind.invalidTransition,
      ChoreDataFailureKind.featurePolicyUnavailable =>
        ChoreFailureKind.featurePolicyUnavailable,
      ChoreDataFailureKind.featureLimitReached =>
        ChoreFailureKind.featureLimitReached,
      ChoreDataFailureKind.temporarilyUnavailable =>
        ChoreFailureKind.temporarilyUnavailable,
      ChoreDataFailureKind.invalidPayload => ChoreFailureKind.invalidPayload,
      ChoreDataFailureKind.unknown => ChoreFailureKind.internal,
    });
  }
}

bool _isPlausibleTimezone(String value) {
  return value == 'UTC' ||
      value.length <= 100 &&
          value.contains('/') &&
          !value.contains(RegExp(r'\s'));
}

bool _occurrenceMatchesQuery(
  ChoreOccurrence occurrence, {
  required ChoreLocalDate localDate,
  required ChoreListView view,
  required HouseholdMemberId? assigneeMemberId,
}) {
  if (assigneeMemberId != null &&
      occurrence.assigneeMemberId != assigneeMemberId) {
    return false;
  }
  final int dateComparison = occurrence.dueLocalDate.value.compareTo(
    localDate.value,
  );
  return switch (view) {
    ChoreListView.today => dateComparison == 0,
    ChoreListView.upcoming =>
      dateComparison > 0 &&
          occurrence.status == ChoreOccurrenceStatus.scheduled,
    ChoreListView.overdue =>
      dateComparison < 0 &&
          occurrence.status == ChoreOccurrenceStatus.scheduled,
    ChoreListView.completed =>
      occurrence.status == ChoreOccurrenceStatus.completed,
  };
}

int _compareChoreListOccurrences(
  ChoreListView view,
  ChoreOccurrence left,
  ChoreOccurrence right,
) {
  final int dateComparison = left.dueLocalDate.value.compareTo(
    right.dueLocalDate.value,
  );
  if (dateComparison != 0) {
    return view == ChoreListView.completed ? -dateComparison : dateComparison;
  }
  final ChoreLocalTime? leftLocalTime = left.dueLocalTime;
  final ChoreLocalTime? rightLocalTime = right.dueLocalTime;
  if (leftLocalTime == null && rightLocalTime != null) {
    return 1;
  }
  if (leftLocalTime != null && rightLocalTime == null) {
    return -1;
  }
  if (leftLocalTime != null && rightLocalTime != null) {
    final int localTimeComparison = leftLocalTime.value.compareTo(
      rightLocalTime.value,
    );
    if (localTimeComparison != 0) {
      return view == ChoreListView.completed
          ? -localTimeComparison
          : localTimeComparison;
    }
  }
  final DateTime? leftDueAt = left.dueAt;
  final DateTime? rightDueAt = right.dueAt;
  if (leftDueAt != null && rightDueAt != null) {
    final int dueAtComparison = leftDueAt.compareTo(rightDueAt);
    if (dueAtComparison != 0) {
      return view == ChoreListView.completed
          ? -dueAtComparison
          : dueAtComparison;
    }
  }
  final int idComparison = left.id.value.compareTo(right.id.value);
  return view == ChoreListView.completed ? -idComparison : idComparison;
}

bool _isBeforeCursor(
  ChoreOccurrenceHistoryEvent event,
  ChoreOccurrenceHistoryCursor cursor,
) {
  final int timeComparison = event.occurredAt.compareTo(cursor.occurredAt);
  return timeComparison < 0 ||
      timeComparison == 0 && event.id.value.compareTo(cursor.entryId.value) < 0;
}
