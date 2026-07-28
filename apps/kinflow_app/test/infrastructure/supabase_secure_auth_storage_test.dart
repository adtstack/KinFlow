import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_secure_auth_storage.dart';

void main() {
  test('persists and removes the Supabase session in secure storage', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final SupabaseSecureAuthStorage storage = SupabaseSecureAuthStorage(store);

    await storage.initialize();
    expect(store.initializeCount, 1);
    expect(await storage.hasAccessToken(), isFalse);

    await storage.persistSession('opaque-session-fixture');

    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), 'opaque-session-fixture');
    expect(
      store.values.keys,
      contains(SupabaseSecureAuthStorage.sessionStorageKey),
    );

    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('isolates PKCE verifier keys from the provider key', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final SupabaseSecureAuthStorage storage = SupabaseSecureAuthStorage(store);

    await storage.setItem(
      key: 'provider-code-verifier',
      value: 'opaque-verifier-fixture',
    );

    expect(
      await storage.getItem(key: 'provider-code-verifier'),
      'opaque-verifier-fixture',
    );
    expect(store.values.keys, isNot(contains('provider-code-verifier')));
    expect(store.values.keys.single, startsWith('supabase_auth_pkce_v1_'));

    await storage.removeItem(key: 'provider-code-verifier');
    expect(store.values, isEmpty);
  });

  test('purge participant clears the complete auth namespace', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final SupabaseSecureAuthStorage storage = SupabaseSecureAuthStorage(store);
    final SecureAuthStoragePurgeParticipant participant =
        SecureAuthStoragePurgeParticipant(storage);
    await storage.persistSession('opaque-session-fixture');
    await storage.setItem(
      key: 'provider-code-verifier',
      value: 'opaque-verifier-fixture',
    );

    await participant.purgeSensitiveLocalState();

    expect(store.deleteAllCount, 1);
    expect(store.values, isEmpty);
  });

  test('storage readiness failure propagates without fallback persistence', () {
    final SupabaseSecureAuthStorage storage = SupabaseSecureAuthStorage(
      _MemorySecureStringStore(failInitialization: true),
    );

    expect(storage.initialize, throwsStateError);
  });
}

final class _MemorySecureStringStore implements SecureStringStore {
  _MemorySecureStringStore({this.failInitialization = false});

  final bool failInitialization;
  final Map<String, String> values = <String, String>{};
  var initializeCount = 0;
  var deleteAllCount = 0;

  @override
  Future<void> initialize() async {
    initializeCount += 1;
    if (failInitialization) {
      throw StateError('secure storage unavailable');
    }
  }

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
