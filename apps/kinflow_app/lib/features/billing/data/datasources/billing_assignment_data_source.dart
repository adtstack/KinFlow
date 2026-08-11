enum BillingAssignmentDataFailureKind {
  unauthenticated,
  invalidInput,
  authorization,
  versionConflict,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class BillingAssignmentPrepareDataRecord {
  const BillingAssignmentPrepareDataRecord({
    required this.intentId,
    required this.outcome,
    required this.bindingState,
    required this.assignmentVersion,
    required this.intentExpiresAt,
    required this.requeuedJobCount,
    required this.duplicate,
  });

  final String intentId;
  final String outcome;
  final String? bindingState;
  final int? assignmentVersion;
  final String? intentExpiresAt;
  final int requeuedJobCount;
  final bool duplicate;
}

final class BillingAssignmentReleaseDataRecord {
  const BillingAssignmentReleaseDataRecord({
    required this.outcome,
    required this.assignmentVersion,
    required this.duplicate,
  });

  final String outcome;
  final int? assignmentVersion;
  final bool duplicate;
}

final class BillingAssignmentStatusDataRecord {
  const BillingAssignmentStatusDataRecord({
    required this.householdId,
    required this.assignmentState,
    required this.ownershipState,
    required this.ownerMembershipState,
    required this.canPrepare,
    required this.requiresSupport,
    required this.assignmentVersion,
    required this.intentExpiresAt,
  });

  final String householdId;
  final String assignmentState;
  final String ownershipState;
  final String ownerMembershipState;
  final bool canPrepare;
  final bool requiresSupport;
  final int? assignmentVersion;
  final String? intentExpiresAt;
}

final class BillingAssignmentRemediationDataRecord {
  const BillingAssignmentRemediationDataRecord({
    required this.requestId,
    required this.status,
    required this.issueKind,
    required this.duplicate,
  });

  final String requestId;
  final String status;
  final String issueKind;
  final bool duplicate;
}

abstract interface class BillingAssignmentDataSource {
  Future<BillingAssignmentDataResult<BillingAssignmentPrepareDataRecord>>
  prepare({required String householdId, required String idempotencyKey});

  Future<BillingAssignmentDataResult<BillingAssignmentReleaseDataRecord>>
  release({
    required String householdId,
    required int expectedAssignmentVersion,
    required String idempotencyKey,
  });

  Future<BillingAssignmentDataResult<BillingAssignmentStatusDataRecord>>
  status({required String householdId});

  Future<BillingAssignmentDataResult<BillingAssignmentRemediationDataRecord>>
  requestRemediation({
    required String householdId,
    required String issueKind,
    required String idempotencyKey,
  });
}

sealed class BillingAssignmentDataResult<T> {
  const BillingAssignmentDataResult();
}

final class BillingAssignmentDataSucceeded<T>
    extends BillingAssignmentDataResult<T> {
  const BillingAssignmentDataSucceeded(this.value);

  final T value;
}

final class BillingAssignmentDataFailed<T>
    extends BillingAssignmentDataResult<T> {
  const BillingAssignmentDataFailed(this.kind);

  final BillingAssignmentDataFailureKind kind;
}
