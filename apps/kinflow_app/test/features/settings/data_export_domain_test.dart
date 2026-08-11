import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';

import '../../support/fakes/fake_data_export_dependencies.dart';

void main() {
  test('preflight enforces the server request eligibility equation', () {
    final DataExportPreflight eligible = dataExportPreflightFixture();
    expect(eligible.canRequest, isTrue);
    expect(eligible.artifactRetention, const Duration(hours: 24));
    expect(eligible.downloadGrantLifetime, const Duration(minutes: 5));

    expect(
      DataExportPreflight.tryCreate(
        canRequest: true,
        pendingRequestId: null,
        pendingStatus: null,
        pendingRequestVersion: null,
        conflictingRequestPending: true,
        requestsEnabled: true,
        downloadsEnabled: true,
        artifactRetention: const Duration(hours: 24),
        downloadGrantLifetime: const Duration(minutes: 5),
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
    );
  });

  test('preflight requires complete pending request metadata', () {
    final DataExportRequest pending = dataExportRequestFixture();

    expect(
      DataExportPreflight.tryCreate(
        canRequest: false,
        pendingRequestId: pending.id,
        pendingStatus: null,
        pendingRequestVersion: pending.version,
        conflictingRequestPending: false,
        requestsEnabled: true,
        downloadsEnabled: true,
        artifactRetention: const Duration(hours: 24),
        downloadGrantLifetime: const Duration(minutes: 5),
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
    );
  });

  test('request status shapes reject impossible provider payloads', () {
    final DataExportRequest queued = dataExportRequestFixture();
    expect(queued.cancellable, isTrue);

    expect(
      DataExportRequest.tryCreate(
        id: queued.id,
        status: DataExportRequestStatus.completed,
        requestedAt: queued.requestedAt,
        processingStartedAt: null,
        completedAt: DateTime.parse('2026-08-08T01:10:00Z'),
        failedAt: null,
        cancelledAt: null,
        failureCode: null,
        cancellable: false,
        version: 2,
        artifact: dataExportArtifactFixture(),
      ),
      isNull,
    );

    expect(
      dataExportRequestFixture(
        status: DataExportRequestStatus.failed,
        version: 3,
      ).failureCode,
      'EXPORT_ATTEMPTS_EXHAUSTED',
    );
  });

  test(
    'available artifacts require the pinned schema and complete metadata',
    () {
      final DataExportArtifact artifact = dataExportArtifactFixture();
      expect(artifact.available, isTrue);
      expect(artifact.schemaVersion, dataExportSchemaVersion);

      expect(
        DataExportArtifact.tryCreate(
          id: artifact.id,
          version: 1,
          schemaVersion: 'future-schema',
          expiresAt: artifact.expiresAt,
          revokedAt: null,
          purgedAt: null,
          machineSizeBytes: artifact.machineSizeBytes,
          humanSizeBytes: artifact.humanSizeBytes,
          available: true,
        ),
        isNull,
      );
      expect(
        DataExportArtifact.tryCreate(
          id: artifact.id,
          version: 1,
          schemaVersion: dataExportSchemaVersion,
          expiresAt: artifact.expiresAt,
          revokedAt: null,
          purgedAt: null,
          machineSizeBytes: artifact.machineSizeBytes,
          humanSizeBytes: null,
          available: true,
        ),
        isNull,
      );
    },
  );

  test('download URLs allow only one opaque token on trusted transports', () {
    final DataExportDownload valid = dataExportDownloadFixture();
    expect(valid.uri.scheme, 'https');
    expect(valid.uri.queryParameters.keys, <String>['token']);

    expect(
      DataExportDownload.tryCreate(
        format: DataExportFormat.json,
        expiresAt: valid.expiresAt,
        uri: Uri.parse(
          'http://download.kinflow.example/data-export?token=$dataExportDownloadToken',
        ),
      ),
      isNull,
    );
    expect(
      DataExportDownload.tryCreate(
        format: DataExportFormat.json,
        expiresAt: valid.expiresAt,
        uri: Uri.parse(
          'https://download.kinflow.example/data-export?token=$dataExportDownloadToken&debug=true',
        ),
      ),
      isNull,
    );
    expect(
      DataExportDownload.tryCreate(
        format: DataExportFormat.json,
        expiresAt: valid.expiresAt,
        uri: Uri.parse(
          'https://user@download.kinflow.example/data-export?token=$dataExportDownloadToken',
        ),
      ),
      isNull,
    );
  });
}
