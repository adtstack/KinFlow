import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/data_export_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_data_export_data_source.dart';

void main() {
  test('preflight parser accepts exact nullable pending metadata', () {
    final DataExportPreflightDataRecord? record =
        dataExportPreflightRecordFromPayload(_preflightPayload());

    expect(record?.canRequest, isTrue);
    expect(record?.pendingRequestId, isNull);
    expect(record?.artifactTtlSeconds, 86400);
    expect(record?.downloadGrantTtlSeconds, 300);
  });

  test('preflight parser rejects extra and mistyped provider fields', () {
    expect(
      dataExportPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'debug': 'private provider detail',
      }),
      isNull,
    );
    expect(
      dataExportPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'artifactTtlSeconds': 86400.0,
      }),
      isNull,
    );
  });

  test('request parser accepts the exact privacy-safe contract', () {
    final DataExportRequestDataRecord? record =
        dataExportRequestRecordFromPayload(_requestPayload());

    expect(record?.id, '74000000-0000-4000-8000-000000000001');
    expect(record?.artifact.id, '75000000-0000-4000-8000-000000000001');
    expect(record?.failureCode, isNull);
    expect(record?.version, 1);
  });

  test('request parser rejects extra identity and storage details', () {
    expect(
      dataExportRequestRecordFromPayload(<String, Object?>{
        ..._requestPayload(),
        'email': 'private@example.com',
      }),
      isNull,
    );
    expect(
      dataExportRequestRecordFromPayload(<String, Object?>{
        ..._requestPayload(),
        'artifact': <String, Object?>{
          ..._artifactPayload(),
          'storagePath': 'privacy-exports/private/path.json',
        },
      }),
      isNull,
    );
  });

  test('download parser accepts only exact public grant metadata', () {
    final Map<String, Object?> payload = <String, Object?>{
      'format': 'json',
      'expiresAt': '2026-08-08T01:05:00Z',
      'downloadUrl':
          'https://download.kinflow.example/data-export?token=opaque',
    };

    expect(dataExportDownloadRecordFromPayload(payload)?.format, 'json');
    expect(
      dataExportDownloadRecordFromPayload(<String, Object?>{
        ...payload,
        'grantId': '76000000-0000-4000-8000-000000000001',
      }),
      isNull,
    );
  });

  test('envelope pins contract version and exact metadata', () {
    final Map<String, Object?> valid = _envelope(_requestPayload());
    expect(dataExportEnvelopeHasValidContract(valid), isTrue);
    expect(
      dataExportEnvelopeHasValidContract(<String, Object?>{
        ...valid,
        'debug': true,
      }),
      isFalse,
    );
    expect(
      dataExportEnvelopeHasValidContract(
        _envelope(_requestPayload(), contractVersion: 'future-contract'),
      ),
      isFalse,
    );
  });

  test('stable Edge error codes map without reflecting details', () {
    expect(
      dataExportDataFailureFromFunctionDetails(<String, Object?>{
        'error': <String, Object?>{
          'code': 'ARTIFACT_UNAVAILABLE',
          'providerMessage': 'private storage detail',
        },
      }),
      DataExportDataFailureKind.artifactUnavailable,
    );
    expect(
      dataExportDataFailureFromCode('DOWNLOADS_PAUSED'),
      DataExportDataFailureKind.downloadsPaused,
    );
    expect(
      dataExportDataFailureFromCode('PGRST002'),
      DataExportDataFailureKind.temporarilyUnavailable,
    );
  });
}

Map<String, Object?> _preflightPayload() {
  return <String, Object?>{
    'canRequest': true,
    'pendingRequestId': null,
    'pendingStatus': null,
    'pendingRequestVersion': null,
    'conflictingRequestPending': false,
    'requestsEnabled': true,
    'downloadsEnabled': true,
    'artifactTtlSeconds': 86400,
    'downloadGrantTtlSeconds': 300,
    'evaluatedAt': '2026-08-08T01:00:00.000Z',
  };
}

Map<String, Object?> _artifactPayload() {
  return <String, Object?>{
    'id': '75000000-0000-4000-8000-000000000001',
    'version': 1,
    'schemaVersion': '2026-08-08-wp07-02a',
    'expiresAt': null,
    'revokedAt': null,
    'purgedAt': null,
    'machineSizeBytes': null,
    'humanSizeBytes': null,
    'available': false,
  };
}

Map<String, Object?> _requestPayload() {
  return <String, Object?>{
    'id': '74000000-0000-4000-8000-000000000001',
    'status': 'queued',
    'requestedAt': '2026-08-08T01:00:00.000Z',
    'processingStartedAt': null,
    'completedAt': null,
    'failedAt': null,
    'cancelledAt': null,
    'failureCode': null,
    'cancellable': true,
    'version': 1,
    'artifact': _artifactPayload(),
  };
}

Map<String, Object?> _envelope(
  Object? data, {
  String contractVersion = '2026-08-08-wp07-02a',
}) {
  return <String, Object?>{
    'data': data,
    'meta': <String, Object?>{
      'requestId': '77000000-0000-4000-8000-000000000001',
      'contractVersion': contractVersion,
    },
  };
}
