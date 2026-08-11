import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_sync_data_source.dart';

void main() {
  test('maps only the exact content-free user watermark payload', () {
    const String authUserId = '00000000-0000-4000-8000-000000000101';
    final NotificationSyncDataSignal? signal =
        notificationSyncSignalFromPayload(<String, Object?>{
          'auth_user_id': authUserId,
          'generation': 41,
          'changed_at': '2026-08-10T01:02:03Z',
        }, expectedAuthUserId: authUserId.toUpperCase());

    expect(signal?.kind, NotificationSyncDataSignalKind.changed);
    expect(signal?.generation, 41);
  });

  test('rejects content, wrong user, malformed generation, and local time', () {
    const String authUserId = '00000000-0000-4000-8000-000000000101';
    final Map<String, Object?> valid = <String, Object?>{
      'auth_user_id': authUserId,
      'generation': 1,
      'changed_at': '2026-08-10T01:02:03Z',
    };

    for (final Map<String, Object?> invalid in <Map<String, Object?>>[
      <String, Object?>{...valid, 'category': 'chore_due'},
      <String, Object?>{
        ...valid,
        'auth_user_id': '00000000-0000-4000-8000-000000000102',
      },
      <String, Object?>{...valid, 'generation': 0},
      <String, Object?>{...valid, 'generation': '1'},
      <String, Object?>{...valid, 'changed_at': '2026-08-10T10:02:03'},
    ]) {
      expect(
        notificationSyncSignalFromPayload(
          invalid,
          expectedAuthUserId: authUserId,
        ),
        isNull,
      );
    }
  });
}
