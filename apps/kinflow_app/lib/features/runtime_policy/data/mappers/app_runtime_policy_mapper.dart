import 'package:kinflow_app/features/runtime_policy/data/dto/app_runtime_policy_dto.dart';
import 'package:kinflow_app/features/runtime_policy/data/dto/app_runtime_feature_policy_dto.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';

abstract final class AppRuntimePolicyMapper {
  static AppRuntimePolicy? toDomain(AppRuntimePolicyDto dto) {
    final RuntimePolicyEnvironment? environment =
        RuntimePolicyEnvironment.tryParse(dto.environment);
    final RuntimePolicyPlatform? platform = RuntimePolicyPlatform.tryParse(
      dto.platform,
    );
    final RuntimeContractVersion? minimumContract =
        dto.minimumContractVersion == null
        ? null
        : RuntimeContractVersion.tryParse(dto.minimumContractVersion!);
    final RuntimeContractVersion? maximumContract =
        dto.maximumContractVersion == null
        ? null
        : RuntimeContractVersion.tryParse(dto.maximumContractVersion!);
    final DateTime? updatedAt = _tryParseUtcTimestamp(dto.updatedAt);
    final DateTime? evaluatedAt = _tryParseUtcTimestamp(dto.evaluatedAt);
    if (environment == null ||
        platform == null ||
        dto.minimumContractVersion != null && minimumContract == null ||
        dto.maximumContractVersion != null && maximumContract == null ||
        updatedAt == null ||
        evaluatedAt == null) {
      return null;
    }
    return AppRuntimePolicy.tryCreate(
      environment: environment,
      platform: platform,
      minimumSupportedVersion: dto.minimumSupportedVersion,
      minimumSupportedBuild: dto.minimumSupportedBuild,
      minimumContractVersion: minimumContract,
      maximumContractVersion: maximumContract,
      mutationsEnabled: dto.mutationsEnabled,
      policyVersion: dto.policyVersion,
      updatedAt: updatedAt.toUtc(),
      evaluatedAt: evaluatedAt.toUtc(),
    );
  }
}

abstract final class AppRuntimeFeaturePolicyMapper {
  static AppRuntimeFeaturePolicy? toDomain(AppRuntimeFeaturePolicyDto dto) {
    final RuntimePolicyEnvironment? environment =
        RuntimePolicyEnvironment.tryParse(dto.environment);
    final RuntimePolicyPlatform? platform = RuntimePolicyPlatform.tryParse(
      dto.platform,
    );
    final AppRuntimeFeature? feature = AppRuntimeFeature.tryParse(dto.feature);
    final DateTime? updatedAt = _tryParseUtcTimestamp(dto.updatedAt);
    final DateTime? evaluatedAt = _tryParseUtcTimestamp(dto.evaluatedAt);
    if (environment == null ||
        platform == null ||
        feature == null ||
        updatedAt == null ||
        evaluatedAt == null) {
      return null;
    }
    return AppRuntimeFeaturePolicy.tryCreate(
      environment: environment,
      platform: platform,
      feature: feature,
      mutationsEnabled: dto.mutationsEnabled,
      policyVersion: dto.policyVersion,
      updatedAt: updatedAt.toUtc(),
      evaluatedAt: evaluatedAt.toUtc(),
    );
  }
}

DateTime? _tryParseUtcTimestamp(String value) {
  if (!RegExp(r'(?:Z|\+00:00)$').hasMatch(value)) return null;
  final DateTime? parsed = DateTime.tryParse(value);
  return parsed != null && parsed.isUtc ? parsed : null;
}
