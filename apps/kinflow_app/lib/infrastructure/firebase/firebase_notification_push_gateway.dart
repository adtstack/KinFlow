import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_push_gateway.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';

@pragma('vm:entry-point')
Future<void> kinFlowFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  notificationPushEnvelopeFromRemoteMessage(message);
}

final class FirebaseNotificationPushGateway implements NotificationPushGateway {
  FirebaseNotificationPushGateway._(this._messaging);

  static const MethodChannel _settingsChannel = MethodChannel(
    'me.newlines.kinflow/notification_settings',
  );
  static bool _backgroundHandlerRegistered = false;

  final FirebaseMessaging _messaging;
  final StreamController<NotificationPushEnvelope> _foregroundMessages =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  final StreamController<NotificationPushEnvelope> _notificationOpens =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  final List<StreamSubscription<RemoteMessage>> _subscriptions =
      <StreamSubscription<RemoteMessage>>[];
  bool _initialNotificationConsumed = false;
  bool _disposed = false;

  static Future<FirebaseNotificationPushGateway> create(
    FirebaseAndroidPublicOptions options,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Android Firebase Messaging is unavailable.');
    }
    final FirebaseOptions firebaseOptions = FirebaseOptions(
      apiKey: options.apiKey,
      appId: options.appId,
      messagingSenderId: options.messagingSenderId,
      projectId: options.projectId,
    );
    final FirebaseApp app;
    if (Firebase.apps.isEmpty) {
      app = await Firebase.initializeApp(options: firebaseOptions);
    } else {
      app = Firebase.app();
      if (!_sameOptions(app.options, firebaseOptions)) {
        throw StateError('Firebase default app configuration mismatch.');
      }
    }
    registerBackgroundHandler();
    final FirebaseNotificationPushGateway gateway =
        FirebaseNotificationPushGateway._(FirebaseMessaging.instance);
    gateway._attachStreams();
    return gateway;
  }

  static void registerBackgroundHandler() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Android Firebase Messaging is unavailable.');
    }
    if (_backgroundHandlerRegistered) return;
    FirebaseMessaging.onBackgroundMessage(
      kinFlowFirebaseMessagingBackgroundHandler,
    );
    _backgroundHandlerRegistered = true;
  }

  @override
  bool get isAvailable => !_disposed;

  @override
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;

  @override
  Stream<NotificationPushEnvelope> get foregroundMessages =>
      _foregroundMessages.stream;

  @override
  Stream<NotificationPushEnvelope> get notificationOpens =>
      _notificationOpens.stream;

  void _attachStreams() {
    _subscriptions
      ..add(
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final NotificationPushEnvelope? envelope =
              notificationPushEnvelopeFromRemoteMessage(message);
          if (envelope != null && !_foregroundMessages.isClosed) {
            _foregroundMessages.add(envelope);
          }
        }),
      )
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final NotificationPushEnvelope? envelope =
              notificationPushEnvelopeFromRemoteMessage(message);
          if (envelope != null && !_notificationOpens.isClosed) {
            _notificationOpens.add(envelope);
          }
        }),
      );
  }

  @override
  Future<NotificationPushPermission> currentPermission() async {
    return _permission(
      (await _messaging.getNotificationSettings()).authorizationStatus,
    );
  }

  @override
  Future<NotificationPushPermission> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return _permission(settings.authorizationStatus);
  }

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async {
    if (_initialNotificationConsumed) return null;
    _initialNotificationConsumed = true;
    return notificationPushEnvelopeFromRemoteMessage(
      await _messaging.getInitialMessage(),
    );
  }

  @override
  Future<bool> openSystemSettings() async {
    return await _settingsChannel.invokeMethod<bool>(
          'openNotificationSettings',
        ) ??
        false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final StreamSubscription<RemoteMessage> subscription
        in _subscriptions) {
      await subscription.cancel();
    }
    await _foregroundMessages.close();
    await _notificationOpens.close();
  }
}

NotificationPushEnvelope? notificationPushEnvelopeFromRemoteMessage(
  RemoteMessage? message,
) {
  if (message == null) return null;
  return NotificationPushEnvelope.tryParse(
    message.data.map<String, Object?>(
      (String key, dynamic value) => MapEntry<String, Object?>(key, value),
    ),
  );
}

NotificationPushPermission _permission(AuthorizationStatus status) {
  return switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => NotificationPushPermission.authorized,
    AuthorizationStatus.denied => NotificationPushPermission.denied,
    AuthorizationStatus.notDetermined =>
      NotificationPushPermission.notDetermined,
  };
}

bool _sameOptions(FirebaseOptions left, FirebaseOptions right) {
  return left.apiKey == right.apiKey &&
      left.appId == right.appId &&
      left.messagingSenderId == right.messagingSenderId &&
      left.projectId == right.projectId;
}
