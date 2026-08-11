import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/data/datasources/household_privacy_data_source.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/household_privacy_identifiers.dart';

final class ProviderHouseholdPrivacyRepository
    implements HouseholdPrivacyRepository {
  const ProviderHouseholdPrivacyRepository(this._dataSource);

  final HouseholdPrivacyDataSource _dataSource;

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyPreflight>> loadPreflight(
    HouseholdId householdId,
  ) async {
    final result = await _dataSource.preflight(householdId.value);
    return switch (result) {
      HouseholdPrivacyDataSucceeded<HouseholdPrivacyPreflightDataRecord>(
        :final value,
      ) =>
        _preflight(value),
      HouseholdPrivacyDataFailed<HouseholdPrivacyPreflightDataRecord>(
        :final kind,
      ) =>
        HouseholdPrivacyFailed<HouseholdPrivacyPreflight>(_failure(kind)),
    };
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> loadStatus(
    HouseholdPrivacyRequestId requestId,
  ) async {
    return _requestResult(await _dataSource.status(requestId.value));
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestExport({
    required HouseholdId householdId,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.requestExport(
        householdId: householdId.value,
        recentAuthenticationProof: recentAuthenticationProof.value,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestDeletion({
    required HouseholdId householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.requestDeletion(
        householdId: householdId.value,
        expectedHouseholdVersion: expectedHouseholdVersion,
        confirmationName: confirmationName,
        acknowledgeMemberAccessLoss: acknowledgeMemberAccessLoss,
        acknowledgeSharedDataRedaction: acknowledgeSharedDataRedaction,
        acknowledgeSubscriptionNotCancelled:
            acknowledgeSubscriptionNotCancelled,
        recentAuthenticationProof: recentAuthenticationProof.value,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> cancel({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdPrivacyRequestKind kind,
    required int expectedVersion,
    required HouseholdCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.cancel(
        requestId: requestId.value,
        kind: kind.wireValue,
        expectedVersion: expectedVersion,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> revokeExport({
    required HouseholdPrivacyRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.revokeExport(
        requestId: requestId.value,
        expectedArtifactVersion: expectedArtifactVersion,
        recentAuthenticationProof: recentAuthenticationProof.value,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdExportDownload>> createDownload({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async {
    final result = await _dataSource.download(
      requestId: requestId.value,
      format: format.wireValue,
      recentAuthenticationProof: recentAuthenticationProof.value,
    );
    return switch (result) {
      HouseholdPrivacyDataSucceeded<HouseholdExportDownloadDataRecord>(
        :final value,
      ) =>
        _download(value),
      HouseholdPrivacyDataFailed<HouseholdExportDownloadDataRecord>(
        :final kind,
      ) =>
        HouseholdPrivacyFailed<HouseholdExportDownload>(_failure(kind)),
    };
  }

  HouseholdPrivacyResult<HouseholdPrivacyPreflight> _preflight(
    HouseholdPrivacyPreflightDataRecord record,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.household.id);
    final HouseholdPrivacyHousehold? household = householdId == null
        ? null
        : HouseholdPrivacyHousehold.tryCreate(
            id: householdId,
            name: record.household.name,
            version: record.household.version,
          );
    final HouseholdPrivacyRequest? pending = record.pendingRequest == null
        ? null
        : _mapRequest(record.pendingRequest!);
    final DateTime? evaluatedAt = _utc(record.evaluatedAt);
    if (household == null ||
        evaluatedAt == null ||
        record.pendingRequest != null && pending == null ||
        !_validOptionalUtc(record.retentionReviewAt)) {
      return _invalid<HouseholdPrivacyPreflight>();
    }
    final HouseholdPrivacyPreflight? value =
        HouseholdPrivacyPreflight.tryCreate(
          household: household,
          memberCount: record.memberCount,
          activeSubscription: record.activeSubscription,
          canExport: record.canExport,
          canDelete: record.canDelete,
          conflictingRequestPending: record.conflictingRequestPending,
          pendingRequest: pending,
          exportRequestsEnabled: record.exportRequestsEnabled,
          deletionRequestsEnabled: record.deletionRequestsEnabled,
          downloadsEnabled: record.downloadsEnabled,
          artifactRetention: Duration(seconds: record.artifactTtlSeconds),
          downloadGrantLifetime: Duration(
            seconds: record.downloadGrantTtlSeconds,
          ),
          deletionCancellationWindow: Duration(
            seconds: record.deletionCancellationWindowSeconds,
          ),
          retentionBlocked: record.retentionBlocked,
          retentionReviewAt: _nullableUtc(record.retentionReviewAt),
          evaluatedAt: evaluatedAt,
        );
    return value == null
        ? _invalid<HouseholdPrivacyPreflight>()
        : HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(value);
  }

  HouseholdPrivacyResult<HouseholdPrivacyRequest> _requestResult(
    HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord> result,
  ) {
    return switch (result) {
      HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
        :final value,
      ) =>
        _mappedRequest(value),
      HouseholdPrivacyDataFailed<HouseholdPrivacyRequestDataRecord>(
        :final kind,
      ) =>
        HouseholdPrivacyFailed<HouseholdPrivacyRequest>(_failure(kind)),
    };
  }

  HouseholdPrivacyResult<HouseholdPrivacyRequest> _mappedRequest(
    HouseholdPrivacyRequestDataRecord record,
  ) {
    final HouseholdPrivacyRequest? value = _mapRequest(record);
    return value == null
        ? _invalid<HouseholdPrivacyRequest>()
        : HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(value);
  }

  HouseholdPrivacyRequest? _mapRequest(
    HouseholdPrivacyRequestDataRecord record,
  ) {
    final HouseholdPrivacyRequestId? id = HouseholdPrivacyRequestId.tryParse(
      record.requestId,
    );
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final HouseholdPrivacyRequestKind? kind =
        HouseholdPrivacyRequestKind.tryParse(record.kind);
    final HouseholdPrivacyRequestStatus? status =
        HouseholdPrivacyRequestStatus.tryParse(record.status);
    final DateTime? requestedAt = _utc(record.requestedAt);
    final DateTime? scheduledFor = _utc(record.scheduledFor);
    final HouseholdExportArtifact? artifact = record.artifact == null
        ? null
        : _mapArtifact(record.artifact!);
    final HouseholdDeletionProgress? deletion = record.deletion == null
        ? null
        : _mapDeletion(record.deletion!);
    if (id == null ||
        householdId == null ||
        kind == null ||
        status == null ||
        requestedAt == null ||
        scheduledFor == null ||
        record.artifact != null && artifact == null ||
        record.deletion != null && deletion == null ||
        !_validOptionalUtc(record.processingStartedAt) ||
        !_validOptionalUtc(record.completedAt) ||
        !_validOptionalUtc(record.failedAt) ||
        !_validOptionalUtc(record.cancelledAt)) {
      return null;
    }
    return HouseholdPrivacyRequest.tryCreate(
      id: id,
      kind: kind,
      householdId: householdId,
      status: status,
      requestedAt: requestedAt,
      scheduledFor: scheduledFor,
      processingStartedAt: _nullableUtc(record.processingStartedAt),
      completedAt: _nullableUtc(record.completedAt),
      failedAt: _nullableUtc(record.failedAt),
      cancelledAt: _nullableUtc(record.cancelledAt),
      failureCode: record.failureCode,
      cancellable: record.cancellable,
      version: record.version,
      activeSubscriptionAtRequest: record.activeSubscriptionAtRequest,
      artifact: artifact,
      deletion: deletion,
    );
  }

  HouseholdExportArtifact? _mapArtifact(
    HouseholdExportArtifactDataRecord record,
  ) {
    final HouseholdExportArtifactId? id = HouseholdExportArtifactId.tryParse(
      record.id,
    );
    if (id == null ||
        !_validOptionalUtc(record.expiresAt) ||
        !_validOptionalUtc(record.revokedAt) ||
        !_validOptionalUtc(record.purgedAt)) {
      return null;
    }
    return HouseholdExportArtifact.tryCreate(
      id: id,
      version: record.version,
      schemaVersion: record.schemaVersion,
      expiresAt: _nullableUtc(record.expiresAt),
      revokedAt: _nullableUtc(record.revokedAt),
      purgedAt: _nullableUtc(record.purgedAt),
      machineSizeBytes: record.machineSizeBytes,
      humanSizeBytes: record.humanSizeBytes,
      available: record.available,
    );
  }

  HouseholdDeletionProgress? _mapDeletion(
    HouseholdDeletionProgressDataRecord record,
  ) {
    if (!_validOptionalUtc(record.retentionReviewAt) ||
        !_validOptionalUtc(record.accessRevokedAt) ||
        !_validOptionalUtc(record.redactedAt) ||
        !_validOptionalUtc(record.billingUnlinkedAt)) {
      return null;
    }
    return HouseholdDeletionProgress.tryCreate(
      retentionBlocked: record.retentionBlocked,
      retentionReviewAt: _nullableUtc(record.retentionReviewAt),
      accessRevokedAt: _nullableUtc(record.accessRevokedAt),
      redactedAt: _nullableUtc(record.redactedAt),
      billingUnlinkedAt: _nullableUtc(record.billingUnlinkedAt),
    );
  }

  HouseholdPrivacyResult<HouseholdExportDownload> _download(
    HouseholdExportDownloadDataRecord record,
  ) {
    final HouseholdExportFormat? format = HouseholdExportFormat.tryParse(
      record.format,
    );
    final DateTime? expiresAt = _utc(record.expiresAt);
    final Uri? uri = Uri.tryParse(record.downloadUrl);
    final HouseholdExportDownload? value =
        format == null || expiresAt == null || uri == null
        ? null
        : HouseholdExportDownload.tryCreate(
            format: format,
            expiresAt: expiresAt,
            uri: uri,
          );
    return value == null
        ? _invalid<HouseholdExportDownload>()
        : HouseholdPrivacySucceeded<HouseholdExportDownload>(value);
  }

  bool _validOptionalUtc(String? value) => value == null || _utc(value) != null;

  DateTime? _nullableUtc(String? value) => value == null ? null : _utc(value);

  DateTime? _utc(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed?.isUtc == true ? parsed : null;
  }

  HouseholdPrivacyResult<T> _invalid<T>() => HouseholdPrivacyFailed<T>(
    const HouseholdPrivacyFailure(HouseholdPrivacyFailureKind.invalidPayload),
  );

  HouseholdPrivacyFailure _failure(HouseholdPrivacyDataFailureKind kind) {
    return HouseholdPrivacyFailure(switch (kind) {
      HouseholdPrivacyDataFailureKind.unauthenticated =>
        HouseholdPrivacyFailureKind.unauthenticated,
      HouseholdPrivacyDataFailureKind.invalidInput =>
        HouseholdPrivacyFailureKind.invalidInput,
      HouseholdPrivacyDataFailureKind.ownerRequired =>
        HouseholdPrivacyFailureKind.ownerRequired,
      HouseholdPrivacyDataFailureKind.recentAuthenticationRequired =>
        HouseholdPrivacyFailureKind.recentAuthenticationRequired,
      HouseholdPrivacyDataFailureKind.exportRequestsPaused =>
        HouseholdPrivacyFailureKind.exportRequestsPaused,
      HouseholdPrivacyDataFailureKind.deletionRequestsPaused =>
        HouseholdPrivacyFailureKind.deletionRequestsPaused,
      HouseholdPrivacyDataFailureKind.downloadsPaused =>
        HouseholdPrivacyFailureKind.downloadsPaused,
      HouseholdPrivacyDataFailureKind.idempotencyConflict =>
        HouseholdPrivacyFailureKind.idempotencyConflict,
      HouseholdPrivacyDataFailureKind.alreadyPending =>
        HouseholdPrivacyFailureKind.alreadyPending,
      HouseholdPrivacyDataFailureKind.notFound =>
        HouseholdPrivacyFailureKind.notFound,
      HouseholdPrivacyDataFailureKind.versionConflict =>
        HouseholdPrivacyFailureKind.versionConflict,
      HouseholdPrivacyDataFailureKind.requestNotMutable =>
        HouseholdPrivacyFailureKind.requestNotMutable,
      HouseholdPrivacyDataFailureKind.confirmationMismatch =>
        HouseholdPrivacyFailureKind.confirmationMismatch,
      HouseholdPrivacyDataFailureKind.subscriptionAcknowledgmentRequired =>
        HouseholdPrivacyFailureKind.subscriptionAcknowledgmentRequired,
      HouseholdPrivacyDataFailureKind.artifactUnavailable =>
        HouseholdPrivacyFailureKind.artifactUnavailable,
      HouseholdPrivacyDataFailureKind.householdAlreadyDeleted =>
        HouseholdPrivacyFailureKind.householdAlreadyDeleted,
      HouseholdPrivacyDataFailureKind.temporarilyUnavailable =>
        HouseholdPrivacyFailureKind.temporarilyUnavailable,
      HouseholdPrivacyDataFailureKind.invalidPayload =>
        HouseholdPrivacyFailureKind.invalidPayload,
      HouseholdPrivacyDataFailureKind.unknown =>
        HouseholdPrivacyFailureKind.unknown,
    });
  }
}
