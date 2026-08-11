import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';

abstract interface class ProfilePreferencesRepository {
  Future<ProfilePreferencesResult> load();

  Future<ProfilePreferencesResult> update(ProfilePreferencesUpdate update);
}

sealed class ProfilePreferencesResult {
  const ProfilePreferencesResult();
}

final class ProfilePreferencesSucceeded extends ProfilePreferencesResult {
  const ProfilePreferencesSucceeded(this.preferences);

  final ProfilePreferences preferences;
}

final class ProfilePreferencesFailed extends ProfilePreferencesResult {
  const ProfilePreferencesFailed(this.failure);

  final ProfilePreferencesFailure failure;
}
