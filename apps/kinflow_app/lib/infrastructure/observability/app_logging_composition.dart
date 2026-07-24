import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/infrastructure/observability/json_console_log_sink.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_structured_log_sink.dart';

abstract final class AppLoggingComposition {
  static AppLogger create(AppPublicConfiguration configuration) {
    return StructuredAppLogger(
      configuration: configuration,
      sinks: selectSinks(
        configuration,
        consoleSink: JsonConsoleLogSink(),
        sentrySink: const SentryStructuredLogSink(),
      ),
    );
  }

  static List<AppLogSink> selectSinks(
    AppPublicConfiguration configuration, {
    required AppLogSink consoleSink,
    required AppLogSink sentrySink,
  }) {
    return <AppLogSink>[
      if (!configuration.environment.isProduction) consoleSink,
      if (configuration.isSentryEnabled) sentrySink,
    ];
  }
}
