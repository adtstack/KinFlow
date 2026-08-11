abstract interface class AppRuntimePolicyDataSource {
  Future<Map<String, Object?>> fetch({
    required String environment,
    required String platform,
  });

  Future<List<Map<String, Object?>>> fetchFeatures({
    required String environment,
    required String platform,
  });
}
