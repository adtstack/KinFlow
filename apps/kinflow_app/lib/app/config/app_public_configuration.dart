import 'package:kinflow_app/app/app_environment.dart';

enum AppConfigurationIssueCode {
  applicationIdMismatch,
  environmentMismatch,
  insecureUri,
  invalidFormat,
  invalidUri,
  missingValue,
  placeholderValue,
  serverSecretPresent,
  unknownKey,
}

final class AppConfigurationIssue {
  const AppConfigurationIssue({required this.code, required this.key});

  final AppConfigurationIssueCode code;
  final String key;

  String get stableCode => '${code.name}:$key';
}

final class AppConfigurationException implements Exception {
  AppConfigurationException(Iterable<AppConfigurationIssue> issues)
    : issues = List<AppConfigurationIssue>.unmodifiable(issues);

  final List<AppConfigurationIssue> issues;

  @override
  String toString() {
    final String codes = issues
        .map((AppConfigurationIssue issue) => issue.stableCode)
        .join(',');
    return 'AppConfigurationException($codes)';
  }
}

final class AppPublicConfiguration {
  const AppPublicConfiguration({
    required this.applicationId,
    required this.appVersion,
    required this.authRedirectHost,
    required this.contractVersion,
    required this.environment,
    required this.featureConfigUri,
    required this.firebaseAndroidOptions,
    required this.googleWebClientId,
    required this.privacyRequestUri,
    required this.publicSiteUri,
    required this.revenueCatAndroidPublicSdkKey,
    required this.sentryDsn,
    required this.supabasePublishableKey,
    required this.supabaseUri,
    required this.supportUri,
  });

  final String applicationId;
  final String appVersion;
  final String authRedirectHost;
  final String contractVersion;
  final AppEnvironment environment;
  final Uri? featureConfigUri;
  final FirebaseAndroidPublicOptions? firebaseAndroidOptions;
  final String? googleWebClientId;
  final Uri privacyRequestUri;
  final Uri publicSiteUri;
  final String? revenueCatAndroidPublicSdkKey;
  final Uri? sentryDsn;
  final String supabasePublishableKey;
  final Uri supabaseUri;
  final Uri supportUri;

  String get release => '$applicationId@$appVersion';

  bool get isSentryEnabled => sentryDsn != null;
}

final class FirebaseAndroidPublicOptions {
  const FirebaseAndroidPublicOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
}

abstract final class AppPublicConfigurationKeys {
  static const String appEnvironment = 'APP_ENV';
  static const String applicationId = 'APP_ID';
  static const String appVersion = 'APP_VERSION';
  static const String authRedirectHost = 'AUTH_REDIRECT_HOST';
  static const String contractVersion = 'CONTRACT_VERSION';
  static const String featureConfigUrl = 'FEATURE_CONFIG_URL';
  static const String firebaseAndroidApiKey = 'FIREBASE_ANDROID_API_KEY';
  static const String firebaseAndroidAppId = 'FIREBASE_ANDROID_APP_ID';
  static const String firebaseMessagingSenderId =
      'FIREBASE_MESSAGING_SENDER_ID';
  static const String firebaseProjectId = 'FIREBASE_PROJECT_ID';
  static const String googleWebClientId = 'GOOGLE_WEB_CLIENT_ID';
  static const String privacyRequestUrl = 'PRIVACY_REQUEST_URL';
  static const String publicSiteUrl = 'PUBLIC_SITE_URL';
  static const String revenueCatAndroidPublicSdkKey =
      'REVENUECAT_ANDROID_PUBLIC_SDK_KEY';
  static const String sentryDsn = 'SENTRY_DSN';
  static const String supabasePublishableKey = 'SUPABASE_PUBLISHABLE_KEY';
  static const String supabaseUrl = 'SUPABASE_URL';
  static const String supportUrl = 'SUPPORT_URL';

  static const Set<String> allowed = <String>{
    appEnvironment,
    applicationId,
    appVersion,
    authRedirectHost,
    contractVersion,
    featureConfigUrl,
    firebaseAndroidApiKey,
    firebaseAndroidAppId,
    firebaseMessagingSenderId,
    firebaseProjectId,
    googleWebClientId,
    privacyRequestUrl,
    publicSiteUrl,
    revenueCatAndroidPublicSdkKey,
    sentryDsn,
    supabasePublishableKey,
    supabaseUrl,
    supportUrl,
  };

  static const Set<String> serverOnly = <String>{
    'APPLE_APP_STORE_API_PRIVATE_KEY',
    'DATA_EXPORT_SIGNING_KEY',
    'FCM_SERVER_CREDENTIAL',
    'KINFLOW_FIREBASE_SERVICE_ACCOUNT_JSON',
    'KINFLOW_BILLING_RECONCILIATION_WORKER_SECRET',
    'KINFLOW_DATA_EXPORT_WORKER_SECRET',
    'KINFLOW_HOUSEHOLD_PRIVACY_WORKER_SECRET',
    'KINFLOW_REVENUECAT_ENTITLEMENT_ID',
    'KINFLOW_REVENUECAT_SECRET_API_KEY',
    'KINFLOW_REVENUECAT_WEBHOOK_AUTHORIZATION',
    'KINFLOW_REVENUECAT_WEBHOOK_SIGNING_SECRET',
    'KINFLOW_NOTIFICATION_TOKEN_ENCRYPTION_KEY',
    'KINFLOW_NOTIFICATION_PUSH_WORKER_SECRET',
    'KINFLOW_NOTIFICATION_TOKEN_DECRYPTION_KEYS',
    'KINFLOW_NOTIFICATION_WORKER_SECRET',
    'GOOGLE_CLIENT_SECRET',
    'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
    'INTERNAL_JOB_AUTH_SECRET',
    'INVITE_TOKEN_HMAC_KEY',
    'REVENUECAT_SECRET_API_KEY',
    'REVENUECAT_WEBHOOK_SECRET',
    'SENTRY_AUTH_TOKEN',
    'SIGNING_KEYSTORE_PASSWORD',
    'SUPABASE_DB_PASSWORD',
    'SUPABASE_DB_URL',
    'SUPABASE_JWT_SECRET',
    'SUPABASE_SERVICE_ROLE_KEY',
  };
}

final class AppPublicConfigurationLoader {
  const AppPublicConfigurationLoader({
    required this.expectedEnvironment,
    this.allowPlaceholders = false,
  });

  final bool allowPlaceholders;
  final AppEnvironment expectedEnvironment;

  AppPublicConfiguration load(Map<String, String> input) {
    final List<AppConfigurationIssue> issues = <AppConfigurationIssue>[];
    _validateKeys(input, issues);

    final String environmentValue = _required(
      input,
      AppPublicConfigurationKeys.appEnvironment,
      issues,
    );
    if (environmentValue.isNotEmpty &&
        environmentValue != expectedEnvironment.value) {
      issues.add(
        const AppConfigurationIssue(
          code: AppConfigurationIssueCode.environmentMismatch,
          key: AppPublicConfigurationKeys.appEnvironment,
        ),
      );
    }

    final String applicationId = _required(
      input,
      AppPublicConfigurationKeys.applicationId,
      issues,
    );
    if (applicationId.isNotEmpty &&
        applicationId != expectedEnvironment.applicationId) {
      issues.add(
        const AppConfigurationIssue(
          code: AppConfigurationIssueCode.applicationIdMismatch,
          key: AppPublicConfigurationKeys.applicationId,
        ),
      );
    }

    final String appVersion = _required(
      input,
      AppPublicConfigurationKeys.appVersion,
      issues,
    );
    if (appVersion.isNotEmpty && !_versionPattern.hasMatch(appVersion)) {
      _invalidFormat(AppPublicConfigurationKeys.appVersion, issues);
    }

    final String contractVersion = _required(
      input,
      AppPublicConfigurationKeys.contractVersion,
      issues,
    );
    if (contractVersion.isNotEmpty &&
        !_contractVersionPattern.hasMatch(contractVersion)) {
      _invalidFormat(AppPublicConfigurationKeys.contractVersion, issues);
    }

    final Uri supabaseUri = _requiredUri(
      input,
      key: AppPublicConfigurationKeys.supabaseUrl,
      issues: issues,
      originOnly: true,
    );
    _validateTransport(
      supabaseUri,
      key: AppPublicConfigurationKeys.supabaseUrl,
      issues: issues,
      allowDevLoopbackHttp: true,
    );

    final String supabasePublishableKey = _required(
      input,
      AppPublicConfigurationKeys.supabasePublishableKey,
      issues,
    );
    if (supabasePublishableKey.isNotEmpty) {
      if (_isPlaceholder(supabasePublishableKey)) {
        if (!allowPlaceholders) {
          issues.add(
            const AppConfigurationIssue(
              code: AppConfigurationIssueCode.placeholderValue,
              key: AppPublicConfigurationKeys.supabasePublishableKey,
            ),
          );
        }
      } else if (!_isPublishableKey(supabasePublishableKey)) {
        _invalidFormat(
          AppPublicConfigurationKeys.supabasePublishableKey,
          issues,
        );
      }
    }

    final Uri publicSiteUri = _requiredUri(
      input,
      key: AppPublicConfigurationKeys.publicSiteUrl,
      issues: issues,
    );
    _validateTransport(
      publicSiteUri,
      key: AppPublicConfigurationKeys.publicSiteUrl,
      issues: issues,
    );

    final Uri supportUri = _requiredUri(
      input,
      key: AppPublicConfigurationKeys.supportUrl,
      issues: issues,
    );
    _validateTransport(
      supportUri,
      key: AppPublicConfigurationKeys.supportUrl,
      issues: issues,
    );

    final Uri privacyRequestUri = _requiredUri(
      input,
      key: AppPublicConfigurationKeys.privacyRequestUrl,
      issues: issues,
    );
    _validateTransport(
      privacyRequestUri,
      key: AppPublicConfigurationKeys.privacyRequestUrl,
      issues: issues,
    );

    final String authRedirectHost = _required(
      input,
      AppPublicConfigurationKeys.authRedirectHost,
      issues,
    );
    if (authRedirectHost.isNotEmpty &&
        !_hostPattern.hasMatch(authRedirectHost)) {
      _invalidFormat(AppPublicConfigurationKeys.authRedirectHost, issues);
    }

    final Uri? sentryDsn = _optionalUri(
      input,
      key: AppPublicConfigurationKeys.sentryDsn,
      issues: issues,
      allowPublicUserInfo: true,
    );
    if (sentryDsn != null) {
      _validateTransport(
        sentryDsn,
        key: AppPublicConfigurationKeys.sentryDsn,
        issues: issues,
        allowDevLoopbackHttp: true,
      );
      if (sentryDsn.pathSegments.isEmpty || sentryDsn.userInfo.isEmpty) {
        _invalidFormat(AppPublicConfigurationKeys.sentryDsn, issues);
      }
    }

    final Uri? featureConfigUri = _optionalUri(
      input,
      key: AppPublicConfigurationKeys.featureConfigUrl,
      issues: issues,
    );
    if (featureConfigUri != null) {
      _validateTransport(
        featureConfigUri,
        key: AppPublicConfigurationKeys.featureConfigUrl,
        issues: issues,
      );
    }

    final Map<String, String?> firebaseValues = <String, String?>{
      AppPublicConfigurationKeys.firebaseAndroidApiKey: _optionalProviderValue(
        input,
        AppPublicConfigurationKeys.firebaseAndroidApiKey,
      ),
      AppPublicConfigurationKeys.firebaseAndroidAppId: _optionalProviderValue(
        input,
        AppPublicConfigurationKeys.firebaseAndroidAppId,
      ),
      AppPublicConfigurationKeys.firebaseMessagingSenderId:
          _optionalProviderValue(
            input,
            AppPublicConfigurationKeys.firebaseMessagingSenderId,
          ),
      AppPublicConfigurationKeys.firebaseProjectId: _optionalProviderValue(
        input,
        AppPublicConfigurationKeys.firebaseProjectId,
      ),
    };
    final int configuredFirebaseValues = firebaseValues.values
        .whereType<String>()
        .length;
    FirebaseAndroidPublicOptions? firebaseAndroidOptions;
    if (configuredFirebaseValues != 0 &&
        configuredFirebaseValues != firebaseValues.length) {
      for (final MapEntry<String, String?> entry in firebaseValues.entries) {
        if (entry.value == null) _invalidFormat(entry.key, issues);
      }
    } else if (configuredFirebaseValues == firebaseValues.length) {
      final String apiKey =
          firebaseValues[AppPublicConfigurationKeys.firebaseAndroidApiKey]!;
      final String appId =
          firebaseValues[AppPublicConfigurationKeys.firebaseAndroidAppId]!;
      final String messagingSenderId =
          firebaseValues[AppPublicConfigurationKeys.firebaseMessagingSenderId]!;
      final String projectId =
          firebaseValues[AppPublicConfigurationKeys.firebaseProjectId]!;
      if (!RegExp(r'^AIza[0-9A-Za-z_-]{35}$').hasMatch(apiKey)) {
        _invalidFormat(
          AppPublicConfigurationKeys.firebaseAndroidApiKey,
          issues,
        );
      }
      if (!RegExp(r'^1:[0-9]{6,20}:android:[0-9a-f]{16,64}$').hasMatch(appId)) {
        _invalidFormat(AppPublicConfigurationKeys.firebaseAndroidAppId, issues);
      }
      if (!RegExp(r'^[0-9]{6,20}$').hasMatch(messagingSenderId)) {
        _invalidFormat(
          AppPublicConfigurationKeys.firebaseMessagingSenderId,
          issues,
        );
      }
      if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId)) {
        _invalidFormat(AppPublicConfigurationKeys.firebaseProjectId, issues);
      }
      firebaseAndroidOptions = FirebaseAndroidPublicOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
      );
    }

    final String? googleWebClientId = _optionalProviderValue(
      input,
      AppPublicConfigurationKeys.googleWebClientId,
    );
    if (googleWebClientId != null &&
        !googleWebClientId.endsWith('.apps.googleusercontent.com')) {
      _invalidFormat(AppPublicConfigurationKeys.googleWebClientId, issues);
    }

    final String? revenueCatAndroidPublicSdkKey = _optionalProviderValue(
      input,
      AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey,
    );
    if (revenueCatAndroidPublicSdkKey != null) {
      if (revenueCatAndroidPublicSdkKey.toLowerCase().startsWith('sk_')) {
        issues.add(
          const AppConfigurationIssue(
            code: AppConfigurationIssueCode.serverSecretPresent,
            key: AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey,
          ),
        );
      } else if (!_revenueCatAndroidPublicSdkKeyPattern.hasMatch(
            revenueCatAndroidPublicSdkKey,
          ) ||
          expectedEnvironment.isProduction &&
              revenueCatAndroidPublicSdkKey.startsWith('test_')) {
        _invalidFormat(
          AppPublicConfigurationKeys.revenueCatAndroidPublicSdkKey,
          issues,
        );
      }
    }

    if (issues.isNotEmpty) {
      throw AppConfigurationException(issues);
    }

    return AppPublicConfiguration(
      applicationId: applicationId,
      appVersion: appVersion,
      authRedirectHost: authRedirectHost,
      contractVersion: contractVersion,
      environment: expectedEnvironment,
      featureConfigUri: featureConfigUri,
      firebaseAndroidOptions: firebaseAndroidOptions,
      googleWebClientId: googleWebClientId,
      privacyRequestUri: privacyRequestUri,
      publicSiteUri: publicSiteUri,
      revenueCatAndroidPublicSdkKey: revenueCatAndroidPublicSdkKey,
      sentryDsn: sentryDsn,
      supabasePublishableKey: supabasePublishableKey,
      supabaseUri: supabaseUri,
      supportUri: supportUri,
    );
  }

  static final RegExp _contractVersionPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _hostPattern = RegExp(
    r'^(?=.{1,253}$)(localhost|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63})$',
  );
  static final RegExp _jwtPattern = RegExp(
    r'^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
  );
  static final RegExp _revenueCatAndroidPublicSdkKeyPattern = RegExp(
    r'^(?:goog|test)_[A-Za-z0-9]{11,}$',
  );
  static final RegExp _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
  );

  void _invalidFormat(String key, List<AppConfigurationIssue> issues) {
    issues.add(
      AppConfigurationIssue(
        code: AppConfigurationIssueCode.invalidFormat,
        key: key,
      ),
    );
  }

  bool _isPlaceholder(String value) {
    final String normalized = value.toLowerCase();
    return normalized.contains('replace-with-') ||
        normalized.contains('example.invalid') ||
        normalized == 'changeme';
  }

  bool _isPublishableKey(String value) {
    if (value.contains(RegExp(r'\s')) ||
        value.toLowerCase().contains('service_role')) {
      return false;
    }
    return (value.startsWith('sb_publishable_') && value.length >= 24) ||
        _jwtPattern.hasMatch(value);
  }

  bool _isSafeLoopback(Uri uri) {
    return <String>{'10.0.2.2', '127.0.0.1', 'localhost'}.contains(uri.host);
  }

  String? _optionalProviderValue(Map<String, String> input, String key) {
    final String value = input[key]?.trim() ?? '';
    if (value.isEmpty || _isPlaceholder(value)) {
      return null;
    }
    return value;
  }

  Uri? _optionalUri(
    Map<String, String> input, {
    required String key,
    required List<AppConfigurationIssue> issues,
    bool allowPublicUserInfo = false,
  }) {
    final String value = input[key]?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return _parseUri(
      value,
      key: key,
      issues: issues,
      allowPublicUserInfo: allowPublicUserInfo,
    );
  }

  Uri _requiredUri(
    Map<String, String> input, {
    required String key,
    required List<AppConfigurationIssue> issues,
    bool originOnly = false,
  }) {
    final String value = _required(input, key, issues);
    if (value.isEmpty) {
      return Uri();
    }
    final Uri? uri = _parseUri(
      value,
      key: key,
      issues: issues,
      originOnly: originOnly,
    );
    return uri ?? Uri();
  }

  Uri? _parseUri(
    String value, {
    required String key,
    required List<AppConfigurationIssue> issues,
    bool allowPublicUserInfo = false,
    bool originOnly = false,
  }) {
    final Uri? uri = Uri.tryParse(value);
    final bool hasForbiddenParts =
        uri != null &&
        ((uri.hasQuery || uri.hasFragment) ||
            (!allowPublicUserInfo && uri.userInfo.isNotEmpty) ||
            (allowPublicUserInfo && uri.userInfo.contains(':')) ||
            (originOnly && uri.path.isNotEmpty && uri.path != '/'));
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        hasForbiddenParts) {
      issues.add(
        AppConfigurationIssue(
          code: AppConfigurationIssueCode.invalidUri,
          key: key,
        ),
      );
      return null;
    }
    return uri;
  }

  String _required(
    Map<String, String> input,
    String key,
    List<AppConfigurationIssue> issues,
  ) {
    final String value = input[key]?.trim() ?? '';
    if (value.isEmpty) {
      issues.add(
        AppConfigurationIssue(
          code: AppConfigurationIssueCode.missingValue,
          key: key,
        ),
      );
    }
    return value;
  }

  void _validateKeys(
    Map<String, String> input,
    List<AppConfigurationIssue> issues,
  ) {
    for (final MapEntry<String, String> entry in input.entries) {
      if (AppPublicConfigurationKeys.serverOnly.contains(entry.key)) {
        issues.add(
          AppConfigurationIssue(
            code: AppConfigurationIssueCode.serverSecretPresent,
            key: entry.key,
          ),
        );
      } else if (!AppPublicConfigurationKeys.allowed.contains(entry.key)) {
        issues.add(
          AppConfigurationIssue(
            code: AppConfigurationIssueCode.unknownKey,
            key: entry.key,
          ),
        );
      }
    }
  }

  void _validateTransport(
    Uri uri, {
    required String key,
    required List<AppConfigurationIssue> issues,
    bool allowDevLoopbackHttp = false,
  }) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      return;
    }
    final bool secure = uri.scheme == 'https';
    final bool allowedDevHttp =
        allowDevLoopbackHttp &&
        !expectedEnvironment.isProduction &&
        uri.scheme == 'http' &&
        _isSafeLoopback(uri);
    if (!secure && !allowedDevHttp) {
      issues.add(
        AppConfigurationIssue(
          code: AppConfigurationIssueCode.insecureUri,
          key: key,
        ),
      );
    }
  }
}
