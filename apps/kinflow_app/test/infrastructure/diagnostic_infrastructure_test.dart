import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/providers/diagnostic_dependencies.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/infrastructure/clipboard/flutter_diagnostic_clipboard.dart';
import 'package:kinflow_app/infrastructure/observability/app_logger_diagnostic_incident_recorder.dart';
import 'package:kinflow_app/infrastructure/package_info/package_info_diagnostic_app_build_reader.dart';
import 'package:kinflow_app/infrastructure/platform/flutter_diagnostic_device_platform_reader.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test(
    'package adapter maps only package ID, version, and build number',
    () async {
      final PackageInfoDiagnosticAppBuildReader reader =
          PackageInfoDiagnosticAppBuildReader(
            loader: () async => PackageInfo(
              appName: 'private display name',
              packageName: 'me.newlines.kinflow.dev',
              version: '0.1.0-dev',
              buildNumber: '1',
              buildSignature: 'private-signing-hash',
              installerStore: 'private-installer',
              installTime: DateTime.utc(2026, 1, 1),
              updateTime: DateTime.utc(2026, 2, 1),
            ),
          );

      final DiagnosticAppBuild? build = await reader.read();

      expect(build?.applicationId, 'me.newlines.kinflow.dev');
      expect(build?.version, '0.1.0-dev');
      expect(build?.buildNumber, '1');
      expect(build?.configuredVersion, '0.1.0-dev+1');
    },
  );

  test('package adapter rejects invalid external metadata', () async {
    final PackageInfoDiagnosticAppBuildReader reader =
        PackageInfoDiagnosticAppBuildReader(
          loader: () async => PackageInfo(
            appName: 'KinFlow',
            packageName: 'me.newlines.kinflow.dev',
            version: 'latest',
            buildNumber: '1',
          ),
        );

    expect(await reader.read(), isNull);
  });

  test('platform adapter exposes only coarse enum categories', () {
    expect(
      FlutterDiagnosticDevicePlatformReader(
        isWeb: true,
        targetPlatform: TargetPlatform.android,
      ).read(),
      DiagnosticDevicePlatform.web,
    );
    for (final (TargetPlatform target, DiagnosticDevicePlatform expected)
        in <(TargetPlatform, DiagnosticDevicePlatform)>[
          (TargetPlatform.android, DiagnosticDevicePlatform.android),
          (TargetPlatform.iOS, DiagnosticDevicePlatform.ios),
          (TargetPlatform.macOS, DiagnosticDevicePlatform.macos),
          (TargetPlatform.windows, DiagnosticDevicePlatform.windows),
          (TargetPlatform.linux, DiagnosticDevicePlatform.linux),
          (TargetPlatform.fuchsia, DiagnosticDevicePlatform.fuchsia),
        ]) {
      expect(
        FlutterDiagnosticDevicePlatformReader(
          isWeb: false,
          targetPlatform: target,
        ).read(),
        expected,
      );
    }
  });

  test(
    'clipboard adapter writes exact text and never reads clipboard',
    () async {
      final List<String> writes = <String>[];
      final FlutterDiagnosticClipboard clipboard = FlutterDiagnosticClipboard(
        writer: (String text) async => writes.add(text),
      );

      expect(await clipboard.write('{"safe":true}'), isTrue);
      expect(writes, <String>['{"safe":true}']);
    },
  );

  test('clipboard adapter maps provider exceptions to false', () async {
    final FlutterDiagnosticClipboard clipboard = FlutterDiagnosticClipboard(
      writer: (String text) async {
        throw StateError('private clipboard provider detail');
      },
    );

    expect(await clipboard.write('safe payload'), isFalse);
  });

  test('incident recorder logs only stable event and request ID', () {
    final _RecordingLogger logger = _RecordingLogger();
    final AppLoggerDiagnosticIncidentRecorder recorder =
        AppLoggerDiagnosticIncidentRecorder(logger);
    final DiagnosticIncidentId id = DiagnosticIncidentId.tryParse(
      '123e4567-e89b-42d3-a456-426614174000',
    )!;

    recorder.record(id);

    expect(logger.events, <String>['application.diagnostics.generated']);
    expect(logger.attributes.single, <String, Object?>{
      'capability': 'diagnostics',
      'operation': 'generate',
      'result': 'succeeded',
      'request_id': id.value,
    });
  });

  test('app composition provides live and fail-closed dependencies', () {
    final DiagnosticDependencies live = createDiagnosticDependencies(
      publicConfigurationFixture(),
      const NoopAppLogger(),
    );
    final DiagnosticDependencies unavailable =
        createUnavailableDiagnosticDependencies();

    expect(live.repository, isA<ProviderDiagnosticReportRepository>());
    expect(live.clipboard, isA<FlutterDiagnosticClipboard>());
    expect(
      unavailable.repository,
      isA<UnavailableDiagnosticReportRepository>(),
    );
    expect(unavailable.clipboard, isA<UnavailableDiagnosticClipboard>());
  });
}

final class _RecordingLogger implements AppLogger {
  final List<String> events = <String>[];
  final List<Map<String, Object?>> attributes = <Map<String, Object?>>[];

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
  }) {}

  @override
  void info(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    events.add(event);
    this.attributes.add(Map<String, Object?>.of(attributes));
  }

  @override
  void warning(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {}
}
