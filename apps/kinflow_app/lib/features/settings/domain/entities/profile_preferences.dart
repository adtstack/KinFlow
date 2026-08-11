import 'dart:convert';

final RegExp _profileUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _profileControlCharacterPattern = RegExp(r'[\x00-\x1f\x7f]');
final RegExp _profileTimezonePattern = RegExp(
  r'^[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+$',
);

enum ProfileAvatarPreset {
  sun('preset:sun'),
  heart('preset:heart'),
  leaf('preset:leaf'),
  star('preset:star');

  const ProfileAvatarPreset(this.key);

  final String key;

  static ProfileAvatarPreset? fromKey(String? key) {
    if (key == null) return null;
    for (final ProfileAvatarPreset preset in values) {
      if (preset.key == key) return preset;
    }
    return null;
  }
}

enum ProfileLanguage {
  english('en'),
  korean('ko');

  const ProfileLanguage(this.code);

  final String code;

  static ProfileLanguage? fromCode(String code) {
    for (final ProfileLanguage language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

enum ProfileHouseholdRole { owner, admin, member }

final class ProfilePreferences {
  const ProfilePreferences._({
    required this.profileId,
    required this.displayName,
    required this.avatar,
    required this.language,
    required this.profileTimezone,
    required this.profileVersion,
    required this.householdId,
    required this.householdName,
    required this.householdTimezone,
    required this.householdVersion,
    required this.householdRole,
  });

  final String profileId;
  final String displayName;
  final ProfileAvatarPreset? avatar;
  final ProfileLanguage language;
  final String profileTimezone;
  final int profileVersion;
  final String householdId;
  final String householdName;
  final String householdTimezone;
  final int householdVersion;
  final ProfileHouseholdRole householdRole;

  bool get canManageHouseholdTimezone =>
      householdRole == ProfileHouseholdRole.owner ||
      householdRole == ProfileHouseholdRole.admin;

  String get snapshotFingerprint => jsonEncode(<Object?>[
    profileId,
    displayName,
    avatar?.key,
    language.code,
    profileTimezone,
    profileVersion,
    householdId,
    householdName,
    householdTimezone,
    householdVersion,
    householdRole.name,
  ]);

  static ProfilePreferences? tryCreate({
    required String profileId,
    required String displayName,
    required String? avatarKey,
    required String locale,
    required String profileTimezone,
    required int profileVersion,
    required String householdId,
    required String householdName,
    required String householdTimezone,
    required int householdVersion,
    required String householdRole,
    required bool canManageHouseholdTimezone,
  }) {
    final ProfileAvatarPreset? avatar = ProfileAvatarPreset.fromKey(avatarKey);
    final ProfileLanguage? language = ProfileLanguage.fromCode(locale);
    final ProfileHouseholdRole? role = switch (householdRole) {
      'owner' => ProfileHouseholdRole.owner,
      'admin' => ProfileHouseholdRole.admin,
      'member' => ProfileHouseholdRole.member,
      _ => null,
    };
    final bool derivedCanManage =
        role == ProfileHouseholdRole.owner ||
        role == ProfileHouseholdRole.admin;
    if (!_validUuid(profileId) ||
        !_validUuid(householdId) ||
        !_validName(displayName) ||
        !_validName(householdName) ||
        (avatarKey != null && avatar == null) ||
        language == null ||
        !_validTimezone(profileTimezone) ||
        !_validTimezone(householdTimezone) ||
        profileVersion < 1 ||
        householdVersion < 1 ||
        role == null ||
        derivedCanManage != canManageHouseholdTimezone) {
      return null;
    }
    return ProfilePreferences._(
      profileId: profileId,
      displayName: displayName,
      avatar: avatar,
      language: language,
      profileTimezone: profileTimezone,
      profileVersion: profileVersion,
      householdId: householdId,
      householdName: householdName,
      householdTimezone: householdTimezone,
      householdVersion: householdVersion,
      householdRole: role,
    );
  }
}

final class ProfilePreferencesUpdate {
  const ProfilePreferencesUpdate._({
    required this.displayName,
    required this.avatar,
    required this.language,
    required this.profileTimezone,
    required this.expectedProfileVersion,
    required this.householdTimezone,
    required this.expectedHouseholdVersion,
  });

  final String displayName;
  final ProfileAvatarPreset? avatar;
  final ProfileLanguage language;
  final String profileTimezone;
  final int expectedProfileVersion;
  final String? householdTimezone;
  final int? expectedHouseholdVersion;

  String get fingerprint => jsonEncode(<Object?>[
    displayName,
    avatar?.key,
    language.code,
    profileTimezone,
    expectedProfileVersion,
    householdTimezone,
    expectedHouseholdVersion,
  ]);

  static ProfilePreferencesUpdate? tryCreate({
    required ProfilePreferences current,
    required String displayName,
    required ProfileAvatarPreset? avatar,
    required ProfileLanguage language,
    required String profileTimezone,
    required String householdTimezone,
  }) {
    final String normalizedName = displayName.trim();
    final String normalizedProfileTimezone = profileTimezone.trim();
    final String normalizedHouseholdTimezone = householdTimezone.trim();
    if (!_validName(normalizedName) ||
        !_validTimezone(normalizedProfileTimezone) ||
        !_validTimezone(normalizedHouseholdTimezone)) {
      return null;
    }
    final bool changesHousehold =
        normalizedHouseholdTimezone != current.householdTimezone;
    if (changesHousehold && !current.canManageHouseholdTimezone) {
      return null;
    }
    return ProfilePreferencesUpdate._(
      displayName: normalizedName,
      avatar: avatar,
      language: language,
      profileTimezone: normalizedProfileTimezone,
      expectedProfileVersion: current.profileVersion,
      householdTimezone: changesHousehold ? normalizedHouseholdTimezone : null,
      expectedHouseholdVersion: changesHousehold
          ? current.householdVersion
          : null,
    );
  }
}

bool _validUuid(String value) => _profileUuidPattern.hasMatch(value);

bool _validName(String value) {
  return value.isNotEmpty &&
      value.length <= 80 &&
      value == value.trim() &&
      !_profileControlCharacterPattern.hasMatch(value);
}

bool _validTimezone(String value) {
  return value == 'UTC' ||
      (value.length <= 100 &&
          value == value.trim() &&
          !value.startsWith('posix/') &&
          !value.startsWith('right/') &&
          _profileTimezonePattern.hasMatch(value));
}
