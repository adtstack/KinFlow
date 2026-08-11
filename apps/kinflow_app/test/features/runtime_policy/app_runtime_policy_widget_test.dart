import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/widgets/app_runtime_policy_lifecycle_host.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('supported policy leaves the application content unchanged', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyRepository repository = _RuntimePolicyRepository(
      <AppRuntimePolicyResult>[AppRuntimePolicySucceeded(_snapshot())],
    );

    await _pumpHost(tester, repository: repository);

    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.host')), findsNothing);
    expect(repository.calls, 1);
  });

  testWidgets('read-only policy keeps reads visible and blocks mutations', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyRepository repository = _RuntimePolicyRepository(
      <AppRuntimePolicyResult>[
        AppRuntimePolicySucceeded(_snapshot(mutationsEnabled: false)),
      ],
    );

    await _pumpHost(tester, repository: repository);

    expect(find.byKey(const Key('runtimePolicy.readOnly')), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    final BuildContext context = tester.element(
      find.byKey(const Key('runtimePolicy.child')),
    );
    expect(
      ProviderScope.containerOf(
        context,
      ).read(appRuntimePolicyMutationsBlockedProvider),
      isTrue,
    );
  });

  testWidgets('failed initial fetch preserves app access and retries', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyRepository repository =
        _RuntimePolicyRepository(<AppRuntimePolicyResult>[
          const AppRuntimePolicyFailed(
            AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
          ),
          AppRuntimePolicySucceeded(_snapshot()),
        ]);

    await _pumpHost(tester, repository: repository);

    expect(find.byKey(const Key('runtimePolicy.unavailable')), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.detailsBody')), findsNothing);

    await tester.tap(find.byKey(const Key('runtimePolicy.details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('runtimePolicy.detailsBody')), findsOneWidget);

    await tester.tap(find.byKey(const Key('runtimePolicy.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('runtimePolicy.unavailable')), findsNothing);
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('unavailable details expose and perform a semantic toggle', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _RuntimePolicyRepository repository =
        _RuntimePolicyRepository(<AppRuntimePolicyResult>[
          const AppRuntimePolicyFailed(
            AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
          ),
        ]);
    try {
      await _pumpHost(
        tester,
        repository: repository,
        locale: const Locale('en', 'XA'),
      );

      final BuildContext detailsContext = tester.element(
        find.byKey(const Key('runtimePolicy.details.semantics')),
      );
      final String detailsLabel = MaterialLocalizations.of(
        detailsContext,
      ).moreButtonTooltip;
      final details = find.semantics.byLabel(detailsLabel);
      expect(details, findsOne);
      expect(
        details.evaluate().single,
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(details);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('runtimePolicy.detailsBody')),
        findsOneWidget,
      );
      expect(
        details.evaluate().single,
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('feature restriction lists exact capabilities only', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyRepository repository = _RuntimePolicyRepository(
      <AppRuntimePolicyResult>[
        AppRuntimePolicySucceeded(
          _snapshot(
            disabledFeatures: const <AppRuntimeFeature>{
              AppRuntimeFeature.chores,
              AppRuntimeFeature.billing,
            },
          ),
        ),
      ],
    );

    await _pumpHost(tester, repository: repository);

    expect(
      find.byKey(const Key('runtimePolicy.featureDisabled')),
      findsOneWidget,
    );
    expect(find.textContaining('Chores'), findsOneWidget);
    expect(find.textContaining('Billing'), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    final BuildContext context = tester.element(
      find.byKey(const Key('runtimePolicy.child')),
    );
    final ProviderContainer container = ProviderScope.containerOf(context);
    expect(container.read(appRuntimePolicyMutationsBlockedProvider), isFalse);
    expect(
      container.read(
        appRuntimePolicyFeatureMutationsBlockedProvider(
          AppRuntimeFeature.chores,
        ),
      ),
      isTrue,
    );
    expect(
      container.read(
        appRuntimePolicyFeatureMutationsBlockedProvider(
          AppRuntimeFeature.calendar,
        ),
      ),
      isFalse,
    );
  });

  testWidgets('resume failure preserves the last read-only restriction', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyRepository repository =
        _RuntimePolicyRepository(<AppRuntimePolicyResult>[
          AppRuntimePolicySucceeded(_snapshot(mutationsEnabled: false)),
          const AppRuntimePolicyFailed(
            AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
          ),
        ]);
    await _pumpHost(tester, repository: repository);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('runtimePolicy.readOnly')), findsOneWidget);
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('update action uses fixed launcher and shows safe failure', (
    WidgetTester tester,
  ) async {
    final _RuntimePolicyExternalLinkLauncher launcher =
        _RuntimePolicyExternalLinkLauncher(result: false);
    final _RuntimePolicyRepository repository = _RuntimePolicyRepository(
      <AppRuntimePolicyResult>[
        AppRuntimePolicySucceeded(_snapshot(minimumSupportedBuild: 11)),
      ],
    );
    await _pumpHost(tester, repository: repository, externalLauncher: launcher);

    expect(
      find.byKey(const Key('runtimePolicy.updateRequired')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('runtimePolicy.update')));
    await tester.pumpAndSettle();

    expect(launcher.calls, 1);
    expect(
      find.byKey(const Key('runtimePolicy.updateFailure')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('runtimePolicy.child')), findsOneWidget);
  });

  testWidgets('banner remains usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final _RuntimePolicyRepository repository =
        _RuntimePolicyRepository(<AppRuntimePolicyResult>[
          AppRuntimePolicySucceeded(
            _snapshot(disabledFeatures: AppRuntimeFeature.values.toSet()),
          ),
        ]);

    await _pumpHost(
      tester,
      repository: repository,
      locale: const Locale('en', 'XA'),
    );

    final Finder retry = find.byKey(const Key('runtimePolicy.retry'));
    await tester.ensureVisible(retry);
    await tester.pump();
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required _RuntimePolicyRepository repository,
  RuntimePolicyExternalLinkLauncher? externalLauncher,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRuntimePolicyRepositoryProvider.overrideWithValue(repository),
        runtimePolicyExternalLinkLauncherProvider.overrideWithValue(
          externalLauncher ?? _RuntimePolicyExternalLinkLauncher(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return AppRuntimePolicyLifecycleHost(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Scaffold(
          body: Center(
            child: Text('Readable content', key: Key('runtimePolicy.child')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppRuntimePolicySnapshot _snapshot({
  int minimumSupportedBuild = 10,
  bool mutationsEnabled = true,
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) {
  final RuntimeClientBuild build = RuntimeClientBuild.tryCreate(
    applicationId: 'me.newlines.kinflow.dev',
    version: '0.1.0-dev',
    buildNumber: '10',
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
    minimumSupportedVersion: '0.2.0-dev',
    minimumSupportedBuild: minimumSupportedBuild,
    minimumContractVersion: RuntimeContractVersion.tryParse('2026-08-01'),
    maximumContractVersion: RuntimeContractVersion.tryParse('2026-08-31'),
    mutationsEnabled: mutationsEnabled,
    policyVersion: 4,
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
          policyVersion: 2,
          updatedAt: DateTime.parse('2026-08-09T00:00:00Z'),
          evaluatedAt: DateTime.parse('2026-08-09T00:00:01Z'),
        )!,
    ],
  )!;
}

final class _RuntimePolicyRepository implements AppRuntimePolicyRepository {
  _RuntimePolicyRepository(this.results);

  final List<AppRuntimePolicyResult> results;
  var calls = 0;

  @override
  Future<AppRuntimePolicyResult> load() async {
    final int index = calls;
    calls += 1;
    return results[index < results.length ? index : results.length - 1];
  }
}

final class _RuntimePolicyExternalLinkLauncher
    implements RuntimePolicyExternalLinkLauncher {
  _RuntimePolicyExternalLinkLauncher({this.result = true});

  final bool result;
  var calls = 0;

  @override
  Future<bool> launchUpdate() async {
    calls += 1;
    return result;
  }
}
