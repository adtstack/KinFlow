import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/profile_preferences_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_profile_preferences_data_source.dart';

void main() {
  test('parser accepts the exact minimal settings projection', () {
    final ProfilePreferencesDataRecord? record =
        profilePreferencesRecordFromPayload(_payload());

    expect(record?.displayName, 'Adult A');
    expect(record?.avatarKey, 'preset:sun');
    expect(record?.canManageHouseholdTimezone, isTrue);
  });

  test('parser rejects extra identity or provider fields', () {
    expect(
      profilePreferencesRecordFromPayload(<String, Object?>{
        ..._payload(),
        'email': 'private@example.invalid',
      }),
      isNull,
    );
    expect(
      profilePreferencesRecordFromPayload(<String, Object?>{
        ..._payload(),
        'auth_user_id': '73000000-0000-4000-8000-000000000001',
      }),
      isNull,
    );
  });

  test('parser rejects missing and mistyped version fields', () {
    final Map<String, Object?> missing = _payload()..remove('profile_version');
    expect(profilePreferencesRecordFromPayload(missing), isNull);
    expect(
      profilePreferencesRecordFromPayload(<String, Object?>{
        ..._payload(),
        'household_version': 4.0,
      }),
      isNull,
    );
  });

  test('stable SQLSTATE maps without reflecting server messages', () {
    expect(
      profilePreferencesDataFailureFromProviderCode('KFS04'),
      ProfilePreferencesDataFailureKind.forbidden,
    );
    expect(
      profilePreferencesDataFailureFromProviderCode('KFS05'),
      ProfilePreferencesDataFailureKind.profileConflict,
    );
    expect(
      profilePreferencesDataFailureFromProviderCode('KFS06'),
      ProfilePreferencesDataFailureKind.householdConflict,
    );
    expect(
      profilePreferencesDataFailureFromProviderCode('PGRST002'),
      ProfilePreferencesDataFailureKind.temporarilyUnavailable,
    );
  });
}

Map<String, Object?> _payload() {
  return <String, Object?>{
    'profile_id': '71000000-0000-4000-8000-000000000001',
    'display_name': 'Adult A',
    'avatar_key': 'preset:sun',
    'locale': 'en',
    'profile_timezone': 'Asia/Seoul',
    'profile_version': 1,
    'household_id': '72000000-0000-4000-8000-000000000001',
    'household_name': 'Kim family',
    'household_timezone': 'Asia/Seoul',
    'household_version': 4,
    'household_role': 'owner',
    'can_manage_household_timezone': true,
  };
}
