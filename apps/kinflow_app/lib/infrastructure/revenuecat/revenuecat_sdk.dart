typedef RevenueCatCustomerInfoListener = void Function();

enum RevenueCatSdkFailureKind {
  cancelled,
  pending,
  networkUnavailable,
  storeUnavailable,
  purchaseNotAllowed,
  invalidConfiguration,
  conflict,
  invalidInput,
  unsupported,
  unknown,
}

final class RevenueCatSdkException implements Exception {
  const RevenueCatSdkException(this.kind);

  final RevenueCatSdkFailureKind kind;

  @override
  String toString() => 'RevenueCatSdkException(${kind.name})';
}

final class RevenueCatIdentitySnapshot {
  const RevenueCatIdentitySnapshot({
    required this.appUserId,
    required this.isAnonymous,
  });

  final String appUserId;
  final bool isAnonymous;
}

final class RevenueCatPackageSnapshot {
  const RevenueCatPackageSnapshot({
    required this.id,
    required this.productId,
    required this.localizedPrice,
    required this.subscriptionPeriod,
  });

  final String id;
  final String productId;
  final String localizedPrice;
  final String? subscriptionPeriod;
}

final class RevenueCatOfferingSnapshot {
  RevenueCatOfferingSnapshot({
    required this.id,
    required List<RevenueCatPackageSnapshot> packages,
  }) : packages = List<RevenueCatPackageSnapshot>.unmodifiable(packages);

  final String id;
  final List<RevenueCatPackageSnapshot> packages;
}

final class RevenueCatOfferingsSnapshot {
  const RevenueCatOfferingsSnapshot({required this.current});

  final RevenueCatOfferingSnapshot? current;
}

final class RevenueCatRestoreSnapshot {
  const RevenueCatRestoreSnapshot({required this.hasStoreRecords});

  final bool hasStoreRecords;
}

abstract interface class RevenueCatSdk {
  Future<bool> isConfigured();

  Future<void> configure({
    required String publicSdkKey,
    required String appUserId,
  });

  Future<RevenueCatIdentitySnapshot> currentIdentity();

  Future<RevenueCatIdentitySnapshot> logIn(String appUserId);

  Future<RevenueCatOfferingsSnapshot> getOfferings();

  Future<void> purchasePackage({
    required String offeringId,
    required String packageId,
    required String productId,
  });

  Future<RevenueCatRestoreSnapshot> restorePurchases();

  void addCustomerInfoListener(RevenueCatCustomerInfoListener listener);

  void removeCustomerInfoListener(RevenueCatCustomerInfoListener listener);
}
