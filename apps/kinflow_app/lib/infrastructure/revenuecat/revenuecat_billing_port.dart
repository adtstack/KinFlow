import 'dart:async';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';

typedef RevenueCatBillingClock = DateTime Function();

final class RevenueCatBillingPort
    implements BillingPort, SensitiveLocalStatePurgeParticipant {
  RevenueCatBillingPort({
    required String publicSdkKey,
    required RevenueCatSdk sdk,
    RevenueCatBillingClock clock = DateTime.now,
  }) : this._(publicSdkKey, sdk, clock);

  RevenueCatBillingPort._(this._publicSdkKey, this._sdk, this._clock) {
    _sdk.addCustomerInfoListener(_onCustomerInfoUpdated);
  }

  final String _publicSdkKey;
  final RevenueCatSdk _sdk;
  final RevenueCatBillingClock _clock;
  final StreamController<BillingClientSnapshot> _snapshots =
      StreamController<BillingClientSnapshot>.broadcast(sync: true);

  AuthUserId? _boundUserId;
  BillingCatalog? _catalog;
  var _bindingGeneration = 0;
  var _disposed = false;

  @override
  bool get isAvailable => !_disposed && _publicSdkKey.isNotEmpty;

  @override
  Stream<BillingClientSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<BillingIdentityResult> bindIdentity(AuthUserId userId) async {
    if (!isAvailable) {
      return const BillingIdentityFailed(
        BillingFailure(BillingFailureKind.unsupported),
      );
    }
    final int generation = _bindingGeneration;
    try {
      final bool configured = await _sdk.isConfigured();
      if (!configured) {
        await _sdk.configure(
          publicSdkKey: _publicSdkKey,
          appUserId: userId.value,
        );
      } else {
        final RevenueCatIdentitySnapshot current = await _sdk.currentIdentity();
        if (current.isAnonymous) {
          _clearLocalBinding();
          return const BillingIdentityFailed(
            BillingFailure(BillingFailureKind.identityConflict),
          );
        }
        if (current.appUserId != userId.value) {
          await _sdk.logIn(userId.value);
        }
      }
      final RevenueCatIdentitySnapshot verified = await _sdk.currentIdentity();
      if (_disposed || generation != _bindingGeneration) {
        return const BillingIdentityFailed(
          BillingFailure(BillingFailureKind.unauthenticated),
        );
      }
      if (verified.isAnonymous || verified.appUserId != userId.value) {
        _clearLocalBinding();
        return const BillingIdentityFailed(
          BillingFailure(BillingFailureKind.identityConflict),
        );
      }
      _boundUserId = userId;
      _catalog = null;
      return BillingIdentityBound(userId);
    } on RevenueCatSdkException catch (error) {
      _clearLocalBinding();
      return BillingIdentityFailed(_billingFailure(error.kind));
    } on Object {
      _clearLocalBinding();
      return const BillingIdentityFailed(
        BillingFailure(BillingFailureKind.unknown),
      );
    }
  }

  @override
  Future<BillingCatalogResult> loadCatalog() async {
    if (!isAvailable) {
      return const BillingCatalogFailed(
        BillingFailure(BillingFailureKind.unsupported),
      );
    }
    if (_boundUserId == null) {
      return const BillingCatalogFailed(
        BillingFailure(BillingFailureKind.unauthenticated),
      );
    }
    try {
      final RevenueCatOfferingSnapshot? current =
          (await _sdk.getOfferings()).current;
      final BillingCatalog? catalog = _mapCatalog(current);
      if (catalog == null) {
        _catalog = null;
        return const BillingCatalogFailed(
          BillingFailure(BillingFailureKind.catalogUnavailable),
        );
      }
      _catalog = catalog;
      return BillingCatalogLoaded(catalog);
    } on RevenueCatSdkException catch (error) {
      _catalog = null;
      return BillingCatalogFailed(_billingFailure(error.kind));
    } on Object {
      _catalog = null;
      return const BillingCatalogFailed(
        BillingFailure(BillingFailureKind.catalogUnavailable),
      );
    }
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    final AuthUserId? boundUserId = _boundUserId;
    final BillingCatalog? catalog = _catalog;
    if (!isAvailable) {
      return const BillingPurchaseFailed(
        BillingFailure(BillingFailureKind.unsupported),
      );
    }
    if (boundUserId == null) {
      return const BillingPurchaseFailed(
        BillingFailure(BillingFailureKind.unauthenticated),
      );
    }
    if (request.context.userId != boundUserId) {
      return const BillingPurchaseFailed(
        BillingFailure(BillingFailureKind.identityConflict),
      );
    }
    final BillingPackage? cached = catalog?.packageById(request.package.id);
    if (catalog == null ||
        cached == null ||
        !_samePackage(cached, request.package)) {
      return const BillingPurchaseFailed(
        BillingFailure(BillingFailureKind.invalidInput),
      );
    }
    try {
      await _sdk.purchasePackage(
        offeringId: catalog.currentOfferingId.value,
        packageId: cached.id.value,
        productId: cached.productId.value,
      );
      return const BillingPurchaseStoreSucceeded();
    } on RevenueCatSdkException catch (error) {
      return switch (error.kind) {
        RevenueCatSdkFailureKind.cancelled => const BillingPurchaseCancelled(),
        RevenueCatSdkFailureKind.pending => const BillingPurchasePending(),
        _ => BillingPurchaseFailed(_billingFailure(error.kind)),
      };
    } on Object {
      return const BillingPurchaseFailed(
        BillingFailure(BillingFailureKind.unknown),
      );
    }
  }

  @override
  Future<BillingRestoreResult> restore(BillingOperationContext context) async {
    final AuthUserId? boundUserId = _boundUserId;
    if (!isAvailable) {
      return const BillingRestoreFailed(
        BillingFailure(BillingFailureKind.unsupported),
      );
    }
    if (boundUserId == null) {
      return const BillingRestoreFailed(
        BillingFailure(BillingFailureKind.unauthenticated),
      );
    }
    if (context.userId != boundUserId) {
      return const BillingRestoreFailed(
        BillingFailure(BillingFailureKind.identityConflict),
      );
    }
    try {
      final RevenueCatRestoreSnapshot restored = await _sdk.restorePurchases();
      return restored.hasStoreRecords
          ? const BillingRestoreStoreRecordsFound()
          : const BillingRestoreEmpty();
    } on RevenueCatSdkException catch (error) {
      return switch (error.kind) {
        RevenueCatSdkFailureKind.conflict => const BillingRestoreConflict(),
        RevenueCatSdkFailureKind.pending => const BillingRestorePending(),
        _ => BillingRestoreFailed(_billingFailure(error.kind)),
      };
    } on Object {
      return const BillingRestoreFailed(
        BillingFailure(BillingFailureKind.unknown),
      );
    }
  }

  @override
  Future<BillingIdentityClearResult> clearIdentity() async {
    _bindingGeneration += 1;
    _clearLocalBinding();
    return const BillingIdentityCleared();
  }

  @override
  Future<void> purgeSensitiveLocalState() async {
    final BillingIdentityClearResult result = await clearIdentity();
    if (result is! BillingIdentityCleared) {
      throw StateError('billing identity clear failed');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _bindingGeneration += 1;
    _clearLocalBinding();
    _sdk.removeCustomerInfoListener(_onCustomerInfoUpdated);
    await _snapshots.close();
  }

  void _onCustomerInfoUpdated() {
    final AuthUserId? boundUserId = _boundUserId;
    if (_disposed || boundUserId == null) return;
    final BillingClientSnapshot? snapshot = BillingClientSnapshot.tryCreate(
      boundUserId: boundUserId,
      change: BillingClientChange.storeStateChanged,
      observedAt: _clock().toUtc(),
    );
    if (snapshot != null) _snapshots.add(snapshot);
  }

  void _clearLocalBinding() {
    _boundUserId = null;
    _catalog = null;
  }
}

BillingCatalog? _mapCatalog(RevenueCatOfferingSnapshot? current) {
  if (current == null) return null;
  final List<BillingPackage> packages = <BillingPackage>[];
  for (final RevenueCatPackageSnapshot package in current.packages) {
    final (int, BillingPeriodUnit)? period = _parsePeriod(
      package.subscriptionPeriod,
    );
    if (period == null) return null;
    final BillingPackage? mapped = BillingPackage.tryCreate(
      id: package.id,
      productId: package.productId,
      localizedPrice: package.localizedPrice,
      periodCount: period.$1,
      periodUnit: period.$2,
    );
    if (mapped == null) return null;
    packages.add(mapped);
  }
  final StoreOffering? offering = StoreOffering.tryCreate(
    id: current.id,
    packages: packages,
  );
  return offering == null
      ? null
      : BillingCatalog.tryCreate(
          currentOfferingId: current.id,
          offerings: <StoreOffering>[offering],
        );
}

final RegExp _subscriptionPeriodPattern = RegExp(
  r'^P([1-9][0-9]{0,2})([DWMY])$',
);

(int, BillingPeriodUnit)? _parsePeriod(String? value) {
  if (value == null) return null;
  final RegExpMatch? match = _subscriptionPeriodPattern.firstMatch(value);
  if (match == null) return null;
  final int count = int.parse(match.group(1)!);
  final BillingPeriodUnit unit = switch (match.group(2)) {
    'D' => BillingPeriodUnit.day,
    'W' => BillingPeriodUnit.week,
    'M' => BillingPeriodUnit.month,
    'Y' => BillingPeriodUnit.year,
    _ => throw StateError('unreachable billing period unit'),
  };
  return (count, unit);
}

bool _samePackage(BillingPackage left, BillingPackage right) {
  return left.id == right.id &&
      left.productId == right.productId &&
      left.localizedPrice == right.localizedPrice &&
      left.period == right.period;
}

BillingFailure _billingFailure(RevenueCatSdkFailureKind kind) {
  return BillingFailure(switch (kind) {
    RevenueCatSdkFailureKind.networkUnavailable =>
      BillingFailureKind.networkUnavailable,
    RevenueCatSdkFailureKind.storeUnavailable ||
    RevenueCatSdkFailureKind.pending ||
    RevenueCatSdkFailureKind.cancelled => BillingFailureKind.storeUnavailable,
    RevenueCatSdkFailureKind.purchaseNotAllowed ||
    RevenueCatSdkFailureKind.invalidConfiguration =>
      BillingFailureKind.providerRejected,
    RevenueCatSdkFailureKind.conflict => BillingFailureKind.identityConflict,
    RevenueCatSdkFailureKind.invalidInput => BillingFailureKind.invalidInput,
    RevenueCatSdkFailureKind.unsupported => BillingFailureKind.unsupported,
    RevenueCatSdkFailureKind.unknown => BillingFailureKind.unknown,
  });
}
