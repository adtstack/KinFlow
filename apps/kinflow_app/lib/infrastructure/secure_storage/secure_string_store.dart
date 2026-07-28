abstract interface class SecureStringStore {
  Future<void> initialize();

  Future<bool> containsKey(String key);

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> deleteAll();
}
