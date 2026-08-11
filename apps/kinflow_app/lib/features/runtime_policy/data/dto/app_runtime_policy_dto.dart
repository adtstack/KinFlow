final class AppRuntimePolicyDto {
  const AppRuntimePolicyDto._({
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

  final String environment;
  final String platform;
  final String minimumSupportedVersion;
  final int minimumSupportedBuild;
  final String? minimumContractVersion;
  final String? maximumContractVersion;
  final bool mutationsEnabled;
  final int policyVersion;
  final String updatedAt;
  final String evaluatedAt;

  static const Set<String> exactKeys = <String>{
    'environment',
    'platform',
    'minimum_supported_version',
    'minimum_supported_build',
    'minimum_contract_version',
    'maximum_contract_version',
    'mutations_enabled',
    'policy_version',
    'updated_at',
    'evaluated_at',
  };

  static AppRuntimePolicyDto? tryParse(Map<String, Object?> json) {
    if (json.keys.toSet().difference(exactKeys).isNotEmpty ||
        exactKeys.difference(json.keys.toSet()).isNotEmpty) {
      return null;
    }
    final Object? environment = json['environment'];
    final Object? platform = json['platform'];
    final Object? minimumSupportedVersion = json['minimum_supported_version'];
    final Object? minimumSupportedBuild = json['minimum_supported_build'];
    final Object? minimumContractVersion = json['minimum_contract_version'];
    final Object? maximumContractVersion = json['maximum_contract_version'];
    final Object? mutationsEnabled = json['mutations_enabled'];
    final Object? policyVersion = json['policy_version'];
    final Object? updatedAt = json['updated_at'];
    final Object? evaluatedAt = json['evaluated_at'];
    if (environment is! String ||
        platform is! String ||
        minimumSupportedVersion is! String ||
        minimumSupportedBuild is! int ||
        minimumContractVersion != null && minimumContractVersion is! String ||
        maximumContractVersion != null && maximumContractVersion is! String ||
        mutationsEnabled is! bool ||
        policyVersion is! int ||
        updatedAt is! String ||
        evaluatedAt is! String) {
      return null;
    }
    return AppRuntimePolicyDto._(
      environment: environment,
      platform: platform,
      minimumSupportedVersion: minimumSupportedVersion,
      minimumSupportedBuild: minimumSupportedBuild,
      minimumContractVersion: minimumContractVersion as String?,
      maximumContractVersion: maximumContractVersion as String?,
      mutationsEnabled: mutationsEnabled,
      policyVersion: policyVersion,
      updatedAt: updatedAt,
      evaluatedAt: evaluatedAt,
    );
  }
}
