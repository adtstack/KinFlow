import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/household_privacy_data_source.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';

import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_household_privacy_dependencies.dart';

void main() {
  test('maps exact Owner preflight into bounded domain values', () async {
    final _FakeHouseholdPrivacyDataSource dataSource =
        _FakeHouseholdPrivacyDataSource();
    final ProviderHouseholdPrivacyRepository repository =
        ProviderHouseholdPrivacyRepository(dataSource);

    final result = await repository.loadPreflight(
      householdPrivacyHouseholdFixture().id,
    );

    expect(result, isA<HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>>());
    final HouseholdPrivacyPreflight value =
        (result as HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>).value;
    expect(value.household.name, 'Kim family');
    expect(value.memberCount, 4);
    expect(value.artifactRetention, const Duration(hours: 24));
    expect(dataSource.preflightHouseholdId, householdPrivacyHouseholdUuid);
  });

  test('maps deletion progress without exposing hold reason', () async {
    final _FakeHouseholdPrivacyDataSource dataSource =
        _FakeHouseholdPrivacyDataSource(
          statusResult:
              HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
                _deletionRecord(),
              ),
        );
    final ProviderHouseholdPrivacyRepository repository =
        ProviderHouseholdPrivacyRepository(dataSource);

    final result = await repository.loadStatus(
      householdPrivacyRequestFixture().id,
    );

    final HouseholdPrivacyRequest request =
        (result as HouseholdPrivacySucceeded<HouseholdPrivacyRequest>).value;
    expect(request.kind, HouseholdPrivacyRequestKind.deletion);
    expect(request.deletion?.retentionBlocked, isFalse);
    expect(request.artifact, isNull);
  });

  test(
    'rejects a mismatched request kind as invalid provider payload',
    () async {
      final HouseholdPrivacyRequestDataRecord export = _exportRecord();
      final _FakeHouseholdPrivacyDataSource
      dataSource = _FakeHouseholdPrivacyDataSource(
        statusResult:
            HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
              HouseholdPrivacyRequestDataRecord(
                requestId: export.requestId,
                kind: 'deletion',
                householdId: export.householdId,
                status: export.status,
                requestedAt: export.requestedAt,
                scheduledFor: export.scheduledFor,
                processingStartedAt: export.processingStartedAt,
                completedAt: export.completedAt,
                failedAt: export.failedAt,
                cancelledAt: export.cancelledAt,
                failureCode: export.failureCode,
                cancellable: export.cancellable,
                version: export.version,
                activeSubscriptionAtRequest: export.activeSubscriptionAtRequest,
                artifact: export.artifact,
                deletion: null,
              ),
            ),
      );
      final ProviderHouseholdPrivacyRepository repository =
          ProviderHouseholdPrivacyRepository(dataSource);

      final result = await repository.loadStatus(
        householdPrivacyRequestFixture().id,
      );

      expect(result, isA<HouseholdPrivacyFailed<HouseholdPrivacyRequest>>());
      expect(
        (result as HouseholdPrivacyFailed<HouseholdPrivacyRequest>)
            .failure
            .kind,
        HouseholdPrivacyFailureKind.invalidPayload,
      );
    },
  );

  test('forwards exact deletion confirmation and optimistic version', () async {
    final _FakeHouseholdPrivacyDataSource dataSource =
        _FakeHouseholdPrivacyDataSource();
    final ProviderHouseholdPrivacyRepository repository =
        ProviderHouseholdPrivacyRepository(dataSource);

    await repository.requestDeletion(
      householdId: householdPrivacyHouseholdFixture().id,
      expectedHouseholdVersion: 4,
      confirmationName: 'Kim family',
      acknowledgeMemberAccessLoss: true,
      acknowledgeSharedDataRedaction: true,
      acknowledgeSubscriptionNotCancelled: true,
      recentAuthenticationProof: recentAuthenticationProofFixture(),
      commandId: FakeHouseholdCommandIdGenerator().generate(),
    );

    expect(
      dataSource.deletionCall?['householdId'],
      householdPrivacyHouseholdUuid,
    );
    expect(dataSource.deletionCall?['expectedHouseholdVersion'], 4);
    expect(dataSource.deletionCall?['confirmationName'], 'Kim family');
    expect(dataSource.deletionCall?['subscription'], isTrue);
  });

  test('maps stable data failures and validates one-time URL grants', () async {
    final _FakeHouseholdPrivacyDataSource
    failedDataSource = _FakeHouseholdPrivacyDataSource(
      statusResult:
          const HouseholdPrivacyDataFailed<HouseholdPrivacyRequestDataRecord>(
            HouseholdPrivacyDataFailureKind.ownerRequired,
          ),
    );
    final ProviderHouseholdPrivacyRepository failedRepository =
        ProviderHouseholdPrivacyRepository(failedDataSource);
    final failed = await failedRepository.loadStatus(
      householdPrivacyRequestFixture().id,
    );
    expect(
      (failed as HouseholdPrivacyFailed<HouseholdPrivacyRequest>).failure.kind,
      HouseholdPrivacyFailureKind.ownerRequired,
    );

    final _FakeHouseholdPrivacyDataSource validDataSource =
        _FakeHouseholdPrivacyDataSource();
    final ProviderHouseholdPrivacyRepository validRepository =
        ProviderHouseholdPrivacyRepository(validDataSource);
    final download = await validRepository.createDownload(
      requestId: householdPrivacyRequestFixture().id,
      format: HouseholdExportFormat.json,
      recentAuthenticationProof: recentAuthenticationProofFixture(),
    );
    expect(
      (download as HouseholdPrivacySucceeded<HouseholdExportDownload>)
          .value
          .uri
          .queryParameters
          .keys,
      <String>['token'],
    );
  });
}

final class _FakeHouseholdPrivacyDataSource
    implements HouseholdPrivacyDataSource {
  _FakeHouseholdPrivacyDataSource({
    HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>? statusResult,
  }) : statusResult =
           statusResult ??
           HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
             _exportRecord(),
           );

  final HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>
  statusResult;
  String? preflightHouseholdId;
  Map<String, Object?>? deletionCall;

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyPreflightDataRecord>>
  preflight(String householdId) async {
    preflightHouseholdId = householdId;
    return HouseholdPrivacyDataSucceeded<HouseholdPrivacyPreflightDataRecord>(
      _preflightRecord(),
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> status(
    String requestId,
  ) async => statusResult;

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestExport({
    required String householdId,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async => HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
    _exportRecord(),
  );

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  requestDeletion({
    required String householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async {
    deletionCall = <String, Object?>{
      'householdId': householdId,
      'expectedHouseholdVersion': expectedHouseholdVersion,
      'confirmationName': confirmationName,
      'memberAccess': acknowledgeMemberAccessLoss,
      'redaction': acknowledgeSharedDataRedaction,
      'subscription': acknowledgeSubscriptionNotCancelled,
      'recentAuthenticationProof': recentAuthenticationProof,
      'idempotencyKey': idempotencyKey,
    };
    return HouseholdPrivacyDataSucceeded<HouseholdPrivacyRequestDataRecord>(
      _deletionRecord(),
    );
  }

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>> cancel({
    required String requestId,
    required String kind,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => statusResult;

  @override
  Future<HouseholdPrivacyDataResult<HouseholdPrivacyRequestDataRecord>>
  revokeExport({
    required String requestId,
    required int expectedArtifactVersion,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async => statusResult;

  @override
  Future<HouseholdPrivacyDataResult<HouseholdExportDownloadDataRecord>>
  download({
    required String requestId,
    required String format,
    required String recentAuthenticationProof,
  }) async => HouseholdPrivacyDataSucceeded<HouseholdExportDownloadDataRecord>(
    HouseholdExportDownloadDataRecord(
      format: format,
      expiresAt: '2026-08-08T01:05:00Z',
      downloadUrl:
          'https://download.kinflow.example/household-export?token='
          '$householdPrivacyDownloadToken',
    ),
  );
}

HouseholdPrivacyPreflightDataRecord _preflightRecord() {
  return HouseholdPrivacyPreflightDataRecord(
    household: const HouseholdPrivacyHouseholdDataRecord(
      id: householdPrivacyHouseholdUuid,
      name: 'Kim family',
      version: 4,
    ),
    memberCount: 4,
    activeSubscription: false,
    canExport: true,
    canDelete: true,
    conflictingRequestPending: false,
    pendingRequest: null,
    exportRequestsEnabled: true,
    deletionRequestsEnabled: true,
    downloadsEnabled: true,
    artifactTtlSeconds: 86400,
    downloadGrantTtlSeconds: 300,
    deletionCancellationWindowSeconds: 86400,
    retentionBlocked: false,
    retentionReviewAt: null,
    evaluatedAt: '2026-08-08T01:00:00Z',
  );
}

HouseholdPrivacyRequestDataRecord _exportRecord() {
  return HouseholdPrivacyRequestDataRecord(
    requestId: householdPrivacyRequestUuid,
    kind: 'export',
    householdId: householdPrivacyHouseholdUuid,
    status: 'queued',
    requestedAt: '2026-08-08T01:00:00Z',
    scheduledFor: '2026-08-08T01:00:00Z',
    processingStartedAt: null,
    completedAt: null,
    failedAt: null,
    cancelledAt: null,
    failureCode: null,
    cancellable: true,
    version: 1,
    activeSubscriptionAtRequest: false,
    artifact: const HouseholdExportArtifactDataRecord(
      id: householdExportArtifactUuid,
      version: 1,
      schemaVersion: householdPrivacySchemaVersion,
      expiresAt: null,
      revokedAt: null,
      purgedAt: null,
      machineSizeBytes: null,
      humanSizeBytes: null,
      available: false,
    ),
    deletion: null,
  );
}

HouseholdPrivacyRequestDataRecord _deletionRecord() {
  return HouseholdPrivacyRequestDataRecord(
    requestId: householdPrivacyRequestUuid,
    kind: 'deletion',
    householdId: householdPrivacyHouseholdUuid,
    status: 'queued',
    requestedAt: '2026-08-08T01:00:00Z',
    scheduledFor: '2026-08-09T01:00:00Z',
    processingStartedAt: null,
    completedAt: null,
    failedAt: null,
    cancelledAt: null,
    failureCode: null,
    cancellable: true,
    version: 1,
    activeSubscriptionAtRequest: true,
    artifact: null,
    deletion: const HouseholdDeletionProgressDataRecord(
      retentionBlocked: false,
      retentionReviewAt: null,
      accessRevokedAt: null,
      redactedAt: null,
      billingUnlinkedAt: null,
    ),
  );
}
