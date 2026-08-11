import 'package:kinflow_app/features/settings/data/datasources/profile_preferences_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _profilePreferencesKeys = <String>{
  'profile_id',
  'display_name',
  'avatar_key',
  'locale',
  'profile_timezone',
  'profile_version',
  'household_id',
  'household_name',
  'household_timezone',
  'household_version',
  'household_role',
  'can_manage_household_timezone',
};

final class SupabaseProfilePreferencesDataSource
    implements ProfilePreferencesDataSource {
  const SupabaseProfilePreferencesDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfilePreferencesDataResult> load() async {
    try {
      return _parse(await _client.rpc('get_profile_preferences'));
    } on PostgrestException catch (error) {
      return ProfilePreferencesDataFailed(
        profilePreferencesDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ProfilePreferencesDataFailed(
        ProfilePreferencesDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ProfilePreferencesDataFailed(
        ProfilePreferencesDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<ProfilePreferencesDataResult> update({
    required String displayName,
    required String? avatarKey,
    required String locale,
    required String profileTimezone,
    required int expectedProfileVersion,
    required String? householdTimezone,
    required int? expectedHouseholdVersion,
  }) async {
    try {
      return _parse(
        await _client.rpc(
          'update_profile_preferences',
          params: <String, Object?>{
            'p_display_name': displayName,
            'p_avatar_key': avatarKey,
            'p_locale': locale,
            'p_profile_timezone': profileTimezone,
            'p_expected_profile_version': expectedProfileVersion,
            'p_household_timezone': householdTimezone,
            'p_expected_household_version': expectedHouseholdVersion,
          },
        ),
      );
    } on PostgrestException catch (error) {
      return ProfilePreferencesDataFailed(
        profilePreferencesDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const ProfilePreferencesDataFailed(
        ProfilePreferencesDataFailureKind.unauthenticated,
      );
    } on Object {
      return const ProfilePreferencesDataFailed(
        ProfilePreferencesDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  ProfilePreferencesDataResult _parse(Object? payload) {
    if (payload is! List<dynamic> || payload.length != 1) {
      return const ProfilePreferencesDataFailed(
        ProfilePreferencesDataFailureKind.invalidPayload,
      );
    }
    final ProfilePreferencesDataRecord? record =
        profilePreferencesRecordFromPayload(payload.single);
    return record == null
        ? const ProfilePreferencesDataFailed(
            ProfilePreferencesDataFailureKind.invalidPayload,
          )
        : ProfilePreferencesDataSucceeded(record);
  }
}

ProfilePreferencesDataRecord? profilePreferencesRecordFromPayload(
  Object? payload,
) {
  if (payload is! Map<String, dynamic> ||
      payload.keys.toSet().difference(_profilePreferencesKeys).isNotEmpty ||
      _profilePreferencesKeys.difference(payload.keys.toSet()).isNotEmpty) {
    return null;
  }
  final Object? profileId = payload['profile_id'];
  final Object? displayName = payload['display_name'];
  final Object? avatarKey = payload['avatar_key'];
  final Object? locale = payload['locale'];
  final Object? profileTimezone = payload['profile_timezone'];
  final Object? profileVersion = payload['profile_version'];
  final Object? householdId = payload['household_id'];
  final Object? householdName = payload['household_name'];
  final Object? householdTimezone = payload['household_timezone'];
  final Object? householdVersion = payload['household_version'];
  final Object? householdRole = payload['household_role'];
  final Object? canManage = payload['can_manage_household_timezone'];
  if (profileId is! String ||
      displayName is! String ||
      (avatarKey != null && avatarKey is! String) ||
      locale is! String ||
      profileTimezone is! String ||
      profileVersion is! int ||
      householdId is! String ||
      householdName is! String ||
      householdTimezone is! String ||
      householdVersion is! int ||
      householdRole is! String ||
      canManage is! bool) {
    return null;
  }
  return ProfilePreferencesDataRecord(
    profileId: profileId,
    displayName: displayName,
    avatarKey: avatarKey as String?,
    locale: locale,
    profileTimezone: profileTimezone,
    profileVersion: profileVersion,
    householdId: householdId,
    householdName: householdName,
    householdTimezone: householdTimezone,
    householdVersion: householdVersion,
    householdRole: householdRole,
    canManageHouseholdTimezone: canManage,
  );
}

ProfilePreferencesDataFailureKind profilePreferencesDataFailureFromProviderCode(
  String? code,
) {
  return switch (code) {
    'KFS01' || 'PGRST301' => ProfilePreferencesDataFailureKind.unauthenticated,
    'KFS02' => ProfilePreferencesDataFailureKind.invalidInput,
    'KFS03' => ProfilePreferencesDataFailureKind.unavailable,
    'KFS04' => ProfilePreferencesDataFailureKind.forbidden,
    'KFS05' => ProfilePreferencesDataFailureKind.profileConflict,
    'KFS06' => ProfilePreferencesDataFailureKind.householdConflict,
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => ProfilePreferencesDataFailureKind.temporarilyUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      ProfilePreferencesDataFailureKind.temporarilyUnavailable,
    _ => ProfilePreferencesDataFailureKind.unknown,
  };
}
