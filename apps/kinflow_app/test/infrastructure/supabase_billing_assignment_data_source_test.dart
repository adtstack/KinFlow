import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/billing_assignment_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_billing_assignment_data_source.dart';

void main() {
  test('prepare parser accepts one exact aggregate row', () {
    final Map<String, Object?> row = <String, Object?>{
      'intent_id': '80000000-0000-4000-8000-000000000001',
      'outcome': 'ready',
      'binding_state': 'provisional',
      'assignment_version': 2,
      'intent_expires_at': '2026-08-08T01:00:00+00:00',
      'requeued_job_count': 1,
      'duplicate': false,
    };

    final BillingAssignmentPrepareDataRecord? record =
        billingAssignmentPrepareRecordFromPayload(<Object?>[row]);

    expect(record?.outcome, 'ready');
    expect(record?.assignmentVersion, 2);
    expect(
      billingAssignmentPrepareRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'provider_customer_ref': 'private'},
      ]),
      isNull,
    );
    expect(
      billingAssignmentPrepareRecordFromPayload(<Object?>[row, row]),
      isNull,
    );
  });

  test('status parser rejects missing and non-integral fields', () {
    final Map<String, Object?> row = <String, Object?>{
      'household_id': '20000000-0000-4000-8000-000000000101',
      'assignment_state': 'confirmed',
      'ownership_state': 'another_user',
      'owner_membership_state': 'removed',
      'can_prepare': false,
      'requires_support': true,
      'assignment_version': 3,
      'intent_expires_at': null,
    };

    expect(billingAssignmentStatusRecordFromPayload(<Object?>[row]), isNotNull);
    expect(
      billingAssignmentStatusRecordFromPayload(<Object?>[
        <String, Object?>{...row}..remove('requires_support'),
      ]),
      isNull,
    );
    expect(
      billingAssignmentStatusRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'assignment_version': 3.5},
      ]),
      isNull,
    );
  });

  test('release and remediation parsers keep exact response surfaces', () {
    expect(
      billingAssignmentReleaseRecordFromPayload(<Object?>[
        <String, Object?>{
          'outcome': 'released',
          'assignment_version': 4,
          'duplicate': false,
        },
      ]),
      isNotNull,
    );
    expect(
      billingAssignmentRemediationRecordFromPayload(<Object?>[
        <String, Object?>{
          'request_id': '80000000-0000-4000-8000-000000000002',
          'status': 'open',
          'issue_kind': 'restore_conflict',
          'duplicate': false,
        },
      ]),
      isNotNull,
    );
    expect(
      billingAssignmentRemediationRecordFromPayload(<Object?>[
        <String, Object?>{
          'request_id': '80000000-0000-4000-8000-000000000002',
          'status': 'open',
          'issue_kind': 'restore_conflict',
          'duplicate': false,
          'case_reference': 'must-not-cross-client-boundary',
        },
      ]),
      isNull,
    );
  });

  test('provider errors map without retaining raw server details', () {
    expect(
      billingAssignmentDataFailureFromProviderCode('KFB50'),
      BillingAssignmentDataFailureKind.invalidInput,
    );
    expect(
      billingAssignmentDataFailureFromProviderCode('KFB51'),
      BillingAssignmentDataFailureKind.temporarilyUnavailable,
    );
    expect(
      billingAssignmentDataFailureFromProviderCode('KFB52'),
      BillingAssignmentDataFailureKind.versionConflict,
    );
    expect(
      billingAssignmentDataFailureFromProviderCode('provider-private-detail'),
      BillingAssignmentDataFailureKind.unknown,
    );
  });
}
