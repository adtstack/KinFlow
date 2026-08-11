import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String householdPrivacyFailureMessage(
  AppLocalizations localizations,
  HouseholdPrivacyFailure failure,
) {
  return switch (failure.kind) {
    HouseholdPrivacyFailureKind.noActiveHousehold ||
    HouseholdPrivacyFailureKind.unauthenticated ||
    HouseholdPrivacyFailureKind.ownerRequired ||
    HouseholdPrivacyFailureKind.notFound =>
      localizations.householdPrivacyPermissionError,
    HouseholdPrivacyFailureKind.recentAuthenticationRequired =>
      localizations.householdPrivacyRecentAuthError,
    HouseholdPrivacyFailureKind.recentAuthenticationCancelled =>
      localizations.householdPrivacyRecentAuthCancelled,
    HouseholdPrivacyFailureKind.accountChanged =>
      localizations.householdPrivacyAccountChangedError,
    HouseholdPrivacyFailureKind.exportRequestsPaused ||
    HouseholdPrivacyFailureKind.deletionRequestsPaused ||
    HouseholdPrivacyFailureKind.downloadsPaused =>
      localizations.householdPrivacyPausedError,
    HouseholdPrivacyFailureKind.alreadyPending =>
      localizations.householdPrivacyPendingError,
    HouseholdPrivacyFailureKind.idempotencyConflict ||
    HouseholdPrivacyFailureKind.versionConflict ||
    HouseholdPrivacyFailureKind.requestNotMutable =>
      localizations.householdPrivacyConflictError,
    HouseholdPrivacyFailureKind.confirmationMismatch =>
      localizations.householdPrivacyConfirmationError,
    HouseholdPrivacyFailureKind.subscriptionAcknowledgmentRequired =>
      localizations.householdPrivacySubscriptionAckError,
    HouseholdPrivacyFailureKind.artifactUnavailable =>
      localizations.householdPrivacyArtifactError,
    HouseholdPrivacyFailureKind.householdAlreadyDeleted =>
      localizations.householdPrivacyDeletedError,
    HouseholdPrivacyFailureKind.launchFailed =>
      localizations.householdPrivacyLaunchError,
    HouseholdPrivacyFailureKind.invalidInput ||
    HouseholdPrivacyFailureKind.temporarilyUnavailable ||
    HouseholdPrivacyFailureKind.invalidPayload ||
    HouseholdPrivacyFailureKind.internal ||
    HouseholdPrivacyFailureKind.unknown =>
      localizations.householdPrivacyGenericError,
  };
}
