import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';

abstract interface class NotificationPushGateway {
  bool get isAvailable;

  Stream<String> get tokenChanges;

  Stream<NotificationPushEnvelope> get foregroundMessages;

  Stream<NotificationPushEnvelope> get notificationOpens;

  Future<NotificationPushPermission> currentPermission();

  Future<NotificationPushPermission> requestPermission();

  Future<String?> currentToken();

  Future<NotificationPushEnvelope?> takeInitialNotification();

  Future<bool> openSystemSettings();

  Future<void> dispose();
}

abstract interface class NotificationLocalPresenter {
  bool get isAvailable;

  Stream<NotificationPushEnvelope> get notificationOpens;

  Future<NotificationPushEnvelope?> takeInitialNotification();

  Future<void> show(
    NotificationPushEnvelope envelope,
    NotificationPushPresentationContent content,
  );

  Future<void> dispose();
}

final class UnavailableNotificationPushGateway
    implements NotificationPushGateway {
  const UnavailableNotificationPushGateway();

  @override
  bool get isAvailable => false;

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  Stream<NotificationPushEnvelope> get foregroundMessages =>
      const Stream<NotificationPushEnvelope>.empty();

  @override
  Stream<NotificationPushEnvelope> get notificationOpens =>
      const Stream<NotificationPushEnvelope>.empty();

  @override
  Future<NotificationPushPermission> currentPermission() async =>
      NotificationPushPermission.unavailable;

  @override
  Future<NotificationPushPermission> requestPermission() async =>
      NotificationPushPermission.unavailable;

  @override
  Future<String?> currentToken() async => null;

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async => null;

  @override
  Future<bool> openSystemSettings() async => false;

  @override
  Future<void> dispose() async {}
}

final class UnavailableNotificationLocalPresenter
    implements NotificationLocalPresenter {
  const UnavailableNotificationLocalPresenter();

  @override
  bool get isAvailable => false;

  @override
  Stream<NotificationPushEnvelope> get notificationOpens =>
      const Stream<NotificationPushEnvelope>.empty();

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async => null;

  @override
  Future<void> show(
    NotificationPushEnvelope envelope,
    NotificationPushPresentationContent content,
  ) async {}

  @override
  Future<void> dispose() async {}
}
