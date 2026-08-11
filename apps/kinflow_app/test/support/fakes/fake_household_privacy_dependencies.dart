import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/household_privacy_identifiers.dart';

const String householdPrivacyHouseholdUuid =
    '71000000-0000-4000-8000-000000000001';
const String householdPrivacyRequestUuid =
    '78000000-0000-4000-8000-000000000001';
const String householdExportArtifactUuid =
    '79000000-0000-4000-8000-000000000001';
const String householdPrivacyDownloadToken =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFG';

HouseholdPrivacyHousehold householdPrivacyHouseholdFixture({
  String name = 'Kim family',
  int version = 4,
}) {
  return HouseholdPrivacyHousehold.tryCreate(
    id: HouseholdId.tryParse(householdPrivacyHouseholdUuid)!,
    name: name,
    version: version,
  )!;
}

HouseholdPrivacyPreflight householdPrivacyPreflightFixture({
  bool exportRequestsEnabled = true,
  bool deletionRequestsEnabled = true,
  bool downloadsEnabled = true,
  bool conflictingRequestPending = false,
  bool activeSubscription = false,
  bool retentionBlocked = false,
  HouseholdPrivacyRequest? pendingRequest,
}) {
  final bool conflict = conflictingRequestPending || pendingRequest != null;
  return HouseholdPrivacyPreflight.tryCreate(
    household: householdPrivacyHouseholdFixture(),
    memberCount: 4,
    activeSubscription: activeSubscription,
    canExport: exportRequestsEnabled && !conflict,
    canDelete: deletionRequestsEnabled && !conflict,
    conflictingRequestPending: conflictingRequestPending,
    pendingRequest: pendingRequest,
    exportRequestsEnabled: exportRequestsEnabled,
    deletionRequestsEnabled: deletionRequestsEnabled,
    downloadsEnabled: downloadsEnabled,
    artifactRetention: const Duration(hours: 24),
    downloadGrantLifetime: const Duration(minutes: 5),
    deletionCancellationWindow: const Duration(hours: 24),
    retentionBlocked: retentionBlocked,
    retentionReviewAt: retentionBlocked
        ? DateTime.parse('2026-08-09T01:00:00Z')
        : null,
    evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
  )!;
}

HouseholdExportArtifact householdExportArtifactFixture({
  bool available = false,
  int version = 1,
  DateTime? revokedAt,
  DateTime? purgedAt,
  bool includeFileMetadata = false,
  int machineSizeBytes = 8192,
  int humanSizeBytes = 4096,
}) {
  return HouseholdExportArtifact.tryCreate(
    id: HouseholdExportArtifactId.tryParse(householdExportArtifactUuid)!,
    version: version,
    schemaVersion: householdPrivacySchemaVersion,
    expiresAt: includeFileMetadata
        ? DateTime.parse('2026-08-09T01:00:00Z')
        : null,
    revokedAt: revokedAt,
    purgedAt: purgedAt,
    machineSizeBytes: includeFileMetadata ? machineSizeBytes : null,
    humanSizeBytes: includeFileMetadata ? humanSizeBytes : null,
    available: available,
  )!;
}

HouseholdDeletionProgress householdDeletionProgressFixture({
  bool retentionBlocked = false,
  bool completed = false,
}) {
  return HouseholdDeletionProgress.tryCreate(
    retentionBlocked: retentionBlocked,
    retentionReviewAt: retentionBlocked
        ? DateTime.parse('2026-08-10T01:00:00Z')
        : null,
    accessRevokedAt: completed ? DateTime.parse('2026-08-09T02:00:00Z') : null,
    redactedAt: completed ? DateTime.parse('2026-08-09T02:00:01Z') : null,
    billingUnlinkedAt: completed
        ? DateTime.parse('2026-08-09T02:00:02Z')
        : null,
  )!;
}

HouseholdPrivacyRequest householdPrivacyRequestFixture({
  HouseholdPrivacyRequestKind kind = HouseholdPrivacyRequestKind.export,
  HouseholdPrivacyRequestStatus status = HouseholdPrivacyRequestStatus.queued,
  int version = 1,
  bool artifactAvailable = false,
  DateTime? artifactRevokedAt,
  DateTime? artifactPurgedAt,
  bool activeSubscriptionAtRequest = false,
  bool retentionBlocked = false,
}) {
  final DateTime requestedAt = DateTime.parse('2026-08-08T01:00:00Z');
  final DateTime processingAt = DateTime.parse('2026-08-08T01:05:00Z');
  final bool processingStarted = switch (status) {
    HouseholdPrivacyRequestStatus.processing ||
    HouseholdPrivacyRequestStatus.completed ||
    HouseholdPrivacyRequestStatus.failed => true,
    _ => false,
  };
  final bool completed = status == HouseholdPrivacyRequestStatus.completed;
  return HouseholdPrivacyRequest.tryCreate(
    id: HouseholdPrivacyRequestId.tryParse(householdPrivacyRequestUuid)!,
    kind: kind,
    householdId: HouseholdId.tryParse(householdPrivacyHouseholdUuid)!,
    status: status,
    requestedAt: requestedAt,
    scheduledFor: kind == HouseholdPrivacyRequestKind.deletion
        ? DateTime.parse('2026-08-09T01:00:00Z')
        : requestedAt,
    processingStartedAt: processingStarted ? processingAt : null,
    completedAt: completed
        ? (kind == HouseholdPrivacyRequestKind.deletion
              ? DateTime.parse('2026-08-09T02:00:03Z')
              : DateTime.parse('2026-08-08T01:10:00Z'))
        : null,
    failedAt: status == HouseholdPrivacyRequestStatus.failed
        ? DateTime.parse('2026-08-08T01:10:00Z')
        : null,
    cancelledAt: status == HouseholdPrivacyRequestStatus.cancelled
        ? DateTime.parse('2026-08-08T01:10:00Z')
        : null,
    failureCode: status == HouseholdPrivacyRequestStatus.failed
        ? 'HOUSEHOLD_PRIVACY_ATTEMPTS_EXHAUSTED'
        : null,
    cancellable:
        status == HouseholdPrivacyRequestStatus.queued ||
        status == HouseholdPrivacyRequestStatus.verifying,
    version: version,
    activeSubscriptionAtRequest: activeSubscriptionAtRequest,
    artifact: kind == HouseholdPrivacyRequestKind.export
        ? householdExportArtifactFixture(
            available: completed && artifactAvailable,
            version: artifactRevokedAt == null && artifactPurgedAt == null
                ? 1
                : 2,
            revokedAt: artifactRevokedAt,
            purgedAt: artifactPurgedAt,
            includeFileMetadata: completed,
          )
        : null,
    deletion: kind == HouseholdPrivacyRequestKind.deletion
        ? householdDeletionProgressFixture(
            retentionBlocked: retentionBlocked,
            completed: completed,
          )
        : null,
  )!;
}

HouseholdExportDownload householdExportDownloadFixture({
  HouseholdExportFormat format = HouseholdExportFormat.json,
}) {
  return HouseholdExportDownload.tryCreate(
    format: format,
    expiresAt: DateTime.parse('2026-08-08T01:05:00Z'),
    uri: Uri.parse(
      'https://download.kinflow.example/household-export?token='
      '$householdPrivacyDownloadToken',
    ),
  )!;
}

final class FakeHouseholdPrivacyRepository
    implements HouseholdPrivacyRepository {
  FakeHouseholdPrivacyRepository({
    HouseholdPrivacyResult<HouseholdPrivacyPreflight>? preflightResult,
    List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>? statusResults,
    List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>? exportResults,
    List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>? deletionResults,
    List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>? cancelResults,
    List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>? revokeResults,
    List<HouseholdPrivacyResult<HouseholdExportDownload>>? downloadResults,
  }) : preflightResult =
           preflightResult ??
           HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(
             householdPrivacyPreflightFixture(),
           ),
       statusResults = List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>.of(
         statusResults ?? <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[],
       ),
       exportResults = List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>.of(
         exportResults ??
             <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
               HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(
                 householdPrivacyRequestFixture(),
               ),
             ],
       ),
       deletionResults =
           List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>.of(
             deletionResults ??
                 <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
                   HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(
                     householdPrivacyRequestFixture(
                       kind: HouseholdPrivacyRequestKind.deletion,
                     ),
                   ),
                 ],
           ),
       cancelResults = List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>.of(
         cancelResults ??
             <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
               HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(
                 householdPrivacyRequestFixture(
                   status: HouseholdPrivacyRequestStatus.cancelled,
                   version: 2,
                 ),
               ),
             ],
       ),
       revokeResults = List<HouseholdPrivacyResult<HouseholdPrivacyRequest>>.of(
         revokeResults ??
             <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
               HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(
                 householdPrivacyRequestFixture(
                   status: HouseholdPrivacyRequestStatus.completed,
                   version: 4,
                   artifactRevokedAt: DateTime.parse('2026-08-08T02:00:00Z'),
                 ),
               ),
             ],
       ),
       downloadResults =
           List<HouseholdPrivacyResult<HouseholdExportDownload>>.of(
             downloadResults ??
                 <HouseholdPrivacyResult<HouseholdExportDownload>>[
                   HouseholdPrivacySucceeded<HouseholdExportDownload>(
                     householdExportDownloadFixture(),
                   ),
                 ],
           );

  HouseholdPrivacyResult<HouseholdPrivacyPreflight> preflightResult;
  final List<HouseholdPrivacyResult<HouseholdPrivacyRequest>> statusResults;
  final List<HouseholdPrivacyResult<HouseholdPrivacyRequest>> exportResults;
  final List<HouseholdPrivacyResult<HouseholdPrivacyRequest>> deletionResults;
  final List<HouseholdPrivacyResult<HouseholdPrivacyRequest>> cancelResults;
  final List<HouseholdPrivacyResult<HouseholdPrivacyRequest>> revokeResults;
  final List<HouseholdPrivacyResult<HouseholdExportDownload>> downloadResults;
  final List<HouseholdId> preflightHouseholdIds = <HouseholdId>[];
  final List<HouseholdPrivacyRequestId> statusRequestIds =
      <HouseholdPrivacyRequestId>[];
  final List<HouseholdPrivacyExportCall> exportCalls =
      <HouseholdPrivacyExportCall>[];
  final List<HouseholdPrivacyDeletionCall> deletionCalls =
      <HouseholdPrivacyDeletionCall>[];
  final List<HouseholdPrivacyCancelCall> cancelCalls =
      <HouseholdPrivacyCancelCall>[];
  final List<HouseholdPrivacyRevokeCall> revokeCalls =
      <HouseholdPrivacyRevokeCall>[];
  final List<HouseholdPrivacyDownloadCall> downloadCalls =
      <HouseholdPrivacyDownloadCall>[];

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyPreflight>> loadPreflight(
    HouseholdId householdId,
  ) async {
    preflightHouseholdIds.add(householdId);
    return preflightResult;
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> loadStatus(
    HouseholdPrivacyRequestId requestId,
  ) async {
    statusRequestIds.add(requestId);
    return statusResults.removeAt(0);
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestExport({
    required HouseholdId householdId,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async {
    exportCalls.add(
      HouseholdPrivacyExportCall(
        householdId: householdId,
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return exportResults.removeAt(0);
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
    deletionCalls.add(
      HouseholdPrivacyDeletionCall(
        householdId: householdId,
        expectedHouseholdVersion: expectedHouseholdVersion,
        confirmationName: confirmationName,
        acknowledgeMemberAccessLoss: acknowledgeMemberAccessLoss,
        acknowledgeSharedDataRedaction: acknowledgeSharedDataRedaction,
        acknowledgeSubscriptionNotCancelled:
            acknowledgeSubscriptionNotCancelled,
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return deletionResults.removeAt(0);
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> cancel({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdPrivacyRequestKind kind,
    required int expectedVersion,
    required HouseholdCommandId commandId,
  }) async {
    cancelCalls.add(
      HouseholdPrivacyCancelCall(
        requestId: requestId,
        kind: kind,
        expectedVersion: expectedVersion,
        commandId: commandId,
      ),
    );
    return cancelResults.removeAt(0);
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> revokeExport({
    required HouseholdPrivacyRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async {
    revokeCalls.add(
      HouseholdPrivacyRevokeCall(
        requestId: requestId,
        expectedArtifactVersion: expectedArtifactVersion,
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return revokeResults.removeAt(0);
  }

  @override
  Future<HouseholdPrivacyResult<HouseholdExportDownload>> createDownload({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async {
    downloadCalls.add(
      HouseholdPrivacyDownloadCall(
        requestId: requestId,
        format: format,
        recentAuthenticationProof: recentAuthenticationProof,
      ),
    );
    return downloadResults.removeAt(0);
  }
}

final class HouseholdPrivacyExportCall {
  const HouseholdPrivacyExportCall({
    required this.householdId,
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final HouseholdId householdId;
  final RecentAuthenticationProof recentAuthenticationProof;
  final HouseholdCommandId commandId;
}

final class HouseholdPrivacyDeletionCall {
  const HouseholdPrivacyDeletionCall({
    required this.householdId,
    required this.expectedHouseholdVersion,
    required this.confirmationName,
    required this.acknowledgeMemberAccessLoss,
    required this.acknowledgeSharedDataRedaction,
    required this.acknowledgeSubscriptionNotCancelled,
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final HouseholdId householdId;
  final int expectedHouseholdVersion;
  final String confirmationName;
  final bool acknowledgeMemberAccessLoss;
  final bool acknowledgeSharedDataRedaction;
  final bool acknowledgeSubscriptionNotCancelled;
  final RecentAuthenticationProof recentAuthenticationProof;
  final HouseholdCommandId commandId;
}

final class HouseholdPrivacyCancelCall {
  const HouseholdPrivacyCancelCall({
    required this.requestId,
    required this.kind,
    required this.expectedVersion,
    required this.commandId,
  });

  final HouseholdPrivacyRequestId requestId;
  final HouseholdPrivacyRequestKind kind;
  final int expectedVersion;
  final HouseholdCommandId commandId;
}

final class HouseholdPrivacyRevokeCall {
  const HouseholdPrivacyRevokeCall({
    required this.requestId,
    required this.expectedArtifactVersion,
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final HouseholdPrivacyRequestId requestId;
  final int expectedArtifactVersion;
  final RecentAuthenticationProof recentAuthenticationProof;
  final HouseholdCommandId commandId;
}

final class HouseholdPrivacyDownloadCall {
  const HouseholdPrivacyDownloadCall({
    required this.requestId,
    required this.format,
    required this.recentAuthenticationProof,
  });

  final HouseholdPrivacyRequestId requestId;
  final HouseholdExportFormat format;
  final RecentAuthenticationProof recentAuthenticationProof;
}
