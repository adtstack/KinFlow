import 'package:kinflow_app/features/billing/data/datasources/entitlement_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _entitlementKeys = <String>{
  'household_id',
  'entitlement_key',
  'plan_code',
  'status',
  'source',
  'current_period_end',
  'will_renew',
  'feature_limits',
  'limits_finalized',
  'verified_at',
  'version',
  'is_billing_owner',
};

final RegExp _featureKeyPattern = RegExp(r'^[a-z][A-Za-z0-9]{0,63}$');

final class SupabaseEntitlementDataSource implements EntitlementDataSource {
  const SupabaseEntitlementDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<EntitlementDataResult<HouseholdEntitlementDataRecord>> load({
    required String householdId,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'get_household_entitlement',
        params: <String, Object?>{'p_household_id': householdId},
      );
      final HouseholdEntitlementDataRecord? record =
          householdEntitlementRecordFromPayload(response);
      return record == null
          ? const EntitlementDataFailed<HouseholdEntitlementDataRecord>(
              EntitlementDataFailureKind.invalidPayload,
            )
          : EntitlementDataSucceeded<HouseholdEntitlementDataRecord>(record);
    } on PostgrestException catch (error) {
      return EntitlementDataFailed<HouseholdEntitlementDataRecord>(
        entitlementDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const EntitlementDataFailed<HouseholdEntitlementDataRecord>(
        EntitlementDataFailureKind.unauthenticated,
      );
    } on Object {
      return const EntitlementDataFailed<HouseholdEntitlementDataRecord>(
        EntitlementDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

HouseholdEntitlementDataRecord? householdEntitlementRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<dynamic> || payload.length != 1) return null;
  final Map<String, Object?>? row = _exactMap(payload.single, _entitlementKeys);
  final Map<String, int>? featureLimits = _featureLimits(
    row?['feature_limits'],
  );
  final int? version = _integer(row?['version']);
  if (row == null ||
      row['household_id'] is! String ||
      row['entitlement_key'] is! String ||
      row['plan_code'] is! String ||
      row['status'] is! String ||
      row['source'] is! String ||
      row['current_period_end'] != null &&
          row['current_period_end'] is! String ||
      row['will_renew'] is! bool ||
      featureLimits == null ||
      row['limits_finalized'] is! bool ||
      row['verified_at'] is! String ||
      version == null ||
      row['is_billing_owner'] is! bool) {
    return null;
  }
  return HouseholdEntitlementDataRecord(
    householdId: row['household_id']! as String,
    entitlementKey: row['entitlement_key']! as String,
    planCode: row['plan_code']! as String,
    status: row['status']! as String,
    source: row['source']! as String,
    currentPeriodEnd: row['current_period_end'] as String?,
    willRenew: row['will_renew']! as bool,
    featureLimits: featureLimits,
    limitsFinalized: row['limits_finalized']! as bool,
    verifiedAt: row['verified_at']! as String,
    version: version,
    isBillingOwner: row['is_billing_owner']! as bool,
  );
}

EntitlementDataFailureKind entitlementDataFailureFromProviderCode(
  String? code,
) {
  return switch (code) {
    'PGRST301' => EntitlementDataFailureKind.unauthenticated,
    '22P02' || '22023' || '23514' => EntitlementDataFailureKind.invalidInput,
    '42501' => EntitlementDataFailureKind.notFoundOrForbidden,
    'PGRST000' ||
    'PGRST001' ||
    'PGRST002' ||
    'PGRST003' => EntitlementDataFailureKind.temporarilyUnavailable,
    _ => EntitlementDataFailureKind.unknown,
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

Map<String, int>? _featureLimits(Object? value) {
  if (value is! Map<dynamic, dynamic> || value.length > 64) return null;
  final Map<String, int> result = <String, int>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final int? limit = _integer(entry.value);
    if (entry.key is! String ||
        !_featureKeyPattern.hasMatch(entry.key! as String) ||
        limit == null ||
        limit < 0 ||
        limit > 1000000) {
      return null;
    }
    result[entry.key! as String] = limit;
  }
  return result;
}

int? _integer(Object? value) {
  return value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : null;
}
