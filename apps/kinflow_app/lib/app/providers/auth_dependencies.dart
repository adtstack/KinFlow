import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/repositories/unavailable_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/application/unavailable_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_recent_authentication_service.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_port.dart';
import 'package:kinflow_app/features/billing/application/unavailable_entitlement_repository.dart';
import 'package:kinflow_app/features/billing/application/unavailable_household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_entitlement_repository.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/data/services/secure_billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/data/repositories/provider_calendar_repository.dart';
import 'package:kinflow_app/features/calendar/data/repositories/provider_calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/data/repositories/unavailable_calendar_repository.dart';
import 'package:kinflow_app/features/calendar/data/services/secure_calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_repository.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/data/repositories/unavailable_chore_repository.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/data/services/secure_guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/data/services/secure_chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/data/services/secure_chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_member_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_selection_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_invite_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_household_member_repository.dart';
import 'package:kinflow_app/features/household/application/unavailable_household_selection_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_invite_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_household_repository.dart';
import 'package:kinflow_app/features/household/data/services/secure_household_command_id_generator.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/data/services/secure_household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/data/services/secure_invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_repository.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_sync_repository.dart';
import 'package:kinflow_app/features/notifications/application/unavailable_notification_repository.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/application/unavailable_notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/data/services/secure_notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/data/services/secure_notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/offline/data/services/secure_read_cache.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';
import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_client_build_reader.dart';
import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/runtime_policy/application/unavailable_app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/application/unavailable_runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/runtime_policy/data/repositories/provider_app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/unavailable_account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/data/services/secure_account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_data_export_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/unavailable_data_export_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/unavailable_household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/application/unavailable_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/data/services/secure_data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/data/services/unavailable_data_export_download_launcher.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/application/unavailable_legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';
import 'package:kinflow_app/infrastructure/cache/cached_chore_data_source.dart';
import 'package:kinflow_app/infrastructure/cache/cached_household_data_source.dart';
import 'package:kinflow_app/infrastructure/cache/read_cache_today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/infrastructure/cache/today_cache_invalidating_calendar_repository.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/firebase/notification_push_composition.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_state_purge_participant.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_recent_authentication_service.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_auth_sign_in_data_source.dart';
import 'package:kinflow_app/infrastructure/package_info/package_info_runtime_client_build_reader.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_billing_composition.dart';
import 'package:kinflow_app/infrastructure/revenuecat/revenuecat_sdk.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_session_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_email_otp_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_account_deletion_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_app_runtime_policy_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_data_export_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_privacy_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_profile_preferences_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_calendar_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_calendar_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_member_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_selection_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_invite_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_entitlement_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_feature_gate_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_billing_assignment_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_endpoint_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_sync_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_read_cache_scope_resolver.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_data_export_download_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_billing_external_link_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_legal_support_resource_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_runtime_policy_external_link_launcher.dart';

typedef AuthDependenciesFactory =
    Future<AuthDependencies> Function(AppPublicConfiguration configuration);

final class AuthDependencies {
  const AuthDependencies({
    required this.sessionRepository,
    required this.signInLauncher,
    required this.emailOtpService,
    required this.recentAuthenticationService,
    required this.localStatePurger,
    required this.activeHouseholdSnapshotWriter,
    required this.activeHouseholdTransitionLocalState,
    required this.householdRepository,
    required this.householdSelectionRepository,
    required this.householdMemberRepository,
    required this.householdCommandIdGenerator,
    required this.householdCreationIdGenerator,
    required this.inviteRepository,
    required this.inviteCommandIdGenerator,
    required this.pendingInviteStore,
    required this.choreRepository,
    required this.choreCommandIdGenerator,
    required this.guidedChoreSetupResumeStore,
    required this.choreCompletionOutbox,
    required this.calendarRepository,
    required this.todayCalendarSnapshotCache,
    required this.calendarCommandIdGenerator,
    required this.calendarTimeResolver,
    required this.billingPort,
    required this.billingExternalLinkLauncher,
    required this.billingAssignmentRepository,
    required this.billingAssignmentCommandIdGenerator,
    required this.entitlementRepository,
    required this.householdFeatureGateRepository,
    required this.accountDeletionRepository,
    required this.accountDeletionCommandIdGenerator,
    required this.dataExportRepository,
    required this.dataExportCommandIdGenerator,
    required this.dataExportDownloadLauncher,
    required this.householdPrivacyRepository,
    required this.profilePreferencesRepository,
    required this.legalSupportResourceLauncher,
    required this.notificationRepository,
    required this.notificationEndpointRepository,
    required this.notificationEndpointLifecycle,
    required this.notificationPushCoordinator,
    required this.platformCapabilityRegistry,
    required this.runtimePolicyRepository,
    required this.runtimePolicyExternalLinkLauncher,
    this.calendarSyncRepository,
    this.choreSyncRepository,
    this.notificationSyncRepository,
  });

  final AuthSessionRepository sessionRepository;
  final AuthSignInLauncher signInLauncher;
  final AuthEmailOtpService emailOtpService;
  final RecentAuthenticationService recentAuthenticationService;
  final SensitiveLocalStatePurger localStatePurger;
  final ActiveHouseholdSnapshotWriter activeHouseholdSnapshotWriter;
  final ActiveHouseholdTransitionLocalState activeHouseholdTransitionLocalState;
  final HouseholdRepository householdRepository;
  final HouseholdSelectionRepository householdSelectionRepository;
  final HouseholdMemberRepository householdMemberRepository;
  final HouseholdCommandIdGenerator householdCommandIdGenerator;
  final HouseholdCreationIdGenerator householdCreationIdGenerator;
  final InviteRepository inviteRepository;
  final InviteCommandIdGenerator inviteCommandIdGenerator;
  final PendingInviteStore pendingInviteStore;
  final ChoreRepository choreRepository;
  final ChoreCommandIdGenerator choreCommandIdGenerator;
  final GuidedChoreSetupResumeStore guidedChoreSetupResumeStore;
  final ChoreCompletionOutbox choreCompletionOutbox;
  final CalendarRepository calendarRepository;
  final TodayCalendarSnapshotCache todayCalendarSnapshotCache;
  final CalendarCommandIdGenerator calendarCommandIdGenerator;
  final CalendarTimeResolver calendarTimeResolver;
  final BillingPort billingPort;
  final BillingExternalLinkLauncher billingExternalLinkLauncher;
  final BillingAssignmentRepository billingAssignmentRepository;
  final BillingAssignmentCommandIdGenerator billingAssignmentCommandIdGenerator;
  final EntitlementRepository entitlementRepository;
  final HouseholdFeatureGateRepository householdFeatureGateRepository;
  final AccountDeletionRepository accountDeletionRepository;
  final AccountDeletionCommandIdGenerator accountDeletionCommandIdGenerator;
  final DataExportRepository dataExportRepository;
  final DataExportCommandIdGenerator dataExportCommandIdGenerator;
  final DataExportDownloadLauncher dataExportDownloadLauncher;
  final HouseholdPrivacyRepository householdPrivacyRepository;
  final ProfilePreferencesRepository profilePreferencesRepository;
  final LegalSupportResourceLauncher legalSupportResourceLauncher;
  final NotificationRepository notificationRepository;
  final NotificationEndpointRepository notificationEndpointRepository;
  final NotificationEndpointLifecycleService notificationEndpointLifecycle;
  final NotificationPushCoordinatorService notificationPushCoordinator;
  final PlatformCapabilityRegistry platformCapabilityRegistry;
  final AppRuntimePolicyRepository runtimePolicyRepository;
  final RuntimePolicyExternalLinkLauncher runtimePolicyExternalLinkLauncher;
  final CalendarSyncRepository? calendarSyncRepository;
  final ChoreSyncRepository? choreSyncRepository;
  final NotificationSyncRepository? notificationSyncRepository;
}

Future<AuthDependencies> createAuthDependencies(
  AppPublicConfiguration configuration, {
  SecureStringStore? secureStringStore,
  SecureStringStore? notificationSecureStringStore,
  SecureStringStore? readCacheSecureStringStore,
  SecureStringStore? guidedChoreSetupSecureStringStore,
  SecureStringStore? choreCompletionOutboxSecureStringStore,
  bool? persistentReadCacheEnabled,
  ReadCacheClock? readCacheClock,
  ReadCacheClock? choreCompletionOutboxClock,
  NotificationEndpointMaterialGenerator? notificationEndpointMaterialGenerator,
  NotificationEndpointRepository? notificationEndpointRepository,
  NotificationPushCoordinatorService? notificationPushCoordinator,
  GoogleIdentityGateway? googleIdentityGateway,
  GoogleTokenExchange? googleTokenExchange,
  BillingPort? billingPort,
  BillingExternalLinkLauncher? billingExternalLinkLauncher,
  LegalSupportResourceLauncher? legalSupportResourceLauncher,
  RevenueCatSdk? revenueCatSdk,
  bool? revenueCatAndroidRuntime,
  bool? isWebRuntime,
  RuntimeClientBuildReader runtimeClientBuildReader =
      const PackageInfoRuntimeClientBuildReader(),
  SupabaseClientInitializer supabaseInitializer =
      const SupabaseFlutterClientInitializer(),
}) async {
  final bool webRuntime = isWebRuntime ?? kIsWeb;
  final bool androidRuntime =
      !webRuntime && defaultTargetPlatform == TargetPlatform.android;
  final RuntimeClientBuild? clientBuild;
  try {
    clientBuild = await runtimeClientBuildReader.read();
  } on Object {
    throw const RuntimeClientIdentityException();
  }
  final RuntimeClientIdentity? runtimeClientIdentity = clientBuild == null
      ? null
      : RuntimeClientIdentity.tryCreate(
          build: clientBuild,
          expectedApplicationId: webRuntime
              ? AppEnvironment.webApplicationId
              : configuration.applicationId,
          expectedConfiguredVersion: configuration.appVersion,
          contractVersion: configuration.contractVersion,
          environment: switch (configuration.environment) {
            AppEnvironment.dev => RuntimePolicyEnvironment.dev,
            AppEnvironment.prod => RuntimePolicyEnvironment.prod,
          },
          platform: webRuntime
              ? RuntimePolicyPlatform.web
              : RuntimePolicyPlatform.android,
        );
  if (runtimeClientIdentity == null) {
    throw const RuntimeClientIdentityException();
  }
  final SecureStringStore store =
      secureStringStore ??
      createSecureAuthStringStore(configuration.environment);
  final SupabaseSecureAuthStorage authStorage = SupabaseSecureAuthStorage(
    store,
  );
  final client = await supabaseInitializer.initialize(
    uri: configuration.supabaseUri,
    publishableKey: configuration.supabasePublishableKey,
    localStorage: authStorage,
    pkceStorage: authStorage,
    headers: runtimeClientIdentity.requestHeaders,
  );
  final EphemeralPendingInviteStore pendingInviteStore =
      EphemeralPendingInviteStore();
  final BillingPort resolvedBillingPort =
      billingPort ??
      createRevenueCatBillingPort(
        configuration: configuration,
        sdk: revenueCatSdk,
        isAndroidRuntime: revenueCatAndroidRuntime ?? androidRuntime,
      );
  final NotificationEndpointMaterialGenerator endpointMaterialGenerator =
      notificationEndpointMaterialGenerator ??
      SecureNotificationEndpointMaterialGenerator();
  final GuidedChoreSetupResumeStore guidedChoreSetupResumeStore = webRuntime
      ? const UnavailableGuidedChoreSetupResumeStore()
      : SecureGuidedChoreSetupResumeStore(
          guidedChoreSetupSecureStringStore ??
              createSecureGuidedChoreSetupStringStore(
                configuration.environment,
              ),
        );
  final NotificationEndpointRepository endpointRepository =
      notificationEndpointRepository ??
      ProviderNotificationEndpointRepository(
        SupabaseNotificationEndpointDataSource(client),
      );
  final NotificationEndpointLifecycleService endpointLifecycle;
  if (webRuntime) {
    endpointLifecycle = const UnavailableNotificationEndpointLifecycle();
  } else {
    final SecureNotificationInstallationStore notificationInstallationStore =
        SecureNotificationInstallationStore(
          notificationSecureStringStore ??
              createSecureNotificationStringStore(configuration.environment),
          endpointMaterialGenerator,
        );
    endpointLifecycle = NotificationEndpointLifecycle(
      endpointRepository,
      notificationInstallationStore,
      endpointMaterialGenerator,
    );
  }
  final List<SensitiveLocalStatePurgeParticipant> purgeParticipants =
      <SensitiveLocalStatePurgeParticipant>[
        endpointLifecycle,
        SecureAuthStoragePurgeParticipant(authStorage),
        pendingInviteStore,
      ];
  final List<SensitiveLocalStatePurgeParticipant>
  activeHouseholdTransitionParticipants = <SensitiveLocalStatePurgeParticipant>[
    pendingInviteStore,
  ];
  if (guidedChoreSetupResumeStore
      case final SensitiveLocalStatePurgeParticipant participant) {
    purgeParticipants.insert(0, participant);
    activeHouseholdTransitionParticipants.insert(0, participant);
  }
  if (resolvedBillingPort
      case final SensitiveLocalStatePurgeParticipant participant) {
    purgeParticipants.insert(0, participant);
  }
  HouseholdDataSource householdDataSource = SupabaseHouseholdDataSource(client);
  ChoreDataSource choreDataSource = SupabaseChoreDataSource(client);
  CalendarRepository calendarRepository = ProviderCalendarRepository(
    SupabaseCalendarDataSource(client),
  );
  TodayCalendarSnapshotCache todayCalendarSnapshotCache =
      const UnavailableTodayCalendarSnapshotCache();
  ActiveHouseholdSnapshotWriter activeHouseholdSnapshotWriter =
      const UnavailableActiveHouseholdSnapshotWriter();
  ChoreCompletionOutbox choreCompletionOutbox =
      const UnavailableChoreCompletionOutbox();
  final bool readCacheEnabled = persistentReadCacheEnabled ?? androidRuntime;
  if (readCacheEnabled) {
    final SupabaseReadCacheScopeResolver scopeResolver =
        SupabaseReadCacheScopeResolver(client);
    final SecureReadCache readCache = SecureReadCache(
      readCacheSecureStringStore ??
          createSecureReadCacheStringStore(configuration.environment),
      scopeResolver,
      clock: readCacheClock ?? DateTime.now,
    );
    final SecureChoreCompletionOutbox secureCompletionOutbox =
        SecureChoreCompletionOutbox(
          choreCompletionOutboxSecureStringStore ??
              createSecureChoreCompletionOutboxStringStore(
                configuration.environment,
              ),
          scopeResolver,
          clock: choreCompletionOutboxClock ?? readCacheClock ?? DateTime.now,
        );
    choreCompletionOutbox = secureCompletionOutbox;
    final CachedHouseholdDataSource cachedHouseholdDataSource =
        CachedHouseholdDataSource(householdDataSource, readCache);
    householdDataSource = cachedHouseholdDataSource;
    choreDataSource = CachedChoreDataSource(choreDataSource, readCache);
    final ReadCacheTodayCalendarSnapshotCache calendarSnapshotCache =
        ReadCacheTodayCalendarSnapshotCache(readCache);
    todayCalendarSnapshotCache = calendarSnapshotCache;
    calendarRepository = TodayCacheInvalidatingCalendarRepository(
      calendarRepository,
      calendarSnapshotCache,
    );
    activeHouseholdSnapshotWriter = cachedHouseholdDataSource;
    purgeParticipants.insert(0, readCache);
    purgeParticipants.insert(0, secureCompletionOutbox);
    activeHouseholdTransitionParticipants.insert(0, readCache);
    activeHouseholdTransitionParticipants.insert(0, secureCompletionOutbox);
  }
  AuthSignInLauncher signInLauncher = createAuthSignInLauncher();
  RecentAuthenticationService recentAuthenticationService =
      const UnavailableRecentAuthenticationService();
  final String? googleWebClientId = configuration.googleWebClientId;
  if (!webRuntime && googleWebClientId != null) {
    final GoogleIdentityGateway identityGateway =
        googleIdentityGateway ?? GoogleSignInIdentityGateway.instance;
    final GoogleTokenExchange tokenExchange =
        googleTokenExchange ?? SupabaseGoogleTokenExchange(client);
    signInLauncher = ProviderAuthSignInLauncher(
      GoogleSupabaseAuthSignInDataSource(
        serverClientId: googleWebClientId,
        identityGateway: identityGateway,
        tokenExchange: tokenExchange,
      ),
    );
    recentAuthenticationService = GoogleSupabaseRecentAuthenticationService(
      serverClientId: googleWebClientId,
      identityGateway: identityGateway,
      tokenExchange: tokenExchange,
      client: client,
    );
    purgeParticipants.add(
      GoogleIdentityStatePurgeParticipant(
        serverClientId: googleWebClientId,
        identityGateway: identityGateway,
      ),
    );
  }

  final NotificationRepository notificationRepository =
      ProviderNotificationRepository(SupabaseNotificationDataSource(client));
  final NotificationPushCoordinatorService pushCoordinator =
      notificationPushCoordinator ??
      await createNotificationPushCoordinator(
        configuration: configuration,
        notificationRepository: notificationRepository,
        endpointLifecycle: endpointLifecycle,
      );
  final PlatformCapabilityRegistry platformCapabilityRegistry = webRuntime
      ? const PlatformCapabilityRegistry.web(externalUriLauncherComposed: true)
      : PlatformCapabilityRegistry.android(
          notificationAdapterComposed:
              androidRuntime &&
              pushCoordinator.state.permission !=
                  NotificationPushPermission.unavailable,
          billingPortAvailable: resolvedBillingPort.isAvailable,
          secureLocalStorageComposed: readCacheEnabled,
          externalUriLauncherComposed: androidRuntime,
        );

  return AuthDependencies(
    sessionRepository: ProviderAuthSessionRepository(
      SupabaseAuthSessionDataSource(client),
    ),
    signInLauncher: signInLauncher,
    emailOtpService: ProviderAuthEmailOtpService(
      SupabaseAuthEmailOtpDataSource(client),
    ),
    recentAuthenticationService: recentAuthenticationService,
    localStatePurger: CompositeSensitiveLocalStatePurger(purgeParticipants),
    activeHouseholdSnapshotWriter: activeHouseholdSnapshotWriter,
    activeHouseholdTransitionLocalState:
        CompositeActiveHouseholdTransitionLocalState(
          snapshotWriter: activeHouseholdSnapshotWriter,
          participants: activeHouseholdTransitionParticipants,
        ),
    householdRepository: ProviderHouseholdRepository(householdDataSource),
    householdSelectionRepository: ProviderHouseholdSelectionRepository(
      SupabaseHouseholdSelectionDataSource(client),
    ),
    householdMemberRepository: ProviderHouseholdMemberRepository(
      SupabaseHouseholdMemberDataSource(client),
    ),
    householdCommandIdGenerator: SecureHouseholdCommandIdGenerator(),
    householdCreationIdGenerator: SecureHouseholdCreationIdGenerator(),
    inviteRepository: ProviderInviteRepository(
      SupabaseInviteDataSource(client),
    ),
    inviteCommandIdGenerator: SecureInviteCommandIdGenerator(),
    pendingInviteStore: pendingInviteStore,
    choreRepository: ProviderChoreRepository(choreDataSource),
    choreCommandIdGenerator: SecureChoreCommandIdGenerator(),
    guidedChoreSetupResumeStore: guidedChoreSetupResumeStore,
    choreCompletionOutbox: choreCompletionOutbox,
    calendarRepository: calendarRepository,
    todayCalendarSnapshotCache: todayCalendarSnapshotCache,
    calendarCommandIdGenerator: SecureCalendarCommandIdGenerator(),
    calendarTimeResolver: TimezoneCalendarTimeResolver(),
    billingPort: resolvedBillingPort,
    billingExternalLinkLauncher:
        billingExternalLinkLauncher ??
        UrlLauncherBillingExternalLinkLauncher(
          publicSiteUri: configuration.publicSiteUri,
          supportUri: configuration.supportUri,
        ),
    billingAssignmentRepository: ProviderBillingAssignmentRepository(
      SupabaseBillingAssignmentDataSource(client),
    ),
    billingAssignmentCommandIdGenerator:
        SecureBillingAssignmentCommandIdGenerator(),
    entitlementRepository: ProviderEntitlementRepository(
      SupabaseEntitlementDataSource(client),
    ),
    householdFeatureGateRepository: ProviderHouseholdFeatureGateRepository(
      SupabaseHouseholdFeatureGateDataSource(client),
    ),
    accountDeletionRepository: ProviderAccountDeletionRepository(
      SupabaseAccountDeletionDataSource(client),
    ),
    accountDeletionCommandIdGenerator:
        SecureAccountDeletionCommandIdGenerator(),
    dataExportRepository: ProviderDataExportRepository(
      SupabaseDataExportDataSource(client),
    ),
    dataExportCommandIdGenerator: SecureDataExportCommandIdGenerator(),
    dataExportDownloadLauncher: const UrlLauncherDataExportDownloadLauncher(),
    householdPrivacyRepository: ProviderHouseholdPrivacyRepository(
      SupabaseHouseholdPrivacyDataSource(client),
    ),
    profilePreferencesRepository: ProviderProfilePreferencesRepository(
      SupabaseProfilePreferencesDataSource(client),
    ),
    legalSupportResourceLauncher:
        legalSupportResourceLauncher ??
        UrlLauncherLegalSupportResourceLauncher(
          publicSiteUri: configuration.publicSiteUri,
          supportUri: configuration.supportUri,
        ),
    notificationRepository: notificationRepository,
    notificationEndpointRepository: endpointRepository,
    notificationEndpointLifecycle: endpointLifecycle,
    notificationPushCoordinator: pushCoordinator,
    platformCapabilityRegistry: platformCapabilityRegistry,
    runtimePolicyRepository: ProviderAppRuntimePolicyRepository(
      dataSource: SupabaseAppRuntimePolicyDataSource(client),
      client: runtimeClientIdentity,
    ),
    runtimePolicyExternalLinkLauncher: webRuntime
        ? const UnavailableRuntimePolicyExternalLinkLauncher()
        : UrlLauncherRuntimePolicyExternalLinkLauncher(
            applicationId: configuration.applicationId,
          ),
    calendarSyncRepository: ProviderCalendarSyncRepository(
      SupabaseCalendarSyncDataSource(client),
    ),
    choreSyncRepository: ProviderChoreSyncRepository(
      SupabaseChoreSyncDataSource(client),
    ),
    notificationSyncRepository: ProviderNotificationSyncRepository(
      SupabaseNotificationSyncDataSource(client),
    ),
  );
}

AuthDependencies createUnavailableAuthDependencies() {
  final EphemeralPendingInviteStore pendingInviteStore =
      EphemeralPendingInviteStore();
  const UnavailableNotificationEndpointLifecycle endpointLifecycle =
      UnavailableNotificationEndpointLifecycle();
  return AuthDependencies(
    sessionRepository: createAuthSessionRepository(),
    signInLauncher: createAuthSignInLauncher(),
    emailOtpService: const UnavailableAuthEmailOtpService(),
    recentAuthenticationService: const UnavailableRecentAuthenticationService(),
    localStatePurger: CompositeSensitiveLocalStatePurger(
      <SensitiveLocalStatePurgeParticipant>[
        endpointLifecycle,
        pendingInviteStore,
      ],
    ),
    activeHouseholdSnapshotWriter:
        const UnavailableActiveHouseholdSnapshotWriter(),
    activeHouseholdTransitionLocalState:
        const UnavailableActiveHouseholdTransitionLocalState(),
    householdRepository: const UnavailableHouseholdRepository(),
    householdSelectionRepository:
        const UnavailableHouseholdSelectionRepository(),
    householdMemberRepository: const UnavailableHouseholdMemberRepository(),
    householdCommandIdGenerator: SecureHouseholdCommandIdGenerator(),
    householdCreationIdGenerator: SecureHouseholdCreationIdGenerator(),
    inviteRepository: const UnavailableInviteRepository(),
    inviteCommandIdGenerator: SecureInviteCommandIdGenerator(),
    pendingInviteStore: pendingInviteStore,
    choreRepository: const UnavailableChoreRepository(),
    choreCommandIdGenerator: SecureChoreCommandIdGenerator(),
    guidedChoreSetupResumeStore: const UnavailableGuidedChoreSetupResumeStore(),
    choreCompletionOutbox: const UnavailableChoreCompletionOutbox(),
    calendarRepository: const UnavailableCalendarRepository(),
    todayCalendarSnapshotCache: const UnavailableTodayCalendarSnapshotCache(),
    calendarCommandIdGenerator: SecureCalendarCommandIdGenerator(),
    calendarTimeResolver: TimezoneCalendarTimeResolver(),
    billingPort: const UnavailableBillingPort(),
    billingExternalLinkLauncher: const UnavailableBillingExternalLinkLauncher(),
    billingAssignmentRepository: const UnavailableBillingAssignmentRepository(),
    billingAssignmentCommandIdGenerator:
        SecureBillingAssignmentCommandIdGenerator(),
    entitlementRepository: const UnavailableEntitlementRepository(),
    householdFeatureGateRepository:
        const UnavailableHouseholdFeatureGateRepository(),
    accountDeletionRepository: const UnavailableAccountDeletionRepository(),
    accountDeletionCommandIdGenerator:
        SecureAccountDeletionCommandIdGenerator(),
    dataExportRepository: const UnavailableDataExportRepository(),
    dataExportCommandIdGenerator: SecureDataExportCommandIdGenerator(),
    dataExportDownloadLauncher: const UnavailableDataExportDownloadLauncher(),
    householdPrivacyRepository: const UnavailableHouseholdPrivacyRepository(),
    profilePreferencesRepository:
        const UnavailableProfilePreferencesRepository(),
    legalSupportResourceLauncher:
        const UnavailableLegalSupportResourceLauncher(),
    notificationRepository: const UnavailableNotificationRepository(),
    notificationEndpointRepository:
        const UnavailableNotificationEndpointRepository(),
    notificationEndpointLifecycle: endpointLifecycle,
    notificationPushCoordinator: const UnavailableNotificationPushCoordinator(),
    platformCapabilityRegistry: const PlatformCapabilityRegistry.unavailable(),
    runtimePolicyRepository: const UnavailableAppRuntimePolicyRepository(),
    runtimePolicyExternalLinkLauncher:
        const UnavailableRuntimePolicyExternalLinkLauncher(),
  );
}

final class RuntimeClientIdentityException implements Exception {
  const RuntimeClientIdentityException();

  @override
  String toString() => 'RuntimeClientIdentityException(invalid_metadata)';
}

SecureStringStore createSecureAuthStringStore(AppEnvironment environment) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: secureAuthAndroidOptions(environment),
      iOptions: secureAuthIosOptions(environment),
    ),
    SupabaseSecureAuthStorage.sessionStorageKey,
  );
}

SecureStringStore createSecureNotificationStringStore(
  AppEnvironment environment,
) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: secureNotificationAndroidOptions(environment),
      iOptions: secureNotificationIosOptions(environment),
    ),
    SecureNotificationInstallationStore.installationStorageKey,
  );
}

SecureStringStore createSecureReadCacheStringStore(AppEnvironment environment) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: secureReadCacheAndroidOptions(environment),
      iOptions: secureReadCacheIosOptions(environment),
    ),
    ReadCacheSlot.activeHousehold.storageKey,
  );
}

SecureStringStore createSecureGuidedChoreSetupStringStore(
  AppEnvironment environment,
) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: secureGuidedChoreSetupAndroidOptions(environment),
      iOptions: secureGuidedChoreSetupIosOptions(environment),
    ),
    SecureGuidedChoreSetupResumeStore.storageKey,
  );
}

SecureStringStore createSecureChoreCompletionOutboxStringStore(
  AppEnvironment environment,
) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: secureChoreCompletionOutboxAndroidOptions(environment),
      iOptions: secureChoreCompletionOutboxIosOptions(environment),
    ),
    SecureChoreCompletionOutbox.storageKey,
  );
}

AndroidOptions secureAuthAndroidOptions(AppEnvironment environment) {
  return AndroidOptions(
    resetOnError: true,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
    enforceBiometrics: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'kinflow_auth_${environment.value}_v1',
  );
}

AndroidOptions secureNotificationAndroidOptions(AppEnvironment environment) {
  return AndroidOptions(
    resetOnError: true,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
    enforceBiometrics: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'kinflow_notification_${environment.value}_v1',
  );
}

AndroidOptions secureReadCacheAndroidOptions(AppEnvironment environment) {
  return AndroidOptions(
    resetOnError: true,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: false,
    enforceBiometrics: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'kinflow_read_cache_${environment.value}_v1',
  );
}

AndroidOptions secureGuidedChoreSetupAndroidOptions(
  AppEnvironment environment,
) {
  return AndroidOptions(
    resetOnError: true,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: false,
    enforceBiometrics: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'kinflow_guided_chore_setup_${environment.value}_v1',
  );
}

AndroidOptions secureChoreCompletionOutboxAndroidOptions(
  AppEnvironment environment,
) {
  return AndroidOptions(
    resetOnError: true,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: false,
    enforceBiometrics: false,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    storageNamespace: 'kinflow_chore_completion_outbox_${environment.value}_v1',
  );
}

IOSOptions secureAuthIosOptions(AppEnvironment environment) {
  return IOSOptions(accountName: 'kinflow_auth_${environment.value}_v1');
}

IOSOptions secureNotificationIosOptions(AppEnvironment environment) {
  return IOSOptions(
    accountName: 'kinflow_notification_${environment.value}_v1',
  );
}

IOSOptions secureReadCacheIosOptions(AppEnvironment environment) {
  return IOSOptions(accountName: 'kinflow_read_cache_${environment.value}_v1');
}

IOSOptions secureGuidedChoreSetupIosOptions(AppEnvironment environment) {
  return IOSOptions(
    accountName: 'kinflow_guided_chore_setup_${environment.value}_v1',
  );
}

IOSOptions secureChoreCompletionOutboxIosOptions(AppEnvironment environment) {
  return IOSOptions(
    accountName: 'kinflow_chore_completion_outbox_${environment.value}_v1',
  );
}

AuthSessionRepository createAuthSessionRepository() {
  return const UnavailableAuthSessionRepository();
}

AuthSignInLauncher createAuthSignInLauncher() {
  return const UnavailableAuthSignInLauncher();
}

SensitiveLocalStatePurger createSensitiveLocalStatePurger() {
  return CompositeSensitiveLocalStatePurger(
    const <SensitiveLocalStatePurgeParticipant>[],
  );
}

ActiveHouseholdSnapshotWriter createActiveHouseholdSnapshotWriter() {
  return const UnavailableActiveHouseholdSnapshotWriter();
}
