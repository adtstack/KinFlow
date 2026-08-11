import 'dart:async';
import 'dart:collection';

import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_controller.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_confirmation_delay.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final AuthUserId subscriptionTestUserId = AuthUserId.tryParse(
  '71000000-0000-4000-8000-000000000001',
)!;
final HouseholdId subscriptionTestHouseholdId = HouseholdId.tryParse(
  '72000000-0000-4000-8000-000000000001',
)!;

final BillingPackage subscriptionMonthlyPackage = BillingPackage.tryCreate(
  id: r'$rc_monthly',
  productId: 'kinflow.plus.monthly',
  localizedPrice: '₩4,900',
  periodCount: 1,
  periodUnit: BillingPeriodUnit.month,
)!;

BillingCatalog subscriptionCatalogFixture() {
  return BillingCatalog.tryCreate(
    currentOfferingId: 'current',
    offerings: <StoreOffering>[
      StoreOffering.tryCreate(
        id: 'current',
        packages: <BillingPackage>[subscriptionMonthlyPackage],
      )!,
    ],
  )!;
}

HouseholdEntitlement subscriptionFreeEntitlementFixture({int version = 1}) {
  return HouseholdEntitlement.tryCreate(
    householdId: subscriptionTestHouseholdId,
    entitlementKey: 'plus',
    plan: EntitlementPlan.free,
    status: HouseholdEntitlementStatus.none,
    source: EntitlementSource.none,
    currentPeriodEnd: null,
    willRenew: false,
    featureLimits: const <String, int>{},
    limitsFinalized: false,
    verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
    version: version,
    isBillingOwner: false,
  )!;
}

HouseholdEntitlement subscriptionPlusEntitlementFixture({
  EntitlementSource source = EntitlementSource.playStore,
  HouseholdEntitlementStatus status = HouseholdEntitlementStatus.active,
  bool billingOwner = true,
  bool willRenew = true,
  int version = 2,
}) {
  final EntitlementPlan plan = switch (status) {
    HouseholdEntitlementStatus.expired ||
    HouseholdEntitlementStatus.revoked => EntitlementPlan.free,
    _ => EntitlementPlan.plus,
  };
  return HouseholdEntitlement.tryCreate(
    householdId: subscriptionTestHouseholdId,
    entitlementKey: 'plus',
    plan: plan,
    status: status,
    source: source,
    currentPeriodEnd: DateTime.parse('2026-09-08T00:00:00Z'),
    willRenew:
        status == HouseholdEntitlementStatus.expired ||
            status == HouseholdEntitlementStatus.revoked
        ? false
        : willRenew,
    featureLimits: const <String, int>{'members': 10},
    limitsFinalized: true,
    verifiedAt: DateTime.parse('2026-08-08T00:01:00Z'),
    version: version,
    isBillingOwner: billingOwner,
  )!;
}

final class SubscriptionTestHarness {
  SubscriptionTestHarness({
    bool storeAvailable = true,
    BillingCatalogResult? catalogResult,
    BillingPurchaseResult purchaseResult = const BillingPurchaseCancelled(),
    BillingRestoreResult restoreResult = const BillingRestoreEmpty(),
    BillingAssignmentPrepareOutcome prepareOutcome =
        BillingAssignmentPrepareOutcome.ready,
    List<EntitlementResult<HouseholdEntitlement>>? entitlementResults,
  }) : port = FakeSubscriptionBillingPort(
         isAvailable: storeAvailable,
         catalogResult:
             catalogResult ??
             BillingCatalogLoaded(subscriptionCatalogFixture()),
         purchaseResult: purchaseResult,
         restoreResult: restoreResult,
       ),
       assignmentRepository = FakeSubscriptionAssignmentRepository(
         prepareOutcome,
       ),
       entitlementRepository = FakeSubscriptionEntitlementRepository(
         entitlementResults ??
             <EntitlementResult<HouseholdEntitlement>>[
               EntitlementSucceeded<HouseholdEntitlement>(
                 subscriptionFreeEntitlementFixture(),
               ),
             ],
       ) {
    controller = BillingFlowController(
      port: port,
      assignmentRepository: assignmentRepository,
      assignmentCommandIdGenerator:
          FakeSubscriptionAssignmentCommandIdGenerator(),
      entitlementRepository: entitlementRepository,
      confirmationDelay: const ImmediateSubscriptionConfirmationDelay(),
      confirmationPolicy: BillingConfirmationPolicy.tryCreate(
        const <Duration>[],
      )!,
    );
  }

  final FakeSubscriptionBillingPort port;
  final FakeSubscriptionAssignmentRepository assignmentRepository;
  final FakeSubscriptionEntitlementRepository entitlementRepository;
  late final BillingFlowController controller;

  Future<void> ready() {
    return controller.synchronize(
      userId: subscriptionTestUserId,
      householdId: subscriptionTestHouseholdId,
    );
  }

  Future<void> dispose() async {
    await controller.dispose();
    await port.dispose();
  }
}

final class FakeSubscriptionBillingPort implements BillingPort {
  FakeSubscriptionBillingPort({
    required this.isAvailable,
    required this.catalogResult,
    required this.purchaseResult,
    required this.restoreResult,
  });

  @override
  final bool isAvailable;
  final BillingCatalogResult catalogResult;
  final BillingPurchaseResult purchaseResult;
  final BillingRestoreResult restoreResult;
  final StreamController<BillingClientSnapshot> _snapshots =
      StreamController<BillingClientSnapshot>.broadcast(sync: true);
  final List<BillingPurchaseRequest> purchaseRequests =
      <BillingPurchaseRequest>[];
  final List<BillingOperationContext> restoreContexts =
      <BillingOperationContext>[];

  @override
  Stream<BillingClientSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<BillingIdentityResult> bindIdentity(AuthUserId userId) async {
    return BillingIdentityBound(userId);
  }

  @override
  Future<BillingCatalogResult> loadCatalog() async => catalogResult;

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    purchaseRequests.add(request);
    return purchaseResult;
  }

  @override
  Future<BillingRestoreResult> restore(BillingOperationContext context) async {
    restoreContexts.add(context);
    return restoreResult;
  }

  @override
  Future<BillingIdentityClearResult> clearIdentity() async {
    return const BillingIdentityCleared();
  }

  Future<void> dispose() => _snapshots.close();
}

final class FakeSubscriptionAssignmentRepository
    implements BillingAssignmentRepository {
  FakeSubscriptionAssignmentRepository(this.prepareOutcome);

  final BillingAssignmentPrepareOutcome prepareOutcome;
  var prepareCount = 0;
  var remediationCount = 0;

  @override
  Future<BillingAssignmentResult<BillingAssignmentPreparation>> prepare({
    required HouseholdId householdId,
    required BillingAssignmentCommandId commandId,
  }) async {
    prepareCount += 1;
    final bool ready = prepareOutcome.isReady;
    return BillingAssignmentSucceeded<BillingAssignmentPreparation>(
      BillingAssignmentPreparation.tryCreate(
        intentId: '87000000-0000-4000-8000-000000000001',
        outcome: prepareOutcome,
        bindingState: ready ? BillingAssignmentBindingState.provisional : null,
        assignmentVersion: ready ? 1 : null,
        intentExpiresAt: ready ? DateTime.parse('2026-08-08T01:00:00Z') : null,
        requeuedJobCount: 0,
        duplicate: false,
      )!,
    );
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRelease>> release({
    required HouseholdId householdId,
    required int expectedAssignmentVersion,
    required BillingAssignmentCommandId commandId,
  }) async {
    return BillingAssignmentSucceeded<BillingAssignmentRelease>(
      BillingAssignmentRelease(
        outcome: BillingAssignmentReleaseOutcome.released,
        assignmentVersion: expectedAssignmentVersion + 1,
        duplicate: false,
      ),
    );
  }

  @override
  Future<BillingAssignmentResult<BillingHouseholdAssignmentStatus>> status(
    HouseholdId householdId,
  ) async {
    return BillingAssignmentSucceeded<BillingHouseholdAssignmentStatus>(
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId,
        assignmentState: BillingAssignmentState.none,
        ownershipState: BillingAssignmentOwnershipState.unassigned,
        ownerMembershipState: BillingAssignmentOwnerMembershipState.none,
        canPrepare: true,
        requiresSupport: false,
        assignmentVersion: null,
        intentExpiresAt: null,
      )!,
    );
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRemediationRequest>>
  requestRemediation({
    required HouseholdId householdId,
    required BillingAssignmentRemediationIssue issue,
    required BillingAssignmentCommandId commandId,
  }) async {
    remediationCount += 1;
    return BillingAssignmentSucceeded<BillingAssignmentRemediationRequest>(
      BillingAssignmentRemediationRequest.tryCreate(
        requestId: '88000000-0000-4000-8000-000000000001',
        status: BillingAssignmentRemediationStatus.open,
        issue: issue,
        duplicate: false,
      )!,
    );
  }
}

final class FakeSubscriptionAssignmentCommandIdGenerator
    implements BillingAssignmentCommandIdGenerator {
  var _counter = 1;

  @override
  BillingAssignmentCommandId generate() {
    final String suffix = _counter.toString().padLeft(12, '0');
    _counter += 1;
    return BillingAssignmentCommandId.tryParse(
      '86000000-0000-4000-8000-$suffix',
    )!;
  }
}

final class FakeSubscriptionEntitlementRepository
    implements EntitlementRepository {
  FakeSubscriptionEntitlementRepository(
    List<EntitlementResult<HouseholdEntitlement>> results,
  ) : _results = Queue<EntitlementResult<HouseholdEntitlement>>.of(results);

  final Queue<EntitlementResult<HouseholdEntitlement>> _results;

  @override
  Future<EntitlementResult<HouseholdEntitlement>> load(
    HouseholdId householdId,
  ) async {
    if (_results.isEmpty) {
      return EntitlementSucceeded<HouseholdEntitlement>(
        subscriptionFreeEntitlementFixture(),
      );
    }
    return _results.removeFirst();
  }
}

final class ImmediateSubscriptionConfirmationDelay
    implements BillingConfirmationDelay {
  const ImmediateSubscriptionConfirmationDelay();

  @override
  Future<void> wait(Duration duration) async {}
}

final class FakeBillingExternalLinkLauncher
    implements BillingExternalLinkLauncher {
  FakeBillingExternalLinkLauncher({
    this.result = BillingExternalLinkLaunchResult.opened,
  });

  BillingExternalLinkLaunchResult result;
  final List<BillingExternalLink> links = <BillingExternalLink>[];

  @override
  Future<BillingExternalLinkLaunchResult> launch(
    BillingExternalLink link,
  ) async {
    links.add(link);
    return result;
  }
}
