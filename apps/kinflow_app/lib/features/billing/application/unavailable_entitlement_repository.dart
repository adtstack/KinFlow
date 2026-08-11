import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableEntitlementRepository implements EntitlementRepository {
  const UnavailableEntitlementRepository();

  @override
  Future<EntitlementResult<HouseholdEntitlement>> load(
    HouseholdId householdId,
  ) async {
    return const EntitlementFailed<HouseholdEntitlement>(
      EntitlementFailure(EntitlementFailureKind.temporarilyUnavailable),
    );
  }
}
