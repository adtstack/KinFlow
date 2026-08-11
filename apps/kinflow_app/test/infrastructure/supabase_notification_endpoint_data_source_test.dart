import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_endpoint_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_notification_endpoint_data_source.dart';

const String _endpointId = '52000000-0000-4000-8000-000000000001';
const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _memberId = '33333333-3333-4333-8333-333333333333';
const String _installationId = '53000000-0000-4000-8000-000000000001';
const String _registrationId = '53010000-0000-4000-8000-000000000001';

void main() {
  test('status parser accepts one exact metadata-only row', () {
    final NotificationEndpointDataRecord? record =
        notificationEndpointStatusRecordFromPayload(<Object?>[_statusRow()]);
    expect(record?.endpointId, _endpointId);
    expect(record?.installationId, _installationId);
    expect(record?.lastRegistrationId, _registrationId);
    expect(record?.revokedAt, isNull);
  });

  test('status parser rejects extra token material and multiple rows', () {
    expect(
      notificationEndpointStatusRecordFromPayload(<Object?>[
        <String, Object?>{..._statusRow(), 'token_fingerprint': 'unsafe'},
      ]),
      isNull,
    );
    expect(
      notificationEndpointStatusRecordFromPayload(<Object?>[
        _statusRow(),
        _statusRow(),
      ]),
      isNull,
    );
  });

  test('function parser requires exact data and metadata envelopes', () {
    final Map<String, Object?> payload = _functionEnvelope(_functionRow());
    final NotificationEndpointDataRecord? record =
        notificationEndpointFunctionRecordFromEnvelope(payload);
    expect(record?.version, 1);
    expect(record?.platform, 'android');

    expect(
      notificationEndpointFunctionRecordFromEnvelope(<String, Object?>{
        ...payload,
        'debug': true,
      }),
      isNull,
    );
    expect(
      notificationEndpointFunctionRecordFromEnvelope(
        _functionEnvelope(<String, Object?>{
          ..._functionRow(),
          'revocationSecret': 'unsafe',
        }),
      ),
      isNull,
    );
  });

  test('revocation parser hides endpoint existence behind one boolean', () {
    expect(
      notificationEndpointRevocationEnvelopeIsValid(
        _functionEnvelope(<String, Object?>{'revoked': true}),
      ),
      isTrue,
    );
    expect(
      notificationEndpointRevocationEnvelopeIsValid(
        _functionEnvelope(<String, Object?>{'revoked': true, 'count': 0}),
      ),
      isFalse,
    );
  });

  test('stable Edge and PostgREST errors map without provider detail', () {
    expect(
      notificationEndpointDataFailureFromFunctionDetails(<String, Object?>{
        'error': <String, Object?>{
          'code': 'VERSION_CONFLICT',
          'debug': 'private provider detail',
        },
      }),
      NotificationEndpointDataFailureKind.versionConflict,
    );
    expect(
      notificationEndpointDataFailureFromFunctionDetails(<String, Object?>{
        'error': <String, Object?>{'code': 'IDEMPOTENCY_KEY_REUSED'},
      }),
      NotificationEndpointDataFailureKind.idempotencyConflict,
    );
    expect(
      notificationEndpointDataFailureFromProviderCode('KND02'),
      NotificationEndpointDataFailureKind.unauthenticated,
    );
    expect(
      notificationEndpointDataFailureFromProviderCode('PGRST002'),
      NotificationEndpointDataFailureKind.temporarilyUnavailable,
    );
  });
}

Map<String, Object?> _statusRow() {
  return <String, Object?>{
    'endpoint_id': _endpointId,
    'household_id': _householdId,
    'member_id': _memberId,
    'installation_id': _installationId,
    'channel': 'native_push',
    'platform': 'android',
    'permission_state': 'granted',
    'locale': 'ko-KR',
    'timezone': 'Asia/Seoul',
    'app_version': '0.1.0+1',
    'runtime_version': 'Flutter 3.44.7',
    'last_registration_id': _registrationId,
    'last_seen_at': '2030-01-01T00:00:00.000Z',
    'revoked_at': null,
    'revocation_reason': null,
    'version': 1,
  };
}

Map<String, Object?> _functionRow() {
  return <String, Object?>{
    'endpointId': _endpointId,
    'householdId': _householdId,
    'memberId': _memberId,
    'installationId': _installationId,
    'channel': 'native_push',
    'platform': 'android',
    'permissionState': 'granted',
    'locale': 'ko-KR',
    'timezone': 'Asia/Seoul',
    'appVersion': '0.1.0+1',
    'runtimeVersion': 'Flutter 3.44.7',
    'lastRegistrationId': _registrationId,
    'lastSeenAt': '2030-01-01T00:00:00.000Z',
    'revokedAt': null,
    'revocationReason': null,
    'version': 1,
  };
}

Map<String, Object?> _functionEnvelope(Map<String, Object?> data) {
  return <String, Object?>{
    'data': data,
    'meta': <String, Object?>{
      'contractVersion': '2026-08-08-wp05-03',
      'requestId': '53030000-0000-4000-8000-000000000001',
    },
  };
}
