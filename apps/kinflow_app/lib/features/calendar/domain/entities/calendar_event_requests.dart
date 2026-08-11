import 'dart:convert';

import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class OneTimeCalendarEventDraft {
  OneTimeCalendarEventDraft._({
    required this.householdId,
    required this.title,
    required this.description,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timeZone,
    required this.overlapPolicy,
    required List<HouseholdMemberId> participantMemberIds,
  }) : participantMemberIds = List<HouseholdMemberId>.unmodifiable(
         participantMemberIds,
       );

  final HouseholdId householdId;
  final String title;
  final String? description;
  final bool isAllDay;
  final CalendarLocalDate localStartDate;
  final CalendarLocalTime? localStartTime;
  final int? durationMinutes;
  final CalendarLocalDate? allDayEndDateExclusive;
  final IanaTimeZoneId? timeZone;
  final CalendarDstOverlapPolicy? overlapPolicy;
  final List<HouseholdMemberId> participantMemberIds;

  CalendarZonedDateTimeIntent? get timedIntent {
    final CalendarLocalTime? time = localStartTime;
    final IanaTimeZoneId? zone = timeZone;
    final CalendarDstOverlapPolicy? overlap = overlapPolicy;
    return isAllDay || time == null || zone == null || overlap == null
        ? null
        : CalendarZonedDateTimeIntent.create(
            localDate: localStartDate,
            localTime: time,
            timeZone: zone,
            overlapPolicy: overlap,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'householdId': householdId.value,
    'title': title,
    'description': description,
    'isAllDay': isAllDay,
    'localStartDate': localStartDate.value,
    'localStartTime': localStartTime?.value,
    'durationMinutes': durationMinutes,
    'allDayEndDateExclusive': allDayEndDateExclusive?.value,
    'timezone': timeZone?.value,
    'overlapPolicy': overlapPolicy?.wireValue,
    'participantMemberIds': participantMemberIds
        .map((HouseholdMemberId id) => id.value)
        .toList(growable: false),
  });

  static OneTimeCalendarEventDraft? tryCreate({
    required HouseholdId householdId,
    required String title,
    required String description,
    required bool isAllDay,
    required CalendarLocalDate localStartDate,
    required CalendarLocalTime? localStartTime,
    required int? durationMinutes,
    required CalendarLocalDate? allDayEndDateExclusive,
    required IanaTimeZoneId? timeZone,
    required CalendarDstOverlapPolicy? overlapPolicy,
    required Iterable<HouseholdMemberId> participantMemberIds,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    final List<HouseholdMemberId> participants =
        participantMemberIds.toList(growable: false)..sort(
          (HouseholdMemberId left, HouseholdMemberId right) =>
              left.value.compareTo(right.value),
        );
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 200 ||
        _containsDraftControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 8000 ||
        participants.isEmpty ||
        participants.length > 50 ||
        participants.toSet().length != participants.length) {
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
    return OneTimeCalendarEventDraft._(
      householdId: householdId,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      isAllDay: isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      participantMemberIds: participants,
    );
  }

  CreateOneTimeCalendarEventRequest createRequest(
    CalendarEventCommandId idempotencyKey,
  ) {
    return CreateOneTimeCalendarEventRequest._(
      idempotencyKey: idempotencyKey,
      draft: this,
    );
  }

  UpdateOneTimeCalendarEventRequest updateRequest({
    required CalendarEventCommandId idempotencyKey,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required int expectedVersion,
  }) {
    return UpdateOneTimeCalendarEventRequest._(
      idempotencyKey: idempotencyKey,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      draft: this,
    );
  }

  UpdateRecurringCalendarOccurrenceRequest updateOccurrenceRequest({
    required CalendarEventCommandId idempotencyKey,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required int expectedOccurrenceVersion,
  }) {
    return UpdateRecurringCalendarOccurrenceRequest._(
      idempotencyKey: idempotencyKey,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
      draft: this,
    );
  }
}

final class CreateOneTimeCalendarEventRequest {
  const CreateOneTimeCalendarEventRequest._({
    required this.idempotencyKey,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final OneTimeCalendarEventDraft draft;
}

final class UpdateOneTimeCalendarEventRequest {
  const UpdateOneTimeCalendarEventRequest._({
    required this.idempotencyKey,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final int expectedVersion;
  final OneTimeCalendarEventDraft draft;
}

final class DeleteOneTimeCalendarEventRequest {
  const DeleteOneTimeCalendarEventRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedVersion,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final int expectedVersion;
}

final class UpdateRecurringCalendarOccurrenceRequest {
  const UpdateRecurringCalendarOccurrenceRequest._({
    required this.idempotencyKey,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedOccurrenceVersion,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final int expectedOccurrenceVersion;
  final OneTimeCalendarEventDraft draft;
}

final class CancelRecurringCalendarOccurrenceRequest {
  const CancelRecurringCalendarOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedOccurrenceVersion,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final int expectedOccurrenceVersion;
}

final class RecurringCalendarOccurrenceCommandSnapshot {
  const RecurringCalendarOccurrenceCommandSnapshot._({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.revisionId,
    required this.occurrenceVersion,
    required this.exceptionVersion,
    required this.cancelled,
    required this.changed,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final CalendarEventRevisionId? revisionId;
  final int occurrenceVersion;
  final int exceptionVersion;
  final bool cancelled;
  final bool changed;

  static RecurringCalendarOccurrenceCommandSnapshot? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required CalendarEventRevisionId? revisionId,
    required int occurrenceVersion,
    required int exceptionVersion,
    required bool cancelled,
    required bool changed,
  }) {
    if (occurrenceVersion < 1 ||
        exceptionVersion < 1 ||
        !cancelled && revisionId == null) {
      return null;
    }
    return RecurringCalendarOccurrenceCommandSnapshot._(
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      revisionId: revisionId,
      occurrenceVersion: occurrenceVersion,
      exceptionVersion: exceptionVersion,
      cancelled: cancelled,
      changed: changed,
    );
  }
}

bool _containsDraftControlCharacter(String value) {
  return value.codeUnits.any(
    (int codeUnit) => codeUnit < 32 || codeUnit == 127,
  );
}
