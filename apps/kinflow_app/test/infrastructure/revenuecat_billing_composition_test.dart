import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_port.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_billing_composition.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_billing_port.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';

import '../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test('missing public key keeps billing explicitly unavailable', () {
    expect(
      createRevenueCatBillingPort(
        configuration: publicConfigurationFixture(),
        isAndroidRuntime: true,
      ),
      isA<UnavailableBillingPort>(),
    );
  });

  test('non-Android runtime never creates the concrete SDK adapter', () {
    expect(
      createRevenueCatBillingPort(
        configuration: publicConfigurationFixture(
          revenueCatAndroidPublicSdkKey: 'goog_12345678901',
        ),
        isAndroidRuntime: false,
      ),
      isA<UnavailableBillingPort>(),
    );
  });

  test('Android public key composes the provider-private adapter', () async {
    final _CompositionSdk sdk = _CompositionSdk();
    final port = createRevenueCatBillingPort(
      configuration: publicConfigurationFixture(
        revenueCatAndroidPublicSdkKey: 'goog_12345678901',
      ),
      sdk: sdk,
      isAndroidRuntime: true,
    );

    expect(port, isA<RevenueCatBillingPort>());
    expect(port.isAvailable, isTrue);

    await (port as RevenueCatBillingPort).dispose();
  });
}

final class _CompositionSdk implements RevenueCatSdk {
  @override
  Future<bool> isConfigured() async => false;

  @override
  Future<void> configure({
    required String publicSdkKey,
    required String appUserId,
  }) async {}

  @override
  Future<RevenueCatIdentitySnapshot> currentIdentity() {
    throw UnimplementedError();
  }

  @override
  Future<RevenueCatIdentitySnapshot> logIn(String appUserId) {
    throw UnimplementedError();
  }

  @override
  Future<RevenueCatOfferingsSnapshot> getOfferings() {
    throw UnimplementedError();
  }

  @override
  Future<void> purchasePackage({
    required String offeringId,
    required String packageId,
    required String productId,
  }) async {}

  @override
  Future<RevenueCatRestoreSnapshot> restorePurchases() {
    throw UnimplementedError();
  }

  @override
  void addCustomerInfoListener(RevenueCatCustomerInfoListener listener) {}

  @override
  void removeCustomerInfoListener(RevenueCatCustomerInfoListener listener) {}
}
