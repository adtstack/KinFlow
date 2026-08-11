import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_policy_external_link_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

typedef RuntimePolicyUrlLauncher =
    Future<bool> Function(Uri uri, {LaunchMode mode});

final class UrlLauncherRuntimePolicyExternalLinkLauncher
    implements RuntimePolicyExternalLinkLauncher {
  factory UrlLauncherRuntimePolicyExternalLinkLauncher({
    required String applicationId,
    RuntimePolicyUrlLauncher launcher = launchUrl,
  }) {
    return UrlLauncherRuntimePolicyExternalLinkLauncher._(
      Uri.https('play.google.com', '/store/apps/details', <String, String>{
        'id': applicationId,
      }),
      launcher,
    );
  }

  const UrlLauncherRuntimePolicyExternalLinkLauncher._(
    this._updateUri,
    this._launcher,
  );

  final Uri _updateUri;
  final RuntimePolicyUrlLauncher _launcher;

  Uri get updateUri => _updateUri;

  @override
  Future<bool> launchUpdate() async {
    try {
      return await _launcher(_updateUri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
