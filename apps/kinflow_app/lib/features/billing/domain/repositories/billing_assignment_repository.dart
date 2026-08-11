import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_assignment_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class BillingAssignmentRepository {
  Future<BillingAssignmentResult<BillingAssignmentPreparation>> prepare({
    required HouseholdId householdId,
    required BillingAssignmentCommandId commandId,
  });

  Future<BillingAssignmentResult<BillingAssignmentRelease>> release({
    required HouseholdId householdId,
    required int expectedAssignmentVersion,
    required BillingAssignmentCommandId commandId,
  });

  Future<BillingAssignmentResult<BillingHouseholdAssignmentStatus>> status(
    HouseholdId householdId,
  );

  Future<BillingAssignmentResult<BillingAssignmentRemediationRequest>>
  requestRemediation({
    required HouseholdId householdId,
    required BillingAssignmentRemediationIssue issue,
    required BillingAssignmentCommandId commandId,
  });
}

sealed class BillingAssignmentResult<T> {
  const BillingAssignmentResult();
}

final class BillingAssignmentSucceeded<T> extends BillingAssignmentResult<T> {
  const BillingAssignmentSucceeded(this.value);

  final T value;
}

final class BillingAssignmentFailed<T> extends BillingAssignmentResult<T> {
  const BillingAssignmentFailed(this.failure);

  final BillingAssignmentFailure failure;
}
