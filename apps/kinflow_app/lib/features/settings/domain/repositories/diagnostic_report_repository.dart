import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';

sealed class DiagnosticReportResult {
  const DiagnosticReportResult();
}

final class DiagnosticReportSucceeded extends DiagnosticReportResult {
  const DiagnosticReportSucceeded(this.report);

  final DiagnosticReport report;
}

final class DiagnosticReportFailed extends DiagnosticReportResult {
  const DiagnosticReportFailed(this.failure);

  final DiagnosticReportFailure failure;
}

abstract interface class DiagnosticReportRepository {
  Future<DiagnosticReportResult> create();
}
