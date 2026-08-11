enum NotificationFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  versionConflict,
  snoozeUnavailable,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class NotificationFailure {
  const NotificationFailure(this.kind);

  final NotificationFailureKind kind;
}
