import 'dart:convert';

import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

const int calendarOverlapPreviewLimit = 10;

final class CalendarOverlapPreviewRequest {
  CalendarOverlapPreviewRequest._({
    required this.householdId,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timeZone,
    required this.overlapPolicy,
    required this.recurrenceRule,
    required this.windowStartDate,
    required List<HouseholdMemberId> participantMemberIds,
    required this.excludedSeriesId,
    required this.excludedOccurrenceId,
  }) : participantMemberIds = List<HouseholdMemberId>.unmodifiable(
         participantMemberIds,
       );

  final HouseholdId householdId;
  final bool isAllDay;
  final CalendarLocalDate localStartDate;
  final CalendarLocalTime? localStartTime;
  final int? durationMinutes;
  final CalendarLocalDate? allDayEndDateExclusive;
  final IanaTimeZoneId? timeZone;
  final CalendarDstOverlapPolicy? overlapPolicy;
  final CalendarRecurrenceRule? recurrenceRule;
  final CalendarLocalDate windowStartDate;
  final List<HouseholdMemberId> participantMemberIds;
  final CalendarEventSeriesId? excludedSeriesId;
  final CalendarEventOccurrenceId? excludedOccurrenceId;

  String get fingerprint => jsonEncode(<String, Object?>{
    'householdId': householdId.value,
    'isAllDay': isAllDay,
    'localStartDate': localStartDate.value,
    'localStartTime': localStartTime?.value,
    'durationMinutes': durationMinutes,
    'allDayEndDateExclusive': allDayEndDateExclusive?.value,
    'timezone': timeZone?.value,
    'overlapPolicy': overlapPolicy?.wireValue,
    'recurrenceRule': recurrenceRule?.toJson(),
    'windowStartDate': windowStartDate.value,
    'participantMemberIds': participantMemberIds
        .map((HouseholdMemberId id) => id.value)
        .toList(growable: false),
    'excludedSeriesId': excludedSeriesId?.value,
    'excludedOccurrenceId': excludedOccurrenceId?.value,
    'limit': calendarOverlapPreviewLimit,
  });

  static CalendarOverlapPreviewRequest? tryCreate({
    required HouseholdId householdId,
    required bool isAllDay,
    required CalendarLocalDate localStartDate,
    required CalendarLocalTime? localStartTime,
    required int? durationMinutes,
    required CalendarLocalDate? allDayEndDateExclusive,
    required IanaTimeZoneId? timeZone,
    required CalendarDstOverlapPolicy? overlapPolicy,
    required CalendarRecurrenceRule? recurrenceRule,
    required CalendarLocalDate windowStartDate,
    required Iterable<HouseholdMemberId> participantMemberIds,
    required CalendarEventSeriesId? excludedSeriesId,
    required CalendarEventOccurrenceId? excludedOccurrenceId,
  }) {
    final List<HouseholdMemberId> participants =
        participantMemberIds.toList(growable: false)..sort(
          (HouseholdMemberId left, HouseholdMemberId right) =>
              left.value.compareTo(right.value),
        );
    if (participants.isEmpty ||
        participants.length > 50 ||
        participants.toSet().length != participants.length ||
        excludedSeriesId != null && excludedOccurrenceId != null) {
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
        overlapPolicy == null;
    final bool validTimed =
        !isAllDay &&
        localStartTime != null &&
        durationMinutes != null &&
        durationMinutes >= 1 &&
        durationMinutes <= 10080 &&
        allDayEndDateExclusive == null &&
        timeZone != null &&
        overlapPolicy != null;
    if (!validAllDay && !validTimed) {
      return null;
    }
    if (recurrenceRule == null) {
      if (windowStartDate != localStartDate) {
        return null;
      }
    } else {
      final CalendarRecurrenceEnd end = recurrenceRule.end;
      if (!recurrenceRule.startsOn(localStartDate) ||
          end is CalendarRecurrenceUntilEnd &&
              end.localDate.compareTo(localStartDate) < 0) {
        return null;
      }
    }
    return CalendarOverlapPreviewRequest._(
      householdId: householdId,
      isAllDay: isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      recurrenceRule: recurrenceRule,
      windowStartDate: windowStartDate,
      participantMemberIds: participants,
      excludedSeriesId: excludedSeriesId,
      excludedOccurrenceId: excludedOccurrenceId,
    );
  }
}

final class CalendarOverlapParticipant {
  const CalendarOverlapParticipant._({
    required this.memberId,
    required this.displayName,
  });

  final HouseholdMemberId memberId;
  final String displayName;

  static CalendarOverlapParticipant? tryCreate({
    required HouseholdMemberId memberId,
    required String displayName,
  }) {
    final String normalized = displayName.trim();
    return normalized.isEmpty ||
            normalized.length > 80 ||
            normalized != displayName
        ? null
        : CalendarOverlapParticipant._(
            memberId: memberId,
            displayName: normalized,
          );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarOverlapParticipant &&
        other.memberId == memberId &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(memberId, displayName);
}

final class CalendarOverlapConflict {
  CalendarOverlapConflict._({
    required this.candidateLocalStartDate,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.isAllDay,
    required this.viewLocalStartDate,
    required this.viewLocalStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required List<CalendarOverlapParticipant> participants,
  }) : participants = List<CalendarOverlapParticipant>.unmodifiable(
         participants,
       );

  final CalendarLocalDate candidateLocalStartDate;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final String title;
  final bool isAllDay;
  final CalendarLocalDate viewLocalStartDate;
  final CalendarLocalTime? viewLocalStartTime;
  final int? durationMinutes;
  final CalendarLocalDate? allDayEndDateExclusive;
  final List<CalendarOverlapParticipant> participants;

  static CalendarOverlapConflict? tryCreate({
    required CalendarLocalDate candidateLocalStartDate,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required String title,
    required bool isAllDay,
    required CalendarLocalDate viewLocalStartDate,
    required CalendarLocalTime? viewLocalStartTime,
    required int? durationMinutes,
    required CalendarLocalDate? allDayEndDateExclusive,
    required List<CalendarOverlapParticipant> participants,
  }) {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle != title ||
        normalizedTitle.length > 200 ||
        participants.isEmpty ||
        participants.length > 50 ||
        participants
                .map((CalendarOverlapParticipant item) => item.memberId)
                .toSet()
                .length !=
            participants.length) {
      return null;
    }
    for (var index = 1; index < participants.length; index += 1) {
      if (participants[index - 1].memberId.value.compareTo(
            participants[index].memberId.value,
          ) >=
          0) {
        return null;
      }
    }
    final bool validAllDay =
        isAllDay &&
        viewLocalStartTime == null &&
        durationMinutes == null &&
        allDayEndDateExclusive != null &&
        CalendarAllDayRange.tryCreate(
              startDate: viewLocalStartDate,
              endDateExclusive: allDayEndDateExclusive,
            ) !=
            null;
    final bool validTimed =
        !isAllDay &&
        viewLocalStartTime != null &&
        durationMinutes != null &&
        durationMinutes >= 1 &&
        durationMinutes <= 10080 &&
        allDayEndDateExclusive == null;
    if (!validAllDay && !validTimed) {
      return null;
    }
    return CalendarOverlapConflict._(
      candidateLocalStartDate: candidateLocalStartDate,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      title: normalizedTitle,
      isAllDay: isAllDay,
      viewLocalStartDate: viewLocalStartDate,
      viewLocalStartTime: viewLocalStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      participants: participants,
    );
  }
}

final class CalendarOverlapPreview {
  CalendarOverlapPreview._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.checkedFromLocalDate,
    required this.checkedThroughLocalDate,
    required this.candidateOccurrenceCount,
    required this.totalConflictCount,
    required this.truncated,
    required List<CalendarOverlapConflict> conflicts,
  }) : conflicts = List<CalendarOverlapConflict>.unmodifiable(conflicts);

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final UtcInstant generatedAt;
  final CalendarLocalDate checkedFromLocalDate;
  final CalendarLocalDate checkedThroughLocalDate;
  final int candidateOccurrenceCount;
  final int totalConflictCount;
  final bool truncated;
  final List<CalendarOverlapConflict> conflicts;

  bool get hasConflicts => totalConflictCount > 0;

  static CalendarOverlapPreview? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required UtcInstant generatedAt,
    required CalendarLocalDate checkedFromLocalDate,
    required CalendarLocalDate checkedThroughLocalDate,
    required int candidateOccurrenceCount,
    required int totalConflictCount,
    required bool truncated,
    required List<CalendarOverlapConflict> conflicts,
  }) {
    if (checkedThroughLocalDate.compareTo(checkedFromLocalDate) < 0 ||
        candidateOccurrenceCount < 0 ||
        candidateOccurrenceCount > 366 ||
        totalConflictCount < conflicts.length ||
        conflicts.length > calendarOverlapPreviewLimit ||
        truncated != (totalConflictCount > conflicts.length) ||
        totalConflictCount == 0 && conflicts.isNotEmpty) {
      return null;
    }
    final Set<String> pairKeys = <String>{};
    for (var index = 0; index < conflicts.length; index += 1) {
      final CalendarOverlapConflict conflict = conflicts[index];
      final String pairKey =
          '${conflict.candidateLocalStartDate.value}:'
          '${conflict.occurrenceId.value}';
      if (conflict.candidateLocalStartDate.compareTo(checkedFromLocalDate) <
              0 ||
          conflict.candidateLocalStartDate.compareTo(checkedThroughLocalDate) >
              0 ||
          !pairKeys.add(pairKey)) {
        return null;
      }
      if (index > 0 &&
          compareCalendarOverlapConflicts(conflicts[index - 1], conflict) >=
              0) {
        return null;
      }
    }
    return CalendarOverlapPreview._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      checkedFromLocalDate: checkedFromLocalDate,
      checkedThroughLocalDate: checkedThroughLocalDate,
      candidateOccurrenceCount: candidateOccurrenceCount,
      totalConflictCount: totalConflictCount,
      truncated: truncated,
      conflicts: conflicts,
    );
  }
}

int compareCalendarOverlapConflicts(
  CalendarOverlapConflict left,
  CalendarOverlapConflict right,
) {
  int result = left.candidateLocalStartDate.compareTo(
    right.candidateLocalStartDate,
  );
  if (result != 0) {
    return result;
  }
  result = left.viewLocalStartDate.compareTo(right.viewLocalStartDate);
  if (result != 0) {
    return result;
  }
  final CalendarLocalTime? leftTime = left.viewLocalStartTime;
  final CalendarLocalTime? rightTime = right.viewLocalStartTime;
  if (leftTime == null && rightTime != null) {
    return -1;
  }
  if (leftTime != null && rightTime == null) {
    return 1;
  }
  if (leftTime != null && rightTime != null) {
    result = leftTime.compareTo(rightTime);
    if (result != 0) {
      return result;
    }
  }
  return left.occurrenceId.value.compareTo(right.occurrenceId.value);
}
