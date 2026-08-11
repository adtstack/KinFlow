import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets('selects exactly three editable templates and opens Today', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository();
    await _pumpGuidedSetup(tester, repository: repository);

    expect(find.byKey(const Key('chore.guided.screen')), findsOneWidget);
    expect(find.text('0 of 3 selected'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('chore.guided.submit')))
          .onPressed,
      isNull,
    );

    await _selectTemplates(tester);
    expect(find.text('3 of 3 selected'), findsOneWidget);
    final FilterChip unavailable = tester.widget<FilterChip>(
      find.byKey(const Key('chore.guided.template.vacuuming')),
    );
    expect(unavailable.onSelected, isNull);

    final Finder dishesTitle = find.byKey(
      const Key('chore.guided.title.dishes'),
    );
    await tester.ensureVisible(dishesTitle);
    await tester.enterText(dishesTitle, 'Dinner dishes');
    final Finder kitchenRepeat = find.byKey(
      const Key('chore.guided.repeat.kitchen_reset'),
    );
    await tester.ensureVisible(kitchenRepeat);
    await tester.tap(kitchenRepeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();

    final Finder submit = find.byKey(const Key('chore.guided.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(repository.recurringRequests, hasLength(3));
    expect(
      repository.recurringRequests.map((request) => request.title),
      <String>['Dinner dishes', 'Kitchen reset', 'Laundry'],
    );
    expect(
      repository.recurringRequests[1].recurrenceRule.frequency,
      ChoreRecurrenceFrequency.weekly,
    );
    expect(
      repository.recurringRequests.map(
        (request) => request.startLocalDate.value,
      ),
      everyElement('2026-08-06'),
    );
    expect(
      repository.recurringRequests.map((request) => request.dueLocalTime),
      everyElement(isNull),
    );
    expect(
      repository.recurringRequests.map((request) => request.description),
      everyElement(isNull),
    );
  });

  testWidgets('partial failure freezes the draft and retries only the rest', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository(
      recurringResults: <CreateRecurringChoreResult>[
        RecurringChoreCreated(_snapshot()),
        const CreateRecurringChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        RecurringChoreCreated(_snapshot()),
        RecurringChoreCreated(_snapshot()),
      ],
    );
    await _pumpGuidedSetup(tester, repository: repository);
    await _selectTemplates(tester);

    final Finder submit = find.byKey(const Key('chore.guided.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.guided.error')), findsOneWidget);
    expect(find.text('1 of 3 chores added'), findsOneWidget);
    expect(repository.recurringRequests, hasLength(2));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('chore.guided.title.dishes')),
          )
          .enabled,
      isFalse,
    );

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(repository.recurringRequests, hasLength(4));
    expect(
      repository.recurringRequests[1].idempotencyKey,
      repository.recurringRequests[2].idempotencyKey,
    );
  });

  testWidgets(
    'submits monthly count and canonical multiple-weekday recurrence',
    (WidgetTester tester) async {
      final FakeChoreRepository repository = FakeChoreRepository();
      await _pumpGuidedSetup(tester, repository: repository);
      await _selectTemplates(tester);

      final Finder dishesRepeat = find.byKey(
        const Key('chore.guided.repeat.dishes'),
      );
      await tester.ensureVisible(dishesRepeat);
      await tester.tap(dishesRepeat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every month').last);
      await tester.pumpAndSettle();

      final Finder dishesInterval = find.byKey(
        const Key('chore.guided.recurrence.dishes.interval'),
      );
      await tester.ensureVisible(dishesInterval);
      await tester.enterText(dishesInterval, '3');
      final Finder dishesEnd = find.byKey(
        const Key('chore.guided.recurrence.dishes.end'),
      );
      await tester.ensureVisible(dishesEnd);
      await tester.tap(dishesEnd);
      await tester.pumpAndSettle();
      await tester.tap(find.text('After a number of occurrences').last);
      await tester.pumpAndSettle();
      final Finder dishesCount = find.byKey(
        const Key('chore.guided.recurrence.dishes.count'),
      );
      await tester.ensureVisible(dishesCount);
      await tester.enterText(dishesCount, '12');

      final Finder kitchenRepeat = find.byKey(
        const Key('chore.guided.repeat.kitchen_reset'),
      );
      await tester.ensureVisible(kitchenRepeat);
      await tester.tap(kitchenRepeat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week').last);
      await tester.pumpAndSettle();
      final Finder monday = find.byKey(
        const Key('chore.guided.recurrence.kitchen_reset.weekday.MO'),
      );
      await tester.ensureVisible(monday);
      await tester.tap(monday);
      await tester.pumpAndSettle();

      final Finder submit = find.byKey(const Key('chore.guided.submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repository.recurringRequests, hasLength(3));
      final ChoreRecurrenceRule monthly =
          repository.recurringRequests[0].recurrenceRule;
      expect(monthly.frequency, ChoreRecurrenceFrequency.monthly);
      expect(monthly.interval, 3);
      expect(monthly.monthDay, 6);
      expect(monthly.end, isA<ChoreRecurrenceCountEnd>());
      expect((monthly.end as ChoreRecurrenceCountEnd).count, 12);
      final ChoreRecurrenceRule weekly =
          repository.recurringRequests[1].recurrenceRule;
      expect(weekly.frequency, ChoreRecurrenceFrequency.weekly);
      expect(weekly.weekdays, <ChoreWeekday>[
        ChoreWeekday.monday,
        ChoreWeekday.thursday,
      ]);
    },
  );

  testWidgets('skip requires confirmation and creates nothing', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository();
    await _pumpGuidedSetup(tester, repository: repository);

    await tester.tap(find.byKey(const Key('chore.guided.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chore.guided.exitDialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chore.guided.stay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chore.guided.screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chore.guided.close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chore.guided.confirmExit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(repository.recurringRequests, isEmpty);
  });

  testWidgets('partial exit discloses that created chores are preserved', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository(
      recurringResults: <CreateRecurringChoreResult>[
        RecurringChoreCreated(_snapshot()),
        const CreateRecurringChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    await _pumpGuidedSetup(tester, repository: repository);
    await _selectTemplates(tester);
    final Finder submit = find.byKey(const Key('chore.guided.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final Finder skip = find.byKey(const Key('chore.guided.skip'));
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();

    expect(find.textContaining('Added so far: 1.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chore.guided.confirmExit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(repository.recurringRequests, hasLength(2));
  });

  testWidgets('Korean copy uses the guided onboarding localization', (
    WidgetTester tester,
  ) async {
    await _pumpGuidedSetup(
      tester,
      repository: FakeChoreRepository(),
      locale: const Locale('ko'),
    );

    expect(find.text('함께 시작할 집안일 세 개 고르기'), findsOneWidget);
    expect(find.text('3개 중 0개 선택'), findsOneWidget);
    expect(find.text('설거지'), findsOneWidget);
  });

  testWidgets('guided setup searches categories and keeps exact-three limit', (
    WidgetTester tester,
  ) async {
    await _pumpGuidedSetup(tester, repository: FakeChoreRepository());

    final Finder petCare = find.byKey(
      const Key('chore.guided.template.category.pet_care'),
    );
    await tester.ensureVisible(petCare);
    await tester.tap(petCare);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('chore.guided.template.feed_pets')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chore.guided.template.clean_pet_area')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chore.guided.template.dishes')), findsNothing);

    final Finder feedPets = find.byKey(
      const Key('chore.guided.template.feed_pets'),
    );
    await tester.ensureVisible(feedPets);
    await tester.tap(feedPets);
    await tester.pumpAndSettle();
    final Finder cleanPetArea = find.byKey(
      const Key('chore.guided.template.clean_pet_area'),
    );
    await tester.ensureVisible(cleanPetArea);
    await tester.tap(cleanPetArea);
    await tester.pumpAndSettle();
    final Finder all = find.byKey(
      const Key('chore.guided.template.category.all'),
    );
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pumpAndSettle();
    final Finder dishes = find.byKey(const Key('chore.guided.template.dishes'));
    await tester.ensureVisible(dishes);
    await tester.tap(dishes);
    await tester.pumpAndSettle();

    expect(find.text('3 of 3 selected'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('chore.guided.template.kitchen_reset')),
          )
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const Key('chore.guided.template.feed_pets')),
          )
          .onSelected,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pseudo copy remains scrollable at 200 percent text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpGuidedSetup(
      tester,
      repository: FakeChoreRepository(),
      locale: const Locale('en', 'XA'),
    );

    await _selectTemplates(tester);
    final Finder submit = find.byKey(const Key('chore.guided.submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cold Today entry redirects and restores a frozen partial batch',
    (WidgetTester tester) async {
      final FakeGuidedChoreSetupResumeStore store =
          FakeGuidedChoreSetupResumeStore(plan: _resumePlan(completedCount: 1));
      final FakeChoreRepository repository = FakeChoreRepository(
        recurringResults: const <CreateRecurringChoreResult>[
          CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();

      await _pumpGuidedSetup(
        tester,
        repository: repository,
        resumeStore: store,
        commandIdGenerator: generator,
        navigateToGuided: false,
      );

      expect(find.byKey(const Key('chore.guided.screen')), findsOneWidget);
      expect(
        find.byKey(const Key('chore.guided.resumeNotice')),
        findsOneWidget,
      );
      expect(find.text('1 of 3 chores added'), findsOneWidget);
      expect(repository.listRequests, isEmpty);
      expect(repository.recurringRequests, hasLength(1));
      expect(repository.recurringRequests.single.title, 'Kitchen reset');
      expect(
        repository.recurringRequests.single.idempotencyKey,
        store.plan!.commandIds[1],
      );
      expect(generator.generateCount, 0);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('chore.guided.title.dishes')),
            )
            .controller!
            .text,
        'Dishes',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('chore.guided.title.dishes')),
            )
            .enabled,
        isFalse,
      );
      expect(
        repository.recurringRequests.single.recurrenceRule.frequency,
        ChoreRecurrenceFrequency.monthly,
      );
      expect(repository.recurringRequests.single.recurrenceRule.interval, 2);
      expect(
        (repository.recurringRequests.single.recurrenceRule.end
                as ChoreRecurrenceCountEnd)
            .count,
        9,
      );
      final TextFormField restoredInterval = tester.widget<TextFormField>(
        find.byKey(const Key('chore.guided.recurrence.kitchen_reset.interval')),
      );
      expect(restoredInterval.controller!.text, '2');
      expect(restoredInterval.enabled, isFalse);
    },
  );

  testWidgets('exit stays put until the pending secure record is cleared', (
    WidgetTester tester,
  ) async {
    final FakeGuidedChoreSetupResumeStore store =
        FakeGuidedChoreSetupResumeStore(clearResults: <bool>[false, true]);
    await _pumpGuidedSetup(
      tester,
      repository: FakeChoreRepository(),
      resumeStore: store,
    );

    await tester.tap(find.byKey(const Key('chore.guided.close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chore.guided.confirmExit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.guided.screen')), findsOneWidget);
    expect(find.byKey(const Key('chore.guided.error')), findsOneWidget);
    expect(store.clearCount, 1);

    await tester.tap(find.byKey(const Key('chore.guided.close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chore.guided.confirmExit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(store.clearCount, 2);
  });

  testWidgets('Today continues safely when resume preflight throws', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository();
    await _pumpGuidedSetup(
      tester,
      repository: repository,
      resumeStore: FakeGuidedChoreSetupResumeStore(throwOnRead: true),
      navigateToGuided: false,
    );

    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(repository.listRequests, isNotEmpty);
    expect(find.byKey(const Key('chore.guided.screen')), findsNothing);
  });
}

Future<void> _selectTemplates(WidgetTester tester) async {
  for (final String key in <String>['dishes', 'kitchen_reset', 'laundry']) {
    final Finder chip = find.byKey(Key('chore.guided.template.$key'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }
}

Future<ProviderContainer> _pumpGuidedSetup(
  WidgetTester tester, {
  required ChoreRepository repository,
  Locale? locale,
  FakeGuidedChoreSetupResumeStore? resumeStore,
  FakeChoreCommandIdGenerator? commandIdGenerator,
  bool navigateToGuided = true,
}) async {
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
      choreRepositoryProvider.overrideWithValue(repository),
      choreCommandIdGeneratorProvider.overrideWithValue(
        commandIdGenerator ?? FakeChoreCommandIdGenerator(),
      ),
      guidedChoreSetupResumeStoreProvider.overrideWithValue(
        resumeStore ?? FakeGuidedChoreSetupResumeStore(),
      ),
      calendarRepositoryProvider.overrideWithValue(
        FakeCalendarRepository(
          eventList: calendarEventListFixture(localDate: '2026-08-06'),
        ),
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
  if (navigateToGuided) {
    container.read(appRouterProvider).go(AppRoutes.guidedChoreSetup);
    await tester.pumpAndSettle();
  }
  return container;
}

GuidedChoreSetupResumePlan _resumePlan({required int completedCount}) {
  final ChoreLocalDate startLocalDate = ChoreLocalDate.tryParse('2026-08-06')!;
  final ChoreRecurrenceRule monthly = ChoreRecurrenceRule.tryAnchored(
    frequency: ChoreRecurrenceFrequency.monthly,
    startLocalDate: startLocalDate,
    interval: 2,
    end: const ChoreRecurrenceCountEnd(9),
  )!;
  return GuidedChoreSetupResumePlan.tryCreate(
    householdId: activeHouseholdFixture().householdId,
    assigneeMemberId: activeHouseholdFixture().memberId,
    startLocalDate: startLocalDate,
    householdTimezone: 'Asia/Seoul',
    inputs: <GuidedChoreSetupInput>[
      GuidedChoreSetupInput(
        template: ChoreTemplatePreset.dishes,
        title: 'Dishes',
        frequency: ChoreRecurrenceFrequency.daily,
      ),
      GuidedChoreSetupInput.withRecurrence(
        template: ChoreTemplatePreset.kitchenReset,
        title: 'Kitchen reset',
        recurrenceRule: monthly,
      ),
      GuidedChoreSetupInput(
        template: ChoreTemplatePreset.laundry,
        title: 'Laundry',
        frequency: ChoreRecurrenceFrequency.weekly,
      ),
    ],
    commandIds: <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ].map((String value) => ChoreCommandId.tryParse(value)!).toList(),
    completedCount: completedCount,
  )!;
}

RecurringChoreSnapshot _snapshot() {
  final start = ChoreLocalDate.tryParse('2026-08-06')!;
  return RecurringChoreSnapshot(
    householdId: activeHouseholdFixture().householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    firstOccurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.daily,
      startLocalDate: start,
    ),
    materializedThrough: start,
    materializedCount: 1,
    created: true,
  );
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _successfulInitialization() async {}
