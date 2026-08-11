import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '20000000-0000-4000-8000-000000000101',
  )!;

  test('wire enums preserve the server lifecycle contract', () {
    expect(EntitlementPlan.tryParse('plus'), EntitlementPlan.plus);
    expect(
      HouseholdEntitlementStatus.tryParse('billing_issue'),
      HouseholdEntitlementStatus.billingIssue,
    );
    expect(
      EntitlementSource.tryParse('play_store'),
      EntitlementSource.playStore,
    );
    expect(HouseholdEntitlementStatus.tryParse('grace_period'), isNull);
  });

  test('finalized Plus exposes immutable feature capacity', () {
    final Map<String, int> sourceLimits = <String, int>{
      'members': 10,
      'activeSeries': 100,
    };
    final HouseholdEntitlement? entitlement = HouseholdEntitlement.tryCreate(
      householdId: householdId,
      entitlementKey: 'plus',
      plan: EntitlementPlan.plus,
      status: HouseholdEntitlementStatus.active,
      source: EntitlementSource.playStore,
      currentPeriodEnd: DateTime.parse('2026-09-01T00:00:00Z'),
      willRenew: true,
      featureLimits: sourceLimits,
      limitsFinalized: true,
      verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
      version: 2,
      isBillingOwner: true,
    );

    expect(entitlement, isNotNull);
    expect(entitlement!.hasPlus, isTrue);
    expect(
      entitlement.allowsAdditional(featureKey: 'members', currentUsage: 9),
      isTrue,
    );
    expect(
      entitlement.allowsAdditional(featureKey: 'members', currentUsage: 10),
      isFalse,
    );
    expect(
      entitlement.allowsAdditional(
        featureKey: 'activeSeries',
        currentUsage: 98,
        requested: 2,
      ),
      isTrue,
    );
    sourceLimits['members'] = 1;
    expect(entitlement.limitFor('members'), 10);
    expect(
      () => entitlement.featureLimits['members'] = 1,
      throwsUnsupportedError,
    );
  });

  test('unfinalized Free state contains no guessed numeric policy', () {
    final HouseholdEntitlement? entitlement = HouseholdEntitlement.tryCreate(
      householdId: householdId,
      entitlementKey: 'plus',
      plan: EntitlementPlan.free,
      status: HouseholdEntitlementStatus.none,
      source: EntitlementSource.none,
      currentPeriodEnd: null,
      willRenew: false,
      featureLimits: const <String, int>{},
      limitsFinalized: false,
      verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
      version: 1,
      isBillingOwner: false,
    );

    expect(entitlement, isNotNull);
    expect(entitlement!.hasPlus, isFalse);
    expect(
      entitlement.allowsAdditional(featureKey: 'members', currentUsage: 0),
      isFalse,
    );
  });

  test('lifecycle notices and Plus benefit usability are explicit', () {
    const Map<HouseholdEntitlementStatus, HouseholdEntitlementLifecycleNotice>
    notices = <HouseholdEntitlementStatus, HouseholdEntitlementLifecycleNotice>{
      HouseholdEntitlementStatus.none: HouseholdEntitlementLifecycleNotice.none,
      HouseholdEntitlementStatus.trialing:
          HouseholdEntitlementLifecycleNotice.trialing,
      HouseholdEntitlementStatus.active:
          HouseholdEntitlementLifecycleNotice.none,
      HouseholdEntitlementStatus.grace:
          HouseholdEntitlementLifecycleNotice.grace,
      HouseholdEntitlementStatus.billingIssue:
          HouseholdEntitlementLifecycleNotice.billingIssue,
      HouseholdEntitlementStatus.expired:
          HouseholdEntitlementLifecycleNotice.expired,
      HouseholdEntitlementStatus.revoked:
          HouseholdEntitlementLifecycleNotice.revoked,
    };

    for (final MapEntry<
          HouseholdEntitlementStatus,
          HouseholdEntitlementLifecycleNotice
        >
        entry
        in notices.entries) {
      final bool plus =
          entry.key == HouseholdEntitlementStatus.trialing ||
          entry.key == HouseholdEntitlementStatus.active ||
          entry.key == HouseholdEntitlementStatus.grace ||
          entry.key == HouseholdEntitlementStatus.billingIssue;
      final HouseholdEntitlement entitlement = HouseholdEntitlement.tryCreate(
        householdId: householdId,
        entitlementKey: 'plus',
        plan: plus ? EntitlementPlan.plus : EntitlementPlan.free,
        status: entry.key,
        source: entry.key == HouseholdEntitlementStatus.none
            ? EntitlementSource.none
            : EntitlementSource.playStore,
        currentPeriodEnd: DateTime.parse('2026-09-01T00:00:00Z'),
        willRenew:
            entry.key != HouseholdEntitlementStatus.expired &&
            entry.key != HouseholdEntitlementStatus.revoked,
        featureLimits: const <String, int>{'members': 10},
        limitsFinalized: true,
        verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
        version: 2,
        isBillingOwner: false,
      )!;

      expect(entitlement.lifecycleNotice, entry.value);
      expect(
        entitlement.hasUsablePlusBenefits,
        plus,
        reason: entry.key.wireValue,
      );
      expect(
        entitlement.requiresBillingAttention,
        entry.key == HouseholdEntitlementStatus.grace ||
            entry.key == HouseholdEntitlementStatus.billingIssue ||
            entry.key == HouseholdEntitlementStatus.expired ||
            entry.key == HouseholdEntitlementStatus.revoked,
        reason: entry.key.wireValue,
      );
    }
  });

  test(
    'downgrade and terminal states preserve data but use Free expansion',
    () {
      for (final HouseholdEntitlementStatus status
          in <HouseholdEntitlementStatus>[
            HouseholdEntitlementStatus.expired,
            HouseholdEntitlementStatus.revoked,
          ]) {
        final HouseholdEntitlement entitlement = HouseholdEntitlement.tryCreate(
          householdId: householdId,
          entitlementKey: 'plus',
          plan: EntitlementPlan.free,
          status: status,
          source: EntitlementSource.playStore,
          currentPeriodEnd: DateTime.parse('2026-08-01T00:00:00Z'),
          willRenew: false,
          featureLimits: const <String, int>{'members': 2},
          limitsFinalized: true,
          verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
          version: 3,
          isBillingOwner: false,
        )!;

        expect(entitlement.isTerminal, isTrue);
        expect(entitlement.usesFreeExpansionPolicy, isTrue);
        expect(entitlement.preservesExistingHouseholdData, isTrue);
        expect(entitlement.hasUsablePlusBenefits, isFalse);
      }
    },
  );

  test('billing issue can retain Plus or fall back to Free policy', () {
    HouseholdEntitlement build(EntitlementPlan plan) {
      return HouseholdEntitlement.tryCreate(
        householdId: householdId,
        entitlementKey: 'plus',
        plan: plan,
        status: HouseholdEntitlementStatus.billingIssue,
        source: EntitlementSource.playStore,
        currentPeriodEnd: DateTime.parse('2026-09-01T00:00:00Z'),
        willRenew: true,
        featureLimits: const <String, int>{'members': 2},
        limitsFinalized: true,
        verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
        version: 3,
        isBillingOwner: false,
      )!;
    }

    expect(build(EntitlementPlan.plus).hasUsablePlusBenefits, isTrue);
    expect(build(EntitlementPlan.free).hasUsablePlusBenefits, isFalse);
    expect(build(EntitlementPlan.free).usesFreeExpansionPolicy, isTrue);
  });

  test('plan state source terminal and limit invariants fail closed', () {
    HouseholdEntitlement? build({
      EntitlementPlan plan = EntitlementPlan.plus,
      HouseholdEntitlementStatus status = HouseholdEntitlementStatus.active,
      EntitlementSource source = EntitlementSource.playStore,
      bool willRenew = true,
      Map<String, int> limits = const <String, int>{'members': 10},
      bool finalized = true,
    }) {
      return HouseholdEntitlement.tryCreate(
        householdId: householdId,
        entitlementKey: 'plus',
        plan: plan,
        status: status,
        source: source,
        currentPeriodEnd: DateTime.parse('2026-09-01T00:00:00Z'),
        willRenew: willRenew,
        featureLimits: limits,
        limitsFinalized: finalized,
        verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
        version: 1,
        isBillingOwner: false,
      );
    }

    expect(build(plan: EntitlementPlan.free), isNull);
    expect(build(source: EntitlementSource.none), isNull);
    expect(
      build(
        plan: EntitlementPlan.free,
        status: HouseholdEntitlementStatus.revoked,
        willRenew: true,
      ),
      isNull,
    );
    expect(build(limits: const <String, int>{}, finalized: true), isNull);
    expect(build(limits: const <String, int>{'Bad Key': 1}), isNull);
    expect(build(limits: const <String, int>{'members': 1000001}), isNull);
  });
}
