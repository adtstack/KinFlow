enum ProfilePreferencesDataFailureKind {
  unauthenticated,
  invalidInput,
  unavailable,
  forbidden,
  profileConflict,
  householdConflict,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class ProfilePreferencesDataRecord {
  const ProfilePreferencesDataRecord({
    required this.profileId,
    required this.displayName,
    required this.avatarKey,
    required this.locale,
    required this.profileTimezone,
    required this.profileVersion,
    required this.householdId,
    required this.householdName,
    required this.householdTimezone,
    required this.householdVersion,
    required this.householdRole,
    required this.canManageHouseholdTimezone,
  });

  final String profileId;
  final String displayName;
  final String? avatarKey;
  final String locale;
  final String profileTimezone;
  final int profileVersion;
  final String householdId;
  final String householdName;
  final String householdTimezone;
  final int householdVersion;
  final String householdRole;
  final bool canManageHouseholdTimezone;
}

abstract interface class ProfilePreferencesDataSource {
  Future<ProfilePreferencesDataResult> load();

  Future<ProfilePreferencesDataResult> update({
    required String displayName,
    required String? avatarKey,
    required String locale,
    required String profileTimezone,
    required int expectedProfileVersion,
    required String? householdTimezone,
    required int? expectedHouseholdVersion,
  });
}

sealed class ProfilePreferencesDataResult {
  const ProfilePreferencesDataResult();
}

final class ProfilePreferencesDataSucceeded
    extends ProfilePreferencesDataResult {
  const ProfilePreferencesDataSucceeded(this.record);

  final ProfilePreferencesDataRecord record;
}

final class ProfilePreferencesDataFailed extends ProfilePreferencesDataResult {
  const ProfilePreferencesDataFailed(this.kind);

  final ProfilePreferencesDataFailureKind kind;
}
