import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/observability/app_telemetry_sanitizer.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_privacy_filter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test('configures Sentry with explicit privacy-first foundation options', () {
    final configuration = publicConfigurationFixture(sentryEnabled: true);
    final SentryFlutterOptions options = SentryFlutterOptions();

    SentryObservabilityRunner.configureOptions(options, configuration);

    expect(options.dsn?.toString(), configuration.sentryDsn.toString());
    expect(options.environment, 'dev');
    expect(options.release, configuration.release);
    expect(options.dist, configuration.contractVersion);
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.reportViewHierarchyIdentifiers, isFalse);
    expect(options.captureFailedRequests, isFalse);
    expect(options.captureNativeFailedRequests, isFalse);
    expect(options.recordHttpBreadcrumbs, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enableAutoPerformanceTracing, isFalse);
    expect(options.enableFramesTracking, isFalse);
    expect(options.enableLogs, isFalse);
    expect(options.tracesSampleRate, isNull);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.beforeSend, isNotNull);
    expect(options.beforeBreadcrumb, isNotNull);
  });

  test(
    'before-send removes identity, request, content, and local variables',
    () {
      final configuration = publicConfigurationFixture(sentryEnabled: true);
      final SentryPrivacyFilter filter = SentryPrivacyFilter(
        configuration: configuration,
      );
      final SentryEvent unsafe = SentryEvent(
        breadcrumbs: <Breadcrumb>[
          Breadcrumb(
            category: 'http',
            data: <String, Object?>{
              'url': 'https://example.invalid/path?token=value',
            },
            message: 'unsafe request',
          ),
          Breadcrumb(
            category: 'kinflow.structured',
            data: <String, Object?>{
              'feature': 'foundation',
              'reason': 'Adult private content',
            },
            message: 'application.initialization.failed',
          ),
        ],
        exceptions: <SentryException>[
          SentryException(
            stackTrace: SentryStackTrace(
              frames: <SentryStackFrame>[
                SentryStackFrame(
                  absPath: '/Users/private-person/project/file.dart',
                  contextLine: 'throw StateError(adult@example.invalid);',
                  fileName: '/Users/private-person/project/file.dart',
                  function: 'initializeApp',
                  vars: <String, Object?>{'token': 'credential'},
                ),
              ],
            ),
            type: 'StateError',
            value: 'adult@example.invalid private title',
          ),
        ],
        // ignore: deprecated_member_use
        extra: <String, Object?>{'title': 'Private chore'},
        message: SentryMessage('adult@example.invalid failed'),
        request: SentryRequest(url: 'https://example.invalid/path?token=value'),
        serverName: 'private-device-name',
        tags: <String, String>{'email': 'adult@example.invalid'},
        transaction: '/household/private-title',
        user: SentryUser(email: 'adult@example.invalid', id: 'raw-user-id'),
      );

      final SentryEvent safe = filter.sanitizeEvent(unsafe, Hint());
      final String payload = jsonEncode(safe.toJson());

      expect(safe.user, isNull);
      expect(safe.request, isNull);
      expect(safe.transaction, isNull);
      expect(safe.serverName, isNull);
      expect(safe.contexts.toJson(), isEmpty);
      expect(safe.message?.formatted, AppTelemetrySanitizer.redacted);
      expect(safe.breadcrumbs, hasLength(1));
      expect(safe.breadcrumbs?.single.category, 'kinflow.structured');
      expect(
        safe.breadcrumbs?.single.data?['reason'],
        AppTelemetrySanitizer.redacted,
      );
      expect(safe.exceptions?.single.value, AppTelemetrySanitizer.redacted);
      expect(safe.exceptions?.single.stackTrace?.frames.single.absPath, isNull);
      expect(safe.exceptions?.single.stackTrace?.frames.single.vars, isEmpty);
      expect(payload, isNot(contains('adult@example.invalid')));
      expect(payload, isNot(contains('private-person')));
      expect(payload, isNot(contains('Private chore')));
      expect(payload, isNot(contains('credential')));
      expect(payload, isNot(contains('?token=')));
    },
  );

  test('breadcrumb filter drops every non-KinFlow breadcrumb', () {
    final SentryPrivacyFilter filter = SentryPrivacyFilter(
      configuration: publicConfigurationFixture(sentryEnabled: true),
    );

    expect(
      filter.sanitizeBreadcrumb(
        Breadcrumb.http(
          method: 'GET',
          url: Uri.parse('https://example.invalid/private'),
        ),
        Hint(),
      ),
      isNull,
    );
  });

  test('Sentry initialization failure starts app once with safe log', () async {
    final _RecordingLogger logger = _RecordingLogger();
    var appStarts = 0;
    final SentryObservabilityRunner runner = SentryObservabilityRunner(
      initializer:
          ({
            required void Function() appRunner,
            required FlutterOptionsConfiguration optionsConfiguration,
          }) async {
            await Future<void>.sync(
              () => optionsConfiguration(SentryFlutterOptions()),
            );
            throw StateError('raw provider setup detail');
          },
    );

    await runner.run(
      appRunner: () => appStarts += 1,
      configuration: publicConfigurationFixture(sentryEnabled: true),
      logger: logger,
    );

    expect(appStarts, 1);
    expect(logger.errorEvents, <String>[
      'application.observability.failed:sentry_initialization_failed',
    ]);
    expect(logger.errorEvents.join(), isNot(contains('raw provider setup')));
  });
}

final class _RecordingLogger implements AppLogger {
  final List<String> errorEvents = <String>[];

  @override
  void debug(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {}

  @override
  void error(
    String event, {
    required String code,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    errorEvents.add('$event:$code');
  }

  @override
  void info(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {}

  @override
  void warning(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {}
}
