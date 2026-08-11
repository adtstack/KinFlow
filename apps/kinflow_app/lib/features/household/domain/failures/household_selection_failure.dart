enum HouseholdSelectionFailureKind {
  unauthenticated,
  invalidInput,
  targetUnavailable,
  versionConflict,
  featureDisabled,
  temporarilyUnavailable,
  invalidPayload,
  localStateUnavailable,
  internal,
}

final class HouseholdSelectionFailure {
  const HouseholdSelectionFailure(this.kind);

  final HouseholdSelectionFailureKind kind;
}
