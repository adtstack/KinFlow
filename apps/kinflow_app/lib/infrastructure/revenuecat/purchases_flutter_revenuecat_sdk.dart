import 'package:flutter/services.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final class PurchasesFlutterRevenueCatSdk implements RevenueCatSdk {
  final Map<_PackageKey, Package> _packages = <_PackageKey, Package>{};
  final Map<RevenueCatCustomerInfoListener, void Function(CustomerInfo)>
  _listeners = <RevenueCatCustomerInfoListener, void Function(CustomerInfo)>{};

  @override
  Future<bool> isConfigured() => _translate(() => Purchases.isConfigured);

  @override
  Future<void> configure({
    required String publicSdkKey,
    required String appUserId,
  }) {
    return _translate(() async {
      await Purchases.setLogLevel(LogLevel.error);
      final PurchasesConfiguration configuration =
          PurchasesConfiguration(publicSdkKey)
            ..appUserID = appUserId
            ..automaticDeviceIdentifierCollectionEnabled = false
            ..diagnosticsEnabled = false;
      await Purchases.configure(configuration);
    });
  }

  @override
  Future<RevenueCatIdentitySnapshot> currentIdentity() {
    return _translate(() async {
      final String appUserId = await Purchases.appUserID;
      final bool anonymous = await Purchases.isAnonymous;
      return RevenueCatIdentitySnapshot(
        appUserId: appUserId,
        isAnonymous: anonymous,
      );
    });
  }

  @override
  Future<RevenueCatIdentitySnapshot> logIn(String appUserId) {
    return _translate(() async {
      await Purchases.logIn(appUserId);
      return currentIdentity();
    });
  }

  @override
  Future<RevenueCatOfferingsSnapshot> getOfferings() {
    return _translate(() async {
      final Offerings offerings = await Purchases.getOfferings();
      final Offering? current = offerings.current;
      _packages.clear();
      if (current == null) {
        return const RevenueCatOfferingsSnapshot(current: null);
      }
      final List<RevenueCatPackageSnapshot> packages =
          <RevenueCatPackageSnapshot>[];
      for (final Package package in current.availablePackages) {
        final StoreProduct product = package.storeProduct;
        _packages[_PackageKey(
              offeringId: current.identifier,
              packageId: package.identifier,
              productId: product.identifier,
            )] =
            package;
        packages.add(
          RevenueCatPackageSnapshot(
            id: package.identifier,
            productId: product.identifier,
            localizedPrice: product.priceString,
            subscriptionPeriod: product.subscriptionPeriod,
          ),
        );
      }
      return RevenueCatOfferingsSnapshot(
        current: RevenueCatOfferingSnapshot(
          id: current.identifier,
          packages: packages,
        ),
      );
    });
  }

  @override
  Future<void> purchasePackage({
    required String offeringId,
    required String packageId,
    required String productId,
  }) {
    return _translate(() async {
      final Package? package =
          _packages[_PackageKey(
            offeringId: offeringId,
            packageId: packageId,
            productId: productId,
          )];
      if (package == null) {
        throw const RevenueCatSdkException(
          RevenueCatSdkFailureKind.invalidInput,
        );
      }
      await Purchases.purchase(PurchaseParams.package(package));
    });
  }

  @override
  Future<RevenueCatRestoreSnapshot> restorePurchases() {
    return _translate(() async {
      final CustomerInfo customerInfo = await Purchases.restorePurchases();
      return RevenueCatRestoreSnapshot(
        hasStoreRecords: customerInfo.allPurchasedProductIdentifiers.isNotEmpty,
      );
    });
  }

  @override
  void addCustomerInfoListener(RevenueCatCustomerInfoListener listener) {
    if (_listeners.containsKey(listener)) return;
    void sdkListener(CustomerInfo _) => listener();
    _listeners[listener] = sdkListener;
    Purchases.addCustomerInfoUpdateListener(sdkListener);
  }

  @override
  void removeCustomerInfoListener(RevenueCatCustomerInfoListener listener) {
    final void Function(CustomerInfo)? sdkListener = _listeners.remove(
      listener,
    );
    if (sdkListener != null) {
      Purchases.removeCustomerInfoUpdateListener(sdkListener);
    }
  }
}

final class _PackageKey {
  const _PackageKey({
    required this.offeringId,
    required this.packageId,
    required this.productId,
  });

  final String offeringId;
  final String packageId;
  final String productId;

  @override
  bool operator ==(Object other) {
    return other is _PackageKey &&
        other.offeringId == offeringId &&
        other.packageId == packageId &&
        other.productId == productId;
  }

  @override
  int get hashCode => Object.hash(offeringId, packageId, productId);
}

Future<T> _translate<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on RevenueCatSdkException {
    rethrow;
  } on PlatformException catch (error) {
    throw RevenueCatSdkException(_failureKind(error));
  } on UnsupportedPlatformException {
    throw const RevenueCatSdkException(RevenueCatSdkFailureKind.unsupported);
  } on ArgumentError {
    throw const RevenueCatSdkException(RevenueCatSdkFailureKind.invalidInput);
  } on Object {
    throw const RevenueCatSdkException(RevenueCatSdkFailureKind.unknown);
  }
}

RevenueCatSdkFailureKind _failureKind(PlatformException error) {
  final PurchasesErrorCode code;
  try {
    code = PurchasesErrorHelper.getErrorCode(error);
  } on Object {
    return RevenueCatSdkFailureKind.unknown;
  }
  return switch (code) {
    PurchasesErrorCode.purchaseCancelledError =>
      RevenueCatSdkFailureKind.cancelled,
    PurchasesErrorCode.paymentPendingError => RevenueCatSdkFailureKind.pending,
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.offlineConnectionError ||
    PurchasesErrorCode.apiEndpointBlocked =>
      RevenueCatSdkFailureKind.networkUnavailable,
    PurchasesErrorCode.storeProblemError ||
    PurchasesErrorCode.productNotAvailableForPurchaseError ||
    PurchasesErrorCode.productRequestTimeout ||
    PurchasesErrorCode.operationAlreadyInProgressError =>
      RevenueCatSdkFailureKind.storeUnavailable,
    PurchasesErrorCode.purchaseNotAllowedError ||
    PurchasesErrorCode.ineligibleError ||
    PurchasesErrorCode.insufficientPermissionsError =>
      RevenueCatSdkFailureKind.purchaseNotAllowed,
    PurchasesErrorCode.invalidCredentialsError ||
    PurchasesErrorCode.configurationError ||
    PurchasesErrorCode.invalidAppUserIdError =>
      RevenueCatSdkFailureKind.invalidConfiguration,
    PurchasesErrorCode.receiptAlreadyInUseError ||
    PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
    PurchasesErrorCode.purchaseBelongsToOtherUser =>
      RevenueCatSdkFailureKind.conflict,
    PurchasesErrorCode.purchaseInvalidError ||
    PurchasesErrorCode.invalidReceiptError ||
    PurchasesErrorCode.missingReceiptFileError ||
    PurchasesErrorCode.productAlreadyPurchasedError =>
      RevenueCatSdkFailureKind.invalidInput,
    PurchasesErrorCode.unsupportedError ||
    PurchasesErrorCode.featureNotAvailableInCustomEntitlementsComputationMode ||
    PurchasesErrorCode.featureNotSupportedWithStoreKit1 =>
      RevenueCatSdkFailureKind.unsupported,
    _ => RevenueCatSdkFailureKind.unknown,
  };
}
