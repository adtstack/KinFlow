import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

final class UnavailableProfilePreferencesRepository
    implements ProfilePreferencesRepository {
  const UnavailableProfilePreferencesRepository();

  static const ProfilePreferencesResult _failure = ProfilePreferencesFailed(
    ProfilePreferencesFailure(
      ProfilePreferencesFailureKind.temporarilyUnavailable,
    ),
  );

  @override
  Future<ProfilePreferencesResult> load() async => _failure;

  @override
  Future<ProfilePreferencesResult> update(
    ProfilePreferencesUpdate update,
  ) async => _failure;
}
