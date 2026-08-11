enum ProfilePreferencesFailureKind {
  unauthenticated,
  invalidInput,
  unavailable,
  forbidden,
  profileConflict,
  householdConflict,
  temporarilyUnavailable,
  invalidPayload,
  internal,
}

final class ProfilePreferencesFailure {
  const ProfilePreferencesFailure(this.kind);

  final ProfilePreferencesFailureKind kind;
}
