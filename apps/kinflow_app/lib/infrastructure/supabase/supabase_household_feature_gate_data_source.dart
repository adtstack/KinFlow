import 'package:kinflow_app/features/billing/data/datasources/household_feature_gate_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _featureGateKeys = <String>{
  'decision',
  'household_id',
  'feature_key',
  'requested_delta',
  'current_usage',
  'limit_value',
  'remaining_after_delta',
  'plan_code',
  'entitlement_status',
  'enforcement_enabled',
  'limits_finalized',
  'entitlement_version',
  'policy_version',
  'runtime_version',
  'evaluated_at',
};

final class SupabaseHouseholdFeatureGateDataSource
    implements HouseholdFeatureGateDataSource {
  const SupabaseHouseholdFeatureGateDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<HouseholdFeatureGateDataResult> evaluate({
    required String householdId,
    required String featureKey,
    required int requestedDelta,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_household_feature_gate',
        params: <String, Object?>{
          'p_household_id': householdId,
          'p_feature_key': featureKey,
          'p_requested_delta': requestedDelta,
        },
      );
      final HouseholdFeatureGateDataRecord? record =
          householdFeatureGateRecordFromPayload(response);
      return record == null
          ? const HouseholdFeatureGateDataFailed(
              HouseholdFeatureGateDataFailureKind.invalidPayload,
            )
          : HouseholdFeatureGateDataSucceeded(record);
    } on PostgrestException catch (error) {
      return HouseholdFeatureGateDataFailed(
        householdFeatureGateDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const HouseholdFeatureGateDataFailed(
        HouseholdFeatureGateDataFailureKind.unauthenticated,
      );
    } on Object {
      return const HouseholdFeatureGateDataFailed(
        HouseholdFeatureGateDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

HouseholdFeatureGateDataRecord? householdFeatureGateRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) return null;
  final Map<String, Object?>? row = _exactMap(payload.single, _featureGateKeys);
  final int? requestedDelta = _integer(row?['requested_delta']);
  final int? currentUsage = _integer(row?['current_usage']);
  final int? limitValue = _nullableInteger(row?['limit_value']);
  final int? remainingAfterDelta = _nullableInteger(
    row?['remaining_after_delta'],
  );
  final int? entitlementVersion = _integer(row?['entitlement_version']);
  final int? policyVersion = _integer(row?['policy_version']);
  final int? runtimeVersion = _integer(row?['runtime_version']);
  if (row == null ||
      row['decision'] is! String ||
      row['household_id'] is! String ||
      row['feature_key'] is! String ||
      requestedDelta == null ||
      currentUsage == null ||
      row['limit_value'] != null && limitValue == null ||
      row['remaining_after_delta'] != null && remainingAfterDelta == null ||
      row['plan_code'] is! String ||
      row['entitlement_status'] is! String ||
      row['enforcement_enabled'] is! bool ||
      row['limits_finalized'] is! bool ||
      entitlementVersion == null ||
      policyVersion == null ||
      runtimeVersion == null ||
      row['evaluated_at'] is! String) {
    return null;
  }
  return HouseholdFeatureGateDataRecord(
    decision: row['decision']! as String,
    householdId: row['household_id']! as String,
    featureKey: row['feature_key']! as String,
    requestedDelta: requestedDelta,
    currentUsage: currentUsage,
    limitValue: limitValue,
    remainingAfterDelta: remainingAfterDelta,
    planCode: row['plan_code']! as String,
    entitlementStatus: row['entitlement_status']! as String,
    enforcementEnabled: row['enforcement_enabled']! as bool,
    limitsFinalized: row['limits_finalized']! as bool,
    entitlementVersion: entitlementVersion,
    policyVersion: policyVersion,
    runtimeVersion: runtimeVersion,
    evaluatedAt: row['evaluated_at']! as String,
  );
}

HouseholdFeatureGateDataFailureKind
householdFeatureGateDataFailureFromProviderCode(String? code) {
  return switch (code) {
    'PGRST301' => HouseholdFeatureGateDataFailureKind.unauthenticated,
    '22P02' ||
    '22023' ||
    '23514' => HouseholdFeatureGateDataFailureKind.invalidInput,
    '42501' => HouseholdFeatureGateDataFailureKind.notFoundOrForbidden,
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => HouseholdFeatureGateDataFailureKind.temporarilyUnavailable,
    _ => HouseholdFeatureGateDataFailureKind.unknown,
  };
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

int? _nullableInteger(Object? value) => value == null ? null : _integer(value);
