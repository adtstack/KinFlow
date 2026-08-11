enum DataExportDataFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  recentAuthenticationRequired,
  requestsPaused,
  downloadsPaused,
  idempotencyConflict,
  alreadyPending,
  notFound,
  versionConflict,
  notCancellable,
  artifactUnavailable,
  exportTooLarge,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class DataExportPreflightDataRecord {
  const DataExportPreflightDataRecord({
    required this.canRequest,
    required this.pendingRequestId,
    required this.pendingStatus,
    required this.pendingRequestVersion,
    required this.conflictingRequestPending,
    required this.requestsEnabled,
    required this.downloadsEnabled,
    required this.artifactTtlSeconds,
    required this.downloadGrantTtlSeconds,
    required this.evaluatedAt,
  });

  final bool canRequest;
  final String? pendingRequestId;
  final String? pendingStatus;
  final int? pendingRequestVersion;
  final bool conflictingRequestPending;
  final bool requestsEnabled;
  final bool downloadsEnabled;
  final int artifactTtlSeconds;
  final int downloadGrantTtlSeconds;
  final String evaluatedAt;
}

final class DataExportArtifactDataRecord {
  const DataExportArtifactDataRecord({
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

final class DataExportRequestDataRecord {
  const DataExportRequestDataRecord({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.processingStartedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.failureCode,
    required this.cancellable,
    required this.version,
    required this.artifact,
  });

  final String id;
  final String status;
  final String requestedAt;
  final String? processingStartedAt;
  final String? completedAt;
  final String? failedAt;
  final String? cancelledAt;
  final String? failureCode;
  final bool cancellable;
  final int version;
  final DataExportArtifactDataRecord artifact;
}

final class DataExportDownloadDataRecord {
  const DataExportDownloadDataRecord({
    required this.format,
    required this.expiresAt,
    required this.downloadUrl,
  });

  final String format;
  final String expiresAt;
  final String downloadUrl;
}

abstract interface class DataExportDataSource {
  Future<DataExportDataResult<DataExportPreflightDataRecord>> preflight();

  Future<DataExportDataResult<DataExportRequestDataRecord?>> status({
    String? requestId,
  });

  Future<DataExportDataResult<DataExportRequestDataRecord>> request({
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<DataExportDataResult<DataExportRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<DataExportDataResult<DataExportRequestDataRecord>> revoke({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  });

  Future<DataExportDataResult<DataExportDownloadDataRecord>> download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  });
}

sealed class DataExportDataResult<T> {
  const DataExportDataResult();
}

final class DataExportDataSucceeded<T> extends DataExportDataResult<T> {
  const DataExportDataSucceeded(this.value);

  final T value;
}

final class DataExportDataFailed<T> extends DataExportDataResult<T> {
  const DataExportDataFailed(this.kind);

  final DataExportDataFailureKind kind;
}
