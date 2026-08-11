import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';

abstract interface class DiagnosticIncidentRecorder {
  void record(DiagnosticIncidentId incidentId);
}
