import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class CalendarEventParticipant {
  const CalendarEventParticipant._({
    required this.memberId,
    required this.displayName,
  });

  final HouseholdMemberId memberId;
  final String displayName;

  static CalendarEventParticipant? tryCreate({
    required HouseholdMemberId memberId,
    required String displayName,
  }) {
    final String normalized = displayName.trim();
    if (normalized.isEmpty ||
        normalized.length > 80 ||
        normalized != displayName) {
      return null;
    }
    return CalendarEventParticipant._(
      memberId: memberId,
      displayName: normalized,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventParticipant &&
        other.memberId == memberId &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(memberId, displayName);
}

final class OneTimeCalendarEvent {
  OneTimeCalendarEvent._({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.description,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timeZone,
    required this.overlapPolicy,
    required this.startsAt,
    required this.endsAt,
    required this.dstResolution,
    required this.utcOffsetSeconds,
    required List<CalendarEventParticipant> participants,
    required this.version,
    required this.occurrenceVersion,
    required this.recurrenceRule,
    required this.recurrenceLocalStartDate,
    required this.revisionNumber,
    required this.isException,
  }) : participants = List<CalendarEventParticipant>.unmodifiable(participants);

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final String title;
  final String? description;
  final bool isAllDay;
  final CalendarLocalDate localStartDate;
  final CalendarLocalTime? localStartTime;
  final int? durationMinutes;
  final CalendarLocalDate? allDayEndDateExclusive;
  final IanaTimeZoneId? timeZone;
  final CalendarDstOverlapPolicy? overlapPolicy;
  final UtcInstant? startsAt;
  final UtcInstant? endsAt;
  final CalendarTimeResolutionKind? dstResolution;
  final int? utcOffsetSeconds;
  final List<CalendarEventParticipant> participants;
  final int version;
  final int occurrenceVersion;
  final CalendarRecurrenceRule? recurrenceRule;
  final CalendarLocalDate recurrenceLocalStartDate;
  final int revisionNumber;
  final bool isException;

  bool get isRecurring => recurrenceRule != null;

  CalendarAllDayRange? get allDayRange {
    final CalendarLocalDate? end = allDayEndDateExclusive;
    return !isAllDay || end == null
        ? null
        : CalendarAllDayRange.tryCreate(
            startDate: localStartDate,
            endDateExclusive: end,
          );
  }

  static OneTimeCalendarEvent? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required String title,
    required String? description,
    required bool isAllDay,
    required CalendarLocalDate localStartDate,
    required CalendarLocalTime? localStartTime,
    required int? durationMinutes,
    required CalendarLocalDate? allDayEndDateExclusive,
    required IanaTimeZoneId? timeZone,
    required CalendarDstOverlapPolicy? overlapPolicy,
    required UtcInstant? startsAt,
    required UtcInstant? endsAt,
    required CalendarTimeResolutionKind? dstResolution,
    required int? utcOffsetSeconds,
    required List<CalendarEventParticipant> participants,
    required int version,
    required int occurrenceVersion,
    CalendarRecurrenceRule? recurrenceRule,
    CalendarLocalDate? recurrenceLocalStartDate,
    int revisionNumber = 1,
    bool isException = false,
  }) {
    final String normalizedTitle = title.trim();
    final String? normalizedDescription = description?.trim();
    final Set<HouseholdMemberId> participantIds = participants
        .map((CalendarEventParticipant participant) => participant.memberId)
        .toSet();
    if (normalizedTitle.isEmpty ||
        normalizedTitle != title ||
        normalizedTitle.length > 200 ||
        _containsControlCharacter(normalizedTitle) ||
        (description != null &&
            (normalizedDescription != description ||
                normalizedDescription!.isEmpty ||
                normalizedDescription.length > 8000)) ||
        participants.isEmpty ||
        participants.length > 50 ||
        participantIds.length != participants.length ||
        version < 1 ||
        occurrenceVersion < 1 ||
        revisionNumber < 1 ||
        isException && recurrenceRule == null) {
      return null;
    }
    final CalendarLocalDate recurrenceDate =
        recurrenceLocalStartDate ?? localStartDate;
    if (recurrenceRule != null && !recurrenceRule.startsOn(recurrenceDate)) {
      return null;
    }
    final bool validAllDay =
        isAllDay &&
        localStartTime == null &&
        durationMinutes == null &&
        allDayEndDateExclusive != null &&
        CalendarAllDayRange.tryCreate(
              startDate: localStartDate,
              endDateExclusive: allDayEndDateExclusive,
            ) !=
            null &&
        timeZone == null &&
        overlapPolicy == null &&
        startsAt == null &&
        endsAt == null &&
        dstResolution == null &&
        utcOffsetSeconds == null;
    final bool validTimed =
        !isAllDay &&
        localStartTime != null &&
        durationMinutes != null &&
        durationMinutes >= 1 &&
        durationMinutes <= 10080 &&
        allDayEndDateExclusive == null &&
        timeZone != null &&
        overlapPolicy != null &&
        startsAt != null &&
        endsAt != null &&
        endsAt.compareTo(startsAt) > 0 &&
        endsAt.dateTime.difference(startsAt.dateTime) ==
            Duration(minutes: durationMinutes) &&
        dstResolution != null &&
        _resolutionMatchesOverlapPolicy(dstResolution, overlapPolicy) &&
        utcOffsetSeconds != null &&
        utcOffsetSeconds >= -57600 &&
        utcOffsetSeconds <= 57600;
    if (!validAllDay && !validTimed) {
      return null;
    }
    return OneTimeCalendarEvent._(
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      title: normalizedTitle,
      description: normalizedDescription,
      isAllDay: isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      startsAt: startsAt,
      endsAt: endsAt,
      dstResolution: dstResolution,
      utcOffsetSeconds: utcOffsetSeconds,
      participants: participants,
      version: version,
      occurrenceVersion: occurrenceVersion,
      recurrenceRule: recurrenceRule,
      recurrenceLocalStartDate: recurrenceDate,
      revisionNumber: revisionNumber,
      isException: isException,
    );
  }
}

final class OneTimeCalendarEventList {
  OneTimeCalendarEventList._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required List<OneTimeCalendarEvent> events,
  }) : events = List<OneTimeCalendarEvent>.unmodifiable(events);

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final List<OneTimeCalendarEvent> events;

  static OneTimeCalendarEventList? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required List<OneTimeCalendarEvent> events,
  }) {
    if (events.length > 100 ||
        events.any(
          (OneTimeCalendarEvent event) => event.householdId != householdId,
        )) {
      return null;
    }
    for (var index = 1; index < events.length; index += 1) {
      if (compareOneTimeCalendarEvents(events[index - 1], events[index]) >= 0) {
        return null;
      }
    }
    return OneTimeCalendarEventList._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      events: events,
    );
  }

  OneTimeCalendarEventList apply(OneTimeCalendarEvent event) {
    final List<OneTimeCalendarEvent> updated =
        events
            .where(
              (OneTimeCalendarEvent item) => item.seriesId != event.seriesId,
            )
            .toList(growable: true)
          ..add(event)
          ..sort(compareOneTimeCalendarEvents);
    final List<OneTimeCalendarEvent> bounded = updated.length <= 100
        ? updated
        : updated.take(100).toList(growable: false);
    return OneTimeCalendarEventList._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      events: bounded,
    );
  }

  OneTimeCalendarEventList remove(CalendarEventSeriesId seriesId) {
    return OneTimeCalendarEventList._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      events: events
          .where((OneTimeCalendarEvent item) => item.seriesId != seriesId)
          .toList(growable: false),
    );
  }

  OneTimeCalendarEventList applyOccurrence(OneTimeCalendarEvent event) {
    final List<OneTimeCalendarEvent> updated =
        events
            .where(
              (OneTimeCalendarEvent item) =>
                  item.occurrenceId != event.occurrenceId,
            )
            .toList(growable: true)
          ..add(event)
          ..sort(compareOneTimeCalendarEvents);
    return OneTimeCalendarEventList._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      events: updated,
    );
  }

  OneTimeCalendarEventList removeOccurrence(
    CalendarEventOccurrenceId occurrenceId,
  ) {
    return OneTimeCalendarEventList._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      events: events
          .where(
            (OneTimeCalendarEvent item) => item.occurrenceId != occurrenceId,
          )
          .toList(growable: false),
    );
  }
}

int compareOneTimeCalendarEvents(
  OneTimeCalendarEvent left,
  OneTimeCalendarEvent right,
) {
  final int date = left.localStartDate.compareTo(right.localStartDate);
  if (date != 0) {
    return date;
  }
  final CalendarLocalTime? leftTime = left.localStartTime;
  final CalendarLocalTime? rightTime = right.localStartTime;
  if (leftTime == null && rightTime != null) {
    return -1;
  }
  if (leftTime != null && rightTime == null) {
    return 1;
  }
  if (leftTime != null && rightTime != null) {
    final int time = leftTime.compareTo(rightTime);
    if (time != 0) {
      return time;
    }
  }
  final int title = left.title.toLowerCase().compareTo(
    right.title.toLowerCase(),
  );
  if (title != 0) {
    return title;
  }
  final int series = left.seriesId.value.compareTo(right.seriesId.value);
  return series != 0
      ? series
      : left.occurrenceId.value.compareTo(right.occurrenceId.value);
}

bool _containsControlCharacter(String value) {
  return value.codeUnits.any(
    (int codeUnit) => codeUnit < 32 || codeUnit == 127,
  );
}

bool _resolutionMatchesOverlapPolicy(
  CalendarTimeResolutionKind resolution,
  CalendarDstOverlapPolicy policy,
) {
  return switch (resolution) {
    CalendarTimeResolutionKind.normal => true,
    CalendarTimeResolutionKind.overlapEarlier =>
      policy == CalendarDstOverlapPolicy.earlier,
    CalendarTimeResolutionKind.overlapLater =>
      policy == CalendarDstOverlapPolicy.later,
  };
}
