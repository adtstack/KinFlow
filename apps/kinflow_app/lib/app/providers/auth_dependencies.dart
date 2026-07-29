import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/repositories/unavailable_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_recent_authentication_service.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_member_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_invite_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_household_member_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_invite_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_household_repository.dart';
import 'package:kinflow_app/features/household/data/services/secure_household_command_id_generator.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/data/services/secure_household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/data/services/secure_invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_state_purge_participant.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_recent_authentication_service.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_auth_sign_in_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_session_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_member_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_invite_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';

typedef AuthDependenciesFactory =
    Future<AuthDependencies> Function(AppPublicConfiguration configuration);

final class AuthDependencies {
  const AuthDependencies({
    required this.sessionRepository,
    required this.signInLauncher,
    required this.recentAuthenticationService,
    required this.localStatePurger,
    required this.householdRepository,
    required this.householdMemberRepository,
    required this.householdCommandIdGenerator,
    required this.householdCreationIdGenerator,
    required this.inviteRepository,
    required this.inviteCommandIdGenerator,
    required this.pendingInviteStore,
  });

  final AuthSessionRepository sessionRepository;
  final AuthSignInLauncher signInLauncher;
  final RecentAuthenticationService recentAuthenticationService;
  final SensitiveLocalStatePurger localStatePurger;
  final HouseholdRepository householdRepository;
  final HouseholdMemberRepository householdMemberRepository;
  final HouseholdCommandIdGenerator householdCommandIdGenerator;
  final HouseholdCreationIdGenerator householdCreationIdGenerator;
  final InviteRepository inviteRepository;
  final InviteCommandIdGenerator inviteCommandIdGenerator;
  final PendingInviteStore pendingInviteStore;
}

Future<AuthDependencies> createAuthDependencies(
  AppPublicConfiguration configuration, {
  SecureStringStore? secureStringStore,
  GoogleIdentityGateway? googleIdentityGateway,
  GoogleTokenExchange? googleTokenExchange,
  SupabaseClientInitializer supabaseInitializer =
      const SupabaseFlutterClientInitializer(),
}) async {
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
  );
  final EphemeralPendingInviteStore pendingInviteStore =
      EphemeralPendingInviteStore();
  final List<SensitiveLocalStatePurgeParticipant> purgeParticipants =
      <SensitiveLocalStatePurgeParticipant>[
        SecureAuthStoragePurgeParticipant(authStorage),
        pendingInviteStore,
      ];
  AuthSignInLauncher signInLauncher = createAuthSignInLauncher();
  RecentAuthenticationService recentAuthenticationService =
      const UnavailableRecentAuthenticationService();
  final String? googleWebClientId = configuration.googleWebClientId;
  if (googleWebClientId != null) {
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

  return AuthDependencies(
    sessionRepository: ProviderAuthSessionRepository(
      SupabaseAuthSessionDataSource(client),
    ),
    signInLauncher: signInLauncher,
    recentAuthenticationService: recentAuthenticationService,
    localStatePurger: CompositeSensitiveLocalStatePurger(purgeParticipants),
    householdRepository: ProviderHouseholdRepository(
      SupabaseHouseholdDataSource(client),
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
  );
}

AuthDependencies createUnavailableAuthDependencies() {
  final EphemeralPendingInviteStore pendingInviteStore =
      EphemeralPendingInviteStore();
  return AuthDependencies(
    sessionRepository: createAuthSessionRepository(),
    signInLauncher: createAuthSignInLauncher(),
    recentAuthenticationService: const UnavailableRecentAuthenticationService(),
    localStatePurger: CompositeSensitiveLocalStatePurger(
      <SensitiveLocalStatePurgeParticipant>[pendingInviteStore],
    ),
    householdRepository: const UnavailableHouseholdRepository(),
    householdMemberRepository: const UnavailableHouseholdMemberRepository(),
    householdCommandIdGenerator: SecureHouseholdCommandIdGenerator(),
    householdCreationIdGenerator: SecureHouseholdCreationIdGenerator(),
    inviteRepository: const UnavailableInviteRepository(),
    inviteCommandIdGenerator: SecureInviteCommandIdGenerator(),
    pendingInviteStore: pendingInviteStore,
  );
}

SecureStringStore createSecureAuthStringStore(AppEnvironment environment) {
  return FlutterSecureStringStore(
    FlutterSecureStorage(aOptions: secureAuthAndroidOptions(environment)),
    SupabaseSecureAuthStorage.sessionStorageKey,
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
