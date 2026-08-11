final class AppRuntimeFeaturePolicyDto {
  const AppRuntimeFeaturePolicyDto._({
    required this.environment,
    required this.platform,
    required this.feature,
    required this.mutationsEnabled,
    required this.policyVersion,
    required this.updatedAt,
    required this.evaluatedAt,
  });

  final String environment;
  final String platform;
  final String feature;
  final bool mutationsEnabled;
  final int policyVersion;
  final String updatedAt;
  final String evaluatedAt;

  static const Set<String> exactKeys = <String>{
    'environment',
    'platform',
    'feature',
    'mutations_enabled',
    'policy_version',
    'updated_at',
    'evaluated_at',
  };

  static AppRuntimeFeaturePolicyDto? tryParse(Map<String, Object?> json) {
    final Set<String> keys = json.keys.toSet();
    if (keys.difference(exactKeys).isNotEmpty ||
        exactKeys.difference(keys).isNotEmpty) {
      return null;
    }
    final Object? environment = json['environment'];
    final Object? platform = json['platform'];
    final Object? feature = json['feature'];
    final Object? mutationsEnabled = json['mutations_enabled'];
    final Object? policyVersion = json['policy_version'];
    final Object? updatedAt = json['updated_at'];
    final Object? evaluatedAt = json['evaluated_at'];
    if (environment is! String ||
        platform is! String ||
        feature is! String ||
        mutationsEnabled is! bool ||
        policyVersion is! int ||
        updatedAt is! String ||
        evaluatedAt is! String) {
      return null;
    }
    return AppRuntimeFeaturePolicyDto._(
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
