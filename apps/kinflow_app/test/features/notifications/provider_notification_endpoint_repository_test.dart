import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_endpoint_data_source.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';

const String _endpointId = '52000000-0000-4000-8000-000000000001';
const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _memberId = '33333333-3333-4333-8333-333333333333';
const String _installationId = '53000000-0000-4000-8000-000000000001';
const String _registrationId = '53010000-0000-4000-8000-000000000001';
const String _secret = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const String _token = 'fcm:provider-token-value-0123456789';

void main() {
  test('repository maps status and enforces installation ownership', () async {
    final _FakeEndpointDataSource dataSource = _FakeEndpointDataSource(
      statusResult:
          NotificationEndpointDataSucceeded<NotificationEndpointDataRecord?>(
            _record(),
          ),
    );
    final ProviderNotificationEndpointRepository repository =
        ProviderNotificationEndpointRepository(dataSource);
    final NotificationEndpointResult<NotificationEndpointMetadata?> result =
        await repository.loadStatus(
          NotificationInstallationId.tryParse(_installationId)!,
        );
    expect(
      result,
      isA<NotificationEndpointSucceeded<NotificationEndpointMetadata?>>(),
    );
    expect(
      (result as NotificationEndpointSucceeded<NotificationEndpointMetadata?>)
          .value
          ?.endpointId
          .value,
      _endpointId,
    );

    dataSource.statusResult =
        NotificationEndpointDataSucceeded<NotificationEndpointDataRecord?>(
          _record(installationId: '53000000-0000-4000-8000-000000000099'),
        );
    final NotificationEndpointResult<NotificationEndpointMetadata?> mismatch =
        await repository.loadStatus(
          NotificationInstallationId.tryParse(_installationId)!,
        );
    expect(
      (mismatch as NotificationEndpointFailed<NotificationEndpointMetadata?>)
          .failure
          .kind,
      NotificationEndpointFailureKind.invalidPayload,
    );
  });

  test(
    'registration forwards secrets once and validates echoed command IDs',
    () async {
      final _FakeEndpointDataSource dataSource = _FakeEndpointDataSource(
        registerResult:
            NotificationEndpointDataSucceeded<NotificationEndpointDataRecord>(
              _record(),
            ),
      );
      final ProviderNotificationEndpointRepository repository =
          ProviderNotificationEndpointRepository(dataSource);
      final NotificationEndpointResult<NotificationEndpointMetadata> result =
          await repository.register(_command());

      expect(
        result,
        isA<NotificationEndpointSucceeded<NotificationEndpointMetadata>>(),
      );
      expect(dataSource.token, _token);
      expect(dataSource.revocationSecret, _secret);
      expect(dataSource.expectedVersion, 0);

      dataSource.registerResult =
          NotificationEndpointDataSucceeded<NotificationEndpointDataRecord>(
            _record(registrationId: '53010000-0000-4000-8000-000000000099'),
          );
      final NotificationEndpointResult<NotificationEndpointMetadata> mismatch =
          await repository.register(_command());
      expect(
        (mismatch as NotificationEndpointFailed<NotificationEndpointMetadata>)
            .failure
            .kind,
        NotificationEndpointFailureKind.invalidPayload,
      );
    },
  );

  test('data failures map to domain retry and conflict semantics', () async {
    final _FakeEndpointDataSource dataSource = _FakeEndpointDataSource(
      registerResult:
          const NotificationEndpointDataFailed<NotificationEndpointDataRecord>(
            NotificationEndpointDataFailureKind.versionConflict,
          ),
      revokeResult: const NotificationEndpointDataFailed<void>(
        NotificationEndpointDataFailureKind.temporarilyUnavailable,
      ),
    );
    final ProviderNotificationEndpointRepository repository =
        ProviderNotificationEndpointRepository(dataSource);
    final NotificationEndpointResult<NotificationEndpointMetadata> register =
        await repository.register(_command());
    expect(
      (register as NotificationEndpointFailed<NotificationEndpointMetadata>)
          .failure
          .kind,
      NotificationEndpointFailureKind.versionConflict,
    );
    final NotificationEndpointResult<void> revoke = await repository.revoke(
      NotificationEndpointBindingProof(
        installationId: NotificationInstallationId.tryParse(_installationId)!,
        registrationId: NotificationRegistrationId.tryParse(_registrationId)!,
        revocationSecret: NotificationRevocationSecret.tryParse(_secret)!,
      ),
    );
    expect(
      (revoke as NotificationEndpointFailed<void>).failure.kind,
      NotificationEndpointFailureKind.temporarilyUnavailable,
    );
  });
}

NotificationEndpointRegistrationCommand _command() {
  return NotificationEndpointRegistrationCommand(
    householdId: HouseholdId.tryParse(_householdId)!,
    installationId: NotificationInstallationId.tryParse(_installationId)!,
    registrationId: NotificationRegistrationId.tryParse(_registrationId)!,
    platform: NotificationEndpointPlatform.android,
    providerToken: NotificationProviderToken.tryParse(_token)!,
    revocationSecret: NotificationRevocationSecret.tryParse(_secret)!,
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: '0.1.0+1',
    runtimeVersion: 'Flutter 3.44.7',
    expectedVersion: 0,
  );
}

NotificationEndpointDataRecord _record({
  String installationId = _installationId,
  String registrationId = _registrationId,
}) {
  return NotificationEndpointDataRecord(
    endpointId: _endpointId,
    householdId: _householdId,
    memberId: _memberId,
    installationId: installationId,
    channel: 'native_push',
    platform: 'android',
    permissionState: 'granted',
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: '0.1.0+1',
    runtimeVersion: 'Flutter 3.44.7',
    lastRegistrationId: registrationId,
    lastSeenAt: '2030-01-01T00:00:00.000Z',
    revokedAt: null,
    revocationReason: null,
    version: 1,
  );
}

final class _FakeEndpointDataSource implements NotificationEndpointDataSource {
  _FakeEndpointDataSource({
    this.statusResult =
        const NotificationEndpointDataSucceeded<
          NotificationEndpointDataRecord?
        >(null),
    this.registerResult =
        const NotificationEndpointDataFailed<NotificationEndpointDataRecord>(
          NotificationEndpointDataFailureKind.temporarilyUnavailable,
        ),
    this.revokeResult = const NotificationEndpointDataSucceeded<void>(null),
  });

  NotificationEndpointDataResult<NotificationEndpointDataRecord?> statusResult;
  NotificationEndpointDataResult<NotificationEndpointDataRecord> registerResult;
  NotificationEndpointDataResult<void> revokeResult;
  String? token;
  String? revocationSecret;
  int? expectedVersion;

  @override
  Future<NotificationEndpointDataResult<NotificationEndpointDataRecord?>>
  loadStatus({required String installationId}) async => statusResult;

  @override
  Future<NotificationEndpointDataResult<NotificationEndpointDataRecord>>
  register({
    required String registrationId,
    required String householdId,
    required String installationId,
    required String platform,
    required String token,
    required String revocationSecret,
    required String? locale,
    required String timezone,
    required String appVersion,
    required String runtimeVersion,
    required int expectedVersion,
  }) async {
    this.token = token;
    this.revocationSecret = revocationSecret;
    this.expectedVersion = expectedVersion;
    return registerResult;
  }

  @override
  Future<NotificationEndpointDataResult<void>> revoke({
    required String installationId,
    required String registrationId,
    required String revocationSecret,
  }) async => revokeResult;
}
