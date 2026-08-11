import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';

final class UnavailableNotificationEndpointRepository
    implements NotificationEndpointRepository {
  const UnavailableNotificationEndpointRepository();

  static const NotificationEndpointFailure _failure =
      NotificationEndpointFailure(
        NotificationEndpointFailureKind.temporarilyUnavailable,
      );

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata?>> loadStatus(
    NotificationInstallationId installationId,
  ) async =>
      const NotificationEndpointFailed<NotificationEndpointMetadata?>(_failure);

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationCommand command,
  ) async =>
      const NotificationEndpointFailed<NotificationEndpointMetadata>(_failure);

  @override
  Future<NotificationEndpointResult<void>> revoke(
    NotificationEndpointBindingProof proof,
  ) async => const NotificationEndpointFailed<void>(_failure);
}
