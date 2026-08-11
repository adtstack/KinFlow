import 'package:flutter/foundation.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_port.dart';
import 'package:kinflow_app/infrastructure/revenuecat/purchases_flutter_revenuecat_sdk.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_billing_port.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';

BillingPort createRevenueCatBillingPort({
  required AppPublicConfiguration configuration,
  RevenueCatSdk? sdk,
  bool? isAndroidRuntime,
}) {
  final bool androidRuntime =
      isAndroidRuntime ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final String? publicSdkKey = configuration.revenueCatAndroidPublicSdkKey;
  if (!androidRuntime || publicSdkKey == null) {
    return const UnavailableBillingPort();
  }
  return RevenueCatBillingPort(
    publicSdkKey: publicSdkKey,
    sdk: sdk ?? PurchasesFlutterRevenueCatSdk(),
  );
}
