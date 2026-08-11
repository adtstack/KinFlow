import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_billing_port.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';

void main() {
  group('RevenueCatBillingPort identity', () {
    test(
      'first bind configures once with the exact authenticated UUID',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);

        final BillingIdentityResult result = await port.bindIdentity(_userOne);

        expect(result, isA<BillingIdentityBound>());
        expect((result as BillingIdentityBound).userId, _userOne);
        expect(sdk.configureCalls, <(String, String)>[
          ('goog_12345678901', _userOne.value),
        ]);
        expect(sdk.loginCalls, isEmpty);
        expect(sdk.identity?.isAnonymous, isFalse);
      },
    );

    test('configured custom identity switches through exact login', () async {
      final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk(
        configured: true,
        identity: RevenueCatIdentitySnapshot(
          appUserId: _userTwo.value,
          isAnonymous: false,
        ),
      );
      final RevenueCatBillingPort port = _port(sdk);
      addTearDown(port.dispose);

      expect(await port.bindIdentity(_userOne), isA<BillingIdentityBound>());
      expect(sdk.configureCalls, isEmpty);
      expect(sdk.loginCalls, <String>[_userOne.value]);
      expect(sdk.identity?.appUserId, _userOne.value);
    });

    test(
      'anonymous configured SDK fails closed without attempting a merge',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk(
          configured: true,
          identity: const RevenueCatIdentitySnapshot(
            appUserId: r'$RCAnonymousID:fixture',
            isAnonymous: true,
          ),
        );
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);

        final BillingIdentityFailed result =
            await port.bindIdentity(_userOne) as BillingIdentityFailed;

        expect(result.failure.kind, BillingFailureKind.identityConflict);
        expect(sdk.loginCalls, isEmpty);
        expect(await port.loadCatalog(), isA<BillingCatalogFailed>());
      },
    );

    test(
      'returned identity mismatch is rejected and local state is detached',
      () async {
        final _FakeRevenueCatSdk sdk =
            _FakeRevenueCatSdk(
                configured: true,
                identity: RevenueCatIdentitySnapshot(
                  appUserId: _userTwo.value,
                  isAnonymous: false,
                ),
              )
              ..loginIdentityOverride = RevenueCatIdentitySnapshot(
                appUserId: _userTwo.value,
                isAnonymous: false,
              );
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);

        final BillingIdentityFailed result =
            await port.bindIdentity(_userOne) as BillingIdentityFailed;

        expect(result.failure.kind, BillingFailureKind.identityConflict);
        expect(
          (await port.loadCatalog() as BillingCatalogFailed).failure.kind,
          BillingFailureKind.unauthenticated,
        );
      },
    );

    test(
      'clear only detaches local state and next authenticated bind logs in',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);
        await port.bindIdentity(_userOne);
        await port.loadCatalog();

        expect(await port.clearIdentity(), isA<BillingIdentityCleared>());
        expect(
          (await port.loadCatalog() as BillingCatalogFailed).failure.kind,
          BillingFailureKind.unauthenticated,
        );

        expect(await port.bindIdentity(_userTwo), isA<BillingIdentityBound>());
        expect(sdk.configureCalls, hasLength(1));
        expect(sdk.loginCalls, <String>[_userTwo.value]);
      },
    );
  });

  group('RevenueCatBillingPort catalog and purchase', () {
    test(
      'maps current offering local price and ISO periods without SDK types',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);
        await port.bindIdentity(_userOne);

        final BillingCatalogLoaded result =
            await port.loadCatalog() as BillingCatalogLoaded;

        expect(result.catalog.currentOffering.id.value, 'plus_default');
        expect(result.catalog.currentOffering.packages, hasLength(2));
        expect(
          result.catalog.currentOffering.packages.first.id.value,
          'monthly',
        );
        expect(
          result.catalog.currentOffering.packages.first.localizedPrice.value,
          '₩4,900',
        );
        expect(
          result.catalog.currentOffering.packages.first.period,
          BillingPeriod.tryCreate(count: 1, unit: BillingPeriodUnit.month),
        );
        expect(
          result.catalog.currentOffering.packages.last.period,
          BillingPeriod.tryCreate(count: 1, unit: BillingPeriodUnit.year),
        );
      },
    );

    test('rejects absent and malformed current offerings', () async {
      final List<RevenueCatOfferingSnapshot?> invalid =
          <RevenueCatOfferingSnapshot?>[
            null,
            RevenueCatOfferingSnapshot(
              id: 'plus_default',
              packages: const <RevenueCatPackageSnapshot>[],
            ),
            RevenueCatOfferingSnapshot(
              id: 'plus_default',
              packages: const <RevenueCatPackageSnapshot>[
                RevenueCatPackageSnapshot(
                  id: 'monthly',
                  productId: 'kinflow.plus.monthly',
                  localizedPrice: '₩4,900',
                  subscriptionPeriod: 'P0M',
                ),
              ],
            ),
          ];

      for (final RevenueCatOfferingSnapshot? offering in invalid) {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk(
          offerings: RevenueCatOfferingsSnapshot(current: offering),
        );
        final RevenueCatBillingPort port = _port(sdk);
        await port.bindIdentity(_userOne);

        final BillingCatalogFailed result =
            await port.loadCatalog() as BillingCatalogFailed;
        expect(result.failure.kind, BillingFailureKind.catalogUnavailable);
        await port.dispose();
      }
    });

    test(
      'purchases only the exact package cached by the loaded catalog',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);
        await port.bindIdentity(_userOne);
        final BillingCatalog catalog =
            (await port.loadCatalog() as BillingCatalogLoaded).catalog;
        final BillingPackage monthly = catalog.currentOffering.packages.first;

        expect(
          await port.purchase(
            BillingPurchaseRequest(context: _contextOne, package: monthly),
          ),
          isA<BillingPurchaseStoreSucceeded>(),
        );
        expect(sdk.purchaseCalls, <(String, String, String)>[
          ('plus_default', 'monthly', 'kinflow.plus.monthly'),
        ]);

        final BillingPackage tampered = BillingPackage.tryCreate(
          id: monthly.id.value,
          productId: monthly.productId.value,
          localizedPrice: '₩1',
          periodCount: 1,
          periodUnit: BillingPeriodUnit.month,
        )!;
        final BillingPurchaseFailed invalid =
            await port.purchase(
                  BillingPurchaseRequest(
                    context: _contextOne,
                    package: tampered,
                  ),
                )
                as BillingPurchaseFailed;
        expect(invalid.failure.kind, BillingFailureKind.invalidInput);
        expect(sdk.purchaseCalls, hasLength(1));
      },
    );

    test(
      'rejects mismatching operation identity before SDK purchase',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        addTearDown(port.dispose);
        await port.bindIdentity(_userOne);
        final BillingPackage package =
            (await port.loadCatalog() as BillingCatalogLoaded)
                .catalog
                .currentOffering
                .packages
                .first;

        final BillingPurchaseFailed result =
            await port.purchase(
                  BillingPurchaseRequest(
                    context: BillingOperationContext(
                      userId: _userTwo,
                      householdId: _householdOne,
                    ),
                    package: package,
                  ),
                )
                as BillingPurchaseFailed;

        expect(result.failure.kind, BillingFailureKind.identityConflict);
        expect(sdk.purchaseCalls, isEmpty);
      },
    );

    test('maps purchase cancellation, pending and stable failures', () async {
      final Map<RevenueCatSdkFailureKind, Object> expectations =
          <RevenueCatSdkFailureKind, Object>{
            RevenueCatSdkFailureKind.cancelled: isA<BillingPurchaseCancelled>(),
            RevenueCatSdkFailureKind.pending: isA<BillingPurchasePending>(),
            RevenueCatSdkFailureKind.networkUnavailable:
                isA<BillingPurchaseFailed>().having(
                  (BillingPurchaseFailed value) => value.failure.kind,
                  'failure',
                  BillingFailureKind.networkUnavailable,
                ),
            RevenueCatSdkFailureKind.purchaseNotAllowed:
                isA<BillingPurchaseFailed>().having(
                  (BillingPurchaseFailed value) => value.failure.kind,
                  'failure',
                  BillingFailureKind.providerRejected,
                ),
          };

      for (final MapEntry<RevenueCatSdkFailureKind, Object> entry
          in expectations.entries) {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = _port(sdk);
        await port.bindIdentity(_userOne);
        final BillingPackage package =
            (await port.loadCatalog() as BillingCatalogLoaded)
                .catalog
                .currentOffering
                .packages
                .first;
        sdk.purchaseFailure = entry.key;

        expect(
          await port.purchase(
            BillingPurchaseRequest(context: _contextOne, package: package),
          ),
          entry.value,
        );
        await port.dispose();
      }
    });
  });

  group('RevenueCatBillingPort restore and invalidation', () {
    test(
      'maps restore records, empty, conflict, pending and network',
      () async {
        final List<(bool, RevenueCatSdkFailureKind?, Object)> cases =
            <(bool, RevenueCatSdkFailureKind?, Object)>[
              (true, null, isA<BillingRestoreStoreRecordsFound>()),
              (false, null, isA<BillingRestoreEmpty>()),
              (
                false,
                RevenueCatSdkFailureKind.conflict,
                isA<BillingRestoreConflict>(),
              ),
              (
                false,
                RevenueCatSdkFailureKind.pending,
                isA<BillingRestorePending>(),
              ),
              (
                false,
                RevenueCatSdkFailureKind.networkUnavailable,
                isA<BillingRestoreFailed>().having(
                  (BillingRestoreFailed value) => value.failure.kind,
                  'failure',
                  BillingFailureKind.networkUnavailable,
                ),
              ),
            ];

        for (final (
              bool records,
              RevenueCatSdkFailureKind? failure,
              Object matcher,
            )
            in cases) {
          final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk()
            ..restoreRecords = records
            ..restoreFailure = failure;
          final RevenueCatBillingPort port = _port(sdk);
          await port.bindIdentity(_userOne);

          expect(await port.restore(_contextOne), matcher);
          await port.dispose();
        }
      },
    );

    test(
      'emits redacted bound-user invalidation only while locally bound',
      () async {
        final _FakeRevenueCatSdk sdk = _FakeRevenueCatSdk();
        final RevenueCatBillingPort port = RevenueCatBillingPort(
          publicSdkKey: 'goog_12345678901',
          sdk: sdk,
          clock: () => DateTime(2026, 8, 8, 12, 30),
        );
        final List<BillingClientSnapshot> snapshots = <BillingClientSnapshot>[];
        final StreamSubscription<BillingClientSnapshot> subscription = port
            .snapshots
            .listen(snapshots.add);

        sdk.emitCustomerInfoUpdate();
        await port.bindIdentity(_userOne);
        sdk.emitCustomerInfoUpdate();
        await port.clearIdentity();
        sdk.emitCustomerInfoUpdate();

        expect(snapshots, hasLength(1));
        expect(snapshots.single.boundUserId, _userOne);
        expect(snapshots.single.change, BillingClientChange.storeStateChanged);
        expect(snapshots.single.observedAt.isUtc, isTrue);
        expect(
          snapshots.single.observedAt,
          DateTime(2026, 8, 8, 12, 30).toUtc(),
        );

        await subscription.cancel();
        await port.dispose();
        expect(sdk.listeners, isEmpty);
      },
    );
  });
}

RevenueCatBillingPort _port(_FakeRevenueCatSdk sdk) {
  return RevenueCatBillingPort(
    publicSdkKey: 'goog_12345678901',
    sdk: sdk,
    clock: () => DateTime.utc(2026, 8, 8),
  );
}

final AuthUserId _userOne = AuthUserId.tryParse(
  '11111111-1111-4111-8111-111111111111',
)!;
final AuthUserId _userTwo = AuthUserId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
final HouseholdId _householdOne = HouseholdId.tryParse(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
)!;
final BillingOperationContext _contextOne = BillingOperationContext(
  userId: _userOne,
  householdId: _householdOne,
);

RevenueCatOfferingsSnapshot _offerings() {
  return RevenueCatOfferingsSnapshot(
    current: RevenueCatOfferingSnapshot(
      id: 'plus_default',
      packages: const <RevenueCatPackageSnapshot>[
        RevenueCatPackageSnapshot(
          id: 'monthly',
          productId: 'kinflow.plus.monthly',
          localizedPrice: '₩4,900',
          subscriptionPeriod: 'P1M',
        ),
        RevenueCatPackageSnapshot(
          id: 'annual',
          productId: 'kinflow.plus.annual',
          localizedPrice: '₩49,000',
          subscriptionPeriod: 'P1Y',
        ),
      ],
    ),
  );
}

final class _FakeRevenueCatSdk implements RevenueCatSdk {
  _FakeRevenueCatSdk({
    this.configured = false,
    this.identity,
    RevenueCatOfferingsSnapshot? offerings,
  }) : offerings = offerings ?? _offerings();

  bool configured;
  RevenueCatIdentitySnapshot? identity;
  RevenueCatIdentitySnapshot? loginIdentityOverride;
  RevenueCatOfferingsSnapshot offerings;
  RevenueCatSdkFailureKind? configureFailure;
  RevenueCatSdkFailureKind? catalogFailure;
  RevenueCatSdkFailureKind? purchaseFailure;
  RevenueCatSdkFailureKind? restoreFailure;
  bool restoreRecords = true;
  final List<(String, String)> configureCalls = <(String, String)>[];
  final List<String> loginCalls = <String>[];
  final List<(String, String, String)> purchaseCalls =
      <(String, String, String)>[];
  final Set<RevenueCatCustomerInfoListener> listeners =
      <RevenueCatCustomerInfoListener>{};

  @override
  Future<bool> isConfigured() async => configured;

  @override
  Future<void> configure({
    required String publicSdkKey,
    required String appUserId,
  }) async {
    _throwIfNeeded(configureFailure);
    configureCalls.add((publicSdkKey, appUserId));
    configured = true;
    identity = RevenueCatIdentitySnapshot(
      appUserId: appUserId,
      isAnonymous: false,
    );
  }

  @override
  Future<RevenueCatIdentitySnapshot> currentIdentity() async {
    return identity ??
        (throw const RevenueCatSdkException(
          RevenueCatSdkFailureKind.invalidConfiguration,
        ));
  }

  @override
  Future<RevenueCatIdentitySnapshot> logIn(String appUserId) async {
    loginCalls.add(appUserId);
    identity =
        loginIdentityOverride ??
        RevenueCatIdentitySnapshot(appUserId: appUserId, isAnonymous: false);
    return identity!;
  }

  @override
  Future<RevenueCatOfferingsSnapshot> getOfferings() async {
    _throwIfNeeded(catalogFailure);
    return offerings;
  }

  @override
  Future<void> purchasePackage({
    required String offeringId,
    required String packageId,
    required String productId,
  }) async {
    purchaseCalls.add((offeringId, packageId, productId));
    _throwIfNeeded(purchaseFailure);
  }

  @override
  Future<RevenueCatRestoreSnapshot> restorePurchases() async {
    _throwIfNeeded(restoreFailure);
    return RevenueCatRestoreSnapshot(hasStoreRecords: restoreRecords);
  }

  @override
  void addCustomerInfoListener(RevenueCatCustomerInfoListener listener) {
    listeners.add(listener);
  }

  @override
  void removeCustomerInfoListener(RevenueCatCustomerInfoListener listener) {
    listeners.remove(listener);
  }

  void emitCustomerInfoUpdate() {
    for (final RevenueCatCustomerInfoListener listener
        in List<RevenueCatCustomerInfoListener>.of(listeners)) {
      listener();
    }
  }

  void _throwIfNeeded(RevenueCatSdkFailureKind? failure) {
    if (failure != null) throw RevenueCatSdkException(failure);
  }
}
