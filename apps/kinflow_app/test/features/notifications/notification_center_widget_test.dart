import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_center_lifecycle_host.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations_en.dart';
import 'package:kinflow_app/l10n/app_localizations_ko.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_notification_dependencies.dart';
import '../../support/fakes/fake_notification_sync_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  test('app-shell lifecycle context is scoped by both user and household', () {
    final ActiveHousehold household = activeHouseholdFixture();
    final active = notificationCenterLifecycleContextFor(
      AuthAuthenticatedActiveHousehold(authSessionFixture(), household),
    );
    final refreshing = notificationCenterLifecycleContextFor(
      AuthRefreshing(authSessionFixture(), activeHousehold: household),
    );
    final otherUser = notificationCenterLifecycleContextFor(
      AuthAuthenticatedActiveHousehold(
        authSessionFixture(userId: '11111111-1111-4111-8111-111111111112'),
        household,
      ),
    );

    expect(active, refreshing);
    expect(otherUser, isNot(active));
    expect(
      notificationCenterLifecycleContextFor(
        AuthAuthenticatedNoHousehold(authSessionFixture()),
      ),
      isNull,
    );
    expect(
      notificationCenterLifecycleContextFor(const AuthUnauthenticated()),
      isNull,
    );
  });

  test('unread badge semantics are localized for EN KO and EN-XA', () {
    expect(
      AppLocalizationsEn().notificationBadgeSemantics(120),
      '120 unread notifications',
    );
    expect(
      AppLocalizationsKo().notificationBadgeSemantics(120),
      '읽지 않은 알림 120개',
    );
    expect(
      AppLocalizationsEnXa().notificationBadgeSemantics(120),
      '[!! 120 complete unread household notifications !!]',
    );
  });

  testWidgets(
    'durable inbox shows badge and opening an unread item marks it read',
    (WidgetTester tester) async {
      final FakeNotificationRepository repository =
          FakeNotificationRepository();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        repository,
      );

      harness.router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification.screen')), findsOneWidget);
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.text('Chore assignment update'), findsWidgets);
      expect(find.text('Chore due update'), findsWidgets);
      expect(find.text('Calendar event reminder'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('notification.item.$notificationItemTwoUuid')),
      );
      await tester.pumpAndSettle();

      expect(repository.readItemIds, hasLength(1));
      expect(
        repository.readItemIds.single.single.value,
        notificationItemTwoUuid,
      );
      expect(
        harness.router.state.uri.path,
        AppRoutes.choreOccurrenceLocation(
          ChoreOccurrenceId.tryParse('83000000-0000-4000-8000-000000000002')!,
        ),
      );
    },
  );

  testWidgets('Calendar inbox item opens its exact occurrence route', (
    WidgetTester tester,
  ) async {
    final NotificationSnapshot base = notificationSnapshotFixture(
      unreadCount: 0,
    );
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
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      repository,
    );

    harness.router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('notification.item.$notificationItemTwoUuid')),
    );
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.path,
      AppRoutes.calendarEventLocation(
        CalendarEventOccurrenceId.tryParse(item.subjectId)!,
      ),
    );
    expect(repository.readItemIds.single.single, item.id);
  });

  testWidgets('Calendar reminder offers fixed snooze and confirms reschedule', (
    WidgetTester tester,
  ) async {
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
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      repository,
    );

    harness.router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('notification.snooze.${item.id.value}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification.snooze.sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('notification.snooze.option.5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification.snooze.option.10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification.snooze.option.30')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('notification.snooze.option.10')));
    await tester.pumpAndSettle();

    expect(repository.snoozeCalls.single.snoozeMinutes, 10);
    expect(
      find.byKey(const Key('notification.snooze.succeeded')),
      findsOneWidget,
    );
    expect(find.byKey(Key('notification.item.${item.id.value}')), findsNothing);
    expect(find.text('0 unread'), findsOneWidget);
  });

  testWidgets('snooze choices remain reachable at 200 percent text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
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
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      repository,
    );
    harness.router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();
    final Finder snooze = find.byKey(
      Key('notification.snooze.${item.id.value}'),
    );
    await tester.drag(
      find.byKey(const Key('notification.list')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(snooze);
    await tester.pumpAndSettle();
    await tester.tap(snooze);
    await tester.pumpAndSettle();

    final Finder thirtyMinutes = find.byKey(
      const Key('notification.snooze.option.30'),
    );
    final Finder sheetScrollable = find
        .descendant(
          of: find.byKey(const Key('notification.snooze.sheet')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      thirtyMinutes,
      160,
      scrollable: sheetScrollable,
    );
    await tester.drag(sheetScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(thirtyMinutes);
    await tester.pumpAndSettle();

    expect(repository.snoozeCalls.single.snoozeMinutes, 30);
    expect(
      find.byKey(const Key('notification.snooze.succeeded')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category settings search timezone save and cancel drafts', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository();
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      repository,
    );
    harness.router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();

    final Finder assignmentEdit = find.byKey(
      const Key('notification.preference.chore_assignment.edit'),
    );
    await tester.drag(
      find.byKey(const Key('notification.list')),
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(assignmentEdit);
    await tester.pump();
    await tester.tap(assignmentEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification.editor.inApp')));
    await tester.tap(find.byKey(const Key('notification.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.updatedPreferences, hasLength(1));
    expect(repository.updatedPreferences.single.inApp, isFalse);
    expect(repository.updatedPreferences.single.email, isFalse);
    expect(repository.updatedPreferences.single.nativePush, isTrue);

    final Finder edit = find.byKey(
      const Key('notification.preference.chore_due.edit'),
    );
    await tester.ensureVisible(edit);
    await tester.pump();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('notification.preferenceEditor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification.editor.reminderLead')),
      findsNothing,
    );

    final Finder timezone = find.byKey(
      const Key('notification.editor.timezone'),
    );
    final EditableText editable = tester.widget<EditableText>(
      find.descendant(of: timezone, matching: find.byType(EditableText)),
    );
    expect(editable.readOnly, isTrue);
    await _selectTimezone(
      tester,
      field: timezone,
      query: 'new york',
      identifier: 'America/New_York',
    );
    await tester.tap(find.byKey(const Key('notification.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.updatedPreferences, hasLength(2));
    expect(repository.updatedPreferences.last.timezone, 'America/New_York');
    expect(repository.updatedPreferences.last.quietStart, '22:00');
    expect(repository.updatedPreferences.last.quietEnd, '07:00');

    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await _selectTimezone(
      tester,
      field: find.byKey(const Key('notification.editor.timezone')),
      query: 'london',
      identifier: 'Europe/London',
    );
    await tester.tap(find.byKey(const Key('notification.editor.cancel')));
    await tester.pumpAndSettle();

    expect(repository.updatedPreferences, hasLength(2));
  });

  testWidgets('preference editor preserves every setting not changed', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = FakeNotificationRepository();
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      repository,
    );
    harness.router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();

    final Finder edit = find.byKey(
      const Key('notification.preference.chore_due.edit'),
    );
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final Finder editorEmail = find.byKey(
      const Key('notification.editor.email'),
    );
    await tester.ensureVisible(editorEmail);
    await tester.tap(editorEmail);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.updatedPreferences, hasLength(1));
    final NotificationPreference edited = repository.updatedPreferences.single;
    expect(edited.email, isTrue);
    expect(edited.inApp, isTrue);
    expect(edited.nativePush, isTrue);
    expect(edited.webPush, isFalse);
    expect(edited.quietStart, '22:00');
    expect(edited.quietEnd, '07:00');
    expect(edited.timezone, 'Asia/Seoul');
    expect(edited.reminderLeadMinuteSet, const <int>[0]);
  });

  testWidgets(
    'Calendar settings select one primary and two additional reminders',
    (WidgetTester tester) async {
      final FakeNotificationRepository repository =
          FakeNotificationRepository();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        repository,
      );
      harness.router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();

      final Finder edit = find.byKey(
        const Key('notification.preference.calendar_event.edit'),
      );
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      expect(find.textContaining('Remind me: At event time'), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();

      final Finder selector = find.byKey(
        const Key('notification.editor.reminderLead'),
      );
      expect(selector, findsOneWidget);
      expect(
        find.textContaining(
          'Changes apply only to Calendar reminders that have not been '
          'delivered yet.',
        ),
        findsOneWidget,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 minutes before').last);
      await tester.pumpAndSettle();
      final Finder thirty = find.byKey(
        const Key('notification.editor.additionalReminder.30'),
      );
      final Finder sixty = find.byKey(
        const Key('notification.editor.additionalReminder.60'),
      );
      await tester.ensureVisible(thirty);
      await tester.tap(thirty);
      await tester.pumpAndSettle();
      await tester.ensureVisible(sixty);
      await tester.tap(sixty);
      await tester.pumpAndSettle();

      final CheckboxListTile disabledThird = tester.widget<CheckboxListTile>(
        find.byKey(const Key('notification.editor.additionalReminder.10')),
      );
      expect(disabledThird.onChanged, isNull);
      await tester.tap(find.byKey(const Key('notification.editor.save')));
      await tester.pumpAndSettle();

      expect(repository.updatedPreferences, hasLength(1));
      expect(repository.updatedPreferences.single.reminderLeadMinutes, 15);
      expect(
        repository.updatedPreferences.single.additionalReminderLeadMinutes,
        const <int>[30, 60],
      );
      expect(
        find.textContaining(
          'Remind me: 15 minutes before, 30 minutes before, '
          '60 minutes before',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'multiple reminder controls remain reachable at 200 percent text scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final FakeNotificationRepository repository =
          FakeNotificationRepository();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        repository,
      );
      harness.router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();

      final Finder edit = find.byKey(
        const Key('notification.preference.calendar_event.edit'),
      );
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();

      final Finder editor = find.byKey(
        const Key('notification.preferenceEditor'),
      );
      final Finder editorScroll = find
          .descendant(of: editor, matching: find.byType(Scrollable))
          .first;
      final Finder email = find.byKey(const Key('notification.editor.email'));
      await tester.scrollUntilVisible(email, 160, scrollable: editorScroll);
      await tester.drag(editorScroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(email);
      await tester.pumpAndSettle();
      for (final int minutes in <int>[30, 60]) {
        final Finder option = find.byKey(
          Key('notification.editor.additionalReminder.$minutes'),
        );
        await tester.scrollUntilVisible(option, 160, scrollable: editorScroll);
        await tester.tap(option);
        await tester.pumpAndSettle();
      }

      final Finder save = find.byKey(const Key('notification.editor.save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        repository.updatedPreferences.single.additionalReminderLeadMinutes,
        const <int>[30, 60],
      );
      expect(repository.updatedPreferences.single.email, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'push permission prompt occurs only after the explanatory action',
    (WidgetTester tester) async {
      final _FakePushCoordinator pushCoordinator = _FakePushCoordinator();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        FakeNotificationRepository(),
        pushCoordinator: pushCoordinator,
      );
      harness.router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();

      expect(pushCoordinator.requestCount, 0);
      final Finder enable = find.byKey(const Key('notification.pushEnable'));
      await tester.ensureVisible(enable);
      await tester.pump();
      expect(find.textContaining('calendar details stay out'), findsOneWidget);

      await tester.tap(enable);
      await tester.pumpAndSettle();
      expect(pushCoordinator.requestCount, 1);

      final Finder settings = find.byKey(
        const Key('notification.pushSettings'),
      );
      expect(settings, findsOneWidget);
      await tester.tap(settings);
      await tester.pump();
      expect(pushCoordinator.openSettingsCount, 1);
    },
  );

  testWidgets(
    'disconnected inbox retains badge and reconnects at 200 percent text scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final FakeNotificationSyncRepository syncRepository =
          FakeNotificationSyncRepository();
      final FakeNotificationRepository notificationRepository =
          FakeNotificationRepository();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        notificationRepository,
        syncRepository: syncRepository,
      );
      harness.router.go(AppRoutes.notifications);
      await tester.pumpAndSettle();
      expect(syncRepository.watchCount, 1);
      final int initialLoadCount =
          notificationRepository.loadedHouseholds.length;

      syncRepository.latest.add(const NotificationSyncDisconnected());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notification.live.disconnected')),
        findsOneWidget,
      );
      expect(find.text('1 unread'), findsOneWidget);
      final Finder reconnect = find.byKey(
        const Key('notification.live.reconnect'),
      );
      expect(reconnect, findsOneWidget);
      await tester.ensureVisible(reconnect);
      await tester.pumpAndSettle();
      final VoidCallback? reconnectAction = tester
          .widget<OutlinedButton>(reconnect)
          .onPressed;
      expect(reconnectAction, isNotNull);
      await tester.runAsync(
        () => harness.container
            .read(notificationCenterProvider.notifier)
            .reconnect(),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(syncRepository.watchCount, 2);
      expect(
        notificationRepository.loadedHouseholds,
        hasLength(initialLoadCount + 1),
      );
    },
  );

  testWidgets(
    'app shell keeps one live inbox and shares its badge across primary routes',
    (WidgetTester tester) async {
      final FakeNotificationSyncRepository syncRepository =
          FakeNotificationSyncRepository();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        snapshot: notificationSnapshotFixture(unreadCount: 7),
      );
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        repository,
        syncRepository: syncRepository,
      );

      final List<(String, Key)> destinations = <(String, Key)>[
        (AppRoutes.today, const Key('today.notifications')),
        (AppRoutes.chores, const Key('today.notifications')),
        (AppRoutes.calendar, const Key('calendar.notifications')),
        (AppRoutes.family, const Key('members.notifications')),
        (AppRoutes.settings, const Key('settings.notifications')),
      ];
      for (final (String location, Key badgeKey) in destinations) {
        harness.router.go(location);
        await tester.pumpAndSettle();

        final Finder badge = find.byKey(badgeKey);
        expect(badge, findsOneWidget);
        expect(
          find.descendant(of: badge, matching: find.text('7')),
          findsOneWidget,
        );
        expect(syncRepository.watchCount, 1);
      }
      expect(repository.loadedHouseholds, hasLength(1));

      repository.defaultSnapshot = notificationSnapshotFixture(unreadCount: 8);
      syncRepository.latest.add(const NotificationSyncChanged(1));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('settings.notifications')),
          matching: find.text('8'),
        ),
        findsOneWidget,
      );
      expect(repository.loadedHouseholds, hasLength(2));
      expect(syncRepository.watchCount, 1);

      syncRepository.latest.add(const NotificationSyncDisconnected());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('settings.notifications')),
          matching: find.text('8'),
        ),
        findsOneWidget,
      );
      expect(repository.loadedHouseholds, hasLength(2));

      repository.defaultSnapshot = notificationSnapshotFixture(unreadCount: 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await _flushWidgetAsync(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('settings.notifications')),
          matching: find.text('9'),
        ),
        findsOneWidget,
      );
      expect(repository.loadedHouseholds, hasLength(3));
      expect(syncRepository.watchCount, 2);
      expect(syncRepository.hasListenerAt(0), isFalse);
      expect(syncRepository.hasListenerAt(1), isTrue);

      await tester.tap(find.byKey(const Key('settings.notifications')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, AppRoutes.notifications);
      expect(repository.loadedHouseholds, hasLength(3));
      expect(syncRepository.watchCount, 2);

      final Finder back = find.byKey(const Key('layout.back'));
      expect(back, findsOneWidget);
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, AppRoutes.settings);
      expect(find.byKey(const Key('settings.screen')), findsOneWidget);
    },
  );

  testWidgets(
    'household transition purges the old badge before loading the new inbox',
    (WidgetTester tester) async {
      final NotificationSnapshot first = notificationSnapshotFixture(
        unreadCount: 7,
      );
      final ActiveHousehold secondHousehold = activeHouseholdFixture(
        householdId: '22222222-2222-4222-8222-222222222223',
        memberId: '33333333-3333-4333-8333-333333333334',
      );
      final NotificationSnapshot second = _notificationSnapshotForHousehold(
        first,
        secondHousehold.householdId,
      );
      final Completer<NotificationResult<NotificationSnapshot>> secondLoad =
          Completer<NotificationResult<NotificationSnapshot>>();
      final FakeNotificationRepository repository = FakeNotificationRepository(
        loadFutures: <Future<NotificationResult<NotificationSnapshot>>>[
          Future<NotificationResult<NotificationSnapshot>>.value(
            NotificationSucceeded<NotificationSnapshot>(first),
          ),
          secondLoad.future,
        ],
      );
      final FakeNotificationSyncRepository syncRepository =
          FakeNotificationSyncRepository();
      final _NotificationHarness harness = await _pumpNotificationApp(
        tester,
        repository,
        syncRepository: syncRepository,
      );

      await tester.runAsync(
        () => harness.container
            .read(authLifecycleProvider.notifier)
            .markActiveHousehold(secondHousehold),
      );
      await tester.pump();
      await tester.pump();
      await _flushWidgetAsync(tester);

      expect(
        harness.container.read(notificationCenterProvider),
        isNot(isA<NotificationCenterReady>()),
      );
      expect(find.text('7'), findsNothing);
      expect(syncRepository.hasListenerAt(0), isFalse);

      secondLoad.complete(NotificationSucceeded<NotificationSnapshot>(second));
      await tester.pumpAndSettle();
      await _flushWidgetAsync(tester);

      final NotificationCenterReady ready =
          harness.container.read(notificationCenterProvider)
              as NotificationCenterReady;
      expect(ready.snapshot.householdId, secondHousehold.householdId);
      expect(ready.snapshot.unreadCount, 0);
      expect(syncRepository.watchCount, 2);
      expect(syncRepository.hasListenerAt(1), isTrue);
      final Badge badge = tester.widget<Badge>(
        find.descendant(
          of: find.byKey(const Key('today.notifications')),
          matching: find.byType(Badge),
        ),
      );
      expect(badge.isLabelVisible, isFalse);
    },
  );

  testWidgets('logout purges the app-shell inbox and cancels its channel', (
    WidgetTester tester,
  ) async {
    final FakeNotificationSyncRepository syncRepository =
        FakeNotificationSyncRepository();
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      FakeNotificationRepository(),
      syncRepository: syncRepository,
    );
    expect(
      harness.container.read(notificationCenterProvider),
      isA<NotificationCenterReady>(),
    );

    await tester.runAsync(
      () => harness.container.read(authLifecycleProvider.notifier).logout(),
    );
    await tester.pumpAndSettle();

    expect(
      harness.container.read(notificationCenterProvider),
      isA<NotificationCenterInitial>(),
    );
    expect(syncRepository.hasListenerAt(0), isFalse);
    expect(harness.router.state.uri.path, AppRoutes.signIn);
  });

  testWidgets('app-shell badge remains reachable at 200 percent text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      FakeNotificationRepository(
        snapshot: notificationSnapshotFixture(unreadCount: 120),
      ),
    );
    harness.router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    final Finder badge = find.byKey(const Key('settings.notifications'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('99+')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('120 unread notifications')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('push navigation host opens exact Chore and Calendar routes', (
    WidgetTester tester,
  ) async {
    final _FakePushCoordinator pushCoordinator = _FakePushCoordinator();
    final _NotificationHarness harness = await _pumpNotificationApp(
      tester,
      FakeNotificationRepository(),
      pushCoordinator: pushCoordinator,
    );
    const String choreSubject = '83000000-0000-4000-8000-000000000001';
    const String calendarSubject = '83000000-0000-4000-8000-000000000003';

    pushCoordinator.emitNavigation(
      const NotificationPushNavigationIntent(
        destination: NotificationPushNavigationDestination.choreOccurrence,
        deliveryId: '84000000-0000-4000-8000-000000000001',
        subjectId: choreSubject,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.router.state.uri.path,
      AppRoutes.choreOccurrenceLocation(
        ChoreOccurrenceId.tryParse(choreSubject)!,
      ),
    );

    pushCoordinator.emitNavigation(
      const NotificationPushNavigationIntent(
        destination: NotificationPushNavigationDestination.calendarEvent,
        deliveryId: '84000000-0000-4000-8000-000000000003',
        subjectId: calendarSubject,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.router.state.uri.path,
      AppRoutes.calendarEventLocation(
        CalendarEventOccurrenceId.tryParse(calendarSubject)!,
      ),
    );
  });
}

NotificationSnapshot _notificationSnapshotForHousehold(
  NotificationSnapshot source,
  HouseholdId householdId,
) {
  return NotificationSnapshot(
    householdId: householdId,
    preferences: source.preferences
        .map(
          (NotificationPreference preference) =>
              NotificationPreference.tryCreate(
                householdId: householdId,
                category: preference.category,
                nativePush: preference.nativePush,
                webPush: preference.webPush,
                email: preference.email,
                inApp: preference.inApp,
                quietStart: preference.quietStart,
                quietEnd: preference.quietEnd,
                timezone: preference.timezone,
                reminderLeadMinutes: preference.reminderLeadMinutes,
                additionalReminderLeadMinutes:
                    preference.additionalReminderLeadMinutes,
                updatedAt: preference.updatedAt,
                version: preference.version,
                isDefault: preference.isDefault,
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
}

Future<void> _flushWidgetAsync(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  });
  await tester.pump();
}

final class _NotificationHarness {
  const _NotificationHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
}

Future<_NotificationHarness> _pumpNotificationApp(
  WidgetTester tester,
  FakeNotificationRepository notificationRepository, {
  NotificationPushCoordinatorService pushCoordinator =
      const UnavailableNotificationPushCoordinator(),
  FakeNotificationSyncRepository? syncRepository,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
    refreshCallback: () async => AuthSessionAvailable(authSessionFixture()),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appRuntimePolicyRepositoryProvider.overrideWithValue(
        const FakeAllowedAppRuntimePolicyRepository(),
      ),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(createAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        createSensitiveLocalStatePurger(),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        createActiveHouseholdSnapshotWriter(),
      ),
      householdRepositoryProvider.overrideWithValue(
        FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
      ),
      householdMemberRepositoryProvider.overrideWithValue(
        FakeHouseholdMemberRepository(),
      ),
      householdCommandIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCommandIdGenerator(),
      ),
      recentAuthenticationServiceProvider.overrideWithValue(
        FakeRecentAuthenticationService(),
      ),
      choreRepositoryProvider.overrideWithValue(FakeChoreRepository()),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
      calendarRepositoryProvider.overrideWithValue(FakeCalendarRepository()),
      calendarCommandIdGeneratorProvider.overrideWithValue(
        FakeCalendarCommandIdGenerator(),
      ),
      calendarTimeResolverProvider.overrideWithValue(
        TimezoneCalendarTimeResolver(),
      ),
      notificationRepositoryProvider.overrideWithValue(notificationRepository),
      if (syncRepository != null)
        notificationSyncRepositoryProvider.overrideWithValue(syncRepository),
      notificationPushCoordinatorProvider.overrideWithValue(pushCoordinator),
    ],
  );
  addTearDown(authRepository.close);
  if (syncRepository != null) {
    addTearDown(syncRepository.dispose);
  }
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
  return _NotificationHarness(
    container: container,
    router: container.read(appRouterProvider),
  );
}

Future<void> _successfulInitialization() async {}

Future<void> _selectTimezone(
  WidgetTester tester, {
  required Finder field,
  required String query,
  required String identifier,
}) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('timezonePicker.sheet')), findsOneWidget);
  await tester.enterText(find.byKey(const Key('timezonePicker.search')), query);
  await tester.pumpAndSettle();
  final Finder result = find.byKey(Key('timezonePicker.result.$identifier'));
  await tester.ensureVisible(result);
  await tester.tap(result);
  await tester.pumpAndSettle();
}

final class _FakePushCoordinator implements NotificationPushCoordinatorService {
  final StreamController<NotificationPushState> _states =
      StreamController<NotificationPushState>.broadcast(sync: true);
  final StreamController<NotificationPushNavigationIntent> _navigation =
      StreamController<NotificationPushNavigationIntent>.broadcast(sync: true);
  NotificationPushState _state = const NotificationPushState(
    permission: NotificationPushPermission.denied,
    busy: false,
    permissionRequestAttempted: false,
    endpointRegistered: false,
    failure: null,
  );
  var requestCount = 0;
  var openSettingsCount = 0;

  void emitNavigation(NotificationPushNavigationIntent intent) {
    _navigation.add(intent);
  }

  @override
  NotificationPushState get state => _state;

  @override
  Stream<NotificationPushState> get states => _states.stream;

  @override
  Stream<NotificationPushNavigationIntent> get navigationIntents =>
      _navigation.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> synchronize({
    required ActiveHousehold? activeHousehold,
    required String? locale,
  }) async {}

  @override
  void updatePresentationContent(NotificationPushPresentationContent content) {}

  @override
  Future<void> requestPermission() async {
    requestCount += 1;
    _state = const NotificationPushState(
      permission: NotificationPushPermission.denied,
      busy: false,
      permissionRequestAttempted: true,
      endpointRegistered: false,
      failure: null,
    );
    _states.add(_state);
  }

  @override
  Future<void> refreshPermission() async {}

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCount += 1;
    return true;
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _navigation.close();
  }
}
