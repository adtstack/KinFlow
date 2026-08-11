import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';

final class UnavailableBillingPort implements BillingPort {
  const UnavailableBillingPort();

  static const BillingFailure _unsupported = BillingFailure(
    BillingFailureKind.unsupported,
  );

  @override
  bool get isAvailable => false;

  @override
  Stream<BillingClientSnapshot> get snapshots =>
      const Stream<BillingClientSnapshot>.empty();

  @override
  Future<BillingIdentityResult> bindIdentity(AuthUserId userId) async {
    return const BillingIdentityFailed(_unsupported);
  }

  @override
  Future<BillingCatalogResult> loadCatalog() async {
    return const BillingCatalogFailed(_unsupported);
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    return const BillingPurchaseFailed(_unsupported);
  }

  @override
  Future<BillingRestoreResult> restore(BillingOperationContext context) async {
    return const BillingRestoreFailed(_unsupported);
  }

  @override
  Future<BillingIdentityClearResult> clearIdentity() async {
    return const BillingIdentityCleared();
  }
}
