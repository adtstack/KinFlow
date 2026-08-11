import 'dart:convert';

import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_endpoint_material_generator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_installation_store.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class SecureNotificationInstallationStore
    implements NotificationInstallationStore {
  SecureNotificationInstallationStore(this._store, this._materialGenerator);

  static const String installationStorageKey =
      'notification_installation_id_v1';
  static const String pendingBindingStorageKey =
      'notification_endpoint_pending_v1';
  static const String activeBindingStorageKey =
      'notification_endpoint_active_v1';

  static const Set<String> _pendingKeys = <String>{
    'householdId',
    'installationId',
    'registrationId',
    'revocationSecret',
    'platform',
    'locale',
    'timezone',
    'appVersion',
    'runtimeVersion',
    'expectedVersion',
  };
  static const Set<String> _activeKeys = <String>{
    'endpointId',
    'householdId',
    'installationId',
    'registrationId',
    'revocationSecret',
    'version',
  };

  final SecureStringStore _store;
  final NotificationEndpointMaterialGenerator _materialGenerator;
  Future<void>? _initialization;
  Future<NotificationInstallationId>? _installation;

  @override
  Future<NotificationInstallationId> getOrCreateInstallationId() {
    return _installation ??= _loadOrCreateInstallationId();
  }

  @override
  Future<PendingNotificationEndpointBinding?> readPendingBinding() async {
    await _initialize();
    final String? value = await _store.read(pendingBindingStorageKey);
    return value == null ? null : _pendingFromJson(value);
  }

  @override
  Future<void> writePendingBinding(
    PendingNotificationEndpointBinding binding,
  ) async {
    await _initialize();
    await _store.write(
      pendingBindingStorageKey,
      jsonEncode(<String, Object?>{
        'householdId': binding.householdId.value,
        'installationId': binding.installationId.value,
        'registrationId': binding.registrationId.value,
        'revocationSecret': binding.revocationSecret.value,
        'platform': binding.platform.wireValue,
        'locale': binding.locale,
        'timezone': binding.timezone,
        'appVersion': binding.appVersion,
        'runtimeVersion': binding.runtimeVersion,
        'expectedVersion': binding.expectedVersion,
      }),
    );
  }

  @override
  Future<void> deletePendingBinding() async {
    await _initialize();
    await _store.delete(pendingBindingStorageKey);
  }

  @override
  Future<ActiveNotificationEndpointBinding?> readActiveBinding() async {
    await _initialize();
    final String? value = await _store.read(activeBindingStorageKey);
    return value == null ? null : _activeFromJson(value);
  }

  @override
  Future<void> writeActiveBinding(
    ActiveNotificationEndpointBinding binding,
  ) async {
    await _initialize();
    await _store.write(
      activeBindingStorageKey,
      jsonEncode(<String, Object?>{
        'endpointId': binding.endpointId.value,
        'householdId': binding.householdId.value,
        'installationId': binding.installationId.value,
        'registrationId': binding.registrationId.value,
        'revocationSecret': binding.revocationSecret.value,
        'version': binding.version,
      }),
    );
  }

  @override
  Future<void> clearAccountBindings() async {
    await _initialize();
    await _store.delete(activeBindingStorageKey);
    await _store.delete(pendingBindingStorageKey);
  }

  Future<NotificationInstallationId> _loadOrCreateInstallationId() async {
    await _initialize();
    final String? stored = await _store.read(installationStorageKey);
    if (stored != null) {
      final NotificationInstallationId? installationId =
          NotificationInstallationId.tryParse(stored);
      if (installationId == null) {
        throw const FormatException('Invalid notification installation ID.');
      }
      return installationId;
    }
    final NotificationInstallationId installationId = _materialGenerator
        .generateInstallationId();
    await _store.write(installationStorageKey, installationId.value);
    return installationId;
  }

  Future<void> _initialize() {
    return _initialization ??= _store.initialize();
  }

  PendingNotificationEndpointBinding _pendingFromJson(String value) {
    final Map<String, Object?> map = _exactJsonMap(value, _pendingKeys);
    final HouseholdId? householdId = _householdId(map['householdId']);
    final NotificationInstallationId? installationId = _installationId(
      map['installationId'],
    );
    final NotificationRegistrationId? registrationId = _registrationId(
      map['registrationId'],
    );
    final NotificationRevocationSecret? secret = _secret(
      map['revocationSecret'],
    );
    final NotificationEndpointPlatform? platform = map['platform'] is String
        ? NotificationEndpointPlatform.tryParse(map['platform']! as String)
        : null;
    final Object? expectedVersion = map['expectedVersion'];
    if (householdId == null ||
        installationId == null ||
        registrationId == null ||
        secret == null ||
        platform == null ||
        map['locale'] != null && map['locale'] is! String ||
        map['timezone'] is! String ||
        map['appVersion'] is! String ||
        map['runtimeVersion'] is! String ||
        expectedVersion is! int ||
        expectedVersion < 0) {
      throw const FormatException('Invalid pending notification binding.');
    }
    final NotificationEndpointRegistrationIntent? intent =
        NotificationEndpointRegistrationIntent.tryCreate(
          householdId: householdId,
          platform: platform,
          providerToken: 'validation-only-provider-token',
          locale: map['locale'] as String?,
          timezone: map['timezone']! as String,
          appVersion: map['appVersion']! as String,
          runtimeVersion: map['runtimeVersion']! as String,
        );
    if (intent == null) {
      throw const FormatException('Invalid pending notification metadata.');
    }
    return PendingNotificationEndpointBinding(
      householdId: householdId,
      installationId: installationId,
      registrationId: registrationId,
      revocationSecret: secret,
      platform: platform,
      locale: intent.locale,
      timezone: intent.timezone,
      appVersion: intent.appVersion,
      runtimeVersion: intent.runtimeVersion,
      expectedVersion: expectedVersion,
    );
  }

  ActiveNotificationEndpointBinding _activeFromJson(String value) {
    final Map<String, Object?> map = _exactJsonMap(value, _activeKeys);
    final NotificationEndpointId? endpointId = map['endpointId'] is String
        ? NotificationEndpointId.tryParse(map['endpointId']! as String)
        : null;
    final HouseholdId? householdId = _householdId(map['householdId']);
    final NotificationInstallationId? installationId = _installationId(
      map['installationId'],
    );
    final NotificationRegistrationId? registrationId = _registrationId(
      map['registrationId'],
    );
    final NotificationRevocationSecret? secret = _secret(
      map['revocationSecret'],
    );
    final Object? version = map['version'];
    if (endpointId == null ||
        householdId == null ||
        installationId == null ||
        registrationId == null ||
        secret == null ||
        version is! int ||
        version < 1) {
      throw const FormatException('Invalid active notification binding.');
    }
    return ActiveNotificationEndpointBinding(
      endpointId: endpointId,
      householdId: householdId,
      installationId: installationId,
      registrationId: registrationId,
      revocationSecret: secret,
      version: version,
    );
  }

  Map<String, Object?> _exactJsonMap(String value, Set<String> keys) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on Object {
      throw const FormatException('Invalid notification binding JSON.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != keys.length ||
        !decoded.keys.toSet().containsAll(keys)) {
      throw const FormatException('Invalid notification binding shape.');
    }
    return Map<String, Object?>.from(decoded);
  }

  HouseholdId? _householdId(Object? value) {
    return value is String ? HouseholdId.tryParse(value) : null;
  }

  NotificationInstallationId? _installationId(Object? value) {
    return value is String ? NotificationInstallationId.tryParse(value) : null;
  }

  NotificationRegistrationId? _registrationId(Object? value) {
    return value is String ? NotificationRegistrationId.tryParse(value) : null;
  }

  NotificationRevocationSecret? _secret(Object? value) {
    return value is String
        ? NotificationRevocationSecret.tryParse(value)
        : null;
  }
}
