import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class FlutterSecureStringStore implements SecureStringStore {
  const FlutterSecureStringStore(this._storage, this._readinessProbeKey);

  final FlutterSecureStorage _storage;
  final String _readinessProbeKey;

  @override
  Future<void> initialize() async {
    await _storage.containsKey(key: _readinessProbeKey);
  }

  @override
  Future<bool> containsKey(String key) {
    return _storage.containsKey(key: key);
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
