import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';

sealed class DiagnosticReportState {
  const DiagnosticReportState();
}

final class DiagnosticReportInitial extends DiagnosticReportState {
  const DiagnosticReportInitial();
}

final class DiagnosticReportLoading extends DiagnosticReportState {
  const DiagnosticReportLoading();
}

final class DiagnosticReportLoadFailed extends DiagnosticReportState {
  const DiagnosticReportLoadFailed(this.failure);

  final DiagnosticReportFailure failure;
}

enum DiagnosticReportNotice { copied, copyFailed, refreshFailed }

final class DiagnosticReportReady extends DiagnosticReportState {
  const DiagnosticReportReady({
    required this.report,
    this.isRefreshing = false,
    this.isCopying = false,
    this.notice,
  });

  final DiagnosticReport report;
  final bool isRefreshing;
  final bool isCopying;
  final DiagnosticReportNotice? notice;

  bool get busy => isRefreshing || isCopying;
}
