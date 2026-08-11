import 'package:kinflow_app/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _calendarEnvelopeKeys = <String>{
  'household_id',
  'household_timezone',
  'household_local_date',
};

const Set<String> _calendarItemKeys = <String>{
  'series_id',
  'occurrence_id',
  'title',
  'description',
  'is_all_day',
  'local_start_date',
  'local_start_time',
  'duration_minutes',
  'all_day_end_date_exclusive',
  'timezone',
  'overlap_policy',
  'starts_at',
  'ends_at',
  'dst_resolution',
  'utc_offset_seconds',
  'participant_member_ids',
  'participant_display_names',
  'version',
  'occurrence_version',
};

const Set<String> _calendarRecurrenceItemKeys = <String>{
  'recurrence_rule',
  'recurrence_local_start_date',
  'revision_number',
  'is_exception',
};

const Set<String> _calendarV2ItemKeys = <String>{
  ..._calendarItemKeys,
  ..._calendarRecurrenceItemKeys,
};

const Set<String> _calendarEventKeys = <String>{
  ..._calendarEnvelopeKeys,
  ..._calendarItemKeys,
};

const Set<String> _calendarCreatedKeys = <String>{
  ..._calendarEventKeys,
  'created',
};

const Set<String> _calendarUpdatedKeys = <String>{
  ..._calendarEventKeys,
  'changed',
};

const Set<String> _calendarDeletedKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'version',
  'occurrence_version',
  'deleted',
  'changed',
};

const Set<String> _calendarPageMetadataKeys = <String>{
  'generated_at',
  'view_mode',
  'range_start_date',
  'range_end_date_exclusive',
  'page_limit',
  'has_more',
  'page_cursor',
};

const Set<String> _calendarProjectionKeys = <String>{
  'view_local_date',
  'view_local_time',
};

const Set<String> _calendarPageKeys = <String>{
  ..._calendarEnvelopeKeys,
  ..._calendarV2ItemKeys,
  ..._calendarPageMetadataKeys,
  ..._calendarProjectionKeys,
};

const Set<String> _calendarRecurringCreatedKeys = <String>{
  ..._calendarEnvelopeKeys,
  'series_id',
  'first_occurrence_id',
  'recurrence_rule',
  'materialized_through',
  'materialized_count',
  'version',
  'created',
};

const Set<String> _calendarRecurringSeriesDetailKeys = <String>{
  ..._calendarEnvelopeKeys,
  'series_id',
  'revision_id',
  'revision_number',
  'title',
  'description',
  'is_all_day',
  'local_start_date',
  'local_start_time',
  'duration_minutes',
  'all_day_end_date_exclusive',
  'timezone',
  'overlap_policy',
  'recurrence_rule',
  'participant_member_ids',
  'participant_display_names',
  'version',
};

const Set<String> _calendarRecurringSeriesUpdateKeys = <String>{
  ..._calendarEnvelopeKeys,
  'series_id',
  'revision_id',
  'revision_number',
  'effective_local_date',
  'materialized_through',
  'version',
  'rebuilt_count',
  'cancelled_count',
  'preserved_exception_count',
  'changed',
};

const Set<String> _calendarRecurringSeriesCancellationKeys = <String>{
  ..._calendarEnvelopeKeys,
  'series_id',
  'effective_local_date',
  'version',
  'cancelled_count',
  'preserved_past_count',
  'changed',
};

const Set<String> _calendarRecurringSeriesFromOccurrenceCancellationKeys =
    <String>{
      ..._calendarRecurringSeriesCancellationKeys,
      'terminal_revision_id',
      'terminal_revision_number',
    };

const Set<String> _calendarRecurringSeriesCancellationResumeKeys = <String>{
  'household_id',
  'series_id',
  'effective_local_date',
  'version',
  'restored_count',
  'preserved_past_count',
  'revision_id',
  'revision_number',
  'changed',
};

const Set<String> _calendarOccurrenceCommandKeys = <String>{
  'household_id',
  'series_id',
  'occurrence_id',
  'revision_id',
  'occurrence_version',
  'exception_version',
  'cancelled',
  'changed',
};

const Set<String> _calendarMonthKeys = <String>{
  ..._calendarEnvelopeKeys,
  'generated_at',
  'month_start_date',
  'month_end_date_exclusive',
  'day_date',
  'event_count',
  'all_day_count',
  'timed_count',
};

const Set<String> _calendarOccurrenceLocatorKeys = <String>{
  ..._calendarEnvelopeKeys,
  'generated_at',
  'series_id',
  'occurrence_id',
  'view_local_date',
  'series_version',
  'occurrence_version',
};

const Set<String> _calendarOverlapPreviewKeys = <String>{
  ..._calendarEnvelopeKeys,
  'generated_at',
  'checked_from_local_date',
  'checked_through_local_date',
  'candidate_occurrence_count',
  'total_conflict_count',
  'truncated',
  'candidate_local_start_date',
  'conflicting_series_id',
  'conflicting_occurrence_id',
  'conflicting_title',
  'conflicting_is_all_day',
  'conflicting_view_local_start_date',
  'conflicting_view_local_start_time',
  'conflicting_duration_minutes',
  'conflicting_all_day_end_date_exclusive',
  'conflicting_participant_member_ids',
  'conflicting_participant_display_names',
};

final class SupabaseCalendarDataSource implements CalendarDataSource {
  const SupabaseCalendarDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<CalendarDataResult<CalendarEventPageDataRecord>> loadEventPage({
    required String householdId,
    required String viewMode,
    required String? rangeStartDate,
    required String? rangeEndDateExclusive,
    required int limit,
    required String? afterCursor,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_calendar_event_page_v2',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_view': viewMode,
          'p_range_start_date': rangeStartDate,
          'p_range_end_date_exclusive': rangeEndDateExclusive,
          'p_limit': limit,
          'p_after_cursor': afterCursor,
        },
      );
      final CalendarEventPageDataRecord? record =
          calendarEventPageRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedViewMode: viewMode,
            expectedRangeStartDate: rangeStartDate,
            expectedRangeEndDateExclusive: rangeEndDateExclusive,
            expectedLimit: limit,
          );
      return record == null
          ? const CalendarDataFailed<CalendarEventPageDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarEventPageDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarEventPageDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarEventPageDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarEventPageDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarMonthSummaryDataRecord>> loadMonthSummary({
    required String householdId,
    required String monthStartDate,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_calendar_month_summary_v2',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_month_start_date': monthStartDate,
        },
      );
      final CalendarMonthSummaryDataRecord? record =
          calendarMonthSummaryRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedMonthStartDate: monthStartDate,
          );
      return record == null
          ? const CalendarDataFailed<CalendarMonthSummaryDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarMonthSummaryDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarMonthSummaryDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarMonthSummaryDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarMonthSummaryDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarOccurrenceLocatorDataRecord>>
  loadOccurrenceLocator({
    required String householdId,
    required String occurrenceId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_calendar_occurrence_locator',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_occurrence_id': occurrenceId,
        },
      );
      final CalendarOccurrenceLocatorDataRecord? record =
          calendarOccurrenceLocatorRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedOccurrenceId: occurrenceId,
          );
      return record == null
          ? const CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarOccurrenceLocatorDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarOverlapPreviewDataRecord>> previewOverlaps({
    required String householdId,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?>? recurrenceRule,
    required String windowStartDate,
    required List<String> participantMemberIds,
    required String? excludedSeriesId,
    required String? excludedOccurrenceId,
    required int limit,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'preview_calendar_event_overlaps',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_recurrence_rule': recurrenceRule,
          'p_window_start_date': windowStartDate,
          'p_participant_member_ids': participantMemberIds,
          'p_excluded_series_id': excludedSeriesId,
          'p_excluded_occurrence_id': excludedOccurrenceId,
          'p_limit': limit,
        },
      );
      final CalendarOverlapPreviewDataRecord? record =
          calendarOverlapPreviewRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedWindowStartDate: windowStartDate,
            expectedLimit: limit,
          );
      return record == null
          ? const CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarOverlapPreviewDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarEventListDataRecord>> loadOneTimeEvents({
    required String householdId,
    required int limit,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'list_one_time_events',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_limit': limit,
        },
      );
      final CalendarEventListDataRecord? record =
          calendarEventListRecordFromPayload(
            response,
            expectedHouseholdId: householdId,
            expectedLimit: limit,
          );
      return record == null
          ? const CalendarDataFailed<CalendarEventListDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarEventListDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarEventListDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarEventListDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarEventListDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarEventDataRecord>> createOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'create_one_time_event',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      return _eventMutationResult(
        response,
        expectedHouseholdId: householdId,
        expectedKeys: _calendarCreatedKeys,
        markerKey: 'created',
      );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarEventDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarEventDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarEventDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<RecurringCalendarEventDataRecord>>
  createRecurringEvent({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'create_recurring_calendar_event',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_recurrence_rule': recurrenceRule,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<RecurringCalendarEventDataRecord>(
          CalendarDataFailureKind.invalidPayload,
        );
      }
      final RecurringCalendarEventDataRecord? record =
          recurringCalendarEventRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
          );
      return record == null
          ? const CalendarDataFailed<RecurringCalendarEventDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<RecurringCalendarEventDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<RecurringCalendarEventDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<RecurringCalendarEventDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<RecurringCalendarEventDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesDetailDataRecord>>
  loadRecurringSeries({
    required String householdId,
    required String seriesId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_recurring_calendar_series',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_series_id': seriesId,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesDetailDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesDetailDataRecord? record =
          calendarRecurringSeriesDetailRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarRecurringSeriesDetailDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>>
  updateRecurringSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_recurring_calendar_series',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_recurrence_rule': recurrenceRule,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesUpdateDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesUpdateDataRecord? record =
          calendarRecurringSeriesUpdateRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarRecurringSeriesUpdateDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>>
  updateRecurringSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_recurring_calendar_series_from_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_effective_occurrence_id': effectiveOccurrenceId,
          'p_expected_version': expectedVersion,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_recurrence_rule': recurrenceRule,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesUpdateDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesUpdateDataRecord? record =
          calendarRecurringSeriesUpdateRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarRecurringSeriesUpdateDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>>
  cancelRecurringSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'cancel_recurring_calendar_series',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesCancellationDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesCancellationDataRecord? record =
          calendarRecurringSeriesCancellationRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<
              CalendarRecurringSeriesCancellationDataRecord
            >(CalendarDataFailureKind.invalidPayload)
          : CalendarDataSucceeded<
              CalendarRecurringSeriesCancellationDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarRecurringSeriesCancellationDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<
        CalendarRecurringSeriesCancellationDataRecord
      >(CalendarDataFailureKind.unauthenticated);
    } on Object {
      return const CalendarDataFailed<
        CalendarRecurringSeriesCancellationDataRecord
      >(CalendarDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<
    CalendarDataResult<
      CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
    >
  >
  cancelRecurringSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'cancel_recurring_calendar_series_from_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_effective_occurrence_id': effectiveOccurrenceId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesFromOccurrenceCancellationDataRecord?
      record =
          calendarRecurringSeriesFromOccurrenceCancellationRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<
              CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
            >(CalendarDataFailureKind.invalidPayload)
          : CalendarDataSucceeded<
              CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<
        CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
      >(calendarDataFailureFromProviderCode(error.code));
    } on AuthException {
      return const CalendarDataFailed<
        CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
      >(CalendarDataFailureKind.unauthenticated);
    } on Object {
      return const CalendarDataFailed<
        CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
      >(CalendarDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<
    CalendarDataResult<CalendarRecurringSeriesCancellationResumeDataRecord>
  >
  resumeRecurringSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'resume_recurring_calendar_series_cancellation',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_cancellation_idempotency_key': cancellationIdempotencyKey,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<
          CalendarRecurringSeriesCancellationResumeDataRecord
        >(CalendarDataFailureKind.invalidPayload);
      }
      final CalendarRecurringSeriesCancellationResumeDataRecord? record =
          calendarRecurringSeriesCancellationResumeRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<
              CalendarRecurringSeriesCancellationResumeDataRecord
            >(CalendarDataFailureKind.invalidPayload)
          : CalendarDataSucceeded<
              CalendarRecurringSeriesCancellationResumeDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<
        CalendarRecurringSeriesCancellationResumeDataRecord
      >(calendarDataFailureFromProviderCode(error.code));
    } on AuthException {
      return const CalendarDataFailed<
        CalendarRecurringSeriesCancellationResumeDataRecord
      >(CalendarDataFailureKind.unauthenticated);
    } on Object {
      return const CalendarDataFailed<
        CalendarRecurringSeriesCancellationResumeDataRecord
      >(CalendarDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<CalendarDataResult<CalendarEventDataRecord>> updateOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_one_time_event',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      return _eventMutationResult(
        response,
        expectedHouseholdId: householdId,
        expectedKeys: _calendarUpdatedKeys,
        markerKey: 'changed',
      );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarEventDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarEventDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarEventDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarEventDeletionDataRecord>>
  deleteOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'delete_one_time_event',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_expected_version': expectedVersion,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CalendarDataFailed<CalendarEventDeletionDataRecord>(
          CalendarDataFailureKind.invalidPayload,
        );
      }
      final CalendarEventDeletionDataRecord? record =
          calendarEventDeletionRecordFromPayload(
            response.single,
            expectedHouseholdId: householdId,
            expectedSeriesId: seriesId,
          );
      return record == null
          ? const CalendarDataFailed<CalendarEventDeletionDataRecord>(
              CalendarDataFailureKind.invalidPayload,
            )
          : CalendarDataSucceeded<CalendarEventDeletionDataRecord>(record);
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarEventDeletionDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarEventDeletionDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarEventDeletionDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarOccurrenceCommandDataRecord>>
  updateRecurringOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedOccurrenceVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_recurring_calendar_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_occurrence_id': occurrenceId,
          'p_expected_occurrence_version': expectedOccurrenceVersion,
          'p_title': title,
          'p_description': description,
          'p_is_all_day': isAllDay,
          'p_local_start_date': localStartDate,
          'p_local_start_time': localStartTime,
          'p_duration_minutes': durationMinutes,
          'p_all_day_end_date_exclusive': allDayEndDateExclusive,
          'p_timezone': timezone,
          'p_overlap_policy': overlapPolicy,
          'p_participant_member_ids': participantMemberIds,
        },
      );
      return _occurrenceCommandResult(
        response,
        expectedHouseholdId: householdId,
        expectedSeriesId: seriesId,
        expectedOccurrenceId: occurrenceId,
      );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CalendarDataResult<CalendarOccurrenceCommandDataRecord>>
  cancelRecurringOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedOccurrenceVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'cancel_recurring_calendar_occurrence',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_id': householdId,
          'p_series_id': seriesId,
          'p_occurrence_id': occurrenceId,
          'p_expected_occurrence_version': expectedOccurrenceVersion,
        },
      );
      return _occurrenceCommandResult(
        response,
        expectedHouseholdId: householdId,
        expectedSeriesId: seriesId,
        expectedOccurrenceId: occurrenceId,
      );
    } on PostgrestException catch (error) {
      return CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        calendarDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        CalendarDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
        CalendarDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

CalendarDataResult<CalendarEventDataRecord> _eventMutationResult(
  Object? response, {
  required String expectedHouseholdId,
  required Set<String> expectedKeys,
  required String markerKey,
}) {
  if (response is! List<dynamic> || response.length != 1) {
    return const CalendarDataFailed<CalendarEventDataRecord>(
      CalendarDataFailureKind.invalidPayload,
    );
  }
  final CalendarEventDataRecord? record = calendarEventRecordFromPayload(
    response.single,
    expectedHouseholdId: expectedHouseholdId,
    expectedKeys: expectedKeys,
    markerKey: markerKey,
  );
  return record == null
      ? const CalendarDataFailed<CalendarEventDataRecord>(
          CalendarDataFailureKind.invalidPayload,
        )
      : CalendarDataSucceeded<CalendarEventDataRecord>(record);
}

CalendarDataResult<CalendarOccurrenceCommandDataRecord>
_occurrenceCommandResult(
  Object? response, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
  required String expectedOccurrenceId,
}) {
  if (response is! List<dynamic> || response.length != 1) {
    return const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
      CalendarDataFailureKind.invalidPayload,
    );
  }
  final CalendarOccurrenceCommandDataRecord? record =
      calendarOccurrenceCommandRecordFromPayload(
        response.single,
        expectedHouseholdId: expectedHouseholdId,
        expectedSeriesId: expectedSeriesId,
        expectedOccurrenceId: expectedOccurrenceId,
      );
  return record == null
      ? const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
          CalendarDataFailureKind.invalidPayload,
        )
      : CalendarDataSucceeded<CalendarOccurrenceCommandDataRecord>(record);
}

CalendarEventPageDataRecord? calendarEventPageRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedViewMode,
  required String? expectedRangeStartDate,
  required String? expectedRangeEndDateExclusive,
  required int expectedLimit,
}) {
  if (payload is! List<dynamic> ||
      payload.isEmpty ||
      expectedLimit < 1 ||
      expectedLimit > 100 ||
      (expectedRangeStartDate == null) !=
          (expectedRangeEndDateExclusive == null)) {
    return null;
  }
  String? householdTimezone;
  String? householdLocalDate;
  String? generatedAt;
  String? viewMode;
  String? rangeStartDate;
  String? rangeEndDateExclusive;
  int? pageLimit;
  bool? hasMore;
  String? pageCursor;
  var metadataInitialized = false;
  var metadataOnlyRows = 0;
  final List<CalendarEventProjectionDataRecord> items =
      <CalendarEventProjectionDataRecord>[];
  for (final Object? item in payload) {
    final Map<String, Object?>? row = _strictMap(item, _calendarPageKeys);
    if (row == null ||
        _requiredString(row['household_id']) != expectedHouseholdId) {
      return null;
    }
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowHouseholdDate = _requiredString(
      row['household_local_date'],
    );
    final String? rowGeneratedAt = _normalizedUtcInstant(row['generated_at']);
    final String? rowViewMode = _requiredString(row['view_mode']);
    final String? rowRangeStart = _requiredString(row['range_start_date']);
    final String? rowRangeEnd = _requiredString(
      row['range_end_date_exclusive'],
    );
    final Object? rowPageLimit = row['page_limit'];
    final Object? rowHasMore = row['has_more'];
    final String? rowCursor = _nullableString(row['page_cursor']);
    if (rowTimezone == null ||
        rowHouseholdDate == null ||
        rowGeneratedAt == null ||
        rowViewMode != expectedViewMode ||
        rowRangeStart == null ||
        rowRangeEnd == null ||
        rowPageLimit is! int ||
        rowPageLimit != expectedLimit ||
        rowHasMore is! bool ||
        (row['page_cursor'] != null &&
            (rowCursor == null || rowCursor.isEmpty))) {
      return null;
    }
    if (!metadataInitialized) {
      householdTimezone = rowTimezone;
      householdLocalDate = rowHouseholdDate;
      generatedAt = rowGeneratedAt;
      viewMode = rowViewMode;
      rangeStartDate = rowRangeStart;
      rangeEndDateExclusive = rowRangeEnd;
      pageLimit = rowPageLimit;
      hasMore = rowHasMore;
      pageCursor = rowCursor;
      metadataInitialized = true;
    } else if (householdTimezone != rowTimezone ||
        householdLocalDate != rowHouseholdDate ||
        generatedAt != rowGeneratedAt ||
        viewMode != rowViewMode ||
        rangeStartDate != rowRangeStart ||
        rangeEndDateExclusive != rowRangeEnd ||
        pageLimit != rowPageLimit ||
        hasMore != rowHasMore ||
        pageCursor != rowCursor) {
      return null;
    }
    if (row['series_id'] == null) {
      if (_calendarV2ItemKeys.any((String key) => row[key] != null) ||
          _calendarProjectionKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final String? viewLocalDate = _requiredString(row['view_local_date']);
    final String? viewLocalTime = _normalizedLocalTime(row['view_local_time']);
    if (viewLocalDate == null ||
        (row['view_local_time'] != null && viewLocalTime == null)) {
      return null;
    }
    final CalendarEventDataRecord? event = calendarEventRecordFromPayload(
      row,
      expectedHouseholdId: expectedHouseholdId,
      expectedKeys: _calendarPageKeys,
    );
    if (event == null) {
      return null;
    }
    items.add(
      CalendarEventProjectionDataRecord(
        event: event,
        viewLocalDate: viewLocalDate,
        viewLocalTime: viewLocalTime,
      ),
    );
  }
  if (householdTimezone == null ||
      householdLocalDate == null ||
      generatedAt == null ||
      viewMode == null ||
      rangeStartDate == null ||
      rangeEndDateExclusive == null ||
      pageLimit == null ||
      hasMore == null ||
      items.length > expectedLimit ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && items.isNotEmpty ||
      items.isEmpty && metadataOnlyRows != 1 ||
      expectedRangeStartDate != null &&
          rangeStartDate != expectedRangeStartDate ||
      expectedRangeEndDateExclusive != null &&
          rangeEndDateExclusive != expectedRangeEndDateExclusive ||
      hasMore && (pageCursor == null || items.length != expectedLimit) ||
      !hasMore && pageCursor != null) {
    return null;
  }
  return CalendarEventPageDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    generatedAt: generatedAt,
    viewMode: viewMode,
    rangeStartDate: rangeStartDate,
    rangeEndDateExclusive: rangeEndDateExclusive,
    pageLimit: pageLimit,
    hasMore: hasMore,
    pageCursor: pageCursor,
    items: items,
  );
}

CalendarMonthSummaryDataRecord? calendarMonthSummaryRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedMonthStartDate,
}) {
  if (payload is! List<dynamic> || payload.isEmpty) {
    return null;
  }
  String? householdTimezone;
  String? householdLocalDate;
  String? generatedAt;
  String? monthStartDate;
  String? monthEndDateExclusive;
  final List<CalendarMonthDayDataRecord> days = <CalendarMonthDayDataRecord>[];
  for (final Object? item in payload) {
    final Map<String, Object?>? row = _strictMap(item, _calendarMonthKeys);
    if (row == null ||
        _requiredString(row['household_id']) != expectedHouseholdId) {
      return null;
    }
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowHouseholdDate = _requiredString(
      row['household_local_date'],
    );
    final String? rowGeneratedAt = _normalizedUtcInstant(row['generated_at']);
    final String? rowMonthStart = _requiredString(row['month_start_date']);
    final String? rowMonthEnd = _requiredString(
      row['month_end_date_exclusive'],
    );
    final String? rowDay = _requiredString(row['day_date']);
    final Object? eventCount = row['event_count'];
    final Object? allDayCount = row['all_day_count'];
    final Object? timedCount = row['timed_count'];
    if (rowTimezone == null ||
        rowHouseholdDate == null ||
        rowGeneratedAt == null ||
        rowMonthStart != expectedMonthStartDate ||
        rowMonthEnd == null ||
        rowDay == null ||
        eventCount is! int ||
        allDayCount is! int ||
        timedCount is! int) {
      return null;
    }
    householdTimezone ??= rowTimezone;
    householdLocalDate ??= rowHouseholdDate;
    generatedAt ??= rowGeneratedAt;
    monthStartDate ??= rowMonthStart;
    monthEndDateExclusive ??= rowMonthEnd;
    if (householdTimezone != rowTimezone ||
        householdLocalDate != rowHouseholdDate ||
        generatedAt != rowGeneratedAt ||
        monthStartDate != rowMonthStart ||
        monthEndDateExclusive != rowMonthEnd) {
      return null;
    }
    days.add(
      CalendarMonthDayDataRecord(
        date: rowDay,
        eventCount: eventCount,
        allDayCount: allDayCount,
        timedCount: timedCount,
      ),
    );
  }
  if (householdTimezone == null ||
      householdLocalDate == null ||
      generatedAt == null ||
      monthStartDate == null ||
      monthEndDateExclusive == null) {
    return null;
  }
  return CalendarMonthSummaryDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    generatedAt: generatedAt,
    monthStartDate: monthStartDate,
    monthEndDateExclusive: monthEndDateExclusive,
    days: days,
  );
}

CalendarEventListDataRecord? calendarEventListRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required int expectedLimit,
}) {
  if (payload is! List<dynamic> ||
      payload.isEmpty ||
      expectedLimit < 1 ||
      expectedLimit > 100) {
    return null;
  }
  String? householdTimezone;
  String? householdLocalDate;
  var metadataOnlyRows = 0;
  final List<CalendarEventDataRecord> events = <CalendarEventDataRecord>[];
  for (final Object? item in payload) {
    final Map<String, Object?>? row = _strictMap(item, _calendarEventKeys);
    if (row == null ||
        _requiredString(row['household_id']) != expectedHouseholdId) {
      return null;
    }
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowLocalDate = _requiredString(row['household_local_date']);
    if (rowTimezone == null || rowLocalDate == null) {
      return null;
    }
    householdTimezone ??= rowTimezone;
    householdLocalDate ??= rowLocalDate;
    if (householdTimezone != rowTimezone ||
        householdLocalDate != rowLocalDate) {
      return null;
    }
    if (row['series_id'] == null) {
      if (_calendarItemKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final CalendarEventDataRecord? event = calendarEventRecordFromPayload(
      row,
      expectedHouseholdId: expectedHouseholdId,
    );
    if (event == null) {
      return null;
    }
    events.add(event);
  }
  if (householdTimezone == null ||
      householdLocalDate == null ||
      events.length > expectedLimit ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && events.isNotEmpty) {
    return null;
  }
  return CalendarEventListDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    events: events,
  );
}

CalendarEventDataRecord? calendarEventRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  Set<String> expectedKeys = _calendarEventKeys,
  String? markerKey,
}) {
  final Map<String, Object?>? row = _strictMap(payload, expectedKeys);
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['household_timezone']) == null ||
      _requiredString(row['household_local_date']) == null ||
      markerKey != null && row[markerKey] is! bool) {
    return null;
  }
  final String? seriesId = _requiredString(row['series_id']);
  final String? occurrenceId = _requiredString(row['occurrence_id']);
  final String? title = _requiredString(row['title']);
  final String? description = _nullableString(row['description']);
  final Object? isAllDay = row['is_all_day'];
  final String? localStartDate = _requiredString(row['local_start_date']);
  final String? localStartTime = _normalizedLocalTime(row['local_start_time']);
  final Object? durationMinutes = row['duration_minutes'];
  final String? allDayEndDate = _nullableString(
    row['all_day_end_date_exclusive'],
  );
  final String? timezone = _nullableString(row['timezone']);
  final String? overlapPolicy = _nullableString(row['overlap_policy']);
  final String? startsAt = _normalizedUtcInstant(row['starts_at']);
  final String? endsAt = _normalizedUtcInstant(row['ends_at']);
  final String? dstResolution = _nullableString(row['dst_resolution']);
  final Object? utcOffsetSeconds = row['utc_offset_seconds'];
  final List<String>? participantIds = _stringList(
    row['participant_member_ids'],
  );
  final List<String>? participantNames = _stringList(
    row['participant_display_names'],
  );
  final Object? version = row['version'];
  final Object? occurrenceVersion = row['occurrence_version'];
  final bool recurrenceAware = expectedKeys.contains('recurrence_rule');
  final Map<String, Object?>? recurrenceRule = row['recurrence_rule'] == null
      ? null
      : _stringObjectMap(row['recurrence_rule']);
  final String? recurrenceLocalStartDate = recurrenceAware
      ? _requiredString(row['recurrence_local_start_date'])
      : null;
  final Object? revisionNumber = recurrenceAware ? row['revision_number'] : 1;
  final Object? isException = recurrenceAware ? row['is_exception'] : false;
  if (seriesId == null ||
      occurrenceId == null ||
      title == null ||
      (row['description'] != null && description == null) ||
      isAllDay is! bool ||
      localStartDate == null ||
      (row['local_start_time'] != null && localStartTime == null) ||
      durationMinutes != null && durationMinutes is! int ||
      (row['all_day_end_date_exclusive'] != null && allDayEndDate == null) ||
      (row['timezone'] != null && timezone == null) ||
      (row['overlap_policy'] != null && overlapPolicy == null) ||
      (row['starts_at'] != null && startsAt == null) ||
      (row['ends_at'] != null && endsAt == null) ||
      (row['dst_resolution'] != null && dstResolution == null) ||
      utcOffsetSeconds != null && utcOffsetSeconds is! int ||
      participantIds == null ||
      participantNames == null ||
      version is! int ||
      occurrenceVersion is! int ||
      recurrenceAware &&
          (row['recurrence_rule'] != null && recurrenceRule == null ||
              recurrenceLocalStartDate == null ||
              revisionNumber is! int ||
              isException is! bool)) {
    return null;
  }
  return CalendarEventDataRecord(
    householdId: expectedHouseholdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    title: title,
    description: description,
    isAllDay: isAllDay,
    localStartDate: localStartDate,
    localStartTime: localStartTime,
    durationMinutes: durationMinutes as int?,
    allDayEndDateExclusive: allDayEndDate,
    timezone: timezone,
    overlapPolicy: overlapPolicy,
    startsAt: startsAt,
    endsAt: endsAt,
    dstResolution: dstResolution,
    utcOffsetSeconds: utcOffsetSeconds as int?,
    participantMemberIds: participantIds,
    participantDisplayNames: participantNames,
    version: version,
    occurrenceVersion: occurrenceVersion,
    recurrenceRule: recurrenceRule,
    recurrenceLocalStartDate: recurrenceLocalStartDate,
    revisionNumber: revisionNumber is int ? revisionNumber : 1,
    isException: isException is bool && isException,
  );
}

RecurringCalendarEventDataRecord? recurringCalendarEventRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringCreatedKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId) {
    return null;
  }
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? householdLocalDate = _requiredString(
    row['household_local_date'],
  );
  final String? seriesId = _requiredString(row['series_id']);
  final String? firstOccurrenceId = _requiredString(row['first_occurrence_id']);
  final Map<String, Object?>? recurrenceRule = _stringObjectMap(
    row['recurrence_rule'],
  );
  final String? materializedThrough = _requiredString(
    row['materialized_through'],
  );
  final Object? materializedCount = row['materialized_count'];
  final Object? version = row['version'];
  final Object? created = row['created'];
  if (householdTimezone == null ||
      householdLocalDate == null ||
      seriesId == null ||
      firstOccurrenceId == null ||
      recurrenceRule == null ||
      materializedThrough == null ||
      materializedCount is! int ||
      version is! int ||
      created is! bool) {
    return null;
  }
  return RecurringCalendarEventDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    seriesId: seriesId,
    firstOccurrenceId: firstOccurrenceId,
    recurrenceRule: recurrenceRule,
    materializedThrough: materializedThrough,
    materializedCount: materializedCount,
    version: version,
    created: created,
  );
}

CalendarRecurringSeriesDetailDataRecord?
calendarRecurringSeriesDetailRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringSeriesDetailKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['series_id']) != expectedSeriesId) {
    return null;
  }
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? householdLocalDate = _requiredString(
    row['household_local_date'],
  );
  final String? revisionId = _requiredString(row['revision_id']);
  final Object? revisionNumber = row['revision_number'];
  final String? title = _requiredString(row['title']);
  final String? description = _nullableString(row['description']);
  final Object? isAllDay = row['is_all_day'];
  final String? localStartDate = _requiredString(row['local_start_date']);
  final String? localStartTime = _normalizedLocalTime(row['local_start_time']);
  final Object? durationMinutes = row['duration_minutes'];
  final String? allDayEndDate = _nullableString(
    row['all_day_end_date_exclusive'],
  );
  final String? timezone = _nullableString(row['timezone']);
  final String? overlapPolicy = _nullableString(row['overlap_policy']);
  final Map<String, Object?>? recurrenceRule = _stringObjectMap(
    row['recurrence_rule'],
  );
  final List<String>? participantIds = _stringList(
    row['participant_member_ids'],
  );
  final List<String>? participantNames = _stringList(
    row['participant_display_names'],
  );
  final Object? version = row['version'];
  if (householdTimezone == null ||
      householdLocalDate == null ||
      revisionId == null ||
      revisionNumber is! int ||
      title == null ||
      (row['description'] != null && description == null) ||
      isAllDay is! bool ||
      localStartDate == null ||
      (row['local_start_time'] != null && localStartTime == null) ||
      (durationMinutes != null && durationMinutes is! int) ||
      (row['all_day_end_date_exclusive'] != null && allDayEndDate == null) ||
      (row['timezone'] != null && timezone == null) ||
      (row['overlap_policy'] != null && overlapPolicy == null) ||
      recurrenceRule == null ||
      participantIds == null ||
      participantNames == null ||
      version is! int) {
    return null;
  }
  return CalendarRecurringSeriesDetailDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    seriesId: expectedSeriesId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    title: title,
    description: description,
    isAllDay: isAllDay,
    localStartDate: localStartDate,
    localStartTime: localStartTime,
    durationMinutes: durationMinutes as int?,
    allDayEndDateExclusive: allDayEndDate,
    timezone: timezone,
    overlapPolicy: overlapPolicy,
    recurrenceRule: recurrenceRule,
    participantMemberIds: participantIds,
    participantDisplayNames: participantNames,
    version: version,
  );
}

CalendarRecurringSeriesUpdateDataRecord?
calendarRecurringSeriesUpdateRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringSeriesUpdateKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['series_id']) != expectedSeriesId) {
    return null;
  }
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? householdLocalDate = _requiredString(
    row['household_local_date'],
  );
  final String? revisionId = _requiredString(row['revision_id']);
  final Object? revisionNumber = row['revision_number'];
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final String? materializedThrough = _requiredString(
    row['materialized_through'],
  );
  final Object? version = row['version'];
  final Object? rebuiltCount = row['rebuilt_count'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedExceptionCount = row['preserved_exception_count'];
  final Object? changed = row['changed'];
  if (householdTimezone == null ||
      householdLocalDate == null ||
      revisionId == null ||
      revisionNumber is! int ||
      effectiveLocalDate == null ||
      materializedThrough == null ||
      version is! int ||
      rebuiltCount is! int ||
      cancelledCount is! int ||
      preservedExceptionCount is! int ||
      changed is! bool) {
    return null;
  }
  return CalendarRecurringSeriesUpdateDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    seriesId: expectedSeriesId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    effectiveLocalDate: effectiveLocalDate,
    materializedThrough: materializedThrough,
    version: version,
    rebuiltCount: rebuiltCount,
    cancelledCount: cancelledCount,
    preservedExceptionCount: preservedExceptionCount,
    changed: changed,
  );
}

CalendarRecurringSeriesCancellationDataRecord?
calendarRecurringSeriesCancellationRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringSeriesCancellationKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['series_id']) != expectedSeriesId) {
    return null;
  }
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? householdLocalDate = _requiredString(
    row['household_local_date'],
  );
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedPastCount = row['preserved_past_count'];
  final Object? changed = row['changed'];
  if (householdTimezone == null ||
      householdLocalDate == null ||
      effectiveLocalDate == null ||
      version is! int ||
      cancelledCount is! int ||
      preservedPastCount is! int ||
      changed is! bool) {
    return null;
  }
  return CalendarRecurringSeriesCancellationDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    seriesId: expectedSeriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    cancelledCount: cancelledCount,
    preservedPastCount: preservedPastCount,
    changed: changed,
  );
}

CalendarRecurringSeriesFromOccurrenceCancellationDataRecord?
calendarRecurringSeriesFromOccurrenceCancellationRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringSeriesFromOccurrenceCancellationKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['series_id']) != expectedSeriesId) {
    return null;
  }
  final String? householdTimezone = _requiredString(row['household_timezone']);
  final String? householdLocalDate = _requiredString(
    row['household_local_date'],
  );
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? cancelledCount = row['cancelled_count'];
  final Object? preservedPastCount = row['preserved_past_count'];
  final Object? terminalRevisionIdValue = row['terminal_revision_id'];
  final String? terminalRevisionId = _nullableString(terminalRevisionIdValue);
  final Object? terminalRevisionNumber = row['terminal_revision_number'];
  final Object? changed = row['changed'];
  if (householdTimezone == null ||
      householdLocalDate == null ||
      effectiveLocalDate == null ||
      version is! int ||
      cancelledCount is! int ||
      preservedPastCount is! int ||
      terminalRevisionIdValue != null && terminalRevisionId == null ||
      terminalRevisionNumber != null && terminalRevisionNumber is! int ||
      (terminalRevisionId == null) != (terminalRevisionNumber == null) ||
      changed is! bool) {
    return null;
  }
  return CalendarRecurringSeriesFromOccurrenceCancellationDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    seriesId: expectedSeriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    cancelledCount: cancelledCount,
    preservedPastCount: preservedPastCount,
    terminalRevisionId: terminalRevisionId,
    terminalRevisionNumber: terminalRevisionNumber as int?,
    changed: changed,
  );
}

CalendarRecurringSeriesCancellationResumeDataRecord?
calendarRecurringSeriesCancellationResumeRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarRecurringSeriesCancellationResumeKeys,
  );
  if (row == null ||
      _requiredString(row['household_id']) != expectedHouseholdId ||
      _requiredString(row['series_id']) != expectedSeriesId) {
    return null;
  }
  final String? effectiveLocalDate = _requiredString(
    row['effective_local_date'],
  );
  final Object? version = row['version'];
  final Object? restoredCount = row['restored_count'];
  final Object? preservedPastCount = row['preserved_past_count'];
  final String? revisionId = _requiredString(row['revision_id']);
  final Object? revisionNumber = row['revision_number'];
  final Object? changed = row['changed'];
  if (effectiveLocalDate == null ||
      version is! int ||
      restoredCount is! int ||
      preservedPastCount is! int ||
      revisionId == null ||
      revisionNumber is! int ||
      changed is! bool) {
    return null;
  }
  return CalendarRecurringSeriesCancellationResumeDataRecord(
    householdId: expectedHouseholdId,
    seriesId: expectedSeriesId,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    restoredCount: restoredCount,
    preservedPastCount: preservedPastCount,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    changed: changed,
  );
}

CalendarEventDataRecord? calendarEventCreatedRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  return calendarEventRecordFromPayload(
    payload,
    expectedHouseholdId: expectedHouseholdId,
    expectedKeys: _calendarCreatedKeys,
    markerKey: 'created',
  );
}

CalendarEventDataRecord? calendarEventUpdatedRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  return calendarEventRecordFromPayload(
    payload,
    expectedHouseholdId: expectedHouseholdId,
    expectedKeys: _calendarUpdatedKeys,
    markerKey: 'changed',
  );
}

CalendarOccurrenceCommandDataRecord? calendarOccurrenceCommandRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
  required String expectedOccurrenceId,
}) {
  final Map<String, Object?>? row = _strictMap(
    payload,
    _calendarOccurrenceCommandKeys,
  );
  final String? householdId = row == null
      ? null
      : _requiredString(row['household_id']);
  final String? seriesId = row == null
      ? null
      : _requiredString(row['series_id']);
  final String? occurrenceId = row == null
      ? null
      : _requiredString(row['occurrence_id']);
  final String? revisionId = row == null
      ? null
      : _nullableString(row['revision_id']);
  final Object? occurrenceVersion = row?['occurrence_version'];
  final Object? exceptionVersion = row?['exception_version'];
  final Object? cancelled = row?['cancelled'];
  final Object? changed = row?['changed'];
  if (householdId != expectedHouseholdId ||
      seriesId != expectedSeriesId ||
      occurrenceId != expectedOccurrenceId ||
      (row?['revision_id'] != null && revisionId == null) ||
      occurrenceVersion is! int ||
      exceptionVersion is! int ||
      cancelled is! bool ||
      changed is! bool) {
    return null;
  }
  return CalendarOccurrenceCommandDataRecord(
    householdId: householdId!,
    seriesId: seriesId!,
    occurrenceId: occurrenceId!,
    revisionId: revisionId,
    occurrenceVersion: occurrenceVersion,
    exceptionVersion: exceptionVersion,
    cancelled: cancelled,
    changed: changed,
  );
}

CalendarEventDeletionDataRecord? calendarEventDeletionRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedSeriesId,
}) {
  final Map<String, Object?>? row = _strictMap(payload, _calendarDeletedKeys);
  final String? householdId = row == null
      ? null
      : _requiredString(row['household_id']);
  final String? seriesId = row == null
      ? null
      : _requiredString(row['series_id']);
  final String? occurrenceId = row == null
      ? null
      : _requiredString(row['occurrence_id']);
  final Object? version = row?['version'];
  final Object? occurrenceVersion = row?['occurrence_version'];
  final Object? deleted = row?['deleted'];
  final Object? changed = row?['changed'];
  if (householdId != expectedHouseholdId ||
      seriesId != expectedSeriesId ||
      occurrenceId == null ||
      version is! int ||
      occurrenceVersion is! int ||
      deleted is! bool ||
      changed is! bool) {
    return null;
  }
  return CalendarEventDeletionDataRecord(
    householdId: householdId!,
    seriesId: seriesId!,
    occurrenceId: occurrenceId,
    version: version,
    occurrenceVersion: occurrenceVersion,
    deleted: deleted,
    changed: changed,
  );
}

CalendarOccurrenceLocatorDataRecord? calendarOccurrenceLocatorRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedOccurrenceId,
}) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _strictMap(
    payload.single,
    _calendarOccurrenceLocatorKeys,
  );
  final String? householdId = row == null
      ? null
      : _requiredString(row['household_id']);
  final String? householdTimezone = row == null
      ? null
      : _requiredString(row['household_timezone']);
  final String? householdLocalDate = row == null
      ? null
      : _requiredString(row['household_local_date']);
  final String? generatedAt = row == null
      ? null
      : _normalizedUtcInstant(row['generated_at']);
  final String? seriesId = row == null
      ? null
      : _requiredString(row['series_id']);
  final String? occurrenceId = row == null
      ? null
      : _requiredString(row['occurrence_id']);
  final String? viewLocalDate = row == null
      ? null
      : _requiredString(row['view_local_date']);
  final Object? seriesVersion = row?['series_version'];
  final Object? occurrenceVersion = row?['occurrence_version'];
  if (householdId != expectedHouseholdId ||
      householdTimezone == null ||
      householdLocalDate == null ||
      generatedAt == null ||
      seriesId == null ||
      occurrenceId != expectedOccurrenceId ||
      viewLocalDate == null ||
      seriesVersion is! int ||
      seriesVersion < 1 ||
      occurrenceVersion is! int ||
      occurrenceVersion < 1) {
    return null;
  }
  return CalendarOccurrenceLocatorDataRecord(
    householdId: householdId!,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    generatedAt: generatedAt,
    seriesId: seriesId,
    occurrenceId: occurrenceId!,
    viewLocalDate: viewLocalDate,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
  );
}

CalendarOverlapPreviewDataRecord? calendarOverlapPreviewRecordFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
  required String expectedWindowStartDate,
  required int expectedLimit,
}) {
  if (payload is! List<dynamic> ||
      payload.isEmpty ||
      expectedLimit < 1 ||
      expectedLimit > 10) {
    return null;
  }
  String? householdTimezone;
  String? householdLocalDate;
  String? generatedAt;
  String? checkedFrom;
  String? checkedThrough;
  int? candidateCount;
  int? totalCount;
  bool? truncated;
  var metadataOnlyRows = 0;
  final List<CalendarOverlapConflictDataRecord> conflicts =
      <CalendarOverlapConflictDataRecord>[];
  for (final Object? item in payload) {
    final Map<String, Object?>? row = _strictMap(
      item,
      _calendarOverlapPreviewKeys,
    );
    if (row == null ||
        _requiredString(row['household_id']) != expectedHouseholdId) {
      return null;
    }
    final String? rowTimezone = _requiredString(row['household_timezone']);
    final String? rowHouseholdDate = _requiredString(
      row['household_local_date'],
    );
    final String? rowGeneratedAt = _normalizedUtcInstant(row['generated_at']);
    final String? rowCheckedFrom = _requiredString(
      row['checked_from_local_date'],
    );
    final String? rowCheckedThrough = _requiredString(
      row['checked_through_local_date'],
    );
    final Object? rowCandidateCount = row['candidate_occurrence_count'];
    final Object? rowTotalCount = row['total_conflict_count'];
    final Object? rowTruncated = row['truncated'];
    if (rowTimezone == null ||
        rowHouseholdDate == null ||
        rowGeneratedAt == null ||
        rowCheckedFrom != expectedWindowStartDate ||
        rowCheckedThrough == null ||
        rowCandidateCount is! int ||
        rowCandidateCount < 0 ||
        rowCandidateCount > 366 ||
        rowTotalCount is! int ||
        rowTotalCount < 0 ||
        rowTruncated is! bool) {
      return null;
    }
    householdTimezone ??= rowTimezone;
    householdLocalDate ??= rowHouseholdDate;
    generatedAt ??= rowGeneratedAt;
    checkedFrom ??= rowCheckedFrom;
    checkedThrough ??= rowCheckedThrough;
    candidateCount ??= rowCandidateCount;
    totalCount ??= rowTotalCount;
    truncated ??= rowTruncated;
    if (householdTimezone != rowTimezone ||
        householdLocalDate != rowHouseholdDate ||
        generatedAt != rowGeneratedAt ||
        checkedFrom != rowCheckedFrom ||
        checkedThrough != rowCheckedThrough ||
        candidateCount != rowCandidateCount ||
        totalCount != rowTotalCount ||
        truncated != rowTruncated) {
      return null;
    }
    if (row['conflicting_occurrence_id'] == null) {
      const Set<String> conflictKeys = <String>{
        'candidate_local_start_date',
        'conflicting_series_id',
        'conflicting_occurrence_id',
        'conflicting_title',
        'conflicting_is_all_day',
        'conflicting_view_local_start_date',
        'conflicting_view_local_start_time',
        'conflicting_duration_minutes',
        'conflicting_all_day_end_date_exclusive',
        'conflicting_participant_member_ids',
        'conflicting_participant_display_names',
      };
      if (conflictKeys.any((String key) => row[key] != null)) {
        return null;
      }
      metadataOnlyRows += 1;
      continue;
    }
    final String? candidateDate = _requiredString(
      row['candidate_local_start_date'],
    );
    final String? seriesId = _requiredString(row['conflicting_series_id']);
    final String? occurrenceId = _requiredString(
      row['conflicting_occurrence_id'],
    );
    final String? title = _requiredString(row['conflicting_title']);
    final Object? isAllDay = row['conflicting_is_all_day'];
    final String? viewDate = _requiredString(
      row['conflicting_view_local_start_date'],
    );
    final String? viewTime = _normalizedLocalTime(
      row['conflicting_view_local_start_time'],
    );
    final Object? duration = row['conflicting_duration_minutes'];
    final String? allDayEnd = _nullableString(
      row['conflicting_all_day_end_date_exclusive'],
    );
    final List<String>? participantIds = _stringList(
      row['conflicting_participant_member_ids'],
    );
    final List<String>? participantNames = _stringList(
      row['conflicting_participant_display_names'],
    );
    if (candidateDate == null ||
        seriesId == null ||
        occurrenceId == null ||
        title == null ||
        isAllDay is! bool ||
        viewDate == null ||
        (row['conflicting_view_local_start_time'] != null &&
            viewTime == null) ||
        (duration != null && duration is! int) ||
        (row['conflicting_all_day_end_date_exclusive'] != null &&
            allDayEnd == null) ||
        participantIds == null ||
        participantNames == null) {
      return null;
    }
    conflicts.add(
      CalendarOverlapConflictDataRecord(
        candidateLocalStartDate: candidateDate,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        title: title,
        isAllDay: isAllDay,
        viewLocalStartDate: viewDate,
        viewLocalStartTime: viewTime,
        durationMinutes: duration as int?,
        allDayEndDateExclusive: allDayEnd,
        participantMemberIds: participantIds,
        participantDisplayNames: participantNames,
      ),
    );
  }
  if (householdTimezone == null ||
      householdLocalDate == null ||
      generatedAt == null ||
      checkedFrom == null ||
      checkedThrough == null ||
      candidateCount == null ||
      totalCount == null ||
      truncated == null ||
      conflicts.length > expectedLimit ||
      totalCount < conflicts.length ||
      truncated != (totalCount > conflicts.length) ||
      metadataOnlyRows > 1 ||
      metadataOnlyRows == 1 && conflicts.isNotEmpty ||
      conflicts.isEmpty && metadataOnlyRows != 1 ||
      totalCount == 0 && conflicts.isNotEmpty ||
      totalCount > 0 && conflicts.isEmpty) {
    return null;
  }
  return CalendarOverlapPreviewDataRecord(
    householdId: expectedHouseholdId,
    householdTimezone: householdTimezone,
    householdLocalDate: householdLocalDate,
    generatedAt: generatedAt,
    checkedFromLocalDate: checkedFrom,
    checkedThroughLocalDate: checkedThrough,
    candidateOccurrenceCount: candidateCount,
    totalConflictCount: totalCount,
    truncated: truncated,
    conflicts: conflicts,
  );
}

CalendarDataFailureKind calendarDataFailureFromProviderCode(String? code) {
  return switch (code) {
    'KFE01' || 'PGRST301' => CalendarDataFailureKind.unauthenticated,
    'KFE02' || 'KFE07' => CalendarDataFailureKind.invalidInput,
    'KFE03' => CalendarDataFailureKind.notFoundOrForbidden,
    'KFE04' => CalendarDataFailureKind.idempotencyConflict,
    'KFE05' => CalendarDataFailureKind.staleVersion,
    'KFE06' => CalendarDataFailureKind.nonexistentLocalTime,
    'KFE08' => CalendarDataFailureKind.transitionNotAllowed,
    'KFB10' || 'KFB11' => CalendarDataFailureKind.featurePolicyUnavailable,
    'KFB12' => CalendarDataFailureKind.featureLimitReached,
    _ when code?.startsWith('PGRST') ?? false =>
      CalendarDataFailureKind.temporarilyUnavailable,
    _ => CalendarDataFailureKind.unknown,
  };
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

Map<String, Object?>? _stringObjectMap(Object? value) {
  if (value is! Map || value.keys.any((Object? key) => key is! String)) {
    return null;
  }
  return Map<String, Object?>.from(value);
}

String? _requiredString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

String? _nullableString(Object? value) {
  return value == null || value is String ? value as String? : null;
}

List<String>? _stringList(Object? value) {
  if (value is! List || value.any((Object? item) => item is! String)) {
    return null;
  }
  return List<String>.unmodifiable(value.cast<String>());
}

String? _normalizedLocalTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    return null;
  }
  final RegExpMatch? match = RegExp(
    r'^([01]\d|2[0-3]):([0-5]\d)(?::00(?:\.0{1,6})?)?$',
  ).firstMatch(value);
  return match == null ? null : '${match.group(1)}:${match.group(2)}';
}

String? _normalizedUtcInstant(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    return null;
  }
  if (!RegExp(r'(?:[zZ]|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);
  return parsed?.toUtc().toIso8601String();
}
