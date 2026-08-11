import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_assignment_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableBillingAssignmentRepository
    implements BillingAssignmentRepository {
  const UnavailableBillingAssignmentRepository();

  static const BillingAssignmentFailure _failure = BillingAssignmentFailure(
    BillingAssignmentFailureKind.temporarilyUnavailable,
  );

  @override
  Future<BillingAssignmentResult<BillingAssignmentPreparation>> prepare({
    required HouseholdId householdId,
    required BillingAssignmentCommandId commandId,
  }) async =>
      const BillingAssignmentFailed<BillingAssignmentPreparation>(_failure);

  @override
  Future<BillingAssignmentResult<BillingAssignmentRelease>> release({
    required HouseholdId householdId,
    required int expectedAssignmentVersion,
    required BillingAssignmentCommandId commandId,
  }) async => const BillingAssignmentFailed<BillingAssignmentRelease>(_failure);

  @override
  Future<BillingAssignmentResult<BillingHouseholdAssignmentStatus>> status(
    HouseholdId householdId,
  ) async =>
      const BillingAssignmentFailed<BillingHouseholdAssignmentStatus>(_failure);

  @override
  Future<BillingAssignmentResult<BillingAssignmentRemediationRequest>>
  requestRemediation({
    required HouseholdId householdId,
    required BillingAssignmentRemediationIssue issue,
    required BillingAssignmentCommandId commandId,
  }) async =>
      const BillingAssignmentFailed<BillingAssignmentRemediationRequest>(
        _failure,
      );
}
