import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class TodayCalendarRequest {
  const TodayCalendarRequest({
    required this.householdId,
    required this.participantMemberId,
  });

  final HouseholdId householdId;
  final HouseholdMemberId? participantMemberId;

  bool hasSameQuery(TodayCalendarRequest other) {
    return householdId == other.householdId &&
        participantMemberId == other.participantMemberId;
  }
}

final class TodayCalendarSnapshot {
  TodayCalendarSnapshot._({
    required this.householdId,
    required this.householdTimeZone,
    required this.localDate,
    required this.generatedAt,
    required this.participantMemberId,
    required List<CalendarEventProjection> events,
    required this.truncated,
  }) : events = List<CalendarEventProjection>.unmodifiable(events);

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate localDate;
  final UtcInstant generatedAt;
  final HouseholdMemberId? participantMemberId;
  final List<CalendarEventProjection> events;
  final bool truncated;

  List<CalendarEventProjection> get nowAndNextEvents {
    String? nextTimedOccurrenceId;
    for (final CalendarEventProjection projection in events) {
      final event = projection.event;
      if (!event.isAllDay && event.startsAt!.compareTo(generatedAt) > 0) {
        nextTimedOccurrenceId = event.occurrenceId.value;
        break;
      }
    }
    return events
        .where((CalendarEventProjection projection) {
          final event = projection.event;
          return event.isAllDay ||
              event.startsAt!.compareTo(generatedAt) <= 0 &&
                  event.endsAt!.compareTo(generatedAt) > 0 ||
              event.occurrenceId.value == nextTimedOccurrenceId;
        })
        .toList(growable: false);
  }

  List<CalendarEventProjection> get remainingEvents {
    final Set<String> featuredOccurrenceIds = nowAndNextEvents
        .map(
          (CalendarEventProjection projection) =>
              projection.event.occurrenceId.value,
        )
        .toSet();
    return events
        .where(
          (CalendarEventProjection projection) => !featuredOccurrenceIds
              .contains(projection.event.occurrenceId.value),
        )
        .toList(growable: false);
  }

  static TodayCalendarSnapshot? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate localDate,
    required UtcInstant generatedAt,
    required HouseholdMemberId? participantMemberId,
    required List<CalendarEventProjection> events,
    required bool truncated,
  }) {
    if (events.length > 500 ||
        events.any(
          (CalendarEventProjection projection) =>
              projection.event.householdId != householdId ||
              projection.viewLocalDate != localDate ||
              participantMemberId != null &&
                  !projection.event.participants.any(
                    (participant) =>
                        participant.memberId == participantMemberId,
                  ),
        ) ||
        events
                .map(
                  (CalendarEventProjection projection) =>
                      projection.event.occurrenceId,
                )
                .toSet()
                .length !=
            events.length) {
      return null;
    }
    for (var index = 1; index < events.length; index += 1) {
      if (compareCalendarEventProjections(events[index - 1], events[index]) >=
          0) {
        return null;
      }
    }
    return TodayCalendarSnapshot._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      localDate: localDate,
      generatedAt: generatedAt,
      participantMemberId: participantMemberId,
      events: events,
      truncated: truncated,
    );
  }
}

enum TodaySectionKind {
  overdueChores,
  nowAndNextEvents,
  dueTodayScheduledChores,
  remainingEvents,
  dueTodayCompletedChores,
}

final class TodaySnapshot {
  TodaySnapshot._({
    required this.chores,
    required this.overdue,
    required this.calendar,
  });

  final TodayChores chores;
  final TodayChores overdue;
  final TodayCalendarSnapshot calendar;

  HouseholdId get householdId => chores.householdId;

  String get householdTimeZone => chores.householdTimezone;

  String get localDate => chores.localDate.value;

  List<ChoreOccurrence> get overdueChores => overdue.occurrences;

  List<CalendarEventProjection> get nowAndNextEvents =>
      calendar.nowAndNextEvents;

  List<ChoreOccurrence> get dueTodayScheduledChores => chores.occurrences
      .where(
        (ChoreOccurrence occurrence) =>
            occurrence.status == ChoreOccurrenceStatus.scheduled,
      )
      .toList(growable: false);

  List<CalendarEventProjection> get remainingEvents => calendar.remainingEvents;

  List<ChoreOccurrence> get dueTodayCompletedChores => chores.occurrences
      .where(
        (ChoreOccurrence occurrence) =>
            occurrence.status == ChoreOccurrenceStatus.completed,
      )
      .toList(growable: false);

  List<TodaySectionKind> get visibleSectionOrder => <TodaySectionKind>[
    if (overdueChores.isNotEmpty) TodaySectionKind.overdueChores,
    if (nowAndNextEvents.isNotEmpty) TodaySectionKind.nowAndNextEvents,
    if (dueTodayScheduledChores.isNotEmpty)
      TodaySectionKind.dueTodayScheduledChores,
    if (remainingEvents.isNotEmpty) TodaySectionKind.remainingEvents,
    if (dueTodayCompletedChores.isNotEmpty)
      TodaySectionKind.dueTodayCompletedChores,
  ];

  static TodaySnapshot? tryCreate({
    required TodayChores chores,
    required TodayChores overdue,
    required TodayCalendarSnapshot calendar,
  }) {
    if (!hasMatchingCalendarContext(chores: chores, calendar: calendar) ||
        overdue.view != ChoreListView.overdue ||
        overdue.householdId != chores.householdId ||
        overdue.householdTimezone != chores.householdTimezone ||
        overdue.localDate != chores.localDate ||
        overdue.assigneeFilterMemberId != chores.assigneeFilterMemberId) {
      return null;
    }
    return TodaySnapshot._(
      chores: chores,
      overdue: overdue,
      calendar: calendar,
    );
  }

  static bool hasMatchingCalendarContext({
    required TodayChores chores,
    required TodayCalendarSnapshot calendar,
  }) {
    return chores.view == ChoreListView.today &&
        chores.householdId == calendar.householdId &&
        chores.householdTimezone == calendar.householdTimeZone.value &&
        chores.localDate.value == calendar.localDate.value &&
        chores.assigneeFilterMemberId == calendar.participantMemberId;
  }
}
