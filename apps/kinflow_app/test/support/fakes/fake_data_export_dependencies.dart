import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

const String dataExportRequestUuid = '74000000-0000-4000-8000-000000000001';
const String dataExportArtifactUuid = '75000000-0000-4000-8000-000000000001';
const String dataExportDownloadToken =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFG';

DataExportPreflight dataExportPreflightFixture({
  bool requestsEnabled = true,
  bool downloadsEnabled = true,
  bool conflictingRequestPending = false,
  DataExportRequest? pendingRequest,
}) {
  return DataExportPreflight.tryCreate(
    canRequest:
        requestsEnabled && !conflictingRequestPending && pendingRequest == null,
    pendingRequestId: pendingRequest?.id,
    pendingStatus: pendingRequest?.status,
    pendingRequestVersion: pendingRequest?.version,
    conflictingRequestPending: conflictingRequestPending,
    requestsEnabled: requestsEnabled,
    downloadsEnabled: downloadsEnabled,
    artifactRetention: const Duration(hours: 24),
    downloadGrantLifetime: const Duration(minutes: 5),
    evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
  )!;
}

DataExportArtifact dataExportArtifactFixture({
  bool available = true,
  int version = 1,
  DateTime? revokedAt,
  DateTime? purgedAt,
  bool includeFileMetadata = true,
}) {
  return DataExportArtifact.tryCreate(
    id: DataExportArtifactId.tryParse(dataExportArtifactUuid)!,
    version: version,
    schemaVersion: dataExportSchemaVersion,
    expiresAt: includeFileMetadata
        ? DateTime.parse('2026-08-10T01:00:00Z')
        : null,
    revokedAt: revokedAt,
    purgedAt: purgedAt,
    machineSizeBytes: includeFileMetadata ? 4096 : null,
    humanSizeBytes: includeFileMetadata ? 2048 : null,
    available: available,
  )!;
}

DataExportRequest dataExportRequestFixture({
  DataExportRequestStatus status = DataExportRequestStatus.queued,
  int version = 1,
  bool artifactAvailable = false,
  DateTime? artifactRevokedAt,
  DateTime? artifactPurgedAt,
}) {
  final DateTime requestedAt = DateTime.parse('2026-08-08T01:00:00Z');
  final DateTime processingAt = DateTime.parse('2026-08-08T01:05:00Z');
  final bool processingStarted = switch (status) {
    DataExportRequestStatus.processing ||
    DataExportRequestStatus.completed ||
    DataExportRequestStatus.failed => true,
    _ => false,
  };
  final bool completed = status == DataExportRequestStatus.completed;
  return DataExportRequest.tryCreate(
    id: DataExportRequestId.tryParse(dataExportRequestUuid)!,
    status: status,
    requestedAt: requestedAt,
    processingStartedAt: processingStarted ? processingAt : null,
    completedAt: completed ? DateTime.parse('2026-08-08T01:10:00Z') : null,
    failedAt: status == DataExportRequestStatus.failed
        ? DateTime.parse('2026-08-08T01:10:00Z')
        : null,
    cancelledAt: status == DataExportRequestStatus.cancelled
        ? DateTime.parse('2026-08-08T01:10:00Z')
        : null,
    failureCode: status == DataExportRequestStatus.failed
        ? 'EXPORT_ATTEMPTS_EXHAUSTED'
        : null,
    cancellable:
        status == DataExportRequestStatus.queued ||
        status == DataExportRequestStatus.verifying,
    version: version,
    artifact: dataExportArtifactFixture(
      available: completed && artifactAvailable,
      version: artifactRevokedAt == null && artifactPurgedAt == null ? 1 : 2,
      revokedAt: artifactRevokedAt,
      purgedAt: artifactPurgedAt,
      includeFileMetadata: completed,
    ),
  )!;
}

DataExportDownload dataExportDownloadFixture({
  DataExportFormat format = DataExportFormat.json,
}) {
  return DataExportDownload.tryCreate(
    format: format,
    expiresAt: DateTime.parse('2026-08-08T01:05:00Z'),
    uri: Uri.parse(
      'https://download.kinflow.example/data-export?token=$dataExportDownloadToken',
    ),
  )!;
}

final class FakeDataExportRepository implements DataExportRepository {
  FakeDataExportRepository({
    DataExportResult<DataExportPreflight>? preflightResult,
    DataExportResult<DataExportRequest?>? latestResult,
    List<DataExportResult<DataExportRequest>>? requestResults,
    List<DataExportResult<DataExportRequest>>? cancelResults,
    List<DataExportResult<DataExportRequest>>? revokeResults,
    List<DataExportResult<DataExportDownload>>? downloadResults,
  }) : preflightResult =
           preflightResult ??
           DataExportSucceeded<DataExportPreflight>(
             dataExportPreflightFixture(),
           ),
       latestResult =
           latestResult ?? const DataExportSucceeded<DataExportRequest?>(null),
       requestResults = List<DataExportResult<DataExportRequest>>.of(
         requestResults ??
             <DataExportResult<DataExportRequest>>[
               DataExportSucceeded<DataExportRequest>(
                 dataExportRequestFixture(),
               ),
             ],
       ),
       cancelResults = List<DataExportResult<DataExportRequest>>.of(
         cancelResults ??
             <DataExportResult<DataExportRequest>>[
               DataExportSucceeded<DataExportRequest>(
                 dataExportRequestFixture(
                   status: DataExportRequestStatus.cancelled,
                   version: 2,
                 ),
               ),
             ],
       ),
       revokeResults = List<DataExportResult<DataExportRequest>>.of(
         revokeResults ??
             <DataExportResult<DataExportRequest>>[
               DataExportSucceeded<DataExportRequest>(
                 dataExportRequestFixture(
                   status: DataExportRequestStatus.completed,
                   version: 2,
                   artifactRevokedAt: DateTime.parse('2026-08-08T02:00:00Z'),
                 ),
               ),
             ],
       ),
       downloadResults = List<DataExportResult<DataExportDownload>>.of(
         downloadResults ??
             <DataExportResult<DataExportDownload>>[
               DataExportSucceeded<DataExportDownload>(
                 dataExportDownloadFixture(),
               ),
             ],
       );

  DataExportResult<DataExportPreflight> preflightResult;
  DataExportResult<DataExportRequest?> latestResult;
  final List<DataExportResult<DataExportRequest>> requestResults;
  final List<DataExportResult<DataExportRequest>> cancelResults;
  final List<DataExportResult<DataExportRequest>> revokeResults;
  final List<DataExportResult<DataExportDownload>> downloadResults;
  final List<DataExportRequestCall> requestCalls = <DataExportRequestCall>[];
  final List<DataExportCancelCall> cancelCalls = <DataExportCancelCall>[];
  final List<DataExportRevokeCall> revokeCalls = <DataExportRevokeCall>[];
  final List<DataExportDownloadCall> downloadCalls = <DataExportDownloadCall>[];
  final List<DataExportRequestId?> statusRequestIds = <DataExportRequestId?>[];
  int preflightCount = 0;

  @override
  Future<DataExportResult<DataExportPreflight>> loadPreflight() async {
    preflightCount += 1;
    return preflightResult;
  }

  @override
  Future<DataExportResult<DataExportRequest?>> loadLatest({
    DataExportRequestId? requestId,
  }) async {
    statusRequestIds.add(requestId);
    return latestResult;
  }

  @override
  Future<DataExportResult<DataExportRequest>> requestExport({
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    requestCalls.add(
      DataExportRequestCall(
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return requestResults.removeAt(0);
  }

  @override
  Future<DataExportResult<DataExportRequest>> cancel({
    required DataExportRequestId requestId,
    required int expectedVersion,
    required DataExportCommandId commandId,
  }) async {
    cancelCalls.add(
      DataExportCancelCall(
        requestId: requestId,
        expectedVersion: expectedVersion,
        commandId: commandId,
      ),
    );
    return cancelResults.removeAt(0);
  }

  @override
  Future<DataExportResult<DataExportRequest>> revoke({
    required DataExportRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    revokeCalls.add(
      DataExportRevokeCall(
        requestId: requestId,
        expectedArtifactVersion: expectedArtifactVersion,
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return revokeResults.removeAt(0);
  }

  @override
  Future<DataExportResult<DataExportDownload>> createDownload({
    required DataExportRequestId requestId,
    required DataExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async {
    downloadCalls.add(
      DataExportDownloadCall(
        requestId: requestId,
        format: format,
        recentAuthenticationProof: recentAuthenticationProof,
      ),
    );
    return downloadResults.removeAt(0);
  }
}

final class DataExportRequestCall {
  const DataExportRequestCall({
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final RecentAuthenticationProof recentAuthenticationProof;
  final DataExportCommandId commandId;
}

final class DataExportCancelCall {
  const DataExportCancelCall({
    required this.requestId,
    required this.expectedVersion,
    required this.commandId,
  });

  final DataExportRequestId requestId;
  final int expectedVersion;
  final DataExportCommandId commandId;
}

final class DataExportRevokeCall {
  const DataExportRevokeCall({
    required this.requestId,
    required this.expectedArtifactVersion,
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final DataExportRequestId requestId;
  final int expectedArtifactVersion;
  final RecentAuthenticationProof recentAuthenticationProof;
  final DataExportCommandId commandId;
}

final class DataExportDownloadCall {
  const DataExportDownloadCall({
    required this.requestId,
    required this.format,
    required this.recentAuthenticationProof,
  });

  final DataExportRequestId requestId;
  final DataExportFormat format;
  final RecentAuthenticationProof recentAuthenticationProof;
}

final class FakeDataExportCommandIdGenerator
    implements DataExportCommandIdGenerator {
  int generateCount = 0;

  @override
  DataExportCommandId generate() {
    generateCount += 1;
    return DataExportCommandId.tryParse(
      '76000000-0000-4000-8000-${generateCount.toString().padLeft(12, '0')}',
    )!;
  }
}

final class FakeDataExportDownloadLauncher
    implements DataExportDownloadLauncher {
  FakeDataExportDownloadLauncher({List<bool>? results})
    : _results = List<bool>.of(results ?? <bool>[true]);

  final List<bool> _results;
  final List<Uri> launchedUris = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return _results.removeAt(0);
  }
}
