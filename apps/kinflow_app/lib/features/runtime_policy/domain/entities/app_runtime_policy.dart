enum RuntimePolicyEnvironment {
  dev('dev'),
  prod('prod');

  const RuntimePolicyEnvironment(this.wireValue);

  final String wireValue;

  static RuntimePolicyEnvironment? tryParse(String value) {
    return switch (value) {
      'dev' => RuntimePolicyEnvironment.dev,
      'prod' => RuntimePolicyEnvironment.prod,
      _ => null,
    };
  }
}

enum RuntimePolicyPlatform {
  android('android'),
  web('web');

  const RuntimePolicyPlatform(this.wireValue);

  final String wireValue;

  static RuntimePolicyPlatform? tryParse(String value) {
    return switch (value) {
      'android' => RuntimePolicyPlatform.android,
      'web' => RuntimePolicyPlatform.web,
      _ => null,
    };
  }
}

enum AppRuntimeFeature {
  household('household'),
  chores('chores'),
  calendar('calendar'),
  notifications('notifications'),
  profile('profile'),
  billing('billing');

  const AppRuntimeFeature(this.wireValue);

  final String wireValue;

  static AppRuntimeFeature? tryParse(String value) {
    for (final AppRuntimeFeature feature in AppRuntimeFeature.values) {
      if (feature.wireValue == value) return feature;
    }
    return null;
  }
}

final class RuntimeContractVersion
    implements Comparable<RuntimeContractVersion> {
  const RuntimeContractVersion._(this.value, this._date);

  final String value;
  final DateTime _date;

  static RuntimeContractVersion? tryParse(String value) {
    if (!_pattern.hasMatch(value)) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00.000Z');
    if (parsed == null || !parsed.isUtc || _format(parsed) != value) {
      return null;
    }
    return RuntimeContractVersion._(value, parsed);
  }

  @override
  int compareTo(RuntimeContractVersion other) => _date.compareTo(other._date);

  static String _format(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-${twoDigits(value.day)}';
  }

  static final RegExp _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
}

final class RuntimeClientBuild {
  const RuntimeClientBuild._({
    required this.applicationId,
    required this.version,
    required this.buildNumber,
  });

  final String applicationId;
  final String version;
  final int buildNumber;

  String get configuredVersion => '$version+$buildNumber';

  static RuntimeClientBuild? tryCreate({
    required String applicationId,
    required String version,
    required String buildNumber,
  }) {
    final int? parsedBuild = int.tryParse(buildNumber);
    if (!_applicationIdPattern.hasMatch(applicationId) ||
        applicationId.length > 255 ||
        !_versionPattern.hasMatch(version) ||
        version.length > 64 ||
        parsedBuild == null ||
        parsedBuild < 1 ||
        parsedBuild > 2147483647 ||
        parsedBuild.toString() != buildNumber) {
      return null;
    }
    return RuntimeClientBuild._(
      applicationId: applicationId,
      version: version,
      buildNumber: parsedBuild,
    );
  }

  static final RegExp _applicationIdPattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*$',
  );
  static final RegExp _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
  );
}

final class RuntimeClientIdentity {
  const RuntimeClientIdentity._({
    required this.build,
    required this.contractVersion,
    required this.environment,
    required this.platform,
  });

  final RuntimeClientBuild build;
  final RuntimeContractVersion contractVersion;
  final RuntimePolicyEnvironment environment;
  final RuntimePolicyPlatform platform;

  Map<String, String> get requestHeaders => <String, String>{
    'X-KinFlow-Client-Version': build.configuredVersion,
    'X-KinFlow-Client-Build': build.buildNumber.toString(),
    'X-KinFlow-Contract-Version': contractVersion.value,
    'X-KinFlow-Platform': platform.wireValue,
    'X-KinFlow-Environment': environment.wireValue,
  };

  static RuntimeClientIdentity? tryCreate({
    required RuntimeClientBuild build,
    required String expectedApplicationId,
    required String expectedConfiguredVersion,
    required String contractVersion,
    required RuntimePolicyEnvironment environment,
    required RuntimePolicyPlatform platform,
  }) {
    final RuntimeContractVersion? parsedContract =
        RuntimeContractVersion.tryParse(contractVersion);
    if (parsedContract == null ||
        build.applicationId != expectedApplicationId ||
        build.configuredVersion != expectedConfiguredVersion) {
      return null;
    }
    return RuntimeClientIdentity._(
      build: build,
      contractVersion: parsedContract,
      environment: environment,
      platform: platform,
    );
  }
}

final class AppRuntimePolicy {
  const AppRuntimePolicy._({
    required this.environment,
    required this.platform,
    required this.minimumSupportedVersion,
    required this.minimumSupportedBuild,
    required this.minimumContractVersion,
    required this.maximumContractVersion,
    required this.mutationsEnabled,
    required this.policyVersion,
    required this.updatedAt,
    required this.evaluatedAt,
  });

  final RuntimePolicyEnvironment environment;
  final RuntimePolicyPlatform platform;
  final String minimumSupportedVersion;
  final int minimumSupportedBuild;
  final RuntimeContractVersion? minimumContractVersion;
  final RuntimeContractVersion? maximumContractVersion;
  final bool mutationsEnabled;
  final int policyVersion;
  final DateTime updatedAt;
  final DateTime evaluatedAt;

  static AppRuntimePolicy? tryCreate({
    required RuntimePolicyEnvironment environment,
    required RuntimePolicyPlatform platform,
    required String minimumSupportedVersion,
    required int minimumSupportedBuild,
    required RuntimeContractVersion? minimumContractVersion,
    required RuntimeContractVersion? maximumContractVersion,
    required bool mutationsEnabled,
    required int policyVersion,
    required DateTime updatedAt,
    required DateTime evaluatedAt,
  }) {
    if (!_versionPattern.hasMatch(minimumSupportedVersion) ||
        minimumSupportedVersion.length > 64 ||
        minimumSupportedBuild < 0 ||
        minimumSupportedBuild > 2147483647 ||
        minimumSupportedBuild == 0 && minimumSupportedVersion != '0.0.0' ||
        minimumContractVersion != null &&
            maximumContractVersion != null &&
            minimumContractVersion.compareTo(maximumContractVersion) > 0 ||
        policyVersion < 1 ||
        !updatedAt.isUtc ||
        !evaluatedAt.isUtc ||
        evaluatedAt.isBefore(updatedAt)) {
      return null;
    }
    return AppRuntimePolicy._(
      environment: environment,
      platform: platform,
      minimumSupportedVersion: minimumSupportedVersion,
      minimumSupportedBuild: minimumSupportedBuild,
      minimumContractVersion: minimumContractVersion,
      maximumContractVersion: maximumContractVersion,
      mutationsEnabled: mutationsEnabled,
      policyVersion: policyVersion,
      updatedAt: updatedAt,
      evaluatedAt: evaluatedAt,
    );
  }

  static final RegExp _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
  );
}

final class AppRuntimeFeaturePolicy {
  const AppRuntimeFeaturePolicy._({
    required this.environment,
    required this.platform,
    required this.feature,
    required this.mutationsEnabled,
    required this.policyVersion,
    required this.updatedAt,
    required this.evaluatedAt,
  });

  final RuntimePolicyEnvironment environment;
  final RuntimePolicyPlatform platform;
  final AppRuntimeFeature feature;
  final bool mutationsEnabled;
  final int policyVersion;
  final DateTime updatedAt;
  final DateTime evaluatedAt;

  static AppRuntimeFeaturePolicy? tryCreate({
    required RuntimePolicyEnvironment environment,
    required RuntimePolicyPlatform platform,
    required AppRuntimeFeature feature,
    required bool mutationsEnabled,
    required int policyVersion,
    required DateTime updatedAt,
    required DateTime evaluatedAt,
  }) {
    if (policyVersion < 1 ||
        !updatedAt.isUtc ||
        !evaluatedAt.isUtc ||
        evaluatedAt.isBefore(updatedAt)) {
      return null;
    }
    return AppRuntimeFeaturePolicy._(
      environment: environment,
      platform: platform,
      feature: feature,
      mutationsEnabled: mutationsEnabled,
      policyVersion: policyVersion,
      updatedAt: updatedAt,
      evaluatedAt: evaluatedAt,
    );
  }
}

enum AppRuntimePolicyDecisionKind { allowed, readOnly, updateRequired }

final class AppRuntimePolicySnapshot {
  const AppRuntimePolicySnapshot._({
    required this.client,
    required this.policy,
    required this.featurePolicies,
    required this.decision,
  });

  final RuntimeClientIdentity client;
  final AppRuntimePolicy policy;
  final Map<AppRuntimeFeature, AppRuntimeFeaturePolicy> featurePolicies;
  final AppRuntimePolicyDecisionKind decision;

  bool get mutationsBlocked => decision != AppRuntimePolicyDecisionKind.allowed;

  List<AppRuntimeFeature> get disabledFeatures => <AppRuntimeFeature>[
    for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
      if (!featurePolicies[feature]!.mutationsEnabled) feature,
  ];

  bool mutationsBlockedFor(AppRuntimeFeature feature) {
    return mutationsBlocked || !featurePolicies[feature]!.mutationsEnabled;
  }

  static AppRuntimePolicySnapshot? evaluate({
    required RuntimeClientIdentity client,
    required AppRuntimePolicy policy,
    required Iterable<AppRuntimeFeaturePolicy> featurePolicies,
  }) {
    if (client.environment != policy.environment ||
        client.platform != policy.platform) {
      return null;
    }
    final Map<AppRuntimeFeature, AppRuntimeFeaturePolicy> byFeature =
        <AppRuntimeFeature, AppRuntimeFeaturePolicy>{};
    for (final AppRuntimeFeaturePolicy featurePolicy in featurePolicies) {
      if (featurePolicy.environment != client.environment ||
          featurePolicy.platform != client.platform ||
          byFeature.containsKey(featurePolicy.feature)) {
        return null;
      }
      byFeature[featurePolicy.feature] = featurePolicy;
    }
    if (byFeature.length != AppRuntimeFeature.values.length) {
      return null;
    }
    final bool unsupported =
        client.build.buildNumber < policy.minimumSupportedBuild ||
        policy.minimumContractVersion != null &&
            client.contractVersion.compareTo(policy.minimumContractVersion!) <
                0 ||
        policy.maximumContractVersion != null &&
            client.contractVersion.compareTo(policy.maximumContractVersion!) >
                0;
    final AppRuntimePolicyDecisionKind decision = unsupported
        ? AppRuntimePolicyDecisionKind.updateRequired
        : policy.mutationsEnabled
        ? AppRuntimePolicyDecisionKind.allowed
        : AppRuntimePolicyDecisionKind.readOnly;
    return AppRuntimePolicySnapshot._(
      client: client,
      policy: policy,
      featurePolicies:
          Map<AppRuntimeFeature, AppRuntimeFeaturePolicy>.unmodifiable(
            byFeature,
          ),
      decision: decision,
    );
  }
}
