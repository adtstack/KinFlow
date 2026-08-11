import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/household_privacy_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_privacy_data_source.dart';

void main() {
  test('preflight parser accepts the exact Owner-safe projection', () {
    final HouseholdPrivacyPreflightDataRecord? record =
        householdPrivacyPreflightRecordFromPayload(_preflightPayload());

    expect(record?.household.name, 'Kim family');
    expect(record?.memberCount, 4);
    expect(record?.activeSubscription, isTrue);
    expect(record?.artifactTtlSeconds, 86400);
    expect(record?.pendingRequest, isNull);
  });

  test('preflight parser rejects extra and mistyped provider fields', () {
    expect(
      householdPrivacyPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'ownerEmail': 'private@example.com',
      }),
      isNull,
    );
    expect(
      householdPrivacyPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'memberCount': 4.0,
      }),
      isNull,
    );
  });

  test('request parser enforces kind-specific exact nested projections', () {
    final HouseholdPrivacyRequestDataRecord? export =
        householdPrivacyRequestRecordFromPayload(_exportRequestPayload());
    final HouseholdPrivacyRequestDataRecord? deletion =
        householdPrivacyRequestRecordFromPayload(_deletionRequestPayload());

    expect(export?.kind, 'export');
    expect(export?.artifact?.schemaVersion, '2026-08-08-wp07-02b');
    expect(export?.deletion, isNull);
    expect(deletion?.kind, 'deletion');
    expect(deletion?.artifact, isNull);
    expect(deletion?.deletion?.retentionBlocked, isFalse);
  });

  test('request parser rejects storage paths and retention reasons', () {
    expect(
      householdPrivacyRequestRecordFromPayload(<String, Object?>{
        ..._exportRequestPayload(),
        'artifact': <String, Object?>{
          ..._artifactPayload(),
          'storagePath': 'privacy-exports/private/household.json',
        },
      }),
      isNull,
    );
    expect(
      householdPrivacyRequestRecordFromPayload(<String, Object?>{
        ..._deletionRequestPayload(),
        'deletion': <String, Object?>{
          ..._deletionPayload(),
          'retentionReason': 'private operator detail',
        },
      }),
      isNull,
    );
  });

  test('download and envelope pin exact one-time public metadata', () {
    final Map<String, Object?> payload = <String, Object?>{
      'format': 'json',
      'expiresAt': '2026-08-08T01:05:00Z',
      'downloadUrl':
          'https://download.kinflow.example/household-export?token=opaque',
    };
    expect(householdExportDownloadRecordFromPayload(payload)?.format, 'json');
    expect(
      householdExportDownloadRecordFromPayload(<String, Object?>{
        ...payload,
        'grantId': '7a000000-0000-4000-8000-000000000001',
      }),
      isNull,
    );
    expect(
      householdPrivacyEnvelopeHasValidContract(
        _envelope(_exportRequestPayload()),
      ),
      isTrue,
    );
    expect(
      householdPrivacyEnvelopeHasValidContract(
        _envelope(_exportRequestPayload(), contractVersion: 'future-contract'),
      ),
      isFalse,
    );
  });

  test('stable Edge and SQL codes map without reflecting details', () {
    expect(
      householdPrivacyDataFailureFromFunctionDetails(<String, Object?>{
        'error': <String, Object?>{
          'code': 'OWNER_REQUIRED',
          'operatorDetail': 'must not escape',
        },
      }),
      HouseholdPrivacyDataFailureKind.ownerRequired,
    );
    expect(
      householdPrivacyDataFailureFromCode('KHP11'),
      HouseholdPrivacyDataFailureKind.subscriptionAcknowledgmentRequired,
    );
    expect(
      householdPrivacyDataFailureFromCode('DOWNLOADS_PAUSED'),
      HouseholdPrivacyDataFailureKind.downloadsPaused,
    );
    expect(
      householdPrivacyDataFailureFromCode('PGRST002'),
      HouseholdPrivacyDataFailureKind.temporarilyUnavailable,
    );
  });
}

Map<String, Object?> _preflightPayload() {
  return <String, Object?>{
    'household': <String, Object?>{
      'id': '71000000-0000-4000-8000-000000000001',
      'name': 'Kim family',
      'version': 4,
    },
    'memberCount': 4,
    'activeSubscription': true,
    'canExport': true,
    'canDelete': true,
    'conflictingRequestPending': false,
    'pendingRequest': null,
    'exportRequestsEnabled': true,
    'deletionRequestsEnabled': true,
    'downloadsEnabled': true,
    'artifactTtlSeconds': 86400,
    'downloadGrantTtlSeconds': 300,
    'deletionCancellationWindowSeconds': 86400,
    'retentionBlocked': false,
    'retentionReviewAt': null,
    'evaluatedAt': '2026-08-08T01:00:00.000Z',
  };
}

Map<String, Object?> _artifactPayload() {
  return <String, Object?>{
    'id': '79000000-0000-4000-8000-000000000001',
    'version': 1,
    'schemaVersion': '2026-08-08-wp07-02b',
    'expiresAt': null,
    'revokedAt': null,
    'purgedAt': null,
    'machineSizeBytes': null,
    'humanSizeBytes': null,
    'available': false,
  };
}

Map<String, Object?> _deletionPayload() {
  return <String, Object?>{
    'retentionBlocked': false,
    'retentionReviewAt': null,
    'accessRevokedAt': null,
    'redactedAt': null,
    'billingUnlinkedAt': null,
  };
}

Map<String, Object?> _requestBase() {
  return <String, Object?>{
    'requestId': '78000000-0000-4000-8000-000000000001',
    'householdId': '71000000-0000-4000-8000-000000000001',
    'status': 'queued',
    'requestedAt': '2026-08-08T01:00:00.000Z',
    'processingStartedAt': null,
    'completedAt': null,
    'failedAt': null,
    'cancelledAt': null,
    'failureCode': null,
    'cancellable': true,
    'version': 1,
    'activeSubscriptionAtRequest': true,
  };
}

Map<String, Object?> _exportRequestPayload() {
  return <String, Object?>{
    ..._requestBase(),
    'kind': 'export',
    'scheduledFor': '2026-08-08T01:00:00.000Z',
    'artifact': _artifactPayload(),
    'deletion': null,
  };
}

Map<String, Object?> _deletionRequestPayload() {
  return <String, Object?>{
    ..._requestBase(),
    'kind': 'deletion',
    'scheduledFor': '2026-08-09T01:00:00.000Z',
    'artifact': null,
    'deletion': _deletionPayload(),
  };
}

Map<String, Object?> _envelope(
  Object? data, {
  String contractVersion = '2026-08-08-wp07-02b',
}) {
  return <String, Object?>{
    'data': data,
    'meta': <String, Object?>{
      'requestId': '7b000000-0000-4000-8000-000000000001',
      'contractVersion': contractVersion,
    },
  };
}
