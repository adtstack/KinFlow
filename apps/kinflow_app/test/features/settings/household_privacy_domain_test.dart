import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';

import '../../support/fakes/fake_household_privacy_dependencies.dart';

void main() {
  test('preflight enforces independent export and deletion eligibility', () {
    final HouseholdPrivacyPreflight eligible =
        householdPrivacyPreflightFixture();
    expect(eligible.canExport, isTrue);
    expect(eligible.canDelete, isTrue);
    expect(eligible.artifactRetention, const Duration(hours: 24));
    expect(eligible.deletionCancellationWindow, const Duration(hours: 24));

    expect(
      HouseholdPrivacyPreflight.tryCreate(
        household: eligible.household,
        memberCount: eligible.memberCount,
        activeSubscription: false,
        canExport: true,
        canDelete: true,
        conflictingRequestPending: true,
        pendingRequest: null,
        exportRequestsEnabled: true,
        deletionRequestsEnabled: true,
        downloadsEnabled: true,
        artifactRetention: const Duration(hours: 24),
        downloadGrantLifetime: const Duration(minutes: 5),
        deletionCancellationWindow: const Duration(hours: 24),
        retentionBlocked: false,
        retentionReviewAt: null,
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
    );
  });

  test('pending request must belong to the preflight household', () {
    final HouseholdPrivacyPreflight source = householdPrivacyPreflightFixture();
    final HouseholdPrivacyRequest pending = householdPrivacyRequestFixture();

    expect(
      HouseholdPrivacyPreflight.tryCreate(
        household: HouseholdPrivacyHousehold.tryCreate(
          id: source.household.id,
          name: source.household.name,
          version: source.household.version,
        )!,
        memberCount: 4,
        activeSubscription: false,
        canExport: false,
        canDelete: false,
        conflictingRequestPending: false,
        pendingRequest: pending,
        exportRequestsEnabled: true,
        deletionRequestsEnabled: true,
        downloadsEnabled: true,
        artifactRetention: const Duration(hours: 24),
        downloadGrantLifetime: const Duration(minutes: 5),
        deletionCancellationWindow: const Duration(hours: 24),
        retentionBlocked: false,
        retentionReviewAt: null,
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNotNull,
    );

    expect(
      HouseholdPrivacyPreflight.tryCreate(
        household: HouseholdPrivacyHousehold.tryCreate(
          id: HouseholdId.tryParse('72000000-0000-4000-8000-000000000001')!,
          name: 'Other family',
          version: 5,
        )!,
        memberCount: 4,
        activeSubscription: false,
        canExport: false,
        canDelete: false,
        conflictingRequestPending: false,
        pendingRequest: pending,
        exportRequestsEnabled: true,
        deletionRequestsEnabled: true,
        downloadsEnabled: true,
        artifactRetention: const Duration(hours: 24),
        downloadGrantLifetime: const Duration(minutes: 5),
        deletionCancellationWindow: const Duration(hours: 24),
        retentionBlocked: false,
        retentionReviewAt: null,
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
      reason: 'a pending request from another household is never accepted',
    );
  });

  test('request kind requires exactly its matching progress projection', () {
    final HouseholdPrivacyRequest export = householdPrivacyRequestFixture();
    expect(export.artifact, isNotNull);
    expect(export.deletion, isNull);

    final HouseholdPrivacyRequest deletion = householdPrivacyRequestFixture(
      kind: HouseholdPrivacyRequestKind.deletion,
    );
    expect(deletion.artifact, isNull);
    expect(deletion.deletion, isNotNull);

    expect(
      HouseholdPrivacyRequest.tryCreate(
        id: export.id,
        kind: HouseholdPrivacyRequestKind.deletion,
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
        activeSubscriptionAtRequest: false,
        artifact: export.artifact,
        deletion: null,
      ),
      isNull,
    );
  });

  test('household export pins schema and a 20 MiB per-file maximum', () {
    final HouseholdExportArtifact artifact = householdExportArtifactFixture(
      available: true,
      includeFileMetadata: true,
      machineSizeBytes: householdExportMaximumFileBytes,
      humanSizeBytes: householdExportMaximumFileBytes,
    );
    expect(artifact.schemaVersion, householdPrivacySchemaVersion);

    expect(
      HouseholdExportArtifact.tryCreate(
        id: artifact.id,
        version: 1,
        schemaVersion: householdPrivacySchemaVersion,
        expiresAt: artifact.expiresAt,
        revokedAt: null,
        purgedAt: null,
        machineSizeBytes: householdExportMaximumFileBytes + 1,
        humanSizeBytes: 1024,
        available: true,
      ),
      isNull,
    );
    expect(
      HouseholdExportArtifact.tryCreate(
        id: artifact.id,
        version: 1,
        schemaVersion: 'future-contract',
        expiresAt: artifact.expiresAt,
        revokedAt: null,
        purgedAt: null,
        machineSizeBytes: 1024,
        humanSizeBytes: 1024,
        available: true,
      ),
      isNull,
    );
  });

  test('download URL accepts one opaque token on trusted transport only', () {
    final HouseholdExportDownload valid = householdExportDownloadFixture();
    expect(valid.uri.queryParameters.keys, <String>['token']);

    expect(
      HouseholdExportDownload.tryCreate(
        format: HouseholdExportFormat.json,
        expiresAt: valid.expiresAt,
        uri: Uri.parse(
          'http://download.kinflow.example/household?token='
          '$householdPrivacyDownloadToken',
        ),
      ),
      isNull,
    );
    expect(
      HouseholdExportDownload.tryCreate(
        format: HouseholdExportFormat.json,
        expiresAt: valid.expiresAt,
        uri: Uri.parse(
          'https://download.kinflow.example/household?token='
          '$householdPrivacyDownloadToken&debug=true',
        ),
      ),
      isNull,
    );
  });
}
