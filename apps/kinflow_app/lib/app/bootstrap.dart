import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';

void bootstrap(AppEnvironment environment, {AppInitializer? initializer}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        foundationRepositoryProvider.overrideWithValue(
          createFoundationRepository(),
        ),
        if (initializer != null)
          appInitializerProvider.overrideWithValue(initializer),
      ],
      child: const KinFlowApp(),
    ),
  );
}
