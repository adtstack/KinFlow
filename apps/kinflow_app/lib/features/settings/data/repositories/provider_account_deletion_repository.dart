import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/data/datasources/account_deletion_data_source.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

final class ProviderAccountDeletionRepository
    implements AccountDeletionRepository {
  const ProviderAccountDeletionRepository(this._dataSource);

  final AccountDeletionDataSource _dataSource;

  @override
  Future<AccountDeletionResult<AccountDeletionPreflight>>
  loadPreflight() async {
    final AccountDeletionDataResult<AccountDeletionPreflightDataRecord> result =
        await _dataSource.preflight();
    return switch (result) {
      AccountDeletionDataSucceeded<AccountDeletionPreflightDataRecord>(
        :final value,
      ) =>
        _preflight(value),
      AccountDeletionDataFailed<AccountDeletionPreflightDataRecord>(
        :final kind,
      ) =>
        AccountDeletionFailed<AccountDeletionPreflight>(_failure(kind)),
    };
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest?>> loadLatest({
    AccountDeletionRequestId? requestId,
  }) async {
    final AccountDeletionDataResult<AccountDeletionRequestDataRecord?> result =
        await _dataSource.status(requestId: requestId?.value);
    return switch (result) {
      AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord?>(
        :final value,
      ) =>
        value == null
            ? const AccountDeletionSucceeded<AccountDeletionRequest?>(null)
            : _nullableRequest(value),
      AccountDeletionDataFailed<AccountDeletionRequestDataRecord?>(
        :final kind,
      ) =>
        AccountDeletionFailed<AccountDeletionRequest?>(_failure(kind)),
    };
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> requestDeletion({
    required bool subscriptionAcknowledged,
    required RecentAuthenticationProof recentAuthenticationProof,
    required AccountDeletionCommandId commandId,
  }) async {
    final AccountDeletionDataResult<AccountDeletionRequestDataRecord> result =
        await _dataSource.request(
          subscriptionAcknowledged: subscriptionAcknowledged,
          recentAuthenticationProof: recentAuthenticationProof.value,
          idempotencyKey: commandId.value,
        );
    return _requestResult(result);
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> cancel({
    required AccountDeletionRequestId requestId,
    required int expectedVersion,
    required AccountDeletionCommandId commandId,
  }) async {
    final AccountDeletionDataResult<AccountDeletionRequestDataRecord> result =
        await _dataSource.cancel(
          requestId: requestId.value,
          expectedVersion: expectedVersion,
          idempotencyKey: commandId.value,
        );
    return _requestResult(result);
  }

  AccountDeletionResult<AccountDeletionPreflight> _preflight(
    AccountDeletionPreflightDataRecord record,
  ) {
    final AccountDeletionRequestId? pendingId = record.pendingRequestId == null
        ? null
        : AccountDeletionRequestId.tryParse(record.pendingRequestId!);
    final AccountDeletionRequestStatus? pendingStatus =
        record.pendingStatus == null
        ? null
        : AccountDeletionRequestStatus.tryParse(record.pendingStatus!);
    final DateTime? evaluatedAt = _utc(record.evaluatedAt);
    final AccountDeletionPreflight? preflight = evaluatedAt == null
        ? null
        : AccountDeletionPreflight.tryCreate(
            canRequest: record.canRequest,
            ownerHouseholdCount: record.ownerHouseholdCount,
            hasActiveSubscription: record.hasActiveSubscription,
            pendingRequestId: pendingId,
            pendingStatus: pendingStatus,
            pendingRequestVersion: record.pendingRequestVersion,
            requestsEnabled: record.requestsEnabled,
            cancellationWindow: Duration(
              seconds: record.cancellationWindowSeconds,
            ),
            evaluatedAt: evaluatedAt,
          );
    return preflight == null
        ? _invalid<AccountDeletionPreflight>()
        : AccountDeletionSucceeded<AccountDeletionPreflight>(preflight);
  }

  AccountDeletionResult<AccountDeletionRequest?> _nullableRequest(
    AccountDeletionRequestDataRecord record,
  ) {
    final AccountDeletionRequest? request = _mapRequest(record);
    return request == null
        ? _invalid<AccountDeletionRequest?>()
        : AccountDeletionSucceeded<AccountDeletionRequest?>(request);
  }

  AccountDeletionResult<AccountDeletionRequest> _requestResult(
    AccountDeletionDataResult<AccountDeletionRequestDataRecord> result,
  ) {
    return switch (result) {
      AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord>(
        :final value,
      ) =>
        _mappedRequestResult(value),
      AccountDeletionDataFailed<AccountDeletionRequestDataRecord>(
        :final kind,
      ) =>
        AccountDeletionFailed<AccountDeletionRequest>(_failure(kind)),
    };
  }

  AccountDeletionRequest? _mapRequest(AccountDeletionRequestDataRecord record) {
    final AccountDeletionRequestId? id = AccountDeletionRequestId.tryParse(
      record.id,
    );
    final AccountDeletionRequestStatus? status =
        AccountDeletionRequestStatus.tryParse(record.status);
    final DateTime? requestedAt = _utc(record.requestedAt);
    final DateTime? scheduledFor = _utc(record.scheduledFor);
    if (record.type != 'deleteAccount' ||
        id == null ||
        status == null ||
        requestedAt == null ||
        scheduledFor == null ||
        !_validOptionalUtc(record.processingStartedAt) ||
        !_validOptionalUtc(record.completedAt) ||
        !_validOptionalUtc(record.failedAt) ||
        !_validOptionalUtc(record.cancelledAt)) {
      return null;
    }
    return AccountDeletionRequest.tryCreate(
      id: id,
      status: status,
      requestedAt: requestedAt,
      scheduledFor: scheduledFor,
      processingStartedAt: _nullableUtc(record.processingStartedAt),
      completedAt: _nullableUtc(record.completedAt),
      failedAt: _nullableUtc(record.failedAt),
      cancelledAt: _nullableUtc(record.cancelledAt),
      failureCode: record.failureCode,
      activeSubscriptionAtRequest: record.activeSubscriptionAtRequest,
      subscriptionAcknowledged: record.subscriptionAcknowledged,
      cancellable: record.cancellable,
      version: record.version,
    );
  }

  AccountDeletionResult<AccountDeletionRequest> _mappedRequestResult(
    AccountDeletionRequestDataRecord record,
  ) {
    final AccountDeletionRequest? request = _mapRequest(record);
    return request == null
        ? _invalid<AccountDeletionRequest>()
        : AccountDeletionSucceeded<AccountDeletionRequest>(request);
  }

  bool _validOptionalUtc(String? value) => value == null || _utc(value) != null;

  DateTime? _nullableUtc(String? value) {
    return value == null ? null : _utc(value);
  }

  DateTime? _utc(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed?.isUtc == true ? parsed : null;
  }

  AccountDeletionResult<T> _invalid<T>() {
    return AccountDeletionFailed<T>(
      AccountDeletionFailure(AccountDeletionFailureKind.invalidPayload),
    );
  }

  AccountDeletionFailure _failure(AccountDeletionDataFailureKind kind) {
    return AccountDeletionFailure(switch (kind) {
      AccountDeletionDataFailureKind.unauthenticated =>
        AccountDeletionFailureKind.unauthenticated,
      AccountDeletionDataFailureKind.invalidInput =>
        AccountDeletionFailureKind.invalidInput,
      AccountDeletionDataFailureKind.permissionDenied =>
        AccountDeletionFailureKind.permissionDenied,
      AccountDeletionDataFailureKind.recentAuthenticationRequired =>
        AccountDeletionFailureKind.recentAuthenticationRequired,
      AccountDeletionDataFailureKind.requestsPaused =>
        AccountDeletionFailureKind.requestsPaused,
      AccountDeletionDataFailureKind.idempotencyConflict =>
        AccountDeletionFailureKind.idempotencyConflict,
      AccountDeletionDataFailureKind.alreadyPending =>
        AccountDeletionFailureKind.alreadyPending,
      AccountDeletionDataFailureKind.notFound =>
        AccountDeletionFailureKind.notFound,
      AccountDeletionDataFailureKind.versionConflict =>
        AccountDeletionFailureKind.versionConflict,
      AccountDeletionDataFailureKind.ownerTransferRequired =>
        AccountDeletionFailureKind.ownerTransferRequired,
      AccountDeletionDataFailureKind.subscriptionAcknowledgementRequired =>
        AccountDeletionFailureKind.subscriptionAcknowledgementRequired,
      AccountDeletionDataFailureKind.notCancellable =>
        AccountDeletionFailureKind.notCancellable,
      AccountDeletionDataFailureKind.temporarilyUnavailable =>
        AccountDeletionFailureKind.temporarilyUnavailable,
      AccountDeletionDataFailureKind.invalidPayload =>
        AccountDeletionFailureKind.invalidPayload,
      AccountDeletionDataFailureKind.unknown =>
        AccountDeletionFailureKind.unknown,
    });
  }
}
