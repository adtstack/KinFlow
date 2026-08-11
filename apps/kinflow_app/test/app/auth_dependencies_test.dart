import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/application/unavailable_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/unavailable_billing_port.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_entitlement_repository.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/data/services/secure_billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/data/repositories/provider_calendar_repository.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_repository.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/data/services/secure_chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/data/services/secure_guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_invite_repository.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_repository.dart';
import 'package:kinflow_app/features/notifications/data/services/secure_notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';
import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_client_build_reader.dart';
import 'package:kinflow_app/features/runtime_policy/data/repositories/provider_app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/application/unavailable_runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/data/services/secure_account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_data_export_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/unavailable_data_export_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/data/repositories/unavailable_household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/application/unavailable_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/application/unavailable_legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/data/services/secure_data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/data/services/unavailable_data_export_download_launcher.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/infrastructure/cache/cached_household_data_source.dart';
import 'package:kinflow_app/infrastructure/cache/read_cache_today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/infrastructure/cache/today_cache_invalidating_calendar_repository.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_data_export_download_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_billing_external_link_launcher.dart';
import 'package:kinflow_app/infrastructure/url_launcher/url_launcher_legal_support_resource_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fixtures/app_public_configuration_fixture.dart';
import '../support/fakes/fake_household_dependencies.dart';

void main() {
  test('secure auth options isolate dev and prod with approved ciphers', () {
    final Map<String, String> dev = secureAuthAndroidOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> prod = secureAuthAndroidOptions(
      AppEnvironment.prod,
    ).toMap();
    final Map<String, String> notificationDev =
        secureNotificationAndroidOptions(AppEnvironment.dev).toMap();
    final Map<String, String> notificationProd =
        secureNotificationAndroidOptions(AppEnvironment.prod).toMap();
    final Map<String, String> readCacheDev = secureReadCacheAndroidOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> readCacheProd = secureReadCacheAndroidOptions(
      AppEnvironment.prod,
    ).toMap();
    final Map<String, String> guidedDev = secureGuidedChoreSetupAndroidOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> guidedProd = secureGuidedChoreSetupAndroidOptions(
      AppEnvironment.prod,
    ).toMap();
    final Map<String, String> completionOutboxDev =
        secureChoreCompletionOutboxAndroidOptions(AppEnvironment.dev).toMap();
    final Map<String, String> completionOutboxProd =
        secureChoreCompletionOutboxAndroidOptions(AppEnvironment.prod).toMap();
    final Map<String, String> authIos = secureAuthIosOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> notificationIos = secureNotificationIosOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> readCacheIos = secureReadCacheIosOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> guidedIos = secureGuidedChoreSetupIosOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> completionOutboxIos =
        secureChoreCompletionOutboxIosOptions(AppEnvironment.dev).toMap();

    expect(dev['storageNamespace'], 'kinflow_auth_dev_v1');
    expect(prod['storageNamespace'], 'kinflow_auth_prod_v1');
    expect(dev['storageNamespace'], isNot(prod['storageNamespace']));
    expect(notificationDev['storageNamespace'], 'kinflow_notification_dev_v1');
    expect(
      notificationProd['storageNamespace'],
      'kinflow_notification_prod_v1',
    );
    expect(notificationDev['storageNamespace'], isNot(dev['storageNamespace']));
    expect(readCacheDev['storageNamespace'], 'kinflow_read_cache_dev_v1');
    expect(readCacheProd['storageNamespace'], 'kinflow_read_cache_prod_v1');
    expect(
      readCacheDev['storageNamespace'],
      isNot(readCacheProd['storageNamespace']),
    );
    expect(
      readCacheDev['storageNamespace'],
      isNot(notificationDev['storageNamespace']),
    );
    expect(authIos['accountName'], 'kinflow_auth_dev_v1');
    expect(notificationIos['accountName'], 'kinflow_notification_dev_v1');
    expect(notificationIos['accountName'], isNot(authIos['accountName']));
    expect(readCacheIos['accountName'], 'kinflow_read_cache_dev_v1');
    expect(guidedDev['storageNamespace'], 'kinflow_guided_chore_setup_dev_v1');
    expect(
      guidedProd['storageNamespace'],
      'kinflow_guided_chore_setup_prod_v1',
    );
    expect(
      guidedDev['storageNamespace'],
      isNot(guidedProd['storageNamespace']),
    );
    expect(guidedDev['storageNamespace'], isNot(dev['storageNamespace']));
    expect(guidedIos['accountName'], 'kinflow_guided_chore_setup_dev_v1');
    expect(
      completionOutboxDev['storageNamespace'],
      'kinflow_chore_completion_outbox_dev_v1',
    );
    expect(
      completionOutboxProd['storageNamespace'],
      'kinflow_chore_completion_outbox_prod_v1',
    );
    expect(
      completionOutboxDev['storageNamespace'],
      isNot(readCacheDev['storageNamespace']),
    );
    expect(
      completionOutboxIos['accountName'],
      'kinflow_chore_completion_outbox_dev_v1',
    );
    expect(dev['resetOnError'], 'true');
    expect(dev['migrateOnAlgorithmChange'], 'true');
    expect(dev['migrateWithBackup'], 'true');
    expect(readCacheDev['migrateWithBackup'], 'false');
    expect(guidedDev['migrateWithBackup'], 'false');
    expect(completionOutboxDev['migrateWithBackup'], 'false');
    expect(dev['enforceBiometrics'], 'false');
    expect(
      dev['keyCipherAlgorithm'],
      KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding.name,
    );
    expect(
      dev['storageCipherAlgorithm'],
      StorageCipherAlgorithm.AES_GCM_NoPadding.name,
    );
  });

  test('runtime composition uses secure session and PKCE storage', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final _MemorySecureStringStore notificationStore =
        _MemorySecureStringStore();
    final _MemorySecureStringStore guidedStore = _MemorySecureStringStore();
    guidedStore.values[SecureGuidedChoreSetupResumeStore.storageKey] =
        'opaque-guided-resume-record';
    notificationStore.values[SecureNotificationInstallationStore
            .installationStorageKey] =
        '53000000-0000-4000-8000-000000000001';
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    addTearDown(initializer.dispose);
    final configuration = publicConfigurationFixture();

    final AuthDependencies dependencies = await createAuthDependencies(
      configuration,
      secureStringStore: store,
      notificationSecureStringStore: notificationStore,
      guidedChoreSetupSecureStringStore: guidedStore,
      persistentReadCacheEnabled: false,
      runtimeClientBuildReader: const _RuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );

    expect(
      dependencies.sessionRepository,
      isA<ProviderAuthSessionRepository>(),
    );
    expect(dependencies.emailOtpService, isA<ProviderAuthEmailOtpService>());
    expect(dependencies.emailOtpService.isAvailable, isTrue);
    expect(
      dependencies.householdRepository,
      isA<ProviderHouseholdRepository>(),
    );
    expect(dependencies.inviteRepository, isA<ProviderInviteRepository>());
    expect(dependencies.choreRepository, isA<ProviderChoreRepository>());
    expect(
      dependencies.choreSyncRepository,
      isA<ProviderChoreSyncRepository>(),
    );
    expect(
      dependencies.guidedChoreSetupResumeStore,
      isA<SecureGuidedChoreSetupResumeStore>(),
    );
    expect(
      dependencies.choreCompletionOutbox,
      isA<UnavailableChoreCompletionOutbox>(),
    );
    expect(dependencies.calendarRepository, isA<ProviderCalendarRepository>());
    expect(
      dependencies.todayCalendarSnapshotCache,
      isA<UnavailableTodayCalendarSnapshotCache>(),
    );
    expect(
      dependencies.notificationRepository,
      isA<ProviderNotificationRepository>(),
    );
    expect(
      dependencies.notificationEndpointRepository,
      isA<ProviderNotificationEndpointRepository>(),
    );
    expect(
      dependencies.calendarTimeResolver,
      isA<TimezoneCalendarTimeResolver>(),
    );
    expect(dependencies.billingPort, isA<UnavailableBillingPort>());
    expect(
      dependencies.billingExternalLinkLauncher,
      isA<UrlLauncherBillingExternalLinkLauncher>(),
    );
    expect(
      dependencies.billingAssignmentRepository,
      isA<ProviderBillingAssignmentRepository>(),
    );
    expect(
      dependencies.billingAssignmentCommandIdGenerator,
      isA<SecureBillingAssignmentCommandIdGenerator>(),
    );
    expect(
      dependencies.entitlementRepository,
      isA<ProviderEntitlementRepository>(),
    );
    expect(
      dependencies.householdFeatureGateRepository,
      isA<ProviderHouseholdFeatureGateRepository>(),
    );
    expect(
      dependencies.accountDeletionRepository,
      isA<ProviderAccountDeletionRepository>(),
    );
    expect(
      dependencies.accountDeletionCommandIdGenerator,
      isA<SecureAccountDeletionCommandIdGenerator>(),
    );
    expect(
      dependencies.dataExportRepository,
      isA<ProviderDataExportRepository>(),
    );
    expect(
      dependencies.dataExportCommandIdGenerator,
      isA<SecureDataExportCommandIdGenerator>(),
    );
    expect(
      dependencies.dataExportDownloadLauncher,
      isA<UrlLauncherDataExportDownloadLauncher>(),
    );
    expect(
      dependencies.householdPrivacyRepository,
      isA<ProviderHouseholdPrivacyRepository>(),
    );
    expect(
      dependencies.profilePreferencesRepository,
      isA<ProviderProfilePreferencesRepository>(),
    );
    expect(
      dependencies.legalSupportResourceLauncher,
      isA<UrlLauncherLegalSupportResourceLauncher>(),
    );
    expect(
      dependencies.pendingInviteStore.capture(
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
      ),
      isTrue,
    );
    expect(dependencies.pendingInviteStore.read(), isNotNull);
    expect(dependencies.signInLauncher.isAvailable, isFalse);
    expect(initializer.uri, configuration.supabaseUri);
    expect(initializer.publishableKey, configuration.supabasePublishableKey);
    expect(initializer.localStorage, same(initializer.pkceStorage));
    expect(initializer.headers, <String, String>{
      'X-KinFlow-Client-Version': '0.1.0-dev+1',
      'X-KinFlow-Client-Build': '1',
      'X-KinFlow-Contract-Version': '2026-07-25',
      'X-KinFlow-Platform': 'android',
      'X-KinFlow-Environment': 'dev',
    });
    expect(
      dependencies.runtimePolicyRepository,
      isA<ProviderAppRuntimePolicyRepository>(),
    );
    final PlatformCapabilitySnapshot capabilitySnapshot = dependencies
        .platformCapabilityRegistry
        .resolve(
          notificationSignal: PlatformNotificationCapabilitySignal.unavailable,
        );
    expect(
      capabilitySnapshot.find(PlatformCapabilityId.notificationDelivery)?.state,
      PlatformCapabilitySupportState.fallbackOnly,
    );
    expect(
      capabilitySnapshot.find(PlatformCapabilityId.storeBilling)?.state,
      PlatformCapabilitySupportState.fallbackOnly,
    );
    expect(
      capabilitySnapshot.find(PlatformCapabilityId.secureLocalStorage)?.state,
      PlatformCapabilitySupportState.fallbackOnly,
    );
    expect(
      capabilitySnapshot.find(PlatformCapabilityId.externalLinks)?.state,
      PlatformCapabilitySupportState.available,
    );

    final SensitiveLocalStatePurgeResult result = await dependencies
        .localStatePurger
        .purge();
    expect(result, isA<SensitiveLocalStatePurged>());
    expect(store.deleteAllCount, 1);
    expect(guidedStore.deleteAllCount, 1);
    expect(guidedStore.values, isEmpty);
    expect(notificationStore.deleteAllCount, 0);
    expect(
      notificationStore.values[SecureNotificationInstallationStore
          .installationStorageKey],
      '53000000-0000-4000-8000-000000000001',
    );
    expect(dependencies.pendingInviteStore.read(), isNull);
  });

  test('unavailable composition fails closed for export downloads', () async {
    final AuthDependencies dependencies = createUnavailableAuthDependencies();

    expect(dependencies.choreSyncRepository, isNull);
    expect(dependencies.emailOtpService, isA<UnavailableAuthEmailOtpService>());
    expect(dependencies.emailOtpService.isAvailable, isFalse);
    expect(
      dependencies.dataExportRepository,
      isA<UnavailableDataExportRepository>(),
    );
    expect(
      dependencies.dataExportDownloadLauncher,
      isA<UnavailableDataExportDownloadLauncher>(),
    );
    expect(
      dependencies.householdPrivacyRepository,
      isA<UnavailableHouseholdPrivacyRepository>(),
    );
    expect(
      dependencies.profilePreferencesRepository,
      isA<UnavailableProfilePreferencesRepository>(),
    );
    expect(
      dependencies.billingExternalLinkLauncher,
      isA<UnavailableBillingExternalLinkLauncher>(),
    );
    expect(
      dependencies.legalSupportResourceLauncher,
      isA<UnavailableLegalSupportResourceLauncher>(),
    );
    expect(
      dependencies.guidedChoreSetupResumeStore,
      isA<UnavailableGuidedChoreSetupResumeStore>(),
    );
    expect(
      dependencies.choreCompletionOutbox,
      isA<UnavailableChoreCompletionOutbox>(),
    );
    expect(
      await dependencies.legalSupportResourceLauncher.launch(
        LegalSupportResource.privacy,
      ),
      LegalSupportResourceLaunchResult.unavailable,
    );
    expect(
      await dependencies.billingExternalLinkLauncher.launch(
        BillingExternalLink.terms,
      ),
      BillingExternalLinkLaunchResult.unavailable,
    );
    expect(
      await dependencies.dataExportDownloadLauncher.launch(
        Uri.parse('https://example.invalid/?token=opaque'),
      ),
      isFalse,
    );
    final PlatformCapabilitySnapshot capabilitySnapshot = dependencies
        .platformCapabilityRegistry
        .resolve(
          notificationSignal: PlatformNotificationCapabilitySignal.authorized,
        );
    expect(
      capabilitySnapshot.entries.every(
        (PlatformCapabilityStatus value) =>
            value.state == PlatformCapabilitySupportState.fallbackOnly &&
            value.provider == PlatformCapabilityProvider.unavailable,
      ),
      isTrue,
    );
  });

  test('household transition purges scoped state but preserves auth', () async {
    final _MemorySecureStringStore authStore = _MemorySecureStringStore();
    final _MemorySecureStringStore notificationStore =
        _MemorySecureStringStore();
    final _MemorySecureStringStore guidedStore = _MemorySecureStringStore();
    guidedStore.values[SecureGuidedChoreSetupResumeStore.storageKey] =
        'opaque-guided-resume-record';
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    addTearDown(initializer.dispose);
    final AuthDependencies dependencies = await createAuthDependencies(
      publicConfigurationFixture(),
      secureStringStore: authStore,
      notificationSecureStringStore: notificationStore,
      guidedChoreSetupSecureStringStore: guidedStore,
      persistentReadCacheEnabled: false,
      runtimeClientBuildReader: const _RuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );
    expect(
      dependencies.pendingInviteStore.capture(
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG',
      ),
      isTrue,
    );

    expect(
      await dependencies.activeHouseholdTransitionLocalState.replaceAfterSwitch(
        activeHouseholdFixture(),
      ),
      isTrue,
    );

    expect(authStore.deleteAllCount, 0);
    expect(notificationStore.deleteAllCount, 0);
    expect(guidedStore.deleteAllCount, 1);
    expect(dependencies.pendingInviteStore.read(), isNull);
  });

  test(
    'household departure purges completion outbox before preserving auth',
    () async {
      final _MemorySecureStringStore authStore = _MemorySecureStringStore();
      final _MemorySecureStringStore notificationStore =
          _MemorySecureStringStore();
      final _MemorySecureStringStore readCacheStore =
          _MemorySecureStringStore();
      final _MemorySecureStringStore completionOutboxStore =
          _MemorySecureStringStore();
      final _MemorySecureStringStore guidedStore = _MemorySecureStringStore();
      readCacheStore.values['active_household_v1'] = 'opaque-cache-record';
      completionOutboxStore.values[SecureChoreCompletionOutbox.storageKey] =
          'opaque-completion-command';
      final _RecordingSupabaseInitializer initializer =
          _RecordingSupabaseInitializer();
      addTearDown(initializer.dispose);

      final AuthDependencies dependencies = await createAuthDependencies(
        publicConfigurationFixture(),
        secureStringStore: authStore,
        notificationSecureStringStore: notificationStore,
        readCacheSecureStringStore: readCacheStore,
        choreCompletionOutboxSecureStringStore: completionOutboxStore,
        guidedChoreSetupSecureStringStore: guidedStore,
        persistentReadCacheEnabled: true,
        runtimeClientBuildReader: const _RuntimeClientBuildReader(),
        supabaseInitializer: initializer,
      );

      expect(
        await dependencies.activeHouseholdTransitionLocalState
            .clearAfterDeparture(),
        isTrue,
      );
      expect(completionOutboxStore.values, isEmpty);
      expect(completionOutboxStore.deleteAllCount, 1);
      expect(readCacheStore.values, isEmpty);
      expect(readCacheStore.deleteAllCount, 2);
      expect(guidedStore.deleteAllCount, 1);
      expect(authStore.deleteAllCount, 0);
      expect(notificationStore.deleteAllCount, 0);
    },
  );

  test('enabled read cache participates in fail-closed local purge', () async {
    final _MemorySecureStringStore authStore = _MemorySecureStringStore();
    final _MemorySecureStringStore notificationStore =
        _MemorySecureStringStore();
    final _MemorySecureStringStore readCacheStore = _MemorySecureStringStore();
    final _MemorySecureStringStore completionOutboxStore =
        _MemorySecureStringStore();
    final _MemorySecureStringStore guidedStore = _MemorySecureStringStore();
    readCacheStore.values['active_household_v1'] = 'opaque-cache-record';
    completionOutboxStore.values[SecureChoreCompletionOutbox.storageKey] =
        'opaque-completion-command';
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    addTearDown(initializer.dispose);

    final AuthDependencies dependencies = await createAuthDependencies(
      publicConfigurationFixture(),
      secureStringStore: authStore,
      notificationSecureStringStore: notificationStore,
      readCacheSecureStringStore: readCacheStore,
      choreCompletionOutboxSecureStringStore: completionOutboxStore,
      guidedChoreSetupSecureStringStore: guidedStore,
      persistentReadCacheEnabled: true,
      runtimeClientBuildReader: const _RuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );

    expect(
      dependencies.activeHouseholdSnapshotWriter,
      isA<CachedHouseholdDataSource>(),
    );
    expect(
      dependencies.todayCalendarSnapshotCache,
      isA<ReadCacheTodayCalendarSnapshotCache>(),
    );
    expect(
      dependencies.calendarRepository,
      isA<TodayCacheInvalidatingCalendarRepository>(),
    );
    expect(
      dependencies.choreCompletionOutbox,
      isA<SecureChoreCompletionOutbox>(),
    );
    expect(
      dependencies.platformCapabilityRegistry
          .resolve(
            notificationSignal:
                PlatformNotificationCapabilitySignal.unavailable,
          )
          .find(PlatformCapabilityId.secureLocalStorage)
          ?.state,
      PlatformCapabilitySupportState.available,
    );
    expect(
      await dependencies.localStatePurger.purge(),
      isA<SensitiveLocalStatePurged>(),
    );
    expect(readCacheStore.values, isEmpty);
    expect(readCacheStore.deleteAllCount, 1);
    expect(completionOutboxStore.values, isEmpty);
    expect(completionOutboxStore.deleteAllCount, 1);
    expect(authStore.deleteAllCount, 1);
    expect(guidedStore.deleteAllCount, 1);
  });

  test('billing adapter participates in account-switch local purge', () async {
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    final _PurgeAwareBillingPort billingPort = _PurgeAwareBillingPort();
    addTearDown(initializer.dispose);

    final AuthDependencies dependencies = await createAuthDependencies(
      publicConfigurationFixture(),
      secureStringStore: _MemorySecureStringStore(),
      notificationSecureStringStore: _MemorySecureStringStore(),
      guidedChoreSetupSecureStringStore: _MemorySecureStringStore(),
      persistentReadCacheEnabled: false,
      billingPort: billingPort,
      runtimeClientBuildReader: const _RuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );

    expect(
      await dependencies.localStatePurger.purge(),
      isA<SensitiveLocalStatePurged>(),
    );
    expect(billingPort.purgeCount, 1);
  });

  test('runtime composes configured Google sign-in and local purge', () async {
    const String clientId = '1234567890-kinflowdev.apps.googleusercontent.com';
    const GoogleIdentityTokens tokens = GoogleIdentityTokens(
      idToken: 'ephemeral-id-token',
      accessToken: 'ephemeral-access-token',
    );
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final _MemorySecureStringStore notificationStore =
        _MemorySecureStringStore();
    final _MemorySecureStringStore guidedStore = _MemorySecureStringStore();
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    final _RecordingGoogleIdentityGateway identityGateway =
        _RecordingGoogleIdentityGateway(
          result: const GoogleIdentityAuthenticated(tokens),
        );
    final _RecordingGoogleTokenExchange tokenExchange =
        _RecordingGoogleTokenExchange();
    addTearDown(initializer.dispose);

    final AuthDependencies dependencies = await createAuthDependencies(
      publicConfigurationFixture(googleWebClientId: clientId),
      secureStringStore: store,
      notificationSecureStringStore: notificationStore,
      guidedChoreSetupSecureStringStore: guidedStore,
      googleIdentityGateway: identityGateway,
      googleTokenExchange: tokenExchange,
      persistentReadCacheEnabled: false,
      runtimeClientBuildReader: const _RuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );

    expect(dependencies.signInLauncher.isAvailable, isTrue);
    expect(
      await dependencies.signInLauncher.requestSignIn(),
      isA<AuthSignInRequestStarted>(),
    );
    expect(identityGateway.authenticateClientIds, <String>[clientId]);
    expect(tokenExchange.tokens, <GoogleIdentityTokens>[tokens]);

    expect(
      await dependencies.localStatePurger.purge(),
      isA<SensitiveLocalStatePurged>(),
    );
    expect(identityGateway.signOutClientIds, <String>[clientId]);
    expect(store.deleteAllCount, 1);
    expect(guidedStore.deleteAllCount, 1);
    expect(notificationStore.deleteAllCount, 0);
  });

  test('web runtime composes email-first safe browser capabilities', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    store.values['opaque-auth-session'] = 'opaque-session-record';
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    final _RecordingGoogleIdentityGateway identityGateway =
        _RecordingGoogleIdentityGateway(
          result: const GoogleIdentityAuthenticationCancelled(),
        );
    addTearDown(initializer.dispose);

    final AuthDependencies dependencies = await createAuthDependencies(
      publicConfigurationFixture(
        googleWebClientId: '1234567890-kinflowdev.apps.googleusercontent.com',
      ),
      isWebRuntime: true,
      secureStringStore: store,
      googleIdentityGateway: identityGateway,
      runtimeClientBuildReader: const _WebRuntimeClientBuildReader(),
      supabaseInitializer: initializer,
    );

    expect(initializer.headers, <String, String>{
      'X-KinFlow-Client-Version': '0.1.0-dev+1',
      'X-KinFlow-Client-Build': '1',
      'X-KinFlow-Contract-Version': '2026-07-25',
      'X-KinFlow-Platform': 'web',
      'X-KinFlow-Environment': 'dev',
    });
    expect(dependencies.emailOtpService.isAvailable, isTrue);
    expect(dependencies.signInLauncher.isAvailable, isFalse);
    expect(identityGateway.authenticateClientIds, isEmpty);
    expect(
      dependencies.guidedChoreSetupResumeStore,
      isA<UnavailableGuidedChoreSetupResumeStore>(),
    );
    expect(
      dependencies.notificationEndpointLifecycle,
      isA<UnavailableNotificationEndpointLifecycle>(),
    );
    expect(dependencies.billingPort, isA<UnavailableBillingPort>());
    expect(
      dependencies.choreCompletionOutbox,
      isA<UnavailableChoreCompletionOutbox>(),
    );
    expect(
      dependencies.todayCalendarSnapshotCache,
      isA<UnavailableTodayCalendarSnapshotCache>(),
    );
    expect(
      dependencies.runtimePolicyExternalLinkLauncher,
      isA<UnavailableRuntimePolicyExternalLinkLauncher>(),
    );

    final PlatformCapabilitySnapshot snapshot = dependencies
        .platformCapabilityRegistry
        .resolve(
          notificationSignal: PlatformNotificationCapabilitySignal.authorized,
        );
    expect(
      snapshot.find(PlatformCapabilityId.notificationDelivery)?.fallback,
      PlatformCapabilityFallback.inAppInboxAndConfiguredEmail,
    );
    expect(
      snapshot.find(PlatformCapabilityId.storeBilling)?.fallback,
      PlatformCapabilityFallback.serverEntitlementReadOnly,
    );
    expect(
      snapshot.find(PlatformCapabilityId.secureLocalStorage)?.fallback,
      PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
    );
    expect(
      snapshot.find(PlatformCapabilityId.externalLinks)?.provider,
      PlatformCapabilityProvider.browserExternalUriLauncher,
    );
    expect(
      snapshot.find(PlatformCapabilityId.backgroundDelivery)?.fallback,
      PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox,
    );

    expect(
      await dependencies.localStatePurger.purge(),
      isA<SensitiveLocalStatePurged>(),
    );
    expect(store.values, isEmpty);
    expect(store.deleteAllCount, 1);
  });

  test(
    'Supabase auth options use secure PKCE and reject deep-link sessions',
    () {
      final _MemorySecureStringStore store = _MemorySecureStringStore();
      final SupabaseSecureAuthStorage storage = SupabaseSecureAuthStorage(
        store,
      );

      final FlutterAuthClientOptions options = secureSupabaseAuthClientOptions(
        localStorage: storage,
        pkceStorage: storage,
      );

      expect(options.authFlowType, AuthFlowType.pkce);
      expect(options.autoRefreshToken, isTrue);
      expect(options.localStorage, same(storage));
      expect(options.pkceAsyncStorage, same(storage));
      expect(options.detectSessionInUri, isFalse);
    },
  );

  test(
    'invalid installed identity fails before Supabase initialization',
    () async {
      for (final RuntimeClientBuildReader reader in <RuntimeClientBuildReader>[
        const _UnavailableRuntimeClientBuildReader(),
        const _MismatchedRuntimeClientBuildReader(),
        const _ThrowingRuntimeClientBuildReader(),
      ]) {
        final _RecordingSupabaseInitializer initializer =
            _RecordingSupabaseInitializer();
        addTearDown(initializer.dispose);

        await expectLater(
          createAuthDependencies(
            publicConfigurationFixture(),
            runtimeClientBuildReader: reader,
            supabaseInitializer: initializer,
          ),
          throwsA(
            isA<RuntimeClientIdentityException>().having(
              (RuntimeClientIdentityException error) => error.toString(),
              'safe description',
              'RuntimeClientIdentityException(invalid_metadata)',
            ),
          ),
        );
        expect(initializer.uri, isNull);
        expect(initializer.headers, isNull);
      }
    },
  );

  test('Android manifest locks backup, links, and build provenance', () async {
    final String manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:name="com.android.vending.BILLING"'));
    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, contains('<intent-filter android:autoVerify="true">'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="\${kinflowAuthRedirectHost}"'));
    expect(manifest, contains('android:pathPrefix="/invite/"'));
    expect(
      manifest,
      contains('android:name="me.newlines.kinflow.SOURCE_COMMIT"'),
    );
    expect(manifest, contains('android:value="\${kinflowSourceCommit}"'));
    expect(
      manifest,
      contains('android:name="me.newlines.kinflow.SOURCE_STATE"'),
    );
    expect(manifest, contains('android:value="\${kinflowSourceState}"'));
  });
}

final class _RecordingSupabaseInitializer implements SupabaseClientInitializer {
  Uri? uri;
  String? publishableKey;
  LocalStorage? localStorage;
  GotrueAsyncStorage? pkceStorage;
  Map<String, String>? headers;
  SupabaseClient? _client;

  @override
  Future<SupabaseClient> initialize({
    required Uri uri,
    required String publishableKey,
    required LocalStorage localStorage,
    required GotrueAsyncStorage pkceStorage,
    required Map<String, String> headers,
  }) async {
    this.uri = uri;
    this.publishableKey = publishableKey;
    this.localStorage = localStorage;
    this.pkceStorage = pkceStorage;
    this.headers = Map<String, String>.unmodifiable(headers);
    return _client = SupabaseClient(uri.toString(), publishableKey);
  }

  Future<void> dispose() async {
    await _client?.dispose();
  }
}

final class _RuntimeClientBuildReader implements RuntimeClientBuildReader {
  const _RuntimeClientBuildReader();

  @override
  Future<RuntimeClientBuild?> read() async {
    return RuntimeClientBuild.tryCreate(
      applicationId: 'me.newlines.kinflow.dev',
      version: '0.1.0-dev',
      buildNumber: '1',
    );
  }
}

final class _WebRuntimeClientBuildReader implements RuntimeClientBuildReader {
  const _WebRuntimeClientBuildReader();

  @override
  Future<RuntimeClientBuild?> read() async {
    return RuntimeClientBuild.tryCreate(
      applicationId: 'kinflow_app',
      version: '0.1.0-dev',
      buildNumber: '1',
    );
  }
}

final class _UnavailableRuntimeClientBuildReader
    implements RuntimeClientBuildReader {
  const _UnavailableRuntimeClientBuildReader();

  @override
  Future<RuntimeClientBuild?> read() async => null;
}

final class _MismatchedRuntimeClientBuildReader
    implements RuntimeClientBuildReader {
  const _MismatchedRuntimeClientBuildReader();

  @override
  Future<RuntimeClientBuild?> read() async {
    return RuntimeClientBuild.tryCreate(
      applicationId: 'me.newlines.kinflow',
      version: '0.1.0',
      buildNumber: '1',
    );
  }
}

final class _ThrowingRuntimeClientBuildReader
    implements RuntimeClientBuildReader {
  const _ThrowingRuntimeClientBuildReader();

  @override
  Future<RuntimeClientBuild?> read() async {
    throw StateError('private package provider detail');
  }
}

final class _MemorySecureStringStore implements SecureStringStore {
  final Map<String, String> values = <String, String>{};
  var deleteAllCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount += 1;
    values.clear();
  }
}

final class _PurgeAwareBillingPort
    implements BillingPort, SensitiveLocalStatePurgeParticipant {
  var purgeCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<BillingClientSnapshot> get snapshots =>
      const Stream<BillingClientSnapshot>.empty();

  @override
  Future<void> purgeSensitiveLocalState() async {
    purgeCount += 1;
  }

  @override
  Future<BillingIdentityResult> bindIdentity(AuthUserId userId) {
    throw UnimplementedError();
  }

  @override
  Future<BillingIdentityClearResult> clearIdentity() {
    throw UnimplementedError();
  }

  @override
  Future<BillingCatalogResult> loadCatalog() {
    throw UnimplementedError();
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<BillingRestoreResult> restore(BillingOperationContext context) {
    throw UnimplementedError();
  }
}

final class _RecordingGoogleIdentityGateway implements GoogleIdentityGateway {
  _RecordingGoogleIdentityGateway({required this.result});

  final GoogleIdentityAuthenticationResult result;
  final List<String> authenticateClientIds = <String>[];
  final List<String> signOutClientIds = <String>[];

  @override
  Future<GoogleIdentityAuthenticationResult> authenticate({
    required String serverClientId,
  }) async {
    authenticateClientIds.add(serverClientId);
    return result;
  }

  @override
  Future<void> signOut({required String serverClientId}) async {
    signOutClientIds.add(serverClientId);
  }
}

final class _RecordingGoogleTokenExchange implements GoogleTokenExchange {
  final List<GoogleIdentityTokens> tokens = <GoogleIdentityTokens>[];

  @override
  Future<GoogleTokenExchangeResult> exchange(
    GoogleIdentityTokens tokens,
  ) async {
    this.tokens.add(tokens);
    return const GoogleTokenExchangeCompleted();
  }
}
