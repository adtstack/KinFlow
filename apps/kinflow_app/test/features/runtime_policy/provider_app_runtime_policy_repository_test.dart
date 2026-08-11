import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_controller.dart';
import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_state.dart';
import 'package:kinflow_app/features/runtime_policy/data/datasources/app_runtime_policy_data_source.dart';
import 'package:kinflow_app/features/runtime_policy/data/repositories/provider_app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

void main() {
  group('provider runtime policy repository', () {
    test('maps the exact provider projection and client decision', () async {
      final _RuntimePolicyDataSource dataSource = _RuntimePolicyDataSource(
        _payload(),
      );
      final AppRuntimePolicyRepository repository =
          ProviderAppRuntimePolicyRepository(
            dataSource: dataSource,
            client: _identity(),
          );

      final AppRuntimePolicyResult result = await repository.load();

      expect(result, isA<AppRuntimePolicySucceeded>());
      final AppRuntimePolicySnapshot snapshot =
          (result as AppRuntimePolicySucceeded).snapshot;
      expect(snapshot.decision, AppRuntimePolicyDecisionKind.allowed);
      expect(snapshot.policy.policyVersion, 4);
      expect(snapshot.disabledFeatures, isEmpty);
      expect(dataSource.requests, <(String, String)>[('dev', 'android')]);
      expect(dataSource.featureRequests, <(String, String)>[
        ('dev', 'android'),
      ]);
    });

    test('accepts the exact PostgREST Web UTC response shape', () async {
      final Map<String, Object?> payload = <String, Object?>{
        ..._payload(),
        'platform': 'web',
        'minimum_supported_version': '0.0.0',
        'minimum_supported_build': 0,
        'minimum_contract_version': null,
        'maximum_contract_version': null,
        'updated_at': '2026-08-09T00:00:00+00:00',
        'evaluated_at': '2026-08-09T00:00:01+00:00',
      };
      final List<Map<String, Object?>> featurePayloads = <Map<String, Object?>>[
        for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
          <String, Object?>{
            ..._featurePayload(feature),
            'platform': 'web',
            'updated_at': '2026-08-09T00:00:00+00:00',
            'evaluated_at': '2026-08-09T00:00:01+00:00',
          },
      ];
      final AppRuntimePolicyRepository repository =
          ProviderAppRuntimePolicyRepository(
            dataSource: _RuntimePolicyDataSource(
              payload,
              featurePayloads: featurePayloads,
            ),
            client: _webIdentity(),
          );

      final AppRuntimePolicyResult result = await repository.load();

      expect(result, isA<AppRuntimePolicySucceeded>());
      final AppRuntimePolicySnapshot snapshot =
          (result as AppRuntimePolicySucceeded).snapshot;
      expect(snapshot.client.platform, RuntimePolicyPlatform.web);
      expect(snapshot.decision, AppRuntimePolicyDecisionKind.allowed);
    });

    test('rejects extra, missing, mistyped, and non-UTC fields', () async {
      final List<Map<String, Object?>> invalid = <Map<String, Object?>>[
        <String, Object?>{..._payload(), 'private_note': 'must-not-cross'},
        <String, Object?>{..._payload()}..remove('policy_version'),
        <String, Object?>{..._payload(), 'minimum_supported_build': '10'},
        <String, Object?>{
          ..._payload(),
          'evaluated_at': '2026-08-09T09:00:01+09:00',
        },
        <String, Object?>{
          ..._payload(),
          'minimum_contract_version': '2026-02-29',
        },
        <String, Object?>{..._payload(), 'environment': 'prod'},
      ];

      for (final Map<String, Object?> payload in invalid) {
        final AppRuntimePolicyResult result = await _repository(payload).load();
        expect(result, isA<AppRuntimePolicyFailed>());
        expect(
          (result as AppRuntimePolicyFailed).failure.kind,
          AppRuntimePolicyFailureKind.invalidPayload,
        );
      }
    });

    test('maps provider exceptions to a safe unavailable failure', () async {
      final AppRuntimePolicyRepository repository =
          ProviderAppRuntimePolicyRepository(
            dataSource: _ThrowingRuntimePolicyDataSource(),
            client: _identity(),
          );

      final AppRuntimePolicyResult result = await repository.load();

      expect(result, isA<AppRuntimePolicyFailed>());
      expect(
        (result as AppRuntimePolicyFailed).failure.kind,
        AppRuntimePolicyFailureKind.unavailable,
      );
    });

    test('requires exactly six unique strict feature rows', () async {
      final List<List<Map<String, Object?>>> invalid =
          <List<Map<String, Object?>>>[
            _featurePayloads().take(5).toList(),
            <Map<String, Object?>>[
              ..._featurePayloads().take(5),
              _featurePayloads().first,
            ],
            <Map<String, Object?>>[
              <String, Object?>{
                ..._featurePayload(AppRuntimeFeature.household),
                'private_note': 'must-not-cross',
              },
              ..._featurePayloads().skip(1),
            ],
            <Map<String, Object?>>[
              <String, Object?>{
                ..._featurePayload(AppRuntimeFeature.household),
                'feature': 'unknown',
              },
              ..._featurePayloads().skip(1),
            ],
            <Map<String, Object?>>[
              <String, Object?>{
                ..._featurePayload(AppRuntimeFeature.household),
                'environment': 'prod',
              },
              ..._featurePayloads().skip(1),
            ],
            <Map<String, Object?>>[
              <String, Object?>{
                ..._featurePayload(AppRuntimeFeature.household),
                'policy_version': '1',
              },
              ..._featurePayloads().skip(1),
            ],
            <Map<String, Object?>>[
              <String, Object?>{
                ..._featurePayload(AppRuntimeFeature.household),
                'evaluated_at': '2026-08-09T09:00:01+09:00',
              },
              ..._featurePayloads().skip(1),
            ],
          ];

      for (final List<Map<String, Object?>> featurePayloads in invalid) {
        final AppRuntimePolicyResult result = await _repository(
          _payload(),
          featurePayloads: featurePayloads,
        ).load();
        expect(result, isA<AppRuntimePolicyFailed>());
        expect(
          (result as AppRuntimePolicyFailed).failure.kind,
          AppRuntimePolicyFailureKind.invalidPayload,
        );
      }
    });

    test(
      'maps disabled features without broadening the global decision',
      () async {
        final AppRuntimePolicyResult result = await _repository(
          _payload(),
          featurePayloads: _featurePayloads(
            disabledFeatures: const <AppRuntimeFeature>{
              AppRuntimeFeature.calendar,
            },
          ),
        ).load();

        final AppRuntimePolicySnapshot snapshot =
            (result as AppRuntimePolicySucceeded).snapshot;
        expect(snapshot.decision, AppRuntimePolicyDecisionKind.allowed);
        expect(snapshot.disabledFeatures, <AppRuntimeFeature>[
          AppRuntimeFeature.calendar,
        ]);
        expect(
          snapshot.mutationsBlockedFor(AppRuntimeFeature.calendar),
          isTrue,
        );
        expect(snapshot.mutationsBlockedFor(AppRuntimeFeature.chores), isFalse);
      },
    );
  });

  group('runtime policy controller', () {
    test('coalesces concurrent loads into one provider request', () async {
      final Completer<AppRuntimePolicyResult> completer =
          Completer<AppRuntimePolicyResult>();
      final _RuntimePolicyRepository repository = _RuntimePolicyRepository(
        () => completer.future,
      );
      final AppRuntimePolicyController controller = AppRuntimePolicyController(
        repository,
      );
      addTearDown(controller.dispose);

      final Future<void> first = controller.load();
      final Future<void> second = controller.load();

      expect(identical(first, second), isTrue);
      expect(repository.calls, 1);
      expect(controller.state, isA<AppRuntimePolicyLoading>());

      completer.complete(AppRuntimePolicySucceeded(_snapshot()));
      await first;
      expect(controller.state, isA<AppRuntimePolicyReady>());
    });

    test('resume failure preserves the last authoritative decision', () async {
      var calls = 0;
      final _RuntimePolicyRepository repository = _RuntimePolicyRepository(() {
        calls += 1;
        return Future<AppRuntimePolicyResult>.value(
          calls == 1
              ? AppRuntimePolicySucceeded(_snapshot(mutationsEnabled: false))
              : const AppRuntimePolicyFailed(
                  AppRuntimePolicyFailure(
                    AppRuntimePolicyFailureKind.unavailable,
                  ),
                ),
        );
      });
      final AppRuntimePolicyController controller = AppRuntimePolicyController(
        repository,
      );
      addTearDown(controller.dispose);

      await controller.load();
      final AppRuntimePolicyReady first =
          controller.state as AppRuntimePolicyReady;
      expect(first.snapshot.decision, AppRuntimePolicyDecisionKind.readOnly);

      await controller.load(preserveContent: true);

      final AppRuntimePolicyReady preserved =
          controller.state as AppRuntimePolicyReady;
      expect(identical(preserved.snapshot, first.snapshot), isTrue);
      expect(
        preserved.refreshFailure?.kind,
        AppRuntimePolicyFailureKind.unavailable,
      );
      expect(preserved.isRefreshing, isFalse);
    });

    test('unexpected repository exceptions never escape to UI state', () async {
      final AppRuntimePolicyController controller = AppRuntimePolicyController(
        _RuntimePolicyRepository(
          () => throw StateError('private upstream response'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      final AppRuntimePolicyLoadFailed failed =
          controller.state as AppRuntimePolicyLoadFailed;
      expect(failed.failure.kind, AppRuntimePolicyFailureKind.unavailable);
    });
  });
}

ProviderAppRuntimePolicyRepository _repository(
  Map<String, Object?> payload, {
  List<Map<String, Object?>>? featurePayloads,
}) {
  return ProviderAppRuntimePolicyRepository(
    dataSource: _RuntimePolicyDataSource(
      payload,
      featurePayloads: featurePayloads,
    ),
    client: _identity(),
  );
}

Map<String, Object?> _payload() => <String, Object?>{
  'environment': 'dev',
  'platform': 'android',
  'minimum_supported_version': '0.1.0-dev',
  'minimum_supported_build': 10,
  'minimum_contract_version': '2026-08-01',
  'maximum_contract_version': '2026-08-31',
  'mutations_enabled': true,
  'policy_version': 4,
  'updated_at': '2026-08-09T00:00:00Z',
  'evaluated_at': '2026-08-09T00:00:01Z',
};

List<Map<String, Object?>> _featurePayloads({
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) {
  return <Map<String, Object?>>[
    for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
      _featurePayload(
        feature,
        mutationsEnabled: !disabledFeatures.contains(feature),
      ),
  ];
}

Map<String, Object?> _featurePayload(
  AppRuntimeFeature feature, {
  bool mutationsEnabled = true,
}) {
  return <String, Object?>{
    'environment': 'dev',
    'platform': 'android',
    'feature': feature.wireValue,
    'mutations_enabled': mutationsEnabled,
    'policy_version': 2,
    'updated_at': '2026-08-09T00:00:00Z',
    'evaluated_at': '2026-08-09T00:00:01Z',
  };
}

RuntimeClientIdentity _identity() {
  final RuntimeClientBuild build = RuntimeClientBuild.tryCreate(
    applicationId: 'me.newlines.kinflow.dev',
    version: '0.1.0-dev',
    buildNumber: '10',
  )!;
  return RuntimeClientIdentity.tryCreate(
    build: build,
    expectedApplicationId: build.applicationId,
    expectedConfiguredVersion: build.configuredVersion,
    contractVersion: '2026-08-09',
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.android,
  )!;
}

RuntimeClientIdentity _webIdentity() {
  final RuntimeClientBuild build = RuntimeClientBuild.tryCreate(
    applicationId: 'kinflow_app',
    version: '0.1.0-dev',
    buildNumber: '1',
  )!;
  return RuntimeClientIdentity.tryCreate(
    build: build,
    expectedApplicationId: build.applicationId,
    expectedConfiguredVersion: build.configuredVersion,
    contractVersion: '2026-08-09',
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.web,
  )!;
}

AppRuntimePolicySnapshot _snapshot({bool mutationsEnabled = true}) {
  final AppRuntimePolicy policy = AppRuntimePolicy.tryCreate(
    environment: RuntimePolicyEnvironment.dev,
    platform: RuntimePolicyPlatform.android,
    minimumSupportedVersion: '0.1.0-dev',
    minimumSupportedBuild: 10,
    minimumContractVersion: RuntimeContractVersion.tryParse('2026-08-01'),
    maximumContractVersion: RuntimeContractVersion.tryParse('2026-08-31'),
    mutationsEnabled: mutationsEnabled,
    policyVersion: 4,
    updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
    evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
  )!;
  return AppRuntimePolicySnapshot.evaluate(
    client: _identity(),
    policy: policy,
    featurePolicies: <AppRuntimeFeaturePolicy>[
      for (final AppRuntimeFeature feature in AppRuntimeFeature.values)
        AppRuntimeFeaturePolicy.tryCreate(
          environment: RuntimePolicyEnvironment.dev,
          platform: RuntimePolicyPlatform.android,
          feature: feature,
          mutationsEnabled: true,
          policyVersion: 2,
          updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
          evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
        )!,
    ],
  )!;
}

final class _RuntimePolicyDataSource implements AppRuntimePolicyDataSource {
  _RuntimePolicyDataSource(
    this.payload, {
    List<Map<String, Object?>>? featurePayloads,
  }) : featurePayloads = featurePayloads ?? _featurePayloads();

  final Map<String, Object?> payload;
  final List<Map<String, Object?>> featurePayloads;
  final List<(String, String)> requests = <(String, String)>[];
  final List<(String, String)> featureRequests = <(String, String)>[];

  @override
  Future<Map<String, Object?>> fetch({
    required String environment,
    required String platform,
  }) async {
    requests.add((environment, platform));
    return payload;
  }

  @override
  Future<List<Map<String, Object?>>> fetchFeatures({
    required String environment,
    required String platform,
  }) async {
    featureRequests.add((environment, platform));
    return featurePayloads;
  }
}

final class _ThrowingRuntimePolicyDataSource
    implements AppRuntimePolicyDataSource {
  @override
  Future<Map<String, Object?>> fetch({
    required String environment,
    required String platform,
  }) async {
    throw StateError('private provider response');
  }

  @override
  Future<List<Map<String, Object?>>> fetchFeatures({
    required String environment,
    required String platform,
  }) async {
    throw StateError('private provider response');
  }
}

final class _RuntimePolicyRepository implements AppRuntimePolicyRepository {
  _RuntimePolicyRepository(this.callback);

  final Future<AppRuntimePolicyResult> Function() callback;
  var calls = 0;

  @override
  Future<AppRuntimePolicyResult> load() {
    calls += 1;
    return callback();
  }
}
