import 'dart:convert';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSecureAuthStorage extends LocalStorage
    implements GotrueAsyncStorage {
  const SupabaseSecureAuthStorage(this._store);

  static const String sessionStorageKey = 'supabase_auth_session_v1';
  static const String _pkceStorageKeyPrefix = 'supabase_auth_pkce_v1_';

  final SecureStringStore _store;

  @override
  Future<void> initialize() {
    return _store.initialize();
  }

  @override
  Future<bool> hasAccessToken() {
    return _store.containsKey(sessionStorageKey);
  }

  @override
  Future<String?> accessToken() {
    return _store.read(sessionStorageKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _store.write(sessionStorageKey, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return _store.delete(sessionStorageKey);
  }

  @override
  Future<String?> getItem({required String key}) {
    return _store.read(_pkceStorageKey(key));
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _store.write(_pkceStorageKey(key), value);
  }

  @override
  Future<void> removeItem({required String key}) {
    return _store.delete(_pkceStorageKey(key));
  }

  Future<void> purge() {
    return _store.deleteAll();
  }

  String _pkceStorageKey(String key) {
    final String encodedKey = base64Url.encode(utf8.encode(key));
    return '$_pkceStorageKeyPrefix$encodedKey';
  }
}

final class SecureAuthStoragePurgeParticipant
    implements SensitiveLocalStatePurgeParticipant {
  const SecureAuthStoragePurgeParticipant(this._storage);

  final SupabaseSecureAuthStorage _storage;

  @override
  Future<void> purgeSensitiveLocalState() {
    return _storage.purge();
  }
}
