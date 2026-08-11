import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/household_feature_gate_data_source.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_household_feature_gate_repository.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/household_feature_gate_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  const String householdUuid = '20000000-0000-4000-8000-000000000101';
  final HouseholdId householdId = HouseholdId.tryParse(householdUuid)!;
  final HouseholdFeatureGateRequest request =
      HouseholdFeatureGateRequest.tryCreate(
        householdId: householdId,
        featureKey: HouseholdFeatureKey.activeSeries,
        requestedDelta: 2,
      )!;

  test('strict aggregate maps to a provider-independent gate', () async {
    final _FakeFeatureGateDataSource dataSource = _FakeFeatureGateDataSource(
      record: _record(),
    );
    final ProviderHouseholdFeatureGateRepository repository =
        ProviderHouseholdFeatureGateRepository(dataSource);

    final HouseholdFeatureGateResult result = await repository.evaluate(
      request,
    );

    final HouseholdFeatureGate gate =
        (result as HouseholdFeatureGateSucceeded).gate;
    expect(gate.decision, HouseholdFeatureGateDecision.allowed);
    expect(gate.remainingAfterDelta, 6);
    expect(gate.evaluatedAt.isUtc, isTrue);
    expect(dataSource.householdId, householdUuid);
    expect(dataSource.featureKey, 'activeSeries');
    expect(dataSource.requestedDelta, 2);
  });

  test(
    'request echo mismatch and local timestamps cannot cross mapper',
    () async {
      for (final HouseholdFeatureGateDataRecord record
          in <HouseholdFeatureGateDataRecord>[
            _record(householdId: '20000000-0000-4000-8000-000000000201'),
            _record(featureKey: 'members'),
            _record(requestedDelta: 1),
            _record(evaluatedAt: '2026-08-08T00:00:00'),
          ]) {
        final HouseholdFeatureGateResult result =
            await ProviderHouseholdFeatureGateRepository(
              _FakeFeatureGateDataSource(record: record),
            ).evaluate(request);
        expect(result, isA<HouseholdFeatureGateFailed>());
        expect(
          (result as HouseholdFeatureGateFailed).failure.kind,
          EntitlementFailureKind.invalidPayload,
        );
      }
    },
  );

  test('inconsistent decision arithmetic fails closed', () async {
    final HouseholdFeatureGateResult result =
        await ProviderHouseholdFeatureGateRepository(
          _FakeFeatureGateDataSource(record: _record(remainingAfterDelta: 5)),
        ).evaluate(request);

    expect(result, isA<HouseholdFeatureGateFailed>());
    expect(
      (result as HouseholdFeatureGateFailed).failure.kind,
      EntitlementFailureKind.invalidPayload,
    );
  });

  test('data-source failures retain bounded domain categories', () async {
    const Map<HouseholdFeatureGateDataFailureKind, EntitlementFailureKind>
    cases = <HouseholdFeatureGateDataFailureKind, EntitlementFailureKind>{
      HouseholdFeatureGateDataFailureKind.unauthenticated:
          EntitlementFailureKind.unauthenticated,
      HouseholdFeatureGateDataFailureKind.invalidInput:
          EntitlementFailureKind.invalidInput,
      HouseholdFeatureGateDataFailureKind.notFoundOrForbidden:
          EntitlementFailureKind.notFoundOrForbidden,
      HouseholdFeatureGateDataFailureKind.temporarilyUnavailable:
          EntitlementFailureKind.temporarilyUnavailable,
      HouseholdFeatureGateDataFailureKind.invalidPayload:
          EntitlementFailureKind.invalidPayload,
      HouseholdFeatureGateDataFailureKind.unknown:
          EntitlementFailureKind.unknown,
    };

    for (final MapEntry<
          HouseholdFeatureGateDataFailureKind,
          EntitlementFailureKind
        >
        entry
        in cases.entries) {
      final HouseholdFeatureGateResult result =
          await ProviderHouseholdFeatureGateRepository(
            _FakeFeatureGateDataSource(failure: entry.key),
          ).evaluate(request);
      expect((result as HouseholdFeatureGateFailed).failure.kind, entry.value);
    }
  });
}

HouseholdFeatureGateDataRecord _record({
  String householdId = '20000000-0000-4000-8000-000000000101',
  String featureKey = 'activeSeries',
  int requestedDelta = 2,
  int remainingAfterDelta = 6,
  String evaluatedAt = '2026-08-08T00:00:00+00:00',
}) {
  return HouseholdFeatureGateDataRecord(
    decision: 'allowed',
    householdId: householdId,
    featureKey: featureKey,
    requestedDelta: requestedDelta,
    currentUsage: 2,
    limitValue: 10,
    remainingAfterDelta: remainingAfterDelta,
    planCode: 'plus',
    entitlementStatus: 'active',
    enforcementEnabled: true,
    limitsFinalized: true,
    entitlementVersion: 2,
    policyVersion: 3,
    runtimeVersion: 4,
    evaluatedAt: evaluatedAt,
  );
}

final class _FakeFeatureGateDataSource
    implements HouseholdFeatureGateDataSource {
  _FakeFeatureGateDataSource({this.record, this.failure});

  final HouseholdFeatureGateDataRecord? record;
  final HouseholdFeatureGateDataFailureKind? failure;
  String? householdId;
  String? featureKey;
  int? requestedDelta;

  @override
  Future<HouseholdFeatureGateDataResult> evaluate({
    required String householdId,
    required String featureKey,
    required int requestedDelta,
  }) async {
    this.householdId = householdId;
    this.featureKey = featureKey;
    this.requestedDelta = requestedDelta;
    return failure == null
        ? HouseholdFeatureGateDataSucceeded(record!)
        : HouseholdFeatureGateDataFailed(failure!);
  }
}
