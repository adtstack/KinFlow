import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';

abstract interface class HouseholdFeatureGateRepository {
  Future<HouseholdFeatureGateResult> evaluate(
    HouseholdFeatureGateRequest request,
  );
}

sealed class HouseholdFeatureGateResult {
  const HouseholdFeatureGateResult();
}

final class HouseholdFeatureGateSucceeded extends HouseholdFeatureGateResult {
  const HouseholdFeatureGateSucceeded(this.gate);

  final HouseholdFeatureGate gate;
}

final class HouseholdFeatureGateFailed extends HouseholdFeatureGateResult {
  const HouseholdFeatureGateFailed(this.failure);

  final EntitlementFailure failure;
}
