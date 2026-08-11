import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum CalendarViewMode {
  agenda('agenda'),
  day('day'),
  month('month');

  const CalendarViewMode(this.wireValue);

  final String wireValue;

  static CalendarViewMode? tryParse(String value) {
    for (final CalendarViewMode mode in values) {
      if (mode.wireValue == value) {
        return mode;
      }
    }
    return null;
  }
}

final class CalendarPageCursor {
  const CalendarPageCursor._(this.value);

  final String value;

  static final RegExp _validValue = RegExp(r'^[0-9a-f]+$');

  static CalendarPageCursor? tryParse(String value) {
    return value.length >= 2 &&
            value.length <= 1000 &&
            value.length.isEven &&
            _validValue.hasMatch(value)
        ? CalendarPageCursor._(value)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarPageCursor && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class CalendarEventPageRequest {
  const CalendarEventPageRequest._({
    required this.householdId,
    required this.view,
    required this.range,
    required this.limit,
    required this.cursor,
  });

  final HouseholdId householdId;
  final CalendarViewMode view;
  final CalendarAllDayRange? range;
  final int limit;
  final CalendarPageCursor? cursor;

  static CalendarEventPageRequest? tryCreate({
    required HouseholdId householdId,
    required CalendarViewMode view,
    CalendarAllDayRange? range,
    int limit = 30,
    CalendarPageCursor? cursor,
  }) {
    if (view == CalendarViewMode.month ||
        limit < 1 ||
        limit > 100 ||
        (range == null &&
            (view != CalendarViewMode.agenda || cursor != null)) ||
        (range != null &&
            (range.dayCount > 366 ||
                (view == CalendarViewMode.day && range.dayCount != 1)))) {
      return null;
    }
    return CalendarEventPageRequest._(
      householdId: householdId,
      view: view,
      range: range,
      limit: limit,
      cursor: cursor,
    );
  }

  static CalendarEventPageRequest initialAgenda(
    HouseholdId householdId, {
    int limit = 30,
  }) {
    return tryCreate(
      householdId: householdId,
      view: CalendarViewMode.agenda,
      limit: limit,
    )!;
  }

  CalendarEventPageRequest? resolveRange(CalendarAllDayRange resolvedRange) {
    final CalendarAllDayRange? current = range;
    if (current != null && current != resolvedRange) {
      return null;
    }
    return tryCreate(
      householdId: householdId,
      view: view,
      range: resolvedRange,
      limit: limit,
      cursor: cursor,
    );
  }

  CalendarEventPageRequest get firstPage => CalendarEventPageRequest._(
    householdId: householdId,
    view: view,
    range: range,
    limit: limit,
    cursor: null,
  );

  CalendarEventPageRequest? continuation(CalendarPageCursor nextCursor) {
    final CalendarAllDayRange? resolvedRange = range;
    return resolvedRange == null
        ? null
        : tryCreate(
            householdId: householdId,
            view: view,
            range: resolvedRange,
            limit: limit,
            cursor: nextCursor,
          );
  }

  bool hasSameQuery(CalendarEventPageRequest other) {
    return householdId == other.householdId &&
        view == other.view &&
        range == other.range &&
        limit == other.limit;
  }
}

final class CalendarEventProjection {
  const CalendarEventProjection._({
    required this.event,
    required this.viewLocalDate,
    required this.viewLocalTime,
  });

  final OneTimeCalendarEvent event;
  final CalendarLocalDate viewLocalDate;
  final CalendarLocalTime? viewLocalTime;

  static CalendarEventProjection? tryCreate({
    required OneTimeCalendarEvent event,
    required CalendarLocalDate viewLocalDate,
    required CalendarLocalTime? viewLocalTime,
    required CalendarAllDayRange queryRange,
  }) {
    if (!queryRange.contains(viewLocalDate) ||
        (event.isAllDay && viewLocalTime != null) ||
        (!event.isAllDay && viewLocalTime == null)) {
      return null;
    }
    return CalendarEventProjection._(
      event: event,
      viewLocalDate: viewLocalDate,
      viewLocalTime: viewLocalTime,
    );
  }
}

final class CalendarEventPage {
  CalendarEventPage._({
    required this.request,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.generatedAt,
    required List<CalendarEventProjection> items,
    required this.hasMore,
    required this.nextCursor,
  }) : items = List<CalendarEventProjection>.unmodifiable(items);

  final CalendarEventPageRequest request;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final UtcInstant generatedAt;
  final List<CalendarEventProjection> items;
  final bool hasMore;
  final CalendarPageCursor? nextCursor;

  HouseholdId get householdId => request.householdId;

  CalendarAllDayRange get range => request.range!;

  static CalendarEventPage? tryCreate({
    required CalendarEventPageRequest request,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required UtcInstant generatedAt,
    required List<CalendarEventProjection> items,
    required bool hasMore,
    required CalendarPageCursor? nextCursor,
  }) {
    if (request.range == null ||
        items.length > request.limit ||
        (hasMore && (nextCursor == null || items.length != request.limit)) ||
        (!hasMore && nextCursor != null) ||
        items.any(
          (CalendarEventProjection item) =>
              item.event.householdId != request.householdId ||
              !request.range!.contains(item.viewLocalDate),
        ) ||
        items
                .map((CalendarEventProjection item) => item.event.occurrenceId)
                .toSet()
                .length !=
            items.length) {
      return null;
    }
    for (var index = 1; index < items.length; index += 1) {
      if (compareCalendarEventProjections(items[index - 1], items[index]) >=
          0) {
        return null;
      }
    }
    return CalendarEventPage._(
      request: request,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  CalendarEventPage? appendPage(CalendarEventPage page) {
    if (!request.hasSameQuery(page.request) ||
        page.request.cursor != nextCursor ||
        householdTimeZone != page.householdTimeZone ||
        householdLocalDate != page.householdLocalDate) {
      return null;
    }
    final List<CalendarEventProjection> merged = <CalendarEventProjection>[
      ...items,
      ...page.items,
    ];
    if (merged
            .map((CalendarEventProjection item) => item.event.occurrenceId)
            .toSet()
            .length !=
        merged.length) {
      return null;
    }
    for (var index = 1; index < merged.length; index += 1) {
      if (compareCalendarEventProjections(merged[index - 1], merged[index]) >=
          0) {
        return null;
      }
    }
    return CalendarEventPage._(
      request: request.firstPage,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      items: merged,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  OneTimeCalendarEvent? eventBySeries(CalendarEventSeriesId seriesId) {
    for (final CalendarEventProjection item in items) {
      if (item.event.seriesId == seriesId) {
        return item.event;
      }
    }
    return null;
  }

  OneTimeCalendarEvent? eventByOccurrence(
    CalendarEventOccurrenceId occurrenceId,
  ) {
    for (final CalendarEventProjection item in items) {
      if (item.event.occurrenceId == occurrenceId) {
        return item.event;
      }
    }
    return null;
  }
}

int compareCalendarEventProjections(
  CalendarEventProjection left,
  CalendarEventProjection right,
) {
  final int date = left.viewLocalDate.compareTo(right.viewLocalDate);
  if (date != 0) {
    return date;
  }
  if (left.event.isAllDay != right.event.isAllDay) {
    return left.event.isAllDay ? -1 : 1;
  }
  final CalendarLocalTime? leftTime = left.viewLocalTime;
  final CalendarLocalTime? rightTime = right.viewLocalTime;
  if (leftTime != null && rightTime != null) {
    final int time = leftTime.compareTo(rightTime);
    if (time != 0) {
      return time;
    }
  }
  return left.event.occurrenceId.value.compareTo(
    right.event.occurrenceId.value,
  );
}

final class CalendarMonthSummaryRequest {
  const CalendarMonthSummaryRequest._({
    required this.householdId,
    required this.monthStartDate,
  });

  final HouseholdId householdId;
  final CalendarLocalDate monthStartDate;

  static CalendarMonthSummaryRequest? tryCreate({
    required HouseholdId householdId,
    required CalendarLocalDate monthStartDate,
  }) {
    return monthStartDate.day == 1
        ? CalendarMonthSummaryRequest._(
            householdId: householdId,
            monthStartDate: monthStartDate,
          )
        : null;
  }
}

final class CalendarMonthDaySummary {
  const CalendarMonthDaySummary._({
    required this.date,
    required this.eventCount,
    required this.allDayCount,
    required this.timedCount,
  });

  final CalendarLocalDate date;
  final int eventCount;
  final int allDayCount;
  final int timedCount;

  static CalendarMonthDaySummary? tryCreate({
    required CalendarLocalDate date,
    required int eventCount,
    required int allDayCount,
    required int timedCount,
  }) {
    return eventCount >= 0 &&
            allDayCount >= 0 &&
            timedCount >= 0 &&
            eventCount == allDayCount + timedCount
        ? CalendarMonthDaySummary._(
            date: date,
            eventCount: eventCount,
            allDayCount: allDayCount,
            timedCount: timedCount,
          )
        : null;
  }
}

final class CalendarMonthSummary {
  CalendarMonthSummary._({
    required this.request,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.monthEndDateExclusive,
    required List<CalendarMonthDaySummary> days,
  }) : days = List<CalendarMonthDaySummary>.unmodifiable(days);

  final CalendarMonthSummaryRequest request;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final UtcInstant generatedAt;
  final CalendarLocalDate monthEndDateExclusive;
  final List<CalendarMonthDaySummary> days;

  static CalendarMonthSummary? tryCreate({
    required CalendarMonthSummaryRequest request,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required UtcInstant generatedAt,
    required CalendarLocalDate monthEndDateExclusive,
    required List<CalendarMonthDaySummary> days,
  }) {
    final CalendarLocalDate expectedEnd = request.monthStartDate
        .addMonthsClamped(1);
    if (monthEndDateExclusive != expectedEnd ||
        days.length != request.monthStartDate.daysInMonth) {
      return null;
    }
    for (var index = 0; index < days.length; index += 1) {
      if (days[index].date != request.monthStartDate.addDays(index)) {
        return null;
      }
    }
    return CalendarMonthSummary._(
      request: request,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      monthEndDateExclusive: monthEndDateExclusive,
      days: days,
    );
  }

  CalendarMonthDaySummary? dayFor(CalendarLocalDate date) {
    final int index = date.differenceInDays(request.monthStartDate);
    return index < 0 || index >= days.length ? null : days[index];
  }
}
