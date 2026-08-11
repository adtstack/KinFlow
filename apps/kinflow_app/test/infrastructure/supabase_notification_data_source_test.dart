import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_data_source.dart';

void main() {
  const String householdId = '22222222-2222-4222-8222-222222222222';
  const String itemId = '81000000-0000-4000-8000-000000000001';
  const String sourceId = '82000000-0000-4000-8000-000000000001';
  const String subjectId = '83000000-0000-4000-8000-000000000001';

  test('preference parser requires the exact server shape', () {
    final Map<String, Object?> payload = <String, Object?>{
      'household_id': householdId,
      'category': 'chore_due',
      'native_push': true,
      'web_push': false,
      'email': false,
      'in_app': true,
      'quiet_start': '22:00:00',
      'quiet_end': '07:00:00',
      'timezone': 'Asia/Seoul',
      'reminder_lead_minutes': 0,
      'additional_reminder_lead_minutes': <int>[],
      'updated_at': null,
      'version': 0,
      'is_default': true,
    };

    expect(notificationPreferenceRecordFromPayload(payload), isNotNull);
    expect(
      notificationPreferenceRecordFromPayload(<String, Object?>{
        ...payload,
        'title': 'private content',
      }),
      isNull,
    );
    expect(
      notificationPreferenceRecordsFromPayload(<Object?>[payload, 'bad']),
      isNull,
    );
    expect(
      notificationPreferenceRecordFromPayload(<String, Object?>{
        ...payload,
        'reminder_lead_minutes': 15.0,
      }),
      isNull,
    );
    final Map<String, Object?> missingLead = <String, Object?>{...payload}
      ..remove('reminder_lead_minutes');
    expect(notificationPreferenceRecordFromPayload(missingLead), isNull);
    expect(
      notificationPreferenceRecordFromPayload(<String, Object?>{
        ...payload,
        'additional_reminder_lead_minutes': <Object?>[30, 60.0],
      }),
      isNull,
    );
    final Map<String, Object?> missingAdditional = <String, Object?>{...payload}
      ..remove('additional_reminder_lead_minutes');
    expect(notificationPreferenceRecordFromPayload(missingAdditional), isNull);
  });

  test(
    'inbox page parser validates repeated cursor metadata and payload type',
    () {
      final Map<String, Object?> row = <String, Object?>{
        'inbox_item_id': itemId,
        'item_version': 1,
        'source_event_id': sourceId,
        'household_id': householdId,
        'category': 'chore_due',
        'subject_type': 'chore_occurrence',
        'subject_id': subjectId,
        'scheduled_at': '2026-08-09T00:00:00+00:00',
        'created_at': '2026-08-08T00:00:00+00:00',
        'read_at': null,
        'payload': <String, Object?>{
          'householdId': householdId,
          'occurrenceId': subjectId,
        },
        'snooze_count': 0,
        'snooze_max_minutes': 0,
        'has_more': true,
        'next_before_created_at': '2026-08-08T00:00:00+00:00',
        'next_before_id': itemId,
      };

      final NotificationInboxPageDataRecord? parsed =
          notificationInboxPageRecordFromPayload(<Object?>[row]);
      expect(parsed?.items.single.inboxItemId, itemId);
      expect(parsed?.hasMore, isTrue);
      expect(
        notificationInboxPageRecordFromPayload(<Object?>[
          row,
          <String, Object?>{...row, 'has_more': false},
        ]),
        isNull,
      );
      expect(
        notificationInboxPageRecordFromPayload(<Object?>[
          <String, Object?>{...row, 'payload': 'not-an-object'},
        ]),
        isNull,
      );
      expect(
        notificationInboxPageRecordFromPayload(const <Object?>[])?.hasMore,
        isFalse,
      );
    },
  );

  test('read parser and provider code mapping fail closed', () {
    final NotificationReadDataRecord? read = notificationReadRecordFromPayload(
      <Object?>[
        <String, Object?>{
          'marked_count': 1,
          'unread_count': 2,
          'marked_at': '2026-08-08T00:00:00+00:00',
        },
      ],
    );
    expect(read?.unreadCount, 2);
    expect(
      notificationDataFailureFromProviderCode('KNP02'),
      NotificationDataFailureKind.unauthenticated,
    );
    expect(
      notificationDataFailureFromProviderCode('KNP06'),
      NotificationDataFailureKind.versionConflict,
    );
    expect(
      notificationDataFailureFromProviderCode('KNS04'),
      NotificationDataFailureKind.snoozeUnavailable,
    );
    expect(
      notificationDataFailureFromProviderCode('not-known'),
      NotificationDataFailureKind.unknown,
    );
  });

  test('snooze receipt parser requires one exact nine-field row', () {
    final Map<String, Object?> row = <String, Object?>{
      'command_id': '85000000-0000-4000-8000-000000000001',
      'source_event_id': sourceId,
      'inbox_item_id': itemId,
      'item_version': 2,
      'snoozed_until': '2026-08-08T00:10:00+00:00',
      'snooze_minutes': 10,
      'snooze_count': 1,
      'unread_count': 0,
      'recorded_at': '2026-08-08T00:00:00+00:00',
    };

    expect(
      notificationSnoozeRecordFromPayload(<Object?>[row])?.snoozeMinutes,
      10,
    );
    expect(
      notificationSnoozeRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'title': 'private content'},
      ]),
      isNull,
    );
    expect(
      notificationSnoozeRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'snooze_minutes': 10.0},
      ]),
      isNull,
    );
  });

  test('push target parser accepts only one exact safe destination row', () {
    final Map<String, Object?> row = <String, Object?>{
      'delivery_id': '84000000-0000-4000-8000-000000000001',
      'household_id': householdId,
      'category': 'chore_due',
      'subject_type': 'chore_occurrence',
      'subject_id': subjectId,
      'inbox_item_id': itemId,
      'safe_destination': 'today',
    };

    expect(
      notificationPushTargetRecordFromPayload(<Object?>[row])?.safeDestination,
      'today',
    );
    expect(
      notificationPushTargetRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'path': '/today'},
      ]),
      isNull,
    );
    expect(
      notificationPushTargetRecordFromPayload(<Object?>[row, row]),
      isNull,
    );
    expect(
      notificationDataFailureFromProviderCode('KPS02'),
      NotificationDataFailureKind.unauthenticated,
    );
  });
}
