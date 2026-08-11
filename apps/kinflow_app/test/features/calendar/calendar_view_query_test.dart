import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  group('Calendar view query domain', () {
    test('keeps month arithmetic date-only and clamps month ends', () {
      final CalendarLocalDate january = CalendarLocalDate.tryParse(
        '2028-01-31',
      )!;

      expect(january.addMonthsClamped(1).value, '2028-02-29');
      expect(january.firstDayOfMonth.value, '2028-01-01');
      expect(january.daysInMonth, 31);
      expect(
        CalendarLocalDate.tryParse('2026-08-02')!.weekday,
        DateTime.sunday,
      );
    });

    test('resolves only the server-authoritative initial agenda range', () {
      final CalendarEventPageRequest initial =
          CalendarEventPageRequest.initialAgenda(calendarHouseholdId());
      final CalendarAllDayRange range = CalendarAllDayRange.tryCreate(
        startDate: CalendarLocalDate.tryParse('2026-08-07')!,
        endDateExclusive: CalendarLocalDate.tryParse('2026-11-05')!,
      )!;

      expect(initial.range, isNull);
      expect(initial.resolveRange(range)?.range, range);
      expect(
        CalendarEventPageRequest.tryCreate(
          householdId: calendarHouseholdId(),
          view: CalendarViewMode.day,
          range: range,
        ),
        isNull,
      );
      expect(
        CalendarEventPageRequest.tryCreate(
          householdId: calendarHouseholdId(),
          view: CalendarViewMode.month,
          range: range,
        ),
        isNull,
      );
    });

    test('orders all-day events before timed events on the same date', () {
      final allDay = calendarEventFixture(title: 'Holiday', isAllDay: true);
      final timed = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'Dinner',
      );
      final CalendarEventPage page = calendarEventPageFixture(
        events: [timed, allDay],
      );

      expect(page.items.map((item) => item.event.title), ['Holiday', 'Dinner']);
    });

    test('appends an exact cursor page without gaps or duplicates', () {
      final firstEvent = calendarEventFixture(title: 'Holiday', isAllDay: true);
      final secondEvent = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'Dinner',
      );
      final CalendarEventPage first = calendarEventPageFixture(
        events: [firstEvent],
        limit: 1,
        hasMore: true,
        nextCursor: 'aa',
      );
      final CalendarEventPage second = calendarEventPageFixture(
        events: [secondEvent],
        limit: 1,
        requestCursor: 'aa',
      );

      final CalendarEventPage? merged = first.appendPage(second);

      expect(merged, isNotNull);
      expect(merged!.items.map((item) => item.event.title), [
        'Holiday',
        'Dinner',
      ]);
      expect(first.appendPage(first), isNull);
    });

    test('requires one contiguous, count-consistent month row per date', () {
      final allDay = calendarEventFixture(
        isAllDay: true,
        allDayEndDateExclusive: '2026-08-10',
      );
      final CalendarMonthSummary summary = calendarMonthSummaryFixture(
        events: [allDay],
      );

      expect(summary.days, hasLength(31));
      expect(
        summary.dayFor(CalendarLocalDate.tryParse('2026-08-08')!)?.allDayCount,
        1,
      );
      expect(summary.dayFor(CalendarLocalDate.tryParse('2026-09-01')!), isNull);
    });
  });
}
