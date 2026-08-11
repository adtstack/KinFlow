import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum CalendarImportParseFailureKind {
  tooLarge,
  tooManyEvents,
  invalidStructure,
  unsupportedVersion,
}

sealed class CalendarImportParseResult {
  const CalendarImportParseResult();
}

final class CalendarImportParsed extends CalendarImportParseResult {
  const CalendarImportParsed(this.document);

  final CalendarImportDocument document;
}

final class CalendarImportParseFailed extends CalendarImportParseResult {
  const CalendarImportParseFailed(this.kind);

  final CalendarImportParseFailureKind kind;
}

final class CalendarImportDocument {
  CalendarImportDocument({
    required List<CalendarImportCandidate> candidates,
    required this.invalidEventCount,
    required this.unsupportedEventCount,
    required this.duplicateEventCount,
  }) : candidates = List<CalendarImportCandidate>.unmodifiable(candidates);

  final List<CalendarImportCandidate> candidates;
  final int invalidEventCount;
  final int unsupportedEventCount;
  final int duplicateEventCount;

  int get skippedEventCount =>
      invalidEventCount + unsupportedEventCount + duplicateEventCount;

  int get totalEventCount => candidates.length + skippedEventCount;
}

final class CalendarImportCandidate {
  const CalendarImportCandidate._({
    required this.sourceIndex,
    required this.title,
    required this.description,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timeZone,
    required this.overlapPolicy,
    required this.recurrenceRule,
    required this.usesHouseholdTimeZone,
    required this.usesOverlapEarlier,
  });

  final int sourceIndex;
  final String title;
  final String? description;
  final bool isAllDay;
  final CalendarLocalDate localStartDate;
  final CalendarLocalTime? localStartTime;
  final int? durationMinutes;
  final CalendarLocalDate? allDayEndDateExclusive;
  final IanaTimeZoneId? timeZone;
  final CalendarDstOverlapPolicy? overlapPolicy;
  final CalendarRecurrenceRule? recurrenceRule;
  final bool usesHouseholdTimeZone;
  final bool usesOverlapEarlier;

  static CalendarImportCandidate? tryCreate({
    required int sourceIndex,
    required String title,
    required String? description,
    required bool isAllDay,
    required CalendarLocalDate localStartDate,
    required CalendarLocalTime? localStartTime,
    required int? durationMinutes,
    required CalendarLocalDate? allDayEndDateExclusive,
    required IanaTimeZoneId? timeZone,
    required CalendarDstOverlapPolicy? overlapPolicy,
    required CalendarRecurrenceRule? recurrenceRule,
    required bool usesHouseholdTimeZone,
    required bool usesOverlapEarlier,
  }) {
    if (sourceIndex < 0 ||
        title.trim() != title ||
        title.isEmpty ||
        title.length > 200 ||
        title.codeUnits.any((int unit) => unit < 32 || unit == 127) ||
        description != null &&
            (description.trim() != description ||
                description.isEmpty ||
                description.length > 8000 ||
                description.codeUnits.any(
                  (int unit) => unit < 32 && unit != 10 || unit == 127,
                ))) {
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
        !usesHouseholdTimeZone &&
        !usesOverlapEarlier;
    final bool validTimed =
        !isAllDay &&
        localStartTime != null &&
        durationMinutes != null &&
        durationMinutes >= 1 &&
        durationMinutes <= 10080 &&
        allDayEndDateExclusive == null &&
        timeZone != null &&
        overlapPolicy != null;
    if (!validAllDay && !validTimed) return null;
    if (recurrenceRule != null &&
        (!recurrenceRule.startsOn(localStartDate) ||
            recurrenceRule.end is CalendarRecurrenceUntilEnd &&
                (recurrenceRule.end as CalendarRecurrenceUntilEnd).localDate
                        .compareTo(localStartDate) <
                    0)) {
      return null;
    }
    return CalendarImportCandidate._(
      sourceIndex: sourceIndex,
      title: title,
      description: description,
      isAllDay: isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      recurrenceRule: recurrenceRule,
      usesHouseholdTimeZone: usesHouseholdTimeZone,
      usesOverlapEarlier: usesOverlapEarlier,
    );
  }

  OneTimeCalendarEventDraft? createEventDraft({
    required HouseholdId householdId,
    required Iterable<HouseholdMemberId> participantMemberIds,
  }) {
    return OneTimeCalendarEventDraft.tryCreate(
      householdId: householdId,
      title: title,
      description: description ?? '',
      isAllDay: isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      participantMemberIds: participantMemberIds,
    );
  }

  RecurringCalendarEventDraft? createRecurringDraft({
    required HouseholdId householdId,
    required Iterable<HouseholdMemberId> participantMemberIds,
  }) {
    final CalendarRecurrenceRule? rule = recurrenceRule;
    final OneTimeCalendarEventDraft? event = createEventDraft(
      householdId: householdId,
      participantMemberIds: participantMemberIds,
    );
    return rule == null || event == null
        ? null
        : RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: rule,
          );
  }
}
