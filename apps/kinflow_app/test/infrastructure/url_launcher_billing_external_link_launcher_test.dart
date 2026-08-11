import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_billing_external_link_launcher.dart';

void main() {
  group('billingExternalUriFor', () {
    test('maps only fixed Store management destinations', () {
      expect(
        _uri(BillingExternalLink.googlePlaySubscriptions),
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      );
      expect(
        _uri(BillingExternalLink.appleAppStoreSubscriptions),
        Uri.parse('https://apps.apple.com/account/subscriptions'),
      );
    });

    test('rebuilds policy paths without inherited query or fragment', () {
      final Uri publicSite = Uri.parse(
        'https://www.kinflow.example/old?campaign=secret#fragment',
      );

      expect(
        billingExternalUriFor(
          BillingExternalLink.terms,
          publicSiteUri: publicSite,
          supportUri: Uri.parse('https://support.kinflow.example/help'),
        ),
        Uri.parse('https://www.kinflow.example/terms'),
      );
      expect(
        billingExternalUriFor(
          BillingExternalLink.privacy,
          publicSiteUri: publicSite,
          supportUri: Uri.parse('https://support.kinflow.example/help'),
        ),
        Uri.parse('https://www.kinflow.example/privacy'),
      );
    });

    test('fails closed for untrusted configured destinations', () {
      expect(
        billingExternalUriFor(
          BillingExternalLink.support,
          publicSiteUri: Uri.parse('https://www.kinflow.example'),
          supportUri: Uri.parse('http://support.kinflow.example/help'),
        ),
        isNull,
      );
      expect(
        billingExternalUriFor(
          BillingExternalLink.support,
          publicSiteUri: Uri.parse('https://www.kinflow.example'),
          supportUri: Uri.parse(
            'https://support.kinflow.example/help?customer=hidden',
          ),
        ),
        isNull,
      );
    });
  });

  test(
    'launcher reports opened, unavailable, and failed without leaking URI',
    () async {
      final List<Uri> opened = <Uri>[];
      final UrlLauncherBillingExternalLinkLauncher successful =
          UrlLauncherBillingExternalLinkLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://support.kinflow.example/help'),
            opener: (Uri uri) async {
              opened.add(uri);
              return true;
            },
          );
      expect(
        await successful.launch(BillingExternalLink.support),
        BillingExternalLinkLaunchResult.opened,
      );
      expect(opened, <Uri>[Uri.parse('https://support.kinflow.example/help')]);

      final UrlLauncherBillingExternalLinkLauncher unavailable =
          UrlLauncherBillingExternalLinkLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://support.kinflow.example/help'),
            opener: (Uri _) async => false,
          );
      expect(
        await unavailable.launch(BillingExternalLink.terms),
        BillingExternalLinkLaunchResult.unavailable,
      );

      final UrlLauncherBillingExternalLinkLauncher failed =
          UrlLauncherBillingExternalLinkLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://support.kinflow.example/help'),
            opener: (Uri _) async => throw StateError('launcher unavailable'),
          );
      expect(
        await failed.launch(BillingExternalLink.privacy),
        BillingExternalLinkLaunchResult.failed,
      );
    },
  );
}

Uri? _uri(BillingExternalLink link) {
  return billingExternalUriFor(
    link,
    publicSiteUri: Uri.parse('https://www.kinflow.example'),
    supportUri: Uri.parse('https://support.kinflow.example/help'),
  );
}
