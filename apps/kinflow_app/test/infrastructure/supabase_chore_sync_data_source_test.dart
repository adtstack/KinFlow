import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_sync_data_source.dart';

import '../support/fakes/fake_household_dependencies.dart';

void main() {
  test('maps only the exact content-free watermark payload', () {
    final String householdId = activeHouseholdFixture().householdId.value;
    final ChoreSyncDataSignal? signal =
        choreSyncSignalFromPayload(<String, Object?>{
          'household_id': householdId,
          'generation': 41,
          'changed_at': '2026-08-10T01:02:03Z',
        }, expectedHouseholdId: householdId.toUpperCase());

    expect(signal?.kind, ChoreSyncDataSignalKind.changed);
    expect(signal?.generation, 41);
  });

  test(
    'rejects content, wrong scope, malformed generation, and local time',
    () {
      final String householdId = activeHouseholdFixture().householdId.value;
      final Map<String, Object?> valid = <String, Object?>{
        'household_id': householdId,
        'generation': 1,
        'changed_at': '2026-08-10T01:02:03Z',
      };

      for (final Map<String, Object?> invalid in <Map<String, Object?>>[
        <String, Object?>{...valid, 'title': 'must-not-arrive'},
        <String, Object?>{
          ...valid,
          'household_id': '22222222-2222-4222-8222-222222222223',
        },
        <String, Object?>{...valid, 'generation': 0},
        <String, Object?>{...valid, 'generation': '1'},
        <String, Object?>{...valid, 'changed_at': '2026-08-10T10:02:03'},
      ]) {
        expect(
          choreSyncSignalFromPayload(invalid, expectedHouseholdId: householdId),
          isNull,
        );
      }
    },
  );
}
