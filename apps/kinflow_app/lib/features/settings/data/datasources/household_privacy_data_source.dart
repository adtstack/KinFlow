enum HouseholdPrivacyDataFailureKind {
  unauthenticated,
  invalidInput,
  ownerRequired,
  recentAuthenticationRequired,
  exportRequestsPaused,
  deletionRequestsPaused,
  downloadsPaused,
  idempotencyConflict,
  alreadyPending,
  notFound,
  versionConflict,
  requestNotMutable,
  confirmationMismatch,
  subscriptionAcknowledgmentRequired,
  artifactUnavailable,
  householdAlreadyDeleted,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class HouseholdPrivacyHouseholdDataRecord {
  const HouseholdPrivacyHouseholdDataRecord({
    required this.id,
    required this.name,
    required this.version,
  });

  final String id;
  final String name;
  final int version;
}

final class HouseholdExportArtifactDataRecord {
  const HouseholdExportArtifactDataRecord({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.expiresAt,
    required this.revokedAt,
    required this.purgedAt,
    required this.machineSizeBytes,
    required this.humanSizeBytes,
    required this.available,
  });

  final String id;
  final int version;
  final String schemaVersion;
  final String? expiresAt;
  final String? revokedAt;
  final String? purgedAt;
  final int? machineSizeBytes;
  final int? humanSizeBytes;
  final bool available;
}

final class HouseholdDeletionProgressDataRecord {
  const HouseholdDeletionProgressDataRecord({
    required this.retentionBlocked,
    required this.retentionReviewAt,
    required this.accessRevokedAt,
    required this.redactedAt,
    required this.billingUnlinkedAt,
  });

  final bool retentionBlocked;
  final String? retentionReviewAt;
  final String? accessRevokedAt;
  final String? redactedAt;
  final String? billingUnlinkedAt;
}

final class HouseholdPrivacyRequestDataRecord {
  const HouseholdPrivacyRequestDataRecord({
    required this.requestId,
    required this.kind,
    required this.householdId,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
    required this.processingStartedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.failureCode,
    required this.cancellable,
    required this.version,
    required this.activeSubscriptionAtRequest,
    required this.artifact,
    required this.deletion,
  });

  final String requestId;
  final String kind;
  final String householdId;
  final String status;
  final String requestedAt;
  final String scheduledFor;
  final String? processingStartedAt;
  final String? completedAt;
  final String? failedAt;
  final String? cancelledAt;
  final String? failureCode;
  final bool cancellable;
  final int version;
  final bool activeSubscriptionAtRequest;
  final HouseholdExportArtifactDataRecord? artifact;
  final HouseholdDeletionProgressDataRecord? deletion;
}

final class HouseholdPrivacyPreflightDataRecord {
  const HouseholdPrivacyPreflightDataRecord({
    required this.household,
    required this.memberCount,
    required this.activeSubscription,
    required this.canExport,
    required this.canDelete,
    required this.conflictingRequestPending,
    required this.pendingRequest,
    required this.exportRequestsEnabled,
    required this.deletionRequestsEnabled,
    required this.downloadsEnabled,
    required this.artifactTtlSeconds,
    required this.downloadGrantTtlSeconds,
    required this.deletionCancellationWindowSeconds,
    required this.retentionBlocked,
    required this.retentionReviewAt,
    required this.evaluatedAt,
  });

  final HouseholdPrivacyHouseholdDataRecord household;
  final int memberCount;
  final bool activeSubscription;
  final bool canExport;
  final bool canDelete;
  final bool conflictingRequestPending;
  final HouseholdPrivacyRequestDataRecord? pendingRequest;
  final bool exportRequestsEnabled;
  final bool deletionRequestsEnabled;
  final bool downloadsEnabled;
  final int artifactTtlSeconds;
  final int downloadGrantTtlSeconds;
  final int deletionCancellationWindowSeconds;
  final bool retentionBlocked;
  final String? retentionReviewAt;
  final String evaluatedAt;
}

final class HouseholdExportDownloadDataRecord {
  const HouseholdExportDownloadDataRecord({
    required this.format,
    required this.expiresAt,
    required this.downloadUrl,
  });

  final String format;
  final String expiresAt;
  final String downloadUrl;
}

abstract interface class HouseholdPrivacyDataSource {
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyPreflightDataRecord>>
  preflight(String householdId);

  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> status(
    String requestId,
  );

  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestExport({
    required String householdId,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestDeletion({
    required String householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> cancel({
    required String requestId,
    required String kind,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  revokeExport({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<HouseholdPrivacyDataResult<HouseholdExportDownloadDataRecord>>
  download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  });
}

sealed class HouseholdPrivacyDataResult<T> {
  const HouseholdPrivacyDataResult();
}

final class HouseholdPrivacyDataSucceeded<T>
    extends HouseholdPrivacyDataResult<T> {
  const HouseholdPrivacyDataSucceeded(this.value);

  final T value;
}

final class HouseholdPrivacyDataFailed<T>
    extends HouseholdPrivacyDataResult<T> {
  const HouseholdPrivacyDataFailed(this.kind);

  final HouseholdPrivacyDataFailureKind kind;
}
