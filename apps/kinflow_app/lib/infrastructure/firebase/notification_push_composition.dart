import 'package:flutter/foundation.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_push_gateway.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kinflow_app/infrastructure/firebase/firebase_notification_push_gateway.dart';
import 'package:kinflow_app/infrastructure/firebase/flutter_local_notification_presenter.dart';

void prepareNotificationPushBackgroundHandler(
  AppPublicConfiguration configuration,
) {
  if (kIsWeb) return;
  if (configuration.firebaseAndroidOptions == null) return;
  try {
    FirebaseNotificationPushGateway.registerBackgroundHandler();
  } on Object {
    // The production adapter will fail closed during dependency composition.
  }
}

Future<NotificationPushCoordinatorService> createNotificationPushCoordinator({
  required AppPublicConfiguration configuration,
  required NotificationRepository notificationRepository,
  required NotificationEndpointLifecycleService endpointLifecycle,
}) async {
  if (kIsWeb) {
    return const UnavailableNotificationPushCoordinator();
  }
  final FirebaseAndroidPublicOptions? options =
      configuration.firebaseAndroidOptions;
  if (options == null) {
    return const UnavailableNotificationPushCoordinator();
  }

  NotificationPushGateway? gateway;
  NotificationLocalPresenter? presenter;
  try {
    gateway = await FirebaseNotificationPushGateway.create(options);
    presenter = await FlutterLocalNotificationPresenter.create();
    return NotificationPushCoordinator(
      gateway: gateway,
      localPresenter: presenter,
      notificationRepository: notificationRepository,
      endpointLifecycle: endpointLifecycle,
      appVersion: configuration.appVersion,
    );
  } on Object {
    await gateway?.dispose();
    await presenter?.dispose();
    return const UnavailableNotificationPushCoordinator();
  }
}
