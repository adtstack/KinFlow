import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application-owned modal routes use the shared focus contract', () {
    const String sharedRoute =
        'lib/app/presentation/widgets/app_modal_route.dart';
    final RegExp rawModalCall = RegExp(
      r'\bshow(?:Dialog|ModalBottomSheet)\s*(?:<[^>]+>)?\s*\(',
    );
    final List<String> violations = <String>[];

    for (final File file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File value) => value.path.endsWith('.dart'))) {
      final String normalizedPath = file.path.replaceAll('\\', '/');
      if (normalizedPath == sharedRoute) {
        continue;
      }
      if (rawModalCall.hasMatch(file.readAsStringSync())) {
        violations.add(normalizedPath);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('shared modal routes request, contain, and restore focus', () {
    final String source = File(
      'lib/app/presentation/widgets/app_modal_route.dart',
    ).readAsStringSync();

    expect(source, contains('requestFocus: true'));
    expect('TraversalEdgeBehavior.closedLoop'.allMatches(source), hasLength(2));
    expect(source, contains('_restoreFocusAfterRoute(source)'));
    expect(source, contains('source.requestFocus()'));
  });
}
