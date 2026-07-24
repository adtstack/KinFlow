import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sentry SDK imports stay inside the observability infrastructure', () {
    final List<String> violations = <String>[];
    for (final File file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))) {
      final String source = file.readAsStringSync();
      if (source.contains("package:sentry_flutter/")) {
        final String normalized = file.path.replaceAll('\\', '/');
        if (!normalized.startsWith('lib/infrastructure/observability/')) {
          violations.add(normalized);
        }
      }
    }

    expect(violations, isEmpty);
  });
}
