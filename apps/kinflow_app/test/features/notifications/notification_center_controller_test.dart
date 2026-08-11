import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_controller.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

import '../../support/fakes/fake_notification_dependencies.dart';
import '../../support/fakes/fake_notification_sync_dependencies.dart';

NotificationSnoozeCommandId _snoozeId() => NotificationSnoozeCommandId.tryParse(
  '85000000-0000-4000-8000-000000000001',
)!;

void main() {
  test('load and read command update durable item and badge state', () async {
    final FakeNotificationRepository repository = FakeNotificationRepository();
    final NotificationCenterController controller =
        NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
    addTearDown(controller.dispose);
    final snapshot = repository.defaultSnapshot;

    await controller.load(snapshot.householdId);
    expect(controller.state, isA<NotificationCenterReady>());

    final NotificationInboxItem unread = snapshot.inbox.items.firstWhere(
      (item) => !item.isRead,
    );
    await controller.markRead(unread.id);

    final NotificationCenterReady ready =
        controller.state as NotificationCenterReady;
    expect(ready.snapshot.unreadCount, 0);
    expect(
      ready.snapshot.inbox.items
          .firstWhere((item) => item.id == unread.id)
          .isRead,
      isTrue,
    );
    expect(repository.readItemIds.single.single, unread.id);
  });

  test(
    'preference version conflict preserves content with safe failure',
    () async {
      final NotificationSnapshot snapshot = notificationSnapshotFixture();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        snapshot: snapshot,
        updateResults: const <NotificationResult<NotificationPreference>>[
          NotificationFailed<NotificationPreference>(
            NotificationFailure(NotificationFailureKind.versionConflict),
          ),
        ],
      );
      final NotificationCenterController controller =
          NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
      addTearDown(controller.dispose);
      await controller.load(snapshot.householdId);
      final NotificationPreference changed = snapshot.preferences.first.changed(
        inApp: false,
        quietHoursEnabled: snapshot.preferences.first.quietHoursEnabled,
      )!;

      await controller.updatePreference(changed);

      final NotificationCenterReady ready =
          controller.state as NotificationCenterReady;
      expect(ready.snapshot.preferences.first.inApp, isTrue);
      expect(
        ready.actionFailure?.kind,
        NotificationFailureKind.versionConflict,
      );
    },
  );

  test('Calendar reminder set replaces only the Calendar preference', () async {
    final NotificationSnapshot snapshot = notificationSnapshotFixture();
    final FakeNotificationRepository repository = FakeNotificationRepository(
      snapshot: snapshot,
    );
    final NotificationCenterController controller =
        NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
    addTearDown(controller.dispose);
    await controller.load(snapshot.householdId);
    final NotificationPreference calendar = snapshot.preference(
      NotificationCategory.calendarEvent,
    )!;

    await controller.updatePreference(
      calendar.changed(
        quietHoursEnabled: calendar.quietHoursEnabled,
        reminderLeadMinutes: 30,
        additionalReminderLeadMinutes: const <int>[5, 15],
      )!,
    );

    final NotificationCenterReady ready =
        controller.state as NotificationCenterReady;
    expect(repository.updatedPreferences.single.reminderLeadMinutes, 30);
    expect(
      repository.updatedPreferences.single.additionalReminderLeadMinutes,
      const <int>[5, 15],
    );
    expect(
      ready.snapshot
          .preference(NotificationCategory.calendarEvent)
          ?.reminderLeadMinutes,
      30,
    );
    expect(
      ready.snapshot
          .preference(NotificationCategory.calendarEvent)
          ?.additionalReminderLeadMinutes,
      const <int>[5, 15],
    );
    expect(
      ready.snapshot
          .preference(NotificationCategory.choreDue)
          ?.reminderLeadMinutes,
      0,
    );
  });

  test(
    'authorization failure clears previously loaded notification content',
    () async {
      final NotificationSnapshot snapshot = notificationSnapshotFixture();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        snapshot: snapshot,
        readAllResults: const <NotificationResult<NotificationReadReceipt>>[
          NotificationFailed<NotificationReadReceipt>(
            NotificationFailure(NotificationFailureKind.notFoundOrForbidden),
          ),
        ],
      );
      final NotificationCenterController controller =
          NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
      addTearDown(controller.dispose);
      await controller.load(snapshot.householdId);

      await controller.markAllRead();

      expect(controller.state, isA<NotificationCenterLoadFailed>());
    },
  );

  test(
    'Calendar snooze removes the item and applies the server badge',
    () async {
      final NotificationSnapshot base = notificationSnapshotFixture();
      final NotificationInboxItem item = notificationInboxItemFixture(
        id: notificationItemTwoUuid,
        category: NotificationCategory.calendarEvent,
        createdAt: DateTime.utc(2026, 8, 8, 2),
        readAt: null,
      );
      final FakeNotificationRepository repository = FakeNotificationRepository(
        snapshot: NotificationSnapshot(
          householdId: base.householdId,
          preferences: base.preferences,
          inbox: NotificationInboxPage(
            items: <NotificationInboxItem>[item],
            hasMore: false,
            nextCursor: null,
          ),
          unreadCount: 1,
        ),
      );
      final NotificationCenterController controller =
          NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
      addTearDown(controller.dispose);
      await controller.load(base.householdId);

      final bool succeeded = await controller.snoozeCalendar(item.id, 10);

      expect(succeeded, isTrue);
      final NotificationCenterReady ready =
          controller.state as NotificationCenterReady;
      expect(ready.snapshot.inbox.items, isEmpty);
      expect(ready.snapshot.unreadCount, 0);
      expect(repository.snoozeCalls.single.inboxItemId, item.id);
      expect(
        repository.snoozeCalls.single.expectedItemVersion,
        item.itemVersion,
      );
      expect(repository.snoozeCalls.single.snoozeMinutes, 10);
    },
  );

  test('transport retry reuses the same snooze command id', () async {
    final NotificationSnapshot base = notificationSnapshotFixture();
    final NotificationInboxItem item = notificationInboxItemFixture(
      id: notificationItemTwoUuid,
      category: NotificationCategory.calendarEvent,
      createdAt: DateTime.utc(2026, 8, 8, 2),
      readAt: null,
    );
    final FakeNotificationRepository repository = FakeNotificationRepository(
      snapshot: NotificationSnapshot(
        householdId: base.householdId,
        preferences: base.preferences,
        inbox: NotificationInboxPage(
          items: <NotificationInboxItem>[item],
          hasMore: false,
          nextCursor: null,
        ),
        unreadCount: 1,
      ),
      snoozeResults: const <NotificationResult<NotificationSnoozeReceipt>>[
        NotificationFailed<NotificationSnoozeReceipt>(
          NotificationFailure(NotificationFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    var generatedCount = 0;
    final NotificationCenterController controller =
        NotificationCenterController(
          repository,
          snoozeIdFactory: () {
            generatedCount += 1;
            return _snoozeId();
          },
        );
    addTearDown(controller.dispose);
    await controller.load(base.householdId);

    expect(await controller.snoozeCalendar(item.id, 10), isFalse);
    expect(await controller.snoozeCalendar(item.id, 10), isTrue);

    expect(generatedCount, 1);
    expect(repository.snoozeCalls, hasLength(2));
    expect(
      repository.snoozeCalls.first.commandId,
      repository.snoozeCalls.last.commandId,
    );
  });

  test('ensureLoaded owns one snapshot load for the same household', () async {
    final FakeNotificationRepository repository = FakeNotificationRepository();
    final NotificationCenterController controller =
        NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
    addTearDown(controller.dispose);

    await Future.wait<void>(<Future<void>>[
      controller.ensureLoaded(repository.defaultSnapshot.householdId),
      controller.ensureLoaded(repository.defaultSnapshot.householdId),
    ]);
    await controller.ensureLoaded(repository.defaultSnapshot.householdId);

    expect(repository.loadedHouseholds, hasLength(1));
    expect(controller.state, isA<NotificationCenterReady>());
  });

  test(
    'deactivate immediately purges content and rejects an in-flight refresh',
    () async {
      final NotificationSnapshot first = notificationSnapshotFixture();
      final NotificationSnapshot stale = notificationSnapshotFixture(
        unreadCount: 9,
      );
      final Completer<NotificationResult<NotificationSnapshot>> refresh =
          Completer<NotificationResult<NotificationSnapshot>>();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        loadFutures: <Future<NotificationResult<NotificationSnapshot>>>[
          Future<NotificationResult<NotificationSnapshot>>.value(
            NotificationSucceeded<NotificationSnapshot>(first),
          ),
          refresh.future,
        ],
      );
      final FakeNotificationSyncRepository syncRepository =
          FakeNotificationSyncRepository();
      final NotificationCenterController controller =
          NotificationCenterController(
            repository,
            authUserId: AuthUserId.tryParse(
              '00000000-0000-4000-8000-000000000101',
            ),
            syncRepository: syncRepository,
            snoozeIdFactory: _snoozeId,
          );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });
      await controller.load(first.householdId);
      expect(syncRepository.watchCount, 1);

      final Future<void> refreshing = controller.refresh();
      final Future<void> deactivating = controller.deactivate();

      expect(controller.state, isA<NotificationCenterInitial>());
      await Future<void>.delayed(Duration.zero);
      expect(syncRepository.hasListenerAt(0), isFalse);

      refresh.complete(NotificationSucceeded<NotificationSnapshot>(stale));
      await Future.wait<void>(<Future<void>>[refreshing, deactivating]);

      expect(controller.state, isA<NotificationCenterInitial>());
    },
  );

  test('deactivate rejects an in-flight mutation response', () async {
    final NotificationSnapshot snapshot = notificationSnapshotFixture();
    final Completer<NotificationResult<NotificationReadReceipt>> markAll =
        Completer<NotificationResult<NotificationReadReceipt>>();
    final FakeNotificationRepository repository = FakeNotificationRepository(
      snapshot: snapshot,
      readAllFutures: <Future<NotificationResult<NotificationReadReceipt>>>[
        markAll.future,
      ],
    );
    final NotificationCenterController controller =
        NotificationCenterController(repository, snoozeIdFactory: _snoozeId);
    addTearDown(controller.dispose);
    await controller.load(snapshot.householdId);

    final Future<void> mutation = controller.markAllRead();
    final Future<void> deactivating = controller.deactivate();
    expect(controller.state, isA<NotificationCenterInitial>());

    markAll.complete(
      NotificationSucceeded<NotificationReadReceipt>(
        NotificationReadReceipt(
          markedCount: snapshot.unreadCount,
          unreadCount: 0,
          markedAt: DateTime.utc(2026, 8, 10),
        ),
      ),
    );
    await Future.wait<void>(<Future<void>>[mutation, deactivating]);

    expect(controller.state, isA<NotificationCenterInitial>());
  });
}
