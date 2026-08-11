import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';

void main() {
  test('catalog transports immutable store-localized values', () {
    final BillingPackage monthly = _package(
      id: r'$rc_monthly',
      productId: 'kinflow.plus.monthly',
      localizedPrice: '₩4,900',
      periodCount: 1,
      periodUnit: BillingPeriodUnit.month,
    );
    final List<BillingPackage> source = <BillingPackage>[monthly];
    final StoreOffering? offering = StoreOffering.tryCreate(
      id: 'current',
      packages: source,
    );
    final BillingCatalog? catalog = BillingCatalog.tryCreate(
      currentOfferingId: 'current',
      offerings: <StoreOffering>[offering!],
    );

    expect(catalog, isNotNull);
    expect(
      catalog!.currentOffering.packages.single.localizedPrice.value,
      '₩4,900',
    );
    expect(catalog.currentOffering.packages.single.period.count, 1);
    expect(
      catalog.currentOffering.packages.single.period.unit,
      BillingPeriodUnit.month,
    );
    source.clear();
    expect(catalog.currentOffering.packages, hasLength(1));
    expect(
      () => catalog.currentOffering.packages.add(monthly),
      throwsUnsupportedError,
    );
  });

  test('package rejects guessed or malformed store values', () {
    expect(
      BillingPackage.tryCreate(
        id: ' monthly',
        productId: 'kinflow.plus.monthly',
        localizedPrice: '₩4,900',
        periodCount: 1,
        periodUnit: BillingPeriodUnit.month,
      ),
      isNull,
    );
    expect(
      BillingPackage.tryCreate(
        id: 'monthly',
        productId: 'bad product id',
        localizedPrice: '₩4,900',
        periodCount: 1,
        periodUnit: BillingPeriodUnit.month,
      ),
      isNull,
    );
    expect(
      BillingPackage.tryCreate(
        id: 'monthly',
        productId: 'kinflow.plus.monthly',
        localizedPrice: 'USD\n4.99',
        periodCount: 1,
        periodUnit: BillingPeriodUnit.month,
      ),
      isNull,
    );
    expect(
      BillingPackage.tryCreate(
        id: 'monthly',
        productId: 'kinflow.plus.monthly',
        localizedPrice: r'$4.99',
        periodCount: 0,
        periodUnit: BillingPeriodUnit.month,
      ),
      isNull,
    );
  });

  test('offering and catalog reject ambiguous duplicate bindings', () {
    final BillingPackage monthly = _package(
      id: 'monthly',
      productId: 'kinflow.plus.monthly',
    );
    final BillingPackage duplicateProduct = _package(
      id: 'monthly_alias',
      productId: 'kinflow.plus.monthly',
    );

    expect(
      StoreOffering.tryCreate(
        id: 'current',
        packages: <BillingPackage>[monthly, monthly],
      ),
      isNull,
    );
    expect(
      StoreOffering.tryCreate(
        id: 'current',
        packages: <BillingPackage>[monthly, duplicateProduct],
      ),
      isNull,
    );
    final StoreOffering offering = StoreOffering.tryCreate(
      id: 'current',
      packages: <BillingPackage>[monthly],
    )!;
    expect(
      BillingCatalog.tryCreate(
        currentOfferingId: 'missing',
        offerings: <StoreOffering>[offering],
      ),
      isNull,
    );
    expect(
      BillingCatalog.tryCreate(
        currentOfferingId: 'current',
        offerings: <StoreOffering>[offering, offering],
      ),
      isNull,
    );
  });
}

BillingPackage _package({
  required String id,
  required String productId,
  String localizedPrice = r'$4.99',
  int periodCount = 1,
  BillingPeriodUnit periodUnit = BillingPeriodUnit.month,
}) {
  return BillingPackage.tryCreate(
    id: id,
    productId: productId,
    localizedPrice: localizedPrice,
    periodCount: periodCount,
    periodUnit: periodUnit,
  )!;
}
