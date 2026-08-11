import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '20000000-0000-4000-8000-000000000101',
  )!;

  test('prepare result keeps ready and conflict shapes disjoint', () {
    expect(
      BillingAssignmentPreparation.tryCreate(
        intentId: '80000000-0000-4000-8000-000000000001',
        outcome: BillingAssignmentPrepareOutcome.ready,
        bindingState: BillingAssignmentBindingState.provisional,
        assignmentVersion: 1,
        intentExpiresAt: DateTime.parse('2026-08-08T01:00:00Z'),
        requeuedJobCount: 2,
        duplicate: false,
      ),
      isNotNull,
    );
    expect(
      BillingAssignmentPreparation.tryCreate(
        intentId: '80000000-0000-4000-8000-000000000002',
        outcome: BillingAssignmentPrepareOutcome.customerConflict,
        bindingState: null,
        assignmentVersion: null,
        intentExpiresAt: null,
        requeuedJobCount: 0,
        duplicate: false,
      ),
      isNotNull,
    );
    expect(
      BillingAssignmentPreparation.tryCreate(
        intentId: '80000000-0000-4000-8000-000000000003',
        outcome: BillingAssignmentPrepareOutcome.householdConflict,
        bindingState: BillingAssignmentBindingState.confirmed,
        assignmentVersion: 1,
        intentExpiresAt: null,
        requeuedJobCount: 0,
        duplicate: false,
      ),
      isNull,
    );
  });

  test(
    'provisional preparation requires UTC expiry and a positive version',
    () {
      for (final BillingAssignmentPreparation? invalid
          in <BillingAssignmentPreparation?>[
            BillingAssignmentPreparation.tryCreate(
              intentId: '80000000-0000-4000-8000-000000000004',
              outcome: BillingAssignmentPrepareOutcome.ready,
              bindingState: BillingAssignmentBindingState.provisional,
              assignmentVersion: 0,
              intentExpiresAt: DateTime.parse('2026-08-08T01:00:00Z'),
              requeuedJobCount: 0,
              duplicate: false,
            ),
            BillingAssignmentPreparation.tryCreate(
              intentId: '80000000-0000-4000-8000-000000000005',
              outcome: BillingAssignmentPrepareOutcome.ready,
              bindingState: BillingAssignmentBindingState.provisional,
              assignmentVersion: 1,
              intentExpiresAt: DateTime(2026, 8, 8),
              requeuedJobCount: 0,
              duplicate: false,
            ),
            BillingAssignmentPreparation.tryCreate(
              intentId: 'not-a-uuid',
              outcome: BillingAssignmentPrepareOutcome.ready,
              bindingState: BillingAssignmentBindingState.confirmed,
              assignmentVersion: 1,
              intentExpiresAt: null,
              requeuedJobCount: 0,
              duplicate: false,
            ),
          ]) {
        expect(invalid, isNull);
      }
    },
  );

  test('assignment status rejects impossible ownership combinations', () {
    expect(
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId,
        assignmentState: BillingAssignmentState.none,
        ownershipState: BillingAssignmentOwnershipState.unassigned,
        ownerMembershipState: BillingAssignmentOwnerMembershipState.none,
        canPrepare: true,
        requiresSupport: false,
        assignmentVersion: null,
        intentExpiresAt: null,
      ),
      isNotNull,
    );
    expect(
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId,
        assignmentState: BillingAssignmentState.confirmed,
        ownershipState: BillingAssignmentOwnershipState.anotherUser,
        ownerMembershipState: BillingAssignmentOwnerMembershipState.removed,
        canPrepare: false,
        requiresSupport: true,
        assignmentVersion: 3,
        intentExpiresAt: null,
      ),
      isNotNull,
    );
    expect(
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId,
        assignmentState: BillingAssignmentState.confirmed,
        ownershipState: BillingAssignmentOwnershipState.anotherUser,
        ownerMembershipState: BillingAssignmentOwnerMembershipState.active,
        canPrepare: true,
        requiresSupport: false,
        assignmentVersion: 3,
        intentExpiresAt: null,
      ),
      isNull,
    );
  });

  test('command and remediation identifiers accept UUIDs only', () {
    expect(
      BillingAssignmentCommandId.tryParse(
        '80000000-0000-4000-8000-000000000006',
      ),
      isNotNull,
    );
    expect(BillingAssignmentCommandId.tryParse('command-raw'), isNull);
    expect(
      BillingAssignmentRemediationRequest.tryCreate(
        requestId: '80000000-0000-4000-8000-000000000007',
        status: BillingAssignmentRemediationStatus.open,
        issue: BillingAssignmentRemediationIssue.restoreConflict,
        duplicate: false,
      ),
      isNotNull,
    );
  });
}
