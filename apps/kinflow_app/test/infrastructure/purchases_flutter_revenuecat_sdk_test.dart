import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/revenuecat/purchases_flutter_revenuecat_sdk.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('purchases_flutter');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'configure disables SDK diagnostics and automatic identifiers',
    () async {
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
      final PurchasesFlutterRevenueCatSdk sdk = PurchasesFlutterRevenueCatSdk();

      await sdk.configure(
        publicSdkKey: 'goog_12345678901',
        appUserId: '11111111-1111-4111-8111-111111111111',
      );

      expect(calls.map((MethodCall value) => value.method), <String>[
        'setLogLevel',
        'setupPurchases',
      ]);
      expect(calls.first.arguments, <String, Object?>{'level': 'ERROR'});
      final Map<Object?, Object?> setup =
          calls.last.arguments! as Map<Object?, Object?>;
      expect(setup['apiKey'], 'goog_12345678901');
      expect(setup['appUserId'], '11111111-1111-4111-8111-111111111111');
      expect(setup['automaticDeviceIdentifierCollectionEnabled'], isFalse);
      expect(setup['diagnosticsEnabled'], isFalse);
    },
  );

  test(
    'provider PlatformException becomes a message-free stable failure',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(
              code: '10',
              message: 'sensitive provider text',
            );
          });
      final PurchasesFlutterRevenueCatSdk sdk = PurchasesFlutterRevenueCatSdk();

      await expectLater(
        sdk.getOfferings(),
        throwsA(
          isA<RevenueCatSdkException>()
              .having(
                (RevenueCatSdkException value) => value.kind,
                'stable kind',
                RevenueCatSdkFailureKind.networkUnavailable,
              )
              .having(
                (RevenueCatSdkException value) => value.toString(),
                'redacted text',
                isNot(contains('sensitive provider text')),
              ),
        ),
      );
    },
  );
}
