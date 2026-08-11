import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  test(
    'combines only matching server household context in stable sections',
    () {
      final OneTimeCalendarEvent allDay = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'School holiday',
        isAllDay: true,
        localStartDate: '2026-08-07',
        allDayEndDateExclusive: '2026-08-08',
      );
      final OneTimeCalendarEvent timed = calendarEventFixture(
        title: 'Family dinner',
        localStartDate: '2026-08-07',
      );
      final CalendarEventPage page = calendarEventPageFixture(
        events: <OneTimeCalendarEvent>[timed, allDay],
        localDate: '2026-08-07',
      );
      final TodayCalendarSnapshot calendar = TodayCalendarSnapshot.tryCreate(
        householdId: page.householdId,
        householdTimeZone: page.householdTimeZone,
        localDate: page.householdLocalDate,
        generatedAt: page.generatedAt,
        participantMemberId: null,
        events: page.items,
        truncated: false,
      )!;
      final TodayChores chores = todayChoresFixture(
        localDate: '2026-08-07',
        occurrences: <ChoreOccurrence>[
          choreOccurrenceFixture(dueLocalDate: _choreDate('2026-08-07')),
          choreOccurrenceFixture(
            occurrenceId: '55555555-5555-4555-8555-555555555556',
            seriesId: '44444444-4444-4444-8444-444444444445',
            dueLocalDate: _choreDate('2026-08-07'),
            status: ChoreOccurrenceStatus.completed,
          ),
        ],
      );
      final TodayChores overdue = todayChoresFixture(
        localDate: '2026-08-07',
        view: ChoreListView.overdue,
        occurrences: <ChoreOccurrence>[
          choreOccurrenceFixture(
            occurrenceId: '55555555-5555-4555-8555-555555555557',
            seriesId: '44444444-4444-4444-8444-444444444446',
            dueLocalDate: _choreDate('2026-08-06'),
          ),
        ],
      );

      final TodaySnapshot? snapshot = TodaySnapshot.tryCreate(
        chores: chores,
        overdue: overdue,
        calendar: calendar,
      );

      expect(snapshot, isNotNull);
      expect(
        snapshot!.calendar.events.map((item) => item.event.title),
        <String>['School holiday', 'Family dinner'],
      );
      expect(snapshot.overdueChores, hasLength(1));
      expect(snapshot.nowAndNextEvents, hasLength(2));
      expect(snapshot.dueTodayScheduledChores, hasLength(1));
      expect(snapshot.remainingEvents, isEmpty);
      expect(snapshot.dueTodayCompletedChores, hasLength(1));
      expect(snapshot.visibleSectionOrder, <TodaySectionKind>[
        TodaySectionKind.overdueChores,
        TodaySectionKind.nowAndNextEvents,
        TodaySectionKind.dueTodayScheduledChores,
        TodaySectionKind.dueTodayCompletedChores,
      ]);
    },
  );

  test('rejects local-date and member-filter mismatches', () {
    final CalendarEventPage page = calendarEventPageFixture(
      localDate: '2026-08-07',
    );
    final TodayCalendarSnapshot calendar = TodayCalendarSnapshot.tryCreate(
      householdId: page.householdId,
      householdTimeZone: page.householdTimeZone,
      localDate: page.householdLocalDate,
      generatedAt: page.generatedAt,
      participantMemberId: calendarMemberOneId(),
      events: const <CalendarEventProjection>[],
      truncated: false,
    )!;

    expect(
      TodaySnapshot.tryCreate(
        chores: todayChoresFixture(localDate: '2026-08-06'),
        overdue: todayChoresFixture(
          localDate: '2026-08-06',
          view: ChoreListView.overdue,
        ),
        calendar: calendar,
      ),
      isNull,
    );
    expect(
      TodaySnapshot.tryCreate(
        chores: todayChoresFixture(
          localDate: '2026-08-07',
          assigneeFilterMemberId: calendarMemberTwoId(),
        ),
        overdue: todayChoresFixture(
          localDate: '2026-08-07',
          view: ChoreListView.overdue,
          assigneeFilterMemberId: calendarMemberTwoId(),
        ),
        calendar: calendar,
      ),
      isNull,
    );
  });

  test('rejects an overdue source with a different context or view', () {
    final CalendarEventPage page = calendarEventPageFixture(
      localDate: '2026-08-07',
    );
    final TodayCalendarSnapshot calendar = TodayCalendarSnapshot.tryCreate(
      householdId: page.householdId,
      householdTimeZone: page.householdTimeZone,
      localDate: page.householdLocalDate,
      generatedAt: page.generatedAt,
      participantMemberId: null,
      events: const <CalendarEventProjection>[],
      truncated: false,
    )!;
    final TodayChores chores = todayChoresFixture(localDate: '2026-08-07');

    expect(
      TodaySnapshot.tryCreate(
        chores: chores,
        overdue: todayChoresFixture(localDate: '2026-08-07'),
        calendar: calendar,
      ),
      isNull,
    );
    expect(
      TodaySnapshot.tryCreate(
        chores: chores,
        overdue: todayChoresFixture(
          localDate: '2026-08-06',
          view: ChoreListView.overdue,
        ),
        calendar: calendar,
      ),
      isNull,
    );
  });

  test(
    'partitions all-day, happening, and nearest next without duplicates',
    () {
      final List<OneTimeCalendarEvent> events = <OneTimeCalendarEvent>[
        calendarEventFixture(
          seriesId: '44444444-4444-4444-8444-444444444451',
          occurrenceId: '55555555-5555-4555-8555-555555555561',
          title: 'All day',
          isAllDay: true,
        ),
        calendarEventFixture(
          seriesId: '44444444-4444-4444-8444-444444444452',
          occurrenceId: '55555555-5555-4555-8555-555555555562',
          title: 'Ended at boundary',
          localStartTime: '09:00',
          startsAt: '2026-08-06T23:30:00Z',
          durationMinutes: 90,
        ),
        calendarEventFixture(
          seriesId: '44444444-4444-4444-8444-444444444453',
          occurrenceId: '55555555-5555-4555-8555-555555555563',
          title: 'Happening',
          localStartTime: '09:30',
          startsAt: '2026-08-07T00:30:00Z',
          durationMinutes: 90,
        ),
        calendarEventFixture(
          seriesId: '44444444-4444-4444-8444-444444444454',
          occurrenceId: '55555555-5555-4555-8555-555555555564',
          title: 'Nearest next',
          localStartTime: '11:00',
          startsAt: '2026-08-07T02:00:00Z',
        ),
        calendarEventFixture(
          seriesId: '44444444-4444-4444-8444-444444444455',
          occurrenceId: '55555555-5555-4555-8555-555555555565',
          title: 'Later',
          localStartTime: '12:00',
          startsAt: '2026-08-07T03:00:00Z',
        ),
      ];
      final CalendarEventPage page = calendarEventPageFixture(events: events);
      final TodayCalendarSnapshot snapshot = TodayCalendarSnapshot.tryCreate(
        householdId: page.householdId,
        householdTimeZone: page.householdTimeZone,
        localDate: page.householdLocalDate,
        generatedAt: UtcInstant.tryParse('2026-08-07T01:00:00Z')!,
        participantMemberId: null,
        events: page.items,
        truncated: false,
      )!;

      expect(
        snapshot.nowAndNextEvents.map((item) => item.event.title),
        <String>['All day', 'Happening', 'Nearest next'],
      );
      expect(snapshot.remainingEvents.map((item) => item.event.title), <String>[
        'Ended at boundary',
        'Later',
      ]);
      expect(<String>{
        ...snapshot.nowAndNextEvents.map(
          (item) => item.event.occurrenceId.value,
        ),
        ...snapshot.remainingEvents.map(
          (item) => item.event.occurrenceId.value,
        ),
      }, hasLength(snapshot.events.length));
    },
  );

  test('calendar snapshot rejects events outside its participant boundary', () {
    final OneTimeCalendarEvent onlyAlex = calendarEventFixture();
    final CalendarEventPage page = calendarEventPageFixture(
      events: <OneTimeCalendarEvent>[onlyAlex],
      localDate: '2026-08-07',
    );

    expect(
      TodayCalendarSnapshot.tryCreate(
        householdId: page.householdId,
        householdTimeZone: page.householdTimeZone,
        localDate: page.householdLocalDate,
        generatedAt: page.generatedAt,
        participantMemberId: calendarMemberTwoId(),
        events: page.items,
        truncated: false,
      ),
      isNull,
    );
  });
}

ChoreLocalDate _choreDate(String value) => ChoreLocalDate.tryParse(value)!;
