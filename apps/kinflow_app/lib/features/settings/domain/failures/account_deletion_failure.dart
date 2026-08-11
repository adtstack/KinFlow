enum AccountDeletionFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  recentAuthenticationRequired,
  recentAuthenticationCancelled,
  accountChanged,
  requestsPaused,
  idempotencyConflict,
  alreadyPending,
  notFound,
  versionConflict,
  ownerTransferRequired,
  subscriptionAcknowledgementRequired,
  notCancellable,
  temporarilyUnavailable,
  invalidPayload,
  internal,
  unknown,
}

final class AccountDeletionFailure {
  const AccountDeletionFailure(this.kind);

  final AccountDeletionFailureKind kind;

  bool get canRetry => switch (kind) {
    AccountDeletionFailureKind.requestsPaused ||
    AccountDeletionFailureKind.temporarilyUnavailable ||
    AccountDeletionFailureKind.internal ||
    AccountDeletionFailureKind.unknown => true,
    _ => false,
  };
}
