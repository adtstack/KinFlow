import 'package:kinflow_app/app/config/app_public_configuration.dart';

abstract final class DartDefinePublicConfiguration {
  static const Map<String, String> values = <String, String>{
    AppPublicConfigurationKeys.appEnvironment: String.fromEnvironment(
      AppPublicConfigurationKeys.appEnvironment,
    ),
    AppPublicConfigurationKeys.applicationId: String.fromEnvironment(
      AppPublicConfigurationKeys.applicationId,
    ),
    AppPublicConfigurationKeys.appVersion: String.fromEnvironment(
      AppPublicConfigurationKeys.appVersion,
    ),
    AppPublicConfigurationKeys.authRedirectHost: String.fromEnvironment(
      AppPublicConfigurationKeys.authRedirectHost,
    ),
    AppPublicConfigurationKeys.contractVersion: String.fromEnvironment(
      AppPublicConfigurationKeys.contractVersion,
    ),
    AppPublicConfigurationKeys.featureConfigUrl: String.fromEnvironment(
      AppPublicConfigurationKeys.featureConfigUrl,
    ),
    AppPublicConfigurationKeys.firebaseAndroidApiKey: String.fromEnvironment(
      AppPublicConfigurationKeys.firebaseAndroidApiKey,
    ),
    AppPublicConfigurationKeys.firebaseAndroidAppId: String.fromEnvironment(
      AppPublicConfigurationKeys.firebaseAndroidAppId,
    ),
    AppPublicConfigurationKeys.firebaseMessagingSenderId:
        String.fromEnvironment(
          AppPublicConfigurationKeys.firebaseMessagingSenderId,
        ),
    AppPublicConfigurationKeys.firebaseProjectId: String.fromEnvironment(
      AppPublicConfigurationKeys.firebaseProjectId,
    ),
    AppPublicConfigurationKeys.googleWebClientId: String.fromEnvironment(
      AppPublicConfigurationKeys.googleWebClientId,
    ),
    AppPublicConfigurationKeys.privacyRequestUrl: String.fromEnvironment(
      AppPublicConfigurationKeys.privacyRequestUrl,
    ),
    AppPublicConfigurationKeys.publicSiteUrl: String.fromEnvironment(
      AppPublicConfigurationKeys.publicSiteUrl,
    ),
    AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey:
        String.fromEnvironment(
          AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey,
        ),
    AppPublicConfigurationKeys.sentryDsn: String.fromEnvironment(
      AppPublicConfigurationKeys.sentryDsn,
    ),
    AppPublicConfigurationKeys.supabasePublishableKey: String.fromEnvironment(
      AppPublicConfigurationKeys.supabasePublishableKey,
    ),
    AppPublicConfigurationKeys.supabaseUrl: String.fromEnvironment(
      AppPublicConfigurationKeys.supabaseUrl,
    ),
    AppPublicConfigurationKeys.supportUrl: String.fromEnvironment(
      AppPublicConfigurationKeys.supportUrl,
    ),
  };
}
