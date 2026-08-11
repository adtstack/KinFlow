import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';

import '../../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test('loads a validated dev configuration with stable correlation', () {
    final AppPublicConfiguration configuration =
        AppPublicConfigurationLoader(
          expectedEnvironment: AppEnvironment.dev,
        ).load(
          publicConfigurationValues(
            sentryDsn: 'https://publickey@o0.ingest.sentry.io/1',
          ),
        );

    expect(configuration.environment, AppEnvironment.dev);
    expect(configuration.applicationId, 'me.newlines.kinflow.dev');
    expect(configuration.release, 'me.newlines.kinflow.dev@0.1.0-dev+1');
    expect(configuration.contractVersion, '2026-07-25');
    expect(configuration.supabaseUri.host, '10.0.2.2');
    expect(configuration.isSentryEnabled, isTrue);
  });

  test('accepts only the public Google Web client ID shape', () {
    const String clientId = '1234567890-kinflowdev.apps.googleusercontent.com';
    final AppPublicConfiguration configuration = publicConfigurationFixture(
      googleWebClientId: clientId,
    );

    expect(configuration.googleWebClientId, clientId);

    final Map<String, String> invalid = publicConfigurationValues(
      googleWebClientId: 'not-a-google-client-id',
    );
    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(invalid),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.single.stableCode,
          'stable issue',
          'invalidFormat:GOOGLE_WEB_CLIENT_ID',
        ),
      ),
    );
  });

  test('accepts Android/Test Store public keys and rejects secret keys', () {
    final AppPublicConfiguration android = publicConfigurationFixture(
      revenueCatAndroidPublicSdkKey: 'goog_12345678901',
    );
    final AppPublicConfiguration testStore = publicConfigurationFixture(
      revenueCatAndroidPublicSdkKey: 'test_12345678901',
    );

    expect(android.revenueCatAndroidPublicSdkKey, 'goog_12345678901');
    expect(testStore.revenueCatAndroidPublicSdkKey, 'test_12345678901');

    final Map<String, String> productionTestStore = publicConfigurationValues(
      environment: AppEnvironment.prod,
      revenueCatAndroidPublicSdkKey: 'test_12345678901',
    );
    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.prod,
      ).load(productionTestStore),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.single.stableCode,
          'stable issue',
          'invalidFormat:REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
        ),
      ),
    );

    final Map<String, String> secret = publicConfigurationValues(
      revenueCatAndroidPublicSdkKey: 'sk_12345678901234567890',
    );
    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(secret),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.single.stableCode,
          'safe issue',
          'serverSecretPresent:REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
        ),
      ),
    );

    final Map<String, String> wrongPlatform = publicConfigurationValues(
      revenueCatAndroidPublicSdkKey: 'appl_12345678901',
    );
    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(wrongPlatform),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.single.stableCode,
          'stable issue',
          'invalidFormat:REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
        ),
      ),
    );
  });

  test('Firebase Android public options are optional but all-or-none', () {
    final Map<String, String> firebaseValues = <String, String>{
      AppPublicConfigurationKeys.firebaseAndroidApiKey:
          'AIza${List<String>.filled(35, 'A').join()}',
      AppPublicConfigurationKeys.firebaseAndroidAppId:
          '1:123456789012:android:abcdef1234567890',
      AppPublicConfigurationKeys.firebaseMessagingSenderId: '123456789012',
      AppPublicConfigurationKeys.firebaseProjectId: 'kinflow-dev',
    };
    final AppPublicConfiguration configured = publicConfigurationFixture(
      firebaseValues: firebaseValues,
    );
    expect(configured.firebaseAndroidOptions?.projectId, 'kinflow-dev');
    expect(publicConfigurationFixture().firebaseAndroidOptions, isNull);

    final Map<String, String> partial = publicConfigurationValues(
      firebaseValues: <String, String>{
        AppPublicConfigurationKeys.firebaseProjectId: 'kinflow-dev',
      },
    );
    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(partial),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) =>
              error.issues.map((AppConfigurationIssue issue) => issue.key),
          'missing Firebase keys',
          contains(AppPublicConfigurationKeys.firebaseAndroidApiKey),
        ),
      ),
    );
  });

  test('rejects environment identity mismatch without exposing values', () {
    final Map<String, String> values = publicConfigurationValues()
      ..[AppPublicConfigurationKeys.appEnvironment] = 'prod'
      ..[AppPublicConfigurationKeys.applicationId] =
          'sensitive.invalid.identifier';

    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(values),
      throwsA(
        isA<AppConfigurationException>()
            .having(
              (AppConfigurationException error) =>
                  error.issues.map((AppConfigurationIssue issue) => issue.code),
              'codes',
              containsAll(<AppConfigurationIssueCode>[
                AppConfigurationIssueCode.environmentMismatch,
                AppConfigurationIssueCode.applicationIdMismatch,
              ]),
            )
            .having(
              (AppConfigurationException error) => error.toString(),
              'safe output',
              isNot(contains('sensitive.invalid.identifier')),
            ),
      ),
    );
  });

  test('allows loopback HTTP only for dev and requires HTTPS in prod', () {
    final Map<String, String> prodValues = publicConfigurationValues(
      environment: AppEnvironment.prod,
    )..[AppPublicConfigurationKeys.supabaseUrl] = 'http://10.0.2.2:54321';

    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.prod,
      ).load(prodValues),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.any(
            (AppConfigurationIssue issue) =>
                issue.code == AppConfigurationIssueCode.insecureUri &&
                issue.key == AppPublicConfigurationKeys.supabaseUrl,
          ),
          'insecure URL issue',
          isTrue,
        ),
      ),
    );

    expect(publicConfigurationFixture().supabaseUri.scheme, 'http');
  });

  test('fails closed for runtime placeholders and server-only values', () {
    final Map<String, String> values = publicConfigurationValues()
      ..[AppPublicConfigurationKeys.supabasePublishableKey] =
          'replace-with-environment-key'
      ..['SUPABASE_SERVICE_ROLE_KEY'] = 'fixture-value-never-reported';

    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(values),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) =>
              error.issues.map((AppConfigurationIssue issue) => issue.code),
          'codes',
          containsAll(<AppConfigurationIssueCode>[
            AppConfigurationIssueCode.placeholderValue,
            AppConfigurationIssueCode.serverSecretPresent,
          ]),
        ),
      ),
    );
  });

  test('rejects every extra key even when its value is empty', () {
    final Map<String, String> values = publicConfigurationValues()
      ..['UNDECLARED_PUBLIC_VALUE'] = '';

    expect(
      () => const AppPublicConfigurationLoader(
        expectedEnvironment: AppEnvironment.dev,
      ).load(values),
      throwsA(
        isA<AppConfigurationException>().having(
          (AppConfigurationException error) => error.issues.single.code,
          'code',
          AppConfigurationIssueCode.unknownKey,
        ),
      ),
    );
  });

  for (final (String path, AppEnvironment environment)
      in <(String, AppEnvironment)>[
        ('config/dev.example.json', AppEnvironment.dev),
        ('config/prod.example.json', AppEnvironment.prod),
      ]) {
    test('$path contains only the exact public allowlist', () {
      final Object? decoded = jsonDecode(File(path).readAsStringSync());
      final Map<String, String> values = (decoded! as Map<String, Object?>).map(
        (String key, Object? value) =>
            MapEntry<String, String>(key, value! as String),
      );

      expect(values.keys.toSet(), AppPublicConfigurationKeys.allowed);
      expect(
        values.keys.toSet().intersection(AppPublicConfigurationKeys.serverOnly),
        isEmpty,
      );

      final AppPublicConfiguration configuration = AppPublicConfigurationLoader(
        allowPlaceholders: true,
        expectedEnvironment: environment,
      ).load(values);
      expect(configuration.environment, environment);
      expect(configuration.isSentryEnabled, isFalse);
      expect(configuration.googleWebClientId, isNull);
    });
  }

  test('machine-readable schema stays aligned with the runtime allowlist', () {
    final Object? decoded = jsonDecode(
      File(
        '../../contracts/client-public-config.schema.json',
      ).readAsStringSync(),
    );
    final Map<String, Object?> schema = decoded! as Map<String, Object?>;
    final Map<String, Object?> properties =
        schema['properties']! as Map<String, Object?>;
    final Set<String> required = (schema['required']! as List<Object?>)
        .cast<String>()
        .toSet();

    expect(schema['additionalProperties'], isFalse);
    expect(properties.keys.toSet(), AppPublicConfigurationKeys.allowed);
    expect(required, AppPublicConfigurationKeys.allowed);
  });
}
