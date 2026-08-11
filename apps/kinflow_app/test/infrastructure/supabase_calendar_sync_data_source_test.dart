import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/datasources/calendar_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_calendar_sync_data_source.dart';

import '../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test('maps only the exact content-free watermark payload', () {
    final CalendarSyncDataSignal? signal =
        calendarSyncSignalFromPayload(<String, Object?>{
          'household_id': calendarHouseholdUuid,
          'generation': 41,
          'changed_at': '2026-08-08T01:02:03Z',
        }, expectedHouseholdId: calendarHouseholdUuid);

    expect(signal?.kind, CalendarSyncDataSignalKind.changed);
    expect(signal?.generation, 41);
  });

  test('rejects content fields, wrong household, and malformed generation', () {
    final Map<String, Object?> valid = <String, Object?>{
      'household_id': calendarHouseholdUuid,
      'generation': 1,
      'changed_at': '2026-08-08T01:02:03Z',
    };

    expect(
      calendarSyncSignalFromPayload(<String, Object?>{
        ...valid,
        'title': 'must-not-arrive',
      }, expectedHouseholdId: calendarHouseholdUuid),
      isNull,
    );
    expect(
      calendarSyncSignalFromPayload(<String, Object?>{
        ...valid,
        'household_id': '22222222-2222-4222-8222-222222222223',
      }, expectedHouseholdId: calendarHouseholdUuid),
      isNull,
    );
    expect(
      calendarSyncSignalFromPayload(<String, Object?>{
        ...valid,
        'generation': 0,
      }, expectedHouseholdId: calendarHouseholdUuid),
      isNull,
    );
    expect(
      calendarSyncSignalFromPayload(<String, Object?>{
        ...valid,
        'changed_at': 'not-an-instant',
      }, expectedHouseholdId: calendarHouseholdUuid),
      isNull,
    );
  });
}
