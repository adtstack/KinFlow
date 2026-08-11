import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';

abstract interface class NotificationEndpointMaterialGenerator {
  NotificationInstallationId generateInstallationId();

  NotificationRegistrationId generateRegistrationId();

  NotificationRevocationSecret generateRevocationSecret();
}
