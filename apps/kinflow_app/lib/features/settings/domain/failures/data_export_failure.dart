enum DataExportFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  recentAuthenticationRequired,
  recentAuthenticationCancelled,
  accountChanged,
  requestsPaused,
  downloadsPaused,
  idempotencyConflict,
  alreadyPending,
  notFound,
  versionConflict,
  notCancellable,
  artifactUnavailable,
  exportTooLarge,
  launchFailed,
  temporarilyUnavailable,
  invalidPayload,
  internal,
  unknown,
}

final class DataExportFailure {
  const DataExportFailure(this.kind);

  final DataExportFailureKind kind;

  bool get canRetry => switch (kind) {
    DataExportFailureKind.requestsPaused ||
    DataExportFailureKind.downloadsPaused ||
    DataExportFailureKind.launchFailed ||
    DataExportFailureKind.temporarilyUnavailable ||
    DataExportFailureKind.internal ||
    DataExportFailureKind.unknown => true,
    _ => false,
  };
}
