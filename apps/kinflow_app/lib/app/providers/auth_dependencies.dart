import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/repositories/unavailable_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/unavailable_household_repository.dart';
import 'package:kinflow_app/features/household/data/services/secure_household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_session_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';

typedef AuthDependenciesFactory =
    Future<AuthDependencies> Function(AppPublicConfiguration configuration);

final class AuthDependencies {
  const AuthDependencies({
    required this.sessionRepository,
    required this.signInLauncher,
    required this.localStatePurger,
    required this.householdRepository,
    required this.householdCreationIdGenerator,
  });

  final AuthSessionRepository sessionRepository;
  final AuthSignInLauncher signInLauncher;
  final SensitiveLocalStatePurger localStatePurger;
  final HouseholdRepository householdRepository;
  final HouseholdCreationIdGenerator householdCreationIdGenerator;
}

Future<AuthDependencies> createAuthDependencies(
  AppPublicConfiguration configuration, {
  SecureStringStore? secureStringStore,
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

  return AuthDependencies(
    sessionRepository: ProviderAuthSessionRepository(
      SupabaseAuthSessionDataSource(client),
    ),
    signInLauncher: createAuthSignInLauncher(),
    localStatePurger: CompositeSensitiveLocalStatePurger(
      <SensitiveLocalStatePurgeParticipant>[
        SecureAuthStoragePurgeParticipant(authStorage),
      ],
    ),
    householdRepository: ProviderHouseholdRepository(
      SupabaseHouseholdDataSource(client),
    ),
    householdCreationIdGenerator: SecureHouseholdCreationIdGenerator(),
  );
}

AuthDependencies createUnavailableAuthDependencies() {
  return AuthDependencies(
    sessionRepository: createAuthSessionRepository(),
    signInLauncher: createAuthSignInLauncher(),
    localStatePurger: createSensitiveLocalStatePurger(),
    householdRepository: const UnavailableHouseholdRepository(),
    householdCreationIdGenerator: SecureHouseholdCreationIdGenerator(),
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
