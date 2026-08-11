enum AccountDeletionDataFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  recentAuthenticationRequired,
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
  unknown,
}

final class AccountDeletionPreflightDataRecord {
  const AccountDeletionPreflightDataRecord({
    required this.canRequest,
    required this.ownerHouseholdCount,
    required this.hasActiveSubscription,
    required this.pendingRequestId,
    required this.pendingStatus,
    required this.pendingRequestVersion,
    required this.requestsEnabled,
    required this.cancellationWindowSeconds,
    required this.evaluatedAt,
  });

  final bool canRequest;
  final int ownerHouseholdCount;
  final bool hasActiveSubscription;
  final String? pendingRequestId;
  final String? pendingStatus;
  final int? pendingRequestVersion;
  final bool requestsEnabled;
  final int cancellationWindowSeconds;
  final String evaluatedAt;
}

final class AccountDeletionRequestDataRecord {
  const AccountDeletionRequestDataRecord({
    required this.id,
    required this.type,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
    required this.processingStartedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.failureCode,
    required this.activeSubscriptionAtRequest,
    required this.subscriptionAcknowledged,
    required this.cancellable,
    required this.version,
  });

  final String id;
  final String type;
  final String status;
  final String requestedAt;
  final String scheduledFor;
  final String? processingStartedAt;
  final String? completedAt;
  final String? failedAt;
  final String? cancelledAt;
  final String? failureCode;
  final bool activeSubscriptionAtRequest;
  final bool subscriptionAcknowledged;
  final bool cancellable;
  final int version;
}

abstract interface class AccountDeletionDataSource {
  Future<AccountDeletionDataResult<AccountDeletionPreflightDataRecord>>
  preflight();

  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord?>> status({
    String? requestId,
  });

  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> request({
    required bool subscriptionAcknowledged,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  });
}

sealed class AccountDeletionDataResult<T> {
  const AccountDeletionDataResult();
}

final class AccountDeletionDataSucceeded<T>
    extends AccountDeletionDataResult<T> {
  const AccountDeletionDataSucceeded(this.value);

  final T value;
}

final class AccountDeletionDataFailed<T> extends AccountDeletionDataResult<T> {
  const AccountDeletionDataFailed(this.kind);

  final AccountDeletionDataFailureKind kind;
}
