import 'package:kinflow_app/features/notifications/data/datasources/notification_endpoint_data_source.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';

final class ProviderNotificationEndpointRepository
    implements NotificationEndpointRepository {
  const ProviderNotificationEndpointRepository(this._dataSource);

  final NotificationEndpointDataSource _dataSource;

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata?>> loadStatus(
    NotificationInstallationId installationId,
  ) async {
    final NotificationEndpointDataResult<NotificationEndpointDataRecord?>
    result = await _dataSource.loadStatus(installationId: installationId.value);
    return switch (result) {
      NotificationEndpointDataSucceeded<NotificationEndpointDataRecord?>(
        :final value,
      ) =>
        _mapOptionalStatus(value, installationId),
      NotificationEndpointDataFailed<NotificationEndpointDataRecord?>(
        :final kind,
      ) =>
        NotificationEndpointFailed<NotificationEndpointMetadata?>(
          _mapFailure(kind),
        ),
    };
  }

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationCommand command,
  ) async {
    if (command.expectedVersion < 0) {
      return const NotificationEndpointFailed<NotificationEndpointMetadata>(
        NotificationEndpointFailure(
          NotificationEndpointFailureKind.invalidInput,
        ),
      );
    }
    final NotificationEndpointDataResult<NotificationEndpointDataRecord>
    result = await _dataSource.register(
      registrationId: command.registrationId.value,
      householdId: command.householdId.value,
      installationId: command.installationId.value,
      platform: command.platform.wireValue,
      token: command.providerToken.value,
      revocationSecret: command.revocationSecret.value,
      locale: command.locale,
      timezone: command.timezone,
      appVersion: command.appVersion,
      runtimeVersion: command.runtimeVersion,
      expectedVersion: command.expectedVersion,
    );
    return switch (result) {
      NotificationEndpointDataSucceeded<NotificationEndpointDataRecord>(
        :final value,
      ) =>
        _mapRegistration(value, command),
      NotificationEndpointDataFailed<NotificationEndpointDataRecord>(
        :final kind,
      ) =>
        NotificationEndpointFailed<NotificationEndpointMetadata>(
          _mapFailure(kind),
        ),
    };
  }

  @override
  Future<NotificationEndpointResult<void>> revoke(
    NotificationEndpointBindingProof proof,
  ) async {
    final NotificationEndpointDataResult<void> result = await _dataSource
        .revoke(
          installationId: proof.installationId.value,
          registrationId: proof.registrationId.value,
          revocationSecret: proof.revocationSecret.value,
        );
    return switch (result) {
      NotificationEndpointDataSucceeded<void>() =>
        const NotificationEndpointSucceeded<void>(null),
      NotificationEndpointDataFailed<void>(:final kind) =>
        NotificationEndpointFailed<void>(_mapFailure(kind)),
    };
  }

  NotificationEndpointResult<NotificationEndpointMetadata?> _mapOptionalStatus(
    NotificationEndpointDataRecord? record,
    NotificationInstallationId expectedInstallationId,
  ) {
    if (record == null) {
      return const NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
        null,
      );
    }
    final NotificationEndpointMetadata? metadata = _metadata(record);
    if (metadata == null || metadata.installationId != expectedInstallationId) {
      return const NotificationEndpointFailed<NotificationEndpointMetadata?>(
        NotificationEndpointFailure(
          NotificationEndpointFailureKind.invalidPayload,
        ),
      );
    }
    return NotificationEndpointSucceeded<NotificationEndpointMetadata?>(
      metadata,
    );
  }

  NotificationEndpointResult<NotificationEndpointMetadata> _mapRegistration(
    NotificationEndpointDataRecord record,
    NotificationEndpointRegistrationCommand command,
  ) {
    final NotificationEndpointMetadata? metadata = _metadata(record);
    if (metadata == null ||
        metadata.installationId != command.installationId ||
        metadata.registrationId != command.registrationId ||
        metadata.householdId != command.householdId ||
        metadata.platform != command.platform ||
        !metadata.isActive ||
        metadata.version <= command.expectedVersion) {
      return const NotificationEndpointFailed<NotificationEndpointMetadata>(
        NotificationEndpointFailure(
          NotificationEndpointFailureKind.invalidPayload,
        ),
      );
    }
    return NotificationEndpointSucceeded<NotificationEndpointMetadata>(
      metadata,
    );
  }

  NotificationEndpointMetadata? _metadata(
    NotificationEndpointDataRecord record,
  ) {
    return NotificationEndpointMetadata.tryCreate(
      endpointId: record.endpointId,
      householdId: record.householdId,
      memberId: record.memberId,
      installationId: record.installationId,
      channel: record.channel,
      platform: record.platform,
      permissionState: record.permissionState,
      locale: record.locale,
      timezone: record.timezone,
      appVersion: record.appVersion,
      runtimeVersion: record.runtimeVersion,
      registrationId: record.lastRegistrationId,
      lastSeenAt: record.lastSeenAt,
      revokedAt: record.revokedAt,
      revocationReason: record.revocationReason,
      version: record.version,
    );
  }

  NotificationEndpointFailure _mapFailure(
    NotificationEndpointDataFailureKind kind,
  ) {
    return NotificationEndpointFailure(switch (kind) {
      NotificationEndpointDataFailureKind.unauthenticated =>
        NotificationEndpointFailureKind.unauthenticated,
      NotificationEndpointDataFailureKind.invalidInput =>
        NotificationEndpointFailureKind.invalidInput,
      NotificationEndpointDataFailureKind.permissionDenied =>
        NotificationEndpointFailureKind.permissionDenied,
      NotificationEndpointDataFailureKind.notFoundOrForbidden =>
        NotificationEndpointFailureKind.notFoundOrForbidden,
      NotificationEndpointDataFailureKind.idempotencyConflict =>
        NotificationEndpointFailureKind.idempotencyConflict,
      NotificationEndpointDataFailureKind.versionConflict =>
        NotificationEndpointFailureKind.versionConflict,
      NotificationEndpointDataFailureKind.temporarilyUnavailable =>
        NotificationEndpointFailureKind.temporarilyUnavailable,
      NotificationEndpointDataFailureKind.invalidPayload =>
        NotificationEndpointFailureKind.invalidPayload,
      NotificationEndpointDataFailureKind.unknown =>
        NotificationEndpointFailureKind.internal,
    });
  }
}
