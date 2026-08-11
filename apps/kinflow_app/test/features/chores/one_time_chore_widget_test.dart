import 'dart:async';

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
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_chore_sync_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets(
    'disconnected Chore updates retain content and reconnect both Today sources',
    (WidgetTester tester) async {
      final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
      addTearDown(syncRepository.dispose);
      final _ChoreHarness harness = await _pumpChoreApp(
        tester,
        choreRepository: FakeChoreRepository(),
        syncRepository: syncRepository,
        size: const Size(390, 844),
        textScaleFactor: 2,
      );
      expect(syncRepository.watchCount, 2);

      syncRepository.addToAll(const ChoreSyncDisconnected());
      await tester.pump();

      expect(
        find.byKey(const Key('today.choreLive.disconnected')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Live chore updates are paused. The last loaded chores may be out of date.',
        ),
        findsOneWidget,
      );
      final Finder reconnect = find.byKey(
        const Key('today.choreLive.reconnect'),
      );
      await tester.ensureVisible(reconnect);
      await tester.pumpAndSettle();
      expect(reconnect.hitTestable(), findsOneWidget);
      tester.widget<OutlinedButton>(reconnect).onPressed!();
      await tester.pump();

      expect(
        (harness.container.read(todayChoresProvider) as TodayChoresReady)
            .syncStatus,
        ChoreSyncConnectionStatus.connecting,
      );
      expect(
        find.byKey(const Key('today.choreLive.disconnected')),
        findsNothing,
      );
    },
  );

  testWidgets('empty Today creates a persisted chore and reloads the list', (
    WidgetTester tester,
  ) async {
    ChoreOccurrence? created;
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: created == null
              ? const <ChoreOccurrence>[]
              : <ChoreOccurrence>[created!],
        ),
      ),
      createCallback: (CreateOneTimeChoreRequest request) async {
        created = choreOccurrenceFixture(
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId,
          assigneeDisplayName:
              request.assigneeMemberId == activeHouseholdFixture().memberId
              ? 'Alex'
              : 'Sam',
          dueLocalDate: request.dueLocalDate,
          dueLocalTime: request.dueLocalTime,
        );
        return OneTimeChoreCreated(created!);
      },
    );
    final _ChoreHarness harness = await _pumpChoreApp(
      tester,
      choreRepository: choreRepository,
    );

    expect(find.byKey(const Key('today.empty')), findsOneWidget);
    expect(find.byKey(const Key('today.createChore')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.create.screen')), findsOneWidget);
    expect(find.text('Alex (you)'), findsOneWidget);
    final Finder assignee = find.byKey(const Key('chore.create.assignee'));
    await tester.ensureVisible(assignee);
    await tester.tap(assignee);
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      '  Take out recycling  ',
    );
    await tester.enterText(
      find.byKey(const Key('chore.create.description')),
      '  Blue bin  ',
    );
    final Finder submit = find.byKey(const Key('chore.create.submit'));
    await tester.ensureVisible(submit);
    await tester.drag(
      find.byKey(const Key('layout.scrollableStatus')),
      const Offset(0, -48),
    );
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.list')), findsOneWidget);
    expect(find.text('Take out recycling'), findsOneWidget);
    expect(find.text('Sam · Any time'), findsOneWidget);
    expect(choreRepository.createRequests, hasLength(1));
    expect(choreRepository.createRequests.single.title, 'Take out recycling');
    expect(choreRepository.createRequests.single.description, 'Blue bin');
    expect(
      choreRepository.createRequests.single.assigneeMemberId,
      householdMemberRosterFixture().members.last.id,
    );
    expect(
      choreRepository.createRequests.single.dueLocalDate.value,
      '2026-08-06',
    );
    expect(harness.memberRepository.loadedHouseholds, hasLength(1));
    expect(choreRepository.loadedHouseholds.length, greaterThanOrEqualTo(2));
  });

  testWidgets('static template fills an editable recurring chore draft', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.templates')), findsOneWidget);
    for (final String key in <String>[
      'dishes',
      'kitchen_reset',
      'laundry',
      'vacuuming',
      'bathroom_cleaning',
      'trash_and_recycling',
      'wipe_counters',
      'fridge_cleanout',
      'mop_floors',
      'dusting',
      'change_bed_linen',
      'fold_clothes',
      'make_beds',
      'water_plants',
      'feed_pets',
      'clean_pet_area',
    ]) {
      expect(find.byKey(Key('chore.template.$key')), findsOneWidget);
    }

    final Finder dishes = find.byKey(const Key('chore.template.dishes'));
    await tester.ensureVisible(dishes);
    await tester.tap(dishes);
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(dishes).selected, isTrue);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('chore.create.title')))
          .controller
          ?.text,
      'Dishes',
    );
    expect(
      find.byKey(const Key('chore.create.recurrence.summary')),
      findsOneWidget,
    );
    expect(find.text('Every day'), findsWidgets);

    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();
    final Finder monday = find.byKey(
      const Key('chore.create.recurrence.weekday.MO'),
    );
    await tester.ensureVisible(monday);
    await tester.tap(monday);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(monday).selected, isTrue);
    final Finder interval = find.byKey(
      const Key('chore.create.recurrence.interval'),
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '2');
    final Finder end = find.byKey(const Key('chore.create.recurrence.end'));
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.recurrence.count')),
      '6',
    );
    expect(tester.widget<ChoiceChip>(dishes).selected, isFalse);

    await tester.ensureVisible(dishes);
    await tester.tap(dishes);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(dishes).selected, isTrue);
    expect(find.text('Every day'), findsWidgets);
    expect(tester.widget<TextFormField>(interval).controller?.text, '1');
    expect(find.text('Never'), findsOneWidget);
    expect(
      find.byKey(const Key('chore.create.recurrence.count')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Sunday kitchen reset',
    );
    await tester.pump();
    expect(tester.widget<ChoiceChip>(dishes).selected, isFalse);

    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.description')),
      'Keep my editable note',
    );
    await tester.ensureVisible(find.byKey(const Key('chore.create.submit')));
    await tester.tap(find.byKey(const Key('chore.create.submit')));
    await tester.pumpAndSettle();

    expect(choreRepository.createRequests, isEmpty);
    expect(choreRepository.recurringRequests, hasLength(1));
    final CreateRecurringChoreRequest request =
        choreRepository.recurringRequests.single;
    expect(request.title, 'Sunday kitchen reset');
    expect(request.description, 'Keep my editable note');
    expect(request.recurrenceRule.frequency, ChoreRecurrenceFrequency.weekly);
    expect(request.recurrenceRule.interval, 1);
    expect(request.recurrenceRule.weekdays, const <ChoreWeekday>[
      ChoreWeekday.thursday,
    ]);
    expect(request.recurrenceRule.end, isA<ChoreRecurrenceNeverEnds>());
    expect(request.startLocalDate.value, '2026-08-06');
  });

  testWidgets(
    'template library intersects localized category and search while preserving selection',
    (WidgetTester tester) async {
      await _pumpChoreApp(
        tester,
        choreRepository: FakeChoreRepository(),
        locale: const Locale('ko'),
      );
      await tester.tap(find.byKey(const Key('today.createChore')));
      await tester.pumpAndSettle();

      final Finder kitchen = find.byKey(
        const Key('chore.template.category.kitchen'),
      );
      await tester.ensureVisible(kitchen);
      await tester.tap(kitchen);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chore.template.search')),
        '정리',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chore.template.kitchen_reset')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chore.template.fridge_cleanout')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chore.template.make_beds')), findsNothing);
      expect(find.byKey(const Key('chore.template.dishes')), findsNothing);

      final Finder fridge = find.byKey(
        const Key('chore.template.fridge_cleanout'),
      );
      await tester.tap(fridge);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(fridge).selected, isTrue);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('chore.create.title')))
            .controller
            ?.text,
        '냉장고 정리',
      );

      await tester.enterText(
        find.byKey(const Key('chore.template.search')),
        '찾을 수 없는 항목',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chore.template.empty')), findsOneWidget);
      expect(fridge, findsNothing);

      await tester.tap(find.byKey(const Key('chore.template.search.clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chore.template.empty')), findsNothing);
      expect(fridge, findsOneWidget);
      expect(tester.widget<ChoiceChip>(fridge).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('template preserves assignee, notes, and date selections', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.description')),
      'Use the upstairs washer',
    );
    final Finder assignee = find.byKey(const Key('chore.create.assignee'));
    await tester.ensureVisible(assignee);
    await tester.tap(assignee);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();

    final Finder laundry = find.byKey(const Key('chore.template.laundry'));
    await tester.ensureVisible(laundry);
    await tester.tap(laundry);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chore.create.submit')));
    await tester.tap(find.byKey(const Key('chore.create.submit')));
    await tester.pumpAndSettle();

    expect(choreRepository.recurringRequests, hasLength(1));
    final CreateRecurringChoreRequest request =
        choreRepository.recurringRequests.single;
    expect(request.title, 'Laundry');
    expect(request.description, 'Use the upstairs washer');
    expect(
      request.assigneeMemberId,
      householdMemberRosterFixture().members.last.id,
    );
    expect(request.startLocalDate.value, '2026-08-06');
    expect(request.dueLocalTime, isNull);
    expect(request.recurrenceRule.frequency, ChoreRecurrenceFrequency.weekly);
  });

  testWidgets('template selection clears a stale creation failure', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      createResults: const <CreateOneTimeChoreResult>[
        CreateOneTimeChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Retry this chore',
    );
    await tester.ensureVisible(find.byKey(const Key('chore.create.submit')));
    await tester.tap(find.byKey(const Key('chore.create.submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chore.create.error')), findsOneWidget);

    final Finder vacuuming = find.byKey(const Key('chore.template.vacuuming'));
    await tester.ensureVisible(vacuuming);
    await tester.tap(vacuuming);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.create.error')), findsNothing);
    expect(tester.widget<ChoiceChip>(vacuuming).selected, isTrue);
  });

  testWidgets('templates localize in Korean', (WidgetTester tester) async {
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(),
      locale: const Locale('ko'),
    );
    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    expect(find.text('빠른 시작'), findsOneWidget);
    expect(find.text('설거지'), findsOneWidget);
    expect(find.text('쓰레기와 재활용품 버리기'), findsOneWidget);
    final Finder laundry = find.byKey(const Key('chore.template.laundry'));
    await tester.ensureVisible(laundry);
    await tester.tap(laundry);
    await tester.pumpAndSettle();
    expect(find.text('반복 요일'), findsOneWidget);
    expect(find.text('목요일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('templates fit 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );
    final Finder create = find.byKey(const Key('today.createChore'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    final Finder template = find.byKey(const Key('chore.template.laundry'));
    final Finder search = find.byKey(const Key('chore.template.search'));
    final Finder category = find.byKey(
      const Key('chore.template.category.all'),
    );
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    expect(tester.getSize(category).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(template);
    await tester.tap(template);
    await tester.pumpAndSettle();

    final Finder weekday = find.byKey(
      const Key('chore.create.recurrence.weekday.TH'),
    );
    await tester.ensureVisible(weekday);
    await tester.pumpAndSettle();

    final Finder interval = find.byKey(
      const Key('chore.create.recurrence.interval'),
    );
    final Finder end = find.byKey(const Key('chore.create.recurrence.end'));
    await tester.ensureVisible(interval);
    await tester.pumpAndSettle();
    expect(tester.getSize(interval).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(end);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.getSize(template).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(weekday).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(end).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation form persists a daily chore and labels Today', (
    WidgetTester tester,
  ) async {
    ChoreOccurrence? created;
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: created == null
              ? const <ChoreOccurrence>[]
              : <ChoreOccurrence>[created!],
        ),
      ),
      recurringCallback: (CreateRecurringChoreRequest request) async {
        created = choreOccurrenceFixture(
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId,
          dueLocalDate: request.startLocalDate,
          dueLocalTime: request.dueLocalTime,
          recurrenceFrequency: request.recurrenceRule.frequency,
        );
        return RecurringChoreCreated(
          RecurringChoreSnapshot(
            householdId: request.householdId,
            seriesId: created!.seriesId,
            firstOccurrenceId: created!.id,
            recurrenceRule: request.recurrenceRule,
            materializedThrough: request.startLocalDate,
            materializedCount: 1,
            created: true,
          ),
        );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chore.create.recurrence.summary')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Daily kitchen reset',
    );
    await tester.ensureVisible(find.byKey(const Key('chore.create.submit')));
    await tester.tap(find.byKey(const Key('chore.create.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.list')), findsOneWidget);
    expect(find.text('Daily kitchen reset'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    expect(choreRepository.createRequests, isEmpty);
    expect(choreRepository.recurringRequests, hasLength(1));
    expect(
      choreRepository.recurringRequests.single.recurrenceRule.toJson(),
      <String, Object?>{
        'frequency': 'daily',
        'interval': 1,
        'end': <String, Object?>{'type': 'never'},
      },
    );
  });

  testWidgets('creation form persists a bounded fortnightly chore', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Fortnightly recycling',
    );
    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();

    final Finder thursday = find.byKey(
      const Key('chore.create.recurrence.weekday.TH'),
    );
    expect(tester.widget<FilterChip>(thursday).selected, isTrue);
    expect(tester.widget<FilterChip>(thursday).onSelected, isNull);
    for (final String weekday in <String>['SA', 'MO']) {
      final Finder chip = find.byKey(
        Key('chore.create.recurrence.weekday.$weekday'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(find.text('On Monday, Thursday, Saturday.'), findsOneWidget);

    final Finder interval = find.byKey(
      const Key('chore.create.recurrence.interval'),
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '2');
    final Finder end = find.byKey(const Key('chore.create.recurrence.end'));
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    final Finder count = find.byKey(const Key('chore.create.recurrence.count'));
    await tester.ensureVisible(count);
    await tester.enterText(count, '6');
    await tester.pump();
    expect(find.textContaining('Every 2 weeks'), findsOneWidget);
    expect(find.text('Ends after 6 occurrences.'), findsOneWidget);

    final Finder submit = find.byKey(const Key('chore.create.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(choreRepository.recurringRequests, hasLength(1));
    expect(
      choreRepository.recurringRequests.single.recurrenceRule.toJson(),
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <String>['MO', 'TH', 'SA'],
        'end': <String, Object?>{'type': 'count', 'count': 6},
      },
    );
  });

  testWidgets('monthly creation derives its locked day from the due date', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Monthly filter change',
    );
    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month').last);
    await tester.pumpAndSettle();

    final Finder monthDay = find.byKey(
      const Key('chore.create.recurrence.monthDay'),
    );
    Finder monthDayDropdown() => find.descendant(
      of: monthDay,
      matching: find.byType(DropdownButtonFormField<int>),
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(monthDayDropdown()).onChanged,
      isNull,
    );
    expect(find.text('Day 6'), findsOneWidget);
    expect(find.text('The first due date sets this day.'), findsOneWidget);
    expect(
      find.text(
        'Months without this date are skipped, not moved to the last day.',
      ),
      findsOneWidget,
    );
    expect(find.text('On day 6 of the month.'), findsOneWidget);

    final Finder date = find.byKey(const Key('chore.create.date'));
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Day 8'), findsOneWidget);
    expect(find.text('On day 8 of the month.'), findsOneWidget);
    final Finder submit = find.byKey(const Key('chore.create.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(choreRepository.recurringRequests, hasLength(1));
    final CreateRecurringChoreRequest request =
        choreRepository.recurringRequests.single;
    expect(request.startLocalDate.value, '2026-08-08');
    expect(request.recurrenceRule.toJson(), <String, Object?>{
      'frequency': 'monthly',
      'interval': 1,
      'monthDay': 8,
      'end': <String, Object?>{'type': 'never'},
    });
  });

  testWidgets(
    'creation date adds a new weekday anchor and unlocks the old one',
    (WidgetTester tester) async {
      final FakeChoreRepository choreRepository = FakeChoreRepository();
      await _pumpChoreApp(tester, choreRepository: choreRepository);

      await tester.tap(find.byKey(const Key('today.createChore')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chore.create.title')),
        'Multi-day recycling',
      );
      final Finder repeat = find.byKey(const Key('chore.create.repeat'));
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week').last);
      await tester.pumpAndSettle();
      final Finder monday = find.byKey(
        const Key('chore.create.recurrence.weekday.MO'),
      );
      await tester.ensureVisible(monday);
      await tester.tap(monday);
      await tester.pumpAndSettle();

      final Finder date = find.byKey(const Key('chore.create.date'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('8').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final Finder thursday = find.byKey(
        const Key('chore.create.recurrence.weekday.TH'),
      );
      final Finder saturday = find.byKey(
        const Key('chore.create.recurrence.weekday.SA'),
      );
      expect(tester.widget<FilterChip>(thursday).selected, isTrue);
      expect(tester.widget<FilterChip>(thursday).onSelected, isNotNull);
      expect(tester.widget<FilterChip>(saturday).selected, isTrue);
      expect(tester.widget<FilterChip>(saturday).onSelected, isNull);
      await tester.ensureVisible(thursday);
      await tester.tap(thursday);
      await tester.pumpAndSettle();

      final Finder submit = find.byKey(const Key('chore.create.submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(choreRepository.recurringRequests, hasLength(1));
      expect(
        choreRepository.recurringRequests.single.recurrenceRule.weekdays,
        const <ChoreWeekday>[ChoreWeekday.monday, ChoreWeekday.saturday],
      );
      expect(
        choreRepository.recurringRequests.single.startLocalDate.value,
        '2026-08-08',
      );
    },
  );

  testWidgets('creation date keeps an until rule valid and household-local', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Short daily reset',
    );
    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day').last);
    await tester.pumpAndSettle();
    final Finder end = find.byKey(const Key('chore.create.recurrence.end'));
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On a date').last);
    await tester.pumpAndSettle();

    final Finder date = find.byKey(const Key('chore.create.date'));
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final Finder submit = find.byKey(const Key('chore.create.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(choreRepository.recurringRequests, hasLength(1));
    final CreateRecurringChoreRequest request =
        choreRepository.recurringRequests.single;
    expect(request.startLocalDate.value, '2026-08-08');
    expect(request.recurrenceRule.end.toJson(), <String, Object?>{
      'type': 'until',
      'localDate': '2026-08-08',
    });
  });

  testWidgets('advanced recurrence validation blocks repository access', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository choreRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.createChore')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chore.create.title')),
      'Invalid schedule',
    );
    final Finder repeat = find.byKey(const Key('chore.create.repeat'));
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day').last);
    await tester.pumpAndSettle();

    final Finder interval = find.byKey(
      const Key('chore.create.recurrence.interval'),
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '31');
    final Finder submit = find.byKey(const Key('chore.create.submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Enter a number from 1 to 30.'), findsOneWidget);
    expect(choreRepository.recurringRequests, isEmpty);

    await tester.enterText(interval, '2');
    final Finder end = find.byKey(const Key('chore.create.recurrence.end'));
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    final Finder count = find.byKey(const Key('chore.create.recurrence.count'));
    await tester.ensureVisible(count);
    await tester.enterText(count, '1001');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Enter a number from 1 to 1,000.'), findsOneWidget);
    expect(choreRepository.recurringRequests, isEmpty);
  });

  testWidgets('Today edits every field of a scheduled one-time chore', (
    WidgetTester tester,
  ) async {
    ChoreOccurrence current = choreOccurrenceFixture(
      title: 'Take out recycling',
      description: 'Blue bin',
      dueLocalTime: ChoreLocalTime.tryParse('19:30'),
      dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
      version: 7,
      seriesVersion: 4,
    );
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      oneTimeUpdateCallback: (UpdateOneTimeChoreRequest request) async {
        current = choreOccurrenceFixture(
          occurrenceId: current.id.value,
          seriesId: current.seriesId.value,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId,
          assigneeDisplayName: 'Alex',
          dueLocalDate: request.dueLocalDate,
          dueLocalTime: request.dueLocalTime,
          dueAt: request.dueLocalTime == null
              ? null
              : DateTime.parse('2026-08-06T10:30:00Z'),
          version: request.expectedOccurrenceVersion + 1,
          seriesVersion: request.expectedSeriesVersion + 1,
        );
        return OneTimeChoreUpdated(
          OneTimeChoreUpdateSnapshot(
            householdId: request.householdId,
            seriesId: request.seriesId,
            occurrenceId: request.occurrenceId,
            revisionId: ChoreRevisionId.tryParse(
              '77777777-7777-4777-8777-777777777777',
            )!,
            revisionNumber: request.expectedSeriesVersion + 1,
            dueLocalDate: request.dueLocalDate,
            dueLocalTime: request.dueLocalTime,
            dueAt: request.dueLocalTime == null
                ? null
                : DateTime.parse('2026-08-06T10:30:00Z'),
            assigneeMemberId: request.assigneeMemberId,
            seriesVersion: request.expectedSeriesVersion + 1,
            occurrenceVersion: request.expectedOccurrenceVersion + 1,
            changed: true,
          ),
        );
      },
    );
    final _ChoreHarness harness = await _pumpChoreApp(
      tester,
      choreRepository: choreRepository,
    );

    await tester.tap(find.byKey(Key('today.chore.menu.${current.id.value}')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('today.oneTime.edit.menuItem')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('today.oneTime.delete.menuItem')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today.reschedule.menuItem')), findsNothing);
    await tester.tap(find.byKey(const Key('today.oneTime.edit.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.oneTime.edit.dialog')), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('today.oneTime.edit.title')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Take out recycling',
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('today.oneTime.edit.description')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Blue bin',
    );
    expect(find.text('Alex (you)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('today.oneTime.edit.confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('today.oneTime.edit.title')),
      '  Updated recycling  ',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('today.oneTime.edit.confirm')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(
      find.byKey(const Key('today.oneTime.edit.confirm')),
    );
    await tester.tap(find.byKey(const Key('today.oneTime.edit.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Updated recycling'), findsOneWidget);
    expect(find.text('Blue bin'), findsOneWidget);
    expect(find.text('The one-time chore was updated.'), findsOneWidget);
    expect(choreRepository.oneTimeUpdateRequests, hasLength(1));
    final UpdateOneTimeChoreRequest request =
        choreRepository.oneTimeUpdateRequests.single;
    expect(request.title, 'Updated recycling');
    expect(request.description, 'Blue bin');
    expect(request.expectedSeriesVersion, 4);
    expect(request.expectedOccurrenceVersion, 7);
    expect(request.dueLocalTime?.value, '19:30');
    expect(harness.memberRepository.loadedHouseholds, hasLength(1));
  });

  testWidgets('Today confirms before deleting a scheduled one-time chore', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'One-time errand',
      version: 3,
      seriesVersion: 2,
    );
    final ChoreOccurrence restoredOccurrence = choreOccurrenceFixture(
      occurrenceId: occurrence.id.value,
      seriesId: occurrence.seriesId.value,
      title: occurrence.title,
      version: 5,
      seriesVersion: 4,
    );
    var deleted = false;
    var restored = false;
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: deleted
              ? const <ChoreOccurrence>[]
              : <ChoreOccurrence>[restored ? restoredOccurrence : occurrence],
        ),
      ),
      oneTimeDeletionCallback: (DeleteOneTimeChoreRequest request) async {
        deleted = true;
        return OneTimeChoreDeleted(
          OneTimeChoreDeletionSnapshot(
            householdId: request.householdId,
            seriesId: request.seriesId,
            occurrenceId: request.occurrenceId,
            seriesVersion: request.expectedSeriesVersion + 1,
            occurrenceVersion: request.expectedOccurrenceVersion + 1,
            changed: true,
          ),
        );
      },
      oneTimeRestoreCallback: (RestoreOneTimeChoreRequest request) async {
        deleted = false;
        restored = true;
        return OneTimeChoreRestored(
          OneTimeChoreRestoreSnapshot(
            householdId: request.householdId,
            seriesId: request.seriesId,
            occurrenceId: request.occurrenceId,
            seriesVersion: request.expectedSeriesVersion + 1,
            occurrenceVersion: request.expectedOccurrenceVersion + 1,
            changed: true,
          ),
        );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);
    final Finder menu = find.byKey(
      Key('today.chore.menu.${occurrence.id.value}'),
    );

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.oneTime.delete.menuItem')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('today.oneTime.delete.dialog')),
      findsOneWidget,
    );
    expect(
      find.text(
        'It will be removed from chore lists. Its protected history will be kept.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('today.oneTime.delete.dismiss')));
    await tester.pumpAndSettle();
    expect(choreRepository.oneTimeDeletionRequests, isEmpty);
    expect(find.text('One-time errand'), findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.oneTime.delete.menuItem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.oneTime.delete.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('One-time errand'), findsNothing);
    expect(find.text('The one-time chore was deleted.'), findsOneWidget);
    expect(choreRepository.oneTimeDeletionRequests, hasLength(1));
    final DeleteOneTimeChoreRequest request =
        choreRepository.oneTimeDeletionRequests.single;
    expect(request.seriesId, occurrence.seriesId);
    expect(request.expectedSeriesVersion, 2);
    expect(request.expectedOccurrenceVersion, 3);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('One-time errand'), findsOneWidget);
    expect(find.text('The deleted chore was restored.'), findsOneWidget);
    expect(choreRepository.oneTimeRestoreRequests, hasLength(1));
    final RestoreOneTimeChoreRequest restoreRequest =
        choreRepository.oneTimeRestoreRequests.single;
    expect(restoreRequest.expectedSeriesVersion, 3);
    expect(restoreRequest.expectedOccurrenceVersion, 4);
  });

  testWidgets('Recently deleted chores opens, restores, and reloads empty', (
    WidgetTester tester,
  ) async {
    final DeletedOneTimeChore item = DeletedOneTimeChore.tryCreate(
      householdId: activeHouseholdFixture().householdId,
      seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444499')!,
      occurrenceId: ChoreOccurrenceId.tryParse(
        '55555555-5555-4555-8555-555555555599',
      )!,
      title: 'Return library books',
      description: 'Front desk',
      assigneeMemberId: activeHouseholdFixture().memberId,
      assigneeDisplayName: 'Alex',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-09')!,
      dueLocalTime: ChoreLocalTime.tryParse('19:30'),
      dueAt: DateTime.parse('2026-08-09T10:30:00Z'),
      deletedAt: DateTime.parse('2026-08-09T11:00:00Z'),
      seriesVersion: 2,
      occurrenceVersion: 2,
    )!;
    final FakeChoreRepository repository = FakeChoreRepository(
      deletedOneTimeChoresResults: <LoadDeletedOneTimeChoresResult>[
        DeletedOneTimeChoresLoaded(
          DeletedOneTimeChorePage.tryCreate(
            householdId: activeHouseholdFixture().householdId,
            householdTimezone: 'Asia/Seoul',
            generatedAt: DateTime.parse('2026-08-09T11:30:00Z'),
            pageLimit: 30,
            hasMore: false,
            nextCursor: null,
            items: <DeletedOneTimeChore>[item],
          )!,
        ),
        DeletedOneTimeChoresLoaded(
          DeletedOneTimeChorePage.tryCreate(
            householdId: activeHouseholdFixture().householdId,
            householdTimezone: 'Asia/Seoul',
            generatedAt: DateTime.parse('2026-08-09T11:31:00Z'),
            pageLimit: 30,
            hasMore: false,
            nextCursor: null,
            items: const <DeletedOneTimeChore>[],
          )!,
        ),
      ],
    );
    await _pumpChoreApp(tester, choreRepository: repository);

    await tester.tap(find.byKey(const Key('today.trash')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('choreTrash.screen')), findsOneWidget);
    expect(find.text('Recently deleted chores'), findsOneWidget);
    expect(find.text('Return library books'), findsOneWidget);
    expect(find.text('Assigned to Alex'), findsOneWidget);

    await tester.tap(
      find.byKey(Key('choreTrash.restore.${item.occurrenceId.value}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return library books'), findsNothing);
    expect(find.text('No recently deleted chores'), findsOneWidget);
    expect(find.text('The one-time chore was restored.'), findsOneWidget);
    expect(repository.oneTimeRestoreRequests, hasLength(1));
  });

  testWidgets('empty trash fits compact 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(find.byKey(const Key('today.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.trash')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('choreTrash.empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one-time lifecycle dialogs fit compact 200 percent pseudo text',
    (WidgetTester tester) async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        title: 'Compact one-time chore',
        description: 'A short editable note',
      );
      await _pumpChoreApp(
        tester,
        choreRepository: FakeChoreRepository(
          today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        ),
        locale: const Locale('en', 'XA'),
        size: const Size(320, 568),
        textScaleFactor: 2,
      );
      final Finder menu = find.byKey(
        Key('today.chore.menu.${occurrence.id.value}'),
      );
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today.oneTime.edit.menuItem')));
      await tester.pumpAndSettle();

      final Finder editDialog = find.byKey(
        const Key('today.oneTime.edit.dialog'),
      );
      final Finder editConfirm = find.byKey(
        const Key('today.oneTime.edit.confirm'),
      );
      expect(editDialog, findsOneWidget);
      expect(
        find.descendant(
          of: editDialog,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(editConfirm);
      await tester.pumpAndSettle();
      expect(tester.getSize(editConfirm).height, greaterThanOrEqualTo(48));
      final Finder editCancel = find.byKey(
        const Key('today.oneTime.edit.cancel'),
      );
      await tester.ensureVisible(editCancel);
      await tester.pumpAndSettle();
      await tester.tap(editCancel);
      await tester.pumpAndSettle();

      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final Finder deleteMenuItem = find.byKey(
        const Key('today.oneTime.delete.menuItem'),
      );
      await tester.ensureVisible(deleteMenuItem);
      await tester.pumpAndSettle();
      await tester.tap(deleteMenuItem);
      await tester.pumpAndSettle();
      final Finder deleteDialog = find.byKey(
        const Key('today.oneTime.delete.dialog'),
      );
      final Finder deleteConfirm = find.byKey(
        const Key('today.oneTime.delete.confirm'),
      );
      expect(deleteDialog, findsOneWidget);
      expect(
        find.descendant(
          of: deleteDialog,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(deleteConfirm);
      await tester.pumpAndSettle();
      expect(tester.getSize(deleteConfirm).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Today reschedules only one recurring occurrence to all day', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence recurring = choreOccurrenceFixture(
      title: 'Timed kitchen reset',
      dueLocalTime: ChoreLocalTime.tryParse('19:30'),
      dueAt: DateTime.parse('2026-08-06T10:30:00Z'),
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[recurring]),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(Key('today.chore.menu.${recurring.id.value}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.reschedule.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.reschedule.dialog')), findsOneWidget);
    expect(find.text('Reschedule this occurrence'), findsOneWidget);
    expect(
      find.text(
        'Only this date changes. The repeating schedule and every other '
        'occurrence will stay unchanged.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('today.reschedule.confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('today.reschedule.clearTime')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('today.reschedule.confirm')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('today.reschedule.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Timed kitchen reset'), findsOneWidget);
    expect(find.text('Alex · Any time'), findsOneWidget);
    expect(find.text('This occurrence was rescheduled.'), findsOneWidget);
    expect(choreRepository.rescheduleRequests, hasLength(1));
    expect(
      choreRepository.rescheduleRequests.single.occurrenceId,
      recurring.id,
    );
    expect(
      choreRepository.rescheduleRequests.single.dueLocalDate,
      recurring.dueLocalDate,
    );
    expect(choreRepository.rescheduleRequests.single.dueLocalTime, isNull);
    expect(choreRepository.rescheduleRequests.single.expectedVersion, 1);
  });

  testWidgets('Today reassigns only the selected recurring occurrence', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence selected = choreOccurrenceFixture(
      title: 'Selected kitchen reset',
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final ChoreOccurrence sibling = choreOccurrenceFixture(
      occurrenceId: '66666666-6666-4666-8666-666666666666',
      title: 'Sibling kitchen reset',
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(
        occurrences: <ChoreOccurrence>[selected, sibling],
      ),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(Key('today.chore.menu.${selected.id.value}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.reassign.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.reassign.dialog')), findsOneWidget);
    expect(find.text("Change this occurrence's assignee"), findsOneWidget);
    expect(
      find.text(
        'Only this occurrence changes. The repeating schedule and every other '
        'occurrence will keep their assignee.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('today.reassign.confirm')))
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(
        const Key('today.reassign.member.33333333-3333-4333-8333-333333333334'),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('today.reassign.confirm')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('today.reassign.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Selected kitchen reset'), findsOneWidget);
    expect(find.text('Sibling kitchen reset'), findsOneWidget);
    expect(find.text('Sam · Any time'), findsOneWidget);
    expect(find.text('Alex · Any time'), findsOneWidget);
    expect(find.text('This occurrence was reassigned.'), findsOneWidget);
    expect(choreRepository.reassignmentRequests, hasLength(1));
    expect(
      choreRepository.reassignmentRequests.single.occurrenceId,
      selected.id,
    );
    expect(
      choreRepository.reassignmentRequests.single.assigneeMemberId,
      householdMemberIdFixture('33333333-3333-4333-8333-333333333334'),
    );
    expect(choreRepository.reassignmentRequests.single.expectedVersion, 1);
  });

  testWidgets('Today reports roster load failure before reassignment', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence recurring = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[recurring]),
    );
    final FakeHouseholdMemberRepository memberRepository =
        FakeHouseholdMemberRepository(
          loadResults: const <LoadHouseholdMemberRosterResult>[
            LoadHouseholdMemberRosterFailed(
              HouseholdMemberFailure(
                HouseholdMemberFailureKind.temporarilyUnavailable,
              ),
            ),
          ],
        );
    await _pumpChoreApp(
      tester,
      choreRepository: choreRepository,
      memberRepository: memberRepository,
    );

    await tester.tap(find.byKey(Key('today.chore.menu.${recurring.id.value}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.reassign.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.reassign.dialog')), findsNothing);
    expect(
      find.text('Household members could not be loaded. Try again.'),
      findsOneWidget,
    );
    expect(memberRepository.loadedHouseholds, hasLength(1));
    expect(choreRepository.reassignmentRequests, isEmpty);
  });

  testWidgets(
    'Today skips one recurring occurrence and immediately restores with Undo',
    (WidgetTester tester) async {
      final ChoreOccurrence recurring = choreOccurrenceFixture(
        title: 'Daily kitchen reset',
        recurrenceFrequency: ChoreRecurrenceFrequency.daily,
      );
      final ChoreOccurrence oneTime = choreOccurrenceFixture(
        occurrenceId: '66666666-6666-4666-8666-666666666666',
        seriesId: '77777777-7777-4777-8777-777777777777',
        title: 'One-time errand',
      );
      final ChoreOccurrence completedRecurring = choreOccurrenceFixture(
        occurrenceId: '88888888-8888-4888-8888-888888888888',
        seriesId: '99999999-9999-4999-8999-999999999999',
        title: 'Completed repeat',
        status: ChoreOccurrenceStatus.completed,
        version: 2,
        recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
      );
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        today: todayChoresFixture(
          occurrences: <ChoreOccurrence>[
            recurring,
            oneTime,
            completedRecurring,
          ],
        ),
      );
      await _pumpChoreApp(tester, choreRepository: choreRepository);
      final Finder menu = find.byKey(
        Key('today.chore.menu.${recurring.id.value}'),
      );

      expect(menu, findsOneWidget);
      expect(
        find.byKey(Key('today.chore.menu.${oneTime.id.value}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('today.chore.menu.${completedRecurring.id.value}')),
        findsNothing,
      );

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip this occurrence'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('today.skip.dialog')), findsOneWidget);
      expect(
        find.text(
          'This date will be skipped. The repeating schedule and every other '
          'occurrence will stay unchanged.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('today.skip.cancel')));
      await tester.pumpAndSettle();
      expect(choreRepository.skipRequests, isEmpty);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip this occurrence'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today.skip.confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Daily kitchen reset'), findsNothing);
      expect(find.text('One-time errand'), findsOneWidget);
      expect(find.text('Completed repeat'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('today.completed.toggle')),
      );
      await tester.tap(find.byKey(const Key('today.completed.toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Completed repeat'), findsOneWidget);
      expect(find.text('This occurrence was skipped.'), findsOneWidget);
      final Finder undo = find.byKey(const Key('today.skip.undo'));
      expect(undo, findsOneWidget);
      expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
      expect(choreRepository.skipRequests, hasLength(1));
      expect(choreRepository.skipRequests.single.occurrenceId, recurring.id);
      expect(choreRepository.skipRequests.single.expectedVersion, 1);

      await tester.tap(undo);
      await tester.pumpAndSettle();

      expect(find.text('Daily kitchen reset'), findsOneWidget);
      expect(find.text('One-time errand'), findsOneWidget);
      expect(find.text('Completed repeat'), findsOneWidget);
      expect(find.text('This occurrence is back on Today.'), findsOneWidget);
      expect(choreRepository.restoreRequests, hasLength(1));
      expect(choreRepository.restoreRequests.single.occurrenceId, recurring.id);
      expect(choreRepository.restoreRequests.single.expectedVersion, 2);
    },
  );

  testWidgets('failed Undo stays retryable with the same restore command', (
    WidgetTester tester,
  ) async {
    var restoreAttempts = 0;
    final ChoreOccurrence recurring = choreOccurrenceFixture(
      title: 'Retry weekly reset',
      recurrenceFrequency: ChoreRecurrenceFrequency.weekly,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[recurring]),
      restoreCallback: (RestoreSkippedChoreOccurrenceRequest request) async {
        restoreAttempts += 1;
        return restoreAttempts == 1
            ? const RestoreSkippedChoreOccurrenceFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              )
            : ChoreOccurrenceRestored(_restoreSnapshot(request));
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(Key('today.chore.menu.${recurring.id.value}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this occurrence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.skip.confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.skip.undo')));
    await tester.pumpAndSettle();

    expect(find.text('Retry weekly reset'), findsNothing);
    expect(find.byKey(const Key('today.actionError')), findsOneWidget);
    expect(find.text('This occurrence could not be restored.'), findsOneWidget);
    expect(find.byKey(const Key('today.skip.undo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today.skip.undo')));
    await tester.pumpAndSettle();

    expect(find.text('Retry weekly reset'), findsOneWidget);
    expect(find.text('This occurrence is back on Today.'), findsOneWidget);
    expect(choreRepository.restoreRequests, hasLength(2));
    expect(
      choreRepository.restoreRequests.first.idempotencyKey,
      choreRepository.restoreRequests.last.idempotencyKey,
    );
  });

  testWidgets('Today edits a manageable repeating series from today', (
    WidgetTester tester,
  ) async {
    ChoreOccurrence current = _manageableSeriesOccurrence();
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      seriesUpdateCallback: (UpdateRepeatingChoreSeriesRequest request) async {
        current = choreOccurrenceFixture(
          occurrenceId: current.id.value,
          seriesId: current.seriesId.value,
          title: request.title,
          description: request.description,
          assigneeMemberId: request.assigneeMemberId,
          assigneeDisplayName:
              request.assigneeMemberId ==
                  householdMemberIdFixture(
                    '33333333-3333-4333-8333-333333333334',
                  )
              ? 'Sam'
              : 'Alex',
          dueLocalTime: request.dueLocalTime,
          dueAt: request.dueLocalTime == null
              ? null
              : DateTime.parse('2026-08-06T11:00:00Z'),
          recurrenceFrequency: request.recurrenceRule.frequency,
          seriesVersion: request.expectedVersion + 1,
          seriesDefaultAssigneeMemberId: request.assigneeMemberId,
          seriesDueLocalTime: request.dueLocalTime,
          recurrenceRule: request.recurrenceRule,
          canManageSeries: true,
        );
        return RepeatingChoreSeriesUpdated(_seriesUpdateSnapshot(request));
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today.series.edit.menuItem')), findsOneWidget);
    expect(
      find.byKey(const Key('today.series.cancel.menuItem')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('today.series.edit.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.series.edit.dialog')), findsOneWidget);
    expect(
      find.text(
        'Changes apply from today in the household time zone. Past '
        'occurrences and completed chores stay unchanged.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today.series.edit.assignee')), findsOneWidget);
    expect(
      find.byKey(const Key('today.series.edit.recurrence')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('today.series.edit.confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('today.series.edit.title')),
      '  Weekly recycling  ',
    );
    await tester.tap(find.byKey(const Key('today.series.edit.recurrence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();
    final Finder monday = find.byKey(
      const Key('today.series.edit.advancedRecurrence.weekday.MO'),
    );
    await tester.ensureVisible(monday);
    await tester.tap(monday);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('today.series.edit.recurrence')),
    );
    await tester.tap(find.byKey(const Key('today.series.edit.recurrence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('today.series.edit.recurrence')),
    );
    await tester.tap(find.byKey(const Key('today.series.edit.recurrence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every week').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(monday).selected, isTrue);
    final Finder interval = find.byKey(
      const Key('today.series.edit.advancedRecurrence.interval'),
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '2');
    final Finder end = find.byKey(
      const Key('today.series.edit.advancedRecurrence.end'),
    );
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On a date').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('today.series.edit.advancedRecurrence.until')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('today.series.edit.confirm')),
    );
    await tester.tap(find.byKey(const Key('today.series.edit.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Weekly recycling'), findsOneWidget);
    expect(find.text('Every week'), findsOneWidget);
    expect(
      find.text('The repeating series was updated from today.'),
      findsOneWidget,
    );
    expect(choreRepository.seriesUpdateRequests, hasLength(1));
    final UpdateRepeatingChoreSeriesRequest request =
        choreRepository.seriesUpdateRequests.single;
    expect(request.title, 'Weekly recycling');
    expect(request.expectedVersion, 1);
    expect(request.effectiveLocalDate.value, '2026-08-06');
    expect(request.recurrenceRule.frequency, ChoreRecurrenceFrequency.weekly);
    expect(request.recurrenceRule.interval, 2);
    expect(request.recurrenceRule.weekdays, <ChoreWeekday>[
      ChoreWeekday.monday,
      ChoreWeekday.thursday,
    ]);
    expect(request.recurrenceRule.end.toJson(), <String, Object?>{
      'type': 'until',
      'localDate': '2026-08-06',
    });
  });

  testWidgets(
    'Upcoming edits a repeating series from the selected occurrence',
    (WidgetTester tester) async {
      ChoreOccurrence current = _manageableSeriesOccurrence(
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
      );
      late final FakeChoreRepository choreRepository;
      choreRepository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? <ChoreOccurrence>[current]
                : const <ChoreOccurrence>[],
            view: request.view,
            assigneeFilterMemberId: request.assigneeMemberId,
            pageLimit: request.limit,
          ),
        ),
        seriesFromOccurrenceUpdateCallback:
            (UpdateRepeatingChoreSeriesFromOccurrenceRequest request) async {
              current = choreOccurrenceFixture(
                occurrenceId: current.id.value,
                seriesId: current.seriesId.value,
                title: request.title,
                description: request.description,
                assigneeMemberId: request.assigneeMemberId,
                assigneeDisplayName: 'Alex',
                dueLocalDate: current.dueLocalDate,
                dueLocalTime: request.dueLocalTime,
                dueAt: request.dueLocalTime == null
                    ? null
                    : DateTime.parse('2026-08-12T11:00:00Z'),
                recurrenceFrequency: request.recurrenceRule.frequency,
                seriesVersion: request.expectedVersion + 1,
                seriesDefaultAssigneeMemberId: request.assigneeMemberId,
                seriesDueLocalTime: request.dueLocalTime,
                recurrenceRule: request.recurrenceRule,
                canManageSeries: true,
              );
              return RepeatingChoreSeriesUpdated(
                _seriesFromOccurrenceUpdateSnapshot(
                  request,
                  current.dueLocalDate,
                ),
              );
            },
      );
      await _pumpChoreApp(tester, choreRepository: choreRepository);

      await tester.tap(find.byKey(const Key('today.view.upcoming')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('today.chore.menu.${current.id.value}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('today.series.editFromOccurrence.menuItem')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('today.series.editFromOccurrence.menuItem')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit this and later occurrences'), findsOneWidget);
      expect(
        find.text(
          'The selected occurrence and later incomplete chores will use the '
          'new series settings. Earlier and completed chores stay unchanged. '
          'Later incomplete one-occurrence adjustments may reset to the new '
          'defaults.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('today.series.edit.title')),
        'Future recycling plan',
      );
      await tester.pump();
      final Finder confirm = find.byKey(const Key('today.series.edit.confirm'));
      await tester.ensureVisible(confirm);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Future recycling plan'), findsOneWidget);
      expect(
        find.text(
          'The repeating series was updated from the selected occurrence.',
        ),
        findsOneWidget,
      );
      expect(choreRepository.seriesFromOccurrenceUpdateRequests, hasLength(1));
      final UpdateRepeatingChoreSeriesFromOccurrenceRequest request =
          choreRepository.seriesFromOccurrenceUpdateRequests.single;
      expect(request.effectiveOccurrenceId.value, current.id.value);
      expect(request.title, 'Future recycling plan');
      expect(choreRepository.seriesUpdateRequests, isEmpty);
      expect(choreRepository.listRequests.last.view, ChoreListView.upcoming);
    },
  );

  testWidgets('selected-occurrence series edit localizes in Korean', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
    );
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? <ChoreOccurrence>[current]
                : const <ChoreOccurrence>[],
            view: request.view,
            pageLimit: request.limit,
          ),
        ),
      ),
      locale: const Locale('ko'),
    );

    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('today.chore.menu.${current.id.value}')));
    await tester.pumpAndSettle();
    expect(find.text('이 회차부터 수정'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('today.series.editFromOccurrence.menuItem')),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 회차와 이후 회차 수정'), findsOneWidget);
    expect(
      find.text(
        '선택한 회차와 이후 미완료 집안일에 새 시리즈 설정을 적용합니다. '
        '이전 회차와 완료한 집안일은 그대로 유지됩니다. 이후 미완료 회차에 '
        '따로 적용한 조정은 새 기본값으로 초기화될 수 있습니다.',
      ),
      findsOneWidget,
    );
    final Finder cancel = find.byKey(const Key('today.series.edit.cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
  });

  testWidgets('selected-occurrence dialog fits compact pseudo text', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
    );
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? <ChoreOccurrence>[current]
                : const <ChoreOccurrence>[],
            view: request.view,
            pageLimit: request.limit,
          ),
        ),
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();
    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder editFromOccurrence = find.byKey(
      const Key('today.series.editFromOccurrence.menuItem'),
    );
    await tester.ensureVisible(editFromOccurrence);
    await tester.tap(editFromOccurrence);
    await tester.pumpAndSettle();

    final Finder dialog = find.byKey(const Key('today.series.edit.dialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final Finder cancel = find.byKey(const Key('today.series.edit.cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
  });

  testWidgets('Upcoming cancels a series from the selected occurrence', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence retained = _manageableSeriesOccurrence(
      occurrenceId: '55555555-5555-4555-8555-555555555554',
      title: 'Retained recycling',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-10'),
    );
    final ChoreOccurrence target = _manageableSeriesOccurrence(
      title: 'Future recycling',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
    );
    var cancelled = false;
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: request.view == ChoreListView.upcoming
              ? cancelled
                    ? <ChoreOccurrence>[retained]
                    : <ChoreOccurrence>[retained, target]
              : const <ChoreOccurrence>[],
          view: request.view,
          assigneeFilterMemberId: request.assigneeMemberId,
          pageLimit: request.limit,
        ),
      ),
      seriesFromOccurrenceCancellationCallback:
          (CancelRepeatingChoreSeriesFromOccurrenceRequest request) async {
            cancelled = true;
            return RepeatingChoreSeriesCancelledFromOccurrence(
              RepeatingChoreSeriesFromOccurrenceCancellationSnapshot(
                householdId: request.householdId,
                seriesId: request.seriesId,
                effectiveLocalDate: target.dueLocalDate,
                version: request.expectedVersion + 1,
                cancelledCount: 19,
                preservedCompletedCount: 2,
                terminalRevisionId: ChoreRevisionId.tryParse(
                  '77777777-7777-4777-8777-777777777778',
                ),
                terminalRevisionNumber: request.expectedVersion + 1,
                changed: true,
              ),
            );
          },
      seriesCancellationResumeCallback:
          (ResumeRepeatingChoreSeriesCancellationRequest request) async {
            cancelled = false;
            return RepeatingChoreSeriesCancellationResumed(
              RepeatingChoreSeriesCancellationResumeSnapshot(
                householdId: request.householdId,
                seriesId: request.seriesId,
                effectiveLocalDate: target.dueLocalDate,
                version: request.expectedVersion + 1,
                restoredCount: 19,
                preservedCompletedCount: 2,
                revisionId: ChoreRevisionId.tryParse(
                  '77777777-7777-4777-8777-777777777779',
                )!,
                revisionNumber: request.expectedVersion + 1,
                changed: true,
              ),
            );
          },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('today.chore.menu.${target.id.value}')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('today.series.cancelFromOccurrence.menuItem')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('today.series.cancelFromOccurrence.menuItem')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('today.series.cancelFromOccurrence.dialog')),
      findsOneWidget,
    );
    expect(find.text('Cancel this and later occurrences?'), findsOneWidget);
    expect(
      find.text(
        'The selected occurrence and later incomplete chores will be '
        'removed. Earlier occurrences and completed chores stay unchanged.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('today.series.cancelFromOccurrence.confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future recycling'), findsNothing);
    expect(find.text('Retained recycling'), findsOneWidget);
    expect(
      find.text(
        'The repeating series was cancelled from the selected occurrence.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('today.series.cancelFromOccurrence.undo')),
      findsOneWidget,
    );
    expect(
      choreRepository.seriesFromOccurrenceCancellationRequests,
      hasLength(1),
    );
    final CancelRepeatingChoreSeriesFromOccurrenceRequest request =
        choreRepository.seriesFromOccurrenceCancellationRequests.single;
    expect(request.effectiveOccurrenceId, target.id);
    expect(request.seriesId, target.seriesId);
    expect(request.expectedVersion, 1);
    expect(choreRepository.seriesCancellationRequests, isEmpty);
    expect(choreRepository.listRequests.last.view, ChoreListView.upcoming);

    await tester.tap(
      find.byKey(const Key('today.series.cancelFromOccurrence.undo')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future recycling'), findsOneWidget);
    expect(find.text('Retained recycling'), findsOneWidget);
    expect(find.text('The repeating series was restored.'), findsOneWidget);
    expect(choreRepository.seriesCancellationResumeRequests, hasLength(1));
    final ResumeRepeatingChoreSeriesCancellationRequest resumeRequest =
        choreRepository.seriesCancellationResumeRequests.single;
    expect(resumeRequest.seriesId, request.seriesId);
    expect(resumeRequest.cancellationIdempotencyKey, request.idempotencyKey);
    expect(resumeRequest.expectedVersion, 2);
  });

  testWidgets('selected-occurrence cancellation localizes in Korean', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence target = _manageableSeriesOccurrence(
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
    );
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? <ChoreOccurrence>[target]
                : const <ChoreOccurrence>[],
            view: request.view,
            pageLimit: request.limit,
          ),
        ),
      ),
      locale: const Locale('ko'),
    );

    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('today.chore.menu.${target.id.value}')));
    await tester.pumpAndSettle();
    expect(find.text('이 회차부터 취소'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('today.series.cancelFromOccurrence.menuItem')),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 회차와 이후 회차를 취소할까요?'), findsOneWidget);
    expect(
      find.text(
        '선택한 회차와 이후의 미완료 집안일을 제거합니다. 이전 회차와 완료한 '
        '집안일은 그대로 유지됩니다.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('today.series.cancel.dismiss')));
    await tester.pumpAndSettle();
  });

  testWidgets('selected cancellation fits compact pseudo text at 200%', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence target = _manageableSeriesOccurrence(
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-12'),
    );
    var cancelled = false;
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? cancelled
                      ? const <ChoreOccurrence>[]
                      : <ChoreOccurrence>[target]
                : const <ChoreOccurrence>[],
            view: request.view,
            pageLimit: request.limit,
          ),
        ),
        seriesFromOccurrenceCancellationCallback:
            (CancelRepeatingChoreSeriesFromOccurrenceRequest request) async {
              cancelled = true;
              return RepeatingChoreSeriesCancelledFromOccurrence(
                RepeatingChoreSeriesFromOccurrenceCancellationSnapshot(
                  householdId: request.householdId,
                  seriesId: request.seriesId,
                  effectiveLocalDate: target.dueLocalDate,
                  version: request.expectedVersion + 1,
                  cancelledCount: 19,
                  preservedCompletedCount: 2,
                  terminalRevisionId: ChoreRevisionId.tryParse(
                    '77777777-7777-4777-8777-777777777778',
                  ),
                  terminalRevisionNumber: request.expectedVersion + 1,
                  changed: true,
                ),
              );
            },
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();
    final Finder menu = find.byKey(Key('today.chore.menu.${target.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder selectedCancellation = find.byKey(
      const Key('today.series.cancelFromOccurrence.menuItem'),
    );
    await tester.ensureVisible(selectedCancellation);
    await tester.tap(selectedCancellation);
    await tester.pumpAndSettle();

    final Finder dialog = find.byKey(
      const Key('today.series.cancelFromOccurrence.dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final Finder confirm = find.byKey(
      const Key('today.series.cancelFromOccurrence.confirm'),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('today.series.cancelFromOccurrence.undo')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('series edit prefills and replaces weekly weekdays', (
    WidgetTester tester,
  ) async {
    final ChoreRecurrenceRule originalRule = ChoreRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 1,
        'weekdays': <String>['TH', 'SA'],
        'end': <String, Object?>{'type': 'never'},
      },
    )!;
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      recurrenceRule: originalRule,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      seriesUpdateCallback: (UpdateRepeatingChoreSeriesRequest request) async {
        return RepeatingChoreSeriesUpdated(_seriesUpdateSnapshot(request));
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder editMenuItem = find.byKey(
      const Key('today.series.edit.menuItem'),
    );
    await tester.ensureVisible(editMenuItem);
    await tester.tap(editMenuItem);
    await tester.pumpAndSettle();

    final Finder thursday = find.byKey(
      const Key('today.series.edit.advancedRecurrence.weekday.TH'),
    );
    final Finder saturday = find.byKey(
      const Key('today.series.edit.advancedRecurrence.weekday.SA'),
    );
    final Finder monday = find.byKey(
      const Key('today.series.edit.advancedRecurrence.weekday.MO'),
    );
    expect(tester.widget<FilterChip>(thursday).selected, isTrue);
    expect(tester.widget<FilterChip>(saturday).selected, isTrue);
    expect(tester.widget<FilterChip>(thursday).onSelected, isNotNull);
    await tester.ensureVisible(thursday);
    await tester.tap(thursday);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(saturday).onSelected, isNull);
    await tester.ensureVisible(monday);
    await tester.tap(monday);
    await tester.pumpAndSettle();
    expect(find.text('On Monday, Saturday.'), findsOneWidget);

    final Finder interval = find.byKey(
      const Key('today.series.edit.advancedRecurrence.interval'),
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '2');
    final Finder end = find.byKey(
      const Key('today.series.edit.advancedRecurrence.end'),
    );
    await tester.ensureVisible(end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    final Finder count = find.byKey(
      const Key('today.series.edit.advancedRecurrence.count'),
    );
    await tester.ensureVisible(count);
    await tester.enterText(count, '4');
    await tester.pump();
    final Finder confirm = find.byKey(const Key('today.series.edit.confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(choreRepository.seriesUpdateRequests, hasLength(1));
    final ChoreRecurrenceRule updated =
        choreRepository.seriesUpdateRequests.single.recurrenceRule;
    expect(updated.frequency, ChoreRecurrenceFrequency.weekly);
    expect(updated.interval, 2);
    expect(updated.weekdays, <ChoreWeekday>[
      ChoreWeekday.monday,
      ChoreWeekday.saturday,
    ]);
    expect(updated.end.toJson(), <String, Object?>{
      'type': 'count',
      'count': 4,
    });
  });

  testWidgets('series edit prefills and changes the monthly day', (
    WidgetTester tester,
  ) async {
    final ChoreRecurrenceRule originalRule = ChoreRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'monthly',
        'interval': 2,
        'monthDay': 31,
        'end': <String, Object?>{'type': 'count', 'count': 8},
      },
    )!;
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      recurrenceRule: originalRule,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      seriesUpdateCallback: (UpdateRepeatingChoreSeriesRequest request) async =>
          RepeatingChoreSeriesUpdated(_seriesUpdateSnapshot(request)),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder editMenuItem = find.byKey(
      const Key('today.series.edit.menuItem'),
    );
    await tester.ensureVisible(editMenuItem);
    await tester.tap(editMenuItem);
    await tester.pumpAndSettle();

    final Finder monthDay = find.byKey(
      const Key('today.series.edit.advancedRecurrence.monthDay'),
    );
    Finder monthDayDropdown() => find.descendant(
      of: monthDay,
      matching: find.byType(DropdownButtonFormField<int>),
    );
    expect(find.text('Day 31'), findsOneWidget);
    expect(find.text('On day 31 of the month.'), findsOneWidget);
    expect(
      tester.widget<DropdownButtonFormField<int>>(monthDayDropdown()).onChanged,
      isNotNull,
    );
    tester.widget<DropdownButtonFormField<int>>(monthDayDropdown()).onChanged!(
      15,
    );
    await tester.pumpAndSettle();
    expect(find.text('Day 15'), findsOneWidget);
    expect(find.text('On day 15 of the month.'), findsOneWidget);

    final Finder confirm = find.byKey(const Key('today.series.edit.confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(choreRepository.seriesUpdateRequests, hasLength(1));
    expect(
      choreRepository.seriesUpdateRequests.single.recurrenceRule.toJson(),
      <String, Object?>{
        'frequency': 'monthly',
        'interval': 2,
        'monthDay': 15,
        'end': <String, Object?>{'type': 'count', 'count': 8},
      },
    );
  });

  testWidgets('monthly day survives an in-editor frequency round trip', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence current = _manageableSeriesOccurrence();
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      seriesUpdateCallback: (UpdateRepeatingChoreSeriesRequest request) async =>
          RepeatingChoreSeriesUpdated(_seriesUpdateSnapshot(request)),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.series.edit.menuItem')));
    await tester.pumpAndSettle();

    final Finder frequency = find.byKey(
      const Key('today.series.edit.recurrence'),
    );
    tester
        .widget<DropdownButtonFormField<ChoreRecurrenceFrequency>>(frequency)
        .onChanged!(ChoreRecurrenceFrequency.monthly);
    await tester.pumpAndSettle();
    Finder monthDay() =>
        find.byKey(const Key('today.series.edit.advancedRecurrence.monthDay'));
    Finder monthDayDropdown() => find.descendant(
      of: monthDay(),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    expect(find.text('Day 6'), findsOneWidget);
    tester.widget<DropdownButtonFormField<int>>(monthDayDropdown()).onChanged!(
      12,
    );
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<ChoreRecurrenceFrequency>>(frequency)
        .onChanged!(ChoreRecurrenceFrequency.daily);
    await tester.pumpAndSettle();
    expect(monthDay(), findsNothing);
    tester
        .widget<DropdownButtonFormField<ChoreRecurrenceFrequency>>(frequency)
        .onChanged!(ChoreRecurrenceFrequency.monthly);
    await tester.pumpAndSettle();
    expect(find.text('Day 12'), findsOneWidget);

    final Finder confirm = find.byKey(const Key('today.series.edit.confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(
      choreRepository.seriesUpdateRequests.single.recurrenceRule.monthDay,
      12,
    );
  });

  testWidgets('weekly series selector fits compact pseudo text', (
    WidgetTester tester,
  ) async {
    final ChoreRecurrenceRule rule = ChoreRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 1,
        'weekdays': <String>['MO', 'TH', 'SA'],
        'end': <String, Object?>{'type': 'never'},
      },
    )!;
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      recurrenceRule: rule,
    );
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder editMenuItem = find.byKey(
      const Key('today.series.edit.menuItem'),
    );
    await tester.ensureVisible(editMenuItem);
    await tester.tap(editMenuItem);
    await tester.pumpAndSettle();

    final Finder dialog = find.byKey(const Key('today.series.edit.dialog'));
    final Finder monday = find.byKey(
      const Key('today.series.edit.advancedRecurrence.weekday.MO'),
    );
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    await tester.ensureVisible(monday);
    await tester.pumpAndSettle();
    expect(tester.getSize(monday).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    final Finder cancel = find.byKey(const Key('today.series.edit.cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
  });

  testWidgets('monthly series selector fits compact pseudo text', (
    WidgetTester tester,
  ) async {
    final ChoreRecurrenceRule rule = ChoreRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'monthly',
        'interval': 1,
        'monthDay': 31,
        'end': <String, Object?>{'type': 'never'},
      },
    )!;
    final ChoreOccurrence current = _manageableSeriesOccurrence(
      recurrenceRule: rule,
    );
    await _pumpChoreApp(
      tester,
      choreRepository: FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[current]),
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final Finder editMenuItem = find.byKey(
      const Key('today.series.edit.menuItem'),
    );
    await tester.ensureVisible(editMenuItem);
    await tester.tap(editMenuItem);
    await tester.pumpAndSettle();

    final Finder monthDay = find.byKey(
      const Key('today.series.edit.advancedRecurrence.monthDay'),
    );
    await tester.ensureVisible(monthDay);
    await tester.pumpAndSettle();
    expect(tester.getSize(monthDay).height, greaterThanOrEqualTo(48));
    expect(
      find.text(
        '[!! Months without this complete date are skipped safely and never '
        'moved to the final day. !!]',
      ),
      findsOneWidget,
    );
    await tester.tap(monthDay);
    await tester.pumpAndSettle();
    expect(find.text('[!! Complete monthly day 30 !!]'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('[!! Complete monthly day 30 !!]'));
    await tester.pumpAndSettle();

    final Finder cancel = find.byKey(const Key('today.series.edit.cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
  });

  testWidgets('Today cancels a manageable repeating series from today', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence current = _manageableSeriesOccurrence();
    var cancelled = false;
    late final FakeChoreRepository choreRepository;
    choreRepository = FakeChoreRepository(
      loadCallback: (_) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: cancelled
              ? const <ChoreOccurrence>[]
              : <ChoreOccurrence>[current],
        ),
      ),
      seriesCancellationCallback:
          (CancelRepeatingChoreSeriesRequest request) async {
            cancelled = true;
            return RepeatingChoreSeriesCancelled(
              RepeatingChoreSeriesCancellationSnapshot(
                householdId: request.householdId,
                seriesId: request.seriesId,
                effectiveLocalDate: todayChoresFixture().localDate,
                version: request.expectedVersion + 1,
                cancelledCount: 366,
                preservedCompletedCount: 0,
                changed: true,
              ),
            );
          },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    final Finder menu = find.byKey(Key('today.chore.menu.${current.id.value}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today.series.cancel.menuItem')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.series.cancel.dialog')), findsOneWidget);
    expect(
      find.text(
        'Incomplete occurrences from today onward will be removed. Past '
        'occurrences and completed chores stay unchanged.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('today.series.cancel.confirm')));
    await tester.pumpAndSettle();

    expect(find.text(current.title), findsNothing);
    expect(find.byKey(const Key('today.empty')), findsOneWidget);
    expect(
      find.text('The repeating series was cancelled from today.'),
      findsOneWidget,
    );
    expect(choreRepository.seriesCancellationRequests, hasLength(1));
    expect(
      choreRepository.seriesCancellationRequests.single.expectedVersion,
      1,
    );
  });

  testWidgets('Today hides series management without server permission', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence recurring = choreOccurrenceFixture(
      recurrenceFrequency: ChoreRecurrenceFrequency.daily,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[recurring]),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.byKey(Key('today.chore.menu.${recurring.id.value}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.series.edit.menuItem')), findsNothing);
    expect(find.byKey(const Key('today.series.cancel.menuItem')), findsNothing);
    expect(find.byKey(const Key('today.skip.menuItem')), findsOneWidget);
  });

  testWidgets('Today opens occurrence details and an empty activity history', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'Water balcony plants',
      description: 'Use the small watering can',
      dueLocalTime: ChoreLocalTime.tryParse('19:30'),
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.text('Water balcony plants'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.history.sheet')), findsOneWidget);
    expect(find.byKey(const Key('chore.history.current')), findsOneWidget);
    expect(find.text('Chore details'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('chore.history.current')),
        matching: find.text('Use the small watering can'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chore.history.empty')), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(choreRepository.historyRequests, hasLength(1));
    expect(
      choreRepository.historyRequests.single.householdId,
      todayChoresFixture().householdId,
    );
    expect(choreRepository.historyRequests.single.occurrenceId, occurrence.id);
    expect(choreRepository.historyRequests.single.cursor, isNull);

    await tester.tap(find.byKey(const Key('chore.history.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chore.history.sheet')), findsNothing);
  });

  testWidgets(
    'occurrence activity renders every event and retries an earlier page',
    (WidgetTester tester) async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        title: 'Activity-rich kitchen reset',
      );
      final ChoreOccurrenceHistoryPage newest = _historyPage(
        occurrenceId: occurrence.id,
        events: <ChoreOccurrenceHistoryEvent>[
          _historyEvent(
            suffix: '706',
            hour: 6,
            type: ChoreOccurrenceHistoryEventType.completed,
          ),
          _historyEvent(
            suffix: '705',
            hour: 5,
            type: ChoreOccurrenceHistoryEventType.reopened,
          ),
          _historyEvent(
            suffix: '704',
            hour: 4,
            type: ChoreOccurrenceHistoryEventType.skipped,
          ),
        ],
        hasMore: true,
      );
      final ChoreOccurrenceHistoryPage earlier = _historyPage(
        occurrenceId: occurrence.id,
        events: <ChoreOccurrenceHistoryEvent>[
          _historyEvent(
            suffix: '703',
            hour: 3,
            type: ChoreOccurrenceHistoryEventType.rescheduled,
          ),
          _historyEvent(
            suffix: '702',
            hour: 2,
            type: ChoreOccurrenceHistoryEventType.reassigned,
          ),
          _historyEvent(
            suffix: '701',
            hour: 1,
            type: ChoreOccurrenceHistoryEventType.restored,
            actingDisplayName: 'Sam',
          ),
        ],
      );
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
        historyResults: <LoadChoreOccurrenceHistoryResult>[
          ChoreOccurrenceHistoryLoaded(newest),
          const LoadChoreOccurrenceHistoryFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          ChoreOccurrenceHistoryLoaded(earlier),
        ],
      );
      await _pumpChoreApp(tester, choreRepository: choreRepository);

      await tester.tap(find.text('Activity-rich kitchen reset'));
      await tester.pumpAndSettle();

      expect(find.text('Alex completed this chore.'), findsOneWidget);
      expect(find.text('Alex reopened this chore.'), findsOneWidget);
      expect(find.text('Alex skipped this occurrence.'), findsOneWidget);
      final Finder loadMore = find.byKey(const Key('chore.history.loadMore'));
      await _scrollHistoryUntilBuilt(tester, loadMore);
      tester.widget<OutlinedButton>(loadMore).onPressed!();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chore.history.loadMoreError')),
        findsOneWidget,
      );
      expect(find.text('Alex completed this chore.'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('chore.history.scroll')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      final Finder loadMoreRetry = find.byKey(
        const Key('chore.history.loadMoreRetry'),
      );
      await _scrollHistoryUntilBuilt(tester, loadMoreRetry);
      tester.widget<OutlinedButton>(loadMoreRetry).onPressed!();
      await tester.pumpAndSettle();

      expect(find.textContaining('changed the schedule from'), findsOneWidget);
      expect(
        find.text('Alex changed the assignee from Sam to Jamie.'),
        findsOneWidget,
      );
      expect(
        find.text('Alex for Sam restored this occurrence.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chore.history.loadMore')), findsNothing);
      expect(choreRepository.historyRequests, hasLength(3));
      expect(
        choreRepository.historyRequests[1].cursor?.entryId.value,
        'completion:61000000-0000-4000-8000-000000000704',
      );
      expect(
        choreRepository.historyRequests[2].cursor?.entryId,
        choreRepository.historyRequests[1].cursor?.entryId,
      );
    },
  );

  testWidgets('occurrence activity retries a safe initial failure', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'Retry activity details',
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      historyResults: <LoadChoreOccurrenceHistoryResult>[
        const LoadChoreOccurrenceHistoryFailed(
          ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
        ),
        ChoreOccurrenceHistoryLoaded(_historyPage(occurrenceId: occurrence.id)),
      ],
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    await tester.tap(find.text('Retry activity details'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.history.error')), findsOneWidget);
    expect(
      find.text('Chore activity could not be loaded. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission'), findsNothing);
    await tester.tap(find.byKey(const Key('chore.history.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.history.empty')), findsOneWidget);
    expect(choreRepository.historyRequests, hasLength(2));
  });

  testWidgets('Today quick action optimistically completes and reopens', (
    WidgetTester tester,
  ) async {
    final Completer<SetChoreCompletionResult> firstResponse =
        Completer<SetChoreCompletionResult>();
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    var completionCalls = 0;
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      completionCallback: (SetChoreCompletionRequest request) {
        completionCalls += 1;
        return completionCalls == 1
            ? firstResponse.future
            : Future<SetChoreCompletionResult>.value(
                ChoreCompletionSet(_completionSnapshot(request)),
              );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);
    final Finder toggle = find.byKey(
      Key('today.chore.toggle.${occurrence.id.value}'),
    );

    expect(find.text('Scheduled'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();

    expect(find.byKey(Key('today.chore.${occurrence.id.value}')), findsNothing);
    expect(find.byKey(const Key('today.completed.toggle')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('today.completed.toggle')));
    await tester.tap(find.byKey(const Key('today.completed.toggle')));
    await tester.pump();
    expect(find.text('Completed'), findsNWidgets(2));
    expect(toggle, findsNothing);
    expect(choreRepository.completionRequests, hasLength(1));
    firstResponse.complete(
      ChoreCompletionSet(
        _completionSnapshot(choreRepository.completionRequests.single),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reopen chore'), findsOneWidget);
    await tester.tap(
      find.byKey(Key('today.chore.toggle.${occurrence.id.value}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.byTooltip('Mark complete'), findsOneWidget);
    expect(choreRepository.completionRequests, hasLength(2));
    expect(choreRepository.completionRequests.first.completed, isTrue);
    expect(choreRepository.completionRequests.first.expectedVersion, 1);
    expect(choreRepository.completionRequests.last.completed, isFalse);
    expect(choreRepository.completionRequests.last.expectedVersion, 2);
    expect(
      choreRepository.completionRequests.first.idempotencyKey,
      isNot(choreRepository.completionRequests.last.idempotencyKey),
    );
  });

  testWidgets('chore agenda switches view and applies the Me server filter', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence upcoming = choreOccurrenceFixture(
      title: 'Tomorrow recycling',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-07'),
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async {
        if (request.view == ChoreListView.overdue) {
          return TodayChoresLoaded(
            todayChoresFixture(
              view: ChoreListView.overdue,
              generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
              pageLimit: request.limit,
            ),
          );
        }
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.upcoming
                ? <ChoreOccurrence>[upcoming]
                : const <ChoreOccurrence>[],
            view: request.view,
            assigneeFilterMemberId: request.assigneeMemberId,
            generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
            pageLimit: request.limit,
          ),
        );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    expect(find.byKey(const Key('today.viewFilters')), findsOneWidget);
    expect(find.byKey(const Key('today.assigneeFilters')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today.view.upcoming')));
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow recycling'), findsOneWidget);
    expect(choreRepository.listRequests.last.view, ChoreListView.upcoming);
    expect(choreRepository.listRequests.last.assigneeMemberId, isNull);

    await tester.tap(find.byKey(const Key('today.assignee.me')));
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow recycling'), findsOneWidget);
    expect(
      choreRepository.listRequests.last.assigneeMemberId,
      activeHouseholdFixture().memberId,
    );
  });

  testWidgets('resume refresh keeps visible chores and shows stale status', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    var calls = 0;
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async {
        calls += 1;
        return calls == 1
            ? TodayChoresLoaded(
                todayChoresFixture(
                  occurrences: <ChoreOccurrence>[occurrence],
                  generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
                  pageLimit: request.limit,
                ),
              )
            : const LoadTodayChoresFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text(occurrence.title), findsOneWidget);
    expect(find.byKey(const Key('today.stale')), findsOneWidget);
    expect(find.byKey(const Key('today.stale.retry')), findsOneWidget);
    expect(choreRepository.listRequests.length, greaterThanOrEqualTo(2));
  });

  testWidgets('load more preserves the first page and appends the next page', (
    WidgetTester tester,
  ) async {
    final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
    final ChoreOccurrence first = choreOccurrenceFixture(
      occurrenceId: '55555555-5555-4555-8555-555555555551',
      title: 'First page chore',
    );
    final ChoreOccurrence second = choreOccurrenceFixture(
      occurrenceId: '55555555-5555-4555-8555-555555555552',
      title: 'Second page chore',
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async {
        if (request.view == ChoreListView.overdue) {
          return TodayChoresLoaded(
            todayChoresFixture(
              view: ChoreListView.overdue,
              generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
              pageLimit: request.limit,
            ),
          );
        }
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: <ChoreOccurrence>[
              request.cursor == null ? first : second,
            ],
            generatedAt: DateTime.parse('2026-08-06T10:30:00Z'),
            pageLimit: request.limit,
            hasMore: request.cursor == null,
            nextCursor: request.cursor == null ? cursor : null,
          ),
        );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    expect(find.text('First page chore'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('today.loadMore')));
    await tester.tap(find.byKey(const Key('today.loadMore')));
    await tester.pumpAndSettle();

    expect(find.text('First page chore'), findsOneWidget);
    expect(find.text('Second page chore'), findsOneWidget);
    expect(find.byKey(const Key('today.loadMore')), findsNothing);
    expect(choreRepository.listRequests.last.cursor, cursor);
  });

  testWidgets('Today keeps content available while activation card retries', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'Visible while activation fails',
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      activationProgressResults: <LoadHouseholdActivationProgressResult>[
        const LoadHouseholdActivationProgressFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        HouseholdActivationProgressLoaded(
          householdActivationProgressFixture(
            adultParticipantProgress: 2,
            choreCreationProgress: 3,
          ),
        ),
      ],
      weeklyReportResults: const <LoadHouseholdWeeklyReportResult>[
        LoadHouseholdWeeklyReportFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);

    expect(find.text('Visible while activation fails'), findsOneWidget);
    expect(find.byKey(const Key('today.activation.failed')), findsOneWidget);
    expect(find.byKey(const Key('today.weeklyReport.card')), findsNothing);
    expect(choreRepository.weeklyReportRequests, hasLength(1));
    final Finder retry = find.byKey(const Key('today.activation.retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today.activation.ready')), findsOneWidget);
    expect(find.text('3 of 3 chores have been created.'), findsOneWidget);
    expect(choreRepository.activationProgressHouseholds, hasLength(2));
  });

  testWidgets('activation chore action opens existing creation route', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository createRepository = FakeChoreRepository();
    await _pumpChoreApp(tester, choreRepository: createRepository);
    final Finder create = find.byKey(const Key('today.activation.create'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chore.create.screen')), findsOneWidget);
  });

  testWidgets('successful quick completion refreshes household insights', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'Activation completion item',
    );
    var activationLoads = 0;
    var weeklyReportLoads = 0;
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      today: todayChoresFixture(occurrences: <ChoreOccurrence>[occurrence]),
      activationProgressCallback: (HouseholdId householdId) async {
        activationLoads += 1;
        return HouseholdActivationProgressLoaded(
          householdActivationProgressFixture(
            householdId: householdId,
            adultParticipantProgress: 2,
            choreCreationProgress: 3,
            distinctAdultCompleterProgress: activationLoads > 1 ? 1 : 0,
          ),
        );
      },
      weeklyReportCallback: (request) async {
        weeklyReportLoads += 1;
        return HouseholdWeeklyReportLoaded(
          householdWeeklyReportFixture(
            householdId: request.householdId,
            weekOffset: request.weekOffset,
          ),
        );
      },
    );
    await _pumpChoreApp(tester, choreRepository: choreRepository);
    expect(
      find.text('0 of 2 adults have completed at least one chore.'),
      findsOneWidget,
    );
    expect(weeklyReportLoads, 1);

    final Finder toggle = find.byKey(
      Key('today.chore.toggle.${occurrence.id.value}'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(activationLoads, 2);
    expect(weeklyReportLoads, 2);
    expect(
      find.text('1 of 2 adults have completed at least one chore.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'offline snapshot without a safe outbox keeps every chore write disabled',
    (WidgetTester tester) async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        title: 'Saved recycling',
      );
      final ChoreListCursor cursor = ChoreListCursor.tryParse('7b7d')!;
      final ReadCacheMetadata metadata = ReadCacheMetadata(
        validatedAt: DateTime.parse('2026-08-06T10:30:00.000Z'),
        expiresAt: DateTime.parse('2026-08-06T12:30:00.000Z'),
      );
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async {
          return TodayChoresLoaded(
            todayChoresFixture(
              occurrences: request.view == ChoreListView.today
                  ? <ChoreOccurrence>[occurrence]
                  : const <ChoreOccurrence>[],
              view: request.view,
              assigneeFilterMemberId: request.assigneeMemberId,
              generatedAt: metadata.validatedAt,
              pageLimit: request.limit,
              hasMore: request.view == ChoreListView.today,
              nextCursor: request.view == ChoreListView.today ? cursor : null,
            ),
            cacheMetadata: metadata,
          );
        },
      );
      await _pumpChoreApp(tester, choreRepository: choreRepository);

      expect(find.byKey(const Key('today.offlineCache')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('today.offlineCache')),
          matching: find.text(
            'Eligible scheduled chore completion can be saved on this device. '
            'Reconnect for every other change.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(Key('today.chore.toggle.${occurrence.id.value}')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('today.createChore')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('today.activation.invite')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('today.activation.create')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('today.activation.readOnly')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('today.loadMore')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('today.view.upcoming')))
            .onSelected,
        isNull,
      );
      expect(choreRepository.completionRequests, isEmpty);
      expect(
        choreRepository.listRequests.map(
          (ChoreListRequest request) => request.view,
        ),
        <ChoreListView>[ChoreListView.today, ChoreListView.overdue],
      );
    },
  );

  testWidgets('offline completion queues once and supports explicit discard', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      title: 'Queued recycling',
    );
    final ReadCacheMetadata metadata = ReadCacheMetadata(
      validatedAt: DateTime.parse('2026-08-06T10:30:00.000Z'),
      expiresAt: DateTime.parse('2026-08-06T12:30:00.000Z'),
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async => TodayChoresLoaded(
        todayChoresFixture(
          occurrences: request.view == ChoreListView.today
              ? <ChoreOccurrence>[occurrence]
              : const <ChoreOccurrence>[],
          view: request.view,
          assigneeFilterMemberId: request.assigneeMemberId,
          generatedAt: metadata.validatedAt,
          pageLimit: request.limit,
        ),
        cacheMetadata: metadata,
      ),
    );
    final _WidgetCompletionOutbox outbox = _WidgetCompletionOutbox();
    await _pumpChoreApp(
      tester,
      choreRepository: choreRepository,
      completionOutbox: outbox,
    );
    final Finder toggle = find.byKey(
      Key('today.chore.toggle.${occurrence.id.value}'),
    );

    expect(tester.widget<IconButton>(toggle).onPressed, isNotNull);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('today.completionSync.queued')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Completion saved on this device. It will be checked and synced when '
        'you reconnect.',
      ),
      findsOneWidget,
    );
    expect(choreRepository.completionRequests, isEmpty);
    expect(outbox.item?.occurrenceId, occurrence.id);

    final Finder discard = find.byKey(
      const Key('today.completionSync.discard'),
    );
    await tester.ensureVisible(discard);
    await tester.tap(discard);
    await tester.pumpAndSettle();

    expect(outbox.item, isNull);
    expect(find.byKey(const Key('today.completionSync.queued')), findsNothing);
    expect(find.text('Queued recycling'), findsOneWidget);
    expect(tester.widget<IconButton>(toggle).onPressed, isNotNull);
  });

  testWidgets('pending completion replays before authoritative list reads', (
    WidgetTester tester,
  ) async {
    final List<String> events = <String>[];
    final ChoreOccurrence scheduled = choreOccurrenceFixture(
      title: 'Replay recycling',
    );
    final ChoreOccurrence completed = choreOccurrenceFixture(
      title: 'Replay recycling',
      status: ChoreOccurrenceStatus.completed,
      version: 2,
    );
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      occurrenceTargetCallback: (_, _) async {
        events.add('target');
        return ChoreOccurrenceTargetLoaded(scheduled);
      },
      completionCallback: (SetChoreCompletionRequest request) async {
        events.add('mutation');
        return ChoreCompletionSet(_completionSnapshot(request));
      },
      listCallback: (ChoreListRequest request) async {
        events.add('list:${request.view.wireName}');
        return TodayChoresLoaded(
          todayChoresFixture(
            occurrences: request.view == ChoreListView.today
                ? <ChoreOccurrence>[completed]
                : const <ChoreOccurrence>[],
            view: request.view,
            assigneeFilterMemberId: request.assigneeMemberId,
            pageLimit: request.limit,
          ),
        );
      },
    );
    final DateTime createdAt = DateTime.now().toUtc();
    final PendingChoreCompletion pending = PendingChoreCompletion.tryCreate(
      householdId: activeHouseholdFixture().householdId,
      actorMemberId: activeHouseholdFixture().memberId,
      occurrenceId: scheduled.id,
      expectedVersion: scheduled.version,
      idempotencyKey: ChoreCommandId.tryParse(
        '98000000-0000-4000-8000-000000000001',
      )!,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
      attemptCount: 0,
    )!;
    final _WidgetCompletionOutbox outbox = _WidgetCompletionOutbox()
      ..item = pending;

    await _pumpChoreApp(
      tester,
      choreRepository: choreRepository,
      completionOutbox: outbox,
    );

    expect(events.take(2), <String>['target', 'mutation']);
    expect(events.skip(2), everyElement(startsWith('list:')));
    expect(choreRepository.completionRequests, hasLength(1));
    expect(
      choreRepository.completionRequests.single.idempotencyKey,
      pending.idempotencyKey,
    );
    expect(outbox.item, isNull);
  });
}

ChoreCompletionSnapshot _completionSnapshot(SetChoreCompletionRequest request) {
  return ChoreCompletionSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    status: request.completed
        ? ChoreOccurrenceStatus.completed
        : ChoreOccurrenceStatus.scheduled,
    version: request.expectedVersion + 1,
    completedByMemberId: request.completed
        ? activeHouseholdFixture().memberId
        : null,
    completedAt: request.completed
        ? DateTime.parse('2026-08-06T10:30:00Z')
        : null,
    changed: true,
  );
}

ChoreOccurrenceRestoreSnapshot _restoreSnapshot(
  RestoreSkippedChoreOccurrenceRequest request,
) {
  return ChoreOccurrenceRestoreSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    version: request.expectedVersion + 1,
    changed: true,
  );
}

ChoreOccurrence _manageableSeriesOccurrence({
  ChoreRecurrenceRule? recurrenceRule,
  ChoreLocalDate? dueLocalDate,
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String title = 'Daily recycling',
}) {
  final ChoreLocalTime dueTime = ChoreLocalTime.tryParse('19:30')!;
  final ChoreLocalDate effectiveDueLocalDate =
      dueLocalDate ?? todayChoresFixture().localDate;
  final DateTime effectiveDueDateTime = effectiveDueLocalDate.toDateTime();
  final ChoreRecurrenceRule effectiveRule =
      recurrenceRule ??
      ChoreRecurrenceRule.anchored(
        frequency: ChoreRecurrenceFrequency.daily,
        startLocalDate: todayChoresFixture().localDate,
      );
  return choreOccurrenceFixture(
    occurrenceId: occurrenceId,
    title: title,
    description: 'Blue bin',
    dueLocalDate: effectiveDueLocalDate,
    dueLocalTime: dueTime,
    dueAt: DateTime.utc(
      effectiveDueDateTime.year,
      effectiveDueDateTime.month,
      effectiveDueDateTime.day,
      10,
      30,
    ),
    recurrenceFrequency: effectiveRule.frequency,
    seriesVersion: 1,
    seriesDefaultAssigneeMemberId: activeHouseholdFixture().memberId,
    seriesDueLocalTime: dueTime,
    recurrenceRule: effectiveRule,
    canManageSeries: true,
  );
}

RepeatingChoreSeriesUpdateSnapshot _seriesUpdateSnapshot(
  UpdateRepeatingChoreSeriesRequest request,
) {
  return RepeatingChoreSeriesUpdateSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    revisionId: ChoreRevisionId.tryParse(
      '77777777-7777-4777-8777-777777777777',
    )!,
    revisionNumber: request.expectedVersion + 1,
    effectiveLocalDate: request.effectiveLocalDate,
    version: request.expectedVersion + 1,
    rebuiltCount: 53,
    cancelledCount: 313,
    preservedCompletedCount: 0,
    changed: true,
  );
}

RepeatingChoreSeriesUpdateSnapshot _seriesFromOccurrenceUpdateSnapshot(
  UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  ChoreLocalDate effectiveLocalDate,
) {
  return RepeatingChoreSeriesUpdateSnapshot(
    householdId: request.householdId,
    seriesId: request.seriesId,
    revisionId: ChoreRevisionId.tryParse(
      '77777777-7777-4777-8777-777777777777',
    )!,
    revisionNumber: request.expectedVersion + 1,
    effectiveLocalDate: effectiveLocalDate,
    version: request.expectedVersion + 1,
    rebuiltCount: 47,
    cancelledCount: 307,
    preservedCompletedCount: 1,
    changed: true,
  );
}

ChoreOccurrenceHistoryPage _historyPage({
  required ChoreOccurrenceId occurrenceId,
  List<ChoreOccurrenceHistoryEvent> events =
      const <ChoreOccurrenceHistoryEvent>[],
  bool hasMore = false,
}) {
  return ChoreOccurrenceHistoryPage.tryCreate(
    householdId: todayChoresFixture().householdId,
    occurrenceId: occurrenceId,
    events: events,
    hasMore: hasMore,
  )!;
}

ChoreOccurrenceHistoryEvent _historyEvent({
  required String suffix,
  required int hour,
  required ChoreOccurrenceHistoryEventType type,
  String? actingDisplayName,
}) {
  final bool rescheduled = type == ChoreOccurrenceHistoryEventType.rescheduled;
  final bool reassigned = type == ChoreOccurrenceHistoryEventType.reassigned;
  final String source = switch (type) {
    ChoreOccurrenceHistoryEventType.rescheduled => 'reschedule',
    ChoreOccurrenceHistoryEventType.reassigned => 'assignment',
    _ => 'completion',
  };
  return ChoreOccurrenceHistoryEvent.tryCreate(
    id: ChoreHistoryEntryId.tryParse(
      '$source:61000000-0000-4000-8000-000000000$suffix',
    )!,
    type: type,
    actorMemberId: activeHouseholdFixture().memberId,
    actorDisplayName: 'Alex',
    actingMemberId: actingDisplayName == null
        ? null
        : householdMemberIdFixture('33333333-3333-4333-8333-333333333334'),
    actingDisplayName: actingDisplayName,
    occurredAt: DateTime.utc(2026, 8, 7, hour),
    occurrenceVersion: hour,
    previousDueLocalDate: rescheduled
        ? ChoreLocalDate.tryParse('2026-08-06')
        : null,
    previousDueLocalTime: rescheduled ? ChoreLocalTime.tryParse('19:30') : null,
    newDueLocalDate: rescheduled ? ChoreLocalDate.tryParse('2026-08-07') : null,
    newDueLocalTime: null,
    previousAssigneeMemberId: reassigned
        ? householdMemberIdFixture('33333333-3333-4333-8333-333333333334')
        : null,
    previousAssigneeDisplayName: reassigned ? 'Sam' : null,
    newAssigneeMemberId: reassigned
        ? householdMemberIdFixture('33333333-3333-4333-8333-333333333335')
        : null,
    newAssigneeDisplayName: reassigned ? 'Jamie' : null,
  )!;
}

Future<void> _scrollHistoryUntilBuilt(
  WidgetTester tester,
  Finder target,
) async {
  for (
    var attempt = 0;
    attempt < 8 && target.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.drag(
      find.byKey(const Key('chore.history.scroll')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

Future<_ChoreHarness> _pumpChoreApp(
  WidgetTester tester, {
  required ChoreRepository choreRepository,
  FakeHouseholdMemberRepository? memberRepository,
  Locale? locale,
  Size? size,
  double textScaleFactor = 1,
  ChoreCompletionOutbox? completionOutbox,
  ChoreSyncRepository? syncRepository,
}) async {
  if (size != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
    refreshCallback: () async => AuthSessionAvailable(authSessionFixture()),
  );
  final FakeHouseholdMemberRepository effectiveMemberRepository =
      memberRepository ?? FakeHouseholdMemberRepository();
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
        effectiveMemberRepository,
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
      if (completionOutbox != null)
        choreCompletionOutboxProvider.overrideWithValue(completionOutbox),
      if (syncRepository != null)
        choreSyncRepositoryProvider.overrideWithValue(syncRepository),
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
  return _ChoreHarness(effectiveMemberRepository, container);
}

final class _ChoreHarness {
  const _ChoreHarness(this.memberRepository, this.container);

  final FakeHouseholdMemberRepository memberRepository;
  final ProviderContainer container;
}

Future<void> _successfulInitialization() async {}

final class _WidgetCompletionOutbox implements ChoreCompletionOutbox {
  PendingChoreCompletion? item;

  @override
  bool get isAvailable => true;

  @override
  Future<PendingChoreCompletion?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  }) async {
    final PendingChoreCompletion? current = item;
    return current != null &&
            current.householdId == expectedHouseholdId &&
            current.actorMemberId == expectedActorMemberId
        ? current
        : null;
  }

  @override
  Future<ChoreCompletionOutboxEnqueueResult> enqueue({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
  }) async {
    final PendingChoreCompletion? current = item;
    if (current != null) {
      return ChoreCompletionOutboxOccupied(current);
    }
    final DateTime createdAt = DateTime.parse('2026-08-06T10:35:00.000Z');
    final PendingChoreCompletion created = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
      attemptCount: 0,
    )!;
    item = created;
    return ChoreCompletionOutboxEnqueued(created, created: true);
  }

  @override
  Future<PendingChoreCompletion?> markNextAttempt(
    PendingChoreCompletion expected,
  ) async {
    final PendingChoreCompletion? next = item == expected
        ? expected.nextAttempt()
        : null;
    item = next;
    return next;
  }

  @override
  Future<PendingChoreCompletion?> exhaustAutomaticAttempts(
    PendingChoreCompletion expected,
  ) async {
    final PendingChoreCompletion? exhausted = item == expected
        ? expected.exhaustAutomaticAttempts()
        : null;
    item = exhausted;
    return exhausted;
  }

  @override
  Future<bool> clear() async {
    item = null;
    return true;
  }
}
