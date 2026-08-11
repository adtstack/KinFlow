import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/package_info/package_info_runtime_client_build_reader.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_app_runtime_policy_data_source.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_runtime_policy_external_link_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('Supabase adapter accepts exactly one string-keyed record', () {
    final Map<String, Object?> row = <String, Object?>{
      'environment': 'dev',
      'policy_version': 1,
    };

    expect(appRuntimePolicyRecordFromPayload(<Object?>[row]), row);
    expect(appRuntimePolicyRecordFromPayload(const <Object?>[]), isNull);
    expect(appRuntimePolicyRecordFromPayload(<Object?>[row, row]), isNull);
    expect(appRuntimePolicyRecordFromPayload(row), isNull);
    expect(
      appRuntimePolicyRecordFromPayload(<Object?>[
        <Object?, Object?>{1: 'not-a-string-key'},
      ]),
      isNull,
    );
  });

  test(
    'Supabase adapter preserves only a list of string-keyed feature rows',
    () {
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[
        <String, Object?>{'feature': 'chores', 'policy_version': 1},
        <String, Object?>{'feature': 'billing', 'policy_version': 2},
      ];

      expect(appRuntimePolicyRecordsFromPayload(rows), rows);
      expect(appRuntimePolicyRecordsFromPayload(const <Object?>[]), isEmpty);
      expect(appRuntimePolicyRecordsFromPayload(rows.first), isNull);
      expect(
        appRuntimePolicyRecordsFromPayload(<Object?>[
          <Object?, Object?>{1: 'not-a-string-key'},
        ]),
        isNull,
      );
      expect(
        appRuntimePolicyRecordsFromPayload(<Object?>[...rows, 'not-a-row']),
        isNull,
      );
    },
  );

  test(
    'package adapter exposes only validated installed build metadata',
    () async {
      final PackageInfoRuntimeClientBuildReader reader =
          PackageInfoRuntimeClientBuildReader(
            loader: () async => PackageInfo(
              appName: 'private display name',
              packageName: 'me.newlines.kinflow.dev',
              version: '0.1.0-dev',
              buildNumber: '10',
              buildSignature: 'private-signature',
              installerStore: 'private-store',
            ),
          );

      final build = await reader.read();

      expect(build?.applicationId, 'me.newlines.kinflow.dev');
      expect(build?.configuredVersion, '0.1.0-dev+10');

      final PackageInfoRuntimeClientBuildReader invalid =
          PackageInfoRuntimeClientBuildReader(
            loader: () async => PackageInfo(
              appName: 'KinFlow',
              packageName: 'me.newlines.kinflow.dev',
              version: 'latest',
              buildNumber: '10',
            ),
          );
      expect(await invalid.read(), isNull);
    },
  );

  test('update launcher opens only the fixed Play application URL', () async {
    Uri? opened;
    LaunchMode? launchMode;
    final UrlLauncherRuntimePolicyExternalLinkLauncher launcher =
        UrlLauncherRuntimePolicyExternalLinkLauncher(
          applicationId: 'me.newlines.kinflow',
          launcher:
              (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
                opened = uri;
                launchMode = mode;
                return true;
              },
        );

    expect(await launcher.launchUpdate(), isTrue);
    expect(
      opened,
      Uri.parse(
        'https://play.google.com/store/apps/details?id=me.newlines.kinflow',
      ),
    );
    expect(launchMode, LaunchMode.externalApplication);
    expect(launcher.updateUri, opened);
  });

  test(
    'update launcher contains unavailable and thrown provider results',
    () async {
      final UrlLauncherRuntimePolicyExternalLinkLauncher unavailable =
          UrlLauncherRuntimePolicyExternalLinkLauncher(
            applicationId: 'me.newlines.kinflow',
            launcher:
                (
                  Uri uri, {
                  LaunchMode mode = LaunchMode.platformDefault,
                }) async {
                  return false;
                },
          );
      final UrlLauncherRuntimePolicyExternalLinkLauncher failed =
          UrlLauncherRuntimePolicyExternalLinkLauncher(
            applicationId: 'me.newlines.kinflow',
            launcher:
                (
                  Uri uri, {
                  LaunchMode mode = LaunchMode.platformDefault,
                }) async {
                  throw StateError('private browser response');
                },
          );

      expect(await unavailable.launchUpdate(), isFalse);
      expect(await failed.launchUpdate(), isFalse);
    },
  );
}
