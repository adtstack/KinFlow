import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';

void bootstrap(AppEnvironment environment, {AppInitializer? initializer}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        if (initializer != null)
          appInitializerProvider.overrideWithValue(initializer),
      ],
      child: const KinFlowApp(),
    ),
  );
}
