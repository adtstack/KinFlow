import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/trusted_external_uri_policy.dart';
import 'package:url_launcher/url_launcher.dart';

typedef BillingExternalUriOpener = Future<bool> Function(Uri uri);

final class UrlLauncherBillingExternalLinkLauncher
    implements BillingExternalLinkLauncher {
  const UrlLauncherBillingExternalLinkLauncher({
    required this.publicSiteUri,
    required this.supportUri,
    this.opener = openBillingExternalUri,
  });

  final Uri publicSiteUri;
  final Uri supportUri;
  final BillingExternalUriOpener opener;

  @override
  Future<BillingExternalLinkLaunchResult> launch(
    BillingExternalLink link,
  ) async {
    final Uri? uri = billingExternalUriFor(
      link,
      publicSiteUri: publicSiteUri,
      supportUri: supportUri,
    );
    if (uri == null) return BillingExternalLinkLaunchResult.unavailable;
    try {
      return await opener(uri)
          ? BillingExternalLinkLaunchResult.opened
          : BillingExternalLinkLaunchResult.unavailable;
    } on Object {
      return BillingExternalLinkLaunchResult.failed;
    }
  }
}

Future<bool> openBillingExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri? billingExternalUriFor(
  BillingExternalLink link, {
  required Uri publicSiteUri,
  required Uri supportUri,
}) {
  return switch (link) {
    BillingExternalLink.googlePlaySubscriptions => trustedExternalHttpsUri(
      Uri.https('play.google.com', '/store/account/subscriptions'),
    ),
    BillingExternalLink.appleAppStoreSubscriptions => trustedExternalHttpsUri(
      Uri.https('apps.apple.com', '/account/subscriptions'),
    ),
    BillingExternalLink.terms => trustedPublicDocumentUri(
      publicSiteUri,
      '/terms',
    ),
    BillingExternalLink.privacy => trustedPublicDocumentUri(
      publicSiteUri,
      '/privacy',
    ),
    BillingExternalLink.support => trustedExternalHttpsUri(supportUri),
  };
}
