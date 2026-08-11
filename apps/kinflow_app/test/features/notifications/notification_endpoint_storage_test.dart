import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/data/services/secure_notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/data/services/secure_notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _endpointId = '52000000-0000-4000-8000-000000000001';
const String _installationId = '53000000-0000-4000-8000-000000000001';
const String _registrationId = '53010000-0000-4000-8000-000000000001';
const String _secret = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const String _providerToken = 'fcm:provider-token-value-0123456789';

void main() {
  test('endpoint values validate contracts and redact secrets', () {
    final NotificationEndpointRegistrationIntent? intent =
        NotificationEndpointRegistrationIntent.tryCreate(
          householdId: HouseholdId.tryParse(_householdId)!,
          platform: NotificationEndpointPlatform.android,
          providerToken: _providerToken,
          locale: 'ko-KR',
          timezone: 'Asia/Seoul',
          appVersion: '0.1.0+1',
          runtimeVersion: 'Flutter 3.44.7',
        );
    expect(intent, isNotNull);
    expect(intent.toString(), isNot(contains(_providerToken)));
    expect(
      NotificationEndpointRegistrationIntent.tryCreate(
        householdId: HouseholdId.tryParse(_householdId)!,
        platform: NotificationEndpointPlatform.android,
        providerToken: 'short',
        locale: 'ko-KR',
        timezone: 'Asia/Seoul',
        appVersion: '0.1.0+1',
        runtimeVersion: 'Flutter 3.44.7',
      ),
      isNull,
    );
    final NotificationRevocationSecret secret =
        NotificationRevocationSecret.tryParse(_secret)!;
    expect(secret.toString(), isNot(contains(_secret)));
    expect(NotificationRevocationSecret.tryParse('${_secret}A'), isNull);
  });

  test('secure material generator emits UUIDv4 and 256-bit-shaped proof', () {
    final SecureNotificationEndpointMaterialGenerator generator =
        SecureNotificationEndpointMaterialGenerator(random: Random(42));
    final NotificationInstallationId installation = generator
        .generateInstallationId();
    final NotificationRegistrationId registration = generator
        .generateRegistrationId();
    final NotificationRevocationSecret first = generator
        .generateRevocationSecret();
    final NotificationRevocationSecret second = generator
        .generateRevocationSecret();

    expect(installation.value.substring(14, 15), '4');
    expect(registration.value.substring(14, 15), '4');
    expect(first.value, hasLength(43));
    expect(first.value, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(second.value, isNot(first.value));
  });

  test(
    'account purge preserves installation ID and removes only proofs',
    () async {
      final _MemorySecureStringStore memory = _MemorySecureStringStore();
      final SecureNotificationInstallationStore store =
          SecureNotificationInstallationStore(
            memory,
            const _FixedMaterialGenerator(),
          );
      final NotificationInstallationId installation = await store
          .getOrCreateInstallationId();
      expect(installation.value, _installationId);
      await store.writePendingBinding(_pending());
      await store.writeActiveBinding(_active());

      await store.clearAccountBindings();

      expect(await store.getOrCreateInstallationId(), installation);
      expect(await store.readPendingBinding(), isNull);
      expect(await store.readActiveBinding(), isNull);
      expect(
        memory.values[SecureNotificationInstallationStore
            .installationStorageKey],
        _installationId,
      );
      expect(memory.deleteAllCount, 0);
    },
  );

  test('secure store persists no raw provider token', () async {
    final _MemorySecureStringStore memory = _MemorySecureStringStore();
    final SecureNotificationInstallationStore store =
        SecureNotificationInstallationStore(
          memory,
          const _FixedMaterialGenerator(),
        );
    await store.writePendingBinding(_pending());
    await store.writeActiveBinding(_active());

    expect(memory.values.toString(), isNot(contains(_providerToken)));
    expect(memory.values.toString(), contains(_secret));
    expect(
      (await store.readPendingBinding())?.registrationId.value,
      _registrationId,
    );
    expect((await store.readActiveBinding())?.endpointId.value, _endpointId);
  });

  test(
    'secure store fails closed on unknown or malformed binding fields',
    () async {
      final _MemorySecureStringStore memory = _MemorySecureStringStore();
      final SecureNotificationInstallationStore store =
          SecureNotificationInstallationStore(
            memory,
            const _FixedMaterialGenerator(),
          );
      memory.values[SecureNotificationInstallationStore
              .pendingBindingStorageKey] =
          '{"unexpected":true}';
      await expectLater(store.readPendingBinding(), throwsFormatException);

      memory.values[SecureNotificationInstallationStore
              .installationStorageKey] =
          'not-a-uuid';
      final SecureNotificationInstallationStore freshStore =
          SecureNotificationInstallationStore(
            memory,
            const _FixedMaterialGenerator(),
          );
      await expectLater(
        freshStore.getOrCreateInstallationId(),
        throwsFormatException,
      );
    },
  );
}

PendingNotificationEndpointBinding _pending() {
  return PendingNotificationEndpointBinding(
    householdId: HouseholdId.tryParse(_householdId)!,
    installationId: NotificationInstallationId.tryParse(_installationId)!,
    registrationId: NotificationRegistrationId.tryParse(_registrationId)!,
    revocationSecret: NotificationRevocationSecret.tryParse(_secret)!,
    platform: NotificationEndpointPlatform.android,
    locale: 'ko-KR',
    timezone: 'Asia/Seoul',
    appVersion: '0.1.0+1',
    runtimeVersion: 'Flutter 3.44.7',
    expectedVersion: 0,
  );
}

ActiveNotificationEndpointBinding _active() {
  return ActiveNotificationEndpointBinding(
    endpointId: NotificationEndpointId.tryParse(_endpointId)!,
    householdId: HouseholdId.tryParse(_householdId)!,
    installationId: NotificationInstallationId.tryParse(_installationId)!,
    registrationId: NotificationRegistrationId.tryParse(_registrationId)!,
    revocationSecret: NotificationRevocationSecret.tryParse(_secret)!,
    version: 1,
  );
}

final class _FixedMaterialGenerator
    implements NotificationEndpointMaterialGenerator {
  const _FixedMaterialGenerator();

  @override
  NotificationInstallationId generateInstallationId() =>
      NotificationInstallationId.tryParse(_installationId)!;

  @override
  NotificationRegistrationId generateRegistrationId() =>
      NotificationRegistrationId.tryParse(_registrationId)!;

  @override
  NotificationRevocationSecret generateRevocationSecret() =>
      NotificationRevocationSecret.tryParse(_secret)!;
}

final class _MemorySecureStringStore implements SecureStringStore {
  final Map<String, String> values = <String, String>{};
  var deleteAllCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount += 1;
    values.clear();
  }
}
