import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app_environment.dart';

typedef AppInitializer = Future<void> Function();

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw StateError('AppEnvironment override is required.');
});

final appInitializerProvider = Provider<AppInitializer>((ref) {
  return _initializeAppDependencies;
});

final appLocaleProvider = Provider<Locale?>((ref) => null);

Future<void> _initializeAppDependencies() async {}
