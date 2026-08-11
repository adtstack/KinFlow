import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/data/datasources/billing_assignment_data_source.dart';
import 'package:kinflow_app/features/billing/data/repositories/provider_billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_assignment_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '20000000-0000-4000-8000-000000000101',
  )!;
  final BillingAssignmentCommandId commandId =
      BillingAssignmentCommandId.tryParse(
        '80000000-0000-4000-8000-000000000001',
      )!;

  test('strict provisional prepare record maps to domain', () async {
    final _FakeDataSource dataSource = _FakeDataSource(
      prepareRecord: const BillingAssignmentPrepareDataRecord(
        intentId: '81000000-0000-4000-8000-000000000001',
        outcome: 'ready',
        bindingState: 'provisional',
        assignmentVersion: 2,
        intentExpiresAt: '2026-08-08T01:00:00+00:00',
        requeuedJobCount: 1,
        duplicate: false,
      ),
    );
    final ProviderBillingAssignmentRepository repository =
        ProviderBillingAssignmentRepository(dataSource);

    final BillingAssignmentResult<BillingAssignmentPreparation> result =
        await repository.prepare(
          householdId: householdId,
          commandId: commandId,
        );

    final BillingAssignmentPreparation preparation =
        (result as BillingAssignmentSucceeded<BillingAssignmentPreparation>)
            .value;
    expect(preparation.outcome, BillingAssignmentPrepareOutcome.ready);
    expect(preparation.bindingState, BillingAssignmentBindingState.provisional);
    expect(preparation.requeuedJobCount, 1);
    expect(dataSource.prepareHouseholdId, householdId.value);
    expect(dataSource.prepareCommandId, commandId.value);
  });

  test('conflict record cannot smuggle assignment metadata', () async {
    final ProviderBillingAssignmentRepository repository =
        ProviderBillingAssignmentRepository(
          _FakeDataSource(
            prepareRecord: const BillingAssignmentPrepareDataRecord(
              intentId: '81000000-0000-4000-8000-000000000002',
              outcome: 'customer_conflict',
              bindingState: 'confirmed',
              assignmentVersion: 9,
              intentExpiresAt: null,
              requeuedJobCount: 0,
              duplicate: false,
            ),
          ),
        );

    final BillingAssignmentResult<BillingAssignmentPreparation> result =
        await repository.prepare(
          householdId: householdId,
          commandId: commandId,
        );

    expect(
      result,
      isA<BillingAssignmentFailed<BillingAssignmentPreparation>>(),
    );
    expect(
      (result as BillingAssignmentFailed<BillingAssignmentPreparation>)
          .failure
          .kind,
      BillingAssignmentFailureKind.invalidPayload,
    );
  });

  test('status rejects cross-household and local timestamps', () async {
    for (final BillingAssignmentStatusDataRecord record
        in <BillingAssignmentStatusDataRecord>[
          _statusRecord(householdId: '20000000-0000-4000-8000-000000000201'),
          _statusRecord(intentExpiresAt: '2026-08-08T01:00:00'),
        ]) {
      final ProviderBillingAssignmentRepository repository =
          ProviderBillingAssignmentRepository(
            _FakeDataSource(statusRecord: record),
          );
      final BillingAssignmentResult<BillingHouseholdAssignmentStatus> result =
          await repository.status(householdId);
      expect(
        result,
        isA<BillingAssignmentFailed<BillingHouseholdAssignmentStatus>>(),
      );
    }
  });

  test(
    'release and remediation retain provider-neutral stable values',
    () async {
      final _FakeDataSource dataSource = _FakeDataSource(
        releaseRecord: const BillingAssignmentReleaseDataRecord(
          outcome: 'released',
          assignmentVersion: 4,
          duplicate: false,
        ),
        remediationRecord: const BillingAssignmentRemediationDataRecord(
          requestId: '82000000-0000-4000-8000-000000000001',
          status: 'open',
          issueKind: 'restore_conflict',
          duplicate: false,
        ),
      );
      final ProviderBillingAssignmentRepository repository =
          ProviderBillingAssignmentRepository(dataSource);

      final BillingAssignmentRelease release =
          (await repository.release(
                    householdId: householdId,
                    expectedAssignmentVersion: 3,
                    commandId: commandId,
                  )
                  as BillingAssignmentSucceeded<BillingAssignmentRelease>)
              .value;
      final BillingAssignmentRemediationRequest request =
          (await repository.requestRemediation(
                    householdId: householdId,
                    issue: BillingAssignmentRemediationIssue.restoreConflict,
                    commandId: commandId,
                  )
                  as BillingAssignmentSucceeded<
                    BillingAssignmentRemediationRequest
                  >)
              .value;

      expect(release.outcome, BillingAssignmentReleaseOutcome.released);
      expect(request.status, BillingAssignmentRemediationStatus.open);
      expect(request.issue, BillingAssignmentRemediationIssue.restoreConflict);
    },
  );

  test('data source failures map to bounded domain categories', () async {
    final ProviderBillingAssignmentRepository repository =
        ProviderBillingAssignmentRepository(
          _FakeDataSource(
            failure: BillingAssignmentDataFailureKind.versionConflict,
          ),
        );

    final BillingAssignmentResult<BillingAssignmentPreparation> result =
        await repository.prepare(
          householdId: householdId,
          commandId: commandId,
        );

    expect(
      (result as BillingAssignmentFailed<BillingAssignmentPreparation>)
          .failure
          .kind,
      BillingAssignmentFailureKind.versionConflict,
    );
  });
}

BillingAssignmentStatusDataRecord _statusRecord({
  String householdId = '20000000-0000-4000-8000-000000000101',
  String intentExpiresAt = '2026-08-08T01:00:00Z',
}) {
  return BillingAssignmentStatusDataRecord(
    householdId: householdId,
    assignmentState: 'provisional',
    ownershipState: 'current_user',
    ownerMembershipState: 'active',
    canPrepare: true,
    requiresSupport: false,
    assignmentVersion: 2,
    intentExpiresAt: intentExpiresAt,
  );
}

final class _FakeDataSource implements BillingAssignmentDataSource {
  _FakeDataSource({
    this.prepareRecord,
    this.releaseRecord,
    this.statusRecord,
    this.remediationRecord,
    this.failure,
  });

  final BillingAssignmentPrepareDataRecord? prepareRecord;
  final BillingAssignmentReleaseDataRecord? releaseRecord;
  final BillingAssignmentStatusDataRecord? statusRecord;
  final BillingAssignmentRemediationDataRecord? remediationRecord;
  final BillingAssignmentDataFailureKind? failure;
  String? prepareHouseholdId;
  String? prepareCommandId;

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentPrepareDataRecord>>
  prepare({required String householdId, required String idempotencyKey}) async {
    prepareHouseholdId = householdId;
    prepareCommandId = idempotencyKey;
    return failure == null
        ? BillingAssignmentDataSucceeded<BillingAssignmentPrepareDataRecord>(
            prepareRecord!,
          )
        : BillingAssignmentDataFailed<BillingAssignmentPrepareDataRecord>(
            failure!,
          );
  }

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentReleaseDataRecord>>
  release({
    required String householdId,
    required int expectedAssignmentVersion,
    required String idempotencyKey,
  }) async =>
      BillingAssignmentDataSucceeded<BillingAssignmentReleaseDataRecord>(
        releaseRecord!,
      );

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentStatusDataRecord>>
  status({required String householdId}) async =>
      BillingAssignmentDataSucceeded<BillingAssignmentStatusDataRecord>(
        statusRecord!,
      );

  @override
  Future<BillingAssignmentDataResult<BillingAssignmentRemediationDataRecord>>
  requestRemediation({
    required String householdId,
    required String issueKind,
    required String idempotencyKey,
  }) async =>
      BillingAssignmentDataSucceeded<BillingAssignmentRemediationDataRecord>(
        remediationRecord!,
      );
}
