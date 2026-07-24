import 'package:flutter/widgets.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_privacy_filter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef SentryInitializer =
    Future<void> Function({
      required void Function() appRunner,
      required FlutterOptionsConfiguration optionsConfiguration,
    });

abstract interface class AppObservabilityRunner {
  Future<void> run({
    required void Function() appRunner,
    required AppPublicConfiguration configuration,
    required AppLogger logger,
  });
}

final class SentryObservabilityRunner implements AppObservabilityRunner {
  const SentryObservabilityRunner({this.initializer = _initializeSentry});

  final SentryInitializer initializer;

  @override
  Future<void> run({
    required void Function() appRunner,
    required AppPublicConfiguration configuration,
    required AppLogger logger,
  }) async {
    if (!configuration.isSentryEnabled) {
      WidgetsFlutterBinding.ensureInitialized();
      logger.info(
        'application.observability.disabled',
        attributes: const <String, Object?>{
          'capability': 'sentry',
          'reason': 'configuration_absent',
        },
      );
      appRunner();
      return;
    }

    var appStarted = false;
    void startAppOnce() {
      if (!appStarted) {
        appStarted = true;
        appRunner();
      }
    }

    try {
      await initializer(
        appRunner: startAppOnce,
        optionsConfiguration: (SentryFlutterOptions options) {
          configureOptions(options, configuration);
        },
      );
    } on Object {
      logger.error(
        'application.observability.failed',
        code: 'sentry_initialization_failed',
        attributes: const <String, Object?>{
          'capability': 'sentry',
          'result': 'failed',
        },
      );
      WidgetsFlutterBinding.ensureInitialized();
      startAppOnce();
    }
  }

  static void configureOptions(
    SentryFlutterOptions options,
    AppPublicConfiguration configuration,
  ) {
    final SentryPrivacyFilter privacyFilter = SentryPrivacyFilter(
      configuration: configuration,
    );
    options.anrEnabled = true;
    options.attachScreenshot = false;
    options.attachStacktrace = true;
    options.attachThreads = false;
    // ignore: experimental_member_use
    options.attachViewHierarchy = false;
    options.beforeBreadcrumb = privacyFilter.sanitizeBreadcrumb;
    options.beforeSend = privacyFilter.sanitizeEvent;
    options.beforeSendFeedback = (SentryEvent _, Hint _) => null;
    options.beforeSendLog = (SentryLog _) => null;
    options.beforeSendMetric = (SentryMetric _) => null;
    options.beforeSendTransaction = (SentryTransaction _, Hint _) => null;
    options.captureFailedRequests = false;
    options.captureNativeFailedRequests = false;
    options.debug = false;
    options.dist = configuration.contractVersion;
    options.dsn = configuration.sentryDsn!.toString();
    options.enableAppHangTracking = false;
    options.enableAppLifecycleBreadcrumbs = false;
    options.enableAutoNativeBreadcrumbs = false;
    options.enableAutoPerformanceTracing = false;
    options.enableAutoSessionTracking = true;
    options.enableBrightnessChangeBreadcrumbs = false;
    options.enableFramesTracking = false;
    options.enableLogs = false;
    options.enableMemoryPressureBreadcrumbs = false;
    options.enableNativeTraceSync = false;
    options.enableNdkScopeSync = false;
    options.enablePrintBreadcrumbs = false;
    options.enableScopeSync = false;
    options.enableTextScaleChangeBreadcrumbs = false;
    options.enableUserInteractionBreadcrumbs = false;
    options.enableUserInteractionTracing = false;
    options.enableWindowMetricBreadcrumbs = false;
    options.environment = configuration.environment.value;
    options.maxBreadcrumbs = 50;
    options.recordHttpBreadcrumbs = false;
    options.release = configuration.release;
    options.reportPackages = true;
    options.reportSilentFlutterErrors = false;
    options.reportViewHierarchyIdentifiers = false;
    options.sendDefaultPii = false;
    options.tracesSampleRate = null;
    options.replay
      ..onErrorSampleRate = 0
      ..sessionSampleRate = 0;
    options.addInAppInclude('kinflow_app');
  }

  static Future<void> _initializeSentry({
    required void Function() appRunner,
    required FlutterOptionsConfiguration optionsConfiguration,
  }) {
    return SentryFlutter.init(optionsConfiguration, appRunner: appRunner);
  }
}
