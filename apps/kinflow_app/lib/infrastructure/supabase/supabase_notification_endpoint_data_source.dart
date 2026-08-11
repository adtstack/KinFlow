import 'package:kinflow_app/features/notifications/data/datasources/notification_endpoint_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _endpointStatusKeys = <String>{
  'endpoint_id',
  'household_id',
  'member_id',
  'installation_id',
  'channel',
  'platform',
  'permission_state',
  'locale',
  'timezone',
  'app_version',
  'runtime_version',
  'last_registration_id',
  'last_seen_at',
  'revoked_at',
  'revocation_reason',
  'version',
};
const Set<String> _endpointFunctionKeys = <String>{
  'endpointId',
  'householdId',
  'memberId',
  'installationId',
  'channel',
  'platform',
  'permissionState',
  'locale',
  'timezone',
  'appVersion',
  'runtimeVersion',
  'lastRegistrationId',
  'lastSeenAt',
  'revokedAt',
  'revocationReason',
  'version',
};
const Set<String> _functionEnvelopeKeys = <String>{'data', 'meta'};
const Set<String> _functionMetaKeys = <String>{'contractVersion', 'requestId'};

final class SupabaseNotificationEndpointDataSource
    implements NotificationEndpointDataSource {
  const SupabaseNotificationEndpointDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<NotificationEndpointDataResult<NotificationEndpointDataRecord?>>
  loadStatus({required String installationId}) async {
    try {
      final Object? response = await _client.rpc(
        'get_notification_endpoint_status',
        params: <String, Object?>{
          'p_installation_id': installationId,
          'p_channel': 'native_push',
        },
      );
      final NotificationEndpointDataRecord? record;
      if (response is List<dynamic> && response.isEmpty) {
        record = null;
      } else {
        record = notificationEndpointStatusRecordFromPayload(response);
        if (record == null) {
          return const NotificationEndpointDataFailed<
            NotificationEndpointDataRecord?
          >(NotificationEndpointDataFailureKind.invalidPayload);
        }
      }
      return NotificationEndpointDataSucceeded<NotificationEndpointDataRecord?>(
        record,
      );
    } on PostgrestException catch (error) {
      return NotificationEndpointDataFailed<NotificationEndpointDataRecord?>(
        notificationEndpointDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const NotificationEndpointDataFailed<
        NotificationEndpointDataRecord?
      >(NotificationEndpointDataFailureKind.unauthenticated);
    } on Object {
      return const NotificationEndpointDataFailed<
        NotificationEndpointDataRecord?
      >(NotificationEndpointDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<NotificationEndpointDataResult<NotificationEndpointDataRecord>>
  register({
    required String registrationId,
    required String householdId,
    required String installationId,
    required String platform,
    required String token,
    required String revocationSecret,
    required String? locale,
    required String timezone,
    required String appVersion,
    required String runtimeVersion,
    required int expectedVersion,
  }) async {
    try {
      final Map<String, Object?> body = <String, Object?>{
        'householdId': householdId,
        'installationId': installationId,
        'platform': platform,
        'token': token,
        'revocationSecret': revocationSecret,
        'permissionState': 'granted',
        'timezone': timezone,
        'appVersion': appVersion,
        'runtimeVersion': runtimeVersion,
        'expectedVersion': expectedVersion,
      };
      if (locale != null) body['locale'] = locale;
      final FunctionResponse response = await _client.functions.invoke(
        'notification-endpoint',
        headers: <String, String>{'idempotency-key': registrationId},
        body: body,
      );
      final NotificationEndpointDataRecord? record =
          notificationEndpointFunctionRecordFromEnvelope(response.data);
      return record == null
          ? const NotificationEndpointDataFailed<
              NotificationEndpointDataRecord
            >(NotificationEndpointDataFailureKind.invalidPayload)
          : NotificationEndpointDataSucceeded<NotificationEndpointDataRecord>(
              record,
            );
    } on FunctionException catch (error) {
      return NotificationEndpointDataFailed<NotificationEndpointDataRecord>(
        notificationEndpointDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const NotificationEndpointDataFailed<
        NotificationEndpointDataRecord
      >(NotificationEndpointDataFailureKind.unauthenticated);
    } on Object {
      return const NotificationEndpointDataFailed<
        NotificationEndpointDataRecord
      >(NotificationEndpointDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<NotificationEndpointDataResult<void>> revoke({
    required String installationId,
    required String registrationId,
    required String revocationSecret,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'notification-endpoint',
        method: HttpMethod.delete,
        body: <String, Object?>{
          'installationId': installationId,
          'channel': 'native_push',
          'registrationId': registrationId,
          'revocationSecret': revocationSecret,
        },
      );
      if (!notificationEndpointRevocationEnvelopeIsValid(response.data)) {
        return const NotificationEndpointDataFailed<void>(
          NotificationEndpointDataFailureKind.invalidPayload,
        );
      }
      return const NotificationEndpointDataSucceeded<void>(null);
    } on FunctionException catch (error) {
      return NotificationEndpointDataFailed<void>(
        notificationEndpointDataFailureFromFunctionDetails(error.details),
      );
    } on Object {
      return const NotificationEndpointDataFailed<void>(
        NotificationEndpointDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

NotificationEndpointDataRecord? notificationEndpointStatusRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) return null;
  final Map<String, Object?>? row = _exactMap(
    payload.single,
    _endpointStatusKeys,
  );
  return row == null
      ? null
      : _recordFromMap(
          row,
          endpointIdKey: 'endpoint_id',
          householdIdKey: 'household_id',
          memberIdKey: 'member_id',
          installationIdKey: 'installation_id',
          permissionStateKey: 'permission_state',
          appVersionKey: 'app_version',
          runtimeVersionKey: 'runtime_version',
          registrationIdKey: 'last_registration_id',
          lastSeenAtKey: 'last_seen_at',
          revokedAtKey: 'revoked_at',
          revocationReasonKey: 'revocation_reason',
        );
}

NotificationEndpointDataRecord? notificationEndpointFunctionRecordFromEnvelope(
  Object? payload,
) {
  final Map<String, Object?>? envelope = _functionEnvelope(payload);
  final Map<String, Object?>? row = _exactMap(
    envelope?['data'],
    _endpointFunctionKeys,
  );
  return row == null
      ? null
      : _recordFromMap(
          row,
          endpointIdKey: 'endpointId',
          householdIdKey: 'householdId',
          memberIdKey: 'memberId',
          installationIdKey: 'installationId',
          permissionStateKey: 'permissionState',
          appVersionKey: 'appVersion',
          runtimeVersionKey: 'runtimeVersion',
          registrationIdKey: 'lastRegistrationId',
          lastSeenAtKey: 'lastSeenAt',
          revokedAtKey: 'revokedAt',
          revocationReasonKey: 'revocationReason',
        );
}

bool notificationEndpointRevocationEnvelopeIsValid(Object? payload) {
  final Map<String, Object?>? envelope = _functionEnvelope(payload);
  final Map<String, Object?>? data = _exactMap(
    envelope?['data'],
    const <String>{'revoked'},
  );
  return data?['revoked'] == true;
}

NotificationEndpointDataFailureKind
notificationEndpointDataFailureFromFunctionDetails(Object? details) {
  if (details is! Map) return NotificationEndpointDataFailureKind.unknown;
  final Object? error = details['error'];
  if (error is! Map || error['code'] is! String) {
    return NotificationEndpointDataFailureKind.unknown;
  }
  return switch (error['code']) {
    'AUTH_REQUIRED' => NotificationEndpointDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' || 'IDEMPOTENCY_KEY_REQUIRED' =>
      NotificationEndpointDataFailureKind.invalidInput,
    'PERMISSION_DENIED' => NotificationEndpointDataFailureKind.permissionDenied,
    'NOT_FOUND_OR_FORBIDDEN' =>
      NotificationEndpointDataFailureKind.notFoundOrForbidden,
    'IDEMPOTENCY_KEY_REUSED' =>
      NotificationEndpointDataFailureKind.idempotencyConflict,
    'VERSION_CONFLICT' => NotificationEndpointDataFailureKind.versionConflict,
    'TEMPORARILY_UNAVAILABLE' =>
      NotificationEndpointDataFailureKind.temporarilyUnavailable,
    _ => NotificationEndpointDataFailureKind.unknown,
  };
}

NotificationEndpointDataFailureKind
notificationEndpointDataFailureFromProviderCode(String? code) {
  return switch (code) {
    'KND02' => NotificationEndpointDataFailureKind.unauthenticated,
    'KND01' ||
    '22P02' ||
    '22007' ||
    '23514' => NotificationEndpointDataFailureKind.invalidInput,
    'KND03' ||
    '42501' => NotificationEndpointDataFailureKind.notFoundOrForbidden,
    'KND04' => NotificationEndpointDataFailureKind.idempotencyConflict,
    'KND06' => NotificationEndpointDataFailureKind.versionConflict,
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => NotificationEndpointDataFailureKind.temporarilyUnavailable,
    _ => NotificationEndpointDataFailureKind.unknown,
  };
}

Map<String, Object?>? _functionEnvelope(Object? payload) {
  final Map<String, Object?>? envelope = _exactMap(
    payload,
    _functionEnvelopeKeys,
  );
  final Map<String, Object?>? meta = _exactMap(
    envelope?['meta'],
    _functionMetaKeys,
  );
  if (meta == null ||
      meta['contractVersion'] is! String ||
      (meta['contractVersion']! as String).isEmpty ||
      meta['requestId'] is! String) {
    return null;
  }
  return envelope;
}

NotificationEndpointDataRecord? _recordFromMap(
  Map<String, Object?> row, {
  required String endpointIdKey,
  required String householdIdKey,
  required String memberIdKey,
  required String installationIdKey,
  required String permissionStateKey,
  required String appVersionKey,
  required String runtimeVersionKey,
  required String registrationIdKey,
  required String lastSeenAtKey,
  required String revokedAtKey,
  required String revocationReasonKey,
}) {
  final int? version = _integer(row['version']);
  if (row[endpointIdKey] is! String ||
      row[householdIdKey] is! String ||
      row[memberIdKey] is! String ||
      row[installationIdKey] is! String ||
      row['channel'] is! String ||
      row['platform'] is! String ||
      row[permissionStateKey] is! String ||
      row['locale'] != null && row['locale'] is! String ||
      row['timezone'] is! String ||
      row[appVersionKey] is! String ||
      row[runtimeVersionKey] is! String ||
      row[registrationIdKey] is! String ||
      row[lastSeenAtKey] is! String ||
      row[revokedAtKey] != null && row[revokedAtKey] is! String ||
      row[revocationReasonKey] != null && row[revocationReasonKey] is! String ||
      version == null) {
    return null;
  }
  return NotificationEndpointDataRecord(
    endpointId: row[endpointIdKey]! as String,
    householdId: row[householdIdKey]! as String,
    memberId: row[memberIdKey]! as String,
    installationId: row[installationIdKey]! as String,
    channel: row['channel']! as String,
    platform: row['platform']! as String,
    permissionState: row[permissionStateKey]! as String,
    locale: row['locale'] as String?,
    timezone: row['timezone']! as String,
    appVersion: row[appVersionKey]! as String,
    runtimeVersion: row[runtimeVersionKey]! as String,
    lastRegistrationId: row[registrationIdKey]! as String,
    lastSeenAt: row[lastSeenAtKey]! as String,
    revokedAt: row[revokedAtKey] as String?,
    revocationReason: row[revocationReasonKey] as String?,
    version: version,
  );
}

Map<String, Object?>? _exactMap(Object? value, Set<String> keys) {
  if (value is! Map<dynamic, dynamic>) return null;
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key! as String] = entry.value;
  }
  return result.length == keys.length && result.keys.toSet().containsAll(keys)
      ? result
      : null;
}

int? _integer(Object? value) {
  return value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : null;
}
