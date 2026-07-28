enum InviteFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  idempotencyConflict,
  invalid,
  expired,
  revoked,
  alreadyUsed,
  emailMismatch,
  rateLimited,
  profileUnavailable,
  temporarilyUnavailable,
  invalidPayload,
  internal,
}

final class InviteFailure {
  const InviteFailure(this.kind);

  final InviteFailureKind kind;
}
