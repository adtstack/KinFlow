import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';

final class UnavailableDiagnosticReportRepository
    implements DiagnosticReportRepository {
  const UnavailableDiagnosticReportRepository();

  @override
  Future<DiagnosticReportResult> create() async {
    return const DiagnosticReportFailed(
      DiagnosticReportFailure(DiagnosticReportFailureKind.unavailable),
    );
  }
}
