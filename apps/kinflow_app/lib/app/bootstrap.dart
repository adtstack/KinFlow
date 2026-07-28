import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/config/dart_define_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:kinflow_app/infrastructure/observability/app_logging_composition.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';

Future<void> bootstrap(
  AppEnvironment environment, {
  AppInitializer? initializer,
  Map<String, String>? configurationValues,
  AppObservabilityRunner observabilityRunner =
      const SentryObservabilityRunner(),
}) async {
  final AppPublicConfiguration configuration;
  try {
    configuration = AppPublicConfigurationLoader(
      expectedEnvironment: environment,
    ).load(configurationValues ?? DartDefinePublicConfiguration.values);
  } on AppConfigurationException catch (error) {
    WidgetsFlutterBinding.ensureInitialized();
    _runKinFlowApp(
      environment: environment,
      initializer: () async => throw error,
      logger: const NoopAppLogger(),
    );
    return;
  }

  final AppLogger logger = AppLoggingComposition.create(configuration);
  logger.info(
    'application.bootstrap.started',
    attributes: const <String, Object?>{
      'operation': 'bootstrap',
      'result': 'started',
    },
  );

  await observabilityRunner.run(
    appRunner: () {
      logger.info(
        'application.bootstrap.succeeded',
        attributes: const <String, Object?>{
          'operation': 'bootstrap',
          'result': 'succeeded',
        },
      );
      _runKinFlowApp(
        configuration: configuration,
        environment: environment,
        initializer: initializer,
        logger: logger,
      );
    },
    configuration: configuration,
    logger: logger,
  );
}

void _runKinFlowApp({
  required AppEnvironment environment,
  required AppLogger logger,
  AppPublicConfiguration? configuration,
  AppInitializer? initializer,
}) {
  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        if (configuration != null)
          appPublicConfigurationProvider.overrideWithValue(configuration),
        appLoggerProvider.overrideWithValue(logger),
        authSessionRepositoryProvider.overrideWithValue(
          createAuthSessionRepository(),
        ),
        authSignInLauncherProvider.overrideWithValue(
          createAuthSignInLauncher(),
        ),
        sensitiveLocalStatePurgerProvider.overrideWithValue(
          createSensitiveLocalStatePurger(),
        ),
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
