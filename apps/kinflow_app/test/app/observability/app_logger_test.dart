import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/observability/app_log_record.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/observability/app_telemetry_sanitizer.dart';
import 'package:kinflow_app/infrastructure/observability/app_logging_composition.dart';
import 'package:kinflow_app/infrastructure/observability/json_console_log_sink.dart';

import '../../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test('emits deterministic structured correlation and allowlisted fields', () {
    final _MemoryLogSink sink = _MemoryLogSink();
    final StructuredAppLogger logger = StructuredAppLogger(
      clock: () => DateTime.utc(2026, 7, 25, 1, 2, 3),
      configuration: publicConfigurationFixture(),
      sinks: <AppLogSink>[sink],
    );

    logger.info(
      'household.create.succeeded',
      attributes: <String, Object?>{
        'duration_ms': 12,
        'feature': 'Household',
        'request_id': 'request_12345678',
        'result': 'Succeeded',
      },
    );

    expect(sink.records, hasLength(1));
    expect(sink.records.single.toJson(), <String, Object>{
      'timestamp': '2026-07-25T01:02:03.000Z',
      'level': 'info',
      'event': 'household.create.succeeded',
      'environment': 'dev',
      'release': 'me.newlines.kinflow.dev@0.1.0-dev+1',
      'contract_version': '2026-07-25',
      'platform': 'android',
      'attributes': <String, Object>{
        'duration_ms': 12,
        'feature': 'household',
        'request_id': 'request_12345678',
        'result': 'succeeded',
      },
    });
  });

  test('drops forbidden fields and redacts suspicious or free-form values', () {
    final _MemoryLogSink sink = _MemoryLogSink();
    final StructuredAppLogger logger = StructuredAppLogger(
      configuration: publicConfigurationFixture(),
      sinks: <AppLogSink>[sink],
    );
    final String jwt = <String>[
      'eyJfixture00',
      'payload0000',
      'signature0000',
    ].join('.');

    logger.error(
      'application.operation.failed',
      code: 'provider_failed',
      attributes: <String, Object?>{
        'email': 'adult@example.invalid',
        'title': 'Private household title',
        'provider': 'supabase',
        'provider_status': 'Bearer credential-value',
        'reason': 'Free form family content',
        'request_id': jwt,
        'nested': <String, Object>{'token': 'value'},
      },
    );

    final Map<String, Object> attributes = sink.records.single.attributes;
    expect(attributes.keys, <String>[
      'provider',
      'provider_status',
      'reason',
      'request_id',
      'error_code',
    ]);
    expect(attributes['provider'], 'supabase');
    expect(attributes['error_code'], 'provider_failed');
    expect(attributes['provider_status'], AppTelemetrySanitizer.redacted);
    expect(attributes['reason'], AppTelemetrySanitizer.redacted);
    expect(attributes['request_id'], AppTelemetrySanitizer.redacted);
    expect(jsonEncode(sink.records.single.toJson()), isNot(contains('adult@')));
    expect(
      jsonEncode(sink.records.single.toJson()),
      isNot(contains('Private')),
    );
  });

  test('isolates a broken sink and continues writing to healthy sinks', () {
    final _MemoryLogSink healthy = _MemoryLogSink();
    final StructuredAppLogger logger = StructuredAppLogger(
      configuration: publicConfigurationFixture(),
      sinks: <AppLogSink>[_ThrowingLogSink(), healthy],
    );

    expect(
      () => logger.warning('application.provider.degraded'),
      returnsNormally,
    );
    expect(healthy.records, hasLength(1));
  });

  test('dev selects console while prod never selects verbose console', () {
    final _MemoryLogSink console = _MemoryLogSink();
    final _MemoryLogSink sentry = _MemoryLogSink();

    expect(
      AppLoggingComposition.selectSinks(
        publicConfigurationFixture(),
        consoleSink: console,
        sentrySink: sentry,
      ),
      <AppLogSink>[console],
    );
    expect(
      AppLoggingComposition.selectSinks(
        publicConfigurationFixture(
          environment: AppEnvironment.prod,
          sentryEnabled: true,
        ),
        consoleSink: console,
        sentrySink: sentry,
      ),
      <AppLogSink>[sentry],
    );
  });

  test('JSON console sink emits the sanitized record only', () {
    final List<String> lines = <String>[];
    final JsonConsoleLogSink sink = JsonConsoleLogSink(writer: lines.add);
    final StructuredAppLogger logger = StructuredAppLogger(
      configuration: publicConfigurationFixture(),
      sinks: <AppLogSink>[sink],
    );

    logger.debug(
      'application.debug.recorded',
      attributes: const <String, Object?>{'screen': 'foundation'},
    );

    expect(lines, hasLength(1));
    expect(
      jsonDecode(lines.single),
      containsPair('event', 'application.debug.recorded'),
    );
    expect(lines.single, isNot(contains('SUPABASE_PUBLISHABLE_KEY')));
  });
}

final class _MemoryLogSink implements AppLogSink {
  final List<AppLogRecord> records = <AppLogRecord>[];

  @override
  void write(AppLogRecord record) {
    records.add(record);
  }
}

final class _ThrowingLogSink implements AppLogSink {
  @override
  void write(AppLogRecord record) {
    throw StateError('sink failure fixture');
  }
}
