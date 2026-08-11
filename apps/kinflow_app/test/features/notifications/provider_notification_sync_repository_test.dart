import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_sync_data_source.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_sync_repository.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';

void main() {
  test('maps provider lifecycle and valid generations', () async {
    final _FakeNotificationSyncDataSource dataSource =
        _FakeNotificationSyncDataSource();
    final ProviderNotificationSyncRepository repository =
        ProviderNotificationSyncRepository(dataSource);
    final AuthUserId authUserId = _authUserId();

    final Future<List<NotificationSyncSignal>> values = repository
        .watch(authUserId)
        .take(4)
        .toList();
    await Future<void>.delayed(Duration.zero);
    dataSource.controller
      ..add(
        const NotificationSyncDataSignal(
          NotificationSyncDataSignalKind.connecting,
        ),
      )
      ..add(
        const NotificationSyncDataSignal(
          NotificationSyncDataSignalKind.connected,
        ),
      )
      ..add(
        const NotificationSyncDataSignal(
          NotificationSyncDataSignalKind.changed,
          generation: 7,
        ),
      )
      ..add(
        const NotificationSyncDataSignal(
          NotificationSyncDataSignalKind.disconnected,
        ),
      );

    expect(await values, <Object>[
      isA<NotificationSyncConnecting>(),
      isA<NotificationSyncConnected>(),
      isA<NotificationSyncChanged>(),
      isA<NotificationSyncDisconnected>(),
    ]);
    expect(dataSource.watchedUserIds, <String>[authUserId.value]);
    await dataSource.dispose();
  });

  test(
    'fails closed when a changed signal lacks a positive generation',
    () async {
      final _FakeNotificationSyncDataSource dataSource =
          _FakeNotificationSyncDataSource();
      final ProviderNotificationSyncRepository repository =
          ProviderNotificationSyncRepository(dataSource);

      final Future<NotificationSyncSignal> value = repository
          .watch(_authUserId())
          .first;
      await Future<void>.delayed(Duration.zero);
      dataSource.controller.add(
        const NotificationSyncDataSignal(
          NotificationSyncDataSignalKind.changed,
          generation: 0,
        ),
      );

      expect(await value, isA<NotificationSyncDisconnected>());
      await dataSource.dispose();
    },
  );
}

AuthUserId _authUserId() =>
    AuthUserId.tryParse('00000000-0000-4000-8000-000000000101')!;

final class _FakeNotificationSyncDataSource
    implements NotificationSyncDataSource {
  final StreamController<NotificationSyncDataSignal> controller =
      StreamController<NotificationSyncDataSignal>.broadcast(sync: true);
  final List<String> watchedUserIds = <String>[];

  @override
  Stream<NotificationSyncDataSignal> watchUser(String authUserId) {
    watchedUserIds.add(authUserId);
    return controller.stream;
  }

  Future<void> dispose() => controller.close();
}
