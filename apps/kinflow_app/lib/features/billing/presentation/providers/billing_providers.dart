import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_controller.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_state.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_confirmation_delay.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_port.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/billing/application/unavailable_entitlement_repository.dart';
import 'package:kinflow_app/features/billing/application/unavailable_household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final billingPortProvider = Provider<BillingPort>((ref) {
  return const UnavailableBillingPort();
});

final billingExternalLinkLauncherProvider =
    Provider<BillingExternalLinkLauncher>((ref) {
      return const UnavailableBillingExternalLinkLauncher();
    });

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return const UnavailableEntitlementRepository();
});

final householdFeatureGateRepositoryProvider =
    Provider<HouseholdFeatureGateRepository>((ref) {
      return const UnavailableHouseholdFeatureGateRepository();
    });

final billingAssignmentRepositoryProvider =
    Provider<BillingAssignmentRepository>((ref) {
      return const UnavailableBillingAssignmentRepository();
    });

final billingAssignmentCommandIdGeneratorProvider =
    Provider<BillingAssignmentCommandIdGenerator>((ref) {
      return const UnavailableBillingAssignmentCommandIdGenerator();
    });

final billingFlowControllerProvider = Provider<BillingFlowController>((ref) {
  final BillingFlowController controller = BillingFlowController(
    port: ref.watch(billingPortProvider),
    assignmentRepository: ref.watch(billingAssignmentRepositoryProvider),
    assignmentCommandIdGenerator: ref.watch(
      billingAssignmentCommandIdGeneratorProvider,
    ),
    entitlementRepository: ref.watch(entitlementRepositoryProvider),
    confirmationDelay: const SystemBillingConfirmationDelay(),
    confirmationPolicy: _defaultConfirmationPolicy,
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

final billingFlowProvider =
    NotifierProvider<BillingFlowNotifier, BillingFlowState>(
      BillingFlowNotifier.new,
    );

final class BillingFlowNotifier extends Notifier<BillingFlowState> {
  @override
  BillingFlowState build() {
    final BillingFlowController controller = ref.watch(
      billingFlowControllerProvider,
    );
    final StreamSubscription<BillingFlowState> subscription = controller.states
        .listen((BillingFlowState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> synchronize({
    required AuthUserId? userId,
    required HouseholdId? householdId,
  }) {
    return ref
        .read(billingFlowControllerProvider)
        .synchronize(userId: userId, householdId: householdId);
  }

  Future<void> purchase(BillingPackageId packageId) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.billing,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(billingFlowControllerProvider).purchase(packageId);
  }

  Future<void> restore() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.billing,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(billingFlowControllerProvider).restore();
  }

  Future<void> refreshServerStatus() {
    return ref.read(billingFlowControllerProvider).refreshServerStatus();
  }

  Future<void> requestAssignmentRemediation() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.billing,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(billingFlowControllerProvider)
        .requestAssignmentRemediation();
  }

  Future<HouseholdFeatureGateResult> evaluateFeatureGate(
    HouseholdFeatureGateRequest request,
  ) {
    return ref.read(householdFeatureGateRepositoryProvider).evaluate(request);
  }

  void returnToReady() {
    ref.read(billingFlowControllerProvider).returnToReady();
  }
}

final BillingConfirmationPolicy _defaultConfirmationPolicy =
    BillingConfirmationPolicy.tryCreate(const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ])!;
