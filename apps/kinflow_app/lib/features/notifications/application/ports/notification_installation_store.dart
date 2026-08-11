import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';

final class PendingNotificationEndpointBinding {
  const PendingNotificationEndpointBinding({
    required this.householdId,
    required this.installationId,
    required this.registrationId,
    required this.revocationSecret,
    required this.platform,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.runtimeVersion,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final NotificationInstallationId installationId;
  final NotificationRegistrationId registrationId;
  final NotificationRevocationSecret revocationSecret;
  final NotificationEndpointPlatform platform;
  final String? locale;
  final String timezone;
  final String appVersion;
  final String runtimeVersion;
  final int expectedVersion;

  NotificationEndpointBindingProof get proof =>
      NotificationEndpointBindingProof(
        installationId: installationId,
        registrationId: registrationId,
        revocationSecret: revocationSecret,
      );

  bool matchesIntent(
    NotificationEndpointRegistrationIntent intent,
    int currentVersion,
  ) {
    return householdId == intent.householdId &&
        platform == intent.platform &&
        locale == intent.locale &&
        timezone == intent.timezone &&
        appVersion == intent.appVersion &&
        runtimeVersion == intent.runtimeVersion &&
        expectedVersion == currentVersion;
  }

  bool matchesMetadata(NotificationEndpointMetadata metadata) {
    return metadata.isActive &&
        metadata.householdId == householdId &&
        metadata.installationId == installationId &&
        metadata.registrationId == registrationId &&
        metadata.platform == platform &&
        metadata.locale == locale &&
        metadata.timezone == timezone &&
        metadata.appVersion == appVersion &&
        metadata.runtimeVersion == runtimeVersion &&
        metadata.version > expectedVersion;
  }

  @override
  String toString() =>
      'PendingNotificationEndpointBinding('
      'installationId: ${installationId.value}, '
      'registrationId: ${registrationId.value}, secret: redacted)';
}

final class ActiveNotificationEndpointBinding {
  const ActiveNotificationEndpointBinding({
    required this.endpointId,
    required this.householdId,
    required this.installationId,
    required this.registrationId,
    required this.revocationSecret,
    required this.version,
  });

  final NotificationEndpointId endpointId;
  final HouseholdId householdId;
  final NotificationInstallationId installationId;
  final NotificationRegistrationId registrationId;
  final NotificationRevocationSecret revocationSecret;
  final int version;

  NotificationEndpointBindingProof get proof =>
      NotificationEndpointBindingProof(
        installationId: installationId,
        registrationId: registrationId,
        revocationSecret: revocationSecret,
      );

  @override
  String toString() =>
      'ActiveNotificationEndpointBinding('
      'endpointId: ${endpointId.value}, registrationId: '
      '${registrationId.value}, secret: redacted)';
}

abstract interface class NotificationInstallationStore {
  Future<NotificationInstallationId> getOrCreateInstallationId();

  Future<PendingNotificationEndpointBinding?> readPendingBinding();

  Future<void> writePendingBinding(PendingNotificationEndpointBinding binding);

  Future<void> deletePendingBinding();

  Future<ActiveNotificationEndpointBinding?> readActiveBinding();

  Future<void> writeActiveBinding(ActiveNotificationEndpointBinding binding);

  Future<void> clearAccountBindings();
}
