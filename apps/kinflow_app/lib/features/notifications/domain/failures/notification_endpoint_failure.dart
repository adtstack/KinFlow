enum NotificationEndpointFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  notFoundOrForbidden,
  idempotencyConflict,
  versionConflict,
  temporarilyUnavailable,
  invalidPayload,
  internal,
}

final class NotificationEndpointFailure {
  const NotificationEndpointFailure(this.kind);

  final NotificationEndpointFailureKind kind;
}
