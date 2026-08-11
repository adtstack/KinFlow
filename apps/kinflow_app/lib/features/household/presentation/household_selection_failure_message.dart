import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String householdSelectionFailureMessage(
  AppLocalizations localizations,
  HouseholdSelectionFailure failure,
) {
  return switch (failure.kind) {
    HouseholdSelectionFailureKind.invalidInput ||
    HouseholdSelectionFailureKind.targetUnavailable =>
      localizations.householdSwitchTargetUnavailableError,
    HouseholdSelectionFailureKind.versionConflict =>
      localizations.householdSwitchConflictError,
    HouseholdSelectionFailureKind.featureDisabled =>
      localizations.householdSwitchFeatureDisabledError,
    HouseholdSelectionFailureKind.localStateUnavailable =>
      localizations.householdSwitchLocalStateError,
    HouseholdSelectionFailureKind.unauthenticated ||
    HouseholdSelectionFailureKind.temporarilyUnavailable ||
    HouseholdSelectionFailureKind.invalidPayload ||
    HouseholdSelectionFailureKind.internal =>
      localizations.householdSwitchGenericError,
  };
}
