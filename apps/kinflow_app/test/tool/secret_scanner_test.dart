import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';

import '../../tool/security/secret_scanner.dart';

void main() {
  test(
    'detects high-confidence credentials without returning their values',
    () {
      final String githubFixture = <String>[
        'ghp',
        List<String>.filled(40, 'A').join(),
      ].join('_');
      final String privateKeyFixture = <String>[
        '-----BEGIN',
        'PRIVATE KEY-----',
      ].join(' ');
      final String source = <String>[
        'token=$githubFixture',
        privateKeyFixture,
      ].join('\n');

      final findings = const SecretScanner().scanText(
        path: 'fixture.txt',
        text: source,
      );

      expect(findings.map((finding) => finding.rule), <String>[
        'github-token',
        'private-key',
      ]);
      expect(
        findings.every((finding) => finding.path == 'fixture.txt'),
        isTrue,
      );
      expect(findings.toString(), isNot(contains(githubFixture)));
    },
  );

  test(
    'allows placeholders and env indirection but catches assigned secrets',
    () {
      final String key = <String>['SENTRY', 'AUTH', 'TOKEN'].join('_');
      final String assigned = List<String>.filled(24, 'x').join();

      expect(
        const SecretScanner().scanText(
          path: 'safe.env',
          text: '$key=\n$key=env(SENTRY_TOKEN)\n$key=replace-with-token',
        ),
        isEmpty,
      );
      expect(
        const SecretScanner().scanText(
          path: 'unsafe.env',
          text: '$key=$assigned',
        ),
        hasLength(1),
      );
    },
  );

  test('detects assignments for every server-only config key', () {
    final String assigned = List<String>.filled(24, 'x').join();
    final String source = AppPublicConfigurationKeys.serverOnly
        .map((String key) => '$key=$assigned')
        .join('\n');

    final findings = const SecretScanner().scanText(
      path: 'server-only.env',
      text: source,
    );

    expect(findings, hasLength(AppPublicConfigurationKeys.serverOnly.length));
    expect(findings.map((finding) => finding.rule).toSet(), <String>{
      'server-secret-assignment',
    });
  });
}
