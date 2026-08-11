import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/bootstrap.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';

import 'support/fixtures/app_public_configuration_fixture.dart';

void main() {
  testWidgets('bootstrap validates valid and invalid config before app start', (
    WidgetTester tester,
  ) async {
    final List<String> startupOrder = <String>[];
    final _FakeObservabilityRunner observability = _FakeObservabilityRunner(
      onRun: () => startupOrder.add('observability'),
    );

    await bootstrap(
      AppEnvironment.dev,
      configurationValues: publicConfigurationValues(),
      initializer: _successfulInitialization,
      observabilityRunner: observability,
      authDependenciesFactory: _loadUnavailableAuthDependencies,
      notificationPushBackgroundPreparer:
          (AppPublicConfiguration configuration) {
            startupOrder.add('push_background');
          },
    );
    await tester.pumpAndSettle();

    expect(observability.runCount, 1);
    expect(observability.configuration?.environment, AppEnvironment.dev);
    expect(observability.logger, isA<StructuredAppLogger>());
    expect(startupOrder, <String>['push_background', 'observability']);
    expect(find.byKey(const Key('auth.signIn')), findsOneWidget);
    expect(find.byKey(const Key('foundation.home')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final _FakeObservabilityRunner invalidObservability =
        _FakeObservabilityRunner();
    final Map<String, String> invalid = publicConfigurationValues()
      ..[AppPublicConfigurationKeys.supabasePublishableKey] =
          'replace-with-environment-key';

    await bootstrap(
      AppEnvironment.dev,
      configurationValues: invalid,
      initializer: _successfulInitialization,
      observabilityRunner: invalidObservability,
      authDependenciesFactory: _loadUnavailableAuthDependencies,
    );
    await tester.pumpAndSettle();

    expect(invalidObservability.runCount, 0);
    expect(find.byKey(const Key('startup.failure')), findsOneWidget);
    expect(find.textContaining('replace-with-environment-key'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('auth runtime initialization fails closed and retries', (
    WidgetTester tester,
  ) async {
    var attempt = 0;

    await bootstrap(
      AppEnvironment.dev,
      configurationValues: publicConfigurationValues(),
      initializer: _successfulInitialization,
      observabilityRunner: _FakeObservabilityRunner(),
      authDependenciesFactory: (AppPublicConfiguration configuration) async {
        attempt += 1;
        if (attempt == 1) {
          throw StateError('provider detail must stay private');
        }
        return createUnavailableAuthDependencies();
      },
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup.failure')), findsOneWidget);
    expect(find.textContaining('provider detail'), findsNothing);
    expect(find.byKey(const Key('auth.signIn')), findsNothing);

    await tester.tap(find.byKey(const Key('startup.retry')));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const Key('startup.failure')), findsNothing);
    expect(find.byKey(const Key('auth.signIn')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('auth runtime blocks the router while loading', (
    WidgetTester tester,
  ) async {
    final Completer<AuthDependencies> dependencies =
        Completer<AuthDependencies>();

    await bootstrap(
      AppEnvironment.dev,
      configurationValues: publicConfigurationValues(),
      initializer: _successfulInitialization,
      observabilityRunner: _FakeObservabilityRunner(),
      authDependenciesFactory: (AppPublicConfiguration configuration) {
        return dependencies.future;
      },
    );
    await tester.pump();

    expect(find.byKey(const Key('startup.loading')), findsOneWidget);
    expect(find.byKey(const Key('auth.loading')), findsNothing);
    expect(find.byKey(const Key('auth.signIn')), findsNothing);
    expect(find.byKey(const Key('foundation.home')), findsNothing);

    dependencies.complete(createUnavailableAuthDependencies());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup.loading')), findsNothing);
    expect(find.byKey(const Key('auth.signIn')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _FakeObservabilityRunner implements AppObservabilityRunner {
  _FakeObservabilityRunner({this.onRun});

  final void Function()? onRun;
  AppPublicConfiguration? configuration;
  AppLogger? logger;
  var runCount = 0;

  @override
  Future<void> run({
    required void Function() appRunner,
    required AppPublicConfiguration configuration,
    required AppLogger logger,
  }) async {
    onRun?.call();
    runCount += 1;
    this.configuration = configuration;
    this.logger = logger;
    appRunner();
  }
}

Future<void> _successfulInitialization() async {}

Future<AuthDependencies> _loadUnavailableAuthDependencies(
  AppPublicConfiguration configuration,
) async {
  return createUnavailableAuthDependencies();
}
