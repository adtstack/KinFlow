import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_endpoint_failure.dart';

abstract interface class NotificationEndpointRepository {
  Future<NotificationEndpointResult<NotificationEndpointMetadata?>> loadStatus(
    NotificationInstallationId installationId,
  );

  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationCommand command,
  );

  Future<NotificationEndpointResult<void>> revoke(
    NotificationEndpointBindingProof proof,
  );
}

sealed class NotificationEndpointResult<T> {
  const NotificationEndpointResult();
}

final class NotificationEndpointSucceeded<T>
    extends NotificationEndpointResult<T> {
  const NotificationEndpointSucceeded(this.value);

  final T value;
}

final class NotificationEndpointFailed<T>
    extends NotificationEndpointResult<T> {
  const NotificationEndpointFailed(this.failure);

  final NotificationEndpointFailure failure;
}
