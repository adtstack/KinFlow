import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';
import 'package:kinflow_app/features/today/presentation/providers/today_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets('renders now and next before Chores on one server-local Today', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence chore = _chore(title: 'Take out recycling');
    final OneTimeCalendarEvent event = _event(title: 'Family dinner');

    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[chore],
        ),
      ),
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[event]),
    );

    expect(find.byKey(const Key('today.list')), findsOneWidget);
    expect(
      find.byKey(const Key('today.calendar.nowAndNext.ready')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('today.event.${event.occurrenceId.value}')),
      findsOneWidget,
    );
    expect(find.byKey(Key('today.chore.${chore.id.value}')), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(const Key('today.calendar.nowAndNext.heading')),
          )
          .dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('today.chores.heading'))).dy,
      ),
    );

    final Finder complete = find.byKey(
      Key('today.chore.toggle.${chore.id.value}'),
    );
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('today.event.${event.occurrenceId.value}')),
      findsOneWidget,
    );
    expect(find.byKey(Key('today.chore.${chore.id.value}')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('today.completed.toggle')));
    await tester.tap(find.byKey(const Key('today.completed.toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('today.chore.${chore.id.value}')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('today.chore.${chore.id.value}')),
        matching: find.text('Completed'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('completed section performs its exposed semantics tap action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final ChoreOccurrence completed = _chore(
      title: 'Finished laundry',
      status: ChoreOccurrenceStatus.completed,
    );
    try {
      await _pumpToday(
        tester,
        choreRepository: FakeChoreRepository(
          today: todayChoresFixture(
            localDate: '2026-08-07',
            occurrences: <ChoreOccurrence>[completed],
          ),
        ),
        calendarRepository: _calendarWith(const <OneTimeCalendarEvent>[]),
      );

      final toggle = find.semantics.byLabel('Completed today');
      expect(toggle, findsOne);
      expect(
        toggle.evaluate().single,
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('today.chore.${completed.id.value}')),
        findsOneWidget,
      );
      expect(
        toggle.evaluate().single,
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('today.chore.${completed.id.value}')),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('opens a Today event through its occurrence deep link', (
    WidgetTester tester,
  ) async {
    final OneTimeCalendarEvent event = _event(title: 'Open this event');
    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(localDate: '2026-08-07'),
      ),
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[event]),
    );

    await tester.tap(
      find.byKey(Key('today.event.${event.occurrenceId.value}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.screen')), findsOneWidget);
    expect(find.byKey(const Key('calendar.list')), findsOneWidget);
    expect(find.text('Open this event'), findsOneWidget);
  });

  testWidgets('keeps Chores visible when Calendar fails and recovers alone', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence chore = _chore(title: 'Water plants');
    final OneTimeCalendarEvent recovered = _event(title: 'Recovered event');
    final CalendarEventPage recoveredPage = calendarEventPageFixture(
      events: <OneTimeCalendarEvent>[recovered],
      localDate: '2026-08-07',
      rangeStartDate: '2026-08-07',
      limit: 100,
    );
    final FakeCalendarRepository calendar = FakeCalendarRepository(
      eventList: calendarEventListFixture(localDate: '2026-08-07'),
      pageResults: <LoadCalendarEventPageResult>[
        const LoadCalendarEventPageFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
        CalendarEventPageLoaded(recoveredPage),
      ],
    );

    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[chore],
        ),
      ),
      calendarRepository: calendar,
    );

    expect(find.byKey(Key('today.chore.${chore.id.value}')), findsOneWidget);
    expect(find.byKey(const Key('today.calendar.error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today.calendar.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Recovered event'), findsOneWidget);
    expect(calendar.pageRequests, hasLength(2));
  });

  testWidgets('keeps Calendar visible when Chores fails and retries Chores', (
    WidgetTester tester,
  ) async {
    final OneTimeCalendarEvent event = _event(title: 'School pickup');
    final ChoreOccurrence recovered = _chore(title: 'Recovered chore');
    final FakeChoreRepository chores = FakeChoreRepository(
      today: todayChoresFixture(
        localDate: '2026-08-07',
        occurrences: <ChoreOccurrence>[recovered],
      ),
      loadResults: <LoadTodayChoresResult>[
        const LoadTodayChoresFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );

    await _pumpToday(
      tester,
      choreRepository: chores,
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[event]),
    );

    expect(find.byKey(const Key('today.partial.calendarOnly')), findsOneWidget);
    expect(find.text('School pickup'), findsOneWidget);
    expect(find.byKey(const Key('today.chores.error')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('today.chores.retry')));
    await tester.tap(find.byKey(const Key('today.chores.retry')));
    await tester.pumpAndSettle();

    expect(find.text('Recovered chore'), findsOneWidget);
    expect(find.text('School pickup'), findsOneWidget);
    expect(
      chores.listRequests.where(
        (ChoreListRequest request) => request.view == ChoreListView.today,
      ),
      hasLength(2),
    );
    expect(
      chores.listRequests.where(
        (ChoreListRequest request) => request.view == ChoreListView.overdue,
      ),
      hasLength(2),
    );
  });

  testWidgets('refuses to mix Calendar content from another local date', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence chore = _chore(title: 'Current-day chore');
    final OneTimeCalendarEvent wrongDay = calendarEventFixture(
      title: 'Wrong-day event',
      localStartDate: '2026-08-08',
    );

    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[chore],
        ),
      ),
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(
          localDate: '2026-08-08',
          events: <OneTimeCalendarEvent>[wrongDay],
        ),
      ),
    );

    expect(find.text('Current-day chore'), findsOneWidget);
    expect(find.text('Wrong-day event'), findsNothing);
    expect(find.byKey(const Key('today.calendar.error')), findsOneWidget);
  });

  testWidgets('Me narrows both assignee and participant sources', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence alexChore = _chore(title: 'Alex chore');
    final ChoreOccurrence jamieChore = _chore(
      occurrenceId: '55555555-5555-4555-8555-555555555559',
      seriesId: '44444444-4444-4444-8444-444444444449',
      title: 'Jamie chore',
      assigneeMemberId: calendarMemberTwoId(),
      assigneeDisplayName: 'Jamie',
    );
    final OneTimeCalendarEvent alexEvent = _event(title: 'Alex event');
    final OneTimeCalendarEvent jamieEvent = _event(
      seriesId: calendarSeriesTwoUuid,
      occurrenceId: calendarOccurrenceTwoUuid,
      title: 'Jamie event',
      participants: <CalendarEventParticipant>[
        CalendarEventParticipant.tryCreate(
          memberId: calendarMemberTwoId(),
          displayName: 'Jamie',
        )!,
      ],
    );

    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[alexChore, jamieChore],
        ),
      ),
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[
        alexEvent,
        jamieEvent,
      ]),
    );

    expect(find.text('Alex chore'), findsOneWidget);
    expect(find.text('Jamie chore'), findsOneWidget);
    expect(find.text('Alex event'), findsOneWidget);
    expect(find.text('Jamie event'), findsOneWidget);

    await tester.tap(find.byKey(const Key('today.assignee.me')));
    await tester.pumpAndSettle();

    expect(find.text('Alex chore'), findsOneWidget);
    expect(find.text('Jamie chore'), findsNothing);
    expect(find.text('Alex event'), findsOneWidget);
    expect(find.text('Jamie event'), findsNothing);
  });

  testWidgets(
    'orders five Today sections and keeps completed chores collapsed',
    (WidgetTester tester) async {
      final ChoreOccurrence overdue = _chore(
        occurrenceId: '55555555-5555-4555-8555-555555555571',
        seriesId: '44444444-4444-4444-8444-444444444471',
        title: 'Overdue chore',
        dueLocalDate: '2026-08-06',
      );
      final ChoreOccurrence scheduled = _chore(
        occurrenceId: '55555555-5555-4555-8555-555555555572',
        seriesId: '44444444-4444-4444-8444-444444444472',
        title: 'Due today',
      );
      final ChoreOccurrence completed = _chore(
        occurrenceId: '55555555-5555-4555-8555-555555555573',
        seriesId: '44444444-4444-4444-8444-444444444473',
        title: 'Completed today',
        status: ChoreOccurrenceStatus.completed,
      );
      final OneTimeCalendarEvent next = _event(
        title: 'Next event',
        localStartTime: '10:00',
        startsAt: '2026-08-07T01:00:00Z',
      );
      final OneTimeCalendarEvent remaining = _event(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'Remaining event',
        localStartTime: '11:00',
        startsAt: '2026-08-07T02:00:00Z',
      );
      final FakeChoreRepository chores = FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[overdue, scheduled, completed],
        ),
      );

      await _pumpToday(
        tester,
        choreRepository: chores,
        calendarRepository: _calendarWith(<OneTimeCalendarEvent>[
          next,
          remaining,
        ]),
      );

      final List<Finder> headings = <Finder>[
        find.byKey(const Key('today.overdue.heading')),
        find.byKey(const Key('today.calendar.nowAndNext.heading')),
        find.byKey(const Key('today.chores.heading')),
        find.byKey(const Key('today.calendar.remaining.heading')),
        find.byKey(const Key('today.completed.toggle')),
      ];
      for (var index = 1; index < headings.length; index += 1) {
        expect(
          tester.getTopLeft(headings[index - 1]).dy,
          lessThan(tester.getTopLeft(headings[index]).dy),
        );
      }
      expect(
        find.byKey(Key('today.chore.${completed.id.value}')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('today.completed.toggle')),
      );
      await tester.tap(find.byKey(const Key('today.completed.toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('today.chore.${completed.id.value}')),
        findsOneWidget,
      );

      final Finder overdueToggle = find.byKey(
        Key('today.chore.toggle.${overdue.id.value}'),
      );
      await tester.ensureVisible(overdueToggle);
      await tester.tap(overdueToggle);
      await tester.pumpAndSettle();
      expect(find.byKey(Key('today.chore.${overdue.id.value}')), findsNothing);
      expect(chores.completionRequests.single.occurrenceId, overdue.id);
    },
  );

  testWidgets('isolates an overdue source failure and retries only it', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence chore = _chore(title: 'Available today chore');
    final FakeChoreRepository chores = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async {
        if (request.view == ChoreListView.overdue) {
          return const LoadTodayChoresFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          );
        }
        return TodayChoresLoaded(
          todayChoresFixture(
            localDate: '2026-08-07',
            view: request.view,
            assigneeFilterMemberId: request.assigneeMemberId,
            occurrences: <ChoreOccurrence>[chore],
          ),
        );
      },
    );

    await _pumpToday(
      tester,
      choreRepository: chores,
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[
        _event(title: 'Available event'),
      ]),
    );

    expect(find.text('Available today chore'), findsOneWidget);
    expect(find.text('Available event'), findsOneWidget);
    expect(find.byKey(const Key('today.overdue.error')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('today.overdue.retry')));
    await tester.tap(find.byKey(const Key('today.overdue.retry')));
    await tester.pumpAndSettle();

    expect(
      chores.listRequests.where(
        (ChoreListRequest request) => request.view == ChoreListView.today,
      ),
      hasLength(1),
    );
    expect(
      chores.listRequests.where(
        (ChoreListRequest request) => request.view == ChoreListView.overdue,
      ),
      hasLength(2),
    );
    expect(find.text('Available today chore'), findsOneWidget);
  });

  testWidgets(
    'shows cached Calendar as read-only and restores controls after retry',
    (WidgetTester tester) async {
      final OneTimeCalendarEvent cached = _event(title: 'Saved family event');
      final OneTimeCalendarEvent fresh = _event(title: 'Fresh family event');
      final _MemoryTodayCalendarSnapshotCache cache =
          _MemoryTodayCalendarSnapshotCache(
            _cachedSnapshot(<OneTimeCalendarEvent>[cached]),
          );
      final FakeCalendarRepository calendar = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
          CalendarEventPageLoaded(
            calendarEventPageFixture(
              events: <OneTimeCalendarEvent>[fresh],
              limit: 100,
            ),
          ),
        ],
      );

      await _pumpToday(
        tester,
        choreRepository: FakeChoreRepository(
          today: todayChoresFixture(localDate: '2026-08-07'),
        ),
        calendarRepository: calendar,
        calendarSnapshotCache: cache,
      );

      expect(find.text('Saved family event'), findsOneWidget);
      expect(
        find.byKey(const Key('today.calendar.offlineCache')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Saved events are read-only. Reconnect and refresh before changing '
          'the Today view or household calendar.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('today.assignee.me')))
            .onSelected,
        isNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('today.view.upcoming')))
            .onSelected,
        isNull,
      );

      await tester.ensureVisible(find.byKey(const Key('today.calendar.retry')));
      await tester.tap(find.byKey(const Key('today.calendar.retry')));
      await tester.pumpAndSettle();

      expect(find.text('Saved family event'), findsNothing);
      expect(find.text('Fresh family event'), findsOneWidget);
      expect(
        find.byKey(const Key('today.calendar.offlineCache')),
        findsNothing,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('today.assignee.me')))
            .onSelected,
        isNotNull,
      );
      expect(cache.writeCount, 1);
      expect(calendar.pageRequests, hasLength(2));
    },
  );

  testWidgets('cached empty Calendar fits pseudo locale at 200 percent', (
    WidgetTester tester,
  ) async {
    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(localDate: '2026-08-07'),
      ),
      calendarRepository: FakeCalendarRepository(
        pageResults: const <LoadCalendarEventPageResult>[
          LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      ),
      calendarSnapshotCache: _MemoryTodayCalendarSnapshotCache(
        _cachedSnapshot(const <OneTimeCalendarEvent>[]),
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    expect(
      find.byKey(const Key('today.calendar.offlineCache')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('today.calendar.nowAndNext.empty')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('combined Today has no overflow at 200% pseudo locale', (
    WidgetTester tester,
  ) async {
    await _pumpToday(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(
          localDate: '2026-08-07',
          occurrences: <ChoreOccurrence>[
            _chore(title: 'A deliberately descriptive household chore'),
          ],
        ),
      ),
      calendarRepository: _calendarWith(<OneTimeCalendarEvent>[
        _event(title: 'A deliberately descriptive shared calendar event'),
      ]),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    expect(
      find.byKey(const Key('today.calendar.nowAndNext.ready')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today.chores.heading')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpToday(
  WidgetTester tester, {
  required ChoreRepository choreRepository,
  required CalendarRepository calendarRepository,
  TodayCalendarSnapshotCache? calendarSnapshotCache,
  Locale? locale,
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
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
      choreRepositoryProvider.overrideWithValue(choreRepository),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
      calendarRepositoryProvider.overrideWithValue(calendarRepository),
      calendarCommandIdGeneratorProvider.overrideWithValue(
        FakeCalendarCommandIdGenerator(),
      ),
      calendarTimeResolverProvider.overrideWithValue(
        TimezoneCalendarTimeResolver(),
      ),
      if (calendarSnapshotCache != null)
        todayCalendarSnapshotCacheProvider.overrideWithValue(
          calendarSnapshotCache,
        ),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(authRepository.close);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
}

FakeCalendarRepository _calendarWith(List<OneTimeCalendarEvent> events) {
  return FakeCalendarRepository(
    eventList: calendarEventListFixture(
      events: events,
      localDate: '2026-08-07',
    ),
  );
}

ChoreOccurrence _chore({
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  required String title,
  HouseholdMemberId? assigneeMemberId,
  String assigneeDisplayName = 'Alex',
  String dueLocalDate = '2026-08-07',
  ChoreOccurrenceStatus status = ChoreOccurrenceStatus.scheduled,
}) {
  return choreOccurrenceFixture(
    occurrenceId: occurrenceId,
    seriesId: seriesId,
    title: title,
    assigneeMemberId: assigneeMemberId,
    assigneeDisplayName: assigneeDisplayName,
    dueLocalDate: ChoreLocalDate.tryParse(dueLocalDate)!,
    status: status,
  );
}

OneTimeCalendarEvent _event({
  String seriesId = calendarSeriesOneUuid,
  String occurrenceId = calendarOccurrenceOneUuid,
  required String title,
  List<CalendarEventParticipant>? participants,
  String localStartTime = '19:00',
  String startsAt = '2026-08-07T10:00:00Z',
}) {
  return calendarEventFixture(
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    title: title,
    localStartDate: '2026-08-07',
    localStartTime: localStartTime,
    startsAt: startsAt,
    participants: participants,
  );
}

Future<void> _successfulInitialization() async {}

CachedTodayCalendarSnapshot _cachedSnapshot(List<OneTimeCalendarEvent> events) {
  final CalendarEventPage page = calendarEventPageFixture(
    events: events,
    limit: 100,
  );
  final TodayCalendarSnapshot snapshot = TodayCalendarSnapshot.tryCreate(
    householdId: page.householdId,
    householdTimeZone: page.householdTimeZone,
    localDate: page.householdLocalDate,
    generatedAt: page.generatedAt,
    participantMemberId: null,
    events: page.items,
    truncated: false,
  )!;
  return CachedTodayCalendarSnapshot(
    snapshot: snapshot,
    metadata: ReadCacheMetadata(
      validatedAt: snapshot.generatedAt.dateTime,
      expiresAt: snapshot.generatedAt.dateTime.add(const Duration(hours: 2)),
    ),
  );
}

final class _MemoryTodayCalendarSnapshotCache
    implements TodayCalendarSnapshotCache {
  _MemoryTodayCalendarSnapshotCache(this.stored);

  CachedTodayCalendarSnapshot? stored;
  var writeCount = 0;

  @override
  Future<CachedTodayCalendarSnapshot?> read(
    TodayCalendarRequest request,
  ) async {
    final CachedTodayCalendarSnapshot? value = stored;
    return value != null &&
            value.snapshot.householdId == request.householdId &&
            value.snapshot.participantMemberId == request.participantMemberId
        ? value
        : null;
  }

  @override
  Future<bool> write(TodayCalendarSnapshot snapshot) async {
    writeCount += 1;
    stored = CachedTodayCalendarSnapshot(
      snapshot: snapshot,
      metadata: ReadCacheMetadata(
        validatedAt: snapshot.generatedAt.dateTime,
        expiresAt: snapshot.generatedAt.dateTime.add(const Duration(hours: 2)),
      ),
    );
    return true;
  }

  @override
  Future<bool> delete() async {
    stored = null;
    return true;
  }

  @override
  Future<bool> clearAll() async {
    stored = null;
    return true;
  }
}
