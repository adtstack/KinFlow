import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String accountDeletionFailureMessage(
  AppLocalizations localizations,
  AccountDeletionFailure failure,
) {
  return switch (failure.kind) {
    AccountDeletionFailureKind.unauthenticated ||
    AccountDeletionFailureKind.permissionDenied ||
    AccountDeletionFailureKind.notFound =>
      localizations.accountDeletionPermissionError,
    AccountDeletionFailureKind.recentAuthenticationRequired =>
      localizations.accountDeletionRecentAuthError,
    AccountDeletionFailureKind.recentAuthenticationCancelled =>
      localizations.accountDeletionRecentAuthCancelled,
    AccountDeletionFailureKind.accountChanged =>
      localizations.accountDeletionAccountChangedError,
    AccountDeletionFailureKind.ownerTransferRequired =>
      localizations.accountDeletionOwnerTransferError,
    AccountDeletionFailureKind.subscriptionAcknowledgementRequired =>
      localizations.accountDeletionSubscriptionError,
    AccountDeletionFailureKind.alreadyPending =>
      localizations.accountDeletionPendingError,
    AccountDeletionFailureKind.versionConflict ||
    AccountDeletionFailureKind.notCancellable ||
    AccountDeletionFailureKind.idempotencyConflict =>
      localizations.accountDeletionConflictError,
    AccountDeletionFailureKind.requestsPaused =>
      localizations.accountDeletionPausedError,
    _ => localizations.accountDeletionGenericError,
  };
}
