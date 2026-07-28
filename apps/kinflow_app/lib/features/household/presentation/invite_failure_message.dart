import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String inviteFailureMessage(
  AppLocalizations localizations,
  InviteFailure failure,
) {
  return switch (failure.kind) {
    InviteFailureKind.invalid => localizations.inviteInvalidError,
    InviteFailureKind.expired => localizations.inviteExpiredError,
    InviteFailureKind.revoked => localizations.inviteRevokedError,
    InviteFailureKind.alreadyUsed => localizations.inviteAlreadyUsedError,
    InviteFailureKind.emailMismatch => localizations.inviteEmailMismatchError,
    InviteFailureKind.rateLimited => localizations.inviteRateLimitedError,
    InviteFailureKind.permissionDenied => localizations.invitePermissionError,
    InviteFailureKind.invalidInput => localizations.householdInvalidInputError,
    _ => localizations.inviteGenericError,
  };
}
