import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '20000000-0000-4000-8000-000000000101',
  )!;

  test('feature and decision wire values remain server compatible', () {
    expect(
      HouseholdFeatureKey.tryParse('activeSeries'),
      HouseholdFeatureKey.activeSeries,
    );
    expect(
      HouseholdFeatureGateDecision.tryParse('policy_unavailable'),
      HouseholdFeatureGateDecision.policyUnavailable,
    );
    expect(HouseholdFeatureKey.tryParse('active_series'), isNull);
    expect(HouseholdFeatureGateDecision.tryParse('denied'), isNull);
  });

  test('request delta is positive and bounded', () {
    expect(
      HouseholdFeatureGateRequest.tryCreate(
        householdId: householdId,
        featureKey: HouseholdFeatureKey.members,
      )?.requestedDelta,
      1,
    );
    expect(
      HouseholdFeatureGateRequest.tryCreate(
        householdId: householdId,
        featureKey: HouseholdFeatureKey.members,
        requestedDelta: 1000,
      ),
      isNotNull,
    );
    expect(
      HouseholdFeatureGateRequest.tryCreate(
        householdId: householdId,
        featureKey: HouseholdFeatureKey.members,
        requestedDelta: 0,
      ),
      isNull,
    );
    expect(
      HouseholdFeatureGateRequest.tryCreate(
        householdId: householdId,
        featureKey: HouseholdFeatureKey.members,
        requestedDelta: 1001,
      ),
      isNull,
    );
  });

  test('allowed decision requires exact remaining capacity', () {
    final HouseholdFeatureGate? gate = _gate(
      householdId: householdId,
      decision: HouseholdFeatureGateDecision.allowed,
      currentUsage: 2,
      requestedDelta: 2,
      limit: 5,
      remainingAfterDelta: 1,
    );

    expect(gate?.isAllowed, isTrue);
    expect(gate?.shouldOfferUpgrade, isFalse);
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.allowed,
        currentUsage: 2,
        requestedDelta: 2,
        limit: 5,
        remainingAfterDelta: 2,
      ),
      isNull,
    );
  });

  test('Free limit reached decision exposes upgrade intent', () {
    final HouseholdFeatureGate? gate = _gate(
      householdId: householdId,
      decision: HouseholdFeatureGateDecision.limitReached,
      currentUsage: 2,
      limit: 2,
      remainingAfterDelta: 0,
      plan: EntitlementPlan.free,
      status: HouseholdEntitlementStatus.none,
    );

    expect(gate?.isAllowed, isFalse);
    expect(gate?.shouldOfferUpgrade, isTrue);
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.limitReached,
        currentUsage: 2,
        limit: 2,
        remainingAfterDelta: 1,
        plan: EntitlementPlan.free,
        status: HouseholdEntitlementStatus.none,
      ),
      isNull,
    );
  });

  test('fail-closed policy states never carry guessed limits', () {
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.policyUnavailable,
        enforcementEnabled: false,
        limitsFinalized: false,
        limit: null,
        remainingAfterDelta: null,
      ),
      isNotNull,
    );
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.policyUnavailable,
        enforcementEnabled: false,
        limitsFinalized: false,
        limit: 5,
        remainingAfterDelta: null,
      ),
      isNull,
    );
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.featureUnconfigured,
        enforcementEnabled: true,
        limitsFinalized: true,
        limit: null,
        remainingAfterDelta: null,
      ),
      isNotNull,
    );
  });

  test('versions timestamps and plan lifecycle combinations fail closed', () {
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.allowed,
        limit: 2,
        remainingAfterDelta: 1,
        entitlementVersion: 0,
      ),
      isNull,
    );
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.allowed,
        limit: 2,
        remainingAfterDelta: 1,
        evaluatedAt: DateTime(2026, 8, 8),
      ),
      isNull,
    );
    expect(
      _gate(
        householdId: householdId,
        decision: HouseholdFeatureGateDecision.allowed,
        limit: 2,
        remainingAfterDelta: 1,
        plan: EntitlementPlan.free,
        status: HouseholdEntitlementStatus.active,
      ),
      isNull,
    );
  });
}

HouseholdFeatureGate? _gate({
  required HouseholdId householdId,
  required HouseholdFeatureGateDecision decision,
  int requestedDelta = 1,
  int currentUsage = 0,
  int? limit,
  int? remainingAfterDelta,
  EntitlementPlan plan = EntitlementPlan.plus,
  HouseholdEntitlementStatus status = HouseholdEntitlementStatus.active,
  bool enforcementEnabled = true,
  bool limitsFinalized = true,
  int entitlementVersion = 2,
  int policyVersion = 3,
  int runtimeVersion = 4,
  DateTime? evaluatedAt,
}) {
  return HouseholdFeatureGate.tryCreate(
    decision: decision,
    householdId: householdId,
    featureKey: HouseholdFeatureKey.members,
    requestedDelta: requestedDelta,
    currentUsage: currentUsage,
    limit: limit,
    remainingAfterDelta: remainingAfterDelta,
    plan: plan,
    entitlementStatus: status,
    enforcementEnabled: enforcementEnabled,
    limitsFinalized: limitsFinalized,
    entitlementVersion: entitlementVersion,
    policyVersion: policyVersion,
    runtimeVersion: runtimeVersion,
    evaluatedAt: evaluatedAt ?? DateTime.parse('2026-08-08T00:00:00Z'),
  );
}
