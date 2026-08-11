import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String profilePreferencesFailureMessage(
  AppLocalizations localizations,
  ProfilePreferencesFailure failure,
) {
  return switch (failure.kind) {
    ProfilePreferencesFailureKind.unauthenticated =>
      localizations.profilePreferencesErrorUnauthenticated,
    ProfilePreferencesFailureKind.invalidInput =>
      localizations.profilePreferencesErrorInvalidInput,
    ProfilePreferencesFailureKind.unavailable =>
      localizations.profilePreferencesErrorUnavailable,
    ProfilePreferencesFailureKind.forbidden =>
      localizations.profilePreferencesErrorForbidden,
    ProfilePreferencesFailureKind.profileConflict =>
      localizations.profilePreferencesErrorProfileConflict,
    ProfilePreferencesFailureKind.householdConflict =>
      localizations.profilePreferencesErrorHouseholdConflict,
    ProfilePreferencesFailureKind.temporarilyUnavailable =>
      localizations.profilePreferencesErrorTemporarilyUnavailable,
    ProfilePreferencesFailureKind.invalidPayload =>
      localizations.profilePreferencesErrorInvalidPayload,
    ProfilePreferencesFailureKind.internal =>
      localizations.profilePreferencesErrorInternal,
  };
}
