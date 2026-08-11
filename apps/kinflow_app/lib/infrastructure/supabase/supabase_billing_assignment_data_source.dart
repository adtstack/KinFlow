import 'package:kinflow_app/features/billing/data/datasources/billing_assignment_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _prepareKeys = <String>{
  'intent_id',
  'outcome',
  'binding_state',
  'assignment_version',
  'intent_expires_at',
  'requeued_job_count',
  'duplicate',
};
const Set<String> _releaseKeys = <String>{
  'outcome',
  'assignment_version',
  'duplicate',
};
const Set<String> _statusKeys = <String>{
  'household_id',
  'assignment_state',
  'ownership_state',
  'owner_membership_state',
  'can_prepare',
  'requires_support',
  'assignment_version',
  'intent_expires_at',
};
const Set<String> _remediationKeys = <String>{
  'request_id',
  'status',
  'issue_kind',
  'duplicate',
};

final class SupabaseBillingAssignmentDataSource
    implements BillingAssignmentDataSource {
  const SupabaseBillingAssignmentDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentPrepareDataRecord>>
  prepare({required String householdId, required String idempotencyKey}) async {
    try {
      final Object? response = await _client.rpc(
        'prepare_billing_household_assignment',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_idempotency_key': idempotencyKey,
        },
      );
      final BillingAssignmentPrepareDataRecord? record =
          billingAssignmentPrepareRecordFromPayload(response);
      return record == null
          ? const BillingAssignmentDataFailed<
              BillingAssignmentPrepareDataRecord
            >(BillingAssignmentDataFailureKind.invalidPayload)
          : BillingAssignmentDataSucceeded<BillingAssignmentPrepareDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return BillingAssignmentDataFailed<BillingAssignmentPrepareDataRecord>(
        billingAssignmentDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const BillingAssignmentDataFailed<
        BillingAssignmentPrepareDataRecord
      >(BillingAssignmentDataFailureKind.unauthenticated);
    } on Object {
      return const BillingAssignmentDataFailed<
        BillingAssignmentPrepareDataRecord
      >(BillingAssignmentDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentReleaseDataRecord>>
  release({
    required String householdId,
    required int expectedAssignmentVersion,
    required String idempotencyKey,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'release_billing_household_assignment',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_expected_assignment_version': expectedAssignmentVersion,
          'p_idempotency_key': idempotencyKey,
        },
      );
      final BillingAssignmentReleaseDataRecord? record =
          billingAssignmentReleaseRecordFromPayload(response);
      return record == null
          ? const BillingAssignmentDataFailed<
              BillingAssignmentReleaseDataRecord
            >(BillingAssignmentDataFailureKind.invalidPayload)
          : BillingAssignmentDataSucceeded<BillingAssignmentReleaseDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return BillingAssignmentDataFailed<BillingAssignmentReleaseDataRecord>(
        billingAssignmentDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const BillingAssignmentDataFailed<
        BillingAssignmentReleaseDataRecord
      >(BillingAssignmentDataFailureKind.unauthenticated);
    } on Object {
      return const BillingAssignmentDataFailed<
        BillingAssignmentReleaseDataRecord
      >(BillingAssignmentDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentStatusDataRecord>>
  status({required String householdId}) async {
    try {
      final Object? response = await _client.rpc(
        'get_billing_household_assignment_status',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final BillingAssignmentStatusDataRecord? record =
          billingAssignmentStatusRecordFromPayload(response);
      return record == null
          ? const BillingAssignmentDataFailed<
              BillingAssignmentStatusDataRecord
            >(BillingAssignmentDataFailureKind.invalidPayload)
          : BillingAssignmentDataSucceeded<BillingAssignmentStatusDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return BillingAssignmentDataFailed<BillingAssignmentStatusDataRecord>(
        billingAssignmentDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const BillingAssignmentDataFailed<
        BillingAssignmentStatusDataRecord
      >(BillingAssignmentDataFailureKind.unauthenticated);
    } on Object {
      return const BillingAssignmentDataFailed<
        BillingAssignmentStatusDataRecord
      >(BillingAssignmentDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentRemediationDataRecord>>
  requestRemediation({
    required String householdId,
    required String issueKind,
    required String idempotencyKey,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'request_billing_assignment_remediation',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_issue_kind': issueKind,
          'p_idempotency_key': idempotencyKey,
        },
      );
      final BillingAssignmentRemediationDataRecord? record =
          billingAssignmentRemediationRecordFromPayload(response);
      return record == null
          ? const BillingAssignmentDataFailed<
              BillingAssignmentRemediationDataRecord
            >(BillingAssignmentDataFailureKind.invalidPayload)
          : BillingAssignmentDataSucceeded<
              BillingAssignmentRemediationDataRecord
            >(record);
    } on PostgrestException catch (error) {
      return BillingAssignmentDataFailed<
        BillingAssignmentRemediationDataRecord
      >(billingAssignmentDataFailureFromProviderCode(error.code));
    } on AuthException {
      return const BillingAssignmentDataFailed<
        BillingAssignmentRemediationDataRecord
      >(BillingAssignmentDataFailureKind.unauthenticated);
    } on Object {
      return const BillingAssignmentDataFailed<
        BillingAssignmentRemediationDataRecord
      >(BillingAssignmentDataFailureKind.temporarilyUnavailable);
    }
  }
}

BillingAssignmentPrepareDataRecord? billingAssignmentPrepareRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _singleExactRow(payload, _prepareKeys);
  final int? version = _nullableInteger(row?['assignment_version']);
  final int? requeued = _integer(row?['requeued_job_count']);
  if (row == null ||
      row['intent_id'] is! String ||
      row['outcome'] is! String ||
      row['binding_state'] != null && row['binding_state'] is! String ||
      row['assignment_version'] != null && version == null ||
      row['intent_expires_at'] != null && row['intent_expires_at'] is! String ||
      requeued == null ||
      row['duplicate'] is! bool) {
    return null;
  }
  return BillingAssignmentPrepareDataRecord(
    intentId: row['intent_id']! as String,
    outcome: row['outcome']! as String,
    bindingState: row['binding_state'] as String?,
    assignmentVersion: version,
    intentExpiresAt: row['intent_expires_at'] as String?,
    requeuedJobCount: requeued,
    duplicate: row['duplicate']! as bool,
  );
}

BillingAssignmentReleaseDataRecord? billingAssignmentReleaseRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _singleExactRow(payload, _releaseKeys);
  final int? version = _nullableInteger(row?['assignment_version']);
  if (row == null ||
      row['outcome'] is! String ||
      row['assignment_version'] != null && version == null ||
      row['duplicate'] is! bool) {
    return null;
  }
  return BillingAssignmentReleaseDataRecord(
    outcome: row['outcome']! as String,
    assignmentVersion: version,
    duplicate: row['duplicate']! as bool,
  );
}

BillingAssignmentStatusDataRecord? billingAssignmentStatusRecordFromPayload(
  Object? payload,
) {
  final Map<String, Object?>? row = _singleExactRow(payload, _statusKeys);
  final int? version = _nullableInteger(row?['assignment_version']);
  if (row == null ||
      row['household_id'] is! String ||
      row['assignment_state'] is! String ||
      row['ownership_state'] is! String ||
      row['owner_membership_state'] is! String ||
      row['can_prepare'] is! bool ||
      row['requires_support'] is! bool ||
      row['assignment_version'] != null && version == null ||
      row['intent_expires_at'] != null && row['intent_expires_at'] is! String) {
    return null;
  }
  return BillingAssignmentStatusDataRecord(
    householdId: row['household_id']! as String,
    assignmentState: row['assignment_state']! as String,
    ownershipState: row['ownership_state']! as String,
    ownerMembershipState: row['owner_membership_state']! as String,
    canPrepare: row['can_prepare']! as bool,
    requiresSupport: row['requires_support']! as bool,
    assignmentVersion: version,
    intentExpiresAt: row['intent_expires_at'] as String?,
  );
}

BillingAssignmentRemediationDataRecord?
billingAssignmentRemediationRecordFromPayload(Object? payload) {
  final Map<String, Object?>? row = _singleExactRow(payload, _remediationKeys);
  if (row == null ||
      row['request_id'] is! String ||
      row['status'] is! String ||
      row['issue_kind'] is! String ||
      row['duplicate'] is! bool) {
    return null;
  }
  return BillingAssignmentRemediationDataRecord(
    requestId: row['request_id']! as String,
    status: row['status']! as String,
    issueKind: row['issue_kind']! as String,
    duplicate: row['duplicate']! as bool,
  );
}

BillingAssignmentDataFailureKind billingAssignmentDataFailureFromProviderCode(
  String? code,
) {
  return switch (code) {
    'PGRST301' => BillingAssignmentDataFailureKind.unauthenticated,
    '22P02' ||
    '22023' ||
    '23514' ||
    'KFB50' => BillingAssignmentDataFailureKind.invalidInput,
    '42501' => BillingAssignmentDataFailureKind.authorization,
    'KFB52' => BillingAssignmentDataFailureKind.versionConflict,
    'KFB51' ||
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => BillingAssignmentDataFailureKind.temporarilyUnavailable,
    _ => BillingAssignmentDataFailureKind.unknown,
  };
}

Map<String, Object?>? _singleExactRow(Object? payload, Set<String> keys) {
  if (payload is! List<dynamic> || payload.length != 1) return null;
  final Object? value = payload.single;
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

int? _nullableInteger(Object? value) {
  return value == null ? null : _integer(value);
}

int? _integer(Object? value) {
  return value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : null;
}
