enum HouseholdFeatureGateDataFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class HouseholdFeatureGateDataRecord {
  const HouseholdFeatureGateDataRecord({
    required this.decision,
    required this.householdId,
    required this.featureKey,
    required this.requestedDelta,
    required this.currentUsage,
    required this.limitValue,
    required this.remainingAfterDelta,
    required this.planCode,
    required this.entitlementStatus,
    required this.enforcementEnabled,
    required this.limitsFinalized,
    required this.entitlementVersion,
    required this.policyVersion,
    required this.runtimeVersion,
    required this.evaluatedAt,
  });

  final String decision;
  final String householdId;
  final String featureKey;
  final int requestedDelta;
  final int currentUsage;
  final int? limitValue;
  final int? remainingAfterDelta;
  final String planCode;
  final String entitlementStatus;
  final bool enforcementEnabled;
  final bool limitsFinalized;
  final int entitlementVersion;
  final int policyVersion;
  final int runtimeVersion;
  final String evaluatedAt;
}

abstract interface class HouseholdFeatureGateDataSource {
  Future<HouseholdFeatureGateDataResult> evaluate({
    required String householdId,
    required String featureKey,
    required int requestedDelta,
  });
}

sealed class HouseholdFeatureGateDataResult {
  const HouseholdFeatureGateDataResult();
}

final class HouseholdFeatureGateDataSucceeded
    extends HouseholdFeatureGateDataResult {
  const HouseholdFeatureGateDataSucceeded(this.value);

  final HouseholdFeatureGateDataRecord value;
}

final class HouseholdFeatureGateDataFailed
    extends HouseholdFeatureGateDataResult {
  const HouseholdFeatureGateDataFailed(this.kind);

  final HouseholdFeatureGateDataFailureKind kind;
}
