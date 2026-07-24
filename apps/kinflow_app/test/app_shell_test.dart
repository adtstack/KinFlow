import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:kinflow_app/features/foundation/domain/value_objects/foundation_sample_id.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';

import 'support/fakes/fake_foundation_repository.dart';

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
    final _RecordingAppLogger logger = _RecordingAppLogger();

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
      logger: logger,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup.failure')), findsOneWidget);
    expect(find.textContaining('raw-sensitive-startup-detail'), findsNothing);
    expect(
      logger.entries.any(
        (_RecordedLog entry) =>
            entry.event == 'application.initialization.failed' &&
            entry.code == 'dependency_initialization_failed',
      ),
      isTrue,
    );
    expect(
      jsonEncode(
        logger.entries
            .map((_RecordedLog entry) => entry.toJson())
            .toList(growable: false),
      ),
      isNot(contains('raw-sensitive-startup-detail')),
    );

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

  testWidgets('repository override drives failure and retry presentation', (
    WidgetTester tester,
  ) async {
    final FakeFoundationRepository repository = FakeFoundationRepository(
      results: <LoadFoundationResult>[
        const FoundationLoadFailed(FoundationUnavailable()),
        FoundationLoaded(
          FoundationStatus(
            id: _foundationSampleId(),
            readiness: FoundationReadiness.ready,
          ),
        ),
      ],
    );

    await _pumpShell(
      tester,
      environment: AppEnvironment.prod,
      initializer: _successfulInitialization,
      foundationRepository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foundation.failure')), findsOneWidget);

    await tester.tap(find.byKey(const Key('foundation.retry')));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.byKey(const Key('foundation.ready')), findsOneWidget);
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
  FoundationRepository? foundationRepository,
  Locale? locale,
  AppLogger? logger,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      appInitializerProvider.overrideWithValue(initializer),
      foundationRepositoryProvider.overrideWithValue(
        foundationRepository ?? createFoundationRepository(),
      ),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
      if (logger != null) appLoggerProvider.overrideWithValue(logger),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );

  return container;
}

final class _RecordedLog {
  const _RecordedLog({
    required this.attributes,
    required this.code,
    required this.event,
    required this.level,
  });

  final Map<String, Object?> attributes;
  final String? code;
  final String event;
  final String level;

  Map<String, Object?> toJson() => <String, Object?>{
    'attributes': attributes,
    'code': code,
    'event': event,
    'level': level,
  };
}

final class _RecordingAppLogger implements AppLogger {
  final List<_RecordedLog> entries = <_RecordedLog>[];

  @override
  void debug(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _add('debug', event, attributes: attributes);
  }

  @override
  void error(
    String event, {
    required String code,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _add('error', event, attributes: attributes, code: code);
  }

  @override
  void info(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _add('info', event, attributes: attributes);
  }

  @override
  void warning(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _add('warning', event, attributes: attributes);
  }

  void _add(
    String level,
    String event, {
    required Map<String, Object?> attributes,
    String? code,
  }) {
    entries.add(
      _RecordedLog(
        attributes: Map<String, Object?>.unmodifiable(attributes),
        code: code,
        event: event,
        level: level,
      ),
    );
  }
}

Future<void> _successfulInitialization() async {}

FoundationSampleId _foundationSampleId() {
  final FoundationSampleId? id = FoundationSampleId.tryParse('test-foundation');
  if (id == null) {
    throw StateError('Static test foundation id must be valid.');
  }
  return id;
}
