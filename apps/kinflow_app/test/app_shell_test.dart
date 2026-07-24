import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/router/app_router.dart';

void main() {
  testWidgets('shows loading until initialization completes', (
    WidgetTester tester,
  ) async {
    final Completer<void> initializer = Completer<void>();

    await _pumpShell(
      tester,
      environment: AppEnvironment.dev,
      initializer: () => initializer.future,
    );

    expect(find.byKey(const Key('startup.loading')), findsOneWidget);
    expect(find.byKey(const Key('foundation.home')), findsNothing);

    initializer.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundation.home')), findsOneWidget);
  });

  testWidgets('hides raw startup error and recovers on retry', (
    WidgetTester tester,
  ) async {
    var attempts = 0;

    Future<void> initialize() async {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('raw-sensitive-startup-detail');
      }
    }

    await _pumpShell(
      tester,
      environment: AppEnvironment.dev,
      initializer: initialize,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup.failure')), findsOneWidget);
    expect(find.textContaining('raw-sensitive-startup-detail'), findsNothing);

    await tester.tap(find.byKey(const Key('startup.retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('foundation.home')), findsOneWidget);
  });

  testWidgets('shows environment banner only in dev', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      environment: AppEnvironment.dev,
      initializer: _successfulInitialization,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('environment.banner')), findsOneWidget);

    await _pumpShell(
      tester,
      environment: AppEnvironment.prod,
      initializer: _successfulInitialization,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('environment.banner')), findsNothing);
  });

  testWidgets('uses Korean localization from the locale provider', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      environment: AppEnvironment.prod,
      initializer: _successfulInitialization,
      locale: const Locale('ko'),
    );
    await tester.pumpAndSettle();

    expect(find.text('KinFlow를 사용할 준비가 되었습니다'), findsOneWidget);
  });

  testWidgets('renders a safe not-found route and returns home', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpShell(
      tester,
      environment: AppEnvironment.prod,
      initializer: _successfulInitialization,
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route.notFound')), findsOneWidget);

    await tester.tap(find.byKey(const Key('route.goHome')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundation.home')), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required AppEnvironment environment,
  required AppInitializer initializer,
  Locale? locale,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      appInitializerProvider.overrideWithValue(initializer),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );

  return container;
}

Future<void> _successfulInitialization() async {}
