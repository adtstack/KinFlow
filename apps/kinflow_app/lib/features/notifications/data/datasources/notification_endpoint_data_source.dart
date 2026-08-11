enum NotificationEndpointDataFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  notFoundOrForbidden,
  idempotencyConflict,
  versionConflict,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class NotificationEndpointDataRecord {
  const NotificationEndpointDataRecord({
    required this.endpointId,
    required this.householdId,
    required this.memberId,
    required this.installationId,
    required this.channel,
    required this.platform,
    required this.permissionState,
    required this.locale,
    required this.timezone,
    required this.appVersion,
    required this.runtimeVersion,
    required this.lastRegistrationId,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.revocationReason,
    required this.version,
  });

  final String endpointId;
  final String householdId;
  final String memberId;
  final String installationId;
  final String channel;
  final String platform;
  final String permissionState;
  final String? locale;
  final String timezone;
  final String appVersion;
  final String runtimeVersion;
  final String lastRegistrationId;
  final String lastSeenAt;
  final String? revokedAt;
  final String? revocationReason;
  final int version;
}

abstract interface class NotificationEndpointDataSource {
  Future<NotificationEndpointDataResult<NotificationEndpointDataRecord?>>
  loadStatus({required String installationId});

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
  });

  Future<NotificationEndpointDataResult<void>> revoke({
    required String installationId,
    required String registrationId,
    required String revocationSecret,
  });
}

sealed class NotificationEndpointDataResult<T> {
  const NotificationEndpointDataResult();
}

final class NotificationEndpointDataSucceeded<T>
    extends NotificationEndpointDataResult<T> {
  const NotificationEndpointDataSucceeded(this.value);

  final T value;
}

final class NotificationEndpointDataFailed<T>
    extends NotificationEndpointDataResult<T> {
  const NotificationEndpointDataFailed(this.kind);

  final NotificationEndpointDataFailureKind kind;
}
