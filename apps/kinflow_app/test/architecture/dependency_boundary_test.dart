import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('materialized architecture contract contains accepted policies', () {
    final File contract = File('../../contracts/architecture-rules.yaml');

    expect(contract.existsSync(), isTrue);
    final String contents = contract.readAsStringSync();
    expect(contents, contains('version: 1'));
    expect(contents, contains('dto_must_not_escape_data_layer: true'));
    expect(contents, contains('generated_files_committed: true'));
  });

  test('feature imports follow the accepted dependency direction', () {
    final Directory features = Directory('lib/features');
    expect(features.existsSync(), isTrue);

    final List<File> dartFiles =
        features
            .listSync(recursive: true)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((File left, File right) => left.path.compareTo(right.path));

    final List<String> violations = <String>[];
    final Set<_Layer> seenLayers = <_Layer>{};
    for (final File file in dartFiles) {
      final _Layer? layer = _layerForPath(file.path);
      if (layer != null) {
        seenLayers.add(layer);
      }
      violations.addAll(
        _violationsFor(path: file.path, source: file.readAsStringSync()),
      );
    }

    expect(seenLayers, containsAll(_Layer.values));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('boundary detector rejects Flutter imports from domain', () {
    final List<String> violations = _violationsFor(
      path: 'lib/features/sample/domain/entities/sample.dart',
      source: "import 'package:flutter/material.dart';",
    );

    expect(violations, isNotEmpty);
  });

  test('boundary detector keeps Google SDK imports in infrastructure', () {
    final List<String> violations = _violationsFor(
      path: 'lib/features/auth/data/services/google_auth.dart',
      source: "import 'package:google_sign_in/google_sign_in.dart';",
    );

    expect(violations, isNotEmpty);
  });

  test('RevenueCat SDK imports stay inside its infrastructure driver', () {
    final Directory lib = Directory('lib');
    final List<String> violations = <String>[];
    for (final File file
        in lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((File value) => value.path.endsWith('.dart'))) {
      if (!file.readAsStringSync().contains(
        "package:purchases_flutter/purchases_flutter.dart",
      )) {
        continue;
      }
      final String normalized = file.path.replaceAll('\\', '/');
      if (normalized !=
          'lib/infrastructure/revenuecat/purchases_flutter_revenuecat_sdk.dart') {
        violations.add(normalized);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('package info SDK imports stay inside validated app-build adapters', () {
    final Directory lib = Directory('lib');
    final List<String> violations = <String>[];
    const Set<String> allowed = <String>{
      'lib/infrastructure/package_info/package_info_diagnostic_app_build_reader.dart',
      'lib/infrastructure/package_info/package_info_runtime_client_build_reader.dart',
    };
    for (final File file
        in lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((File value) => value.path.endsWith('.dart'))) {
      if (!file.readAsStringSync().contains(
        "package:package_info_plus/package_info_plus.dart",
      )) {
        continue;
      }
      final String normalized = file.path.replaceAll('\\', '/');
      if (!allowed.contains(normalized)) {
        violations.add(normalized);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('mutation providers use only their exact runtime capability guard', () {
    const Map<String, ({String feature, int guardCount})>
    contracts = <String, ({String feature, int guardCount})>{
      'lib/features/household/presentation/providers/household_providers.dart':
          (feature: 'household', guardCount: 8),
      'lib/features/chores/presentation/providers/chore_providers.dart': (
        feature: 'chores',
        guardCount: 19,
      ),
      'lib/features/calendar/presentation/providers/calendar_providers.dart': (
        feature: 'calendar',
        guardCount: 13,
      ),
      'lib/features/notifications/presentation/providers/notification_providers.dart':
          (feature: 'notifications', guardCount: 6),
      'lib/features/settings/presentation/providers/profile_preferences_providers.dart':
          (feature: 'profile', guardCount: 1),
      'lib/features/billing/presentation/providers/billing_providers.dart': (
        feature: 'billing',
        guardCount: 3,
      ),
    };
    final RegExp featureGuard = RegExp(
      r'appRuntimePolicyFeatureMutationsBlockedProvider\(\s*AppRuntimeFeature\.(\w+)',
    );

    for (final MapEntry<String, ({String feature, int guardCount})> contract
        in contracts.entries) {
      final String source = File(contract.key).readAsStringSync();
      final List<String> features = featureGuard
          .allMatches(source)
          .map((RegExpMatch match) => match.group(1)!)
          .toList(growable: false);

      expect(
        features,
        List<String>.filled(contract.value.guardCount, contract.value.feature),
        reason:
            '${contract.key} must guard every mutation as '
            '${contract.value.feature}',
      );
      expect(
        source,
        isNot(contains('appRuntimePolicyMutationsBlockedProvider')),
        reason: '${contract.key} must not use the broad global guard',
      );
    }
  });

  test('broad runtime mutation guard stays inside runtime policy feature', () {
    final List<String> violations = <String>[];
    for (final File file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File value) => value.path.endsWith('.dart'))) {
      final String normalized = file.path.replaceAll('\\', '/');
      if (normalized.startsWith('lib/features/runtime_policy/')) {
        continue;
      }
      if (file.readAsStringSync().contains(
        'appRuntimePolicyMutationsBlockedProvider',
      )) {
        violations.add(normalized);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('privacy and export providers stay outside runtime mutation advisory', () {
    for (final String path in <String>[
      'lib/features/settings/presentation/providers/account_deletion_providers.dart',
      'lib/features/settings/presentation/providers/data_export_providers.dart',
      'lib/features/settings/presentation/providers/household_privacy_providers.dart',
    ]) {
      final String source = File(path).readAsStringSync();
      expect(
        source,
        allOf(
          isNot(contains('appRuntimePolicyMutationsBlockedProvider')),
          isNot(contains('appRuntimePolicyFeatureMutationsBlockedProvider')),
        ),
        reason: '$path must preserve privacy and export mutations',
      );
    }
  });
}

enum _Layer { domain, application, data, presentation }

List<String> _violationsFor({required String path, required String source}) {
  final _Layer? sourceLayer = _layerForPath(path);
  if (sourceLayer == null) {
    return <String>['$path is not inside a known feature layer'];
  }

  final Set<_Layer> allowedFeatureLayers = switch (sourceLayer) {
    _Layer.domain => <_Layer>{_Layer.domain},
    _Layer.application => <_Layer>{_Layer.application, _Layer.domain},
    _Layer.data => <_Layer>{_Layer.data, _Layer.application, _Layer.domain},
    _Layer.presentation => <_Layer>{
      _Layer.presentation,
      _Layer.application,
      _Layer.domain,
    },
  };
  final List<String> violations = <String>[];

  for (final RegExpMatch match in _importPattern.allMatches(source)) {
    final String uri = match.group(1) ?? '';
    final _Layer? importedLayer = _layerForPackageUri(uri);

    if (importedLayer != null &&
        !allowedFeatureLayers.contains(importedLayer)) {
      violations.add(
        '$path: ${sourceLayer.name} must not import ${importedLayer.name}: $uri',
      );
    }

    if (uri.contains('/data/dto/') && sourceLayer != _Layer.data) {
      violations.add('$path: DTO escaped the data layer: $uri');
    }

    if (_isForbiddenExternalImport(sourceLayer, uri)) {
      violations.add('$path: forbidden ${sourceLayer.name} import: $uri');
    }
  }

  return violations;
}

_Layer? _layerForPath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  for (final _Layer layer in _Layer.values) {
    if (normalized.contains('/${layer.name}/')) {
      return layer;
    }
  }
  return null;
}

_Layer? _layerForPackageUri(String uri) {
  final RegExpMatch? match = _featureLayerPattern.firstMatch(uri);
  final String? layerName = match?.group(1);
  if (layerName == null) {
    return null;
  }

  return _Layer.values.where((_Layer layer) => layer.name == layerName).first;
}

bool _isForbiddenExternalImport(_Layer layer, String uri) {
  const List<String> providerSdkPrefixes = <String>[
    'package:google_sign_in/',
    'package:supabase_flutter/',
    'package:purchases_flutter/',
    'package:firebase_core/',
    'package:firebase_messaging/',
  ];
  if (providerSdkPrefixes.any(uri.startsWith)) {
    return true;
  }

  if (layer == _Layer.domain || layer == _Layer.application) {
    return uri.startsWith('package:flutter/') ||
        uri.startsWith('package:flutter_riverpod/') ||
        uri.startsWith('package:riverpod/') ||
        uri == 'dart:html';
  }

  return false;
}

final RegExp _importPattern = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);
final RegExp _featureLayerPattern = RegExp(
  r'^package:kinflow_app/features/[^/]+/(domain|application|data|presentation)/',
);
