import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/account_deletion_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_account_deletion_data_source.dart';

void main() {
  test('preflight parser accepts exact nullable pending metadata', () {
    final AccountDeletionPreflightDataRecord? record =
        accountDeletionPreflightRecordFromPayload(_preflightPayload());

    expect(record?.canRequest, isTrue);
    expect(record?.pendingRequestId, isNull);
    expect(record?.cancellationWindowSeconds, 86400);
  });

  test('preflight parser rejects extra and mistyped provider fields', () {
    expect(
      accountDeletionPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'debug': 'private provider detail',
      }),
      isNull,
    );
    expect(
      accountDeletionPreflightRecordFromPayload(<String, Object?>{
        ..._preflightPayload(),
        'ownerHouseholdCount': 0.0,
      }),
      isNull,
    );
  });

  test('request parser accepts the exact privacy-safe contract', () {
    final AccountDeletionRequestDataRecord? record =
        accountDeletionRequestRecordFromPayload(_requestPayload());

    expect(record?.id, '71000000-0000-4000-8000-000000000001');
    expect(record?.type, 'deleteAccount');
    expect(record?.failureCode, isNull);
    expect(record?.version, 1);
  });

  test('request parser rejects extra identity and provider details', () {
    expect(
      accountDeletionRequestRecordFromPayload(<String, Object?>{
        ..._requestPayload(),
        'email': 'private@example.com',
      }),
      isNull,
    );
    expect(
      accountDeletionRequestRecordFromPayload(<String, Object?>{
        ..._requestPayload(),
        'version': '1',
      }),
      isNull,
    );
  });

  test('envelope pins contract version and exact metadata', () {
    final Map<String, Object?> valid = _envelope(_requestPayload());
    expect(accountDeletionEnvelopeHasValidContract(valid), isTrue);
    expect(
      accountDeletionEnvelopeHasValidContract(<String, Object?>{
        ...valid,
        'debug': true,
      }),
      isFalse,
    );
    expect(
      accountDeletionEnvelopeHasValidContract(
        _envelope(_requestPayload(), contractVersion: 'future-contract'),
      ),
      isFalse,
    );
  });

  test('stable Edge error codes map without reflecting details', () {
    expect(
      accountDeletionDataFailureFromFunctionDetails(<String, Object?>{
        'error': <String, Object?>{
          'code': 'OWNER_TRANSFER_REQUIRED',
          'providerMessage': 'private database detail',
        },
      }),
      AccountDeletionDataFailureKind.ownerTransferRequired,
    );
    expect(
      accountDeletionDataFailureFromCode(
        'SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED',
      ),
      AccountDeletionDataFailureKind.subscriptionAcknowledgementRequired,
    );
    expect(
      accountDeletionDataFailureFromCode('PGRST002'),
      AccountDeletionDataFailureKind.temporarilyUnavailable,
    );
  });
}

Map<String, Object?> _preflightPayload() {
  return <String, Object?>{
    'canRequest': true,
    'ownerHouseholdCount': 0,
    'hasActiveSubscription': false,
    'pendingRequestId': null,
    'pendingStatus': null,
    'pendingRequestVersion': null,
    'requestsEnabled': true,
    'cancellationWindowSeconds': 86400,
    'evaluatedAt': '2026-08-08T01:00:00.000Z',
  };
}

Map<String, Object?> _requestPayload() {
  return <String, Object?>{
    'id': '71000000-0000-4000-8000-000000000001',
    'type': 'deleteAccount',
    'status': 'queued',
    'requestedAt': '2026-08-08T01:00:00.000Z',
    'scheduledFor': '2026-08-09T01:00:00.000Z',
    'processingStartedAt': null,
    'completedAt': null,
    'failedAt': null,
    'cancelledAt': null,
    'failureCode': null,
    'activeSubscriptionAtRequest': false,
    'subscriptionAcknowledged': false,
    'cancellable': true,
    'version': 1,
  };
}

Map<String, Object?> _envelope(
  Object? data, {
  String contractVersion = '2026-08-08-wp07-01',
}) {
  return <String, Object?>{
    'data': data,
    'meta': <String, Object?>{
      'requestId': '73000000-0000-4000-8000-000000000001',
      'contractVersion': contractVersion,
    },
  };
}
