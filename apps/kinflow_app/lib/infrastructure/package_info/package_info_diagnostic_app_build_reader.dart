import 'package:kinflow_app/features/settings/application/ports/diagnostic_app_build_reader.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef DiagnosticPackageInfoLoader = Future<PackageInfo> Function();

final class PackageInfoDiagnosticAppBuildReader
    implements DiagnosticAppBuildReader {
  const PackageInfoDiagnosticAppBuildReader({
    this.loader = loadDiagnosticPackageInfo,
  });

  final DiagnosticPackageInfoLoader loader;

  @override
  Future<DiagnosticAppBuild?> read() async {
    final PackageInfo record = await loader();
    return DiagnosticAppBuild.tryCreate(
      applicationId: record.packageName,
      version: record.version,
      buildNumber: record.buildNumber,
    );
  }
}

Future<PackageInfo> loadDiagnosticPackageInfo() {
  return PackageInfo.fromPlatform();
}
