import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android share channel validates and opens a text chooser only', () {
    final String source = File(
      'android/app/src/main/kotlin/me/newlines/kinflow/MainActivity.kt',
    ).readAsStringSync();
    final String gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    for (final String requiredSource in <String>[
      'me.newlines.kinflow/invite_sharing',
      'openInviteShareSheet',
      'Intent.ACTION_SEND',
      'type = "text/plain"',
      'Intent.EXTRA_TEXT',
      'Intent.createChooser',
      'R.string.kinflow_auth_redirect_host',
      'uri.scheme != "https"',
      'pathSegments.size != 2',
      'pathSegments[0] != "invite"',
      'value == canonical',
      '^[A-Za-z0-9_-]{20,512}',
    ]) {
      expect(source, contains(requiredSource), reason: requiredSource);
    }
    expect(
      gradle,
      contains(
        'resValue("string", "kinflow_auth_redirect_host", '
        'kinflowAuthRedirectHost)',
      ),
    );
    expect(source, isNot(contains('Intent.EXTRA_EMAIL')));
    expect(source, isNot(contains('Intent.EXTRA_STREAM')));
  });
}
