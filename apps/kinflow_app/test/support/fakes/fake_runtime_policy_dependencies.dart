import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

final class FakeAllowedAppRuntimePolicyRepository
    implements AppRuntimePolicyRepository {
  const FakeAllowedAppRuntimePolicyRepository();

  @override
  Future<AppRuntimePolicyResult> load() async {
    return AppRuntimePolicySucceeded(runtimePolicySnapshotFixture());
  }
}

AppRuntimePolicySnapshot runtimePolicySnapshotFixture({
  int minimumSupportedBuild = 1,
  bool mutationsEnabled = true,
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) {
  final RuntimeClientBuild build = RuntimeClientBuild.tryCreate(
    applicationId: 'me.newlines.kinflow.dev',
    version: '0.1.0-dev',
    buildNumber: '1',
  )!;
  final RuntimeClientIdentity identity = RuntimeClientIdentity.tryCreate(
    build: build,
    expectedApplicationId: build.applicationId,
    expectedConfiguredVersion: build.configuredVersion,
    contractVersion: '2026-08-09',
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.android,
  )!;
  final AppRuntimePolicy policy = AppRuntimePolicy.tryCreate(
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.android,
    minimumSupportedVersion: '0.1.0-dev',
    minimumSupportedBuild: minimumSupportedBuild,
    minimumContractVersion: RuntimeContractVersion.tryParse('2026-08-01'),
    maximumContractVersion: RuntimeContractVersion.tryParse('2026-08-31'),
    mutationsEnabled: mutationsEnabled,
    policyVersion: 1,
    updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
    evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
  )!;
  return AppRuntimePolicySnapshot.evaluate(
    client: identity,
    policy: policy,
    featurePolicies: <AppRuntimeFeaturePolicy>[
      for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
        AppRuntimeFeaturePolicy.tryCreate(
          environment: RuntimePolicyEnvironment.dev,
          platform: RuntimePolicyPlatform.android,
          feature: feature,
          mutationsEnabled: !disabledFeatures.contains(feature),
          policyVersion: 1,
          updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
          evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
        )!,
    ],
  )!;
}
