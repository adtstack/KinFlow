import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

enum ChoreDataFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  idempotencyConflict,
  invalidRecurrence,
  staleVersion,
  invalidTransition,
  featurePolicyUnavailable,
  featureLimitReached,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class ChoreOccurrenceDataRecord {
  const ChoreOccurrenceDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.status,
    required this.version,
    this.recurrenceFrequency,
    this.seriesVersion,
    this.seriesDefaultAssigneeMemberId,
    this.seriesDueLocalTime,
    this.recurrenceRule,
    this.canManageSeries = false,
    this.canSetCompletion = false,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String title;
  final String? description;
  final String assigneeMemberId;
  final String assigneeDisplayName;
  final String dueLocalDate;
  final String? dueLocalTime;
  final String? dueAt;
  final String status;
  final int version;
  final String? recurrenceFrequency;
  final int? seriesVersion;
  final String? seriesDefaultAssigneeMemberId;
  final String? seriesDueLocalTime;
  final Map<String, Object?>? recurrenceRule;
  final bool canManageSeries;
  final bool canSetCompletion;
}

final class TodayChoresDataRecord {
  TodayChoresDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required List<ChoreOccurrenceDataRecord> occurrences,
  }) : occurrences = List<ChoreOccurrenceDataRecord>.unmodifiable(occurrences);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final List<ChoreOccurrenceDataRecord> occurrences;
}

final class HouseholdActivationProgressDataRecord {
  const HouseholdActivationProgressDataRecord({
    required this.householdId,
    required this.adultParticipantProgress,
    required this.choreCreationProgress,
    required this.distinctAdultCompleterProgress,
    required this.returnAfterFirstDayReached,
  });

  final String householdId;
  final int adultParticipantProgress;
  final int choreCreationProgress;
  final int distinctAdultCompleterProgress;
  final bool returnAfterFirstDayReached;
}

final class HouseholdWeeklyReportMemberDataRecord {
  const HouseholdWeeklyReportMemberDataRecord({
    required this.memberId,
    required this.displayName,
    required this.completedCount,
    required this.completedByWeekEndCount,
    required this.isViewer,
  });

  final String memberId;
  final String displayName;
  final int completedCount;
  final int completedByWeekEndCount;
  final bool isViewer;
}

final class HouseholdWeeklyReportDataRecord {
  HouseholdWeeklyReportDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.generatedAt,
    required this.weekOffset,
    required this.weekStart,
    required this.weekEnd,
    required this.dueCount,
    required this.completedCount,
    required this.completedByWeekEndCount,
    required this.completedAfterWeekEndCount,
    required this.openCount,
    required this.skippedCount,
    required this.viewerCompletedCount,
    required List<HouseholdWeeklyReportMemberDataRecord> members,
    required this.otherMemberCompletedCount,
    required this.memberBreakdownTruncated,
  }) : members = List<HouseholdWeeklyReportMemberDataRecord>.unmodifiable(
         members,
       );

  final String householdId;
  final String householdTimezone;
  final String generatedAt;
  final int weekOffset;
  final String weekStart;
  final String weekEnd;
  final int dueCount;
  final int completedCount;
  final int completedByWeekEndCount;
  final int completedAfterWeekEndCount;
  final int openCount;
  final int skippedCount;
  final int viewerCompletedCount;
  final List<HouseholdWeeklyReportMemberDataRecord> members;
  final int otherMemberCompletedCount;
  final bool memberBreakdownTruncated;
}

final class ChoreListPageDataRecord {
  ChoreListPageDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.listView,
    required this.assigneeFilterMemberId,
    required this.pageLimit,
    required this.hasMore,
    required this.pageCursor,
    required List<ChoreOccurrenceDataRecord> occurrences,
  }) : occurrences = List<ChoreOccurrenceDataRecord>.unmodifiable(occurrences);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String generatedAt;
  final String listView;
  final String? assigneeFilterMemberId;
  final int pageLimit;
  final bool hasMore;
  final String? pageCursor;
  final List<ChoreOccurrenceDataRecord> occurrences;
}

final class ChoreOccurrenceHistoryDataRecord {
  const ChoreOccurrenceHistoryDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.historyEntryId,
    required this.eventType,
    required this.actorMemberId,
    required this.actorDisplayName,
    required this.actingMemberId,
    required this.actingDisplayName,
    required this.occurredAt,
    required this.occurrenceVersion,
    required this.previousDueLocalDate,
    required this.previousDueLocalTime,
    required this.newDueLocalDate,
    required this.newDueLocalTime,
    required this.previousAssigneeMemberId,
    required this.previousAssigneeDisplayName,
    required this.newAssigneeMemberId,
    required this.newAssigneeDisplayName,
  });

  final String householdId;
  final String occurrenceId;
  final String historyEntryId;
  final String eventType;
  final String actorMemberId;
  final String actorDisplayName;
  final String? actingMemberId;
  final String? actingDisplayName;
  final String occurredAt;
  final int occurrenceVersion;
  final String? previousDueLocalDate;
  final String? previousDueLocalTime;
  final String? newDueLocalDate;
  final String? newDueLocalTime;
  final String? previousAssigneeMemberId;
  final String? previousAssigneeDisplayName;
  final String? newAssigneeMemberId;
  final String? newAssigneeDisplayName;
}

final class ChoreOccurrenceHistoryPageDataRecord {
  ChoreOccurrenceHistoryPageDataRecord({
    required List<ChoreOccurrenceHistoryDataRecord> events,
    required this.hasMore,
  }) : events = List<ChoreOccurrenceHistoryDataRecord>.unmodifiable(events);

  final List<ChoreOccurrenceHistoryDataRecord> events;
  final bool hasMore;
}

final class DeletedOneTimeChoreDataRecord {
  const DeletedOneTimeChoreDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.deletedAt,
    required this.seriesVersion,
    required this.occurrenceVersion,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String title;
  final String? description;
  final String assigneeMemberId;
  final String assigneeDisplayName;
  final String dueLocalDate;
  final String? dueLocalTime;
  final String? dueAt;
  final String deletedAt;
  final int seriesVersion;
  final int occurrenceVersion;
}

final class DeletedOneTimeChorePageDataRecord {
  DeletedOneTimeChorePageDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.generatedAt,
    required this.pageLimit,
    required this.hasMore,
    required this.pageCursor,
    required List<DeletedOneTimeChoreDataRecord> items,
  }) : items = List<DeletedOneTimeChoreDataRecord>.unmodifiable(items);

  final String householdId;
  final String householdTimezone;
  final String generatedAt;
  final int pageLimit;
  final bool hasMore;
  final String? pageCursor;
  final List<DeletedOneTimeChoreDataRecord> items;
}

final class ChoreCompletionDataRecord {
  const ChoreCompletionDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.status,
    required this.version,
    required this.completedByMemberId,
    required this.completedAt,
    required this.changed,
  });

  final String householdId;
  final String occurrenceId;
  final String status;
  final int version;
  final String? completedByMemberId;
  final String? completedAt;
  final bool changed;
}

final class ChoreOccurrenceSkipDataRecord {
  const ChoreOccurrenceSkipDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.status,
    required this.version,
    required this.changed,
  });

  final String householdId;
  final String occurrenceId;
  final String status;
  final int version;
  final bool changed;
}

final class ChoreOccurrenceRestoreDataRecord {
  const ChoreOccurrenceRestoreDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.status,
    required this.version,
    required this.changed,
  });

  final String householdId;
  final String occurrenceId;
  final String status;
  final int version;
  final bool changed;
}

final class ChoreOccurrenceRescheduleDataRecord {
  const ChoreOccurrenceRescheduleDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.status,
    required this.version,
    required this.changed,
  });

  final String householdId;
  final String occurrenceId;
  final String dueLocalDate;
  final String? dueLocalTime;
  final String? dueAt;
  final String status;
  final int version;
  final bool changed;
}

final class ChoreOccurrenceReassignmentDataRecord {
  const ChoreOccurrenceReassignmentDataRecord({
    required this.householdId,
    required this.occurrenceId,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.status,
    required this.version,
    required this.changed,
  });

  final String householdId;
  final String occurrenceId;
  final String assigneeMemberId;
  final String assigneeDisplayName;
  final String status;
  final int version;
  final bool changed;
}

final class OneTimeChoreUpdateDataRecord {
  const OneTimeChoreUpdateDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.revisionId,
    required this.revisionNumber,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.assigneeMemberId,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String revisionId;
  final int revisionNumber;
  final String dueLocalDate;
  final String? dueLocalTime;
  final String? dueAt;
  final String assigneeMemberId;
  final int seriesVersion;
  final int occurrenceVersion;
  final bool changed;
}

final class OneTimeChoreDeletionDataRecord {
  const OneTimeChoreDeletionDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.status,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String status;
  final int seriesVersion;
  final int occurrenceVersion;
  final bool changed;
}

final class OneTimeChoreRestoreDataRecord {
  const OneTimeChoreRestoreDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.status,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String status;
  final int seriesVersion;
  final int occurrenceVersion;
  final bool changed;
}

final class RecurringChoreDataRecord {
  RecurringChoreDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.firstOccurrenceId,
    required Map<String, Object?> recurrenceRule,
    required this.materializedThrough,
    required this.materializedCount,
    required this.created,
  }) : recurrenceRule = Map<String, Object?>.unmodifiable(recurrenceRule);

  final String householdId;
  final String seriesId;
  final String firstOccurrenceId;
  final Map<String, Object?> recurrenceRule;
  final String materializedThrough;
  final int materializedCount;
  final bool created;
}

final class RepeatingChoreSeriesUpdateDataRecord {
  const RepeatingChoreSeriesUpdateDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.effectiveLocalDate,
    required this.version,
    required this.rebuiltCount,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String revisionId;
  final int revisionNumber;
  final String effectiveLocalDate;
  final int version;
  final int rebuiltCount;
  final int cancelledCount;
  final int preservedCompletedCount;
  final bool changed;
}

final class RepeatingChoreSeriesCancellationDataRecord {
  const RepeatingChoreSeriesCancellationDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedCompletedCount;
  final bool changed;
}

final class RepeatingChoreSeriesFromOccurrenceCancellationDataRecord {
  const RepeatingChoreSeriesFromOccurrenceCancellationDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.terminalRevisionId,
    required this.terminalRevisionNumber,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedCompletedCount;
  final String? terminalRevisionId;
  final int? terminalRevisionNumber;
  final bool changed;
}

final class RepeatingChoreSeriesCancellationResumeDataRecord {
  const RepeatingChoreSeriesCancellationResumeDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.restoredCount,
    required this.preservedCompletedCount,
    required this.revisionId,
    required this.revisionNumber,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int restoredCount;
  final int preservedCompletedCount;
  final String revisionId;
  final int revisionNumber;
  final bool changed;
}

abstract interface class ChoreDataSource {
  Future<ChoreDataResult<TodayChoresDataRecord>> loadToday({
    required String householdId,
  });

  Future<ChoreDataResult<HouseholdActivationProgressDataRecord>>
  loadHouseholdActivationProgress({required String householdId});

  Future<ChoreDataResult<HouseholdWeeklyReportDataRecord>>
  loadHouseholdWeeklyReport({
    required String householdId,
    required int weekOffset,
  });

  Future<ChoreDataResult<ChoreListPageDataRecord>> loadChoreList({
    required String householdId,
    required String view,
    required String? assigneeMemberId,
    required int limit,
    required String? afterCursor,
  });

  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> loadOccurrenceTarget({
    required String householdId,
    required String occurrenceId,
  });

  Future<ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord>>
  loadOccurrenceHistory({
    required String householdId,
    required String occurrenceId,
    required int limit,
    required String? beforeOccurredAt,
    required String? beforeEntryId,
  });

  Future<ChoreDataResult<DeletedOneTimeChorePageDataRecord>>
  loadDeletedOneTimeChores({
    required String householdId,
    required int limit,
    required String? beforeCursor,
  });

  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> createOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  });

  Future<ChoreDataResult<OneTimeChoreUpdateDataRecord>> updateOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  });

  Future<ChoreDataResult<OneTimeChoreDeletionDataRecord>> deleteOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  });

  Future<ChoreDataResult<OneTimeChoreRestoreDataRecord>> restoreOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  });

  Future<ChoreDataResult<RecurringChoreDataRecord>> createRepeatingChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  });

  Future<ChoreDataResult<ChoreCompletionDataRecord>> setCompletion({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required bool completed,
  });

  Future<ChoreDataResult<ChoreOccurrenceSkipDataRecord>> skipOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  });

  Future<ChoreDataResult<ChoreOccurrenceRestoreDataRecord>>
  restoreSkippedOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  });

  Future<ChoreDataResult<ChoreOccurrenceRescheduleDataRecord>>
  rescheduleOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String dueLocalDate,
    required String? dueLocalTime,
  });

  Future<ChoreDataResult<ChoreOccurrenceReassignmentDataRecord>>
  reassignOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String assigneeMemberId,
  });

  Future<ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>>
  updateRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  });

  Future<ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>>
  updateRepeatingSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  });

  Future<ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord>>
  cancelRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  });

  Future<
    ChoreDataResult<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>
  >
  cancelRepeatingSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
  });

  Future<ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>>
  resumeRepeatingSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  });
}

sealed class ChoreDataResult<T> {
  const ChoreDataResult();
}

final class ChoreDataSucceeded<T> extends ChoreDataResult<T> {
  const ChoreDataSucceeded(this.value, {this.cacheMetadata});

  final T value;
  final ReadCacheMetadata? cacheMetadata;
}

final class ChoreDataFailed<T> extends ChoreDataResult<T> {
  const ChoreDataFailed(this.kind);

  final ChoreDataFailureKind kind;
}
