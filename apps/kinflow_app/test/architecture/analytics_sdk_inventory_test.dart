import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';

void main() {
  test('every direct runtime dependency has an exact inventory entry', () {
    final List<String> pubspecDependencies = _runtimeDependencies(
      File('pubspec.yaml').readAsLinesSync(),
    );
    final List<String> inventory = AnalyticsSdkInventory
        .directRuntimeDependencies
        .map((entry) => entry.packageName)
        .toList(growable: false);

    expect(inventory, pubspecDependencies);
    expect(inventory.toSet().length, inventory.length);
  });

  test('unreviewed analytics advertising and tracking SDKs are absent', () {
    final Set<String> dependencies = _runtimeDependencies(
      File('pubspec.yaml').readAsLinesSync(),
    ).toSet();
    expect(
      dependencies.intersection(
        AnalyticsSdkInventory.forbiddenUnreviewedPackages,
      ),
      isEmpty,
    );
  });

  test('behavioral analytics stays separate from operational Sentry', () {
    final List<AnalyticsRuntimeDependencyInventoryEntry> operational =
        AnalyticsSdkInventory.directRuntimeDependencies
            .where(
              (entry) =>
                  entry.purpose ==
                  AnalyticsRuntimeDependencyPurpose.operationalErrors,
            )
            .toList(growable: false);
    expect(operational.map((entry) => entry.packageName), <String>[
      'sentry_flutter',
    ]);

    final String composition = File(
      'lib/app/providers/analytics_dependencies.dart',
    ).readAsStringSync();
    expect(composition, contains('UnavailableAnalyticsSink'));
    expect(composition, isNot(contains('Sentry')));
    expect(composition, isNot(contains('sentry_flutter')));
  });
}

List<String> _runtimeDependencies(List<String> lines) {
  final List<String> dependencies = <String>[];
  bool inDependencies = false;
  final RegExp entryPattern = RegExp(r'^  ([a-z][a-z0-9_]*):');
  for (final String line in lines) {
    if (line == 'dependencies:') {
      inDependencies = true;
      continue;
    }
    if (line == 'dev_dependencies:') {
      break;
    }
    if (!inDependencies) continue;
    final RegExpMatch? match = entryPattern.firstMatch(line);
    if (match != null) dependencies.add(match.group(1)!);
  }
  return dependencies;
}
