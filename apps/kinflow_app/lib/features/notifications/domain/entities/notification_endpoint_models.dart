import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _endpointUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final RegExp _providerTokenPattern = RegExp(r'^[\x21-\x7e]{20,4096}$');
final RegExp _revocationSecretPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
final RegExp _endpointLocalePattern = RegExp(
  r'^[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$',
);
final RegExp _endpointTimezonePattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9._+-]*(?:/[A-Za-z0-9][A-Za-z0-9._+-]*)+$',
);
final RegExp _controlCharacterPattern = RegExp(r'[\x00-\x1f\x7f]');

enum NotificationEndpointPlatform {
  ios('ios'),
  android('android');

  const NotificationEndpointPlatform(this.wireValue);

  final String wireValue;

  static NotificationEndpointPlatform? tryParse(String value) {
    for (final NotificationEndpointPlatform platform in values) {
      if (platform.wireValue == value) return platform;
    }
    return null;
  }
}

enum NotificationEndpointRevocationReason {
  clientRevoked('client_revoked'),
  tokenReassigned('token_reassigned'),
  providerUnregistered('provider_unregistered'),
  providerInvalidArgument('provider_invalid_argument'),
  membershipRemoved('membership_removed'),
  permissionRevoked('permission_revoked'),
  rollbackDisabled('rollback_disabled');

  const NotificationEndpointRevocationReason(this.wireValue);

  final String wireValue;

  static NotificationEndpointRevocationReason? tryParse(String value) {
    for (final NotificationEndpointRevocationReason reason in values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}

final class NotificationEndpointId {
  const NotificationEndpointId._(this.value);

  final String value;

  static NotificationEndpointId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _endpointUuidPattern.hasMatch(normalized)
        ? NotificationEndpointId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationEndpointId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class NotificationInstallationId {
  const NotificationInstallationId._(this.value);

  final String value;

  static NotificationInstallationId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _endpointUuidPattern.hasMatch(normalized)
        ? NotificationInstallationId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationInstallationId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class NotificationRegistrationId {
  const NotificationRegistrationId._(this.value);

  final String value;

  static NotificationRegistrationId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _endpointUuidPattern.hasMatch(normalized)
        ? NotificationRegistrationId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationRegistrationId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class NotificationProviderToken {
  const NotificationProviderToken._(this.value);

  final String value;

  static NotificationProviderToken? tryParse(String value) {
    return _providerTokenPattern.hasMatch(value)
        ? NotificationProviderToken._(value)
        : null;
  }

  @override
  String toString() => 'NotificationProviderToken(redacted)';
}

final class NotificationRevocationSecret {
  const NotificationRevocationSecret._(this.value);

  final String value;

  static NotificationRevocationSecret? tryParse(String value) {
    return _revocationSecretPattern.hasMatch(value)
        ? NotificationRevocationSecret._(value)
        : null;
  }

  @override
  String toString() => 'NotificationRevocationSecret(redacted)';
}

final class NotificationEndpointRegistrationIntent {
  const NotificationEndpointRegistrationIntent._({
    required this.householdId,
    required this.platform,
    required this.providerToken,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.runtimeVersion,
  });

  final HouseholdId householdId;
  final NotificationEndpointPlatform platform;
  final NotificationProviderToken providerToken;
  final String? locale;
  final String timezone;
  final String appVersion;
  final String runtimeVersion;

  static NotificationEndpointRegistrationIntent? tryCreate({
    required HouseholdId householdId,
    required NotificationEndpointPlatform platform,
    required String providerToken,
    required String? locale,
    required String timezone,
    required String appVersion,
    required String runtimeVersion,
  }) {
    final NotificationProviderToken? token = NotificationProviderToken.tryParse(
      providerToken,
    );
    if (token == null ||
        !_validLocale(locale) ||
        !_validTimezone(timezone) ||
        !_validText(appVersion, 1, 64) ||
        !_validText(runtimeVersion, 1, 64)) {
      return null;
    }
    return NotificationEndpointRegistrationIntent._(
      householdId: householdId,
      platform: platform,
      providerToken: token,
      locale: locale,
      timezone: timezone,
      appVersion: appVersion,
      runtimeVersion: runtimeVersion,
    );
  }

  @override
  String toString() =>
      'NotificationEndpointRegistrationIntent('
      'householdId: ${householdId.value}, platform: ${platform.wireValue}, '
      'providerToken: redacted)';
}

final class NotificationEndpointRegistrationCommand {
  const NotificationEndpointRegistrationCommand({
    required this.householdId,
    required this.installationId,
    required this.registrationId,
    required this.platform,
    required this.providerToken,
    required this.revocationSecret,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.runtimeVersion,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final NotificationInstallationId installationId;
  final NotificationRegistrationId registrationId;
  final NotificationEndpointPlatform platform;
  final NotificationProviderToken providerToken;
  final NotificationRevocationSecret revocationSecret;
  final String? locale;
  final String timezone;
  final String appVersion;
  final String runtimeVersion;
  final int expectedVersion;

  @override
  String toString() =>
      'NotificationEndpointRegistrationCommand('
      'installationId: ${installationId.value}, '
      'registrationId: ${registrationId.value}, token: redacted, '
      'revocationSecret: redacted)';
}

final class NotificationEndpointBindingProof {
  const NotificationEndpointBindingProof({
    required this.installationId,
    required this.registrationId,
    required this.revocationSecret,
  });

  final NotificationInstallationId installationId;
  final NotificationRegistrationId registrationId;
  final NotificationRevocationSecret revocationSecret;

  @override
  String toString() =>
      'NotificationEndpointBindingProof('
      'installationId: ${installationId.value}, '
      'registrationId: ${registrationId.value}, secret: redacted)';
}

final class NotificationEndpointMetadata {
  const NotificationEndpointMetadata._({
    required this.endpointId,
    required this.householdId,
    required this.memberId,
    required this.installationId,
    required this.registrationId,
    required this.platform,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.runtimeVersion,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.revocationReason,
    required this.version,
  });

  final NotificationEndpointId endpointId;
  final HouseholdId householdId;
  final HouseholdMemberId memberId;
  final NotificationInstallationId installationId;
  final NotificationRegistrationId registrationId;
  final NotificationEndpointPlatform platform;
  final String? locale;
  final String timezone;
  final String appVersion;
  final String runtimeVersion;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;
  final NotificationEndpointRevocationReason? revocationReason;
  final int version;

  bool get isActive => revokedAt == null;

  static NotificationEndpointMetadata? tryCreate({
    required String endpointId,
    required String householdId,
    required String memberId,
    required String installationId,
    required String channel,
    required String platform,
    required String permissionState,
    required String? locale,
    required String timezone,
    required String appVersion,
    required String runtimeVersion,
    required String registrationId,
    required String lastSeenAt,
    required String? revokedAt,
    required String? revocationReason,
    required int version,
  }) {
    final NotificationEndpointId? parsedEndpointId =
        NotificationEndpointId.tryParse(endpointId);
    final HouseholdId? parsedHouseholdId = HouseholdId.tryParse(householdId);
    final HouseholdMemberId? parsedMemberId = HouseholdMemberId.tryParse(
      memberId,
    );
    final NotificationInstallationId? parsedInstallationId =
        NotificationInstallationId.tryParse(installationId);
    final NotificationRegistrationId? parsedRegistrationId =
        NotificationRegistrationId.tryParse(registrationId);
    final NotificationEndpointPlatform? parsedPlatform =
        NotificationEndpointPlatform.tryParse(platform);
    final DateTime? parsedLastSeenAt = DateTime.tryParse(lastSeenAt)?.toUtc();
    final DateTime? parsedRevokedAt = revokedAt == null
        ? null
        : DateTime.tryParse(revokedAt)?.toUtc();
    final NotificationEndpointRevocationReason? parsedReason =
        revocationReason == null
        ? null
        : NotificationEndpointRevocationReason.tryParse(revocationReason);
    if (parsedEndpointId == null ||
        parsedHouseholdId == null ||
        parsedMemberId == null ||
        parsedInstallationId == null ||
        parsedRegistrationId == null ||
        channel != 'native_push' ||
        permissionState != 'granted' ||
        parsedPlatform == null ||
        !_validLocale(locale) ||
        !_validTimezone(timezone) ||
        !_validText(appVersion, 1, 64) ||
        !_validText(runtimeVersion, 1, 64) ||
        parsedLastSeenAt == null ||
        (revokedAt != null && parsedRevokedAt == null) ||
        (revocationReason != null && parsedReason == null) ||
        (parsedRevokedAt == null) != (parsedReason == null) ||
        version < 1) {
      return null;
    }
    return NotificationEndpointMetadata._(
      endpointId: parsedEndpointId,
      householdId: parsedHouseholdId,
      memberId: parsedMemberId,
      installationId: parsedInstallationId,
      registrationId: parsedRegistrationId,
      platform: parsedPlatform,
      locale: locale,
      timezone: timezone,
      appVersion: appVersion,
      runtimeVersion: runtimeVersion,
      lastSeenAt: parsedLastSeenAt,
      revokedAt: parsedRevokedAt,
      revocationReason: parsedReason,
      version: version,
    );
  }
}

bool _validLocale(String? value) {
  return value == null || _endpointLocalePattern.hasMatch(value);
}

bool _validTimezone(String value) {
  return value == 'UTC' ||
      value.length <= 100 && _endpointTimezonePattern.hasMatch(value);
}

bool _validText(String value, int minimum, int maximum) {
  return value.length >= minimum &&
      value.length <= maximum &&
      value == value.trim() &&
      !_controlCharacterPattern.hasMatch(value);
}
