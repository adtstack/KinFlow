enum EntitlementDataFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class HouseholdEntitlementDataRecord {
  HouseholdEntitlementDataRecord({
    required this.householdId,
    required this.entitlementKey,
    required this.planCode,
    required this.status,
    required this.source,
    required this.currentPeriodEnd,
    required this.willRenew,
    required Map<String, int> featureLimits,
    required this.limitsFinalized,
    required this.verifiedAt,
    required this.version,
    required this.isBillingOwner,
  }) : featureLimits = Map<String, int>.unmodifiable(featureLimits);

  final String householdId;
  final String entitlementKey;
  final String planCode;
  final String status;
  final String source;
  final String? currentPeriodEnd;
  final bool willRenew;
  final Map<String, int> featureLimits;
  final bool limitsFinalized;
  final String verifiedAt;
  final int version;
  final bool isBillingOwner;
}

abstract interface class EntitlementDataSource {
  Future<EntitlementDataResult<HouseholdEntitlementDataRecord>> load({
    required String householdId,
  });
}

sealed class EntitlementDataResult<T> {
  const EntitlementDataResult();
}

final class EntitlementDataSucceeded<T> extends EntitlementDataResult<T> {
  const EntitlementDataSucceeded(this.value);

  final T value;
}

final class EntitlementDataFailed<T> extends EntitlementDataResult<T> {
  const EntitlementDataFailed(this.kind);

  final EntitlementDataFailureKind kind;
}
