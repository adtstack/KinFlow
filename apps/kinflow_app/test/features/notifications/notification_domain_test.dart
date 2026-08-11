import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';

import '../../support/fakes/fake_notification_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;

  test('preference validates category quiet hours and IANA timezone', () {
    final NotificationPreference preference = NotificationPreference.tryCreate(
      householdId: householdId,
      category: NotificationCategory.choreDue,
      nativePush: true,
      webPush: false,
      email: false,
      inApp: true,
      quietStart: '22:00',
      quietEnd: '07:00',
      timezone: 'Asia/Seoul',
      reminderLeadMinutes: 0,
      additionalReminderLeadMinutes: const <int>[],
      updatedAt: null,
      version: 0,
      isDefault: true,
    )!;

    expect(preference.quietHoursEnabled, isTrue);
    expect(
      NotificationCategory.tryParse('chore_assignment'),
      NotificationCategory.choreAssignment,
    );
    expect(
      NotificationCategory.tryParse('calendar_event'),
      NotificationCategory.calendarEvent,
    );
    expect(
      NotificationCategory.calendarEvent.subjectType,
      'calendar_occurrence',
    );
    expect(
      NotificationPreference.tryCreate(
        householdId: householdId,
        category: NotificationCategory.choreDue,
        nativePush: true,
        webPush: false,
        email: false,
        inApp: true,
        quietStart: '22:00',
        quietEnd: '22:00',
        timezone: 'Asia/Seoul',
        reminderLeadMinutes: 0,
        additionalReminderLeadMinutes: const <int>[],
        updatedAt: null,
        version: 0,
        isDefault: true,
      ),
      isNull,
    );
    expect(
      preference.changed(quietHoursEnabled: true, timezone: 'not-a-zone'),
      isNull,
    );
  });

  test('Calendar reminder set accepts one primary and two fixed extras', () {
    final NotificationPreference calendar = NotificationPreference.tryCreate(
      householdId: householdId,
      category: NotificationCategory.calendarEvent,
      nativePush: true,
      webPush: false,
      email: false,
      inApp: true,
      quietStart: null,
      quietEnd: null,
      timezone: 'Asia/Seoul',
      reminderLeadMinutes: 15,
      additionalReminderLeadMinutes: const <int>[30, 60],
      updatedAt: DateTime.utc(2026, 8, 10),
      version: 1,
      isDefault: false,
    )!;

    expect(calendar.reminderLeadMinutes, 15);
    expect(calendar.additionalReminderLeadMinutes, const <int>[30, 60]);
    expect(calendar.reminderLeadMinuteSet, const <int>[15, 30, 60]);
    expect(
      calendar
          .changed(
            quietHoursEnabled: false,
            reminderLeadMinutes: 30,
            additionalReminderLeadMinutes: const <int>[60],
          )
          ?.reminderLeadMinutes,
      30,
    );
    expect(
      calendar.changed(quietHoursEnabled: false, reminderLeadMinutes: 7),
      isNull,
    );
    expect(
      calendar.changed(
        quietHoursEnabled: false,
        additionalReminderLeadMinutes: const <int>[60, 30],
      ),
      isNull,
    );
    expect(
      calendar.changed(
        quietHoursEnabled: false,
        additionalReminderLeadMinutes: const <int>[0, 30, 60],
      ),
      isNull,
    );
    expect(
      NotificationPreference.tryCreate(
        householdId: householdId,
        category: NotificationCategory.choreAssignment,
        nativePush: true,
        webPush: false,
        email: false,
        inApp: true,
        quietStart: null,
        quietEnd: null,
        timezone: 'Asia/Seoul',
        reminderLeadMinutes: 5,
        additionalReminderLeadMinutes: const <int>[],
        updatedAt: DateTime.utc(2026, 8, 10),
        version: 1,
        isDefault: false,
      ),
      isNull,
    );
  });

  test('inbox item accepts only exact content-free routing payload', () {
    final NotificationInboxItemId id = NotificationInboxItemId.tryParse(
      '81000000-0000-4000-8000-000000000001',
    )!;
    final Map<String, Object?> payload = <String, Object?>{
      'householdId': householdId.value,
      'occurrenceId': '83000000-0000-4000-8000-000000000001',
    };
    final NotificationInboxItem? valid = NotificationInboxItem.tryCreate(
      id: id,
      itemVersion: 1,
      sourceEventId: '82000000-0000-4000-8000-000000000001',
      householdId: householdId,
      category: NotificationCategory.choreDue,
      subjectType: 'chore_occurrence',
      subjectId: '83000000-0000-4000-8000-000000000001',
      scheduledAt: DateTime.utc(2026, 8, 9),
      createdAt: DateTime.utc(2026, 8, 8),
      readAt: null,
      snoozeCount: 0,
      snoozeMaxMinutes: 0,
      payload: payload,
    );

    expect(valid, isNotNull);
    expect(
      NotificationInboxItem.tryCreate(
        id: id,
        itemVersion: 1,
        sourceEventId: '82000000-0000-4000-8000-000000000003',
        householdId: householdId,
        category: NotificationCategory.calendarEvent,
        subjectType: 'calendar_occurrence',
        subjectId: '83000000-0000-4000-8000-000000000001',
        scheduledAt: DateTime.utc(2026, 8, 9),
        createdAt: DateTime.utc(2026, 8, 8),
        readAt: null,
        snoozeCount: 0,
        snoozeMaxMinutes: 30,
        payload: payload,
      ),
      isNotNull,
    );
    expect(
      NotificationInboxItem.tryCreate(
        id: id,
        itemVersion: 1,
        sourceEventId: '82000000-0000-4000-8000-000000000003',
        householdId: householdId,
        category: NotificationCategory.calendarEvent,
        subjectType: 'chore_occurrence',
        subjectId: '83000000-0000-4000-8000-000000000001',
        scheduledAt: DateTime.utc(2026, 8, 9),
        createdAt: DateTime.utc(2026, 8, 8),
        readAt: null,
        snoozeCount: 0,
        snoozeMaxMinutes: 30,
        payload: payload,
      ),
      isNull,
    );
    expect(
      NotificationInboxItem.tryCreate(
        id: id,
        itemVersion: 1,
        sourceEventId: '82000000-0000-4000-8000-000000000001',
        householdId: householdId,
        category: NotificationCategory.choreDue,
        subjectType: 'chore_occurrence',
        subjectId: '83000000-0000-4000-8000-000000000001',
        scheduledAt: DateTime.utc(2026, 8, 9),
        createdAt: DateTime.utc(2026, 8, 8),
        readAt: null,
        snoozeCount: 0,
        snoozeMaxMinutes: 0,
        payload: <String, Object?>{...payload, 'title': 'must fail closed'},
      ),
      isNull,
    );
  });

  test('Calendar snooze metadata is bounded and category-safe', () {
    final NotificationInboxItem item = notificationInboxItemFixture(
      id: notificationItemOneUuid,
      category: NotificationCategory.calendarEvent,
      createdAt: DateTime.utc(2026, 8, 10),
      readAt: null,
      snoozeCount: 1,
      snoozeMaxMinutes: 10,
    );

    expect(item.canSnooze, isTrue);
    expect(item.availableSnoozeMinutes, <int>[5, 10]);
    expect(
      notificationInboxItemFixture(
        id: notificationItemOneUuid,
        category: NotificationCategory.calendarEvent,
        createdAt: DateTime.utc(2026, 8, 10),
        readAt: null,
        snoozeCount: 3,
        snoozeMaxMinutes: 0,
      ).canSnooze,
      isFalse,
    );
  });
}
