import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/bootstrap.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';

import 'support/fixtures/app_public_configuration_fixture.dart';

void main() {
  testWidgets('bootstrap validates valid and invalid config before app start', (
    WidgetTester tester,
  ) async {
    final _FakeObservabilityRunner observability = _FakeObservabilityRunner();

    await bootstrap(
      AppEnvironment.dev,
      configurationValues: publicConfigurationValues(),
      initializer: _successfulInitialization,
      observabilityRunner: observability,
    );
    await tester.pumpAndSettle();

    expect(observability.runCount, 1);
    expect(observability.configuration?.environment, AppEnvironment.dev);
    expect(observability.logger, isA<StructuredAppLogger>());
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
    );
    await tester.pumpAndSettle();

    expect(invalidObservability.runCount, 0);
    expect(find.byKey(const Key('startup.failure')), findsOneWidget);
    expect(find.textContaining('replace-with-environment-key'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

final class _FakeObservabilityRunner implements AppObservabilityRunner {
  AppPublicConfiguration? configuration;
  AppLogger? logger;
  var runCount = 0;

  @override
  Future<void> run({
    required void Function() appRunner,
    required AppPublicConfiguration configuration,
    required AppLogger logger,
  }) async {
    runCount += 1;
    this.configuration = configuration;
    this.logger = logger;
    appRunner();
  }
}

Future<void> _successfulInitialization() async {}
