import 'package:kinflow_app/features/notifications/data/datasources/notification_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _notificationPreferenceKeys = <String>{
  'household_id',
  'category',
  'native_push',
  'web_push',
  'email',
  'in_app',
  'quiet_start',
  'quiet_end',
  'timezone',
  'reminder_lead_minutes',
  'additional_reminder_lead_minutes',
  'updated_at',
  'version',
  'is_default',
};
const Set<String> _notificationInboxKeys = <String>{
  'inbox_item_id',
  'item_version',
  'source_event_id',
  'household_id',
  'category',
  'subject_type',
  'subject_id',
  'scheduled_at',
  'created_at',
  'read_at',
  'payload',
  'snooze_count',
  'snooze_max_minutes',
  'has_more',
  'next_before_created_at',
  'next_before_id',
};
const Set<String> _notificationReadKeys = <String>{
  'marked_count',
  'unread_count',
  'marked_at',
};
const Set<String> _notificationSnoozeKeys = <String>{
  'command_id',
  'source_event_id',
  'inbox_item_id',
  'item_version',
  'snoozed_until',
  'snooze_minutes',
  'snooze_count',
  'unread_count',
  'recorded_at',
};
const Set<String> _notificationPushTargetKeys = <String>{
  'delivery_id',
  'household_id',
  'category',
  'subject_type',
  'subject_id',
  'inbox_item_id',
  'safe_destination',
};

final class SupabaseNotificationDataSource implements NotificationDataSource {
  const SupabaseNotificationDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<NotificationDataResult<List<NotificationPreferenceDataRecord>>>
  loadPreferences({required String householdId}) async {
    try {
      final Object? response = await _client.rpc(
        'get_notification_preferences_v3',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final List<NotificationPreferenceDataRecord>? records =
          notificationPreferenceRecordsFromPayload(response);
      return records == null
          ? const NotificationDataFailed<
              List<NotificationPreferenceDataRecord>
            >(NotificationDataFailureKind.invalidPayload)
          : NotificationDataSucceeded<List<NotificationPreferenceDataRecord>>(
              records,
            );
    } on PostgrestException catch (error) {
      return NotificationDataFailed<List<NotificationPreferenceDataRecord>>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<
        List<NotificationPreferenceDataRecord>
      >(NotificationDataFailureKind.unauthenticated);
    } on Object {
      return const NotificationDataFailed<
        List<NotificationPreferenceDataRecord>
      >(NotificationDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<NotificationDataResult<NotificationInboxPageDataRecord>> loadInbox({
    required String householdId,
    required int limit,
    required String? beforeCreatedAt,
    required String? beforeId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'list_notification_inbox_items_v2',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_limit': limit,
          'p_before_created_at': beforeCreatedAt,
          'p_before_id': beforeId,
        },
      );
      final NotificationInboxPageDataRecord? record =
          notificationInboxPageRecordFromPayload(response);
      return record == null
          ? const NotificationDataFailed<NotificationInboxPageDataRecord>(
              NotificationDataFailureKind.invalidPayload,
            )
          : NotificationDataSucceeded<NotificationInboxPageDataRecord>(record);
    } on PostgrestException catch (error) {
      return NotificationDataFailed<NotificationInboxPageDataRecord>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<NotificationInboxPageDataRecord>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<NotificationInboxPageDataRecord>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<NotificationDataResult<int>> loadUnreadCount({
    required String householdId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_notification_unread_count',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final int? count = _integer(response);
      return count == null || count < 0
          ? const NotificationDataFailed<int>(
              NotificationDataFailureKind.invalidPayload,
            )
          : NotificationDataSucceeded<int>(count);
    } on PostgrestException catch (error) {
      return NotificationDataFailed<int>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<int>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<int>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<NotificationDataResult<NotificationPreferenceDataRecord>>
  updatePreference({
    required String householdId,
    required String category,
    required bool nativePush,
    required bool webPush,
    required bool email,
    required bool inApp,
    required String? quietStart,
    required String? quietEnd,
    required String timezone,
    required int reminderLeadMinutes,
    required List<int> additionalReminderLeadMinutes,
    required int expectedVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'update_notification_preference_v3',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_category': category,
          'p_native_push': nativePush,
          'p_web_push': webPush,
          'p_email': email,
          'p_in_app': inApp,
          'p_quiet_start': quietStart,
          'p_quiet_end': quietEnd,
          'p_timezone': timezone,
          'p_reminder_lead_minutes': reminderLeadMinutes,
          'p_additional_reminder_lead_minutes': additionalReminderLeadMinutes,
          'p_expected_version': expectedVersion,
        },
      );
      final NotificationPreferenceDataRecord? record =
          notificationPreferenceRecordFromSinglePayload(response);
      return record == null
          ? const NotificationDataFailed<NotificationPreferenceDataRecord>(
              NotificationDataFailureKind.invalidPayload,
            )
          : NotificationDataSucceeded<NotificationPreferenceDataRecord>(record);
    } on PostgrestException catch (error) {
      return NotificationDataFailed<NotificationPreferenceDataRecord>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<NotificationPreferenceDataRecord>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<NotificationPreferenceDataRecord>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<NotificationDataResult<NotificationReadDataRecord>> markRead({
    required String householdId,
    required List<String> itemIds,
  }) {
    return _readCommand('mark_notification_inbox_items_read', <String, Object?>{
      'p_household_id': householdId,
      'p_item_ids': itemIds,
    });
  }

  @override
  Future<NotificationDataResult<NotificationReadDataRecord>> markAllRead({
    required String householdId,
  }) {
    return _readCommand('mark_all_notification_inbox_read', <String, Object?>{
      'p_household_id': householdId,
      'p_through_created_at': null,
    });
  }

  @override
  Future<NotificationDataResult<NotificationSnoozeDataRecord>> snoozeCalendar({
    required String householdId,
    required String inboxItemId,
    required int snoozeMinutes,
    required String commandId,
    required int expectedItemVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'snooze_calendar_notification',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_inbox_item_id': inboxItemId,
          'p_snooze_minutes': snoozeMinutes,
          'p_command_id': commandId,
          'p_expected_item_version': expectedItemVersion,
        },
      );
      final NotificationSnoozeDataRecord? record =
          notificationSnoozeRecordFromPayload(response);
      return record == null
          ? const NotificationDataFailed<NotificationSnoozeDataRecord>(
              NotificationDataFailureKind.invalidPayload,
            )
          : NotificationDataSucceeded<NotificationSnoozeDataRecord>(record);
    } on PostgrestException catch (error) {
      return NotificationDataFailed<NotificationSnoozeDataRecord>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<NotificationSnoozeDataRecord>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<NotificationSnoozeDataRecord>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<NotificationDataResult<NotificationPushTargetDataRecord?>>
  resolvePushTarget({
    required String deliveryId,
    required String householdId,
    required String subjectId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'resolve_notification_push_target',
        params: <String, Object?>{
          'p_delivery_id': deliveryId,
          'p_household_id': householdId,
          'p_subject_id': subjectId,
        },
      );
      final NotificationPushTargetDataRecord? record;
      if (response is List<dynamic> && response.isEmpty) {
        record = null;
      } else {
        record = notificationPushTargetRecordFromPayload(response);
        if (record == null) {
          return const NotificationDataFailed<
            NotificationPushTargetDataRecord?
          >(NotificationDataFailureKind.invalidPayload);
        }
      }
      return NotificationDataSucceeded<NotificationPushTargetDataRecord?>(
        record,
      );
    } on PostgrestException catch (error) {
      return NotificationDataFailed<NotificationPushTargetDataRecord?>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<NotificationPushTargetDataRecord?>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<NotificationPushTargetDataRecord?>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  Future<NotificationDataResult<NotificationReadDataRecord>> _readCommand(
    String function,
    Map<String, Object?> parameters,
  ) async {
    try {
      final Object? response = await _client.rpc(function, params: parameters);
      final NotificationReadDataRecord? record =
          notificationReadRecordFromPayload(response);
      return record == null
          ? const NotificationDataFailed<NotificationReadDataRecord>(
              NotificationDataFailureKind.invalidPayload,
            )
          : NotificationDataSucceeded<NotificationReadDataRecord>(record);
    } on PostgrestException catch (error) {
      return NotificationDataFailed<NotificationReadDataRecord>(
        notificationDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationDataFailed<NotificationReadDataRecord>(
        NotificationDataFailureKind.unauthenticated,
      );
    } on Object {
      return const NotificationDataFailed<NotificationReadDataRecord>(
        NotificationDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

List<NotificationPreferenceDataRecord>?
notificationPreferenceRecordsFromPayload(Object? payload) {
  if (payload is! List<dynamic>) {
    return null;
  }
  final List<NotificationPreferenceDataRecord> records =
      <NotificationPreferenceDataRecord>[];
  for (final Object? row in payload) {
    final NotificationPreferenceDataRecord? record =
        notificationPreferenceRecordFromPayload(row);
    if (record == null) {
      return null;
    }
    records.add(record);
  }
  return records;
}

NotificationPreferenceDataRecord? notificationPreferenceRecordFromSinglePayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  return notificationPreferenceRecordFromPayload(payload.single);
}

NotificationPreferenceDataRecord? notificationPreferenceRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _exactMap(
    payload,
    _notificationPreferenceKeys,
  );
  final Object? additionalReminderLeads =
      row?['additional_reminder_lead_minutes'];
  if (row == null ||
      row['household_id'] is! String ||
      row['category'] is! String ||
      row['native_push'] is! bool ||
      row['web_push'] is! bool ||
      row['email'] is! bool ||
      row['in_app'] is! bool ||
      row['quiet_start'] != null && row['quiet_start'] is! String ||
      row['quiet_end'] != null && row['quiet_end'] is! String ||
      row['timezone'] is! String ||
      row['reminder_lead_minutes'] is! int ||
      additionalReminderLeads is! List<dynamic> ||
      additionalReminderLeads.any((value) => value is! int) ||
      row['updated_at'] != null && row['updated_at'] is! String ||
      _integer(row['version']) == null ||
      row['is_default'] is! bool) {
    return null;
  }
  return NotificationPreferenceDataRecord(
    householdId: row['household_id']! as String,
    category: row['category']! as String,
    nativePush: row['native_push']! as bool,
    webPush: row['web_push']! as bool,
    email: row['email']! as bool,
    inApp: row['in_app']! as bool,
    quietStart: row['quiet_start'] as String?,
    quietEnd: row['quiet_end'] as String?,
    timezone: row['timezone']! as String,
    reminderLeadMinutes: row['reminder_lead_minutes']! as int,
    additionalReminderLeadMinutes: additionalReminderLeads.cast<int>(),
    updatedAt: row['updated_at'] as String?,
    version: _integer(row['version'])!,
    isDefault: row['is_default']! as bool,
  );
}

NotificationInboxPageDataRecord? notificationInboxPageRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic>) {
    return null;
  }
  if (payload.isEmpty) {
    return NotificationInboxPageDataRecord(
      items: const <NotificationInboxItemDataRecord>[],
      hasMore: false,
      nextBeforeCreatedAt: null,
      nextBeforeId: null,
    );
  }
  final List<NotificationInboxItemDataRecord> items =
      <NotificationInboxItemDataRecord>[];
  bool? hasMore;
  String? nextBeforeCreatedAt;
  String? nextBeforeId;
  for (final Object? payloadRow in payload) {
    final Map<String, Object?>? row = _exactMap(
      payloadRow,
      _notificationInboxKeys,
    );
    final Map<String, Object?>? content = _objectMap(row?['payload']);
    if (row == null ||
        row['inbox_item_id'] is! String ||
        _integer(row['item_version']) == null ||
        row['source_event_id'] is! String ||
        row['household_id'] is! String ||
        row['category'] is! String ||
        row['subject_type'] is! String ||
        row['subject_id'] is! String ||
        row['scheduled_at'] is! String ||
        row['created_at'] is! String ||
        row['read_at'] != null && row['read_at'] is! String ||
        content == null ||
        _integer(row['snooze_count']) == null ||
        _integer(row['snooze_max_minutes']) == null ||
        row['has_more'] is! bool ||
        row['next_before_created_at'] != null &&
            row['next_before_created_at'] is! String ||
        row['next_before_id'] != null && row['next_before_id'] is! String) {
      return null;
    }
    final bool rowHasMore = row['has_more']! as bool;
    final String? rowCreatedAt = row['next_before_created_at'] as String?;
    final String? rowId = row['next_before_id'] as String?;
    hasMore ??= rowHasMore;
    nextBeforeCreatedAt ??= rowCreatedAt;
    nextBeforeId ??= rowId;
    if (hasMore != rowHasMore ||
        nextBeforeCreatedAt != rowCreatedAt ||
        nextBeforeId != rowId) {
      return null;
    }
    items.add(
      NotificationInboxItemDataRecord(
        inboxItemId: row['inbox_item_id']! as String,
        itemVersion: _integer(row['item_version'])!,
        sourceEventId: row['source_event_id']! as String,
        householdId: row['household_id']! as String,
        category: row['category']! as String,
        subjectType: row['subject_type']! as String,
        subjectId: row['subject_id']! as String,
        scheduledAt: row['scheduled_at']! as String,
        createdAt: row['created_at']! as String,
        readAt: row['read_at'] as String?,
        snoozeCount: _integer(row['snooze_count'])!,
        snoozeMaxMinutes: _integer(row['snooze_max_minutes'])!,
        payload: content,
      ),
    );
  }
  return NotificationInboxPageDataRecord(
    items: items,
    hasMore: hasMore!,
    nextBeforeCreatedAt: nextBeforeCreatedAt,
    nextBeforeId: nextBeforeId,
  );
}

NotificationReadDataRecord? notificationReadRecordFromPayload(Object? payload) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _exactMap(
    payload.single,
    _notificationReadKeys,
  );
  final int? markedCount = _integer(row?['marked_count']);
  final int? unreadCount = _integer(row?['unread_count']);
  if (row == null ||
      markedCount == null ||
      unreadCount == null ||
      row['marked_at'] is! String) {
    return null;
  }
  return NotificationReadDataRecord(
    markedCount: markedCount,
    unreadCount: unreadCount,
    markedAt: row['marked_at']! as String,
  );
}

NotificationSnoozeDataRecord? notificationSnoozeRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _exactMap(
    payload.single,
    _notificationSnoozeKeys,
  );
  final int? itemVersion = _integer(row?['item_version']);
  final int? snoozeMinutes = _integer(row?['snooze_minutes']);
  final int? snoozeCount = _integer(row?['snooze_count']);
  final int? unreadCount = _integer(row?['unread_count']);
  if (row == null ||
      row['command_id'] is! String ||
      row['source_event_id'] is! String ||
      row['inbox_item_id'] is! String ||
      itemVersion == null ||
      row['item_version'] is! int ||
      row['snoozed_until'] is! String ||
      snoozeMinutes == null ||
      row['snooze_minutes'] is! int ||
      snoozeCount == null ||
      row['snooze_count'] is! int ||
      unreadCount == null ||
      row['unread_count'] is! int ||
      row['recorded_at'] is! String) {
    return null;
  }
  return NotificationSnoozeDataRecord(
    commandId: row['command_id']! as String,
    sourceEventId: row['source_event_id']! as String,
    inboxItemId: row['inbox_item_id']! as String,
    itemVersion: itemVersion,
    snoozedUntil: row['snoozed_until']! as String,
    snoozeMinutes: snoozeMinutes,
    snoozeCount: snoozeCount,
    unreadCount: unreadCount,
    recordedAt: row['recorded_at']! as String,
  );
}

NotificationPushTargetDataRecord? notificationPushTargetRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) return null;
  final Map<String, Object?>? row = _exactMap(
    payload.single,
    _notificationPushTargetKeys,
  );
  if (row == null ||
      row['delivery_id'] is! String ||
      row['household_id'] is! String ||
      row['category'] is! String ||
      row['subject_type'] is! String ||
      row['subject_id'] is! String ||
      row['inbox_item_id'] != null && row['inbox_item_id'] is! String ||
      row['safe_destination'] is! String) {
    return null;
  }
  return NotificationPushTargetDataRecord(
    deliveryId: row['delivery_id']! as String,
    householdId: row['household_id']! as String,
    category: row['category']! as String,
    subjectType: row['subject_type']! as String,
    subjectId: row['subject_id']! as String,
    inboxItemId: row['inbox_item_id'] as String?,
    safeDestination: row['safe_destination']! as String,
  );
}

NotificationDataFailureKind notificationDataFailureFromProviderCode(
  String? code,
) {
  return switch (code) {
    'KNP02' || 'KPS02' => NotificationDataFailureKind.unauthenticated,
    'KNP01' ||
    'KPS01' ||
    'KNP07' ||
    '22P02' ||
    '22007' ||
    '23514' => NotificationDataFailureKind.invalidInput,
    'KNP03' || '42501' => NotificationDataFailureKind.notFoundOrForbidden,
    'KNP06' => NotificationDataFailureKind.versionConflict,
    'KNS04' => NotificationDataFailureKind.snoozeUnavailable,
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => NotificationDataFailureKind.temporarilyUnavailable,
    _ => NotificationDataFailureKind.unknown,
  };
}

Map<String, Object?>? _exactMap(Object? value, Set<String> keys) {
  final Map<String, Object?>? map = _objectMap(value);
  return map != null &&
          map.keys.toSet().containsAll(keys) &&
          map.length == keys.length
      ? map
      : null;
}

Map<String, Object?>? _objectMap(Object? value) {
  if (value is! Map<dynamic, dynamic>) {
    return null;
  }
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    if (entry.key is! String) {
      return null;
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}

int? _integer(Object? value) {
  return value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : null;
}
