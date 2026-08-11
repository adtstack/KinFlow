enum EntitlementFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class EntitlementFailure {
  const EntitlementFailure(this.kind);

  final EntitlementFailureKind kind;
}
