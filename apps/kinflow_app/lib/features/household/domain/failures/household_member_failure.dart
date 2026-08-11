enum HouseholdMemberFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  notFound,
  roleNotAllowed,
  ownerTransferRequired,
  recentAuthenticationRequired,
  recentAuthenticationCancelled,
  accountChanged,
  versionConflict,
  idempotencyConflict,
  temporarilyUnavailable,
  invalidPayload,
  localStateUnavailable,
  internal,
}

final class HouseholdMemberFailure {
  const HouseholdMemberFailure(this.kind);

  final HouseholdMemberFailureKind kind;
}
