import 'dart:convert';
import 'dart:io';

import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';

void main() {
  const List<(String, AppEnvironment)> files = <(String, AppEnvironment)>[
    ('config/dev.example.json', AppEnvironment.dev),
    ('config/prod.example.json', AppEnvironment.prod),
  ];

  for (final (String path, AppEnvironment environment) in files) {
    final Object? decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$path must contain a JSON object.');
    }
    final Map<String, String> values = decoded.map((String key, Object? value) {
      if (value is! String) {
        throw FormatException('$path:$key must be a string.');
      }
      return MapEntry<String, String>(key, value);
    });
    if (values.keys
            .toSet()
            .difference(AppPublicConfigurationKeys.allowed)
            .isNotEmpty ||
        AppPublicConfigurationKeys.allowed
            .difference(values.keys.toSet())
            .isNotEmpty) {
      throw FormatException(
        '$path must contain the exact public key allowlist.',
      );
    }
    AppPublicConfigurationLoader(
      allowPlaceholders: true,
      expectedEnvironment: environment,
    ).load(values);
  }

  stdout.writeln('Public configuration examples are valid and allowlisted.');
}
