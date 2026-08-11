import 'package:kinflow_app/features/billing/data/datasources/household_feature_gate_data_source.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/household_feature_gate_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _utcOffsetPattern = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$');

final class ProviderHouseholdFeatureGateRepository
    implements HouseholdFeatureGateRepository {
  const ProviderHouseholdFeatureGateRepository(this._dataSource);

  final HouseholdFeatureGateDataSource _dataSource;

  @override
  Future<HouseholdFeatureGateResult> evaluate(
    HouseholdFeatureGateRequest request,
  ) async {
    final HouseholdFeatureGateDataResult result = await _dataSource.evaluate(
      householdId: request.householdId.value,
      featureKey: request.featureKey.wireValue,
      requestedDelta: request.requestedDelta,
    );
    return switch (result) {
      HouseholdFeatureGateDataSucceeded(:final value) => _map(value, request),
      HouseholdFeatureGateDataFailed(:final kind) => HouseholdFeatureGateFailed(
        EntitlementFailure(_mapFailure(kind)),
      ),
    };
  }

  HouseholdFeatureGateResult _map(
    HouseholdFeatureGateDataRecord record,
    HouseholdFeatureGateRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final HouseholdFeatureKey? featureKey = HouseholdFeatureKey.tryParse(
      record.featureKey,
    );
    final HouseholdFeatureGateDecision? decision =
        HouseholdFeatureGateDecision.tryParse(record.decision);
    final EntitlementPlan? plan = EntitlementPlan.tryParse(record.planCode);
    final HouseholdEntitlementStatus? status =
        HouseholdEntitlementStatus.tryParse(record.entitlementStatus);
    final DateTime? evaluatedAt = _utcInstant(record.evaluatedAt);
    if (householdId != request.householdId ||
        featureKey != request.featureKey ||
        record.requestedDelta != request.requestedDelta ||
        decision == null ||
        plan == null ||
        status == null ||
        evaluatedAt == null) {
      return const HouseholdFeatureGateFailed(
        EntitlementFailure(EntitlementFailureKind.invalidPayload),
      );
    }
    final HouseholdFeatureGate? gate = HouseholdFeatureGate.tryCreate(
      decision: decision,
      householdId: householdId!,
      featureKey: featureKey!,
      requestedDelta: record.requestedDelta,
      currentUsage: record.currentUsage,
      limit: record.limitValue,
      remainingAfterDelta: record.remainingAfterDelta,
      plan: plan,
      entitlementStatus: status,
      enforcementEnabled: record.enforcementEnabled,
      limitsFinalized: record.limitsFinalized,
      entitlementVersion: record.entitlementVersion,
      policyVersion: record.policyVersion,
      runtimeVersion: record.runtimeVersion,
      evaluatedAt: evaluatedAt,
    );
    return gate == null
        ? const HouseholdFeatureGateFailed(
            EntitlementFailure(EntitlementFailureKind.invalidPayload),
          )
        : HouseholdFeatureGateSucceeded(gate);
  }
}

DateTime? _utcInstant(String value) {
  if (!_utcOffsetPattern.hasMatch(value)) return null;
  return DateTime.tryParse(value)?.toUtc();
}

EntitlementFailureKind _mapFailure(HouseholdFeatureGateDataFailureKind kind) {
  return switch (kind) {
    HouseholdFeatureGateDataFailureKind.unauthenticated =>
      EntitlementFailureKind.unauthenticated,
    HouseholdFeatureGateDataFailureKind.invalidInput =>
      EntitlementFailureKind.invalidInput,
    HouseholdFeatureGateDataFailureKind.notFoundOrForbidden =>
      EntitlementFailureKind.notFoundOrForbidden,
    HouseholdFeatureGateDataFailureKind.temporarilyUnavailable =>
      EntitlementFailureKind.temporarilyUnavailable,
    HouseholdFeatureGateDataFailureKind.invalidPayload =>
      EntitlementFailureKind.invalidPayload,
    HouseholdFeatureGateDataFailureKind.unknown =>
      EntitlementFailureKind.unknown,
  };
}
