import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/config/dart_define_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/presentation/widgets/auth_runtime_bootstrap_gate.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/infrastructure/observability/app_logging_composition.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';

Future<void> bootstrap(
  AppEnvironment environment, {
  AppInitializer? initializer,
  Map<String, String>? configurationValues,
  AppObservabilityRunner observabilityRunner =
      const SentryObservabilityRunner(),
  AuthDependenciesFactory authDependenciesFactory = createAuthDependencies,
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
      authDependenciesFactory: authDependenciesFactory,
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
        authDependenciesFactory: authDependenciesFactory,
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
  required AuthDependenciesFactory authDependenciesFactory,
}) {
  final AuthDependenciesLoader authDependenciesLoader = configuration == null
      ? () async => createUnavailableAuthDependencies()
      : () => authDependenciesFactory(configuration);
  runApp(
    AuthRuntimeBootstrapGate(
      environment: environment,
      loader: authDependenciesLoader,
      logger: logger,
      builder: (BuildContext context, AuthDependencies dependencies) {
        return ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(environment),
            if (configuration != null)
              appPublicConfigurationProvider.overrideWithValue(configuration),
            appLoggerProvider.overrideWithValue(logger),
            authSessionRepositoryProvider.overrideWithValue(
              dependencies.sessionRepository,
            ),
            authSignInLauncherProvider.overrideWithValue(
              dependencies.signInLauncher,
            ),
            sensitiveLocalStatePurgerProvider.overrideWithValue(
              dependencies.localStatePurger,
            ),
            householdRepositoryProvider.overrideWithValue(
              dependencies.householdRepository,
            ),
            householdCreationIdGeneratorProvider.overrideWithValue(
              dependencies.householdCreationIdGenerator,
            ),
            inviteRepositoryProvider.overrideWithValue(
              dependencies.inviteRepository,
            ),
            inviteCommandIdGeneratorProvider.overrideWithValue(
              dependencies.inviteCommandIdGenerator,
            ),
            pendingInviteStoreProvider.overrideWithValue(
              dependencies.pendingInviteStore,
            ),
            foundationRepositoryProvider.overrideWithValue(
              createFoundationRepository(),
            ),
            if (initializer != null)
              appInitializerProvider.overrideWithValue(initializer),
          ],
          child: const KinFlowApp(),
        );
      },
    ),
  );
}
