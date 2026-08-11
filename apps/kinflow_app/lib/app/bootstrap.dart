import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/config/dart_define_public_configuration.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/presentation/focus_highlight_policy.dart';
import 'package:kinflow_app/app/presentation/widgets/auth_runtime_bootstrap_gate.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/analytics_dependencies.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/providers/calendar_import_dependencies.dart';
import 'package:kinflow_app/app/providers/diagnostic_dependencies.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/app/providers/invite_sharing_dependencies.dart';
import 'package:kinflow_app/app/router/platform_url_strategy.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:kinflow_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_selection_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/providers/platform_capability_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/account_deletion_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/data_export_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/diagnostic_report_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/legal_support_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';
import 'package:kinflow_app/features/today/presentation/providers/today_providers.dart';
import 'package:kinflow_app/infrastructure/firebase/notification_push_composition.dart';
import 'package:kinflow_app/infrastructure/observability/app_logging_composition.dart';
import 'package:kinflow_app/infrastructure/observability/sentry_observability.dart';

typedef NotificationPushBackgroundPreparer =
    void Function(AppPublicConfiguration configuration);

Future<void> bootstrap(
  AppEnvironment environment, {
  AppInitializer? initializer,
  Map<String, String>? configurationValues,
  AppObservabilityRunner observabilityRunner =
      const SentryObservabilityRunner(),
  AuthDependenciesFactory authDependenciesFactory = createAuthDependencies,
  NotificationPushBackgroundPreparer notificationPushBackgroundPreparer =
      prepareNotificationPushBackgroundHandler,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  configurePlatformFocusHighlightStrategy();
  configurePlatformUrlStrategy();
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

  // Firebase requires the top-level background message callback to be assigned
  // before runApp. The registration is inert when public Android options are
  // absent and the later production composition remains the fail-closed gate.
  notificationPushBackgroundPreparer(configuration);

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
  final DiagnosticDependencies diagnosticDependencies = configuration == null
      ? createUnavailableDiagnosticDependencies()
      : createDiagnosticDependencies(configuration, logger);
  final AnalyticsDependencies analyticsDependencies = configuration == null
      ? createUnavailableAnalyticsDependencies()
      : createAnalyticsDependencies(configuration);
  final InviteSharingDependencies inviteSharingDependencies =
      configuration == null
      ? createUnavailableInviteSharingDependencies()
      : createInviteSharingDependencies();
  final calendarImportFileGateway = configuration == null
      ? createUnavailableCalendarImportFileGateway()
      : createCalendarImportFileGateway();
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
            analyticsPreferenceRepositoryProvider.overrideWithValue(
              analyticsDependencies.preferenceRepository,
            ),
            analyticsSinkProvider.overrideWithValue(analyticsDependencies.sink),
            analyticsDispatchMetadataProvider.overrideWithValue(
              analyticsDependencies.metadata,
            ),
            authSessionRepositoryProvider.overrideWithValue(
              dependencies.sessionRepository,
            ),
            authSignInLauncherProvider.overrideWithValue(
              dependencies.signInLauncher,
            ),
            authEmailOtpServiceProvider.overrideWithValue(
              dependencies.emailOtpService,
            ),
            recentAuthenticationServiceProvider.overrideWithValue(
              dependencies.recentAuthenticationService,
            ),
            sensitiveLocalStatePurgerProvider.overrideWithValue(
              dependencies.localStatePurger,
            ),
            activeHouseholdSnapshotWriterProvider.overrideWithValue(
              dependencies.activeHouseholdSnapshotWriter,
            ),
            activeHouseholdTransitionLocalStateProvider.overrideWithValue(
              dependencies.activeHouseholdTransitionLocalState,
            ),
            householdRepositoryProvider.overrideWithValue(
              dependencies.householdRepository,
            ),
            householdSelectionRepositoryProvider.overrideWithValue(
              dependencies.householdSelectionRepository,
            ),
            householdMemberRepositoryProvider.overrideWithValue(
              dependencies.householdMemberRepository,
            ),
            householdCommandIdGeneratorProvider.overrideWithValue(
              dependencies.householdCommandIdGenerator,
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
            householdInviteShareGatewayProvider.overrideWithValue(
              inviteSharingDependencies.shareGateway,
            ),
            householdInviteClipboardProvider.overrideWithValue(
              inviteSharingDependencies.clipboard,
            ),
            choreRepositoryProvider.overrideWithValue(
              dependencies.choreRepository,
            ),
            choreCommandIdGeneratorProvider.overrideWithValue(
              dependencies.choreCommandIdGenerator,
            ),
            guidedChoreSetupResumeStoreProvider.overrideWithValue(
              dependencies.guidedChoreSetupResumeStore,
            ),
            choreCompletionOutboxProvider.overrideWithValue(
              dependencies.choreCompletionOutbox,
            ),
            choreSyncRepositoryProvider.overrideWithValue(
              dependencies.choreSyncRepository,
            ),
            calendarRepositoryProvider.overrideWithValue(
              dependencies.calendarRepository,
            ),
            calendarImportFileGatewayProvider.overrideWithValue(
              calendarImportFileGateway,
            ),
            todayCalendarSnapshotCacheProvider.overrideWithValue(
              dependencies.todayCalendarSnapshotCache,
            ),
            calendarCommandIdGeneratorProvider.overrideWithValue(
              dependencies.calendarCommandIdGenerator,
            ),
            calendarTimeResolverProvider.overrideWithValue(
              dependencies.calendarTimeResolver,
            ),
            calendarSyncRepositoryProvider.overrideWithValue(
              dependencies.calendarSyncRepository,
            ),
            billingPortProvider.overrideWithValue(dependencies.billingPort),
            billingExternalLinkLauncherProvider.overrideWithValue(
              dependencies.billingExternalLinkLauncher,
            ),
            billingAssignmentRepositoryProvider.overrideWithValue(
              dependencies.billingAssignmentRepository,
            ),
            billingAssignmentCommandIdGeneratorProvider.overrideWithValue(
              dependencies.billingAssignmentCommandIdGenerator,
            ),
            entitlementRepositoryProvider.overrideWithValue(
              dependencies.entitlementRepository,
            ),
            householdFeatureGateRepositoryProvider.overrideWithValue(
              dependencies.householdFeatureGateRepository,
            ),
            accountDeletionRepositoryProvider.overrideWithValue(
              dependencies.accountDeletionRepository,
            ),
            accountDeletionCommandIdGeneratorProvider.overrideWithValue(
              dependencies.accountDeletionCommandIdGenerator,
            ),
            dataExportRepositoryProvider.overrideWithValue(
              dependencies.dataExportRepository,
            ),
            dataExportCommandIdGeneratorProvider.overrideWithValue(
              dependencies.dataExportCommandIdGenerator,
            ),
            dataExportDownloadLauncherProvider.overrideWithValue(
              dependencies.dataExportDownloadLauncher,
            ),
            householdPrivacyRepositoryProvider.overrideWithValue(
              dependencies.householdPrivacyRepository,
            ),
            profilePreferencesRepositoryProvider.overrideWithValue(
              dependencies.profilePreferencesRepository,
            ),
            legalSupportResourceLauncherProvider.overrideWithValue(
              dependencies.legalSupportResourceLauncher,
            ),
            diagnosticReportRepositoryProvider.overrideWithValue(
              diagnosticDependencies.repository,
            ),
            diagnosticClipboardProvider.overrideWithValue(
              diagnosticDependencies.clipboard,
            ),
            notificationRepositoryProvider.overrideWithValue(
              dependencies.notificationRepository,
            ),
            notificationSyncRepositoryProvider.overrideWithValue(
              dependencies.notificationSyncRepository,
            ),
            notificationEndpointRepositoryProvider.overrideWithValue(
              dependencies.notificationEndpointRepository,
            ),
            notificationEndpointLifecycleProvider.overrideWithValue(
              dependencies.notificationEndpointLifecycle,
            ),
            notificationPushCoordinatorProvider.overrideWithValue(
              dependencies.notificationPushCoordinator,
            ),
            platformCapabilityRegistryProvider.overrideWithValue(
              dependencies.platformCapabilityRegistry,
            ),
            appRuntimePolicyRepositoryProvider.overrideWithValue(
              dependencies.runtimePolicyRepository,
            ),
            runtimePolicyExternalLinkLauncherProvider.overrideWithValue(
              dependencies.runtimePolicyExternalLinkLauncher,
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
