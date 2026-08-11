import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

enum AccountDeletionRequestStatus {
  queued('queued'),
  verifying('verifying'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const AccountDeletionRequestStatus(this.wireValue);

  final String wireValue;

  static AccountDeletionRequestStatus? tryParse(String value) {
    for (final AccountDeletionRequestStatus status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return null;
  }

  bool get isPending => switch (this) {
    queued || verifying || processing => true,
    completed || failed || cancelled => false,
  };
}

final class AccountDeletionPreflight {
  const AccountDeletionPreflight._({
    required this.canRequest,
    required this.ownerHouseholdCount,
    required this.hasActiveSubscription,
    required this.pendingRequestId,
    required this.pendingStatus,
    required this.pendingRequestVersion,
    required this.requestsEnabled,
    required this.cancellationWindow,
    required this.evaluatedAt,
  });

  final bool canRequest;
  final int ownerHouseholdCount;
  final bool hasActiveSubscription;
  final AccountDeletionRequestId? pendingRequestId;
  final AccountDeletionRequestStatus? pendingStatus;
  final int? pendingRequestVersion;
  final bool requestsEnabled;
  final Duration cancellationWindow;
  final DateTime evaluatedAt;

  bool get requiresOwnerTransfer => ownerHouseholdCount > 0;
  bool get hasPendingRequest => pendingRequestId != null;

  static AccountDeletionPreflight? tryCreate({
    required bool canRequest,
    required int ownerHouseholdCount,
    required bool hasActiveSubscription,
    required AccountDeletionRequestId? pendingRequestId,
    required AccountDeletionRequestStatus? pendingStatus,
    required int? pendingRequestVersion,
    required bool requestsEnabled,
    required Duration cancellationWindow,
    required DateTime evaluatedAt,
  }) {
    final bool allPendingValuesAbsent =
        pendingRequestId == null &&
        pendingStatus == null &&
        pendingRequestVersion == null;
    final bool allPendingValuesPresent =
        pendingRequestId != null &&
        pendingStatus != null &&
        pendingRequestVersion != null;
    if (ownerHouseholdCount < 0 ||
        ownerHouseholdCount > 1000 ||
        (!allPendingValuesAbsent && !allPendingValuesPresent) ||
        pendingStatus != null && !pendingStatus.isPending ||
        pendingRequestVersion != null && pendingRequestVersion < 1 ||
        cancellationWindow < const Duration(hours: 1) ||
        cancellationWindow > const Duration(days: 7) ||
        !evaluatedAt.isUtc ||
        canRequest !=
            (requestsEnabled &&
                ownerHouseholdCount == 0 &&
                pendingRequestId == null)) {
      return null;
    }
    return AccountDeletionPreflight._(
      canRequest: canRequest,
      ownerHouseholdCount: ownerHouseholdCount,
      hasActiveSubscription: hasActiveSubscription,
      pendingRequestId: pendingRequestId,
      pendingStatus: pendingStatus,
      pendingRequestVersion: pendingRequestVersion,
      requestsEnabled: requestsEnabled,
      cancellationWindow: cancellationWindow,
      evaluatedAt: evaluatedAt,
    );
  }

  AccountDeletionPreflight withPending(AccountDeletionRequest request) {
    return AccountDeletionPreflight._(
      canRequest: false,
      ownerHouseholdCount: ownerHouseholdCount,
      hasActiveSubscription: hasActiveSubscription,
      pendingRequestId: request.id,
      pendingStatus: request.status,
      pendingRequestVersion: request.version,
      requestsEnabled: requestsEnabled,
      cancellationWindow: cancellationWindow,
      evaluatedAt: evaluatedAt,
    );
  }

  AccountDeletionPreflight withoutPending() {
    return AccountDeletionPreflight._(
      canRequest: requestsEnabled && ownerHouseholdCount == 0,
      ownerHouseholdCount: ownerHouseholdCount,
      hasActiveSubscription: hasActiveSubscription,
      pendingRequestId: null,
      pendingStatus: null,
      pendingRequestVersion: null,
      requestsEnabled: requestsEnabled,
      cancellationWindow: cancellationWindow,
      evaluatedAt: evaluatedAt,
    );
  }
}

final class AccountDeletionRequest {
  const AccountDeletionRequest._({
    required this.id,
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

  final AccountDeletionRequestId id;
  final AccountDeletionRequestStatus status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final String? failureCode;
  final bool activeSubscriptionAtRequest;
  final bool subscriptionAcknowledged;
  final bool cancellable;
  final int version;

  static AccountDeletionRequest? tryCreate({
    required AccountDeletionRequestId id,
    required AccountDeletionRequestStatus status,
    required DateTime requestedAt,
    required DateTime scheduledFor,
    required DateTime? processingStartedAt,
    required DateTime? completedAt,
    required DateTime? failedAt,
    required DateTime? cancelledAt,
    required String? failureCode,
    required bool activeSubscriptionAtRequest,
    required bool subscriptionAcknowledged,
    required bool cancellable,
    required int version,
  }) {
    if (!requestedAt.isUtc ||
        !scheduledFor.isUtc ||
        scheduledFor.isBefore(requestedAt) ||
        version < 1 ||
        activeSubscriptionAtRequest && !subscriptionAcknowledged ||
        !_validOptionalTimestamp(processingStartedAt, requestedAt) ||
        !_validOptionalTimestamp(completedAt, processingStartedAt) ||
        !_validOptionalTimestamp(failedAt, processingStartedAt) ||
        !_validOptionalTimestamp(cancelledAt, requestedAt) ||
        !_validFailureCode(failureCode) ||
        !_validStatusShape(
          status: status,
          processingStartedAt: processingStartedAt,
          completedAt: completedAt,
          failedAt: failedAt,
          cancelledAt: cancelledAt,
          failureCode: failureCode,
          cancellable: cancellable,
        )) {
      return null;
    }
    return AccountDeletionRequest._(
      id: id,
      status: status,
      requestedAt: requestedAt,
      scheduledFor: scheduledFor,
      processingStartedAt: processingStartedAt,
      completedAt: completedAt,
      failedAt: failedAt,
      cancelledAt: cancelledAt,
      failureCode: failureCode,
      activeSubscriptionAtRequest: activeSubscriptionAtRequest,
      subscriptionAcknowledged: subscriptionAcknowledged,
      cancellable: cancellable,
      version: version,
    );
  }
}

bool _validOptionalTimestamp(DateTime? value, DateTime? lowerBound) {
  return value == null ||
      value.isUtc && lowerBound != null && !value.isBefore(lowerBound);
}

bool _validFailureCode(String? value) {
  if (value == null) {
    return true;
  }
  return switch (value) {
    'OWNER_TRANSFER_REQUIRED' ||
    'AUTH_DELETE_REJECTED' ||
    'AUTH_DELETE_UNAVAILABLE' ||
    'AUTH_DELETE_ATTEMPTS_EXHAUSTED' ||
    'PROCESSING_PRECONDITION_FAILED' => true,
    _ => false,
  };
}

bool _validStatusShape({
  required AccountDeletionRequestStatus status,
  required DateTime? processingStartedAt,
  required DateTime? completedAt,
  required DateTime? failedAt,
  required DateTime? cancelledAt,
  required String? failureCode,
  required bool cancellable,
}) {
  return switch (status) {
    AccountDeletionRequestStatus.queued ||
    AccountDeletionRequestStatus.verifying =>
      processingStartedAt == null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt == null &&
          failureCode == null &&
          cancellable,
    AccountDeletionRequestStatus.processing =>
      processingStartedAt != null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt == null &&
          !cancellable,
    AccountDeletionRequestStatus.completed =>
      processingStartedAt != null &&
          completedAt != null &&
          failedAt == null &&
          cancelledAt == null &&
          failureCode == null &&
          !cancellable,
    AccountDeletionRequestStatus.failed =>
      processingStartedAt != null &&
          completedAt == null &&
          failedAt != null &&
          cancelledAt == null &&
          failureCode != null &&
          !cancellable,
    AccountDeletionRequestStatus.cancelled =>
      processingStartedAt == null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt != null &&
          failureCode == null &&
          !cancellable,
  };
}
