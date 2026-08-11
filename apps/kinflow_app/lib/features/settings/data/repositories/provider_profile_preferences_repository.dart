import 'package:kinflow_app/features/settings/data/datasources/profile_preferences_data_source.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

final class ProviderProfilePreferencesRepository
    implements ProfilePreferencesRepository {
  const ProviderProfilePreferencesRepository(this._dataSource);

  final ProfilePreferencesDataSource _dataSource;

  @override
  Future<ProfilePreferencesResult> load() async {
    return _map(await _dataSource.load());
  }

  @override
  Future<ProfilePreferencesResult> update(
    ProfilePreferencesUpdate update,
  ) async {
    return _map(
      await _dataSource.update(
        displayName: update.displayName,
        avatarKey: update.avatar?.key,
        locale: update.language.code,
        profileTimezone: update.profileTimezone,
        expectedProfileVersion: update.expectedProfileVersion,
        householdTimezone: update.householdTimezone,
        expectedHouseholdVersion: update.expectedHouseholdVersion,
      ),
    );
  }

  ProfilePreferencesResult _map(ProfilePreferencesDataResult result) {
    return switch (result) {
      ProfilePreferencesDataSucceeded(:final record) => _mapRecord(record),
      ProfilePreferencesDataFailed(:final kind) => ProfilePreferencesFailed(
        ProfilePreferencesFailure(_mapFailure(kind)),
      ),
    };
  }

  ProfilePreferencesResult _mapRecord(ProfilePreferencesDataRecord record) {
    final ProfilePreferences? preferences = ProfilePreferences.tryCreate(
      profileId: record.profileId,
      displayName: record.displayName,
      avatarKey: record.avatarKey,
      locale: record.locale,
      profileTimezone: record.profileTimezone,
      profileVersion: record.profileVersion,
      householdId: record.householdId,
      householdName: record.householdName,
      householdTimezone: record.householdTimezone,
      householdVersion: record.householdVersion,
      householdRole: record.householdRole,
      canManageHouseholdTimezone: record.canManageHouseholdTimezone,
    );
    return preferences == null
        ? const ProfilePreferencesFailed(
            ProfilePreferencesFailure(
              ProfilePreferencesFailureKind.invalidPayload,
            ),
          )
        : ProfilePreferencesSucceeded(preferences);
  }

  ProfilePreferencesFailureKind _mapFailure(
    ProfilePreferencesDataFailureKind kind,
  ) {
    return switch (kind) {
      ProfilePreferencesDataFailureKind.unauthenticated =>
        ProfilePreferencesFailureKind.unauthenticated,
      ProfilePreferencesDataFailureKind.invalidInput =>
        ProfilePreferencesFailureKind.invalidInput,
      ProfilePreferencesDataFailureKind.unavailable =>
        ProfilePreferencesFailureKind.unavailable,
      ProfilePreferencesDataFailureKind.forbidden =>
        ProfilePreferencesFailureKind.forbidden,
      ProfilePreferencesDataFailureKind.profileConflict =>
        ProfilePreferencesFailureKind.profileConflict,
      ProfilePreferencesDataFailureKind.householdConflict =>
        ProfilePreferencesFailureKind.householdConflict,
      ProfilePreferencesDataFailureKind.temporarilyUnavailable =>
        ProfilePreferencesFailureKind.temporarilyUnavailable,
      ProfilePreferencesDataFailureKind.invalidPayload =>
        ProfilePreferencesFailureKind.invalidPayload,
      ProfilePreferencesDataFailureKind.unknown =>
        ProfilePreferencesFailureKind.internal,
    };
  }
}
