import 'dart:async';

import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';

DiagnosticReport diagnosticReportFixture({
  String applicationId = 'me.newlines.kinflow.dev',
  String version = '0.1.0-dev',
  String buildNumber = '1',
  DiagnosticEnvironment environment = DiagnosticEnvironment.dev,
  String contractVersion = '2026-08-08',
  DiagnosticDevicePlatform devicePlatform = DiagnosticDevicePlatform.android,
  String incidentId = '123e4567-e89b-42d3-a456-426614174000',
  DateTime? generatedAt,
}) {
  return DiagnosticReport.tryCreate(
    appBuild: DiagnosticAppBuild.tryCreate(
      applicationId: applicationId,
      version: version,
      buildNumber: buildNumber,
    )!,
    environment: environment,
    contractVersion: contractVersion,
    devicePlatform: devicePlatform,
    incidentId: DiagnosticIncidentId.tryParse(incidentId)!,
    generatedAt: generatedAt ?? DateTime.utc(2026, 8, 8, 2, 3, 4),
  )!;
}

final class FakeDiagnosticReportRepository
    implements DiagnosticReportRepository {
  FakeDiagnosticReportRepository({
    List<DiagnosticReportResult>? results,
    this.pending,
  }) : _results =
           results ??
           <DiagnosticReportResult>[
             DiagnosticReportSucceeded(diagnosticReportFixture()),
           ];

  final List<DiagnosticReportResult> _results;
  final Completer<DiagnosticReportResult>? pending;
  int createCalls = 0;

  @override
  Future<DiagnosticReportResult> create() async {
    createCalls += 1;
    final Completer<DiagnosticReportResult>? pending = this.pending;
    if (pending != null) return pending.future;
    if (_results.isEmpty) {
      return DiagnosticReportSucceeded(diagnosticReportFixture());
    }
    return _results.removeAt(0);
  }
}

final class FakeDiagnosticClipboard implements DiagnosticClipboard {
  FakeDiagnosticClipboard({List<bool>? results, this.pending})
    : _results = results ?? <bool>[true];

  final List<bool> _results;
  final Completer<bool>? pending;
  final List<String> writes = <String>[];

  @override
  Future<bool> write(String text) async {
    writes.add(text);
    final Completer<bool>? pending = this.pending;
    if (pending != null) return pending.future;
    return _results.isEmpty ? true : _results.removeAt(0);
  }
}
