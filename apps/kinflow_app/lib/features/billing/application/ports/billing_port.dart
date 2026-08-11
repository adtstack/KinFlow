import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum BillingClientChange { storeStateChanged, identityChanged }

final class BillingClientSnapshot {
  const BillingClientSnapshot._({
    required this.boundUserId,
    required this.change,
    required this.observedAt,
  });

  final AuthUserId? boundUserId;
  final BillingClientChange change;
  final DateTime observedAt;

  static BillingClientSnapshot? tryCreate({
    required AuthUserId? boundUserId,
    required BillingClientChange change,
    required DateTime observedAt,
  }) {
    return observedAt.isUtc
        ? BillingClientSnapshot._(
            boundUserId: boundUserId,
            change: change,
            observedAt: observedAt,
          )
        : null;
  }
}

final class BillingOperationContext {
  const BillingOperationContext({
    required this.userId,
    required this.householdId,
  });

  final AuthUserId userId;
  final HouseholdId householdId;

  @override
  bool operator ==(Object other) {
    return other is BillingOperationContext &&
        other.userId == userId &&
        other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(userId, householdId);
}

final class BillingPurchaseRequest {
  const BillingPurchaseRequest({required this.context, required this.package});

  final BillingOperationContext context;
  final BillingPackage package;
}

abstract interface class BillingPort {
  bool get isAvailable;

  Stream<BillingClientSnapshot> get snapshots;

  Future<BillingIdentityResult> bindIdentity(AuthUserId userId);

  Future<BillingCatalogResult> loadCatalog();

  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request);

  Future<BillingRestoreResult> restore(BillingOperationContext context);

  Future<BillingIdentityClearResult> clearIdentity();
}

sealed class BillingIdentityResult {
  const BillingIdentityResult();
}

final class BillingIdentityBound extends BillingIdentityResult {
  const BillingIdentityBound(this.userId);

  final AuthUserId userId;
}

final class BillingIdentityFailed extends BillingIdentityResult {
  const BillingIdentityFailed(this.failure);

  final BillingFailure failure;
}

sealed class BillingCatalogResult {
  const BillingCatalogResult();
}

final class BillingCatalogLoaded extends BillingCatalogResult {
  const BillingCatalogLoaded(this.catalog);

  final BillingCatalog catalog;
}

final class BillingCatalogFailed extends BillingCatalogResult {
  const BillingCatalogFailed(this.failure);

  final BillingFailure failure;
}

sealed class BillingPurchaseResult {
  const BillingPurchaseResult();
}

final class BillingPurchaseStoreSucceeded extends BillingPurchaseResult {
  const BillingPurchaseStoreSucceeded();
}

final class BillingPurchaseCancelled extends BillingPurchaseResult {
  const BillingPurchaseCancelled();
}

final class BillingPurchasePending extends BillingPurchaseResult {
  const BillingPurchasePending();
}

final class BillingPurchaseFailed extends BillingPurchaseResult {
  const BillingPurchaseFailed(this.failure);

  final BillingFailure failure;
}

sealed class BillingRestoreResult {
  const BillingRestoreResult();
}

final class BillingRestoreStoreRecordsFound extends BillingRestoreResult {
  const BillingRestoreStoreRecordsFound();
}

final class BillingRestoreEmpty extends BillingRestoreResult {
  const BillingRestoreEmpty();
}

final class BillingRestoreConflict extends BillingRestoreResult {
  const BillingRestoreConflict();
}

final class BillingRestorePending extends BillingRestoreResult {
  const BillingRestorePending();
}

final class BillingRestoreFailed extends BillingRestoreResult {
  const BillingRestoreFailed(this.failure);

  final BillingFailure failure;
}

sealed class BillingIdentityClearResult {
  const BillingIdentityClearResult();
}

final class BillingIdentityCleared extends BillingIdentityClearResult {
  const BillingIdentityCleared();
}

final class BillingIdentityClearFailed extends BillingIdentityClearResult {
  const BillingIdentityClearFailed();
}
