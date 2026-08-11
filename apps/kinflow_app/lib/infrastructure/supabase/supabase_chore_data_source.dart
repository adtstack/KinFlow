import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _todayKeys = <String>{
  'household_id',
  'household_timezone',
  'household_local_date',
  'occurrence_id',
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'recurrence_frequency',
  'series_version',
  'series_default_assignee_member_id',
  'series_due_local_time',
  'recurrence_rule',
  'can_manage_series',
};

const Set<String> _householdActivationProgressKeys = <String>{
  'household_id',
  'adult_participant_progress',
  'chore_creation_progress',
  'distinct_adult_completer_progress',
  'return_after_first_day_reached',
};

const Set<String> _householdWeeklyReportKeys = <String>{
  'household_id',
  'household_timezone',
  'generated_at',
  'week_offset',
  'week_start',
  'week_end',
  'due_count',
  'completed_count',
  'completed_by_week_end_count',
  'completed_after_week_end_count',
  'open_count',
  'skipped_count',
  'viewer_completed_count',
  'member_breakdown',
  'other_member_completed_count',
  'member_breakdown_truncated',
};

const Set<String> _householdWeeklyReportMemberKeys = <String>{
  'memberId',
  'displayName',
  'completedCount',
  'completedByWeekEndCount',
  'isViewer',
};

const Set<String> _choreListKeys = <String>{
  'household_id',
  'household_timezone',
  'household_local_date',
  'generated_at',
  'list_view',
  'assignee_filter_member_id',
  'page_limit',
  'has_more',
  'page_cursor',
  'occurrence_id',
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'recurrence_frequency',
  'series_version',
  'series_default_assignee_member_id',
  'series_due_local_time',
  'recurrence_rule',
  'can_manage_series',
};

const Set<String> _historyKeys = <String>{
  'household_id',
  'occurrence_id',
  'history_entry_id',
  'event_type',
  'actor_member_id',
  'actor_display_name',
  'acting_member_id',
  'acting_display_name',
  'occurred_at',
  'occurrence_version',
  'previous_due_local_date',
  'previous_due_local_time',
  'new_due_local_date',
  'new_due_local_time',
  'previous_assignee_member_id',
  'previous_assignee_display_name',
  'new_assignee_member_id',
  'new_assignee_display_name',
  'has_more',
};

const Set<String> _deletedOneTimeChoreKeys = <String>{
  'household_id',
  'household_timezone',
  'generated_at',
  'page_limit',
  'has_more',
  'page_cursor',
  'occurrence_id',
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'deleted_at',
  'series_version',
  'occurrence_version',
};

const Set<String> _createdKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'created',
};

const Set<String> _oneTimeUpdateKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'revision_id',
  'revision_number',
  'due_local_date',
  'due_local_time',
  'due_at',
  'assignee_member_id',
  'series_version',
  'occurrence_version',
  'changed',
};

const Set<String> _oneTimeDeletionKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'status',
  'series_version',
  'occurrence_version',
  'changed',
};

const Set<String> _oneTimeRestoreKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'status',
  'series_version',
  'occurrence_version',
  'changed',
};

const Set<String> _completionKeys = <String>{
  'household_id',
  'occurrence_id',
  'status',
  'version',
  'completed_by_member_id',
  'completed_at',
  'changed',
};

const Set<String> _skipKeys = <String>{
  'household_id',
  'occurrence_id',
  'status',
  'version',
  'changed',
};

const Set<String> _restoreKeys = <String>{
  'household_id',
  'occurrence_id',
  'status',
  'version',
  'changed',
};

const Set<String> _rescheduleKeys = <String>{
  'household_id',
  'occurrence_id',
  'due_local_date',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'changed',
};

const Set<String> _reassignmentKeys = <String>{
  'household_id',
  'occurrence_id',
  'assignee_member_id',
  'assignee_display_name',
  'status',
  'version',
  'changed',
};

const Set<String> _recurringCreatedKeys = <String>{
  'household_id',
  'series_id',
  'first_occurrence_id',
  'recurrence_rule',
  'materialized_through',
  'materialized_count',
  'created',
};

const Set<String> _seriesUpdateKeys = <String>{
  'household_id',
  'series_id',
  'revision_id',
  'revision_number',
  'effective_local_date',
  'version',
  'rebuilt_count',
  'cancelled_count',
  'preserved_completed_count',
  'changed',
};

const Set<String> _seriesCancellationKeys = <String>{
  'household_id',
  'series_id',
  'effective_local_date',
  'version',
  'cancelled_count',
  'preserved_completed_count',
  'changed',
};

const Set<String> _seriesFromOccurrenceCancellationKeys = <String>{
  'household_id',
  'series_id',
  'effective_local_date',
  'version',
  'cancelled_count',
  'preserved_completed_count',
  'terminal_revision_id',
  'terminal_revision_number',
  'changed',
};

const Set<String> _seriesCancellationResumeKeys = <String>{
  'household_id',
  'series_id',
  'effective_local_date',
  'version',
  'restored_count',
  'preserved_completed_count',
  'revision_id',
  'revision_number',
  'changed',
};

final class SupabaseChoreDataSource implements ChoreDataSource {
  const SupabaseChoreDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<ChoreDataResult<TodayChoresDataRecord>> loadToday({
    required String householdId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_today_chores_v2',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final TodayChoresDataRecord? record = todayChoresRecordFromPayload(
        response,
      );
      return record == null
          ? const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<TodayChoresDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<TodayChoresDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<TodayChoresDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<TodayChoresDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<HouseholdActivationProgressDataRecord>>
  loadHouseholdActivationProgress({required String householdId}) async {
    try {
      final Object? response = await _client.rpc(
        'get_household_activation_progress',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final HouseholdActivationProgressDataRecord? record =
          householdActivationProgressRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
          );
      return record == null
          ? const ChoreDataFailed<HouseholdActivationProgressDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<HouseholdActivationProgressDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<HouseholdActivationProgressDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<HouseholdActivationProgressDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<HouseholdActivationProgressDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<HouseholdWeeklyReportDataRecord>>
  loadHouseholdWeeklyReport({
    required String householdId,
    required int weekOffset,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_household_weekly_report',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_week_offset': weekOffset,
        },
      );
      final HouseholdWeeklyReportDataRecord? record =
          householdWeeklyReportRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedWeekOffset: weekOffset,
          );
      return record == null
          ? const ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreListPageDataRecord>> loadChoreList({
    required String householdId,
    required String view,
    required String? assigneeMemberId,
    required int limit,
    required String? afterCursor,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_chore_list',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_view': view,
          'p_assignee_member_id': assigneeMemberId,
          'p_limit': limit,
          'p_after_cursor': afterCursor,
        },
      );
      final ChoreListPageDataRecord? record = choreListPageFromPayload(
        response,
        expectedHouseholdId: householdId,
        expectedView: view,
        expectedAssigneeMemberId: assigneeMemberId,
        expectedLimit: limit,
      );
      return record == null
          ? const ChoreDataFailed<ChoreListPageDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreListPageDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreListPageDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreListPageDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreListPageDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> loadOccurrenceTarget({
    required String householdId,
    required String occurrenceId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_chore_occurrence_action_target',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceDataRecord? record =
          choreOccurrenceTargetRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord>>
  loadOccurrenceHistory({
    required String householdId,
    required String occurrenceId,
    required int limit,
    required String? beforeOccurredAt,
    required String? beforeEntryId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_chore_occurrence_history',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_limit': limit,
          'p_before_occurred_at': beforeOccurredAt,
          'p_before_entry_id': beforeEntryId,
        },
      );
      final ChoreOccurrenceHistoryPageDataRecord? record =
          choreOccurrenceHistoryPageFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedOccurrenceId: occurrenceId,
          );
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceHistoryPageDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<DeletedOneTimeChorePageDataRecord>>
  loadDeletedOneTimeChores({
    required String householdId,
    required int limit,
    required String? beforeCursor,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_deleted_one_time_chores',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_limit': limit,
          'p_before_cursor': beforeCursor,
        },
      );
      final DeletedOneTimeChorePageDataRecord? record =
          deletedOneTimeChorePageFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedLimit: limit,
          );
      return record == null
          ? const ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<RecurringChoreDataRecord>> createRepeatingChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'create_repeating_chore',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_title': title,
          'p_description': description,
          'p_assignee_member_id': assigneeMemberId,
          'p_start_local_date': startLocalDate,
          'p_due_local_time': dueLocalTime,
          'p_recurrence_rule': recurrenceRule,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<RecurringChoreDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final RecurringChoreDataRecord? record = recurringChoreRecordFromPayload(
        response.single,
      );
      return record == null
          ? const ChoreDataFailed<RecurringChoreDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<RecurringChoreDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<RecurringChoreDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<RecurringChoreDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<RecurringChoreDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> createOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'create_one_time_chore',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_title': title,
          'p_description': description,
          'p_assignee_member_id': assigneeMemberId,
          'p_due_local_date': dueLocalDate,
          'p_due_local_time': dueLocalTime,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceDataRecord? record =
          choreOccurrenceRecordFromPayload(
            response.single,
            expectedKeys: _createdKeys,
          );
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
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
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_one_time_chore',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_occurrence_id': occurrenceId,
          'p_expected_series_version': expectedSeriesVersion,
          'p_expected_occurrence_version': expectedOccurrenceVersion,
          'p_title': title,
          'p_description': description,
          'p_assignee_member_id': assigneeMemberId,
          'p_due_local_date': dueLocalDate,
          'p_due_local_time': dueLocalTime,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final OneTimeChoreUpdateDataRecord? record =
          oneTimeChoreUpdateRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<OneTimeChoreUpdateDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<OneTimeChoreDeletionDataRecord>> deleteOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'delete_one_time_chore',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_occurrence_id': occurrenceId,
          'p_expected_series_version': expectedSeriesVersion,
          'p_expected_occurrence_version': expectedOccurrenceVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final OneTimeChoreDeletionDataRecord? record =
          oneTimeChoreDeletionRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<OneTimeChoreDeletionDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<OneTimeChoreRestoreDataRecord>> restoreOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'restore_one_time_chore',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_occurrence_id': occurrenceId,
          'p_expected_series_version': expectedSeriesVersion,
          'p_expected_occurrence_version': expectedOccurrenceVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final OneTimeChoreRestoreDataRecord? record =
          oneTimeChoreRestoreRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<OneTimeChoreRestoreDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreCompletionDataRecord>> setCompletion({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required bool completed,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'set_chore_occurrence_completion',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_expected_version': expectedVersion,
          'p_completed': completed,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreCompletionDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreCompletionDataRecord? record =
          choreCompletionRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreCompletionDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreCompletionDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreCompletionDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreCompletionDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreCompletionDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceSkipDataRecord>> skipOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'skip_chore_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceSkipDataRecord? record =
          choreOccurrenceSkipRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceSkipDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceRestoreDataRecord>>
  restoreSkippedOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'restore_skipped_chore_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceRestoreDataRecord? record =
          choreOccurrenceRestoreRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceRestoreDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceRescheduleDataRecord>>
  rescheduleOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'reschedule_chore_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_expected_version': expectedVersion,
          'p_due_local_date': dueLocalDate,
          'p_due_local_time': dueLocalTime,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceRescheduleDataRecord? record =
          choreOccurrenceRescheduleRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceRescheduleDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceReassignmentDataRecord>>
  reassignOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String assigneeMemberId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'reassign_chore_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
          'p_expected_version': expectedVersion,
          'p_assignee_member_id': assigneeMemberId,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final ChoreOccurrenceReassignmentDataRecord? record =
          choreOccurrenceReassignmentRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<ChoreOccurrenceReassignmentDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
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
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_repeating_chore_series',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
          'p_title': title,
          'p_description': description,
          'p_assignee_member_id': assigneeMemberId,
          'p_due_local_time': dueLocalTime,
          'p_recurrence_rule': recurrenceRule,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final RepeatingChoreSeriesUpdateDataRecord? record =
          repeatingChoreSeriesUpdateRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
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
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_repeating_chore_series_from_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_effective_occurrence_id': effectiveOccurrenceId,
          'p_expected_version': expectedVersion,
          'p_title': title,
          'p_description': description,
          'p_assignee_member_id': assigneeMemberId,
          'p_due_local_time': dueLocalTime,
          'p_recurrence_rule': recurrenceRule,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
          ChoreDataFailureKind.invalidPayload,
        );
      }
      final RepeatingChoreSeriesUpdateDataRecord? record =
          repeatingChoreSeriesUpdateRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord>>
  cancelRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'cancel_repeating_chore_series',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<
          RepeatingChoreSeriesCancellationDataRecord
        >(ChoreDataFailureKind.invalidPayload);
      }
      final RepeatingChoreSeriesCancellationDataRecord? record =
          repeatingChoreSeriesCancellationRecordFromPayload(response.single);
      return record == null
          ? const ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
              ChoreDataFailureKind.invalidPayload,
            )
          : ChoreDataSucceeded<RepeatingChoreSeriesCancellationDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
        ChoreDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<
    ChoreDataResult<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>
  >
  cancelRepeatingSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'cancel_repeating_chore_series_from_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_effective_occurrence_id': effectiveOccurrenceId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<
          RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
        >(ChoreDataFailureKind.invalidPayload);
      }
      final RepeatingChoreSeriesFromOccurrenceCancellationDataRecord? record =
          repeatingChoreSeriesFromOccurrenceCancellationRecordFromPayload(
            response.single,
          );
      return record == null
          ? const ChoreDataFailed<
              RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
            >(ChoreDataFailureKind.invalidPayload)
          : ChoreDataSucceeded<
              RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<
        RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
      >(choreDataFailureFromProviderCode(error.code));
    } on AuthException {
      return const ChoreDataFailed<
        RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
      >(ChoreDataFailureKind.unauthenticated);
    } on Object {
      return const ChoreDataFailed<
        RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
      >(ChoreDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>>
  resumeRepeatingSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'resume_repeating_chore_series_cancellation',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_cancellation_idempotency_key': cancellationIdempotencyKey,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const ChoreDataFailed<
          RepeatingChoreSeriesCancellationResumeDataRecord
        >(ChoreDataFailureKind.invalidPayload);
      }
      final RepeatingChoreSeriesCancellationResumeDataRecord? record =
          repeatingChoreSeriesCancellationResumeRecordFromPayload(
            response.single,
          );
      return record == null
          ? const ChoreDataFailed<
              RepeatingChoreSeriesCancellationResumeDataRecord
            >(ChoreDataFailureKind.invalidPayload)
          : ChoreDataSucceeded<
              RepeatingChoreSeriesCancellationResumeDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return ChoreDataFailed<RepeatingChoreSeriesCancellationResumeDataRecord>(
        choreDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ChoreDataFailed<
        RepeatingChoreSeriesCancellationResumeDataRecord
      >(ChoreDataFailureKind.unauthenticated);
    } on Object {
      return const ChoreDataFailed<
        RepeatingChoreSeriesCancellationResumeDataRecord
      >(ChoreDataFailureKind.temporarilyUnavailable);
    }
  }
}

ChoreOccurrenceHistoryPageDataRecord? choreOccurrenceHistoryPageFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedOccurrenceId,
}) {
  if (payload is! List<dynamic>) {
    return null;
  }
  if (payload.isEmpty) {
    return ChoreOccurrenceHistoryPageDataRecord(
      events: const <ChoreOccurrenceHistoryDataRecord>[],
      hasMore: false,
    );
  }
  bool? hasMore;
  final List<ChoreOccurrenceHistoryDataRecord> events =
      <ChoreOccurrenceHistoryDataRecord>[];
  for (final Object? rawRow in payload) {
    final Map<String, Object?>? row = _strictMap(rawRow, _historyKeys);
    if (row == null) {
      return null;
    }
    final String? householdId = _requiredString(row['household_id']);
    final String? occurrenceId = _requiredString(row['occurrence_id']);
    final String? historyEntryId = _requiredString(row['history_entry_id']);
    final String? eventType = _requiredString(row['event_type']);
    final String? actorMemberId = _requiredString(row['actor_member_id']);
    final String? actorDisplayName = _requiredString(row['actor_display_name']);
    final String? actingMemberId = _nullableString(row['acting_member_id']);
    final String? actingDisplayName = _nullableString(
      row['acting_display_name'],
    );
    final String? occurredAt = _requiredString(row['occurred_at']);
    final Object? occurrenceVersion = row['occurrence_version'];
    final String? previousDueLocalDate = _nullableString(
      row['previous_due_local_date'],
    );
    final String? previousDueLocalTime = _nullableString(
      row['previous_due_local_time'],
    );
    final String? newDueLocalDate = _nullableString(row['new_due_local_date']);
    final String? newDueLocalTime = _nullableString(row['new_due_local_time']);
    final String? previousAssigneeMemberId = _nullableString(
      row['previous_assignee_member_id'],
    );
    final String? previousAssigneeDisplayName = _nullableString(
      row['previous_assignee_display_name'],
    );
    final String? newAssigneeMemberId = _nullableString(
      row['new_assignee_member_id'],
    );
    final String? newAssigneeDisplayName = _nullableString(
      row['new_assignee_display_name'],
    );
    final Object? rowHasMore = row['has_more'];
    final String? expectedSource = switch (eventType) {
      'completed' || 'reopened' || 'skipped' || 'restored' => 'completion',
      'rescheduled' => 'reschedule',
      'reassigned' => 'assignment',
      _ => null,
    };
    final bool actingShapeValid =
        (actingMemberId == null) == (actingDisplayName == null);
    final bool scheduleShapeValid = eventType == 'rescheduled'
        ? previousDueLocalDate != null &&
              newDueLocalDate != null &&
              previousAssigneeMemberId == null &&
              previousAssigneeDisplayName == null &&
              newAssigneeMemberId == null &&
              newAssigneeDisplayName == null
        : previousDueLocalDate == null &&
              previousDueLocalTime == null &&
              newDueLocalDate == null &&
              newDueLocalTime == null;
    final bool assignmentShapeValid = eventType == 'reassigned'
        ? previousAssigneeMemberId != null &&
              previousAssigneeDisplayName != null &&
              newAssigneeMemberId != null &&
              newAssigneeDisplayName != null &&
              previousDueLocalDate == null &&
              previousDueLocalTime == null &&
              newDueLocalDate == null &&
              newDueLocalTime == null
        : previousAssigneeMemberId == null &&
              previousAssigneeDisplayName == null &&
              newAssigneeMemberId == null &&
              newAssigneeDisplayName == null;
    if (householdId != expectedHouseholdId ||
        occurrenceId != expectedOccurrenceId ||
        historyEntryId == null ||
        expectedSource == null ||
        !historyEntryId.startsWith('$expectedSource:') ||
        actorMemberId == null ||
        actorDisplayName == null ||
        !actingShapeValid ||
        occurredAt == null ||
        occurrenceVersion is! int ||
        occurrenceVersion < 1 ||
        !scheduleShapeValid ||
        !assignmentShapeValid ||
        rowHasMore is! bool ||
        hasMore != null && hasMore != rowHasMore) {
      return null;
    }
    hasMore ??= rowHasMore;
    events.add(
      ChoreOccurrenceHistoryDataRecord(
        householdId: householdId!,
        occurrenceId: occurrenceId!,
        historyEntryId: historyEntryId,
        eventType: eventType!,
        actorMemberId: actorMemberId,
        actorDisplayName: actorDisplayName,
        actingMemberId: actingMemberId,
        actingDisplayName: actingDisplayName,
        occurredAt: occurredAt,
        occurrenceVersion: occurrenceVersion,
        previousDueLocalDate: previousDueLocalDate,
        previousDueLocalTime: previousDueLocalTime,
        newDueLocalDate: newDueLocalDate,
        newDueLocalTime: newDueLocalTime,
        previousAssigneeMemberId: previousAssigneeMemberId,
        previousAssigneeDisplayName: previousAssigneeDisplayName,
        newAssigneeMemberId: newAssigneeMemberId,
        newAssigneeDisplayName: newAssigneeDisplayName,
      ),
    );
  }
  return ChoreOccurrenceHistoryPageDataRecord(
    events: events,
    hasMore: hasMore!,
  );
}

TodayChoresDataRecord? todayChoresRecordFromPayload(Object? payload) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return null;
  }
  String? householdId;
  String? householdTimezone;
  String? householdLocalDate;
  var metadataOnlyRows = 0;
  final List<ChoreOccurrenceDataRecord> occurrences =
      <ChoreOccurrenceDataRecord>[];
  for (final Object? rawRow in payload) {
    final Map<String, Object?>? row = _strictMap(rawRow, _todayKeys);
    if (row == null) {
      return null;
    }
    final String? rowHouseholdId = _requiredString(row['household_id']);
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowLocalDate = _requiredString(row['household_local_date']);
    if (rowHouseholdId == null || rowTimezone == null || rowLocalDate == null) {
      return null;
    }
    householdId ??= rowHouseholdId;
    householdTimezone ??= rowTimezone;
    householdLocalDate ??= rowLocalDate;
    if (householdId != rowHouseholdId ||
        householdTimezone != rowTimezone ||
        householdLocalDate != rowLocalDate) {
      return null;
    }
    if (row['occurrence_id'] == null) {
      if (_todayItemKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final ChoreOccurrenceDataRecord? occurrence =
        choreOccurrenceRecordFromPayload(<String, Object?>{
          'household_id': rowHouseholdId,
          'series_id': row['series_id'],
          'occurrence_id': row['occurrence_id'],
          'title': row['title'],
          'description': row['description'],
          'assignee_member_id': row['assignee_member_id'],
          'assignee_display_name': row['assignee_display_name'],
          'due_local_date': rowLocalDate,
          'due_local_time': row['due_local_time'],
          'due_at': row['due_at'],
          'status': row['status'],
          'version': row['version'],
          'recurrence_frequency': row['recurrence_frequency'],
          'series_version': row['series_version'],
          'series_default_assignee_member_id':
              row['series_default_assignee_member_id'],
          'series_due_local_time': row['series_due_local_time'],
          'recurrence_rule': row['recurrence_rule'],
          'can_manage_series': row['can_manage_series'],
        }, expectedKeys: _todayOccurrenceKeys);
    if (occurrence == null) {
      return null;
    }
    occurrences.add(occurrence);
  }
  if (householdId == null ||
      householdTimezone == null ||
      householdLocalDate == null ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && occurrences.isNotEmpty) {
    return null;
  }
  return TodayChoresDataRecord(
    householdId: householdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    occurrences: occurrences,
  );
}

HouseholdActivationProgressDataRecord?
householdActivationProgressRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _strictMap(
    payload.single,
    _householdActivationProgressKeys,
  );
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final Object? adultParticipantProgress = row['adult_participant_progress'];
  final Object? choreCreationProgress = row['chore_creation_progress'];
  final Object? distinctAdultCompleterProgress =
      row['distinct_adult_completer_progress'];
  final Object? returnAfterFirstDayReached =
      row['return_after_first_day_reached'];
  if (householdId != expectedHouseholdId ||
      adultParticipantProgress is! int ||
      adultParticipantProgress < 0 ||
      adultParticipantProgress > 2 ||
      choreCreationProgress is! int ||
      choreCreationProgress < 0 ||
      choreCreationProgress > 3 ||
      distinctAdultCompleterProgress is! int ||
      distinctAdultCompleterProgress < 0 ||
      distinctAdultCompleterProgress > 2 ||
      returnAfterFirstDayReached is! bool) {
    return null;
  }
  return HouseholdActivationProgressDataRecord(
    householdId: householdId!,
    adultParticipantProgress: adultParticipantProgress,
    choreCreationProgress: choreCreationProgress,
    distinctAdultCompleterProgress: distinctAdultCompleterProgress,
    returnAfterFirstDayReached: returnAfterFirstDayReached,
  );
}

HouseholdWeeklyReportDataRecord? householdWeeklyReportRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required int expectedWeekOffset,
}) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _strictMap(
    payload.single,
    _householdWeeklyReportKeys,
  );
  if (row == null) {
    return null;
  }

  final String? householdId = _requiredString(row['household_id']);
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? generatedAt = _requiredString(row['generated_at']);
  final String? weekStart = _requiredString(row['week_start']);
  final String? weekEnd = _requiredString(row['week_end']);
  final Object? weekOffset = row['week_offset'];
  final Object? dueCount = row['due_count'];
  final Object? completedCount = row['completed_count'];
  final Object? completedByWeekEndCount = row['completed_by_week_end_count'];
  final Object? completedAfterWeekEndCount =
      row['completed_after_week_end_count'];
  final Object? openCount = row['open_count'];
  final Object? skippedCount = row['skipped_count'];
  final Object? viewerCompletedCount = row['viewer_completed_count'];
  final Object? otherMemberCompletedCount = row['other_member_completed_count'];
  final Object? memberBreakdownTruncated = row['member_breakdown_truncated'];
  final Object? memberBreakdown = row['member_breakdown'];
  if (householdId != expectedHouseholdId ||
      householdTimezone == null ||
      generatedAt == null ||
      weekStart == null ||
      weekEnd == null ||
      weekOffset is! int ||
      weekOffset != expectedWeekOffset ||
      dueCount is! int ||
      completedCount is! int ||
      completedByWeekEndCount is! int ||
      completedAfterWeekEndCount is! int ||
      openCount is! int ||
      skippedCount is! int ||
      viewerCompletedCount is! int ||
      otherMemberCompletedCount is! int ||
      memberBreakdownTruncated is! bool ||
      memberBreakdown is! List<dynamic> ||
      memberBreakdown.length > 20 ||
      <int>[
        dueCount,
        completedCount,
        completedByWeekEndCount,
        completedAfterWeekEndCount,
        openCount,
        skippedCount,
        viewerCompletedCount,
        otherMemberCompletedCount,
      ].any((int count) => count < 0)) {
    return null;
  }

  final List<HouseholdWeeklyReportMemberDataRecord> members =
      <HouseholdWeeklyReportMemberDataRecord>[];
  for (final Object? value in memberBreakdown) {
    final Map<String, Object?>? item = _strictMap(
      value,
      _householdWeeklyReportMemberKeys,
    );
    if (item == null) {
      return null;
    }
    final String? memberId = _requiredString(item['memberId']);
    final String? displayName = _requiredString(item['displayName']);
    final Object? itemCompletedCount = item['completedCount'];
    final Object? itemCompletedByWeekEndCount = item['completedByWeekEndCount'];
    final Object? isViewer = item['isViewer'];
    if (memberId == null ||
        displayName == null ||
        itemCompletedCount is! int ||
        itemCompletedCount < 0 ||
        itemCompletedByWeekEndCount is! int ||
        itemCompletedByWeekEndCount < 0 ||
        isViewer is! bool) {
      return null;
    }
    members.add(
      HouseholdWeeklyReportMemberDataRecord(
        memberId: memberId,
        displayName: displayName,
        completedCount: itemCompletedCount,
        completedByWeekEndCount: itemCompletedByWeekEndCount,
        isViewer: isViewer,
      ),
    );
  }

  return HouseholdWeeklyReportDataRecord(
    householdId: householdId!,
    householdTimezone: householdTimezone,
    generatedAt: generatedAt,
    weekOffset: weekOffset,
    weekStart: weekStart,
    weekEnd: weekEnd,
    dueCount: dueCount,
    completedCount: completedCount,
    completedByWeekEndCount: completedByWeekEndCount,
    completedAfterWeekEndCount: completedAfterWeekEndCount,
    openCount: openCount,
    skippedCount: skippedCount,
    viewerCompletedCount: viewerCompletedCount,
    members: members,
    otherMemberCompletedCount: otherMemberCompletedCount,
    memberBreakdownTruncated: memberBreakdownTruncated,
  );
}

ChoreListPageDataRecord? choreListPageFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedView,
  required String? expectedAssigneeMemberId,
  required int expectedLimit,
}) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return null;
  }
  String? householdId;
  String? householdTimezone;
  String? householdLocalDate;
  String? generatedAt;
  String? listView;
  String? assigneeFilterMemberId;
  int? pageLimit;
  bool? hasMore;
  String? pageCursor;
  var metadataInitialized = false;
  var metadataOnlyRows = 0;
  final List<ChoreOccurrenceDataRecord> occurrences =
      <ChoreOccurrenceDataRecord>[];
  for (final Object? rawRow in payload) {
    final Map<String, Object?>? row = _strictMap(rawRow, _choreListKeys);
    if (row == null) {
      return null;
    }
    final String? rowHouseholdId = _requiredString(row['household_id']);
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowLocalDate = _requiredString(row['household_local_date']);
    final String? rowGeneratedAt = _requiredString(row['generated_at']);
    final String? rowView = _requiredString(row['list_view']);
    final String? rowAssigneeFilter = _nullableString(
      row['assignee_filter_member_id'],
    );
    final Object? rowLimit = row['page_limit'];
    final Object? rowHasMore = row['has_more'];
    final String? rowCursor = _nullableString(row['page_cursor']);
    if (rowHouseholdId == null ||
        rowTimezone == null ||
        rowLocalDate == null ||
        rowGeneratedAt == null ||
        rowView == null ||
        (row['assignee_filter_member_id'] != null &&
            rowAssigneeFilter == null) ||
        rowLimit is! int ||
        rowHasMore is! bool ||
        (row['page_cursor'] != null && rowCursor == null)) {
      return null;
    }
    if (!metadataInitialized) {
      householdId = rowHouseholdId;
      householdTimezone = rowTimezone;
      householdLocalDate = rowLocalDate;
      generatedAt = rowGeneratedAt;
      listView = rowView;
      assigneeFilterMemberId = rowAssigneeFilter;
      pageLimit = rowLimit;
      hasMore = rowHasMore;
      pageCursor = rowCursor;
      metadataInitialized = true;
    } else {
      if (householdId != rowHouseholdId ||
          householdTimezone != rowTimezone ||
          householdLocalDate != rowLocalDate ||
          generatedAt != rowGeneratedAt ||
          listView != rowView ||
          assigneeFilterMemberId != rowAssigneeFilter ||
          pageLimit != rowLimit ||
          hasMore != rowHasMore ||
          pageCursor != rowCursor) {
        return null;
      }
    }
    if (row['occurrence_id'] == null) {
      if (_choreListItemKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final ChoreOccurrenceDataRecord? occurrence =
        choreOccurrenceRecordFromPayload(<String, Object?>{
          'household_id': rowHouseholdId,
          'series_id': row['series_id'],
          'occurrence_id': row['occurrence_id'],
          'title': row['title'],
          'description': row['description'],
          'assignee_member_id': row['assignee_member_id'],
          'assignee_display_name': row['assignee_display_name'],
          'due_local_date': row['due_local_date'],
          'due_local_time': row['due_local_time'],
          'due_at': row['due_at'],
          'status': row['status'],
          'version': row['version'],
          'recurrence_frequency': row['recurrence_frequency'],
          'series_version': row['series_version'],
          'series_default_assignee_member_id':
              row['series_default_assignee_member_id'],
          'series_due_local_time': row['series_due_local_time'],
          'recurrence_rule': row['recurrence_rule'],
          'can_manage_series': row['can_manage_series'],
        }, expectedKeys: _todayOccurrenceKeys);
    if (occurrence == null) {
      return null;
    }
    occurrences.add(occurrence);
  }
  if (householdId != expectedHouseholdId ||
      householdTimezone == null ||
      householdLocalDate == null ||
      generatedAt == null ||
      listView != expectedView ||
      assigneeFilterMemberId != expectedAssigneeMemberId ||
      pageLimit != expectedLimit ||
      hasMore == null ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && occurrences.isNotEmpty ||
      occurrences.length > expectedLimit ||
      hasMore && (pageCursor == null || occurrences.length != expectedLimit) ||
      !hasMore && pageCursor != null ||
      hasMore && occurrences.isEmpty) {
    return null;
  }
  return ChoreListPageDataRecord(
    householdId: householdId!,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    generatedAt: generatedAt,
    listView: listView!,
    assigneeFilterMemberId: assigneeFilterMemberId,
    pageLimit: pageLimit!,
    hasMore: hasMore,
    pageCursor: pageCursor,
    occurrences: occurrences,
  );
}

const Set<String> _deletedOneTimeChoreItemKeys = <String>{
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'deleted_at',
  'series_version',
  'occurrence_version',
};

DeletedOneTimeChorePageDataRecord? deletedOneTimeChorePageFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required int expectedLimit,
}) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return null;
  }
  String? householdId;
  String? householdTimezone;
  String? generatedAt;
  int? pageLimit;
  bool? hasMore;
  String? pageCursor;
  var metadataInitialized = false;
  var metadataOnlyRows = 0;
  final List<DeletedOneTimeChoreDataRecord> items =
      <DeletedOneTimeChoreDataRecord>[];
  for (final Object? rawRow in payload) {
    final Map<String, Object?>? row = _strictMap(
      rawRow,
      _deletedOneTimeChoreKeys,
    );
    if (row == null) {
      return null;
    }
    final String? rowHouseholdId = _requiredString(row['household_id']);
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowGeneratedAt = _requiredString(row['generated_at']);
    final Object? rowLimit = row['page_limit'];
    final Object? rowHasMore = row['has_more'];
    final String? rowCursor = _nullableString(row['page_cursor']);
    if (rowHouseholdId == null ||
        rowTimezone == null ||
        rowGeneratedAt == null ||
        rowLimit is! int ||
        rowHasMore is! bool ||
        (row['page_cursor'] != null && rowCursor == null)) {
      return null;
    }
    if (!metadataInitialized) {
      householdId = rowHouseholdId;
      householdTimezone = rowTimezone;
      generatedAt = rowGeneratedAt;
      pageLimit = rowLimit;
      hasMore = rowHasMore;
      pageCursor = rowCursor;
      metadataInitialized = true;
    } else if (householdId != rowHouseholdId ||
        householdTimezone != rowTimezone ||
        generatedAt != rowGeneratedAt ||
        pageLimit != rowLimit ||
        hasMore != rowHasMore ||
        pageCursor != rowCursor) {
      return null;
    }
    if (row['occurrence_id'] == null) {
      if (_deletedOneTimeChoreItemKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final String? occurrenceId = _requiredString(row['occurrence_id']);
    final String? seriesId = _requiredString(row['series_id']);
    final String? title = _requiredString(row['title']);
    final String? description = _nullableString(row['description']);
    final String? assigneeMemberId = _requiredString(row['assignee_member_id']);
    final String? assigneeDisplayName = _requiredString(
      row['assignee_display_name'],
    );
    final String? dueLocalDate = _requiredString(row['due_local_date']);
    final String? dueLocalTime = _nullableString(row['due_local_time']);
    final String? dueAt = _nullableString(row['due_at']);
    final String? deletedAt = _requiredString(row['deleted_at']);
    final Object? seriesVersion = row['series_version'];
    final Object? occurrenceVersion = row['occurrence_version'];
    if (occurrenceId == null ||
        seriesId == null ||
        title == null ||
        (row['description'] != null && description == null) ||
        assigneeMemberId == null ||
        assigneeDisplayName == null ||
        dueLocalDate == null ||
        (row['due_local_time'] != null && dueLocalTime == null) ||
        (row['due_at'] != null && dueAt == null) ||
        deletedAt == null ||
        seriesVersion is! int ||
        occurrenceVersion is! int) {
      return null;
    }
    items.add(
      DeletedOneTimeChoreDataRecord(
        householdId: rowHouseholdId,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        assigneeDisplayName: assigneeDisplayName,
        dueLocalDate: dueLocalDate,
        dueLocalTime: dueLocalTime,
        dueAt: dueAt,
        deletedAt: deletedAt,
        seriesVersion: seriesVersion,
        occurrenceVersion: occurrenceVersion,
      ),
    );
  }
  if (householdId != expectedHouseholdId ||
      householdTimezone == null ||
      generatedAt == null ||
      pageLimit != expectedLimit ||
      hasMore == null ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && items.isNotEmpty ||
      items.length > expectedLimit ||
      hasMore && (pageCursor == null || items.length != expectedLimit) ||
      !hasMore && pageCursor != null ||
      hasMore && items.isEmpty) {
    return null;
  }
  return DeletedOneTimeChorePageDataRecord(
    householdId: householdId!,
    householdTimezone: householdTimezone,
    generatedAt: generatedAt,
    pageLimit: pageLimit!,
    hasMore: hasMore,
    pageCursor: pageCursor,
    items: items,
  );
}

const Set<String> _occurrenceKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'status',
  'version',
};

const Set<String> _todayOccurrenceKeys = <String>{
  ..._occurrenceKeys,
  'recurrence_frequency',
  'series_version',
  'series_default_assignee_member_id',
  'series_due_local_time',
  'recurrence_rule',
  'can_manage_series',
};

const Set<String> _choreOccurrenceActionTargetKeys = <String>{
  ..._todayOccurrenceKeys,
  'can_set_completion',
};

const Set<String> _todayItemKeys = <String>{
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'recurrence_frequency',
  'series_version',
  'series_default_assignee_member_id',
  'series_due_local_time',
  'recurrence_rule',
  'can_manage_series',
};

const Set<String> _choreListItemKeys = <String>{
  'series_id',
  'title',
  'description',
  'assignee_member_id',
  'assignee_display_name',
  'due_local_date',
  'due_local_time',
  'due_at',
  'status',
  'version',
  'recurrence_frequency',
  'series_version',
  'series_default_assignee_member_id',
  'series_due_local_time',
  'recurrence_rule',
  'can_manage_series',
};

ChoreOccurrenceDataRecord? choreOccurrenceRecordFromPayload(
  Object? payload, {
  Set<String> expectedKeys = _occurrenceKeys,
}) {
  final Map<String, Object?>? row = _strictMap(payload, expectedKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? title = _requiredString(row['title']);
  final String? description = _nullableString(row['description']);
  final String? assigneeMemberId = _requiredString(row['assignee_member_id']);
  final String? assigneeDisplayName = _requiredString(
    row['assignee_display_name'],
  );
  final String? dueLocalDate = _requiredString(row['due_local_date']);
  final String? dueLocalTime = _nullableString(row['due_local_time']);
  final String? dueAt = _nullableString(row['due_at']);
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final Object? created = row['created'];
  final String? recurrenceFrequency = _nullableString(
    row['recurrence_frequency'],
  );
  final Object? seriesVersion = row['series_version'];
  final String? seriesDefaultAssigneeMemberId = _nullableString(
    row['series_default_assignee_member_id'],
  );
  final String? seriesDueLocalTime = _nullableString(
    row['series_due_local_time'],
  );
  final Map<String, Object?>? recurrenceRule = row['recurrence_rule'] == null
      ? null
      : _strictStringMap(row['recurrence_rule']);
  final Object? canManageSeries = row['can_manage_series'];
  final Object? canSetCompletion = row['can_set_completion'];
  final bool expectsSeriesContract = expectedKeys.contains('series_version');
  final bool expectsActionTarget = expectedKeys.contains('can_set_completion');
  if (householdId == null ||
      seriesId == null ||
      occurrenceId == null ||
      title == null ||
      (row['description'] != null && description == null) ||
      assigneeMemberId == null ||
      assigneeDisplayName == null ||
      dueLocalDate == null ||
      (row['due_local_time'] != null && dueLocalTime == null) ||
      (row['due_at'] != null && dueAt == null) ||
      status == null ||
      version is! int ||
      (expectedKeys.contains('recurrence_frequency') &&
          row['recurrence_frequency'] != null &&
          recurrenceFrequency == null) ||
      (expectsSeriesContract && seriesVersion is! int) ||
      (expectsSeriesContract && seriesDefaultAssigneeMemberId == null) ||
      (expectsSeriesContract &&
          row['series_due_local_time'] != null &&
          seriesDueLocalTime == null) ||
      (expectsSeriesContract &&
          row['recurrence_rule'] != null &&
          recurrenceRule == null) ||
      (expectsSeriesContract && canManageSeries is! bool) ||
      (expectsSeriesContract &&
          canManageSeries == true &&
          recurrenceRule == null) ||
      (expectsActionTarget && canSetCompletion is! bool) ||
      (expectedKeys.contains('created') && created is! bool)) {
    return null;
  }
  return ChoreOccurrenceDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    title: title,
    description: description,
    assigneeMemberId: assigneeMemberId,
    assigneeDisplayName: assigneeDisplayName,
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    status: status,
    version: version,
    recurrenceFrequency: recurrenceFrequency,
    seriesVersion: seriesVersion as int?,
    seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
    seriesDueLocalTime: seriesDueLocalTime,
    recurrenceRule: recurrenceRule,
    canManageSeries: canManageSeries is bool && canManageSeries,
    canSetCompletion: canSetCompletion is bool && canSetCompletion,
  );
}

ChoreOccurrenceDataRecord? choreOccurrenceTargetRecordFromPayload(
  Object? payload,
) {
  return choreOccurrenceRecordFromPayload(
    payload,
    expectedKeys: _choreOccurrenceActionTargetKeys,
  );
}

OneTimeChoreUpdateDataRecord? oneTimeChoreUpdateRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _oneTimeUpdateKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? revisionId = _requiredString(row['revision_id']);
  final Object? revisionNumber = row['revision_number'];
  final String? dueLocalDate = _requiredString(row['due_local_date']);
  final String? dueLocalTime = _nullableString(row['due_local_time']);
  final String? dueAt = _nullableString(row['due_at']);
  final String? assigneeMemberId = _requiredString(row['assignee_member_id']);
  final Object? seriesVersion = row['series_version'];
  final Object? occurrenceVersion = row['occurrence_version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      occurrenceId == null ||
      revisionId == null ||
      revisionNumber is! int ||
      dueLocalDate == null ||
      (row['due_local_time'] != null && dueLocalTime == null) ||
      (row['due_at'] != null && dueAt == null) ||
      assigneeMemberId == null ||
      seriesVersion is! int ||
      occurrenceVersion is! int ||
      changed is! bool) {
    return null;
  }
  return OneTimeChoreUpdateDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    assigneeMemberId: assigneeMemberId,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
    changed: changed,
  );
}

OneTimeChoreDeletionDataRecord? oneTimeChoreDeletionRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _oneTimeDeletionKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? status = _requiredString(row['status']);
  final Object? seriesVersion = row['series_version'];
  final Object? occurrenceVersion = row['occurrence_version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      occurrenceId == null ||
      status == null ||
      seriesVersion is! int ||
      occurrenceVersion is! int ||
      changed is! bool) {
    return null;
  }
  return OneTimeChoreDeletionDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    status: status,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
    changed: changed,
  );
}

OneTimeChoreRestoreDataRecord? oneTimeChoreRestoreRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _oneTimeRestoreKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? status = _requiredString(row['status']);
  final Object? seriesVersion = row['series_version'];
  final Object? occurrenceVersion = row['occurrence_version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      occurrenceId == null ||
      status == null ||
      seriesVersion is! int ||
      occurrenceVersion is! int ||
      changed is! bool) {
    return null;
  }
  return OneTimeChoreRestoreDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    status: status,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
    changed: changed,
  );
}

RecurringChoreDataRecord? recurringChoreRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(payload, _recurringCreatedKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? firstOccurrenceId = _requiredString(row['first_occurrence_id']);
  final Map<String, Object?>? recurrenceRule = _strictStringMap(
    row['recurrence_rule'],
  );
  final String? materializedThrough = _requiredString(
    row['materialized_through'],
  );
  final Object? materializedCount = row['materialized_count'];
  final Object? created = row['created'];
  if (householdId == null ||
      seriesId == null ||
      firstOccurrenceId == null ||
      recurrenceRule == null ||
      materializedThrough == null ||
      materializedCount is! int ||
      created is! bool) {
    return null;
  }
  return RecurringChoreDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    firstOccurrenceId: firstOccurrenceId,
    recurrenceRule: recurrenceRule,
    materializedThrough: materializedThrough,
    materializedCount: materializedCount,
    created: created,
  );
}

RepeatingChoreSeriesUpdateDataRecord?
repeatingChoreSeriesUpdateRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(payload, _seriesUpdateKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? revisionId = _requiredString(row['revision_id']);
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? revisionNumber = row['revision_number'];
  final Object? version = row['version'];
  final Object? rebuiltCount = row['rebuilt_count'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedCompletedCount = row['preserved_completed_count'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      revisionId == null ||
      effectiveLocalDate == null ||
      revisionNumber is! int ||
      version is! int ||
      rebuiltCount is! int ||
      cancelledCount is! int ||
      preservedCompletedCount is! int ||
      changed is! bool) {
    return null;
  }
  return RepeatingChoreSeriesUpdateDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    rebuiltCount: rebuiltCount,
    cancelledCount: cancelledCount,
    preservedCompletedCount: preservedCompletedCount,
    changed: changed,
  );
}

RepeatingChoreSeriesCancellationDataRecord?
repeatingChoreSeriesCancellationRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _seriesCancellationKeys,
  );
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedCompletedCount = row['preserved_completed_count'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      effectiveLocalDate == null ||
      version is! int ||
      cancelledCount is! int ||
      preservedCompletedCount is! int ||
      changed is! bool) {
    return null;
  }
  return RepeatingChoreSeriesCancellationDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    cancelledCount: cancelledCount,
    preservedCompletedCount: preservedCompletedCount,
    changed: changed,
  );
}

RepeatingChoreSeriesFromOccurrenceCancellationDataRecord?
repeatingChoreSeriesFromOccurrenceCancellationRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _seriesFromOccurrenceCancellationKeys,
  );
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedCompletedCount = row['preserved_completed_count'];
  final Object? terminalRevisionIdValue = row['terminal_revision_id'];
  final String? terminalRevisionId = _nullableString(terminalRevisionIdValue);
  final Object? terminalRevisionNumber = row['terminal_revision_number'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      effectiveLocalDate == null ||
      version is! int ||
      cancelledCount is! int ||
      preservedCompletedCount is! int ||
      terminalRevisionIdValue != null && terminalRevisionId == null ||
      terminalRevisionNumber != null && terminalRevisionNumber is! int ||
      (terminalRevisionId == null) != (terminalRevisionNumber == null) ||
      changed is! bool) {
    return null;
  }
  return RepeatingChoreSeriesFromOccurrenceCancellationDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    cancelledCount: cancelledCount,
    preservedCompletedCount: preservedCompletedCount,
    terminalRevisionId: terminalRevisionId,
    terminalRevisionNumber: terminalRevisionNumber as int?,
    changed: changed,
  );
}

RepeatingChoreSeriesCancellationResumeDataRecord?
repeatingChoreSeriesCancellationResumeRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _seriesCancellationResumeKeys,
  );
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? seriesId = _requiredString(row['series_id']);
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? restoredCount = row['restored_count'];
  final Object? preservedCompletedCount = row['preserved_completed_count'];
  final String? revisionId = _requiredString(row['revision_id']);
  final Object? revisionNumber = row['revision_number'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      seriesId == null ||
      effectiveLocalDate == null ||
      version is! int ||
      restoredCount is! int ||
      preservedCompletedCount is! int ||
      revisionId == null ||
      revisionNumber is! int ||
      changed is! bool) {
    return null;
  }
  return RepeatingChoreSeriesCancellationResumeDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    restoredCount: restoredCount,
    preservedCompletedCount: preservedCompletedCount,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    changed: changed,
  );
}

ChoreCompletionDataRecord? choreCompletionRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(payload, _completionKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final String? completedByMemberId = _nullableString(
    row['completed_by_member_id'],
  );
  final String? completedAt = _nullableString(row['completed_at']);
  final Object? changed = row['changed'];
  if (householdId == null ||
      occurrenceId == null ||
      status == null ||
      version is! int ||
      (row['completed_by_member_id'] != null && completedByMemberId == null) ||
      (row['completed_at'] != null && completedAt == null) ||
      changed is! bool) {
    return null;
  }
  return ChoreCompletionDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    completedByMemberId: completedByMemberId,
    completedAt: completedAt,
    changed: changed,
  );
}

ChoreOccurrenceSkipDataRecord? choreOccurrenceSkipRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _skipKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      occurrenceId == null ||
      status == null ||
      version is! int ||
      changed is! bool) {
    return null;
  }
  return ChoreOccurrenceSkipDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    changed: changed,
  );
}

ChoreOccurrenceRestoreDataRecord? choreOccurrenceRestoreRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _restoreKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      occurrenceId == null ||
      status == null ||
      version is! int ||
      changed is! bool) {
    return null;
  }
  return ChoreOccurrenceRestoreDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    changed: changed,
  );
}

ChoreOccurrenceRescheduleDataRecord? choreOccurrenceRescheduleRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _strictMap(payload, _rescheduleKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? dueLocalDate = _requiredString(row['due_local_date']);
  final String? dueLocalTime = _nullableString(row['due_local_time']);
  final String? dueAt = _nullableString(row['due_at']);
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      occurrenceId == null ||
      dueLocalDate == null ||
      (row['due_local_time'] != null && dueLocalTime == null) ||
      (row['due_at'] != null && dueAt == null) ||
      status == null ||
      version is! int ||
      changed is! bool) {
    return null;
  }
  return ChoreOccurrenceRescheduleDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    status: status,
    version: version,
    changed: changed,
  );
}

ChoreOccurrenceReassignmentDataRecord?
choreOccurrenceReassignmentRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _strictMap(payload, _reassignmentKeys);
  if (row == null) {
    return null;
  }
  final String? householdId = _requiredString(row['household_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? assigneeMemberId = _requiredString(row['assignee_member_id']);
  final String? assigneeDisplayName = _requiredString(
    row['assignee_display_name'],
  );
  final String? status = _requiredString(row['status']);
  final Object? version = row['version'];
  final Object? changed = row['changed'];
  if (householdId == null ||
      occurrenceId == null ||
      assigneeMemberId == null ||
      assigneeDisplayName == null ||
      status == null ||
      version is! int ||
      changed is! bool) {
    return null;
  }
  return ChoreOccurrenceReassignmentDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    assigneeMemberId: assigneeMemberId,
    assigneeDisplayName: assigneeDisplayName,
    status: status,
    version: version,
    changed: changed,
  );
}

Map<String, Object?>? _strictMap(Object? payload, Set<String> expectedKeys) {
  if (payload is! Map || payload.keys.any((Object? key) => key is! String)) {
    return null;
  }
  final Map<String, Object?> row = Map<String, Object?>.from(payload);
  return row.keys.toSet().containsAll(expectedKeys) &&
          expectedKeys.containsAll(row.keys)
      ? row
      : null;
}

Map<String, Object?>? _strictStringMap(Object? payload) {
  if (payload is! Map || payload.keys.any((Object? key) => key is! String)) {
    return null;
  }
  return Map<String, Object?>.from(payload);
}

String? _requiredString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

String? _nullableString(Object? value) {
  return value == null || value is String ? value as String? : null;
}

ChoreDataFailureKind choreDataFailureFromProviderCode(String? code) {
  return switch (code) {
    'KFC01' || 'PGRST301' => ChoreDataFailureKind.unauthenticated,
    'KFC02' => ChoreDataFailureKind.invalidInput,
    'KFC03' => ChoreDataFailureKind.notFoundOrForbidden,
    'KFC04' => ChoreDataFailureKind.idempotencyConflict,
    'KFC07' => ChoreDataFailureKind.invalidRecurrence,
    'KFC05' => ChoreDataFailureKind.staleVersion,
    'KFC06' => ChoreDataFailureKind.invalidTransition,
    'KFB10' || 'KFB11' => ChoreDataFailureKind.featurePolicyUnavailable,
    'KFB12' => ChoreDataFailureKind.featureLimitReached,
    _ when code?.startsWith('PGRST') ?? false =>
      ChoreDataFailureKind.temporarilyUnavailable,
    _ => ChoreDataFailureKind.unknown,
  };
}
