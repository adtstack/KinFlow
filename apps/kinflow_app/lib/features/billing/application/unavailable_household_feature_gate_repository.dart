import 'package:kinflow_app/features/billing/domain/entities/household_feature_gate.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/household_feature_gate_repository.dart';

final class UnavailableHouseholdFeatureGateRepository
    implements HouseholdFeatureGateRepository {
  const UnavailableHouseholdFeatureGateRepository();

  @override
  Future<HouseholdFeatureGateResult> evaluate(
    HouseholdFeatureGateRequest request,
  ) async {
    return const HouseholdFeatureGateFailed(
      EntitlementFailure(EntitlementFailureKind.temporarilyUnavailable),
    );
  }
}
