import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/application/notification_sync_session.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';

import '../../support/fakes/fake_notification_sync_dependencies.dart';

void main() {
  test(
    'coalesces duplicate, out-of-order, and in-flight invalidations',
    () async {
      final FakeNotificationSyncRepository repository =
          FakeNotificationSyncRepository();
      final List<Completer<void>> refreshes = <Completer<void>>[];
      final List<NotificationSyncConnectionStatus> statuses =
          <NotificationSyncConnectionStatus>[];
      final NotificationSyncSession session = NotificationSyncSession(
        repository,
        () {
          final Completer<void> completer = Completer<void>();
          refreshes.add(completer);
          return completer.future;
        },
        statuses.add,
      );
      addTearDown(() async {
        for (final Completer<void> refresh in refreshes) {
          if (!refresh.isCompleted) {
            refresh.complete();
          }
        }
        await session.dispose();
        await repository.dispose();
      });

      await session.start(_authUserId());
      repository.latest.add(const NotificationSyncConnected());
      await _flush();
      expect(refreshes, hasLength(1));
      expect(statuses.last, NotificationSyncConnectionStatus.live);

      repository.latest
        ..add(const NotificationSyncChanged(8))
        ..add(const NotificationSyncChanged(8))
        ..add(const NotificationSyncChanged(7));
      await _flush();
      expect(refreshes, hasLength(1));

      refreshes.first.complete();
      await _flush();
      expect(refreshes, hasLength(2));
      refreshes.last.complete();
      await _flush();
      expect(refreshes, hasLength(2));
    },
  );

  test('retains disconnected status and full-refetches on reconnect', () async {
    final FakeNotificationSyncRepository repository =
        FakeNotificationSyncRepository();
    final List<NotificationSyncConnectionStatus> statuses =
        <NotificationSyncConnectionStatus>[];
    var refreshCount = 0;
    final NotificationSyncSession session = NotificationSyncSession(
      repository,
      () async => refreshCount += 1,
      statuses.add,
    );
    addTearDown(() async {
      await session.dispose();
      await repository.dispose();
    });

    await session.start(_authUserId());
    repository.latest.add(const NotificationSyncConnected());
    await _flush();
    expect(refreshCount, 1);

    repository.latest.add(const NotificationSyncDisconnected());
    expect(statuses.last, NotificationSyncConnectionStatus.disconnected);

    await session.reconnect();
    expect(repository.watchCount, 2);
    expect(statuses.last, NotificationSyncConnectionStatus.connecting);
    expect(refreshCount, 2);

    repository.latest.add(const NotificationSyncConnected());
    await _flush();
    expect(statuses.last, NotificationSyncConnectionStatus.live);
    expect(refreshCount, 3);
  });

  test('stop cancels the old user and resets generation ordering', () async {
    final FakeNotificationSyncRepository repository =
        FakeNotificationSyncRepository();
    final List<NotificationSyncConnectionStatus> statuses =
        <NotificationSyncConnectionStatus>[];
    var refreshCount = 0;
    final NotificationSyncSession session = NotificationSyncSession(
      repository,
      () async => refreshCount += 1,
      statuses.add,
    );
    addTearDown(() async {
      await session.dispose();
      await repository.dispose();
    });
    final AuthUserId first = _authUserId();
    final AuthUserId second = AuthUserId.tryParse(
      '00000000-0000-4000-8000-000000000102',
    )!;

    await session.start(first);
    repository.addAt(0, const NotificationSyncChanged(9));
    await _flush();
    expect(refreshCount, 1);

    await session.stop();
    expect(repository.hasListenerAt(0), isFalse);
    expect(statuses.last, NotificationSyncConnectionStatus.disabled);
    repository.addAt(0, const NotificationSyncChanged(10));
    await _flush();
    expect(refreshCount, 1);

    await session.start(second);
    repository.latest.add(const NotificationSyncChanged(1));
    await _flush();
    expect(refreshCount, 2);
    expect(repository.watchedUsers, <AuthUserId>[first, second]);
  });

  test('disabled session still performs a resume refetch', () async {
    var refreshCount = 0;
    final NotificationSyncSession session = NotificationSyncSession(
      null,
      () async => refreshCount += 1,
      (_) {},
    );
    addTearDown(session.dispose);

    await session.start(_authUserId());
    await session.resume();

    expect(refreshCount, 1);
  });
}

AuthUserId _authUserId() =>
    AuthUserId.tryParse('00000000-0000-4000-8000-000000000101')!;

Future<void> _flush() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
