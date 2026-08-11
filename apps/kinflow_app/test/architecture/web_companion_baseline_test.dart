import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web Companion uses path URLs without a PWA install surface', () async {
    final String index = await File('web/index.html').readAsString();
    final String bootstrap = await File(
      'lib/app/bootstrap.dart',
    ).readAsString();
    final String strategy = await File(
      'lib/app/router/platform_url_strategy_web.dart',
    ).readAsString();
    final String metadata = await File('.metadata').readAsString();

    expect(index, contains(r'<base href="$FLUTTER_BASE_HREF">'));
    expect(index, contains('flutter_bootstrap.js'));
    expect(index, isNot(contains('manifest.json')));
    expect(index, isNot(contains('apple-mobile-web-app-capable')));
    expect(File('web/manifest.json').existsSync(), isFalse);
    expect(bootstrap, contains('configurePlatformUrlStrategy();'));
    expect(strategy, contains('usePathUrlStrategy();'));
    expect(metadata, contains('- platform: web'));
  });

  test('Web release gate disables persistent Flutter API caching', () async {
    final String source = await File(
      '../../scripts/ci/web-build.sh',
    ).readAsString();

    expect(source, contains('--pwa-strategy none'));
    expect(source, contains('flutter_service_worker.js'));
    expect(source, contains('service_worker=disabled'));
    expect(source, contains('persistent_api_cache=disabled'));
    expect(source, contains('manifest.json'));
  });

  test(
    'Web invite sharing selects a browser-only explicit gesture adapter',
    () async {
      final String factory = await File(
        'lib/infrastructure/share/platform_household_invite_share_gateway.dart',
      ).readAsString();
      final String browserClient = await File(
        'lib/infrastructure/share/browser_web_share_client.dart',
      ).readAsString();
      final String gateway = await File(
        'lib/infrastructure/share/web_household_invite_share_gateway.dart',
      ).readAsString();

      expect(factory, contains('dart.library.js_interop'));
      expect(
        factory,
        contains('platform_household_invite_share_gateway_web.dart'),
      );
      expect(browserClient, contains("_browserNavigator.has('share')"));
      expect(browserClient, contains('navigator.share(data)'));
      expect(gateway, contains('HouseholdInviteShareResult.unavailable'));
      expect(gateway, isNot(contains('Clipboard')));
      expect(browserClient, isNot(contains('localStorage')));
    },
  );
}
