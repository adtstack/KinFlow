import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/data/datasources/data_export_data_source.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

void main() {
  test('maps preflight and pending request into domain invariants', () async {
    final _FakeDataExportDataSource dataSource = _FakeDataExportDataSource(
      preflightResult: DataExportDataSucceeded<DataExportPreflightDataRecord>(
        _preflightRecord(pending: true),
      ),
      statusResult: DataExportDataSucceeded<DataExportRequestDataRecord?>(
        _requestRecord(),
      ),
    );
    final ProviderDataExportRepository repository =
        ProviderDataExportRepository(dataSource);

    final DataExportResult<DataExportPreflight> preflightResult =
        await repository.loadPreflight();
    final DataExportResult<DataExportRequest?> requestResult = await repository
        .loadLatest();

    expect(
      (preflightResult as DataExportSucceeded<DataExportPreflight>)
          .value
          .pendingStatus,
      DataExportRequestStatus.queued,
    );
    expect(
      (requestResult as DataExportSucceeded<DataExportRequest?>)
          .value
          ?.cancellable,
      isTrue,
    );
  });

  test('maps completed artifact metadata and one-time download', () async {
    final _FakeDataExportDataSource dataSource = _FakeDataExportDataSource(
      statusResult: DataExportDataSucceeded<DataExportRequestDataRecord?>(
        _requestRecord(completed: true),
      ),
      downloadResult: const DataExportDataSucceeded<DataExportDownloadDataRecord>(
        DataExportDownloadDataRecord(
          format: 'json',
          expiresAt: '2026-08-08T01:15:00Z',
          downloadUrl:
              'https://download.kinflow.example/data-export?token=0123456789abcdefghijklmnopqrstuvwxyzABCDEFG',
        ),
      ),
    );
    final ProviderDataExportRepository repository =
        ProviderDataExportRepository(dataSource);

    final DataExportResult<DataExportRequest?> requestResult = await repository
        .loadLatest();
    final DataExportResult<DataExportDownload> downloadResult = await repository
        .createDownload(
          requestId: (requestResult as DataExportSucceeded<DataExportRequest?>)
              .value!
              .id,
          format: DataExportFormat.json,
          recentAuthenticationProof: _recentProof(),
        );

    expect(requestResult.value?.artifact.machineSizeBytes, 4096);
    expect(requestResult.value?.artifact.available, isTrue);
    expect(
      (downloadResult as DataExportSucceeded<DataExportDownload>)
          .value
          .uri
          .queryParameters['token'],
      isNotEmpty,
    );
  });

  test('rejects a non-UTC optional timestamp instead of erasing it', () async {
    final _FakeDataExportDataSource dataSource = _FakeDataExportDataSource(
      statusResult: DataExportDataSucceeded<DataExportRequestDataRecord?>(
        DataExportRequestDataRecord(
          id: _requestId,
          status: 'processing',
          requestedAt: '2026-08-08T01:00:00Z',
          processingStartedAt: '2026-08-08 10:05:00',
          completedAt: null,
          failedAt: null,
          cancelledAt: null,
          failureCode: null,
          cancellable: false,
          version: 2,
          artifact: _artifactRecord(),
        ),
      ),
    );

    final DataExportResult<DataExportRequest?> result =
        await ProviderDataExportRepository(dataSource).loadLatest();

    expect(
      (result as DataExportFailed<DataExportRequest?>).failure.kind,
      DataExportFailureKind.invalidPayload,
    );
  });

  test('rejects download URLs containing an extra query parameter', () async {
    final _FakeDataExportDataSource dataSource = _FakeDataExportDataSource(
      downloadResult: const DataExportDataSucceeded<DataExportDownloadDataRecord>(
        DataExportDownloadDataRecord(
          format: 'json',
          expiresAt: '2026-08-08T01:15:00Z',
          downloadUrl:
              'https://download.kinflow.example/data-export?token=0123456789abcdefghijklmnopqrstuvwxyzABCDEFG&debug=true',
        ),
      ),
    );

    final DataExportResult<DataExportDownload> result =
        await ProviderDataExportRepository(dataSource).createDownload(
          requestId: _requestIdValue(),
          format: DataExportFormat.json,
          recentAuthenticationProof: _recentProof(),
        );

    expect(
      (result as DataExportFailed<DataExportDownload>).failure.kind,
      DataExportFailureKind.invalidPayload,
    );
  });

  test('maps stable data failures without leaking provider details', () async {
    final _FakeDataExportDataSource dataSource = _FakeDataExportDataSource(
      preflightResult:
          const DataExportDataFailed<DataExportPreflightDataRecord>(
            DataExportDataFailureKind.downloadsPaused,
          ),
    );

    final DataExportResult<DataExportPreflight> result =
        await ProviderDataExportRepository(dataSource).loadPreflight();

    expect(
      (result as DataExportFailed<DataExportPreflight>).failure.kind,
      DataExportFailureKind.downloadsPaused,
    );
  });
}

const String _requestId = '74000000-0000-4000-8000-000000000001';
const String _artifactId = '75000000-0000-4000-8000-000000000001';

RecentAuthenticationProof _recentProof() {
  return RecentAuthenticationProof.tryParse('fresh-supabase-access-token')!;
}

DataExportRequestId _requestIdValue() {
  return DataExportRequestId.tryParse(_requestId)!;
}

DataExportPreflightDataRecord _preflightRecord({bool pending = false}) {
  return DataExportPreflightDataRecord(
    canRequest: !pending,
    pendingRequestId: pending ? _requestId : null,
    pendingStatus: pending ? 'queued' : null,
    pendingRequestVersion: pending ? 1 : null,
    conflictingRequestPending: false,
    requestsEnabled: true,
    downloadsEnabled: true,
    artifactTtlSeconds: 86400,
    downloadGrantTtlSeconds: 300,
    evaluatedAt: '2026-08-08T01:00:00Z',
  );
}

DataExportArtifactDataRecord _artifactRecord({bool available = false}) {
  return DataExportArtifactDataRecord(
    id: _artifactId,
    version: 1,
    schemaVersion: dataExportSchemaVersion,
    expiresAt: available ? '2026-08-10T01:00:00Z' : null,
    revokedAt: null,
    purgedAt: null,
    machineSizeBytes: available ? 4096 : null,
    humanSizeBytes: available ? 2048 : null,
    available: available,
  );
}

DataExportRequestDataRecord _requestRecord({bool completed = false}) {
  return DataExportRequestDataRecord(
    id: _requestId,
    status: completed ? 'completed' : 'queued',
    requestedAt: '2026-08-08T01:00:00Z',
    processingStartedAt: completed ? '2026-08-08T01:05:00Z' : null,
    completedAt: completed ? '2026-08-08T01:10:00Z' : null,
    failedAt: null,
    cancelledAt: null,
    failureCode: null,
    cancellable: !completed,
    version: completed ? 3 : 1,
    artifact: _artifactRecord(available: completed),
  );
}

final class _FakeDataExportDataSource implements DataExportDataSource {
  _FakeDataExportDataSource({
    DataExportDataResult<DataExportPreflightDataRecord>? preflightResult,
    DataExportDataResult<DataExportRequestDataRecord?>? statusResult,
    DataExportDataResult<DataExportDownloadDataRecord>? downloadResult,
  }) : preflightResult =
           preflightResult ??
           DataExportDataSucceeded<DataExportPreflightDataRecord>(
             _preflightRecord(),
           ),
       statusResult =
           statusResult ??
           const DataExportDataSucceeded<DataExportRequestDataRecord?>(null),
       downloadResult =
           downloadResult ??
           const DataExportDataFailed<DataExportDownloadDataRecord>(
             DataExportDataFailureKind.unknown,
           );

  final DataExportDataResult<DataExportPreflightDataRecord> preflightResult;
  final DataExportDataResult<DataExportRequestDataRecord?> statusResult;
  final DataExportDataResult<DataExportDownloadDataRecord> downloadResult;

  @override
  Future<DataExportDataResult<DataExportPreflightDataRecord>>
  preflight() async => preflightResult;

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord?>> status({
    String? requestId,
  }) async => statusResult;

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> request({
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async =>
      DataExportDataSucceeded<DataExportRequestDataRecord>(_requestRecord());

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async =>
      DataExportDataSucceeded<DataExportRequestDataRecord>(_requestRecord());

  @override
  Future<DataExportDataResult<DataExportRequestDataRecord>> revoke({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async => DataExportDataSucceeded<DataExportRequestDataRecord>(
    _requestRecord(completed: true),
  );

  @override
  Future<DataExportDataResult<DataExportDownloadDataRecord>> download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  }) async => downloadResult;
}
