import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_repository.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_invite_repository.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_client_initializer.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  test('secure auth options isolate dev and prod with approved ciphers', () {
    final Map<String, String> dev = secureAuthAndroidOptions(
      AppEnvironment.dev,
    ).toMap();
    final Map<String, String> prod = secureAuthAndroidOptions(
      AppEnvironment.prod,
    ).toMap();

    expect(dev['storageNamespace'], 'kinflow_auth_dev_v1');
    expect(prod['storageNamespace'], 'kinflow_auth_prod_v1');
    expect(dev['storageNamespace'], isNot(prod['storageNamespace']));
    expect(dev['resetOnError'], 'true');
    expect(dev['migrateOnAlgorithmChange'], 'true');
    expect(dev['migrateWithBackup'], 'true');
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
    final _RecordingSupabaseInitializer initializer =
        _RecordingSupabaseInitializer();
    addTearDown(initializer.dispose);
    final configuration = publicConfigurationFixture();

    final AuthDependencies dependencies = await createAuthDependencies(
      configuration,
      secureStringStore: store,
      supabaseInitializer: initializer,
    );

    expect(
      dependencies.sessionRepository,
      isA<ProviderAuthSessionRepository>(),
    );
    expect(
      dependencies.householdRepository,
      isA<ProviderHouseholdRepository>(),
    );
    expect(dependencies.inviteRepository, isA<ProviderInviteRepository>());
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

    final SensitiveLocalStatePurgeResult result = await dependencies
        .localStatePurger
        .purge();
    expect(result, isA<SensitiveLocalStatePurged>());
    expect(store.deleteAllCount, 1);
    expect(dependencies.pendingInviteStore.read(), isNull);
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

  test('Android manifest disables OS backup for Keystore ciphertext', () async {
    final String manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('<intent-filter android:autoVerify="true">'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="\${kinflowAuthRedirectHost}"'));
    expect(manifest, contains('android:pathPrefix="/invite/"'));
  });
}

final class _RecordingSupabaseInitializer implements SupabaseClientInitializer {
  Uri? uri;
  String? publishableKey;
  LocalStorage? localStorage;
  GotrueAsyncStorage? pkceStorage;
  SupabaseClient? _client;

  @override
  Future<SupabaseClient> initialize({
    required Uri uri,
    required String publishableKey,
    required LocalStorage localStorage,
    required GotrueAsyncStorage pkceStorage,
  }) async {
    this.uri = uri;
    this.publishableKey = publishableKey;
    this.localStorage = localStorage;
    this.pkceStorage = pkceStorage;
    return _client = SupabaseClient(uri.toString(), publishableKey);
  }

  Future<void> dispose() async {
    await _client?.dispose();
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
