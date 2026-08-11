enum ChoreFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  idempotencyConflict,
  invalidRecurrence,
  staleVersion,
  invalidTransition,
  featurePolicyUnavailable,
  featureLimitReached,
  temporarilyUnavailable,
  offlineReadOnly,
  invalidPayload,
  internal,
}

final class ChoreFailure {
  const ChoreFailure(this.kind);

  final ChoreFailureKind kind;

  /// Authorization loss invalidates any previously readable in-memory list.
  bool get invalidatesRetainedContent =>
      kind == ChoreFailureKind.unauthenticated ||
      kind == ChoreFailureKind.notFoundOrForbidden;
}
