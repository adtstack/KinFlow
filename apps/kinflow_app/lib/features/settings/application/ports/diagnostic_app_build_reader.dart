import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';

abstract interface class DiagnosticAppBuildReader {
  Future<DiagnosticAppBuild?> read();
}
