enum HouseholdPrivacyFailureKind {
  noActiveHousehold,
  unauthenticated,
  invalidInput,
  ownerRequired,
  recentAuthenticationRequired,
  recentAuthenticationCancelled,
  accountChanged,
  exportRequestsPaused,
  deletionRequestsPaused,
  downloadsPaused,
  idempotencyConflict,
  alreadyPending,
  notFound,
  versionConflict,
  requestNotMutable,
  confirmationMismatch,
  subscriptionAcknowledgmentRequired,
  artifactUnavailable,
  householdAlreadyDeleted,
  launchFailed,
  temporarilyUnavailable,
  invalidPayload,
  internal,
  unknown,
}

final class HouseholdPrivacyFailure {
  const HouseholdPrivacyFailure(this.kind);

  final HouseholdPrivacyFailureKind kind;

  bool get canRetry => switch (kind) {
    HouseholdPrivacyFailureKind.exportRequestsPaused ||
    HouseholdPrivacyFailureKind.deletionRequestsPaused ||
    HouseholdPrivacyFailureKind.downloadsPaused ||
    HouseholdPrivacyFailureKind.launchFailed ||
    HouseholdPrivacyFailureKind.temporarilyUnavailable ||
    HouseholdPrivacyFailureKind.internal ||
    HouseholdPrivacyFailureKind.unknown => true,
    _ => false,
  };
}
