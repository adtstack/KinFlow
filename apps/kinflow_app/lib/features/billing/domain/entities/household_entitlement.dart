import 'dart:collection';

import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _featureKeyPattern = RegExp(r'^[a-z][A-Za-z0-9]{0,63}$');

enum EntitlementPlan {
  free('free'),
  plus('plus');

  const EntitlementPlan(this.wireValue);

  final String wireValue;

  static EntitlementPlan? tryParse(String value) {
    for (final EntitlementPlan plan in values) {
      if (plan.wireValue == value) return plan;
    }
    return null;
  }
}

enum HouseholdEntitlementStatus {
  none('none'),
  trialing('trialing'),
  active('active'),
  grace('grace'),
  billingIssue('billing_issue'),
  expired('expired'),
  revoked('revoked');

  const HouseholdEntitlementStatus(this.wireValue);

  final String wireValue;

  static HouseholdEntitlementStatus? tryParse(String value) {
    for (final HouseholdEntitlementStatus status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

enum EntitlementSource {
  appStore('app_store'),
  playStore('play_store'),
  web('web'),
  manualSupport('manual_support'),
  none('none');

  const EntitlementSource(this.wireValue);

  final String wireValue;

  static EntitlementSource? tryParse(String value) {
    for (final EntitlementSource source in values) {
      if (source.wireValue == value) return source;
    }
    return null;
  }
}

enum HouseholdEntitlementLifecycleNotice {
  none,
  trialing,
  grace,
  billingIssue,
  expired,
  revoked,
}

final class HouseholdEntitlement {
  HouseholdEntitlement._({
    required this.householdId,
    required this.entitlementKey,
    required this.plan,
    required this.status,
    required this.source,
    required this.currentPeriodEnd,
    required this.willRenew,
    required Map<String, int> featureLimits,
    required this.limitsFinalized,
    required this.verifiedAt,
    required this.version,
    required this.isBillingOwner,
  }) : featureLimits = UnmodifiableMapView<String, int>(featureLimits);

  final HouseholdId householdId;
  final String entitlementKey;
  final EntitlementPlan plan;
  final HouseholdEntitlementStatus status;
  final EntitlementSource source;
  final DateTime? currentPeriodEnd;
  final bool willRenew;
  final Map<String, int> featureLimits;
  final bool limitsFinalized;
  final DateTime verifiedAt;
  final int version;
  final bool isBillingOwner;

  bool get hasPlus => plan == EntitlementPlan.plus;

  bool get hasUsablePlusBenefits =>
      plan == EntitlementPlan.plus &&
      (status == HouseholdEntitlementStatus.trialing ||
          status == HouseholdEntitlementStatus.active ||
          status == HouseholdEntitlementStatus.grace ||
          status == HouseholdEntitlementStatus.billingIssue);

  HouseholdEntitlementLifecycleNotice get lifecycleNotice => switch (status) {
    HouseholdEntitlementStatus.none || HouseholdEntitlementStatus.active =>
      HouseholdEntitlementLifecycleNotice.none,
    HouseholdEntitlementStatus.trialing =>
      HouseholdEntitlementLifecycleNotice.trialing,
    HouseholdEntitlementStatus.grace =>
      HouseholdEntitlementLifecycleNotice.grace,
    HouseholdEntitlementStatus.billingIssue =>
      HouseholdEntitlementLifecycleNotice.billingIssue,
    HouseholdEntitlementStatus.expired =>
      HouseholdEntitlementLifecycleNotice.expired,
    HouseholdEntitlementStatus.revoked =>
      HouseholdEntitlementLifecycleNotice.revoked,
  };

  bool get requiresBillingAttention =>
      status == HouseholdEntitlementStatus.grace ||
      status == HouseholdEntitlementStatus.billingIssue ||
      status == HouseholdEntitlementStatus.expired ||
      status == HouseholdEntitlementStatus.revoked;

  bool get usesFreeExpansionPolicy => plan == EntitlementPlan.free;

  bool get preservesExistingHouseholdData => true;

  bool get isTerminal =>
      status == HouseholdEntitlementStatus.expired ||
      status == HouseholdEntitlementStatus.revoked;

  int? limitFor(String featureKey) => featureLimits[featureKey];

  bool allowsAdditional({
    required String featureKey,
    required int currentUsage,
    int requested = 1,
  }) {
    final int? limit = featureLimits[featureKey];
    return limitsFinalized &&
        limit != null &&
        currentUsage >= 0 &&
        requested > 0 &&
        currentUsage + requested <= limit;
  }

  static HouseholdEntitlement? tryCreate({
    required HouseholdId householdId,
    required String entitlementKey,
    required EntitlementPlan plan,
    required HouseholdEntitlementStatus status,
    required EntitlementSource source,
    required DateTime? currentPeriodEnd,
    required bool willRenew,
    required Map<String, int> featureLimits,
    required bool limitsFinalized,
    required DateTime verifiedAt,
    required int version,
    required bool isBillingOwner,
  }) {
    if (entitlementKey != 'plus' ||
        !verifiedAt.isUtc ||
        currentPeriodEnd != null && !currentPeriodEnd.isUtc ||
        version < 1 ||
        !limitsFinalized && featureLimits.isNotEmpty ||
        limitsFinalized && featureLimits.isEmpty ||
        featureLimits.length > 64 ||
        featureLimits.entries.any(
          (MapEntry<String, int> entry) =>
              !_featureKeyPattern.hasMatch(entry.key) ||
              entry.value < 0 ||
              entry.value > 1000000,
        ) ||
        !isValidEntitlementPlanStatus(plan, status) ||
        !_validSourceStatus(source, status) ||
        (status == HouseholdEntitlementStatus.expired ||
                status == HouseholdEntitlementStatus.revoked) &&
            willRenew) {
      return null;
    }
    return HouseholdEntitlement._(
      householdId: householdId,
      entitlementKey: entitlementKey,
      plan: plan,
      status: status,
      source: source,
      currentPeriodEnd: currentPeriodEnd?.toUtc(),
      willRenew: willRenew,
      featureLimits: Map<String, int>.of(featureLimits),
      limitsFinalized: limitsFinalized,
      verifiedAt: verifiedAt.toUtc(),
      version: version,
      isBillingOwner: isBillingOwner,
    );
  }

  static bool _validSourceStatus(
    EntitlementSource source,
    HouseholdEntitlementStatus status,
  ) {
    return status == HouseholdEntitlementStatus.none
        ? source == EntitlementSource.none
        : source != EntitlementSource.none;
  }
}

bool isValidEntitlementPlanStatus(
  EntitlementPlan plan,
  HouseholdEntitlementStatus status,
) {
  return switch (status) {
    HouseholdEntitlementStatus.trialing ||
    HouseholdEntitlementStatus.active ||
    HouseholdEntitlementStatus.grace => plan == EntitlementPlan.plus,
    HouseholdEntitlementStatus.none ||
    HouseholdEntitlementStatus.expired ||
    HouseholdEntitlementStatus.revoked => plan == EntitlementPlan.free,
    HouseholdEntitlementStatus.billingIssue => true,
  };
}
