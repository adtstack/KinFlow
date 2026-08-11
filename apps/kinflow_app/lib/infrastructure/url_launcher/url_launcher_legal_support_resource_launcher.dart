import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/trusted_external_uri_policy.dart';
import 'package:url_launcher/url_launcher.dart';

typedef LegalSupportExternalUriOpener = Future<bool> Function(Uri uri);

final class UrlLauncherLegalSupportResourceLauncher
    implements LegalSupportResourceLauncher {
  const UrlLauncherLegalSupportResourceLauncher({
    required this.publicSiteUri,
    required this.supportUri,
    this.opener = openLegalSupportExternalUri,
  });

  final Uri publicSiteUri;
  final Uri supportUri;
  final LegalSupportExternalUriOpener opener;

  @override
  Future<LegalSupportResourceLaunchResult> launch(
    LegalSupportResource resource,
  ) async {
    final Uri? uri = legalSupportExternalUriFor(
      resource,
      publicSiteUri: publicSiteUri,
      supportUri: supportUri,
    );
    if (uri == null) return LegalSupportResourceLaunchResult.unavailable;
    try {
      return await opener(uri)
          ? LegalSupportResourceLaunchResult.opened
          : LegalSupportResourceLaunchResult.unavailable;
    } on Object {
      return LegalSupportResourceLaunchResult.failed;
    }
  }
}

Future<bool> openLegalSupportExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri? legalSupportExternalUriFor(
  LegalSupportResource resource, {
  required Uri publicSiteUri,
  required Uri supportUri,
}) {
  return switch (resource) {
    LegalSupportResource.terms => trustedPublicDocumentUri(
      publicSiteUri,
      '/terms',
    ),
    LegalSupportResource.privacy => trustedPublicDocumentUri(
      publicSiteUri,
      '/privacy',
    ),
    LegalSupportResource.support => trustedExternalHttpsUri(supportUri),
  };
}
