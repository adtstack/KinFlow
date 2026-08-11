import 'package:kinflow_app/features/billing/data/datasources/billing_assignment_data_source.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_assignment_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _utcOffsetPattern = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$');

final class ProviderBillingAssignmentRepository
    implements BillingAssignmentRepository {
  const ProviderBillingAssignmentRepository(this._dataSource);

  final BillingAssignmentDataSource _dataSource;

  @override
  Future<BillingAssignmentResult<BillingAssignmentPreparation>> prepare({
    required HouseholdId householdId,
    required BillingAssignmentCommandId commandId,
  }) async {
    final BillingAssignmentDataResult<BillingAssignmentPrepareDataRecord>
    result = await _dataSource.prepare(
      householdId: householdId.value,
      idempotencyKey: commandId.value,
    );
    return switch (result) {
      BillingAssignmentDataSucceeded<BillingAssignmentPrepareDataRecord>(
        :final value,
      ) =>
        _prepare(value),
      BillingAssignmentDataFailed<BillingAssignmentPrepareDataRecord>(
        :final kind,
      ) =>
        BillingAssignmentFailed<BillingAssignmentPreparation>(_failure(kind)),
    };
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRelease>> release({
    required HouseholdId householdId,
    required int expectedAssignmentVersion,
    required BillingAssignmentCommandId commandId,
  }) async {
    final BillingAssignmentDataResult<BillingAssignmentReleaseDataRecord>
    result = await _dataSource.release(
      householdId: householdId.value,
      expectedAssignmentVersion: expectedAssignmentVersion,
      idempotencyKey: commandId.value,
    );
    return switch (result) {
      BillingAssignmentDataSucceeded<BillingAssignmentReleaseDataRecord>(
        :final value,
      ) =>
        _release(value),
      BillingAssignmentDataFailed<BillingAssignmentReleaseDataRecord>(
        :final kind,
      ) =>
        BillingAssignmentFailed<BillingAssignmentRelease>(_failure(kind)),
    };
  }

  @override
  Future<BillingAssignmentResult<BillingHouseholdAssignmentStatus>> status(
    HouseholdId householdId,
  ) async {
    final BillingAssignmentDataResult<BillingAssignmentStatusDataRecord>
    result = await _dataSource.status(householdId: householdId.value);
    return switch (result) {
      BillingAssignmentDataSucceeded<BillingAssignmentStatusDataRecord>(
        :final value,
      ) =>
        _status(value, householdId),
      BillingAssignmentDataFailed<BillingAssignmentStatusDataRecord>(
        :final kind,
      ) =>
        BillingAssignmentFailed<BillingHouseholdAssignmentStatus>(
          _failure(kind),
        ),
    };
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRemediationRequest>>
  requestRemediation({
    required HouseholdId householdId,
    required BillingAssignmentRemediationIssue issue,
    required BillingAssignmentCommandId commandId,
  }) async {
    final BillingAssignmentDataResult<BillingAssignmentRemediationDataRecord>
    result = await _dataSource.requestRemediation(
      householdId: householdId.value,
      issueKind: issue.wireValue,
      idempotencyKey: commandId.value,
    );
    return switch (result) {
      BillingAssignmentDataSucceeded<BillingAssignmentRemediationDataRecord>(
        :final value,
      ) =>
        _remediation(value),
      BillingAssignmentDataFailed<BillingAssignmentRemediationDataRecord>(
        :final kind,
      ) =>
        BillingAssignmentFailed<BillingAssignmentRemediationRequest>(
          _failure(kind),
        ),
    };
  }
}

BillingAssignmentResult<BillingAssignmentPreparation> _prepare(
  BillingAssignmentPrepareDataRecord record,
) {
  final BillingAssignmentPrepareOutcome? outcome =
      BillingAssignmentPrepareOutcome.tryParse(record.outcome);
  final BillingAssignmentBindingState? bindingState =
      record.bindingState == null
      ? null
      : BillingAssignmentBindingState.tryParse(record.bindingState!);
  final DateTime? expiresAt = record.intentExpiresAt == null
      ? null
      : _utcInstant(record.intentExpiresAt!);
  if (outcome == null ||
      record.bindingState != null && bindingState == null ||
      record.intentExpiresAt != null && expiresAt == null) {
    return const BillingAssignmentFailed<BillingAssignmentPreparation>(
      BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
    );
  }
  final BillingAssignmentPreparation? preparation =
      BillingAssignmentPreparation.tryCreate(
        intentId: record.intentId,
        outcome: outcome,
        bindingState: bindingState,
        assignmentVersion: record.assignmentVersion,
        intentExpiresAt: expiresAt,
        requeuedJobCount: record.requeuedJobCount,
        duplicate: record.duplicate,
      );
  return preparation == null
      ? const BillingAssignmentFailed<BillingAssignmentPreparation>(
          BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
        )
      : BillingAssignmentSucceeded<BillingAssignmentPreparation>(preparation);
}

BillingAssignmentResult<BillingAssignmentRelease> _release(
  BillingAssignmentReleaseDataRecord record,
) {
  final BillingAssignmentReleaseOutcome? outcome =
      BillingAssignmentReleaseOutcome.tryParse(record.outcome);
  if (outcome == null ||
      record.assignmentVersion != null && record.assignmentVersion! < 1 ||
      outcome != BillingAssignmentReleaseOutcome.alreadyReleased &&
          record.assignmentVersion == null) {
    return const BillingAssignmentFailed<BillingAssignmentRelease>(
      BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
    );
  }
  return BillingAssignmentSucceeded<BillingAssignmentRelease>(
    BillingAssignmentRelease(
      outcome: outcome,
      assignmentVersion: record.assignmentVersion,
      duplicate: record.duplicate,
    ),
  );
}

BillingAssignmentResult<BillingHouseholdAssignmentStatus> _status(
  BillingAssignmentStatusDataRecord record,
  HouseholdId expectedHouseholdId,
) {
  final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
  final BillingAssignmentState? assignmentState =
      BillingAssignmentState.tryParse(record.assignmentState);
  final BillingAssignmentOwnershipState? ownershipState =
      BillingAssignmentOwnershipState.tryParse(record.ownershipState);
  final BillingAssignmentOwnerMembershipState? ownerMembershipState =
      BillingAssignmentOwnerMembershipState.tryParse(
        record.ownerMembershipState,
      );
  final DateTime? expiresAt = record.intentExpiresAt == null
      ? null
      : _utcInstant(record.intentExpiresAt!);
  if (householdId != expectedHouseholdId ||
      assignmentState == null ||
      ownershipState == null ||
      ownerMembershipState == null ||
      record.intentExpiresAt != null && expiresAt == null) {
    return const BillingAssignmentFailed<BillingHouseholdAssignmentStatus>(
      BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
    );
  }
  final BillingHouseholdAssignmentStatus? status =
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId!,
        assignmentState: assignmentState,
        ownershipState: ownershipState,
        ownerMembershipState: ownerMembershipState,
        canPrepare: record.canPrepare,
        requiresSupport: record.requiresSupport,
        assignmentVersion: record.assignmentVersion,
        intentExpiresAt: expiresAt,
      );
  return status == null
      ? const BillingAssignmentFailed<BillingHouseholdAssignmentStatus>(
          BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
        )
      : BillingAssignmentSucceeded<BillingHouseholdAssignmentStatus>(status);
}

BillingAssignmentResult<BillingAssignmentRemediationRequest> _remediation(
  BillingAssignmentRemediationDataRecord record,
) {
  final BillingAssignmentRemediationStatus? status =
      BillingAssignmentRemediationStatus.tryParse(record.status);
  final BillingAssignmentRemediationIssue? issue =
      BillingAssignmentRemediationIssue.tryParse(record.issueKind);
  if (status == null || issue == null) {
    return const BillingAssignmentFailed<BillingAssignmentRemediationRequest>(
      BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
    );
  }
  final BillingAssignmentRemediationRequest? request =
      BillingAssignmentRemediationRequest.tryCreate(
        requestId: record.requestId,
        status: status,
        issue: issue,
        duplicate: record.duplicate,
      );
  return request == null
      ? const BillingAssignmentFailed<BillingAssignmentRemediationRequest>(
          BillingAssignmentFailure(BillingAssignmentFailureKind.invalidPayload),
        )
      : BillingAssignmentSucceeded<BillingAssignmentRemediationRequest>(
          request,
        );
}

DateTime? _utcInstant(String value) {
  if (!_utcOffsetPattern.hasMatch(value)) return null;
  return DateTime.tryParse(value)?.toUtc();
}

BillingAssignmentFailure _failure(BillingAssignmentDataFailureKind kind) {
  return BillingAssignmentFailure(switch (kind) {
    BillingAssignmentDataFailureKind.unauthenticated =>
      BillingAssignmentFailureKind.unauthenticated,
    BillingAssignmentDataFailureKind.invalidInput =>
      BillingAssignmentFailureKind.invalidInput,
    BillingAssignmentDataFailureKind.authorization =>
      BillingAssignmentFailureKind.authorization,
    BillingAssignmentDataFailureKind.versionConflict =>
      BillingAssignmentFailureKind.versionConflict,
    BillingAssignmentDataFailureKind.temporarilyUnavailable =>
      BillingAssignmentFailureKind.temporarilyUnavailable,
    BillingAssignmentDataFailureKind.invalidPayload =>
      BillingAssignmentFailureKind.invalidPayload,
    BillingAssignmentDataFailureKind.unknown =>
      BillingAssignmentFailureKind.unknown,
  });
}
