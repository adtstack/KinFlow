import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_controller.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

import '../../support/fakes/fake_notification_dependencies.dart';
import '../../support/fakes/fake_notification_sync_dependencies.dart';

void main() {
  test(
    'connected and newer generations replace the first inbox page',
    () async {
      final NotificationSnapshot first = notificationSnapshotFixture();
      final NotificationSnapshot second = notificationSnapshotFixture(
        unreadCount: 2,
      );
      final NotificationSnapshot third = notificationSnapshotFixture(
        unreadCount: 3,
      );
      final FakeNotificationRepository repository = FakeNotificationRepository(
        loadResults: <NotificationResult<NotificationSnapshot>>[
          NotificationSucceeded<NotificationSnapshot>(first),
          NotificationSucceeded<NotificationSnapshot>(second),
          NotificationSucceeded<NotificationSnapshot>(third),
        ],
      );
      final FakeNotificationSyncRepository syncRepository =
          FakeNotificationSyncRepository();
      final NotificationCenterController controller =
          NotificationCenterController(
            repository,
            authUserId: _authUserId(),
            syncRepository: syncRepository,
            snoozeIdFactory: _snoozeId,
          );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });

      await controller.load(first.householdId);
      expect(syncRepository.watchCount, 1);
      expect(
        (controller.state as NotificationCenterReady).syncStatus,
        NotificationSyncConnectionStatus.connecting,
      );

      syncRepository.latest.add(const NotificationSyncConnected());
      await _flush();
      expect(repository.loadedHouseholds, hasLength(2));
      expect(
        (controller.state as NotificationCenterReady).snapshot.unreadCount,
        2,
      );

      syncRepository.latest
        ..add(const NotificationSyncChanged(5))
        ..add(const NotificationSyncChanged(5))
        ..add(const NotificationSyncChanged(4));
      await _flush();
      expect(repository.loadedHouseholds, hasLength(3));
      expect(
        (controller.state as NotificationCenterReady).snapshot.unreadCount,
        3,
      );
    },
  );

  test('disconnect and transport failure retain the last snapshot', () async {
    final NotificationSnapshot snapshot = notificationSnapshotFixture();
    final FakeNotificationRepository repository = FakeNotificationRepository(
      loadResults: <NotificationResult<NotificationSnapshot>>[
        NotificationSucceeded<NotificationSnapshot>(snapshot),
        const NotificationFailed<NotificationSnapshot>(
          NotificationFailure(NotificationFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeNotificationSyncRepository syncRepository =
        FakeNotificationSyncRepository();
    final NotificationCenterController controller =
        NotificationCenterController(
          repository,
          authUserId: _authUserId(),
          syncRepository: syncRepository,
          snoozeIdFactory: _snoozeId,
        );
    addTearDown(() async {
      await controller.dispose();
      await syncRepository.dispose();
    });

    await controller.load(snapshot.householdId);
    syncRepository.latest.add(const NotificationSyncConnected());
    await _flush();

    final NotificationCenterReady retained =
        controller.state as NotificationCenterReady;
    expect(retained.snapshot, same(snapshot));
    expect(
      retained.actionFailure?.kind,
      NotificationFailureKind.temporarilyUnavailable,
    );
    syncRepository.latest.add(const NotificationSyncDisconnected());
    final NotificationCenterReady disconnected =
        controller.state as NotificationCenterReady;
    expect(
      disconnected.syncStatus,
      NotificationSyncConnectionStatus.disconnected,
    );
    expect(disconnected.snapshot, same(snapshot));
  });

  test('authorization failure purges content and stops the channel', () async {
    final NotificationSnapshot snapshot = notificationSnapshotFixture();
    final FakeNotificationRepository repository = FakeNotificationRepository(
      loadResults: <NotificationResult<NotificationSnapshot>>[
        NotificationSucceeded<NotificationSnapshot>(snapshot),
        const NotificationFailed<NotificationSnapshot>(
          NotificationFailure(NotificationFailureKind.notFoundOrForbidden),
        ),
      ],
    );
    final FakeNotificationSyncRepository syncRepository =
        FakeNotificationSyncRepository();
    final NotificationCenterController controller =
        NotificationCenterController(
          repository,
          authUserId: _authUserId(),
          syncRepository: syncRepository,
          snoozeIdFactory: _snoozeId,
        );
    addTearDown(() async {
      await controller.dispose();
      await syncRepository.dispose();
    });

    await controller.load(snapshot.householdId);
    syncRepository.latest.add(const NotificationSyncChanged(1));
    await _flush();

    final NotificationCenterLoadFailed failed =
        controller.state as NotificationCenterLoadFailed;
    expect(failed.failure.kind, NotificationFailureKind.notFoundOrForbidden);
    expect(syncRepository.hasListenerAt(0), isFalse);
  });

  test('manual reconnect replaces the channel and refetches', () async {
    final NotificationSnapshot first = notificationSnapshotFixture();
    final NotificationSnapshot second = notificationSnapshotFixture(
      unreadCount: 2,
    );
    final FakeNotificationRepository repository = FakeNotificationRepository(
      loadResults: <NotificationResult<NotificationSnapshot>>[
        NotificationSucceeded<NotificationSnapshot>(first),
        NotificationSucceeded<NotificationSnapshot>(second),
      ],
    );
    final FakeNotificationSyncRepository syncRepository =
        FakeNotificationSyncRepository();
    final NotificationCenterController controller =
        NotificationCenterController(
          repository,
          authUserId: _authUserId(),
          syncRepository: syncRepository,
          snoozeIdFactory: _snoozeId,
        );
    addTearDown(() async {
      await controller.dispose();
      await syncRepository.dispose();
    });

    await controller.load(first.householdId);
    syncRepository.latest.add(const NotificationSyncDisconnected());
    await controller.reconnect();

    expect(syncRepository.watchCount, 2);
    expect(repository.loadedHouseholds, hasLength(2));
    expect(
      (controller.state as NotificationCenterReady).snapshot.unreadCount,
      2,
    );
  });

  test('household switch removes the old channel before new content', () async {
    final NotificationSnapshot first = notificationSnapshotFixture();
    final HouseholdId secondHousehold = HouseholdId.tryParse(
      '22222222-2222-4222-8222-222222222223',
    )!;
    final NotificationSnapshot second = NotificationSnapshot(
      householdId: secondHousehold,
      preferences: first.preferences
          .map(
            (item) => NotificationPreference.tryCreate(
              householdId: secondHousehold,
              category: item.category,
              nativePush: item.nativePush,
              webPush: item.webPush,
              email: item.email,
              inApp: item.inApp,
              quietStart: item.quietStart,
              quietEnd: item.quietEnd,
              timezone: item.timezone,
              reminderLeadMinutes: item.reminderLeadMinutes,
              additionalReminderLeadMinutes: item.additionalReminderLeadMinutes,
              updatedAt: item.updatedAt,
              version: item.version,
              isDefault: item.isDefault,
            )!,
          )
          .toList(growable: false),
      inbox: NotificationInboxPage(
        items: <NotificationInboxItem>[],
        hasMore: false,
        nextCursor: null,
      ),
      unreadCount: 0,
    );
    final FakeNotificationRepository repository = FakeNotificationRepository(
      loadResults: <NotificationResult<NotificationSnapshot>>[
        NotificationSucceeded<NotificationSnapshot>(first),
        NotificationSucceeded<NotificationSnapshot>(second),
      ],
    );
    final FakeNotificationSyncRepository syncRepository =
        FakeNotificationSyncRepository();
    final NotificationCenterController controller =
        NotificationCenterController(
          repository,
          authUserId: _authUserId(),
          syncRepository: syncRepository,
          snoozeIdFactory: _snoozeId,
        );
    addTearDown(() async {
      await controller.dispose();
      await syncRepository.dispose();
    });

    await controller.load(first.householdId);
    final Future<void> switching = controller.load(secondHousehold);
    expect(controller.state, isA<NotificationCenterLoading>());
    await switching;

    expect(syncRepository.hasListenerAt(0), isFalse);
    expect(syncRepository.watchCount, 2);
    expect(
      (controller.state as NotificationCenterReady).snapshot.householdId,
      secondHousehold,
    );
    syncRepository.addAt(0, const NotificationSyncChanged(100));
    await _flush();
    expect(repository.loadedHouseholds, hasLength(2));
  });
}

AuthUserId _authUserId() =>
    AuthUserId.tryParse('00000000-0000-4000-8000-000000000101')!;

NotificationSnoozeCommandId _snoozeId() => NotificationSnoozeCommandId.tryParse(
  '85000000-0000-4000-8000-000000000001',
)!;

Future<void> _flush() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
