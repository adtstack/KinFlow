import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/data/datasources/data_export_data_source.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

final class ProviderDataExportRepository implements DataExportRepository {
  const ProviderDataExportRepository(this._dataSource);

  final DataExportDataSource _dataSource;

  @override
  Future<DataExportResult<DataExportPreflight>> loadPreflight() async {
    final DataExportDataResult<DataExportPreflightDataRecord> result =
        await _dataSource.preflight();
    return switch (result) {
      DataExportDataSucceeded<DataExportPreflightDataRecord>(:final value) =>
        _preflight(value),
      DataExportDataFailed<DataExportPreflightDataRecord>(:final kind) =>
        DataExportFailed<DataExportPreflight>(_failure(kind)),
    };
  }

  @override
  Future<DataExportResult<DataExportRequest?>> loadLatest({
    DataExportRequestId? requestId,
  }) async {
    final DataExportDataResult<DataExportRequestDataRecord?> result =
        await _dataSource.status(requestId: requestId?.value);
    return switch (result) {
      DataExportDataSucceeded<DataExportRequestDataRecord?>(:final value) =>
        value == null
            ? const DataExportSucceeded<DataExportRequest?>(null)
            : _nullableRequest(value),
      DataExportDataFailed<DataExportRequestDataRecord?>(:final kind) =>
        DataExportFailed<DataExportRequest?>(_failure(kind)),
    };
  }

  @override
  Future<DataExportResult<DataExportRequest>> requestExport({
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.request(
        recentAuthenticationProof: recentAuthenticationProof.value,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<DataExportResult<DataExportRequest>> cancel({
    required DataExportRequestId requestId,
    required int expectedVersion,
    required DataExportCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.cancel(
        requestId: requestId.value,
        expectedVersion: expectedVersion,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<DataExportResult<DataExportRequest>> revoke({
    required DataExportRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    return _requestResult(
      await _dataSource.revoke(
        requestId: requestId.value,
        expectedArtifactVersion: expectedArtifactVersion,
        recentAuthenticationProof: recentAuthenticationProof.value,
        idempotencyKey: commandId.value,
      ),
    );
  }

  @override
  Future<DataExportResult<DataExportDownload>> createDownload({
    required DataExportRequestId requestId,
    required DataExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async {
    final DataExportDataResult<DataExportDownloadDataRecord> result =
        await _dataSource.download(
          requestId: requestId.value,
          format: format.wireValue,
          recentAuthenticationProof: recentAuthenticationProof.value,
        );
    return switch (result) {
      DataExportDataSucceeded<DataExportDownloadDataRecord>(:final value) =>
        _download(value),
      DataExportDataFailed<DataExportDownloadDataRecord>(:final kind) =>
        DataExportFailed<DataExportDownload>(_failure(kind)),
    };
  }

  DataExportResult<DataExportPreflight> _preflight(
    DataExportPreflightDataRecord record,
  ) {
    final DataExportRequestId? pendingId = record.pendingRequestId == null
        ? null
        : DataExportRequestId.tryParse(record.pendingRequestId!);
    final DataExportRequestStatus? pendingStatus = record.pendingStatus == null
        ? null
        : DataExportRequestStatus.tryParse(record.pendingStatus!);
    final DateTime? evaluatedAt = _utc(record.evaluatedAt);
    final DataExportPreflight? value = evaluatedAt == null
        ? null
        : DataExportPreflight.tryCreate(
            canRequest: record.canRequest,
            pendingRequestId: pendingId,
            pendingStatus: pendingStatus,
            pendingRequestVersion: record.pendingRequestVersion,
            conflictingRequestPending: record.conflictingRequestPending,
            requestsEnabled: record.requestsEnabled,
            downloadsEnabled: record.downloadsEnabled,
            artifactRetention: Duration(seconds: record.artifactTtlSeconds),
            downloadGrantLifetime: Duration(
              seconds: record.downloadGrantTtlSeconds,
            ),
            evaluatedAt: evaluatedAt,
          );
    return value == null
        ? _invalid<DataExportPreflight>()
        : DataExportSucceeded<DataExportPreflight>(value);
  }

  DataExportResult<DataExportRequest?> _nullableRequest(
    DataExportRequestDataRecord record,
  ) {
    final DataExportRequest? request = _mapRequest(record);
    return request == null
        ? _invalid<DataExportRequest?>()
        : DataExportSucceeded<DataExportRequest?>(request);
  }

  DataExportResult<DataExportRequest> _requestResult(
    DataExportDataResult<DataExportRequestDataRecord> result,
  ) {
    return switch (result) {
      DataExportDataSucceeded<DataExportRequestDataRecord>(:final value) =>
        _mappedRequest(value),
      DataExportDataFailed<DataExportRequestDataRecord>(:final kind) =>
        DataExportFailed<DataExportRequest>(_failure(kind)),
    };
  }

  DataExportResult<DataExportRequest> _mappedRequest(
    DataExportRequestDataRecord record,
  ) {
    final DataExportRequest? request = _mapRequest(record);
    return request == null
        ? _invalid<DataExportRequest>()
        : DataExportSucceeded<DataExportRequest>(request);
  }

  DataExportRequest? _mapRequest(DataExportRequestDataRecord record) {
    final DataExportRequestId? id = DataExportRequestId.tryParse(record.id);
    final DataExportRequestStatus? status = DataExportRequestStatus.tryParse(
      record.status,
    );
    final DateTime? requestedAt = _utc(record.requestedAt);
    final DataExportArtifact? artifact = _mapArtifact(record.artifact);
    if (id == null ||
        status == null ||
        requestedAt == null ||
        artifact == null ||
        !_validOptionalUtc(record.processingStartedAt) ||
        !_validOptionalUtc(record.completedAt) ||
        !_validOptionalUtc(record.failedAt) ||
        !_validOptionalUtc(record.cancelledAt)) {
      return null;
    }
    return DataExportRequest.tryCreate(
      id: id,
      status: status,
      requestedAt: requestedAt,
      processingStartedAt: _nullableUtc(record.processingStartedAt),
      completedAt: _nullableUtc(record.completedAt),
      failedAt: _nullableUtc(record.failedAt),
      cancelledAt: _nullableUtc(record.cancelledAt),
      failureCode: record.failureCode,
      cancellable: record.cancellable,
      version: record.version,
      artifact: artifact,
    );
  }

  DataExportArtifact? _mapArtifact(DataExportArtifactDataRecord record) {
    final DataExportArtifactId? id = DataExportArtifactId.tryParse(record.id);
    if (id == null ||
        !_validOptionalUtc(record.expiresAt) ||
        !_validOptionalUtc(record.revokedAt) ||
        !_validOptionalUtc(record.purgedAt)) {
      return null;
    }
    return DataExportArtifact.tryCreate(
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

  DataExportResult<DataExportDownload> _download(
    DataExportDownloadDataRecord record,
  ) {
    final DataExportFormat? format = DataExportFormat.tryParse(record.format);
    final DateTime? expiresAt = _utc(record.expiresAt);
    final Uri? uri = Uri.tryParse(record.downloadUrl);
    final DataExportDownload? value =
        format == null || expiresAt == null || uri == null
        ? null
        : DataExportDownload.tryCreate(
            format: format,
            expiresAt: expiresAt,
            uri: uri,
          );
    return value == null
        ? _invalid<DataExportDownload>()
        : DataExportSucceeded<DataExportDownload>(value);
  }

  bool _validOptionalUtc(String? value) => value == null || _utc(value) != null;

  DateTime? _nullableUtc(String? value) => value == null ? null : _utc(value);

  DateTime? _utc(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed?.isUtc == true ? parsed : null;
  }

  DataExportResult<T> _invalid<T>() {
    return DataExportFailed<T>(
      const DataExportFailure(DataExportFailureKind.invalidPayload),
    );
  }

  DataExportFailure _failure(DataExportDataFailureKind kind) {
    return DataExportFailure(switch (kind) {
      DataExportDataFailureKind.unauthenticated =>
        DataExportFailureKind.unauthenticated,
      DataExportDataFailureKind.invalidInput =>
        DataExportFailureKind.invalidInput,
      DataExportDataFailureKind.permissionDenied =>
        DataExportFailureKind.permissionDenied,
      DataExportDataFailureKind.recentAuthenticationRequired =>
        DataExportFailureKind.recentAuthenticationRequired,
      DataExportDataFailureKind.requestsPaused =>
        DataExportFailureKind.requestsPaused,
      DataExportDataFailureKind.downloadsPaused =>
        DataExportFailureKind.downloadsPaused,
      DataExportDataFailureKind.idempotencyConflict =>
        DataExportFailureKind.idempotencyConflict,
      DataExportDataFailureKind.alreadyPending =>
        DataExportFailureKind.alreadyPending,
      DataExportDataFailureKind.notFound => DataExportFailureKind.notFound,
      DataExportDataFailureKind.versionConflict =>
        DataExportFailureKind.versionConflict,
      DataExportDataFailureKind.notCancellable =>
        DataExportFailureKind.notCancellable,
      DataExportDataFailureKind.artifactUnavailable =>
        DataExportFailureKind.artifactUnavailable,
      DataExportDataFailureKind.exportTooLarge =>
        DataExportFailureKind.exportTooLarge,
      DataExportDataFailureKind.temporarilyUnavailable =>
        DataExportFailureKind.temporarilyUnavailable,
      DataExportDataFailureKind.invalidPayload =>
        DataExportFailureKind.invalidPayload,
      DataExportDataFailureKind.unknown => DataExportFailureKind.unknown,
    });
  }
}
