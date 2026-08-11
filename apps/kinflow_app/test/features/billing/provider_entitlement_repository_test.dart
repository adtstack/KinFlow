import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/entitlement_data_source.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  const String householdUuid = '20000000-0000-4000-8000-000000000101';
  final HouseholdId householdId = HouseholdId.tryParse(householdUuid)!;

  test(
    'strict record maps to provider-independent entitlement domain',
    () async {
      final _FakeEntitlementDataSource dataSource = _FakeEntitlementDataSource(
        record: _record(),
      );
      final ProviderEntitlementRepository repository =
          ProviderEntitlementRepository(dataSource);

      final EntitlementResult<HouseholdEntitlement> result = await repository
          .load(householdId);

      expect(result, isA<EntitlementSucceeded<HouseholdEntitlement>>());
      final HouseholdEntitlement entitlement =
          (result as EntitlementSucceeded<HouseholdEntitlement>).value;
      expect(entitlement.householdId, householdId);
      expect(entitlement.plan, EntitlementPlan.plus);
      expect(entitlement.status, HouseholdEntitlementStatus.active);
      expect(entitlement.source, EntitlementSource.playStore);
      expect(entitlement.limitFor('activeSeries'), 100);
      expect(dataSource.loadedHouseholdId, householdUuid);
    },
  );

  test('household and timestamp mismatch cannot cross the mapper', () async {
    final ProviderEntitlementRepository wrongHousehold =
        ProviderEntitlementRepository(
          _FakeEntitlementDataSource(
            record: _record(
              householdId: '20000000-0000-4000-8000-000000000201',
            ),
          ),
        );
    final ProviderEntitlementRepository localTime =
        ProviderEntitlementRepository(
          _FakeEntitlementDataSource(
            record: _record(verifiedAt: '2026-08-08T09:00:00'),
          ),
        );

    for (final ProviderEntitlementRepository repository
        in <ProviderEntitlementRepository>[wrongHousehold, localTime]) {
      final EntitlementResult<HouseholdEntitlement> result = await repository
          .load(householdId);
      expect(result, isA<EntitlementFailed<HouseholdEntitlement>>());
      expect(
        (result as EntitlementFailed<HouseholdEntitlement>).failure.kind,
        EntitlementFailureKind.invalidPayload,
      );
    }
  });

  test('inconsistent server plan and lifecycle fail closed', () async {
    final ProviderEntitlementRepository repository =
        ProviderEntitlementRepository(
          _FakeEntitlementDataSource(
            record: _record(planCode: 'free', status: 'active'),
          ),
        );

    final EntitlementResult<HouseholdEntitlement> result = await repository
        .load(householdId);

    expect(result, isA<EntitlementFailed<HouseholdEntitlement>>());
    expect(
      (result as EntitlementFailed<HouseholdEntitlement>).failure.kind,
      EntitlementFailureKind.invalidPayload,
    );
  });

  test('data-source failures retain stable domain categories', () async {
    final ProviderEntitlementRepository repository =
        ProviderEntitlementRepository(
          _FakeEntitlementDataSource(
            failure: EntitlementDataFailureKind.notFoundOrForbidden,
          ),
        );

    final EntitlementResult<HouseholdEntitlement> result = await repository
        .load(householdId);

    expect(result, isA<EntitlementFailed<HouseholdEntitlement>>());
    expect(
      (result as EntitlementFailed<HouseholdEntitlement>).failure.kind,
      EntitlementFailureKind.notFoundOrForbidden,
    );
  });
}

HouseholdEntitlementDataRecord _record({
  String householdId = '20000000-0000-4000-8000-000000000101',
  String planCode = 'plus',
  String status = 'active',
  String verifiedAt = '2026-08-08T00:00:00Z',
}) {
  return HouseholdEntitlementDataRecord(
    householdId: householdId,
    entitlementKey: 'plus',
    planCode: planCode,
    status: status,
    source: 'play_store',
    currentPeriodEnd: '2026-09-01T00:00:00+00:00',
    willRenew: true,
    featureLimits: const <String, int>{'members': 10, 'activeSeries': 100},
    limitsFinalized: true,
    verifiedAt: verifiedAt,
    version: 2,
    isBillingOwner: false,
  );
}

final class _FakeEntitlementDataSource implements EntitlementDataSource {
  _FakeEntitlementDataSource({this.record, this.failure});

  final HouseholdEntitlementDataRecord? record;
  final EntitlementDataFailureKind? failure;
  String? loadedHouseholdId;

  @override
  Future<EntitlementDataResult<HouseholdEntitlementDataRecord>> load({
    required String householdId,
  }) async {
    loadedHouseholdId = householdId;
    return failure == null
        ? EntitlementDataSucceeded<HouseholdEntitlementDataRecord>(record!)
        : EntitlementDataFailed<HouseholdEntitlementDataRecord>(failure!);
  }
}
