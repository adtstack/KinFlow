import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_primary_destination.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../support/fakes/fake_auth_dependencies.dart';
import '../support/fakes/fake_calendar_dependencies.dart';
import '../support/fakes/fake_chore_dependencies.dart';
import '../support/fakes/fake_household_dependencies.dart';
import '../support/fakes/fake_household_member_dependencies.dart';
import '../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  const List<({String key, Size size})> layoutScenarios =
      <({String key, Size size})>[
        (key: 'layout.compact', size: Size(390, 844)),
        (key: 'layout.medium', size: Size(700, 800)),
        (key: 'layout.expanded', size: Size(1200, 800)),
      ];

  for (final ({String key, Size size}) scenario in layoutScenarios) {
    testWidgets('selects ${scenario.key} from available width', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, size: scenario.size);

      expect(find.byKey(Key(scenario.key)), findsOneWidget);
      expect(find.byKey(const Key('layout.primaryNavigation')), findsOneWidget);
      for (final AppPrimaryDestination destination
          in AppPrimaryDestination.values) {
        expect(
          find.byKey(Key('layout.primaryNavigation.${destination.name}')),
          findsOneWidget,
        );
      }
      expect(
        scenario.key == 'layout.compact'
            ? find.byType(NavigationBar)
            : find.byType(NavigationRail),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('core navigation exposes four stable primary destinations', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    final ProviderContainer container = await _pumpApp(
      tester,
      size: const Size(390, 844),
      choreRepository: choreRepository,
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(localDate: '2026-08-06'),
      ),
    );
    final router = container.read(appRouterProvider);
    NavigationBar navigation = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(navigation.selectedIndex, AppPrimaryDestination.today.index);
    expect(
      navigation.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
    expect(
      navigation.destinations.cast<NavigationDestination>().map(
        (NavigationDestination destination) => destination.label,
      ),
      <String>['Today', 'Calendar', 'Family', 'Settings'],
    );
    final int initialRequestCount = choreRepository.listRequests.length;
    await tester.tap(find.byKey(const Key('layout.primaryNavigation.today')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.today);
    expect(choreRepository.listRequests, hasLength(initialRequestCount));

    const List<({AppPrimaryDestination destination, String path, String key})>
    journeys = <({AppPrimaryDestination destination, String path, String key})>[
      (
        destination: AppPrimaryDestination.calendar,
        path: AppRoutes.calendar,
        key: 'calendar.screen',
      ),
      (
        destination: AppPrimaryDestination.family,
        path: AppRoutes.family,
        key: 'members.screen',
      ),
      (
        destination: AppPrimaryDestination.settings,
        path: AppRoutes.settings,
        key: 'settings.screen',
      ),
      (
        destination: AppPrimaryDestination.today,
        path: AppRoutes.today,
        key: 'today.screen',
      ),
    ];
    for (final journey in journeys) {
      final Finder destination = find.byKey(
        Key('layout.primaryNavigation.${journey.destination.name}'),
      );
      expect(tester.getSize(destination).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(destination).height, greaterThanOrEqualTo(48));
      await tester.tap(destination);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, journey.path);
      expect(find.byKey(Key(journey.key)), findsOneWidget);
      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.selectedIndex, journey.destination.index);
    }

    await tester.tap(find.byKey(const Key('today.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.chores')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.chores);
    expect(find.byKey(const Key('chores.screen')), findsOneWidget);
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, AppPrimaryDestination.today.index);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.today);

    await tester.tap(find.byKey(const Key('today.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.chores')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('layout.primaryNavigation.today')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.today);
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'authenticated expanded core navigation completes with keyboard only',
    (WidgetTester tester) async {
      final ProviderContainer container = await _pumpApp(
        tester,
        size: const Size(1200, 800),
      );
      final router = container.read(appRouterProvider);
      const List<({AppPrimaryDestination destination, String path, String key})>
      journeys =
          <({AppPrimaryDestination destination, String path, String key})>[
            (
              destination: AppPrimaryDestination.calendar,
              path: AppRoutes.calendar,
              key: 'calendar.screen',
            ),
            (
              destination: AppPrimaryDestination.family,
              path: AppRoutes.family,
              key: 'members.screen',
            ),
            (
              destination: AppPrimaryDestination.settings,
              path: AppRoutes.settings,
              key: 'settings.screen',
            ),
            (
              destination: AppPrimaryDestination.today,
              path: AppRoutes.today,
              key: 'today.screen',
            ),
          ];

      for (final journey in journeys) {
        final Finder destination = find.byKey(
          Key('layout.primaryNavigation.${journey.destination.name}'),
        );
        expect(
          await _focusWithTab(tester, destination),
          isTrue,
          reason: 'Could not focus ${journey.destination.name}',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(router.state.uri.path, journey.path);
        expect(find.byKey(Key(journey.key)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exposes headings, navigation, status, and retry semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await _pumpApp(tester, size: const Size(1200, 800));

      expect(find.semantics.byLabel('Primary navigation'), findsOne);
      expect(
        tester.getSemantics(find.byKey(const Key('layout.pageHeading'))),
        isSemantics(label: 'Today', isHeader: true),
      );
      expect(
        tester.getSemantics(find.text('Nothing is scheduled for today')),
        isSemantics(label: 'Nothing is scheduled for today', isHeader: true),
      );

      await _pumpApp(
        tester,
        size: const Size(390, 844),
        householdRepository: FakeHouseholdRepository(
          defaultLoadResult: const LoadActiveHouseholdFailed(
            HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('household.resolutionRetry'))),
        isSemantics(
          label: 'Try again',
          hint: 'Runs this check again',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  const List<({Locale locale, String layoutKey, Size size})> scaleScenarios =
      <({Locale locale, String layoutKey, Size size})>[
        (
          locale: Locale('ko'),
          layoutKey: 'layout.compact',
          size: Size(320, 568),
        ),
        (
          locale: Locale('en', 'XA'),
          layoutKey: 'layout.compact',
          size: Size(320, 568),
        ),
        (
          locale: Locale('en', 'XA'),
          layoutKey: 'layout.medium',
          size: Size(700, 600),
        ),
        (
          locale: Locale('en', 'XA'),
          layoutKey: 'layout.expanded',
          size: Size(1000, 700),
        ),
      ];

  for (final scenario in scaleScenarios) {
    testWidgets('${scenario.locale.toLanguageTag()} ${scenario.layoutKey} '
        'has no blocker overflow at 200% text', (WidgetTester tester) async {
      await _pumpApp(
        tester,
        locale: scenario.locale,
        size: scenario.size,
        textScaleFactor: 2,
      );

      expect(find.byKey(Key(scenario.layoutKey)), findsOneWidget);
      expect(find.byKey(const Key('layout.scrollableStatus')), findsOneWidget);
      expect(find.byKey(const Key('today.empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restructured settings stays usable at 200% pseudo text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.settings')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings.screen')), findsOneWidget);
    expect(find.byKey(const Key('settings.list')), findsOneWidget);
    for (final String key in <String>[
      'settings.notifications',
      'settings.profilePreferences',
      'settings.accountDeletion',
    ]) {
      final Finder control = find.byKey(Key(key));
      await tester.ensureVisible(control);
      await tester.pump();
      expect(
        tester.getSize(control).height,
        greaterThanOrEqualTo(48),
        reason: '$key must keep a 48dp touch target',
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final Locale locale in <Locale>[
    const Locale('ko'),
    const Locale('en', 'XA'),
  ]) {
    testWidgets('Today chore actions fit ${locale.toLanguageTag()} at 200%', (
      WidgetTester tester,
    ) async {
      final occurrence = choreOccurrenceFixture(
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrenceHistoryEvent historyEvent =
          ChoreOccurrenceHistoryEvent.tryCreate(
            id: ChoreHistoryEntryId.tryParse(
              'completion:61000000-0000-4000-8000-000000000701',
            )!,
            type: ChoreOccurrenceHistoryEventType.completed,
            actorMemberId: activeHouseholdFixture().memberId,
            actorDisplayName: 'Alexandra Household Member',
            actingMemberId: null,
            actingDisplayName: null,
            occurredAt: DateTime.utc(2026, 8, 7, 1),
            occurrenceVersion: 2,
            previousDueLocalDate: null,
            previousDueLocalTime: null,
            newDueLocalDate: null,
            newDueLocalTime: null,
            previousAssigneeMemberId: null,
            previousAssigneeDisplayName: null,
            newAssigneeMemberId: null,
            newAssigneeDisplayName: null,
          )!;
      final ChoreOccurrenceHistoryPage historyPage =
          ChoreOccurrenceHistoryPage.tryCreate(
            householdId: todayChoresFixture().householdId,
            occurrenceId: occurrence.id,
            events: <ChoreOccurrenceHistoryEvent>[historyEvent],
            hasMore: false,
          )!;
      await _pumpApp(
        tester,
        locale: locale,
        size: const Size(320, 568),
        textScaleFactor: 2,
        choreRepository: FakeChoreRepository(
          today: todayChoresFixture(occurrences: [occurrence]),
          historyResults: <LoadChoreOccurrenceHistoryResult>[
            ChoreOccurrenceHistoryLoaded(historyPage),
          ],
        ),
      );
      final Finder toggle = find.byKey(
        Key('today.chore.toggle.${occurrence.id.value}'),
      );
      final Finder menu = find.byKey(
        Key('today.chore.menu.${occurrence.id.value}'),
      );

      expect(find.byKey(const Key('today.list')), findsOneWidget);
      await tester.ensureVisible(find.text(occurrence.title));
      await tester.tap(find.text(occurrence.title));
      await tester.pumpAndSettle();
      final Finder closeDetails = find.byKey(const Key('chore.history.close'));
      expect(find.byKey(const Key('chore.history.sheet')), findsOneWidget);
      expect(tester.getSize(closeDetails).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(closeDetails).height, greaterThanOrEqualTo(48));
      final Finder historyEventFinder = find.byKey(
        Key('chore.history.event.${historyEvent.id.value}'),
      );
      for (
        var attempt = 0;
        attempt < 16 && historyEventFinder.evaluate().isEmpty;
        attempt += 1
      ) {
        await tester.drag(
          find.byKey(const Key('chore.history.scroll')),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
      }
      expect(historyEventFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(closeDetails);
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      await tester.pump();
      expect(tester.getSize(toggle).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today.reschedule.menuItem')));
      await tester.pumpAndSettle();
      final Finder rescheduleConfirm = find.byKey(
        const Key('today.reschedule.confirm'),
      );
      final Finder rescheduleCancel = find.byKey(
        const Key('today.reschedule.cancel'),
      );
      await tester.ensureVisible(rescheduleConfirm);
      await tester.pump();
      expect(
        tester.getSize(rescheduleConfirm).height,
        greaterThanOrEqualTo(48),
      );
      await tester.ensureVisible(rescheduleCancel);
      await tester.pump();
      expect(tester.getSize(rescheduleCancel).height, greaterThanOrEqualTo(48));
      await tester.tap(rescheduleCancel);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final Finder reassignMenuItem = find.byKey(
        const Key('today.reassign.menuItem'),
      );
      await tester.ensureVisible(reassignMenuItem);
      await tester.pump();
      await tester.tap(reassignMenuItem);
      await tester.pumpAndSettle();
      final Finder reassignMember = find.byKey(
        const Key('today.reassign.member.33333333-3333-4333-8333-333333333334'),
      );
      await tester.ensureVisible(reassignMember);
      await tester.pump();
      await tester.tap(reassignMember);
      await tester.pump();
      final Finder reassignConfirm = find.byKey(
        const Key('today.reassign.confirm'),
      );
      final Finder reassignCancel = find.byKey(
        const Key('today.reassign.cancel'),
      );
      await tester.ensureVisible(reassignConfirm);
      await tester.pump();
      expect(tester.getSize(reassignConfirm).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(reassignCancel);
      await tester.pump();
      expect(tester.getSize(reassignCancel).height, greaterThanOrEqualTo(48));
      await tester.tap(reassignCancel);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final Finder skipMenuItem = find.byKey(const Key('today.skip.menuItem'));
      await tester.ensureVisible(skipMenuItem);
      await tester.pump();
      await tester.tap(skipMenuItem);
      await tester.pumpAndSettle();
      final Finder confirm = find.byKey(const Key('today.skip.confirm'));
      await tester.ensureVisible(confirm);
      await tester.pump();
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final Finder undo = find.byKey(const Key('today.skip.undo'));
      expect(undo, findsOneWidget);
      expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('today.chore.${occurrence.id.value}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry action remains at least 48dp at 200% text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      locale: const Locale('ko'),
      householdRepository: FakeHouseholdRepository(
        defaultLoadResult: const LoadActiveHouseholdFailed(
          HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
        ),
      ),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.ensureVisible(
      find.byKey(const Key('household.resolutionRetry')),
    );
    await tester.pump();
    final Size retrySize = tester.getSize(
      find.byKey(const Key('household.resolutionRetry')),
    );

    expect(retrySize.width, greaterThanOrEqualTo(48));
    expect(retrySize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in remains scrollable at 200% text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      authenticated: false,
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    expect(find.byKey(const Key('auth.signIn')), findsOneWidget);
    expect(find.byKey(const Key('auth.signIn.google')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('auth.signIn.google')));
    expect(
      tester.getSize(find.byKey(const Key('auth.signIn.google'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('subflow scaffolds omit the core primary navigation', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: const AppResponsiveScaffold(
          title: 'Edit chore',
          body: SizedBox.expand(key: Key('subflow.body')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('layout.expanded')), findsOneWidget);
    expect(find.byKey(const Key('layout.primaryNavigation')), findsNothing);
    expect(find.byKey(const Key('subflow.body')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forced RTL mirrors the expanded rail without declaring Arabic', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'XA'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppResponsiveScaffold(
            title: '[!! Adaptive title !!]',
            selectedPrimaryDestination: AppPrimaryDestination.today,
            onPrimaryDestinationSelected: (_) {},
            body: const SizedBox.expand(key: Key('rtl.body')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect navigation = tester.getRect(
      find.byKey(const Key('layout.primaryNavigation')),
    );
    final Rect content = tester.getRect(
      find.byKey(const Key('layout.content')),
    );

    expect(
      Directionality.of(tester.element(find.byKey(const Key('rtl.body')))),
      TextDirection.rtl,
    );
    expect(navigation.left, greaterThan(content.left));
    expect(
      find.text('[!! Ţôđåŷ household schedule destination !!]'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required Size size,
  bool authenticated = true,
  Locale? locale,
  HouseholdRepository? householdRepository,
  FakeChoreRepository? choreRepository,
  FakeCalendarRepository? calendarRepository,
  double textScaleFactor = 1,
}) async {
  _configureView(tester, size: size, textScaleFactor: textScaleFactor);
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: authenticated
        ? AuthSessionAvailable(authSessionFixture())
        : const AuthSessionAbsent(),
  );
  addTearDown(authRepository.close);
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
        householdRepository ??
            FakeHouseholdRepository(
              defaultLoadResult: ActiveHouseholdLoaded(
                activeHouseholdFixture(),
              ),
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
      choreRepositoryProvider.overrideWithValue(
        choreRepository ?? FakeChoreRepository(),
      ),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
      calendarRepositoryProvider.overrideWithValue(
        calendarRepository ??
            FakeCalendarRepository(
              eventList: calendarEventListFixture(localDate: '2026-08-06'),
            ),
      ),
      calendarCommandIdGeneratorProvider.overrideWithValue(
        FakeCalendarCommandIdGenerator(),
      ),
      calendarTimeResolverProvider.overrideWithValue(
        TimezoneCalendarTimeResolver(),
      ),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  double textScaleFactor = 1,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _successfulInitialization() async {}

Future<bool> _focusWithTab(
  WidgetTester tester,
  Finder target, {
  int maximumTabs = 40,
}) async {
  for (var attempt = 0; attempt <= maximumTabs; attempt += 1) {
    if (_primaryFocusIsWithin(target)) {
      return true;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  return false;
}

bool _primaryFocusIsWithin(Finder target) {
  final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus is FocusScopeNode) {
    return false;
  }
  final BuildContext? focusContext = primaryFocus?.context;
  if (focusContext is! Element) {
    return false;
  }
  final Finder focusedElement = find.byElementPredicate(
    (Element element) => identical(element, focusContext),
  );
  return find
          .ancestor(of: target, matching: focusedElement)
          .evaluate()
          .isNotEmpty ||
      find
          .descendant(of: target, matching: focusedElement)
          .evaluate()
          .isNotEmpty;
}
