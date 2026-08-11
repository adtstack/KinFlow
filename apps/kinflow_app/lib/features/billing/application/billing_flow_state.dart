import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';

enum BillingOperationKind { purchase, restore }

enum BillingReadyNotice {
  purchaseCancelled,
  alreadyActive,
  purchaseServerConfirmed,
  restoreServerConfirmed,
  serverRefreshed,
}

final class BillingFlowSnapshot {
  const BillingFlowSnapshot({
    required this.context,
    required this.catalog,
    required this.entitlement,
    this.catalogFailure,
  });

  final BillingOperationContext context;
  final BillingCatalog? catalog;
  final HouseholdEntitlement entitlement;
  final BillingFailure? catalogFailure;

  bool get canPurchase => catalog != null && catalogFailure == null;

  BillingFlowSnapshot withEntitlement(HouseholdEntitlement value) {
    return BillingFlowSnapshot(
      context: context,
      catalog: catalog,
      entitlement: value,
      catalogFailure: catalogFailure,
    );
  }

  BillingFlowSnapshot withCatalog({
    required BillingCatalog? catalog,
    required BillingFailure? failure,
  }) {
    return BillingFlowSnapshot(
      context: context,
      catalog: catalog,
      entitlement: entitlement,
      catalogFailure: failure,
    );
  }
}

sealed class BillingFlowState {
  const BillingFlowState();

  BillingFlowSnapshot? get snapshot => switch (this) {
    BillingFlowReady(:final snapshot) => snapshot,
    BillingAssignmentPreparingState(:final snapshot) => snapshot,
    BillingAssignmentConflictState(:final snapshot) => snapshot,
    BillingFlowPurchasing(:final snapshot) => snapshot,
    BillingFlowRestoring(:final snapshot) => snapshot,
    BillingStorePendingState(:final snapshot) => snapshot,
    BillingServerConfirmationPendingState(:final snapshot) => snapshot,
    BillingRestoreEmptyState(:final snapshot) => snapshot,
    BillingRestoreConflictState(:final snapshot) => snapshot,
    BillingFlowFailed(:final snapshot) => snapshot,
    BillingFlowInitial() || BillingFlowLoading() => null,
  };

  BillingOperationContext? get context => switch (this) {
    BillingFlowLoading(:final context) => context,
    BillingFlowFailed(:final context) => context,
    _ => snapshot?.context,
  };
}

final class BillingFlowInitial extends BillingFlowState {
  const BillingFlowInitial();
}

final class BillingFlowLoading extends BillingFlowState {
  const BillingFlowLoading(this.context);

  @override
  final BillingOperationContext context;
}

final class BillingFlowReady extends BillingFlowState {
  const BillingFlowReady(this.snapshot, {this.notice, this.actionFailure});

  @override
  final BillingFlowSnapshot snapshot;
  final BillingReadyNotice? notice;
  final BillingFailure? actionFailure;
}

final class BillingAssignmentPreparingState extends BillingFlowState {
  const BillingAssignmentPreparingState(this.snapshot, this.operation);

  @override
  final BillingFlowSnapshot snapshot;
  final BillingOperationKind operation;
}

final class BillingAssignmentConflictState extends BillingFlowState {
  const BillingAssignmentConflictState({
    required this.snapshot,
    required this.operation,
    required this.issue,
    this.remediationRequest,
    this.remediationFailure,
  });

  @override
  final BillingFlowSnapshot snapshot;
  final BillingOperationKind operation;
  final BillingAssignmentRemediationIssue issue;
  final BillingAssignmentRemediationRequest? remediationRequest;
  final BillingFailure? remediationFailure;
}

final class BillingFlowPurchasing extends BillingFlowState {
  const BillingFlowPurchasing(this.snapshot, this.package);

  @override
  final BillingFlowSnapshot snapshot;
  final BillingPackage package;
}

final class BillingFlowRestoring extends BillingFlowState {
  const BillingFlowRestoring(this.snapshot);

  @override
  final BillingFlowSnapshot snapshot;
}

final class BillingStorePendingState extends BillingFlowState {
  const BillingStorePendingState(this.snapshot, this.operation);

  @override
  final BillingFlowSnapshot snapshot;
  final BillingOperationKind operation;
}

final class BillingServerConfirmationPendingState extends BillingFlowState {
  const BillingServerConfirmationPendingState({
    required this.snapshot,
    required this.operation,
    required this.attemptsCompleted,
    this.lastFailure,
  });

  @override
  final BillingFlowSnapshot snapshot;
  final BillingOperationKind operation;
  final int attemptsCompleted;
  final BillingFailure? lastFailure;
}

final class BillingRestoreEmptyState extends BillingFlowState {
  const BillingRestoreEmptyState(this.snapshot);

  @override
  final BillingFlowSnapshot snapshot;
}

final class BillingRestoreConflictState extends BillingFlowState {
  const BillingRestoreConflictState(
    this.snapshot, {
    this.remediationRequest,
    this.remediationFailure,
  });

  @override
  final BillingFlowSnapshot snapshot;
  final BillingAssignmentRemediationRequest? remediationRequest;
  final BillingFailure? remediationFailure;
}

final class BillingFlowFailed extends BillingFlowState {
  const BillingFlowFailed({
    required this.failure,
    this.context,
    this.snapshot,
    this.operation,
  });

  final BillingFailure failure;

  @override
  final BillingOperationContext? context;

  @override
  final BillingFlowSnapshot? snapshot;

  final BillingOperationKind? operation;
}
