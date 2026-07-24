import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_telemetry_sanitizer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final class SentryPrivacyFilter {
  const SentryPrivacyFilter({
    required this.configuration,
    this.sanitizer = const AppTelemetrySanitizer(),
  });

  final AppPublicConfiguration configuration;
  final AppTelemetrySanitizer sanitizer;

  SentryEvent sanitizeEvent(SentryEvent event, Hint hint) {
    event
      ..breadcrumbs = event.breadcrumbs
          ?.map((Breadcrumb breadcrumb) => sanitizeBreadcrumb(breadcrumb, hint))
          .whereType<Breadcrumb>()
          .toList(growable: false)
      ..contexts = Contexts()
      ..culprit = null
      ..environment = configuration.environment.value
      // ignore: deprecated_member_use
      ..extra = null
      ..fingerprint = null
      ..message = event.message == null
          ? null
          : SentryMessage(
              sanitizer.sanitizeStableMessage(event.message?.formatted),
            )
      ..modules = null
      ..release = configuration.release
      ..request = null
      ..serverName = null
      ..tags = <String, String>{
        'contract_version': configuration.contractVersion,
        'platform': 'android',
      }
      ..threads = null
      ..transaction = null
      ..user = null;

    event.exceptions = event.exceptions
        ?.map(_sanitizeException)
        .toList(growable: false);
    return event;
  }

  Breadcrumb? sanitizeBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null || breadcrumb.category != 'kinflow.structured') {
      return null;
    }
    return Breadcrumb(
      category: 'kinflow.structured',
      data: sanitizer.sanitizeAttributes(
        Map<String, Object?>.from(breadcrumb.data ?? const <String, Object?>{}),
      ),
      level: breadcrumb.level,
      message: sanitizer.sanitizeStableMessage(breadcrumb.message),
      timestamp: breadcrumb.timestamp.toUtc(),
      type: 'default',
    );
  }

  SentryException _sanitizeException(SentryException exception) {
    return SentryException(
      mechanism: null,
      module: sanitizer.sanitizeCodeIdentifier(exception.module),
      stackTrace: _sanitizeStackTrace(exception.stackTrace),
      threadId: exception.threadId,
      throwable: null,
      type: sanitizer.sanitizeCodeIdentifier(exception.type),
      value: AppTelemetrySanitizer.redacted,
    );
  }

  SentryStackTrace? _sanitizeStackTrace(SentryStackTrace? stackTrace) {
    if (stackTrace == null) {
      return null;
    }
    return SentryStackTrace(
      frames: stackTrace.frames
          .map(_sanitizeStackFrame)
          .toList(growable: false),
      lang: stackTrace.lang,
      snapshot: stackTrace.snapshot,
    );
  }

  SentryStackFrame _sanitizeStackFrame(SentryStackFrame frame) {
    return SentryStackFrame(
      colNo: frame.colNo,
      fileName: sanitizer.sanitizeCodeIdentifier(frame.fileName),
      function: sanitizer.sanitizeCodeIdentifier(frame.function),
      inApp: frame.inApp,
      lineNo: frame.lineNo,
      module: sanitizer.sanitizeCodeIdentifier(frame.module),
      native: frame.native,
      package: sanitizer.sanitizeCodeIdentifier(frame.package),
      platform: sanitizer.sanitizeCodeIdentifier(frame.platform),
      stackStart: frame.stackStart,
    );
  }
}
