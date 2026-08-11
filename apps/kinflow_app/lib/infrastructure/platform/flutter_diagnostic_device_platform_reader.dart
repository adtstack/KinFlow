import 'package:flutter/foundation.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_device_platform_reader.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';

final class FlutterDiagnosticDevicePlatformReader
    implements DiagnosticDevicePlatformReader {
  FlutterDiagnosticDevicePlatformReader({
    bool? isWeb,
    TargetPlatform? targetPlatform,
  }) : _isWeb = isWeb ?? kIsWeb,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform;

  final bool _isWeb;
  final TargetPlatform _targetPlatform;

  @override
  DiagnosticDevicePlatform read() {
    if (_isWeb) return DiagnosticDevicePlatform.web;
    return switch (_targetPlatform) {
      TargetPlatform.android => DiagnosticDevicePlatform.android,
      TargetPlatform.iOS => DiagnosticDevicePlatform.ios,
      TargetPlatform.macOS => DiagnosticDevicePlatform.macos,
      TargetPlatform.windows => DiagnosticDevicePlatform.windows,
      TargetPlatform.linux => DiagnosticDevicePlatform.linux,
      TargetPlatform.fuchsia => DiagnosticDevicePlatform.fuchsia,
    };
  }
}
