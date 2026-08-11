import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/entitlement_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_entitlement_data_source.dart';

void main() {
  const String householdId = '20000000-0000-4000-8000-000000000101';

  Map<String, Object?> payload() => <String, Object?>{
    'household_id': householdId,
    'entitlement_key': 'plus',
    'plan_code': 'plus',
    'status': 'active',
    'source': 'play_store',
    'current_period_end': '2026-09-01T00:00:00+00:00',
    'will_renew': true,
    'feature_limits': <String, Object?>{'members': 10, 'activeSeries': 100},
    'limits_finalized': true,
    'verified_at': '2026-08-08T00:00:00+00:00',
    'version': 2,
    'is_billing_owner': false,
  };

  test('entitlement parser accepts only one exact projection row', () {
    final HouseholdEntitlementDataRecord? record =
        householdEntitlementRecordFromPayload(<Object?>[payload()]);

    expect(record, isNotNull);
    expect(record!.householdId, householdId);
    expect(record.featureLimits, <String, int>{
      'members': 10,
      'activeSeries': 100,
    });
    expect(
      householdEntitlementRecordFromPayload(<Object?>[
        <String, Object?>{...payload(), 'provider_customer_ref': 'secret'},
      ]),
      isNull,
    );
    expect(
      householdEntitlementRecordFromPayload(<Object?>[payload(), payload()]),
      isNull,
    );
    expect(householdEntitlementRecordFromPayload(const <Object?>[]), isNull);
  });

  test('feature limit payload rejects malformed keys and numeric values', () {
    expect(
      householdEntitlementRecordFromPayload(<Object?>[
        <String, Object?>{
          ...payload(),
          'feature_limits': <String, Object?>{'Bad Key': 1},
        },
      ]),
      isNull,
    );
    expect(
      householdEntitlementRecordFromPayload(<Object?>[
        <String, Object?>{
          ...payload(),
          'feature_limits': <String, Object?>{'members': 2.5},
        },
      ]),
      isNull,
    );
    expect(
      householdEntitlementRecordFromPayload(<Object?>[
        <String, Object?>{
          ...payload(),
          'feature_limits': <String, Object?>{'members': 1000001},
        },
      ]),
      isNull,
    );
  });

  test('provider errors map without exposing raw server details', () {
    expect(
      entitlementDataFailureFromProviderCode('PGRST301'),
      EntitlementDataFailureKind.unauthenticated,
    );
    expect(
      entitlementDataFailureFromProviderCode('42501'),
      EntitlementDataFailureKind.notFoundOrForbidden,
    );
    expect(
      entitlementDataFailureFromProviderCode('PGRST003'),
      EntitlementDataFailureKind.temporarilyUnavailable,
    );
    expect(
      entitlementDataFailureFromProviderCode('provider-private-code'),
      EntitlementDataFailureKind.unknown,
    );
  });
}
