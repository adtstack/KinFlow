import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String householdMemberFailureMessage(
  AppLocalizations localizations,
  HouseholdMemberFailure failure,
) {
  return switch (failure.kind) {
    HouseholdMemberFailureKind.permissionDenied ||
    HouseholdMemberFailureKind.notFound ||
    HouseholdMemberFailureKind.roleNotAllowed =>
      localizations.membersPermissionError,
    HouseholdMemberFailureKind.ownerTransferRequired =>
      localizations.membersOwnerTransferRequiredError,
    HouseholdMemberFailureKind.recentAuthenticationRequired =>
      localizations.membersRecentAuthError,
    HouseholdMemberFailureKind.recentAuthenticationCancelled =>
      localizations.membersRecentAuthCancelled,
    HouseholdMemberFailureKind.accountChanged =>
      localizations.membersAccountChangedError,
    HouseholdMemberFailureKind.versionConflict =>
      localizations.membersVersionConflictError,
    HouseholdMemberFailureKind.localStateUnavailable =>
      localizations.householdSwitchLocalStateError,
    _ => localizations.membersGenericError,
  };
}
