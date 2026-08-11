import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class EntitlementRepository {
  Future<EntitlementResult<HouseholdEntitlement>> load(HouseholdId householdId);
}

sealed class EntitlementResult<T> {
  const EntitlementResult();
}

final class EntitlementSucceeded<T> extends EntitlementResult<T> {
  const EntitlementSucceeded(this.value);

  final T value;
}

final class EntitlementFailed<T> extends EntitlementResult<T> {
  const EntitlementFailed(this.failure);

  final EntitlementFailure failure;
}
