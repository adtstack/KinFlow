abstract interface class FoundationStatusDataSource {
  Future<Map<String, Object?>> loadStatus();
}

final class LocalFoundationStatusDataSource
    implements FoundationStatusDataSource {
  const LocalFoundationStatusDataSource();

  @override
  Future<Map<String, Object?>> loadStatus() {
    return Future<Map<String, Object?>>.value(const <String, Object?>{
      'sample_id': 'local-foundation',
      'status': 'ready',
    });
  }
}
