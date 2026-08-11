import 'package:kinflow_app/features/runtime_policy/data/datasources/app_runtime_policy_data_source.dart';
import 'package:kinflow_app/features/runtime_policy/data/dto/app_runtime_policy_dto.dart';
import 'package:kinflow_app/features/runtime_policy/data/dto/app_runtime_feature_policy_dto.dart';
import 'package:kinflow_app/features/runtime_policy/data/mappers/app_runtime_policy_mapper.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

final class ProviderAppRuntimePolicyRepository
    implements AppRuntimePolicyRepository {
  factory ProviderAppRuntimePolicyRepository({
    required AppRuntimePolicyDataSource dataSource,
    required RuntimeClientIdentity client,
  }) {
    return ProviderAppRuntimePolicyRepository._(dataSource, client);
  }

  const ProviderAppRuntimePolicyRepository._(this._dataSource, this._client);

  final AppRuntimePolicyDataSource _dataSource;
  final RuntimeClientIdentity _client;

  @override
  Future<AppRuntimePolicyResult> load() async {
    final Map<String, Object?> payload;
    final List<Map<String, Object?>> featurePayloads;
    try {
      payload = await _dataSource.fetch(
        environment: _client.environment.wireValue,
        platform: _client.platform.wireValue,
      );
      featurePayloads = await _dataSource.fetchFeatures(
        environment: _client.environment.wireValue,
        platform: _client.platform.wireValue,
      );
    } on Object {
      return const AppRuntimePolicyFailed(
        AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
      );
    }
    final AppRuntimePolicyDto? dto = AppRuntimePolicyDto.tryParse(payload);
    final AppRuntimePolicy? policy = dto == null
        ? null
        : AppRuntimePolicyMapper.toDomain(dto);
    final List<AppRuntimeFeaturePolicy>? featurePolicies = _featurePolicies(
      featurePayloads,
    );
    final AppRuntimePolicySnapshot? snapshot =
        policy == null || featurePolicies == null
        ? null
        : AppRuntimePolicySnapshot.evaluate(
            client: _client,
            policy: policy,
            featurePolicies: featurePolicies,
          );
    if (snapshot == null) {
      return const AppRuntimePolicyFailed(
        AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.invalidPayload),
      );
    }
    return AppRuntimePolicySucceeded(snapshot);
  }

  List<AppRuntimeFeaturePolicy>? _featurePolicies(
    List<Map<String, Object?>> payloads,
  ) {
    if (payloads.length != AppRuntimeFeature.values.length) return null;
    final List<AppRuntimeFeaturePolicy> result = <AppRuntimeFeaturePolicy>[];
    for (final Map<String, Object?> payload in payloads) {
      final AppRuntimeFeaturePolicyDto? dto =
          AppRuntimeFeaturePolicyDto.tryParse(payload);
      final AppRuntimeFeaturePolicy? policy = dto == null
          ? null
          : AppRuntimeFeaturePolicyMapper.toDomain(dto);
      if (policy == null) return null;
      result.add(policy);
    }
    return result;
  }
}
