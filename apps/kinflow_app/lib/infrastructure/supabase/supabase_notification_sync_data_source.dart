import 'dart:async';

import 'package:kinflow_app/features/notifications/data/datasources/notification_sync_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _notificationSyncKeys = <String>{
  'auth_user_id',
  'generation',
  'changed_at',
};

final class SupabaseNotificationSyncDataSource
    implements NotificationSyncDataSource {
  SupabaseNotificationSyncDataSource(this._client);

  final SupabaseClient _client;
  var _channelSequence = 0;

  @override
  Stream<NotificationSyncDataSignal> watchUser(String authUserId) {
    late final StreamController<NotificationSyncDataSignal> controller;
    RealtimeChannel? channel;
    var cancelled = false;

    controller = StreamController<NotificationSyncDataSignal>(
      sync: true,
      onListen: () {
        if (cancelled) {
          return;
        }
        controller.add(
          const NotificationSyncDataSignal(
            NotificationSyncDataSignalKind.connecting,
          ),
        );
        try {
          channel = _client
              .channel('kinflow-notification-sync-${_channelSequence++}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'notification_sync_watermarks',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'auth_user_id',
                  value: authUserId,
                ),
                select: _notificationSyncKeys.toList(growable: false),
                callback: (PostgresChangePayload payload) {
                  if (cancelled) {
                    return;
                  }
                  final NotificationSyncDataSignal? signal =
                      notificationSyncSignalFromPayload(
                        payload.newRecord,
                        expectedAuthUserId: authUserId,
                      );
                  controller.add(
                    signal ??
                        const NotificationSyncDataSignal(
                          NotificationSyncDataSignalKind.disconnected,
                        ),
                  );
                },
              )
              .subscribe((RealtimeSubscribeStatus status, Object? _) {
                if (cancelled) {
                  return;
                }
                controller.add(
                  NotificationSyncDataSignal(switch (status) {
                    RealtimeSubscribeStatus.subscribed =>
                      NotificationSyncDataSignalKind.connected,
                    RealtimeSubscribeStatus.channelError ||
                    RealtimeSubscribeStatus.closed ||
                    RealtimeSubscribeStatus.timedOut =>
                      NotificationSyncDataSignalKind.disconnected,
                  }),
                );
              });
        } on Object {
          controller.add(
            const NotificationSyncDataSignal(
              NotificationSyncDataSignalKind.disconnected,
            ),
          );
        }
      },
      onCancel: () async {
        cancelled = true;
        final RealtimeChannel? activeChannel = channel;
        if (activeChannel != null) {
          try {
            await _client.removeChannel(activeChannel);
          } on Object {
            // Disposal is best-effort and must not expose transport details.
          }
        }
        await controller.close();
      },
    );
    return controller.stream;
  }
}

NotificationSyncDataSignal? notificationSyncSignalFromPayload(
  Object? payload, {
  required String expectedAuthUserId,
}) {
  if (payload is! Map ||
      payload.keys.any((Object? key) => key is! String) ||
      payload.keys
          .cast<String>()
          .toSet()
          .difference(_notificationSyncKeys)
          .isNotEmpty ||
      _notificationSyncKeys
          .difference(payload.keys.cast<String>().toSet())
          .isNotEmpty) {
    return null;
  }
  final Object? authUserId = payload['auth_user_id'];
  final Object? generation = payload['generation'];
  final Object? changedAt = payload['changed_at'];
  if (authUserId is! String ||
      authUserId.toLowerCase() != expectedAuthUserId.toLowerCase() ||
      generation is! int ||
      generation < 1 ||
      changedAt is! String) {
    return null;
  }
  final DateTime? parsedChangedAt = DateTime.tryParse(changedAt);
  if (parsedChangedAt == null || !parsedChangedAt.isUtc) {
    return null;
  }
  return NotificationSyncDataSignal(
    NotificationSyncDataSignalKind.changed,
    generation: generation,
  );
}
