import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';

import '../../support/fakes/fake_profile_preferences_dependencies.dart';

void main() {
  test('valid projection derives household timezone authority from role', () {
    final ProfilePreferences owner = profilePreferencesFixture();
    final ProfilePreferences admin = profilePreferencesFixture(
      role: ProfileHouseholdRole.admin,
    );
    final ProfilePreferences member = profilePreferencesFixture(
      role: ProfileHouseholdRole.member,
    );

    expect(owner.canManageHouseholdTimezone, isTrue);
    expect(admin.canManageHouseholdTimezone, isTrue);
    expect(member.canManageHouseholdTimezone, isFalse);
  });

  test('projection rejects unknown avatar and forged capability flag', () {
    expect(
      ProfilePreferences.tryCreate(
        profileId: profilePreferencesProfileId,
        displayName: 'Adult A',
        avatarKey: 'https://remote.invalid/avatar.png',
        locale: 'en',
        profileTimezone: 'Asia/Seoul',
        profileVersion: 1,
        householdId: profilePreferencesHouseholdId,
        householdName: 'Kim family',
        householdTimezone: 'Asia/Seoul',
        householdVersion: 1,
        householdRole: 'owner',
        canManageHouseholdTimezone: true,
      ),
      isNull,
    );
    expect(
      ProfilePreferences.tryCreate(
        profileId: profilePreferencesProfileId,
        displayName: 'Adult A',
        avatarKey: null,
        locale: 'en',
        profileTimezone: 'Asia/Seoul',
        profileVersion: 1,
        householdId: profilePreferencesHouseholdId,
        householdName: 'Kim family',
        householdTimezone: 'Asia/Seoul',
        householdVersion: 1,
        householdRole: 'member',
        canManageHouseholdTimezone: true,
      ),
      isNull,
    );
  });

  test('update normalizes profile fields and versions household changes', () {
    final ProfilePreferences current = profilePreferencesFixture();

    final ProfilePreferencesUpdate update = ProfilePreferencesUpdate.tryCreate(
      current: current,
      displayName: '  Adult Alpha  ',
      avatar: ProfileAvatarPreset.star,
      language: ProfileLanguage.korean,
      profileTimezone: ' America/New_York ',
      householdTimezone: ' Europe/London ',
    )!;

    expect(update.displayName, 'Adult Alpha');
    expect(update.profileTimezone, 'America/New_York');
    expect(update.householdTimezone, 'Europe/London');
    expect(update.expectedProfileVersion, current.profileVersion);
    expect(update.expectedHouseholdVersion, current.householdVersion);
  });

  test('unchanged household timezone omits household version', () {
    final ProfilePreferences current = profilePreferencesFixture();

    final ProfilePreferencesUpdate update = ProfilePreferencesUpdate.tryCreate(
      current: current,
      displayName: current.displayName,
      avatar: current.avatar,
      language: current.language,
      profileTimezone: current.profileTimezone,
      householdTimezone: current.householdTimezone,
    )!;

    expect(update.householdTimezone, isNull);
    expect(update.expectedHouseholdVersion, isNull);
  });

  test('Member cannot construct household timezone mutation', () {
    final ProfilePreferences member = profilePreferencesFixture(
      role: ProfileHouseholdRole.member,
    );

    expect(
      ProfilePreferencesUpdate.tryCreate(
        current: member,
        displayName: member.displayName,
        avatar: member.avatar,
        language: member.language,
        profileTimezone: member.profileTimezone,
        householdTimezone: 'Europe/London',
      ),
      isNull,
    );
  });
}
