import 'package:kinflow_app/features/settings/data/datasources/account_deletion_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _accountDeletionFunctionName = 'account-deletion';
const String _accountDeletionContractVersion = '2026-08-08-wp07-01';
const Set<String> _envelopeKeys = <String>{'data', 'meta'};
const Set<String> _metaKeys = <String>{'requestId', 'contractVersion'};
const Set<String> _preflightKeys = <String>{
  'canRequest',
  'ownerHouseholdCount',
  'hasActiveSubscription',
  'pendingRequestId',
  'pendingStatus',
  'pendingRequestVersion',
  'requestsEnabled',
  'cancellationWindowSeconds',
  'evaluatedAt',
};
const Set<String> _requestKeys = <String>{
  'id',
  'type',
  'status',
  'requestedAt',
  'scheduledFor',
  'processingStartedAt',
  'completedAt',
  'failedAt',
  'cancelledAt',
  'failureCode',
  'activeSubscriptionAtRequest',
  'subscriptionAcknowledged',
  'cancellable',
  'version',
};
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class SupabaseAccountDeletionDataSource
    implements AccountDeletionDataSource {
  const SupabaseAccountDeletionDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<AccountDeletionDataResult<AccountDeletionPreflightDataRecord>>
  preflight() {
    return _invoke<AccountDeletionPreflightDataRecord>(
      body: const <String, Object?>{'operation': 'preflight'},
      parse: accountDeletionPreflightRecordFromPayload,
    );
  }

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord?>> status({
    String? requestId,
  }) async {
    final Map<String, Object?> body = <String, Object?>{'operation': 'status'};
    if (requestId != null) {
      body['requestId'] = requestId;
    }
    try {
      final FunctionResponse response = await _client.functions.invoke(
        _accountDeletionFunctionName,
        body: body,
      );
      final _AccountDeletionEnvelope envelope =
          _accountDeletionEnvelopeFromPayload(response.data);
      if (!envelope.valid) {
        return const AccountDeletionDataFailed<
          AccountDeletionRequestDataRecord?
        >(AccountDeletionDataFailureKind.invalidPayload);
      }
      if (envelope.data == null) {
        return const AccountDeletionDataSucceeded<
          AccountDeletionRequestDataRecord?
        >(null);
      }
      final AccountDeletionRequestDataRecord? record =
          accountDeletionRequestRecordFromPayload(envelope.data);
      return record == null
          ? const AccountDeletionDataFailed<AccountDeletionRequestDataRecord?>(
              AccountDeletionDataFailureKind.invalidPayload,
            )
          : AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord?>(
              record,
            );
    } on FunctionException catch (error) {
      return AccountDeletionDataFailed<AccountDeletionRequestDataRecord?>(
        accountDeletionDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const AccountDeletionDataFailed<AccountDeletionRequestDataRecord?>(
        AccountDeletionDataFailureKind.unauthenticated,
      );
    } on Object {
      return const AccountDeletionDataFailed<AccountDeletionRequestDataRecord?>(
        AccountDeletionDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> request({
    required bool subscriptionAcknowledged,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) {
    return _invoke<AccountDeletionRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'request',
        'subscriptionAcknowledged': subscriptionAcknowledged,
      },
      headers: <String, String>{
        'idempotency-key': idempotencyKey,
        'x-kinflow-recent-auth': recentAuthenticationProof,
      },
      parse: accountDeletionRequestRecordFromPayload,
    );
  }

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    return _invoke<AccountDeletionRequestDataRecord>(
      body: <String, Object?>{
        'operation': 'cancel',
        'requestId': requestId,
        'expectedVersion': expectedVersion,
      },
      headers: <String, String>{'idempotency-key': idempotencyKey},
      parse: accountDeletionRequestRecordFromPayload,
    );
  }

  Future<AccountDeletionDataResult<T>> _invoke<T>({
    required Map<String, Object?> body,
    required T? Function(Object? payload) parse,
    Map<String, String>? headers,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        _accountDeletionFunctionName,
        body: body,
        headers: headers,
      );
      final _AccountDeletionEnvelope envelope =
          _accountDeletionEnvelopeFromPayload(response.data);
      final T? record = envelope.valid ? parse(envelope.data) : null;
      return record == null
          ? AccountDeletionDataFailed<T>(
              AccountDeletionDataFailureKind.invalidPayload,
            )
          : AccountDeletionDataSucceeded<T>(record);
    } on FunctionException catch (error) {
      return AccountDeletionDataFailed<T>(
        accountDeletionDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return AccountDeletionDataFailed<T>(
        AccountDeletionDataFailureKind.unauthenticated,
      );
    } on Object {
      return AccountDeletionDataFailed<T>(
        AccountDeletionDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

AccountDeletionPreflightDataRecord? accountDeletionPreflightRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _preflightKeys);
  if (data == null ||
      data['canRequest'] is! bool ||
      data['ownerHouseholdCount'] is! int ||
      data['hasActiveSubscription'] is! bool ||
      data['pendingRequestId'] != null && data['pendingRequestId'] is! String ||
      data['pendingStatus'] != null && data['pendingStatus'] is! String ||
      data['pendingRequestVersion'] != null &&
          data['pendingRequestVersion'] is! int ||
      data['requestsEnabled'] is! bool ||
      data['cancellationWindowSeconds'] is! int ||
      data['evaluatedAt'] is! String) {
    return null;
  }
  return AccountDeletionPreflightDataRecord(
    canRequest: data['canRequest']! as bool,
    ownerHouseholdCount: data['ownerHouseholdCount']! as int,
    hasActiveSubscription: data['hasActiveSubscription']! as bool,
    pendingRequestId: data['pendingRequestId'] as String?,
    pendingStatus: data['pendingStatus'] as String?,
    pendingRequestVersion: data['pendingRequestVersion'] as int?,
    requestsEnabled: data['requestsEnabled']! as bool,
    cancellationWindowSeconds: data['cancellationWindowSeconds']! as int,
    evaluatedAt: data['evaluatedAt']! as String,
  );
}

AccountDeletionRequestDataRecord? accountDeletionRequestRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? data = _exactMap(payload, _requestKeys);
  if (data == null ||
      data['id'] is! String ||
      data['type'] is! String ||
      data['status'] is! String ||
      data['requestedAt'] is! String ||
      data['scheduledFor'] is! String ||
      !_nullableString(data['processingStartedAt']) ||
      !_nullableString(data['completedAt']) ||
      !_nullableString(data['failedAt']) ||
      !_nullableString(data['cancelledAt']) ||
      !_nullableString(data['failureCode']) ||
      data['activeSubscriptionAtRequest'] is! bool ||
      data['subscriptionAcknowledged'] is! bool ||
      data['cancellable'] is! bool ||
      data['version'] is! int) {
    return null;
  }
  return AccountDeletionRequestDataRecord(
    id: data['id']! as String,
    type: data['type']! as String,
    status: data['status']! as String,
    requestedAt: data['requestedAt']! as String,
    scheduledFor: data['scheduledFor']! as String,
    processingStartedAt: data['processingStartedAt'] as String?,
    completedAt: data['completedAt'] as String?,
    failedAt: data['failedAt'] as String?,
    cancelledAt: data['cancelledAt'] as String?,
    failureCode: data['failureCode'] as String?,
    activeSubscriptionAtRequest: data['activeSubscriptionAtRequest']! as bool,
    subscriptionAcknowledged: data['subscriptionAcknowledged']! as bool,
    cancellable: data['cancellable']! as bool,
    version: data['version']! as int,
  );
}

AccountDeletionDataFailureKind accountDeletionDataFailureFromFunctionDetails(
  Object? details,
) {
  if (details is! Map || details['error'] is! Map) {
    return AccountDeletionDataFailureKind.unknown;
  }
  final Object? code = (details['error']! as Map)['code'];
  return code is String
      ? accountDeletionDataFailureFromCode(code)
      : AccountDeletionDataFailureKind.unknown;
}

AccountDeletionDataFailureKind accountDeletionDataFailureFromCode(
  String? code,
) {
  return switch (code) {
    'AUTH_REQUIRED' ||
    'KFP01' ||
    'KFP13' ||
    'PGRST301' => AccountDeletionDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' ||
    'IDEMPOTENCY_KEY_REQUIRED' ||
    'METHOD_NOT_ALLOWED' ||
    'KFP02' => AccountDeletionDataFailureKind.invalidInput,
    'PERMISSION_DENIED' => AccountDeletionDataFailureKind.permissionDenied,
    'RECENT_AUTH_REQUIRED' =>
      AccountDeletionDataFailureKind.recentAuthenticationRequired,
    'REQUESTS_PAUSED' ||
    'KFP03' => AccountDeletionDataFailureKind.requestsPaused,
    'IDEMPOTENCY_KEY_REUSED' ||
    'KFP04' => AccountDeletionDataFailureKind.idempotencyConflict,
    'PRIVACY_REQUEST_ALREADY_PENDING' ||
    'KFP05' => AccountDeletionDataFailureKind.alreadyPending,
    'NOT_FOUND' || 'KFP06' => AccountDeletionDataFailureKind.notFound,
    'VERSION_CONFLICT' ||
    'KFP07' => AccountDeletionDataFailureKind.versionConflict,
    'OWNER_TRANSFER_REQUIRED' ||
    'KFP08' => AccountDeletionDataFailureKind.ownerTransferRequired,
    'SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED' || 'KFP09' =>
      AccountDeletionDataFailureKind.subscriptionAcknowledgementRequired,
    'REQUEST_NOT_CANCELLABLE' ||
    'KFP10' => AccountDeletionDataFailureKind.notCancellable,
    'TEMPORARILY_UNAVAILABLE' ||
    'INTERNAL_ERROR' ||
    'KFP11' ||
    'KFP12' => AccountDeletionDataFailureKind.temporarilyUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      AccountDeletionDataFailureKind.temporarilyUnavailable,
    _ => AccountDeletionDataFailureKind.unknown,
  };
}

bool accountDeletionEnvelopeHasValidContract(Object? payload) {
  return _accountDeletionEnvelopeFromPayload(payload).valid;
}

_AccountDeletionEnvelope _accountDeletionEnvelopeFromPayload(Object? payload) {
  final Map<String, Object?>? envelope = _exactMap(payload, _envelopeKeys);
  final Map<String, Object?>? meta = _exactMap(envelope?['meta'], _metaKeys);
  if (envelope == null ||
      meta == null ||
      meta['requestId'] is! String ||
      !_uuidPattern.hasMatch(meta['requestId']! as String) ||
      meta['contractVersion'] != _accountDeletionContractVersion) {
    return const _AccountDeletionEnvelope(valid: false, data: null);
  }
  return _AccountDeletionEnvelope(valid: true, data: envelope['data']);
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

final class _AccountDeletionEnvelope {
  const _AccountDeletionEnvelope({required this.valid, required this.data});

  final bool valid;
  final Object? data;
}
