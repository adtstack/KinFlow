import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/data/services/secure_diagnostic_incident_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';
import 'package:kinflow_app/infrastructure/clipboard/flutter_diagnostic_clipboard.dart';
import 'package:kinflow_app/infrastructure/observability/app_logger_diagnostic_incident_recorder.dart';
import 'package:kinflow_app/infrastructure/package_info/package_info_diagnostic_app_build_reader.dart';
import 'package:kinflow_app/infrastructure/platform/flutter_diagnostic_device_platform_reader.dart';

final class DiagnosticDependencies {
  const DiagnosticDependencies({
    required this.repository,
    required this.clipboard,
  });

  final DiagnosticReportRepository repository;
  final DiagnosticClipboard clipboard;
}

DiagnosticDependencies createDiagnosticDependencies(
  AppPublicConfiguration configuration,
  AppLogger logger,
) {
  return DiagnosticDependencies(
    repository: ProviderDiagnosticReportRepository(
      expectedApplicationId: configuration.applicationId,
      expectedAppVersion: configuration.appVersion,
      environment: switch (configuration.environment) {
        AppEnvironment.dev => DiagnosticEnvironment.dev,
        AppEnvironment.prod => DiagnosticEnvironment.prod,
      },
      contractVersion: configuration.contractVersion,
      appBuildReader: const PackageInfoDiagnosticAppBuildReader(),
      platformReader: FlutterDiagnosticDevicePlatformReader(),
      incidentIdGenerator: SecureDiagnosticIncidentIdGenerator(),
      incidentRecorder: AppLoggerDiagnosticIncidentRecorder(logger),
    ),
    clipboard: const FlutterDiagnosticClipboard(),
  );
}

DiagnosticDependencies createUnavailableDiagnosticDependencies() {
  return const DiagnosticDependencies(
    repository: UnavailableDiagnosticReportRepository(),
    clipboard: UnavailableDiagnosticClipboard(),
  );
}
