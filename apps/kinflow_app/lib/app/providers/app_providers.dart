import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';

typedef AppInitializer = Future<void> Function();

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw StateError('AppEnvironment override is required.');
});

final appPublicConfigurationProvider = Provider<AppPublicConfiguration>((ref) {
  throw StateError('AppPublicConfiguration override is required.');
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  return const NoopAppLogger();
});

final appInitializerProvider = Provider<AppInitializer>((ref) {
  return _initializeAppDependencies;
});

final appLocaleProvider = Provider<Locale?>((ref) => null);

Future<void> _initializeAppDependencies() async {}
