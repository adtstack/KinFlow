import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

final class UrlLauncherDataExportDownloadLauncher
    implements DataExportDownloadLauncher {
  const UrlLauncherDataExportDownloadLauncher();

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
