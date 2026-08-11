import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/household_feature_gate_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_feature_gate_data_source.dart';

void main() {
  Map<String, Object?> payload() => <String, Object?>{
    'decision': 'allowed',
    'household_id': '20000000-0000-4000-8000-000000000101',
    'feature_key': 'activeSeries',
    'requested_delta': 2,
    'current_usage': 2,
    'limit_value': 10,
    'remaining_after_delta': 6,
    'plan_code': 'plus',
    'entitlement_status': 'active',
    'enforcement_enabled': true,
    'limits_finalized': true,
    'entitlement_version': 2,
    'policy_version': 3,
    'runtime_version': 4,
    'evaluated_at': '2026-08-08T00:00:00+00:00',
  };

  test('parser accepts exactly one safe aggregate projection', () {
    final HouseholdFeatureGateDataRecord? record =
        householdFeatureGateRecordFromPayload(<Object?>[payload()]);

    expect(record?.featureKey, 'activeSeries');
    expect(record?.requestedDelta, 2);
    expect(record?.remainingAfterDelta, 6);
    expect(
      householdFeatureGateRecordFromPayload(<Object?>[
        <String, Object?>{
          ...payload(),
          'provider_customer_ref': 'must-not-cross-boundary',
        },
      ]),
      isNull,
    );
    expect(
      householdFeatureGateRecordFromPayload(<Object?>[payload(), payload()]),
      isNull,
    );
    expect(householdFeatureGateRecordFromPayload(const <Object?>[]), isNull);
  });

  test('nullable capacity and integral fields remain type safe', () {
    expect(
      householdFeatureGateRecordFromPayload(<Object?>[
        <String, Object?>{
          ...payload(),
          'decision': 'policy_unavailable',
          'limit_value': null,
          'remaining_after_delta': null,
          'enforcement_enabled': false,
          'limits_finalized': false,
        },
      ]),
      isNotNull,
    );
    for (final Map<String, Object?> row in <Map<String, Object?>>[
      <String, Object?>{...payload(), 'limit_value': '10'},
      <String, Object?>{...payload(), 'remaining_after_delta': 1.5},
      <String, Object?>{...payload(), 'requested_delta': 2.5},
      <String, Object?>{...payload(), 'runtime_version': null},
    ]) {
      expect(householdFeatureGateRecordFromPayload(<Object?>[row]), isNull);
    }
  });

  test('provider errors map without retaining raw provider details', () {
    expect(
      householdFeatureGateDataFailureFromProviderCode('PGRST301'),
      HouseholdFeatureGateDataFailureKind.unauthenticated,
    );
    expect(
      householdFeatureGateDataFailureFromProviderCode('22023'),
      HouseholdFeatureGateDataFailureKind.invalidInput,
    );
    expect(
      householdFeatureGateDataFailureFromProviderCode('42501'),
      HouseholdFeatureGateDataFailureKind.notFoundOrForbidden,
    );
    expect(
      householdFeatureGateDataFailureFromProviderCode('PGRST003'),
      HouseholdFeatureGateDataFailureKind.temporarilyUnavailable,
    );
    expect(
      householdFeatureGateDataFailureFromProviderCode('private-detail'),
      HouseholdFeatureGateDataFailureKind.unknown,
    );
  });
}
