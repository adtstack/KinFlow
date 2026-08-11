import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/profile_preferences_data_source.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

import '../../support/fakes/fake_profile_preferences_dependencies.dart';

void main() {
  test('maps exact record through domain validation', () async {
    final ProviderProfilePreferencesRepository repository =
        ProviderProfilePreferencesRepository(
          FakeProfilePreferencesDataSource(),
        );

    final ProfilePreferencesResult result = await repository.load();

    expect(result, isA<ProfilePreferencesSucceeded>());
    final ProfilePreferences preferences =
        (result as ProfilePreferencesSucceeded).preferences;
    expect(preferences.displayName, 'Adult A');
    expect(preferences.canManageHouseholdTimezone, isTrue);
  });

  test('rejects provider capability that disagrees with role', () async {
    final ProviderProfilePreferencesRepository repository =
        ProviderProfilePreferencesRepository(
          FakeProfilePreferencesDataSource(
            loadResult: ProfilePreferencesDataSucceeded(
              profilePreferencesRecordFixture(
                householdRole: 'member',
                canManageHouseholdTimezone: true,
              ),
            ),
          ),
        );

    final ProfilePreferencesResult result = await repository.load();

    expect(
      (result as ProfilePreferencesFailed).failure.kind,
      ProfilePreferencesFailureKind.invalidPayload,
    );
  });

  test('sends nullable household mutation boundary exactly', () async {
    final FakeProfilePreferencesDataSource dataSource =
        FakeProfilePreferencesDataSource();
    final ProviderProfilePreferencesRepository repository =
        ProviderProfilePreferencesRepository(dataSource);
    final ProfilePreferences current = profilePreferencesFixture();
    final ProfilePreferencesUpdate update = ProfilePreferencesUpdate.tryCreate(
      current: current,
      displayName: 'Adult Alpha',
      avatar: ProfileAvatarPreset.leaf,
      language: ProfileLanguage.korean,
      profileTimezone: 'America/New_York',
      householdTimezone: 'Europe/London',
    )!;

    await repository.update(update);

    expect(dataSource.updateCalls.single, <String, Object?>{
      'displayName': 'Adult Alpha',
      'avatarKey': 'preset:leaf',
      'locale': 'ko',
      'profileTimezone': 'America/New_York',
      'expectedProfileVersion': 1,
      'householdTimezone': 'Europe/London',
      'expectedHouseholdVersion': 4,
    });
  });

  test('maps stable provider conflict without reflecting details', () async {
    final ProviderProfilePreferencesRepository repository =
        ProviderProfilePreferencesRepository(
          FakeProfilePreferencesDataSource(
            loadResult: const ProfilePreferencesDataFailed(
              ProfilePreferencesDataFailureKind.householdConflict,
            ),
          ),
        );

    final ProfilePreferencesResult result = await repository.load();

    expect(
      (result as ProfilePreferencesFailed).failure.kind,
      ProfilePreferencesFailureKind.householdConflict,
    );
  });
}
