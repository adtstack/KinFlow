import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum HouseholdFeatureKey {
  members('members'),
  activeSeries('activeSeries');

  const HouseholdFeatureKey(this.wireValue);

  final String wireValue;

  static HouseholdFeatureKey? tryParse(String value) {
    for (final HouseholdFeatureKey key in values) {
      if (key.wireValue == value) return key;
    }
    return null;
  }
}

enum HouseholdFeatureGateDecision {
  allowed('allowed'),
  policyUnavailable('policy_unavailable'),
  featureUnconfigured('feature_unconfigured'),
  limitReached('limit_reached');

  const HouseholdFeatureGateDecision(this.wireValue);

  final String wireValue;

  static HouseholdFeatureGateDecision? tryParse(String value) {
    for (final HouseholdFeatureGateDecision decision in values) {
      if (decision.wireValue == value) return decision;
    }
    return null;
  }
}

final class HouseholdFeatureGateRequest {
  const HouseholdFeatureGateRequest._({
    required this.householdId,
    required this.featureKey,
    required this.requestedDelta,
  });

  final HouseholdId householdId;
  final HouseholdFeatureKey featureKey;
  final int requestedDelta;

  static HouseholdFeatureGateRequest? tryCreate({
    required HouseholdId householdId,
    required HouseholdFeatureKey featureKey,
    int requestedDelta = 1,
  }) {
    return requestedDelta < 1 || requestedDelta > 1000
        ? null
        : HouseholdFeatureGateRequest._(
            householdId: householdId,
            featureKey: featureKey,
            requestedDelta: requestedDelta,
          );
  }
}

final class HouseholdFeatureGate {
  const HouseholdFeatureGate._({
    required this.decision,
    required this.householdId,
    required this.featureKey,
    required this.requestedDelta,
    required this.currentUsage,
    required this.limit,
    required this.remainingAfterDelta,
    required this.plan,
    required this.entitlementStatus,
    required this.enforcementEnabled,
    required this.limitsFinalized,
    required this.entitlementVersion,
    required this.policyVersion,
    required this.runtimeVersion,
    required this.evaluatedAt,
  });

  final HouseholdFeatureGateDecision decision;
  final HouseholdId householdId;
  final HouseholdFeatureKey featureKey;
  final int requestedDelta;
  final int currentUsage;
  final int? limit;
  final int? remainingAfterDelta;
  final EntitlementPlan plan;
  final HouseholdEntitlementStatus entitlementStatus;
  final bool enforcementEnabled;
  final bool limitsFinalized;
  final int entitlementVersion;
  final int policyVersion;
  final int runtimeVersion;
  final DateTime evaluatedAt;

  bool get isAllowed => decision == HouseholdFeatureGateDecision.allowed;

  bool get shouldOfferUpgrade =>
      decision == HouseholdFeatureGateDecision.limitReached &&
      plan == EntitlementPlan.free;

  static HouseholdFeatureGate? tryCreate({
    required HouseholdFeatureGateDecision decision,
    required HouseholdId householdId,
    required HouseholdFeatureKey featureKey,
    required int requestedDelta,
    required int currentUsage,
    required int? limit,
    required int? remainingAfterDelta,
    required EntitlementPlan plan,
    required HouseholdEntitlementStatus entitlementStatus,
    required bool enforcementEnabled,
    required bool limitsFinalized,
    required int entitlementVersion,
    required int policyVersion,
    required int runtimeVersion,
    required DateTime evaluatedAt,
  }) {
    if (requestedDelta < 1 ||
        requestedDelta > 1000 ||
        currentUsage < 0 ||
        entitlementVersion < 1 ||
        policyVersion < 1 ||
        runtimeVersion < 1 ||
        !evaluatedAt.isUtc ||
        !isValidEntitlementPlanStatus(plan, entitlementStatus)) {
      return null;
    }

    final bool validDecision = switch (decision) {
      HouseholdFeatureGateDecision.allowed =>
        enforcementEnabled &&
            limitsFinalized &&
            limit != null &&
            limit >= 0 &&
            currentUsage + requestedDelta <= limit &&
            remainingAfterDelta == limit - currentUsage - requestedDelta,
      HouseholdFeatureGateDecision.limitReached =>
        enforcementEnabled &&
            limitsFinalized &&
            limit != null &&
            limit >= 0 &&
            currentUsage + requestedDelta > limit &&
            remainingAfterDelta == 0,
      HouseholdFeatureGateDecision.policyUnavailable =>
        (!enforcementEnabled || !limitsFinalized) &&
            limit == null &&
            remainingAfterDelta == null,
      HouseholdFeatureGateDecision.featureUnconfigured =>
        enforcementEnabled &&
            limitsFinalized &&
            limit == null &&
            remainingAfterDelta == null,
    };
    if (!validDecision) return null;

    return HouseholdFeatureGate._(
      decision: decision,
      householdId: householdId,
      featureKey: featureKey,
      requestedDelta: requestedDelta,
      currentUsage: currentUsage,
      limit: limit,
      remainingAfterDelta: remainingAfterDelta,
      plan: plan,
      entitlementStatus: entitlementStatus,
      enforcementEnabled: enforcementEnabled,
      limitsFinalized: limitsFinalized,
      entitlementVersion: entitlementVersion,
      policyVersion: policyVersion,
      runtimeVersion: runtimeVersion,
      evaluatedAt: evaluatedAt.toUtc(),
    );
  }
}
