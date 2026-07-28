import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';

Map<String, String> publicConfigurationValues({
  AppEnvironment environment = AppEnvironment.dev,
  String googleWebClientId = '',
  String sentryDsn = '',
}) {
  return <String, String>{
    AppPublicConfigurationKeys.appEnvironment: environment.value,
    AppPublicConfigurationKeys.applicationId: environment.applicationId,
    AppPublicConfigurationKeys.appVersion: environment.isProduction
        ? '0.1.0+1'
        : '0.1.0-dev+1',
    AppPublicConfigurationKeys.authRedirectHost: 'auth.example.invalid',
    AppPublicConfigurationKeys.contractVersion: '2026-07-25',
    AppPublicConfigurationKeys.featureConfigUrl: '',
    AppPublicConfigurationKeys.googleWebClientId: googleWebClientId,
    AppPublicConfigurationKeys.privacyRequestUrl:
        'https://example.invalid/privacy-request',
    AppPublicConfigurationKeys.publicSiteUrl: 'https://example.invalid',
    AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey: '',
    AppPublicConfigurationKeys.sentryDsn: sentryDsn,
    AppPublicConfigurationKeys.supabasePublishableKey:
        'sb_publishable_12345678901234567890',
    AppPublicConfigurationKeys.supabaseUrl: environment.isProduction
        ? 'https://project.example.invalid'
        : 'http://10.0.2.2:54321',
    AppPublicConfigurationKeys.supportUrl: 'https://example.invalid/support',
  };
}

AppPublicConfiguration publicConfigurationFixture({
  AppEnvironment environment = AppEnvironment.dev,
  String googleWebClientId = '',
  bool sentryEnabled = false,
}) {
  return AppPublicConfigurationLoader(expectedEnvironment: environment).load(
    publicConfigurationValues(
      environment: environment,
      googleWebClientId: googleWebClientId,
      sentryDsn: sentryEnabled ? 'https://publickey@o0.ingest.sentry.io/1' : '',
    ),
  );
}
