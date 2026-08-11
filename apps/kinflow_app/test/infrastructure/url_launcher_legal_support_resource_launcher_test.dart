import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_legal_support_resource_launcher.dart';

void main() {
  group('legal support URI policy', () {
    test(
      'maps only the fixed public document paths and configured support',
      () {
        final Uri publicSite = Uri.parse(
          'https://www.kinflow.example/old/path?token=hidden#fragment',
        );
        final Uri support = Uri.parse('https://help.kinflow.example/contact');

        expect(
          _uri(
            LegalSupportResource.terms,
            publicSiteUri: publicSite,
            supportUri: support,
          ),
          Uri.parse('https://www.kinflow.example/terms'),
        );
        expect(
          _uri(
            LegalSupportResource.privacy,
            publicSiteUri: publicSite,
            supportUri: support,
          ),
          Uri.parse('https://www.kinflow.example/privacy'),
        );
        expect(
          _uri(
            LegalSupportResource.support,
            publicSiteUri: publicSite,
            supportUri: support,
          ),
          support,
        );
      },
    );

    test('rejects insecure or contextual external destinations', () {
      final Uri validPublic = Uri.parse('https://www.kinflow.example');
      final Uri validSupport = Uri.parse('https://help.kinflow.example');

      for (final Uri publicSite in <Uri>[
        Uri.parse('http://www.kinflow.example'),
        Uri.parse('https://user@www.kinflow.example'),
        Uri(),
      ]) {
        expect(
          _uri(
            LegalSupportResource.terms,
            publicSiteUri: publicSite,
            supportUri: validSupport,
          ),
          isNull,
        );
      }

      for (final Uri support in <Uri>[
        Uri.parse('http://help.kinflow.example/contact'),
        Uri.parse('https://user@help.kinflow.example/contact'),
        Uri.parse('https://help.kinflow.example/contact?user=hidden'),
        Uri.parse('https://help.kinflow.example/contact#case'),
      ]) {
        expect(
          _uri(
            LegalSupportResource.support,
            publicSiteUri: validPublic,
            supportUri: support,
          ),
          isNull,
        );
      }
    });
  });

  test(
    'launcher maps success, unavailable, and exceptions without leaking',
    () async {
      final List<Uri> opened = <Uri>[];
      final UrlLauncherLegalSupportResourceLauncher successful =
          UrlLauncherLegalSupportResourceLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://help.kinflow.example/contact'),
            opener: (Uri uri) async {
              opened.add(uri);
              return true;
            },
          );
      expect(
        await successful.launch(LegalSupportResource.privacy),
        LegalSupportResourceLaunchResult.opened,
      );
      expect(opened, <Uri>[Uri.parse('https://www.kinflow.example/privacy')]);

      final UrlLauncherLegalSupportResourceLauncher unavailable =
          UrlLauncherLegalSupportResourceLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://help.kinflow.example/contact'),
            opener: (Uri uri) async => false,
          );
      expect(
        await unavailable.launch(LegalSupportResource.support),
        LegalSupportResourceLaunchResult.unavailable,
      );

      final UrlLauncherLegalSupportResourceLauncher failed =
          UrlLauncherLegalSupportResourceLauncher(
            publicSiteUri: Uri.parse('https://www.kinflow.example'),
            supportUri: Uri.parse('https://help.kinflow.example/contact'),
            opener: (Uri uri) async =>
                throw StateError('private browser detail'),
          );
      expect(
        await failed.launch(LegalSupportResource.terms),
        LegalSupportResourceLaunchResult.failed,
      );
    },
  );
}

Uri? _uri(
  LegalSupportResource resource, {
  required Uri publicSiteUri,
  required Uri supportUri,
}) {
  return legalSupportExternalUriFor(
    resource,
    publicSiteUri: publicSiteUri,
    supportUri: supportUri,
  );
}
