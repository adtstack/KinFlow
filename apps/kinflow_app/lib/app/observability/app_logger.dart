import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_log_record.dart';
import 'package:kinflow_app/app/observability/app_telemetry_sanitizer.dart';

abstract interface class AppLogSink {
  void write(AppLogRecord record);
}

abstract interface class AppLogger {
  void debug(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  });

  void error(
    String event, {
    required String code,
    Map<String, Object?> attributes = const <String, Object?>{},
  });

  void info(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  });

  void warning(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  });
}

final class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void debug(String event, {Map<String, Object?> attributes = const {}}) {}

  @override
  void error(
    String event, {
    required String code,
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void info(String event, {Map<String, Object?> attributes = const {}}) {}

  @override
  void warning(String event, {Map<String, Object?> attributes = const {}}) {}
}

final class StructuredAppLogger implements AppLogger {
  factory StructuredAppLogger({
    required AppPublicConfiguration configuration,
    required Iterable<AppLogSink> sinks,
    DateTime Function()? clock,
    AppTelemetrySanitizer sanitizer = const AppTelemetrySanitizer(),
  }) {
    return StructuredAppLogger._(
      clock: clock ?? DateTime.now,
      configuration: configuration,
      sanitizer: sanitizer,
      sinks: List<AppLogSink>.unmodifiable(sinks),
    );
  }

  StructuredAppLogger._({
    required this._clock,
    required this._configuration,
    required this._sanitizer,
    required this._sinks,
  });

  final DateTime Function() _clock;
  final AppPublicConfiguration _configuration;
  final AppTelemetrySanitizer _sanitizer;
  final List<AppLogSink> _sinks;

  @override
  void debug(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _write(AppLogLevel.debug, event, attributes);
  }

  @override
  void error(
    String event, {
    required String code,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _write(AppLogLevel.error, event, <String, Object?>{
      ...attributes,
      'error_code': code,
    });
  }

  @override
  void info(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _write(AppLogLevel.info, event, attributes);
  }

  @override
  void warning(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _write(AppLogLevel.warning, event, attributes);
  }

  void _write(
    AppLogLevel level,
    String event,
    Map<String, Object?> attributes,
  ) {
    final AppLogRecord record = AppLogRecord(
      attributes: _sanitizer.sanitizeAttributes(attributes),
      contractVersion: _configuration.contractVersion,
      environment: _configuration.environment.value,
      event: _sanitizer.sanitizeStableMessage(
        event,
        fallback: 'application.logging.invalid_event',
      ),
      level: level,
      platform: 'android',
      release: _configuration.release,
      timestamp: _clock().toUtc(),
    );

    for (final AppLogSink sink in _sinks) {
      try {
        sink.write(record);
      } on Object {
        // Observability must never fail a user operation or application boot.
      }
    }
  }
}
