enum BillingAssignmentFailureKind {
  unauthenticated,
  invalidInput,
  authorization,
  versionConflict,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class BillingAssignmentFailure {
  const BillingAssignmentFailure(this.kind);

  final BillingAssignmentFailureKind kind;

  bool get canRetry => switch (kind) {
    BillingAssignmentFailureKind.temporarilyUnavailable ||
    BillingAssignmentFailureKind.unknown => true,
    BillingAssignmentFailureKind.unauthenticated ||
    BillingAssignmentFailureKind.invalidInput ||
    BillingAssignmentFailureKind.authorization ||
    BillingAssignmentFailureKind.versionConflict ||
    BillingAssignmentFailureKind.invalidPayload => false,
  };
}
