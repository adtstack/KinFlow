import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';

void main() {
  group('runtime client identity', () {
    test('accepts exact installed metadata and emits bounded headers', () {
      final RuntimeClientBuild build = _build();
      final RuntimeClientIdentity identity = _identity(build: build);

      expect(build.configuredVersion, '0.1.0-dev+10');
      expect(identity.requestHeaders, <String, String>{
        'X-KinFlow-Client-Version': '0.1.0-dev+10',
        'X-KinFlow-Client-Build': '10',
        'X-KinFlow-Contract-Version': '2026-08-09',
        'X-KinFlow-Platform': 'android',
        'X-KinFlow-Environment': 'dev',
      });
    });

    test('accepts the web platform and emits the exact web identity', () {
      final RuntimeClientBuild build = RuntimeClientBuild.tryCreate(
        applicationId: 'kinflow_app',
        version: '0.1.0-dev',
        buildNumber: '10',
      )!;
      final RuntimeClientIdentity identity = RuntimeClientIdentity.tryCreate(
        build: build,
        expectedApplicationId: 'kinflow_app',
        expectedConfiguredVersion: '0.1.0-dev+10',
        contractVersion: '2026-08-09',
        environment: RuntimePolicyEnvironment.dev,
        platform: RuntimePolicyPlatform.web,
      )!;

      expect(RuntimePolicyPlatform.tryParse('web'), RuntimePolicyPlatform.web);
      expect(identity.requestHeaders, <String, String>{
        'X-KinFlow-Client-Version': '0.1.0-dev+10',
        'X-KinFlow-Client-Build': '10',
        'X-KinFlow-Contract-Version': '2026-08-09',
        'X-KinFlow-Platform': 'web',
        'X-KinFlow-Environment': 'dev',
      });
    });

    test('rejects malformed or mismatched installed metadata', () {
      for (final ({String applicationId, String version, String buildNumber})
          value
          in <({String applicationId, String version, String buildNumber})>[
            (applicationId: 'bad id', version: '0.1.0-dev', buildNumber: '10'),
            (
              applicationId: 'me.newlines.kinflow.dev',
              version: 'latest',
              buildNumber: '10',
            ),
            (
              applicationId: 'me.newlines.kinflow.dev',
              version: '0.1.0-dev',
              buildNumber: '01',
            ),
            (
              applicationId: 'me.newlines.kinflow.dev',
              version: '0.1.0-dev',
              buildNumber: '0',
            ),
          ]) {
        expect(
          RuntimeClientBuild.tryCreate(
            applicationId: value.applicationId,
            version: value.version,
            buildNumber: value.buildNumber,
          ),
          isNull,
        );
      }

      final RuntimeClientBuild build = _build();
      expect(
        RuntimeClientIdentity.tryCreate(
          build: build,
          expectedApplicationId: 'me.newlines.kinflow',
          expectedConfiguredVersion: build.configuredVersion,
          contractVersion: '2026-08-09',
          environment: RuntimePolicyEnvironment.dev,
          platform: RuntimePolicyPlatform.android,
        ),
        isNull,
      );
      expect(
        RuntimeClientIdentity.tryCreate(
          build: build,
          expectedApplicationId: build.applicationId,
          expectedConfiguredVersion: '0.1.0-dev+11',
          contractVersion: '2026-08-09',
          environment: RuntimePolicyEnvironment.dev,
          platform: RuntimePolicyPlatform.android,
        ),
        isNull,
      );
    });

    test('contract versions are strict real ISO calendar dates', () {
      expect(RuntimeContractVersion.tryParse('2026-08-09'), isNotNull);
      for (final String value in <String>[
        '2026-8-09',
        '2026-02-29',
        '2026-08-09T00:00:00Z',
        '2026-08-09\n',
      ]) {
        expect(RuntimeContractVersion.tryParse(value), isNull);
      }
    });
  });

  group('runtime policy evaluation', () {
    test('allows supported clients while retaining display version', () {
      final AppRuntimePolicySnapshot snapshot = _snapshot(
        policy: _policy(minimumSupportedVersion: '9.9.9'),
      );

      expect(snapshot.decision, AppRuntimePolicyDecisionKind.allowed);
      expect(snapshot.policy.minimumSupportedVersion, '9.9.9');
      expect(snapshot.mutationsBlocked, isFalse);
    });

    test('requires update for build and contract bounds', () {
      for (final AppRuntimePolicy policy in <AppRuntimePolicy>[
        _policy(minimumSupportedBuild: 11),
        _policy(minimumContractVersion: '2026-08-10'),
        _policy(maximumContractVersion: '2026-08-08'),
      ]) {
        final AppRuntimePolicySnapshot snapshot = _snapshot(policy: policy);
        expect(snapshot.decision, AppRuntimePolicyDecisionKind.updateRequired);
        expect(snapshot.mutationsBlocked, isTrue);
      }
    });

    test('update requirement takes precedence over maintenance mode', () {
      final AppRuntimePolicySnapshot snapshot = _snapshot(
        policy: _policy(minimumSupportedBuild: 11, mutationsEnabled: false),
      );

      expect(snapshot.decision, AppRuntimePolicyDecisionKind.updateRequired);
    });

    test('read-only mode blocks only mutations for supported clients', () {
      final AppRuntimePolicySnapshot snapshot = _snapshot(
        policy: _policy(mutationsEnabled: false),
      );

      expect(snapshot.decision, AppRuntimePolicyDecisionKind.readOnly);
      expect(snapshot.mutationsBlocked, isTrue);
    });

    test('feature policy blocks only the exact capability', () {
      final AppRuntimePolicySnapshot snapshot = _snapshot(
        policy: _policy(),
        disabledFeatures: const <AppRuntimeFeature>{
          AppRuntimeFeature.billing,
          AppRuntimeFeature.notifications,
        },
      );

      expect(snapshot.mutationsBlocked, isFalse);
      expect(snapshot.mutationsBlockedFor(AppRuntimeFeature.chores), isFalse);
      expect(snapshot.mutationsBlockedFor(AppRuntimeFeature.billing), isTrue);
      expect(snapshot.disabledFeatures, <AppRuntimeFeature>[
        AppRuntimeFeature.notifications,
        AppRuntimeFeature.billing,
      ]);
      expect(
        () => snapshot.featurePolicies[AppRuntimeFeature.chores] =
            _featurePolicy(AppRuntimeFeature.chores),
        throwsUnsupportedError,
      );
    });

    test('feature policy set must be exact, unique, and scope correlated', () {
      final List<AppRuntimeFeaturePolicy> exact = _featurePolicies();

      expect(
        AppRuntimePolicySnapshot.evaluate(
          client: _identity(),
          policy: _policy(),
          featurePolicies: exact.take(exact.length - 1),
        ),
        isNull,
      );
      expect(
        AppRuntimePolicySnapshot.evaluate(
          client: _identity(),
          policy: _policy(),
          featurePolicies: <AppRuntimeFeaturePolicy>[...exact, exact.first],
        ),
        isNull,
      );
      expect(
        AppRuntimePolicySnapshot.evaluate(
          client: _identity(),
          policy: _policy(),
          featurePolicies: <AppRuntimeFeaturePolicy>[
            ...exact.skip(1),
            _featurePolicy(
              AppRuntimeFeature.household,
              environment: RuntimePolicyEnvironment.prod,
            ),
          ],
        ),
        isNull,
      );
    });

    test('fails closed for a policy from another scope', () {
      expect(
        AppRuntimePolicySnapshot.evaluate(
          client: _identity(),
          policy: _policy(environment: RuntimePolicyEnvironment.prod),
          featurePolicies: _featurePolicies(),
        ),
        isNull,
      );
    });

    test('rejects invalid ranges and timestamp provenance', () {
      expect(
        AppRuntimePolicy.tryCreate(
          environment: RuntimePolicyEnvironment.dev,
          platform: RuntimePolicyPlatform.android,
          minimumSupportedVersion: '0.1.0-dev',
          minimumSupportedBuild: 10,
          minimumContractVersion: RuntimeContractVersion.tryParse('2026-08-10'),
          maximumContractVersion: RuntimeContractVersion.tryParse('2026-08-09'),
          mutationsEnabled: true,
          policyVersion: 1,
          updatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
          evaluatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
        ),
        isNull,
      );
    });
  });
}

RuntimeClientBuild _build({int buildNumber = 10}) {
  return RuntimeClientBuild.tryCreate(
    applicationId: 'me.newlines.kinflow.dev',
    version: '0.1.0-dev',
    buildNumber: '$buildNumber',
  )!;
}

RuntimeClientIdentity _identity({RuntimeClientBuild? build}) {
  final RuntimeClientBuild actualBuild = build ?? _build();
  return RuntimeClientIdentity.tryCreate(
    build: actualBuild,
    expectedApplicationId: actualBuild.applicationId,
    expectedConfiguredVersion: actualBuild.configuredVersion,
    contractVersion: '2026-08-09',
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.android,
  )!;
}

AppRuntimePolicy _policy({
  RuntimePolicyEnvironment environment = RuntimePolicyEnvironment.dev,
  String minimumSupportedVersion = '0.1.0-dev',
  int minimumSupportedBuild = 10,
  String? minimumContractVersion = '2026-08-01',
  String? maximumContractVersion = '2026-08-31',
  bool mutationsEnabled = true,
}) {
  return AppRuntimePolicy.tryCreate(
    environment: environment,
    platform: RuntimePolicyPlatform.android,
    minimumSupportedVersion: minimumSupportedVersion,
    minimumSupportedBuild: minimumSupportedBuild,
    minimumContractVersion: minimumContractVersion == null
        ? null
        : RuntimeContractVersion.tryParse(minimumContractVersion),
    maximumContractVersion: maximumContractVersion == null
        ? null
        : RuntimeContractVersion.tryParse(maximumContractVersion),
    mutationsEnabled: mutationsEnabled,
    policyVersion: 3,
    updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
    evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
  )!;
}

AppRuntimePolicySnapshot _snapshot({
  required AppRuntimePolicy policy,
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) {
  return AppRuntimePolicySnapshot.evaluate(
    client: _identity(),
    policy: policy,
    featurePolicies: _featurePolicies(disabledFeatures: disabledFeatures),
  )!;
}

List<AppRuntimeFeaturePolicy> _featurePolicies({
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) {
  return <AppRuntimeFeaturePolicy>[
    for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
      _featurePolicy(
        feature,
        mutationsEnabled: !disabledFeatures.contains(feature),
      ),
  ];
}

AppRuntimeFeaturePolicy _featurePolicy(
  AppRuntimeFeature feature, {
  RuntimePolicyEnvironment environment = RuntimePolicyEnvironment.dev,
  bool mutationsEnabled = true,
}) {
  return AppRuntimeFeaturePolicy.tryCreate(
    environment: environment,
    platform: RuntimePolicyPlatform.android,
    feature: feature,
    mutationsEnabled: mutationsEnabled,
    policyVersion: 2,
    updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
    evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
  )!;
}
