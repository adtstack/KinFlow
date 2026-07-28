import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/repositories/unavailable_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_session_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';

typedef AuthDependenciesFactory =
    Future<AuthDependencies> Function(AppPublicConfiguration configuration);

final class AuthDependencies {
  const AuthDependencies({
    required this.sessionRepository,
    required this.signInLauncher,
    required this.localStatePurger,
  });

  final AuthSessionRepository sessionRepository;
  final AuthSignInLauncher signInLauncher;
  final SensitiveLocalStatePurger localStatePurger;
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
  );
}

AuthDependencies createUnavailableAuthDependencies() {
  return AuthDependencies(
    sessionRepository: createAuthSessionRepository(),
    signInLauncher: createAuthSignInLauncher(),
    localStatePurger: createSensitiveLocalStatePurger(),
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
