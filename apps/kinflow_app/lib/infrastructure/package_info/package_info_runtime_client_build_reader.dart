import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_client_build_reader.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef RuntimePackageInfoLoader = Future<PackageInfo> Function();

final class PackageInfoRuntimeClientBuildReader
    implements RuntimeClientBuildReader {
  const PackageInfoRuntimeClientBuildReader({
    this.loader = loadRuntimePackageInfo,
  });

  final RuntimePackageInfoLoader loader;

  @override
  Future<RuntimeClientBuild?> read() async {
    final PackageInfo record = await loader();
    return RuntimeClientBuild.tryCreate(
      applicationId: record.packageName,
      version: record.version,
      buildNumber: record.buildNumber,
    );
  }
}

Future<PackageInfo> loadRuntimePackageInfo() => PackageInfo.fromPlatform();
