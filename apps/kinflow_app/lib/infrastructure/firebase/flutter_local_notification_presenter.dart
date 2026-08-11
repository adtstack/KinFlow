import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_push_gateway.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';

final class FlutterLocalNotificationPresenter
    implements NotificationLocalPresenter {
  FlutterLocalNotificationPresenter._(this._plugin);

  static const String channelId = 'kinflow_reminders';
  static const String iconName = 'ic_stat_kinflow_notification';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationPushEnvelope> _notificationOpens =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  NotificationPushEnvelope? _initialNotification;
  bool _initialNotificationConsumed = false;
  bool _disposed = false;

  static Future<FlutterLocalNotificationPresenter> create({
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    final FlutterLocalNotificationPresenter presenter =
        FlutterLocalNotificationPresenter._(
          plugin ?? FlutterLocalNotificationsPlugin(),
        );
    await presenter._initialize();
    return presenter;
  }

  Future<void> _initialize() async {
    final bool initialized =
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings(iconName),
          ),
          onDidReceiveNotificationResponse: _onNotificationResponse,
        ) ??
        false;
    if (!initialized) {
      throw StateError('Local notification initialization failed.');
    }
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      _initialNotification = notificationPushEnvelopeFromLocalPayload(
        details?.notificationResponse?.payload,
      );
    }
  }

  @override
  bool get isAvailable => !_disposed;

  @override
  Stream<NotificationPushEnvelope> get notificationOpens =>
      _notificationOpens.stream;

  void _onNotificationResponse(NotificationResponse response) {
    final NotificationPushEnvelope? envelope =
        notificationPushEnvelopeFromLocalPayload(response.payload);
    if (envelope != null && !_notificationOpens.isClosed) {
      _notificationOpens.add(envelope);
    }
  }

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async {
    if (_initialNotificationConsumed) return null;
    _initialNotificationConsumed = true;
    return _initialNotification;
  }

  @override
  Future<void> show(
    NotificationPushEnvelope envelope,
    NotificationPushPresentationContent content,
  ) {
    return _plugin.show(
      id: notificationIdForDelivery(envelope.deliveryId),
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          content.channelName,
          channelDescription: content.channelDescription,
          icon: iconName,
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
      payload: jsonEncode(envelope.toData()),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _notificationOpens.close();
  }
}

NotificationPushEnvelope? notificationPushEnvelopeFromLocalPayload(
  String? payload,
) {
  if (payload == null || payload.length > 4096) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on Object {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  return NotificationPushEnvelope.tryParse(Map<String, Object?>.from(decoded));
}

int notificationIdForDelivery(String deliveryId) {
  final String compact = deliveryId.replaceAll('-', '');
  if (compact.length != 32) return 0;
  return int.parse(compact.substring(24), radix: 16) & 0x7fffffff;
}
