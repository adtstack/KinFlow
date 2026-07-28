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
