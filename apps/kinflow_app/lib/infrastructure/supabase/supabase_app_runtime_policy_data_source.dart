import 'package:kinflow_app/features/runtime_policy/data/datasources/app_runtime_policy_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAppRuntimePolicyDataSource
    implements AppRuntimePolicyDataSource {
  const SupabaseAppRuntimePolicyDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, Object?>> fetch({
    required String environment,
    required String platform,
  }) async {
    final Object? payload = await _client.rpc<Object?>(
      'get_app_runtime_policy',
      params: <String, Object?>{
        'p_environment': environment,
        'p_platform': platform,
      },
    );
    final Map<String, Object?>? record = appRuntimePolicyRecordFromPayload(
      payload,
    );
    if (record == null) {
      throw const FormatException('invalid runtime policy response');
    }
    return record;
  }

  @override
  Future<List<Map<String, Object?>>> fetchFeatures({
    required String environment,
    required String platform,
  }) async {
    final Object? payload = await _client.rpc<Object?>(
      'get_app_runtime_feature_policies',
      params: <String, Object?>{
        'p_environment': environment,
        'p_platform': platform,
      },
    );
    final List<Map<String, Object?>>? records =
        appRuntimePolicyRecordsFromPayload(payload);
    if (records == null) {
      throw const FormatException('invalid runtime feature policy response');
    }
    return records;
  }
}

Map<String, Object?>? appRuntimePolicyRecordFromPayload(Object? payload) {
  if (payload is! List<Object?> || payload.length != 1) {
    return null;
  }
  final Object? row = payload.single;
  if (row is! Map<Object?, Object?> ||
      row.keys.any((Object? key) => key is! String)) {
    return null;
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in row.entries)
      entry.key! as String: entry.value,
  };
}

List<Map<String, Object?>>? appRuntimePolicyRecordsFromPayload(
  Object? payload,
) {
  if (payload is! List<Object?>) return null;
  final List<Map<String, Object?>> records = <Map<String, Object?>>[];
  for (final Object? row in payload) {
    if (row is! Map<Object?, Object?> ||
        row.keys.any((Object? key) => key is! String)) {
      return null;
    }
    records.add(<String, Object?>{
      for (final MapEntry<Object?, Object?> entry in row.entries)
        entry.key! as String: entry.value,
    });
  }
  return List<Map<String, Object?>>.unmodifiable(records);
}
