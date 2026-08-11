enum CalendarFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  idempotencyConflict,
  staleVersion,
  nonexistentLocalTime,
  transitionNotAllowed,
  featurePolicyUnavailable,
  featureLimitReached,
  temporarilyUnavailable,
  invalidPayload,
  internal,
}

final class CalendarFailure {
  const CalendarFailure(this.kind);

  final CalendarFailureKind kind;

  /// An authorization boundary failure invalidates any previously readable
  /// in-memory snapshot instead of treating it as ordinary stale content.
  bool get invalidatesRetainedContent =>
      kind == CalendarFailureKind.unauthenticated ||
      kind == CalendarFailureKind.notFoundOrForbidden;
}
