import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_incident_recorder.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';

final class AppLoggerDiagnosticIncidentRecorder
    implements DiagnosticIncidentRecorder {
  const AppLoggerDiagnosticIncidentRecorder(this._logger);

  final AppLogger _logger;

  @override
  void record(DiagnosticIncidentId incidentId) {
    _logger.info(
      'application.diagnostics.generated',
      attributes: <String, Object?>{
        'capability': 'diagnostics',
        'operation': 'generate',
        'result': 'succeeded',
        'request_id': incidentId.value,
      },
    );
  }
}
