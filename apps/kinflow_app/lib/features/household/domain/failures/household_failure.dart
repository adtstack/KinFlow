enum HouseholdFailureKind {
  unauthenticated,
  invalidInput,
  activeHouseholdExists,
  idempotencyConflict,
  profileUnavailable,
  temporarilyUnavailable,
  invalidPayload,
  internal,
}

final class HouseholdFailure {
  const HouseholdFailure(this.kind);

  final HouseholdFailureKind kind;
}
