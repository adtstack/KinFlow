import 'dart:async';

import 'package:kinflow_app/app/observability/app_log_record.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final class SentryStructuredLogSink implements AppLogSink {
  const SentryStructuredLogSink();

  @override
  void write(AppLogRecord record) {
    unawaited(_writeSafely(record));
  }

  Future<void> _writeSafely(AppLogRecord record) async {
    try {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'kinflow.structured',
          data: record.attributes,
          level: _sentryLevel(record.level),
          message: record.event,
          timestamp: record.timestamp,
          type: 'default',
        ),
      );
      if (record.level == AppLogLevel.error) {
        await Sentry.captureMessage(record.event, level: SentryLevel.error);
      }
    } on Object {
      // A telemetry provider failure must not escape into application logic.
    }
  }

  SentryLevel _sentryLevel(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => SentryLevel.debug,
      AppLogLevel.info => SentryLevel.info,
      AppLogLevel.warning => SentryLevel.warning,
      AppLogLevel.error => SentryLevel.error,
    };
  }
}
