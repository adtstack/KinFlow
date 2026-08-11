import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';

final class UnavailableDataExportDownloadLauncher
    implements DataExportDownloadLauncher {
  const UnavailableDataExportDownloadLauncher();

  @override
  Future<bool> launch(Uri uri) async => false;
}
