enum NotificationDataFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  versionConflict,
  snoozeUnavailable,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class NotificationPreferenceDataRecord {
  NotificationPreferenceDataRecord({
    required this.householdId,
    required this.category,
    required this.nativePush,
    required this.webPush,
    required this.email,
    required this.inApp,
    required this.quietStart,
    required this.quietEnd,
    required this.timezone,
    required this.reminderLeadMinutes,
    required List<int> additionalReminderLeadMinutes,
    required this.updatedAt,
    required this.version,
    required this.isDefault,
  }) : additionalReminderLeadMinutes = List<int>.unmodifiable(
         additionalReminderLeadMinutes,
       );

  final String householdId;
  final String category;
  final bool nativePush;
  final bool webPush;
  final bool email;
  final bool inApp;
  final String? quietStart;
  final String? quietEnd;
  final String timezone;
  final int reminderLeadMinutes;
  final List<int> additionalReminderLeadMinutes;
  final String? updatedAt;
  final int version;
  final bool isDefault;
}

final class NotificationInboxItemDataRecord {
  NotificationInboxItemDataRecord({
    required this.inboxItemId,
    required this.itemVersion,
    required this.sourceEventId,
    required this.householdId,
    required this.category,
    required this.subjectType,
    required this.subjectId,
    required this.scheduledAt,
    required this.createdAt,
    required this.readAt,
    required this.snoozeCount,
    required this.snoozeMaxMinutes,
    required Map<String, Object?> payload,
  }) : payload = Map<String, Object?>.unmodifiable(payload);

  final String inboxItemId;
  final int itemVersion;
  final String sourceEventId;
  final String householdId;
  final String category;
  final String subjectType;
  final String subjectId;
  final String scheduledAt;
  final String createdAt;
  final String? readAt;
  final int snoozeCount;
  final int snoozeMaxMinutes;
  final Map<String, Object?> payload;
}

final class NotificationInboxPageDataRecord {
  NotificationInboxPageDataRecord({
    required List<NotificationInboxItemDataRecord> items,
    required this.hasMore,
    required this.nextBeforeCreatedAt,
    required this.nextBeforeId,
  }) : items = List<NotificationInboxItemDataRecord>.unmodifiable(items);

  final List<NotificationInboxItemDataRecord> items;
  final bool hasMore;
  final String? nextBeforeCreatedAt;
  final String? nextBeforeId;
}

final class NotificationReadDataRecord {
  const NotificationReadDataRecord({
    required this.markedCount,
    required this.unreadCount,
    required this.markedAt,
  });

  final int markedCount;
  final int unreadCount;
  final String markedAt;
}

final class NotificationSnoozeDataRecord {
  const NotificationSnoozeDataRecord({
    required this.commandId,
    required this.sourceEventId,
    required this.inboxItemId,
    required this.itemVersion,
    required this.snoozedUntil,
    required this.snoozeMinutes,
    required this.snoozeCount,
    required this.unreadCount,
    required this.recordedAt,
  });

  final String commandId;
  final String sourceEventId;
  final String inboxItemId;
  final int itemVersion;
  final String snoozedUntil;
  final int snoozeMinutes;
  final int snoozeCount;
  final int unreadCount;
  final String recordedAt;
}

final class NotificationPushTargetDataRecord {
  const NotificationPushTargetDataRecord({
    required this.deliveryId,
    required this.householdId,
    required this.category,
    required this.subjectType,
    required this.subjectId,
    required this.inboxItemId,
    required this.safeDestination,
  });

  final String deliveryId;
  final String householdId;
  final String category;
  final String subjectType;
  final String subjectId;
  final String? inboxItemId;
  final String safeDestination;
}

abstract interface class NotificationDataSource {
  Future<NotificationDataResult<List<NotificationPreferenceDataRecord>>>
  loadPreferences({required String householdId});

  Future<NotificationDataResult<NotificationInboxPageDataRecord>> loadInbox({
    required String householdId,
    required int limit,
    required String? beforeCreatedAt,
    required String? beforeId,
  });

  Future<NotificationDataResult<int>> loadUnreadCount({
    required String householdId,
  });

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
  });

  Future<NotificationDataResult<NotificationReadDataRecord>> markRead({
    required String householdId,
    required List<String> itemIds,
  });

  Future<NotificationDataResult<NotificationReadDataRecord>> markAllRead({
    required String householdId,
  });

  Future<NotificationDataResult<NotificationSnoozeDataRecord>> snoozeCalendar({
    required String householdId,
    required String inboxItemId,
    required int snoozeMinutes,
    required String commandId,
    required int expectedItemVersion,
  });

  Future<NotificationDataResult<NotificationPushTargetDataRecord?>>
  resolvePushTarget({
    required String deliveryId,
    required String householdId,
    required String subjectId,
  });
}

sealed class NotificationDataResult<T> {
  const NotificationDataResult();
}

final class NotificationDataSucceeded<T> extends NotificationDataResult<T> {
  const NotificationDataSucceeded(this.value);

  final T value;
}

final class NotificationDataFailed<T> extends NotificationDataResult<T> {
  const NotificationDataFailed(this.kind);

  final NotificationDataFailureKind kind;
}
