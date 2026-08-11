import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_app_build_reader.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_device_platform_reader.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_incident_recorder.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/diagnostic_incident_id_generator.dart';

void main() {
  test(
    'creates a report only when runtime and configured build match',
    () async {
      final _RecordingIncidentRecorder recorder = _RecordingIncidentRecorder();
      final ProviderDiagnosticReportRepository repository = _repository(
        recorder: recorder,
      );

      final DiagnosticReportResult result = await repository.create();

      expect(result, isA<DiagnosticReportSucceeded>());
      final DiagnosticReport report =
          (result as DiagnosticReportSucceeded).report;
      expect(report.appBuild.configuredVersion, '0.1.0-dev+1');
      expect(report.environment, DiagnosticEnvironment.dev);
      expect(report.devicePlatform, DiagnosticDevicePlatform.android);
      expect(report.generatedAt, DateTime.utc(2026, 8, 8, 2, 3, 4));
      expect(recorder.ids.single, report.incidentId.value);
    },
  );

  test(
    'fails closed on application ID or configured version mismatch',
    () async {
      for (final ProviderDiagnosticReportRepository repository
          in <ProviderDiagnosticReportRepository>[
            _repository(expectedApplicationId: 'me.newlines.kinflow'),
            _repository(expectedAppVersion: '0.1.0-dev+2'),
          ]) {
        final DiagnosticReportResult result = await repository.create();

        expect(result, isA<DiagnosticReportFailed>());
        expect(
          (result as DiagnosticReportFailed).failure.kind,
          DiagnosticReportFailureKind.invalidMetadata,
        );
      }
    },
  );

  test('rejects invalid mapped package or config metadata', () async {
    final List<ProviderDiagnosticReportRepository> repositories =
        <ProviderDiagnosticReportRepository>[
          _repository(reader: const _AppBuildReader(null)),
          _repository(contractVersion: 'not-a-date'),
        ];

    for (final ProviderDiagnosticReportRepository repository in repositories) {
      final DiagnosticReportResult result = await repository.create();
      expect(
        (result as DiagnosticReportFailed).failure.kind,
        DiagnosticReportFailureKind.invalidMetadata,
      );
    }
  });

  test('maps package provider failure without reflecting details', () async {
    final DiagnosticReportResult result = await _repository(
      reader: const _AppBuildReader.throwing(),
    ).create();

    expect(
      (result as DiagnosticReportFailed).failure.kind,
      DiagnosticReportFailureKind.unavailable,
    );
  });

  test('observability failure never blocks valid report generation', () async {
    final DiagnosticReportResult result = await _repository(
      recorder: _RecordingIncidentRecorder(throwOnRecord: true),
    ).create();

    expect(result, isA<DiagnosticReportSucceeded>());
  });

  test(
    'generator or platform failure maps to stable internal failure',
    () async {
      final DiagnosticReportResult generatorFailure = await _repository(
        generator: const _IncidentIdGenerator.throwing(),
      ).create();
      final DiagnosticReportResult platformFailure = await _repository(
        platformReader: const _PlatformReader.throwing(),
      ).create();

      for (final DiagnosticReportResult result in <DiagnosticReportResult>[
        generatorFailure,
        platformFailure,
      ]) {
        expect(
          (result as DiagnosticReportFailed).failure.kind,
          DiagnosticReportFailureKind.internal,
        );
      }
    },
  );
}

ProviderDiagnosticReportRepository _repository({
  String expectedApplicationId = 'me.newlines.kinflow.dev',
  String expectedAppVersion = '0.1.0-dev+1',
  String contractVersion = '2026-08-08',
  DiagnosticAppBuildReader? reader,
  DiagnosticDevicePlatformReader? platformReader,
  DiagnosticIncidentIdGenerator? generator,
  DiagnosticIncidentRecorder? recorder,
}) {
  return ProviderDiagnosticReportRepository(
    expectedApplicationId: expectedApplicationId,
    expectedAppVersion: expectedAppVersion,
    environment: DiagnosticEnvironment.dev,
    contractVersion: contractVersion,
    appBuildReader: reader ?? _AppBuildReader(_appBuild()),
    platformReader: platformReader ?? const _PlatformReader(),
    incidentIdGenerator: generator ?? const _IncidentIdGenerator(),
    incidentRecorder: recorder ?? _RecordingIncidentRecorder(),
    clock: () => DateTime.utc(2026, 8, 8, 2, 3, 4),
  );
}

DiagnosticAppBuild _appBuild() {
  return DiagnosticAppBuild.tryCreate(
    applicationId: 'me.newlines.kinflow.dev',
    version: '0.1.0-dev',
    buildNumber: '1',
  )!;
}

final class _AppBuildReader implements DiagnosticAppBuildReader {
  const _AppBuildReader(this.value) : throws = false;

  const _AppBuildReader.throwing() : value = null, throws = true;

  final DiagnosticAppBuild? value;
  final bool throws;

  @override
  Future<DiagnosticAppBuild?> read() async {
    if (throws) throw StateError('private package provider detail');
    return value;
  }
}

final class _PlatformReader implements DiagnosticDevicePlatformReader {
  const _PlatformReader() : throws = false;

  const _PlatformReader.throwing() : throws = true;

  final bool throws;

  @override
  DiagnosticDevicePlatform read() {
    if (throws) throw StateError('private platform detail');
    return DiagnosticDevicePlatform.android;
  }
}

final class _IncidentIdGenerator implements DiagnosticIncidentIdGenerator {
  const _IncidentIdGenerator() : throws = false;

  const _IncidentIdGenerator.throwing() : throws = true;

  final bool throws;

  @override
  DiagnosticIncidentId generate() {
    if (throws) throw StateError('private random provider detail');
    return DiagnosticIncidentId.tryParse(
      '123e4567-e89b-42d3-a456-426614174000',
    )!;
  }
}

final class _RecordingIncidentRecorder implements DiagnosticIncidentRecorder {
  _RecordingIncidentRecorder({this.throwOnRecord = false});

  final bool throwOnRecord;
  final List<String> ids = <String>[];

  @override
  void record(DiagnosticIncidentId incidentId) {
    if (throwOnRecord) throw StateError('private logger detail');
    ids.add(incidentId.value);
  }
}
