import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';

sealed class ProfilePreferencesState {
  const ProfilePreferencesState();
}

final class ProfilePreferencesInitial extends ProfilePreferencesState {
  const ProfilePreferencesInitial();
}

final class ProfilePreferencesLoading extends ProfilePreferencesState {
  const ProfilePreferencesLoading();
}

final class ProfilePreferencesLoadFailed extends ProfilePreferencesState {
  const ProfilePreferencesLoadFailed(this.failure);

  final ProfilePreferencesFailure failure;
}

final class ProfilePreferencesReady extends ProfilePreferencesState {
  const ProfilePreferencesReady({
    required this.preferences,
    this.isRefreshing = false,
    this.isSaving = false,
    this.failure,
    this.saveCount = 0,
  });

  final ProfilePreferences preferences;
  final bool isRefreshing;
  final bool isSaving;
  final ProfilePreferencesFailure? failure;
  final int saveCount;

  bool get busy => isRefreshing || isSaving;
}
