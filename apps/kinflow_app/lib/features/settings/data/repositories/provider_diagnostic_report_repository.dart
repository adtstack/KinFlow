import 'package:kinflow_app/features/settings/application/ports/diagnostic_app_build_reader.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_device_platform_reader.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_incident_recorder.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/diagnostic_incident_id_generator.dart';

typedef DiagnosticClock = DateTime Function();

final class ProviderDiagnosticReportRepository
    implements DiagnosticReportRepository {
  factory ProviderDiagnosticReportRepository({
    required String expectedApplicationId,
    required String expectedAppVersion,
    required DiagnosticEnvironment environment,
    required String contractVersion,
    required DiagnosticAppBuildReader appBuildReader,
    required DiagnosticDevicePlatformReader platformReader,
    required DiagnosticIncidentIdGenerator incidentIdGenerator,
    required DiagnosticIncidentRecorder incidentRecorder,
    DiagnosticClock clock = DateTime.now,
  }) {
    return ProviderDiagnosticReportRepository._(
      expectedApplicationId,
      expectedAppVersion,
      environment,
      contractVersion,
      appBuildReader,
      platformReader,
      incidentIdGenerator,
      incidentRecorder,
      clock,
    );
  }

  const ProviderDiagnosticReportRepository._(
    this._expectedApplicationId,
    this._expectedAppVersion,
    this._environment,
    this._contractVersion,
    this._appBuildReader,
    this._platformReader,
    this._incidentIdGenerator,
    this._incidentRecorder,
    this._clock,
  );

  final String _expectedApplicationId;
  final String _expectedAppVersion;
  final DiagnosticEnvironment _environment;
  final String _contractVersion;
  final DiagnosticAppBuildReader _appBuildReader;
  final DiagnosticDevicePlatformReader _platformReader;
  final DiagnosticIncidentIdGenerator _incidentIdGenerator;
  final DiagnosticIncidentRecorder _incidentRecorder;
  final DiagnosticClock _clock;

  @override
  Future<DiagnosticReportResult> create() async {
    final DiagnosticAppBuild? appBuild;
    try {
      appBuild = await _appBuildReader.read();
    } on Object {
      return const DiagnosticReportFailed(
        DiagnosticReportFailure(DiagnosticReportFailureKind.unavailable),
      );
    }
    if (appBuild == null ||
        appBuild.applicationId != _expectedApplicationId ||
        appBuild.configuredVersion != _expectedAppVersion) {
      return const DiagnosticReportFailed(
        DiagnosticReportFailure(DiagnosticReportFailureKind.invalidMetadata),
      );
    }

    final DiagnosticDevicePlatform platform;
    final DiagnosticIncidentId incidentId;
    final DateTime generatedAt;
    try {
      platform = _platformReader.read();
      incidentId = _incidentIdGenerator.generate();
      generatedAt = _clock().toUtc();
    } on Object {
      return const DiagnosticReportFailed(
        DiagnosticReportFailure(DiagnosticReportFailureKind.internal),
      );
    }
    final DiagnosticReport? report = DiagnosticReport.tryCreate(
      appBuild: appBuild,
      environment: _environment,
      contractVersion: _contractVersion,
      devicePlatform: platform,
      incidentId: incidentId,
      generatedAt: generatedAt,
    );
    if (report == null) {
      return const DiagnosticReportFailed(
        DiagnosticReportFailure(DiagnosticReportFailureKind.invalidMetadata),
      );
    }

    try {
      _incidentRecorder.record(incidentId);
    } on Object {
      // Diagnostic generation remains available when observability is down.
    }
    return DiagnosticReportSucceeded(report);
  }
}
