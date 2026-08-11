import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _notificationUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final RegExp _quietTimePattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
final RegExp _timezonePattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9._+-]*(?:/[A-Za-z0-9][A-Za-z0-9._+-]*)+$',
);

enum NotificationCategory {
  choreDue('chore_due'),
  choreAssignment('chore_assignment'),
  calendarEvent('calendar_event');

  const NotificationCategory(this.wireValue);

  final String wireValue;

  String get subjectType => switch (this) {
    NotificationCategory.choreDue ||
    NotificationCategory.choreAssignment => 'chore_occurrence',
    NotificationCategory.calendarEvent => 'calendar_occurrence',
  };

  static NotificationCategory? tryParse(String value) {
    for (final NotificationCategory category in values) {
      if (category.wireValue == value) {
        return category;
      }
    }
    return null;
  }
}

final class NotificationInboxItemId {
  const NotificationInboxItemId._(this.value);

  final String value;

  static NotificationInboxItemId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _notificationUuidPattern.hasMatch(normalized)
        ? NotificationInboxItemId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationInboxItemId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class NotificationSnoozeCommandId {
  const NotificationSnoozeCommandId._(this.value);

  final String value;

  static NotificationSnoozeCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _notificationUuidPattern.hasMatch(normalized)
        ? NotificationSnoozeCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSnoozeCommandId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class NotificationInboxCursor {
  const NotificationInboxCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final NotificationInboxItemId id;
}

final class NotificationPreference {
  const NotificationPreference({
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
    required this.additionalReminderLeadMinutes,
    required this.updatedAt,
    required this.version,
    required this.isDefault,
  });

  static const List<int> calendarReminderLeadMinuteOptions = <int>[
    0,
    5,
    10,
    15,
    30,
    60,
  ];

  final HouseholdId householdId;
  final NotificationCategory category;
  final bool nativePush;
  final bool webPush;
  final bool email;
  final bool inApp;
  final String? quietStart;
  final String? quietEnd;
  final String timezone;
  final int reminderLeadMinutes;
  final List<int> additionalReminderLeadMinutes;
  final DateTime? updatedAt;
  final int version;
  final bool isDefault;

  bool get quietHoursEnabled => quietStart != null;

  List<int> get reminderLeadMinuteSet => List<int>.unmodifiable(<int>[
    reminderLeadMinutes,
    ...additionalReminderLeadMinutes,
  ]);

  static NotificationPreference? tryCreate({
    required HouseholdId householdId,
    required NotificationCategory category,
    required bool nativePush,
    required bool webPush,
    required bool email,
    required bool inApp,
    required String? quietStart,
    required String? quietEnd,
    required String timezone,
    required int reminderLeadMinutes,
    required List<int> additionalReminderLeadMinutes,
    required DateTime? updatedAt,
    required int version,
    required bool isDefault,
  }) {
    final String normalizedTimezone = timezone.trim();
    final bool validTimezone =
        normalizedTimezone == 'UTC' ||
        _timezonePattern.hasMatch(normalizedTimezone);
    final bool validQuiet =
        quietStart == null && quietEnd == null ||
        quietStart != null &&
            quietEnd != null &&
            quietStart != quietEnd &&
            _quietTimePattern.hasMatch(quietStart) &&
            _quietTimePattern.hasMatch(quietEnd);
    final bool validReminderLead = switch (category) {
      NotificationCategory.calendarEvent =>
        calendarReminderLeadMinuteOptions.contains(reminderLeadMinutes),
      NotificationCategory.choreDue ||
      NotificationCategory.choreAssignment => reminderLeadMinutes == 0,
    };
    final bool validAdditionalReminderLeads =
        additionalReminderLeadMinutes.length <= 2 &&
        (category == NotificationCategory.calendarEvent ||
            additionalReminderLeadMinutes.isEmpty) &&
        additionalReminderLeadMinutes.every(
          calendarReminderLeadMinuteOptions.contains,
        ) &&
        !additionalReminderLeadMinutes.contains(reminderLeadMinutes) &&
        _strictlyIncreasing(additionalReminderLeadMinutes);
    if (!validTimezone ||
        !validQuiet ||
        !validReminderLead ||
        !validAdditionalReminderLeads ||
        version < 0 ||
        isDefault != (version == 0) ||
        (version == 0 && updatedAt != null) ||
        (version > 0 && updatedAt == null)) {
      return null;
    }
    return NotificationPreference(
      householdId: householdId,
      category: category,
      nativePush: nativePush,
      webPush: webPush,
      email: email,
      inApp: inApp,
      quietStart: quietStart,
      quietEnd: quietEnd,
      timezone: normalizedTimezone,
      reminderLeadMinutes: reminderLeadMinutes,
      additionalReminderLeadMinutes: List<int>.unmodifiable(
        additionalReminderLeadMinutes,
      ),
      updatedAt: updatedAt?.toUtc(),
      version: version,
      isDefault: isDefault,
    );
  }

  NotificationPreference? changed({
    bool? nativePush,
    bool? webPush,
    bool? email,
    bool? inApp,
    String? quietStart,
    String? quietEnd,
    required bool quietHoursEnabled,
    String? timezone,
    int? reminderLeadMinutes,
    List<int>? additionalReminderLeadMinutes,
  }) {
    return tryCreate(
      householdId: householdId,
      category: category,
      nativePush: nativePush ?? this.nativePush,
      webPush: webPush ?? this.webPush,
      email: email ?? this.email,
      inApp: inApp ?? this.inApp,
      quietStart: quietHoursEnabled ? quietStart ?? this.quietStart : null,
      quietEnd: quietHoursEnabled ? quietEnd ?? this.quietEnd : null,
      timezone: timezone ?? this.timezone,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      additionalReminderLeadMinutes:
          additionalReminderLeadMinutes ?? this.additionalReminderLeadMinutes,
      updatedAt: updatedAt,
      version: version,
      isDefault: isDefault,
    );
  }

  static bool _strictlyIncreasing(List<int> values) {
    for (var index = 1; index < values.length; index += 1) {
      if (values[index - 1] >= values[index]) {
        return false;
      }
    }
    return true;
  }
}

final class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.itemVersion,
    required this.sourceEventId,
    required this.householdId,
    required this.category,
    required this.subjectId,
    required this.scheduledAt,
    required this.createdAt,
    required this.readAt,
    required this.snoozeCount,
    required this.snoozeMaxMinutes,
  });

  static const List<int> snoozeMinuteOptions = <int>[5, 10, 30];
  static const int maximumSnoozeCount = 3;

  final NotificationInboxItemId id;
  final int itemVersion;
  final String sourceEventId;
  final HouseholdId householdId;
  final NotificationCategory category;
  final String subjectId;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final DateTime? readAt;
  final int snoozeCount;
  final int snoozeMaxMinutes;

  bool get isRead => readAt != null;

  bool get canSnooze =>
      category == NotificationCategory.calendarEvent &&
      snoozeCount < maximumSnoozeCount &&
      snoozeMaxMinutes > 0;

  List<int> get availableSnoozeMinutes => canSnooze
      ? List<int>.unmodifiable(
          snoozeMinuteOptions.where((minutes) => minutes <= snoozeMaxMinutes),
        )
      : const <int>[];

  static NotificationInboxItem? tryCreate({
    required NotificationInboxItemId id,
    required int itemVersion,
    required String sourceEventId,
    required HouseholdId householdId,
    required NotificationCategory category,
    required String subjectType,
    required String subjectId,
    required DateTime scheduledAt,
    required DateTime createdAt,
    required DateTime? readAt,
    required int snoozeCount,
    required int snoozeMaxMinutes,
    required Map<String, Object?> payload,
  }) {
    final String normalizedSourceId = sourceEventId.trim().toLowerCase();
    final String normalizedSubjectId = subjectId.trim().toLowerCase();
    if (itemVersion < 1 ||
        !_notificationUuidPattern.hasMatch(normalizedSourceId) ||
        subjectType != category.subjectType ||
        !_notificationUuidPattern.hasMatch(normalizedSubjectId) ||
        payload.length != 2 ||
        payload['householdId'] != householdId.value ||
        payload['occurrenceId'] != normalizedSubjectId ||
        snoozeCount < 0 ||
        snoozeCount > maximumSnoozeCount ||
        !<int>[0, ...snoozeMinuteOptions].contains(snoozeMaxMinutes) ||
        category != NotificationCategory.calendarEvent &&
            (snoozeCount != 0 || snoozeMaxMinutes != 0) ||
        snoozeCount >= maximumSnoozeCount && snoozeMaxMinutes != 0 ||
        readAt != null && readAt.isBefore(createdAt)) {
      return null;
    }
    return NotificationInboxItem(
      id: id,
      itemVersion: itemVersion,
      sourceEventId: normalizedSourceId,
      householdId: householdId,
      category: category,
      subjectId: normalizedSubjectId,
      scheduledAt: scheduledAt.toUtc(),
      createdAt: createdAt.toUtc(),
      readAt: readAt?.toUtc(),
      snoozeCount: snoozeCount,
      snoozeMaxMinutes: snoozeMaxMinutes,
    );
  }

  NotificationInboxItem markRead(DateTime at) => NotificationInboxItem(
    id: id,
    itemVersion: itemVersion + 1,
    sourceEventId: sourceEventId,
    householdId: householdId,
    category: category,
    subjectId: subjectId,
    scheduledAt: scheduledAt,
    createdAt: createdAt,
    readAt: at.toUtc(),
    snoozeCount: snoozeCount,
    snoozeMaxMinutes: snoozeMaxMinutes,
  );
}

final class NotificationSnoozeReceipt {
  const NotificationSnoozeReceipt({
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

  final NotificationSnoozeCommandId commandId;
  final String sourceEventId;
  final NotificationInboxItemId inboxItemId;
  final int itemVersion;
  final DateTime snoozedUntil;
  final int snoozeMinutes;
  final int snoozeCount;
  final int unreadCount;
  final DateTime recordedAt;

  static NotificationSnoozeReceipt? tryCreate({
    required NotificationSnoozeCommandId commandId,
    required String sourceEventId,
    required NotificationInboxItemId inboxItemId,
    required int itemVersion,
    required DateTime snoozedUntil,
    required int snoozeMinutes,
    required int snoozeCount,
    required int unreadCount,
    required DateTime recordedAt,
  }) {
    final String normalizedSourceId = sourceEventId.trim().toLowerCase();
    final DateTime normalizedUntil = snoozedUntil.toUtc();
    final DateTime normalizedRecordedAt = recordedAt.toUtc();
    if (!_notificationUuidPattern.hasMatch(normalizedSourceId) ||
        itemVersion < 2 ||
        !NotificationInboxItem.snoozeMinuteOptions.contains(snoozeMinutes) ||
        snoozeCount < 1 ||
        snoozeCount > NotificationInboxItem.maximumSnoozeCount ||
        unreadCount < 0 ||
        normalizedUntil !=
            normalizedRecordedAt.add(Duration(minutes: snoozeMinutes))) {
      return null;
    }
    return NotificationSnoozeReceipt(
      commandId: commandId,
      sourceEventId: normalizedSourceId,
      inboxItemId: inboxItemId,
      itemVersion: itemVersion,
      snoozedUntil: normalizedUntil,
      snoozeMinutes: snoozeMinutes,
      snoozeCount: snoozeCount,
      unreadCount: unreadCount,
      recordedAt: normalizedRecordedAt,
    );
  }
}

final class NotificationInboxPage {
  NotificationInboxPage({
    required List<NotificationInboxItem> items,
    required this.hasMore,
    required this.nextCursor,
  }) : items = List<NotificationInboxItem>.unmodifiable(items);

  final List<NotificationInboxItem> items;
  final bool hasMore;
  final NotificationInboxCursor? nextCursor;
}

final class NotificationSnapshot {
  NotificationSnapshot({
    required this.householdId,
    required List<NotificationPreference> preferences,
    required this.inbox,
    required this.unreadCount,
  }) : preferences = List<NotificationPreference>.unmodifiable(preferences);

  final HouseholdId householdId;
  final List<NotificationPreference> preferences;
  final NotificationInboxPage inbox;
  final int unreadCount;

  NotificationPreference? preference(NotificationCategory category) {
    for (final NotificationPreference preference in preferences) {
      if (preference.category == category) {
        return preference;
      }
    }
    return null;
  }
}
