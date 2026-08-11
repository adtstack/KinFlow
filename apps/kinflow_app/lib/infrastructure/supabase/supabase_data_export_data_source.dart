import 'package:kinflow_app/features/settings/data/datasources/data_export_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _dataExportFunctionName = 'data-export';
const String _dataExportContractVersion = '2026-08-08-wp07-02a';
const Set<String> _envelopeKeys = <String>{'data', 'meta'};
const Set<String> _metaKeys = <String>{'requestId', 'contractVersion'};
const Set<String> _preflightKeys = <String>{
  'canRequest',
  'pendingRequestId',
  'pendingStatus',
  'pendingRequestVersion',
  'conflictingRequestPending',
  'requestsEnabled',
  'downloadsEnabled',
  'artifactTtlSeconds',
  'downloadGrantTtlSeconds',
  'evaluatedAt',
};
const Set<String> _requestKeys = <String>{
  'id',
  'status',
  'requestedAt',
  'processingStartedAt',
  'completedAt',
  'failedAt',
  'cancelledAt',
  'failureCode',
  'cancellable',
  'version',
  'artifact',
};
const Set<String> _artifactKeys = <String>{
  'id',
  'version',
  'schemaVersion',
  'expiresAt',
  'revokedAt',
  'purgedAt',
  'machineSizeBytes',
  'humanSizeBytes',
  'available',
};
const Set<String> _downloadKeys = <String>{
  'format',
  'expiresAt',
  'downloadUrl',
};
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class SupabaseDataExportDataSource implements DataExportDataSource {
  const SupabaseDataExportDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<DataExportDataResult<DataExportPreflightDataRecord>> preflight() {
    return _invoke<DataExportPreflightDataRecord>(
      body: const <String, Object?>{'operation': 'preflight'},
      parse: dataExportPreflightRecordFromPayload,
    );
  }

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord?>> status({
    String? requestId,
  }) async {
    final Map<String, Object?> body = <String, Object?>{'operation': 'status'};
    if (requestId != null) {
      body['requestId'] = requestId;
    }
    try {
      final FunctionResponse response = await _client.functions.invoke(
        _dataExportFunctionName,
        body: body,
      );
      final _DataExportEnvelope envelope = _envelopeFromPayload(response.data);
      if (!envelope.valid) {
        return const DataExportDataFailed<DataExportRequestDataRecord?>(
          DataExportDataFailureKind.invalidPayload,
        );
      }
      if (envelope.data == null) {
        return const DataExportDataSucceeded<DataExportRequestDataRecord?>(
          null,
        );
      }
      final DataExportRequestDataRecord? record =
          dataExportRequestRecordFromPayload(envelope.data);
      return record == null
          ? const DataExportDataFailed<DataExportRequestDataRecord?>(
              DataExportDataFailureKind.invalidPayload,
            )
          : DataExportDataSucceeded<DataExportRequestDataRecord?>(record);
    } on FunctionException catch (error) {
      return DataExportDataFailed<DataExportRequestDataRecord?>(
        dataExportDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const DataExportDataFailed<DataExportRequestDataRecord?>(
        DataExportDataFailureKind.unauthenticated,
      );
    } on Object {
      return const DataExportDataFailed<DataExportRequestDataRecord?>(
        DataExportDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> request({
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<DataExportRequestDataRecord>(
      body: const <String, Object?>{'operation': 'request'},
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: dataExportRequestRecordFromPayload,
    );
  }

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    return _invoke<DataExportRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'cancel',
        'requestId': requestId,
        'expectedVersion': expectedVersion,
      },
      headers: <String, String>{'idempotency-key': idempotencyKey},
      parse: dataExportRequestRecordFromPayload,
    );
  }

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> revoke({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<DataExportRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'revoke',
        'requestId': requestId,
        'expectedArtifactVersion': expectedArtifactVersion,
      },
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: dataExportRequestRecordFromPayload,
    );
  }

  @override
  Future<DataExportDataResult<DataExportDownloadDataRecord>> download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  }) {
    return _invoke<DataExportDownloadDataRecord>(
      body: <String, Object?>{
        'operation': 'download',
        'requestId': requestId,
        'format': format,
      },
      headers: <String, String>{
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: dataExportDownloadRecordFromPayload,
    );
  }

  Future<DataExportDataResult<T>> _invoke<T>({
    required Map<String, Object?> body,
    required T? Function(Object? payload) parse,
    Map<String, String>? headers,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        _dataExportFunctionName,
        body: body,
        headers: headers,
      );
      final _DataExportEnvelope envelope = _envelopeFromPayload(response.data);
      final T? record = envelope.valid ? parse(envelope.data) : null;
      return record == null
          ? DataExportDataFailed<T>(DataExportDataFailureKind.invalidPayload)
          : DataExportDataSucceeded<T>(record);
    } on FunctionException catch (error) {
      return DataExportDataFailed<T>(
        dataExportDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return DataExportDataFailed<T>(DataExportDataFailureKind.unauthenticated);
    } on Object {
      return DataExportDataFailed<T>(
        DataExportDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

DataExportPreflightDataRecord? dataExportPreflightRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _preflightKeys);
  if (data == null ||
      data['canRequest'] is! bool ||
      !_nullableString(data['pendingRequestId']) ||
      !_nullableString(data['pendingStatus']) ||
      !_nullableInt(data['pendingRequestVersion']) ||
      data['conflictingRequestPending'] is! bool ||
      data['requestsEnabled'] is! bool ||
      data['downloadsEnabled'] is! bool ||
      data['artifactTtlSeconds'] is! int ||
      data['downloadGrantTtlSeconds'] is! int ||
      data['evaluatedAt'] is! String) {
    return null;
  }
  return DataExportPreflightDataRecord(
    canRequest: data['canRequest']! as bool,
    pendingRequestId: data['pendingRequestId'] as String?,
    pendingStatus: data['pendingStatus'] as String?,
    pendingRequestVersion: data['pendingRequestVersion'] as int?,
    conflictingRequestPending: data['conflictingRequestPending']! as bool,
    requestsEnabled: data['requestsEnabled']! as bool,
    downloadsEnabled: data['downloadsEnabled']! as bool,
    artifactTtlSeconds: data['artifactTtlSeconds']! as int,
    downloadGrantTtlSeconds: data['downloadGrantTtlSeconds']! as int,
    evaluatedAt: data['evaluatedAt']! as String,
  );
}

DataExportRequestDataRecord? dataExportRequestRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _requestKeys);
  final DataExportArtifactDataRecord? artifact =
      dataExportArtifactRecordFromPayload(data?['artifact']);
  if (data == null ||
      artifact == null ||
      data['id'] is! String ||
      data['status'] is! String ||
      data['requestedAt'] is! String ||
      !_nullableString(data['processingStartedAt']) ||
      !_nullableString(data['completedAt']) ||
      !_nullableString(data['failedAt']) ||
      !_nullableString(data['cancelledAt']) ||
      !_nullableString(data['failureCode']) ||
      data['cancellable'] is! bool ||
      data['version'] is! int) {
    return null;
  }
  return DataExportRequestDataRecord(
    id: data['id']! as String,
    status: data['status']! as String,
    requestedAt: data['requestedAt']! as String,
    processingStartedAt: data['processingStartedAt'] as String?,
    completedAt: data['completedAt'] as String?,
    failedAt: data['failedAt'] as String?,
    cancelledAt: data['cancelledAt'] as String?,
    failureCode: data['failureCode'] as String?,
    cancellable: data['cancellable']! as bool,
    version: data['version']! as int,
    artifact: artifact,
  );
}

DataExportArtifactDataRecord? dataExportArtifactRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _artifactKeys);
  if (data == null ||
      data['id'] is! String ||
      data['version'] is! int ||
      data['schemaVersion'] is! String ||
      !_nullableString(data['expiresAt']) ||
      !_nullableString(data['revokedAt']) ||
      !_nullableString(data['purgedAt']) ||
      !_nullableInt(data['machineSizeBytes']) ||
      !_nullableInt(data['humanSizeBytes']) ||
      data['available'] is! bool) {
    return null;
  }
  return DataExportArtifactDataRecord(
    id: data['id']! as String,
    version: data['version']! as int,
    schemaVersion: data['schemaVersion']! as String,
    expiresAt: data['expiresAt'] as String?,
    revokedAt: data['revokedAt'] as String?,
    purgedAt: data['purgedAt'] as String?,
    machineSizeBytes: data['machineSizeBytes'] as int?,
    humanSizeBytes: data['humanSizeBytes'] as int?,
    available: data['available']! as bool,
  );
}

DataExportDownloadDataRecord? dataExportDownloadRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _downloadKeys);
  if (data == null ||
      data['format'] is! String ||
      data['expiresAt'] is! String ||
      data['downloadUrl'] is! String) {
    return null;
  }
  return DataExportDownloadDataRecord(
    format: data['format']! as String,
    expiresAt: data['expiresAt']! as String,
    downloadUrl: data['downloadUrl']! as String,
  );
}

DataExportDataFailureKind dataExportDataFailureFromFunctionDetails(
  Object? details,
) {
  if (details is! Map || details['error'] is! Map) {
    return DataExportDataFailureKind.unknown;
  }
  final Object? code = (details['error']! as Map)['code'];
  return code is String
      ? dataExportDataFailureFromCode(code)
      : DataExportDataFailureKind.unknown;
}

DataExportDataFailureKind dataExportDataFailureFromCode(String? code) {
  return switch (code) {
    'AUTH_REQUIRED' ||
    'KFX01' ||
    'PGRST301' => DataExportDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' ||
    'IDEMPOTENCY_KEY_REQUIRED' ||
    'METHOD_NOT_ALLOWED' ||
    'KFX02' => DataExportDataFailureKind.invalidInput,
    'PERMISSION_DENIED' => DataExportDataFailureKind.permissionDenied,
    'RECENT_AUTH_REQUIRED' =>
      DataExportDataFailureKind.recentAuthenticationRequired,
    'REQUESTS_PAUSED' || 'KFX03' => DataExportDataFailureKind.requestsPaused,
    'DOWNLOADS_PAUSED' || 'KFX10' => DataExportDataFailureKind.downloadsPaused,
    'IDEMPOTENCY_KEY_REUSED' ||
    'KFX04' => DataExportDataFailureKind.idempotencyConflict,
    'PRIVACY_REQUEST_ALREADY_PENDING' ||
    'KFX05' => DataExportDataFailureKind.alreadyPending,
    'NOT_FOUND' || 'KFX06' => DataExportDataFailureKind.notFound,
    'VERSION_CONFLICT' || 'KFX07' => DataExportDataFailureKind.versionConflict,
    'REQUEST_NOT_CANCELLABLE' ||
    'KFX08' => DataExportDataFailureKind.notCancellable,
    'ARTIFACT_UNAVAILABLE' ||
    'DOWNLOAD_GRANT_INVALID' ||
    'KFX11' ||
    'KFX12' => DataExportDataFailureKind.artifactUnavailable,
    'EXPORT_TOO_LARGE' || 'KFX14' => DataExportDataFailureKind.exportTooLarge,
    'TEMPORARILY_UNAVAILABLE' ||
    'INTERNAL_ERROR' ||
    'KFX13' ||
    'KFX15' => DataExportDataFailureKind.temporarilyUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      DataExportDataFailureKind.temporarilyUnavailable,
    _ => DataExportDataFailureKind.unknown,
  };
}

bool dataExportEnvelopeHasValidContract(Object? payload) {
  return _envelopeFromPayload(payload).valid;
}

_DataExportEnvelope _envelopeFromPayload(Object? payload) {
  final Map<String, Object?>? envelope = _exactMap(payload, _envelopeKeys);
  final Map<String, Object?>? meta = _exactMap(envelope?['meta'], _metaKeys);
  if (envelope == null ||
      meta == null ||
      meta['requestId'] is! String ||
      !_uuidPattern.hasMatch(meta['requestId']! as String) ||
      meta['contractVersion'] != _dataExportContractVersion) {
    return const _DataExportEnvelope(valid: false, data: null);
  }
  return _DataExportEnvelope(valid: true, data: envelope['data']);
}

Map<String, Object?>? _exactMap(Object? payload, Set<String> expectedKeys) {
  if (payload is! Map) {
    return null;
  }
  final Map<String, Object?> value;
  try {
    value = Map<String, Object?>.from(payload);
  } on Object {
    return null;
  }
  if (value.length != expectedKeys.length ||
      !value.keys.every(expectedKeys.contains)) {
    return null;
  }
  return value;
}

bool _nullableString(Object? value) => value == null || value is String;

bool _nullableInt(Object? value) => value == null || value is int;

final class _DataExportEnvelope {
  const _DataExportEnvelope({required this.valid, required this.data});

  final bool valid;
  final Object? data;
}
