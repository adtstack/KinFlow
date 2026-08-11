import 'dart:collection';

final RegExp _storeIdentifierPattern = RegExp(
  r'^[A-Za-z0-9$][A-Za-z0-9$._:-]{0,254}$',
);
final RegExp _controlCharacterPattern = RegExp(r'[\u0000-\u001F\u007F]');

enum BillingPeriodUnit { day, week, month, year }

final class BillingPeriod {
  const BillingPeriod._({required this.count, required this.unit});

  final int count;
  final BillingPeriodUnit unit;

  static BillingPeriod? tryCreate({
    required int count,
    required BillingPeriodUnit unit,
  }) {
    return count >= 1 && count <= 365
        ? BillingPeriod._(count: count, unit: unit)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingPeriod && other.count == count && other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(count, unit);
}

final class BillingOfferingId {
  const BillingOfferingId._(this.value);

  final String value;

  static BillingOfferingId? tryParse(String value) {
    return _validIdentifier(value) ? BillingOfferingId._(value) : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingOfferingId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class BillingPackageId {
  const BillingPackageId._(this.value);

  final String value;

  static BillingPackageId? tryParse(String value) {
    return _validIdentifier(value) ? BillingPackageId._(value) : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingPackageId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class BillingProductId {
  const BillingProductId._(this.value);

  final String value;

  static BillingProductId? tryParse(String value) {
    return _validIdentifier(value) ? BillingProductId._(value) : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingProductId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class LocalizedStorePrice {
  const LocalizedStorePrice._(this.value);

  final String value;

  static LocalizedStorePrice? tryParse(String value) {
    return _validDisplayText(value, maximumLength: 80)
        ? LocalizedStorePrice._(value)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is LocalizedStorePrice && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class BillingPackage {
  const BillingPackage._({
    required this.id,
    required this.productId,
    required this.localizedPrice,
    required this.period,
  });

  final BillingPackageId id;
  final BillingProductId productId;
  final LocalizedStorePrice localizedPrice;
  final BillingPeriod period;

  static BillingPackage? tryCreate({
    required String id,
    required String productId,
    required String localizedPrice,
    required int periodCount,
    required BillingPeriodUnit periodUnit,
  }) {
    final BillingPackageId? parsedId = BillingPackageId.tryParse(id);
    final BillingProductId? parsedProductId = BillingProductId.tryParse(
      productId,
    );
    final LocalizedStorePrice? parsedPrice = LocalizedStorePrice.tryParse(
      localizedPrice,
    );
    final BillingPeriod? parsedPeriod = BillingPeriod.tryCreate(
      count: periodCount,
      unit: periodUnit,
    );
    return parsedId == null ||
            parsedProductId == null ||
            parsedPrice == null ||
            parsedPeriod == null
        ? null
        : BillingPackage._(
            id: parsedId,
            productId: parsedProductId,
            localizedPrice: parsedPrice,
            period: parsedPeriod,
          );
  }
}

final class StoreOffering {
  StoreOffering._({required this.id, required List<BillingPackage> packages})
    : packages = UnmodifiableListView<BillingPackage>(packages);

  final BillingOfferingId id;
  final List<BillingPackage> packages;

  static StoreOffering? tryCreate({
    required String id,
    required List<BillingPackage> packages,
  }) {
    final BillingOfferingId? parsedId = BillingOfferingId.tryParse(id);
    if (parsedId == null || packages.isEmpty || packages.length > 16) {
      return null;
    }
    final Set<BillingPackageId> packageIds = <BillingPackageId>{};
    final Set<BillingProductId> productIds = <BillingProductId>{};
    for (final BillingPackage package in packages) {
      if (!packageIds.add(package.id) || !productIds.add(package.productId)) {
        return null;
      }
    }
    return StoreOffering._(
      id: parsedId,
      packages: List<BillingPackage>.of(packages),
    );
  }

  BillingPackage? packageById(BillingPackageId id) {
    for (final BillingPackage package in packages) {
      if (package.id == id) return package;
    }
    return null;
  }
}

final class BillingCatalog {
  BillingCatalog._({
    required this.currentOfferingId,
    required List<StoreOffering> offerings,
  }) : offerings = UnmodifiableListView<StoreOffering>(offerings);

  final BillingOfferingId currentOfferingId;
  final List<StoreOffering> offerings;

  StoreOffering get currentOffering {
    return offerings.singleWhere(
      (StoreOffering offering) => offering.id == currentOfferingId,
    );
  }

  BillingPackage? packageById(BillingPackageId id) {
    return currentOffering.packageById(id);
  }

  static BillingCatalog? tryCreate({
    required String currentOfferingId,
    required List<StoreOffering> offerings,
  }) {
    final BillingOfferingId? parsedCurrent = BillingOfferingId.tryParse(
      currentOfferingId,
    );
    if (parsedCurrent == null || offerings.isEmpty || offerings.length > 8) {
      return null;
    }
    final Set<BillingOfferingId> offeringIds = <BillingOfferingId>{};
    for (final StoreOffering offering in offerings) {
      if (!offeringIds.add(offering.id)) return null;
    }
    if (!offeringIds.contains(parsedCurrent)) return null;
    return BillingCatalog._(
      currentOfferingId: parsedCurrent,
      offerings: List<StoreOffering>.of(offerings),
    );
  }
}

bool _validIdentifier(String value) {
  return value == value.trim() && _storeIdentifierPattern.hasMatch(value);
}

bool _validDisplayText(String value, {required int maximumLength}) {
  return value == value.trim() &&
      value.isNotEmpty &&
      value.length <= maximumLength &&
      !_controlCharacterPattern.hasMatch(value);
}
