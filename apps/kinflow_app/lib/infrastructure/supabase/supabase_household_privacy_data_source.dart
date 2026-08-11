import 'package:kinflow_app/features/settings/data/datasources/household_privacy_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'household-privacy';
const String _contractVersion = '2026-08-08-wp07-02b';
const Set<String> _envelopeKeys = <String>{'data', 'meta'};
const Set<String> _metaKeys = <String>{'requestId', 'contractVersion'};
const Set<String> _preflightKeys = <String>{
  'household',
  'memberCount',
  'activeSubscription',
  'canExport',
  'canDelete',
  'conflictingRequestPending',
  'pendingRequest',
  'exportRequestsEnabled',
  'deletionRequestsEnabled',
  'downloadsEnabled',
  'artifactTtlSeconds',
  'downloadGrantTtlSeconds',
  'deletionCancellationWindowSeconds',
  'retentionBlocked',
  'retentionReviewAt',
  'evaluatedAt',
};
const Set<String> _householdKeys = <String>{'id', 'name', 'version'};
const Set<String> _requestKeys = <String>{
  'requestId',
  'kind',
  'householdId',
  'status',
  'requestedAt',
  'scheduledFor',
  'processingStartedAt',
  'completedAt',
  'failedAt',
  'cancelledAt',
  'failureCode',
  'cancellable',
  'version',
  'activeSubscriptionAtRequest',
  'artifact',
  'deletion',
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
const Set<String> _deletionKeys = <String>{
  'retentionBlocked',
  'retentionReviewAt',
  'accessRevokedAt',
  'redactedAt',
  'billingUnlinkedAt',
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

final class SupabaseHouseholdPrivacyDataSource
    implements HouseholdPrivacyDataSource {
  const SupabaseHouseholdPrivacyDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyPreflightDataRecord>>
  preflight(String householdId) {
    return _invoke<HouseholdPrivacyPreflightDataRecord>(
      body: <String, Object?>{
        'operation': 'preflight',
        'householdId': householdId,
      },
      parse: householdPrivacyPreflightRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> status(
    String requestId,
  ) {
    return _invoke<HouseholdPrivacyRequestDataRecord>(
      body: <String, Object?>{'operation': 'status', 'requestId': requestId},
      parse: householdPrivacyRequestRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestExport({
    required String householdId,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<HouseholdPrivacyRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'requestExport',
        'householdId': householdId,
      },
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: householdPrivacyRequestRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestDeletion({
    required String householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<HouseholdPrivacyRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'requestDeletion',
        'householdId': householdId,
        'expectedHouseholdVersion': expectedHouseholdVersion,
        'confirmationName': confirmationName,
        'acknowledgeMemberAccessLoss': acknowledgeMemberAccessLoss,
        'acknowledgeSharedDataRedaction': acknowledgeSharedDataRedaction,
        'acknowledgeSubscriptionNotCancelled':
            acknowledgeSubscriptionNotCancelled,
      },
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: householdPrivacyRequestRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> cancel({
    required String requestId,
    required String kind,
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    return _invoke<HouseholdPrivacyRequestDataRecord>(
      body: <String, Object?>{
        'operation': kind == 'export' ? 'cancelExport' : 'cancelDeletion',
        'requestId': requestId,
        'expectedVersion': expectedVersion,
      },
      headers: <String, String>{'idempotency-key': idempotencyKey},
      parse: householdPrivacyRequestRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  revokeExport({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<HouseholdPrivacyRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'revokeExport',
        'requestId': requestId,
        'expectedArtifactVersion': expectedArtifactVersion,
      },
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: householdPrivacyRequestRecordFromPayload,
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdExportDownloadDataRecord>>
  download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  }) {
    return _invoke<HouseholdExportDownloadDataRecord>(
      body: <String, Object?>{
        'operation': 'downloadExport',
        'requestId': requestId,
        'format': format,
      },
      headers: <String, String>{
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: householdExportDownloadRecordFromPayload,
    );
  }

  Future<HouseholdPrivacyDataResult<T>> _invoke<T>({
    required Map<String, Object?> body,
    required T? Function(Object? payload) parse,
    Map<String, String>? headers,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        _functionName,
        body: body,
        headers: headers,
      );
      final _HouseholdPrivacyEnvelope envelope = _envelopeFromPayload(
        response.data,
      );
      final T? record = envelope.valid ? parse(envelope.data) : null;
      return record == null
          ? HouseholdPrivacyDataFailed<T>(
              HouseholdPrivacyDataFailureKind.invalidPayload,
            )
          : HouseholdPrivacyDataSucceeded<T>(record);
    } on FunctionException catch (error) {
      return HouseholdPrivacyDataFailed<T>(
        householdPrivacyDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return HouseholdPrivacyDataFailed<T>(
        HouseholdPrivacyDataFailureKind.unauthenticated,
      );
    } on Object {
      return HouseholdPrivacyDataFailed<T>(
        HouseholdPrivacyDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

HouseholdPrivacyPreflightDataRecord? householdPrivacyPreflightRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _preflightKeys);
  final HouseholdPrivacyHouseholdDataRecord? household =
      householdPrivacyHouseholdRecordFromPayload(data?['household']);
  final Object? pendingPayload = data?['pendingRequest'];
  final HouseholdPrivacyRequestDataRecord? pending = pendingPayload == null
      ? null
      : householdPrivacyRequestRecordFromPayload(pendingPayload);
  if (data == null ||
      household == null ||
      pendingPayload != null && pending == null ||
      data['memberCount'] is! int ||
      data['activeSubscription'] is! bool ||
      data['canExport'] is! bool ||
      data['canDelete'] is! bool ||
      data['conflictingRequestPending'] is! bool ||
      data['exportRequestsEnabled'] is! bool ||
      data['deletionRequestsEnabled'] is! bool ||
      data['downloadsEnabled'] is! bool ||
      data['artifactTtlSeconds'] is! int ||
      data['downloadGrantTtlSeconds'] is! int ||
      data['deletionCancellationWindowSeconds'] is! int ||
      data['retentionBlocked'] is! bool ||
      !_nullableString(data['retentionReviewAt']) ||
      data['evaluatedAt'] is! String) {
    return null;
  }
  return HouseholdPrivacyPreflightDataRecord(
    household: household,
    memberCount: data['memberCount']! as int,
    activeSubscription: data['activeSubscription']! as bool,
    canExport: data['canExport']! as bool,
    canDelete: data['canDelete']! as bool,
    conflictingRequestPending: data['conflictingRequestPending']! as bool,
    pendingRequest: pending,
    exportRequestsEnabled: data['exportRequestsEnabled']! as bool,
    deletionRequestsEnabled: data['deletionRequestsEnabled']! as bool,
    downloadsEnabled: data['downloadsEnabled']! as bool,
    artifactTtlSeconds: data['artifactTtlSeconds']! as int,
    downloadGrantTtlSeconds: data['downloadGrantTtlSeconds']! as int,
    deletionCancellationWindowSeconds:
        data['deletionCancellationWindowSeconds']! as int,
    retentionBlocked: data['retentionBlocked']! as bool,
    retentionReviewAt: data['retentionReviewAt'] as String?,
    evaluatedAt: data['evaluatedAt']! as String,
  );
}

HouseholdPrivacyHouseholdDataRecord? householdPrivacyHouseholdRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _householdKeys);
  if (data == null ||
      data['id'] is! String ||
      data['name'] is! String ||
      data['version'] is! int) {
    return null;
  }
  return HouseholdPrivacyHouseholdDataRecord(
    id: data['id']! as String,
    name: data['name']! as String,
    version: data['version']! as int,
  );
}

HouseholdPrivacyRequestDataRecord? householdPrivacyRequestRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _requestKeys);
  final Object? artifactPayload = data?['artifact'];
  final Object? deletionPayload = data?['deletion'];
  final HouseholdExportArtifactDataRecord? artifact = artifactPayload == null
      ? null
      : householdExportArtifactRecordFromPayload(artifactPayload);
  final HouseholdDeletionProgressDataRecord? deletion = deletionPayload == null
      ? null
      : householdDeletionProgressRecordFromPayload(deletionPayload);
  if (data == null ||
      artifactPayload != null && artifact == null ||
      deletionPayload != null && deletion == null ||
      data['requestId'] is! String ||
      data['kind'] is! String ||
      data['householdId'] is! String ||
      data['status'] is! String ||
      data['requestedAt'] is! String ||
      data['scheduledFor'] is! String ||
      !_nullableString(data['processingStartedAt']) ||
      !_nullableString(data['completedAt']) ||
      !_nullableString(data['failedAt']) ||
      !_nullableString(data['cancelledAt']) ||
      !_nullableString(data['failureCode']) ||
      data['cancellable'] is! bool ||
      data['version'] is! int ||
      data['activeSubscriptionAtRequest'] is! bool) {
    return null;
  }
  return HouseholdPrivacyRequestDataRecord(
    requestId: data['requestId']! as String,
    kind: data['kind']! as String,
    householdId: data['householdId']! as String,
    status: data['status']! as String,
    requestedAt: data['requestedAt']! as String,
    scheduledFor: data['scheduledFor']! as String,
    processingStartedAt: data['processingStartedAt'] as String?,
    completedAt: data['completedAt'] as String?,
    failedAt: data['failedAt'] as String?,
    cancelledAt: data['cancelledAt'] as String?,
    failureCode: data['failureCode'] as String?,
    cancellable: data['cancellable']! as bool,
    version: data['version']! as int,
    activeSubscriptionAtRequest: data['activeSubscriptionAtRequest']! as bool,
    artifact: artifact,
    deletion: deletion,
  );
}

HouseholdExportArtifactDataRecord? householdExportArtifactRecordFromPayload(
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
  return HouseholdExportArtifactDataRecord(
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

HouseholdDeletionProgressDataRecord? householdDeletionProgressRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _deletionKeys);
  if (data == null ||
      data['retentionBlocked'] is! bool ||
      !_nullableString(data['retentionReviewAt']) ||
      !_nullableString(data['accessRevokedAt']) ||
      !_nullableString(data['redactedAt']) ||
      !_nullableString(data['billingUnlinkedAt'])) {
    return null;
  }
  return HouseholdDeletionProgressDataRecord(
    retentionBlocked: data['retentionBlocked']! as bool,
    retentionReviewAt: data['retentionReviewAt'] as String?,
    accessRevokedAt: data['accessRevokedAt'] as String?,
    redactedAt: data['redactedAt'] as String?,
    billingUnlinkedAt: data['billingUnlinkedAt'] as String?,
  );
}

HouseholdExportDownloadDataRecord? householdExportDownloadRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _downloadKeys);
  if (data == null ||
      data['format'] is! String ||
      data['expiresAt'] is! String ||
      data['downloadUrl'] is! String) {
    return null;
  }
  return HouseholdExportDownloadDataRecord(
    format: data['format']! as String,
    expiresAt: data['expiresAt']! as String,
    downloadUrl: data['downloadUrl']! as String,
  );
}

HouseholdPrivacyDataFailureKind householdPrivacyDataFailureFromFunctionDetails(
  Object? details,
) {
  if (details is! Map || details['error'] is! Map) {
    return HouseholdPrivacyDataFailureKind.unknown;
  }
  final Object? code = (details['error']! as Map)['code'];
  return code is String
      ? householdPrivacyDataFailureFromCode(code)
      : HouseholdPrivacyDataFailureKind.unknown;
}

HouseholdPrivacyDataFailureKind householdPrivacyDataFailureFromCode(
  String? code,
) {
  return switch (code) {
    'AUTH_REQUIRED' ||
    'KHP01' ||
    'PGRST301' => HouseholdPrivacyDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' ||
    'IDEMPOTENCY_KEY_REQUIRED' ||
    'METHOD_NOT_ALLOWED' ||
    'KHP02' => HouseholdPrivacyDataFailureKind.invalidInput,
    'OWNER_REQUIRED' ||
    'KHP03' => HouseholdPrivacyDataFailureKind.ownerRequired,
    'RECENT_AUTH_REQUIRED' =>
      HouseholdPrivacyDataFailureKind.recentAuthenticationRequired,
    'EXPORT_REQUESTS_PAUSED' ||
    'KHP09' => HouseholdPrivacyDataFailureKind.exportRequestsPaused,
    'DELETION_REQUESTS_PAUSED' ||
    'KHP12' => HouseholdPrivacyDataFailureKind.deletionRequestsPaused,
    'DOWNLOADS_PAUSED' ||
    'KHP14' => HouseholdPrivacyDataFailureKind.downloadsPaused,
    'IDEMPOTENCY_KEY_REUSED' ||
    'KHP04' => HouseholdPrivacyDataFailureKind.idempotencyConflict,
    'PRIVACY_REQUEST_ALREADY_PENDING' ||
    'KHP05' => HouseholdPrivacyDataFailureKind.alreadyPending,
    'NOT_FOUND' || 'KHP06' => HouseholdPrivacyDataFailureKind.notFound,
    'VERSION_CONFLICT' ||
    'KHP07' => HouseholdPrivacyDataFailureKind.versionConflict,
    'REQUEST_NOT_MUTABLE' ||
    'KHP08' => HouseholdPrivacyDataFailureKind.requestNotMutable,
    'CONFIRMATION_MISMATCH' ||
    'KHP10' => HouseholdPrivacyDataFailureKind.confirmationMismatch,
    'SUBSCRIPTION_ACK_REQUIRED' || 'KHP11' =>
      HouseholdPrivacyDataFailureKind.subscriptionAcknowledgmentRequired,
    'ARTIFACT_UNAVAILABLE' ||
    'KHP13' ||
    'KHP15' => HouseholdPrivacyDataFailureKind.artifactUnavailable,
    'HOUSEHOLD_ALREADY_DELETED' ||
    'KHP17' => HouseholdPrivacyDataFailureKind.householdAlreadyDeleted,
    'TEMPORARILY_UNAVAILABLE' ||
    'INTERNAL_ERROR' ||
    'KHP16' => HouseholdPrivacyDataFailureKind.temporarilyUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      HouseholdPrivacyDataFailureKind.temporarilyUnavailable,
    _ => HouseholdPrivacyDataFailureKind.unknown,
  };
}

bool householdPrivacyEnvelopeHasValidContract(Object? payload) =>
    _envelopeFromPayload(payload).valid;

_HouseholdPrivacyEnvelope _envelopeFromPayload(Object? payload) {
  final Map<String, Object?>? envelope = _exactMap(payload, _envelopeKeys);
  final Map<String, Object?>? meta = _exactMap(envelope?['meta'], _metaKeys);
  if (envelope == null ||
      meta == null ||
      meta['requestId'] is! String ||
      !_uuidPattern.hasMatch(meta['requestId']! as String) ||
      meta['contractVersion'] != _contractVersion) {
    return const _HouseholdPrivacyEnvelope(valid: false, data: null);
  }
  return _HouseholdPrivacyEnvelope(valid: true, data: envelope['data']);
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

final class _HouseholdPrivacyEnvelope {
  const _HouseholdPrivacyEnvelope({required this.valid, required this.data});

  final bool valid;
  final Object? data;
}
