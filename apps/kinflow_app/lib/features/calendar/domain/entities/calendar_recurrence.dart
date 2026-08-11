import 'dart:convert';

import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum CalendarRecurrenceFrequency {
  daily,
  weekly,
  monthly;

  String get wireValue => name;

  static CalendarRecurrenceFrequency? tryParse(String value) {
    return switch (value) {
      'daily' => CalendarRecurrenceFrequency.daily,
      'weekly' => CalendarRecurrenceFrequency.weekly,
      'monthly' => CalendarRecurrenceFrequency.monthly,
      _ => null,
    };
  }
}

enum CalendarWeekday {
  monday('MO', DateTime.monday),
  tuesday('TU', DateTime.tuesday),
  wednesday('WE', DateTime.wednesday),
  thursday('TH', DateTime.thursday),
  friday('FR', DateTime.friday),
  saturday('SA', DateTime.saturday),
  sunday('SU', DateTime.sunday);

  const CalendarWeekday(this.wireValue, this.dateTimeValue);

  final String wireValue;
  final int dateTimeValue;

  static CalendarWeekday? tryParse(String value) {
    for (final CalendarWeekday weekday in values) {
      if (weekday.wireValue == value) {
        return weekday;
      }
    }
    return null;
  }

  static CalendarWeekday fromDate(CalendarLocalDate value) {
    return values.firstWhere(
      (CalendarWeekday weekday) => weekday.dateTimeValue == value.weekday,
    );
  }
}

sealed class CalendarRecurrenceEnd {
  const CalendarRecurrenceEnd();

  Map<String, Object?> toJson();

  static CalendarRecurrenceEnd? tryParse(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null || value['type'] is! String) {
      return null;
    }
    return switch (value['type']) {
      'never' when _hasExactKeys(value, const <String>{'type'}) =>
        const CalendarRecurrenceNeverEnds(),
      'count'
          when _hasExactKeys(value, const <String>{'type', 'count'}) &&
              value['count'] is int &&
              (value['count']! as int) >= 1 &&
              (value['count']! as int) <= 1000 =>
        CalendarRecurrenceCountEnd(value['count']! as int),
      'until'
          when _hasExactKeys(value, const <String>{'type', 'localDate'}) &&
              value['localDate'] is String =>
        _untilEnd(value['localDate']! as String),
      _ => null,
    };
  }
}

final class CalendarRecurrenceNeverEnds extends CalendarRecurrenceEnd {
  const CalendarRecurrenceNeverEnds();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{'type': 'never'};

  @override
  bool operator ==(Object other) => other is CalendarRecurrenceNeverEnds;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class CalendarRecurrenceCountEnd extends CalendarRecurrenceEnd {
  const CalendarRecurrenceCountEnd(this.count);

  final int count;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'count',
    'count': count,
  };

  @override
  bool operator ==(Object other) {
    return other is CalendarRecurrenceCountEnd && other.count == count;
  }

  @override
  int get hashCode => Object.hash(runtimeType, count);
}

final class CalendarRecurrenceUntilEnd extends CalendarRecurrenceEnd {
  const CalendarRecurrenceUntilEnd(this.localDate);

  final CalendarLocalDate localDate;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'until',
    'localDate': localDate.value,
  };

  @override
  bool operator ==(Object other) {
    return other is CalendarRecurrenceUntilEnd && other.localDate == localDate;
  }

  @override
  int get hashCode => Object.hash(runtimeType, localDate);
}

final class CalendarRecurrenceRule {
  CalendarRecurrenceRule._({
    required this.frequency,
    required this.interval,
    required List<CalendarWeekday> weekdays,
    required this.monthDay,
    required this.end,
  }) : weekdays = List<CalendarWeekday>.unmodifiable(weekdays);

  final CalendarRecurrenceFrequency frequency;
  final int interval;
  final List<CalendarWeekday> weekdays;
  final int? monthDay;
  final CalendarRecurrenceEnd end;

  static CalendarRecurrenceRule anchored({
    required CalendarRecurrenceFrequency frequency,
    required CalendarLocalDate startLocalDate,
  }) => tryAnchored(
    frequency: frequency,
    startLocalDate: startLocalDate,
    interval: 1,
    end: const CalendarRecurrenceNeverEnds(),
  )!;

  static CalendarRecurrenceRule? tryAnchored({
    required CalendarRecurrenceFrequency frequency,
    required CalendarLocalDate startLocalDate,
    required int interval,
    required CalendarRecurrenceEnd end,
  }) {
    if (!_validIntervalAndEnd(
      interval: interval,
      end: end,
      minimumLocalDate: startLocalDate,
    )) {
      return null;
    }
    return CalendarRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: frequency == CalendarRecurrenceFrequency.weekly
          ? <CalendarWeekday>[CalendarWeekday.fromDate(startLocalDate)]
          : const <CalendarWeekday>[],
      monthDay: frequency == CalendarRecurrenceFrequency.monthly
          ? startLocalDate.day
          : null,
      end: end,
    );
  }

  CalendarRecurrenceRule? tryWithIntervalAndEnd({
    required int interval,
    required CalendarRecurrenceEnd end,
    required CalendarLocalDate minimumLocalDate,
  }) {
    if (!_validIntervalAndEnd(
      interval: interval,
      end: end,
      minimumLocalDate: minimumLocalDate,
    )) {
      return null;
    }
    return CalendarRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays,
      monthDay: monthDay,
      end: end,
    );
  }

  CalendarRecurrenceRule? tryWithWeeklyWeekdays({
    required Iterable<CalendarWeekday> weekdays,
    required CalendarLocalDate sourceLocalDate,
    required int interval,
    required CalendarRecurrenceEnd end,
    required CalendarLocalDate minimumLocalDate,
  }) {
    if (frequency != CalendarRecurrenceFrequency.weekly ||
        !_validIntervalAndEnd(
          interval: interval,
          end: end,
          minimumLocalDate: minimumLocalDate,
        )) {
      return null;
    }
    final List<CalendarWeekday> provided = weekdays.toList(growable: false);
    final Set<CalendarWeekday> selected = provided.toSet();
    final CalendarWeekday anchor = CalendarWeekday.fromDate(sourceLocalDate);
    if (provided.isEmpty ||
        provided.length > CalendarWeekday.values.length ||
        selected.length != provided.length ||
        !selected.contains(anchor)) {
      return null;
    }
    final List<CalendarWeekday> canonical = CalendarWeekday.values
        .where(selected.contains)
        .toList(growable: false);
    return CalendarRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: canonical,
      monthDay: null,
      end: end,
    );
  }

  CalendarRecurrenceRule? tryWithMonthlyStartDate({
    required CalendarLocalDate sourceLocalDate,
    required int interval,
    required CalendarRecurrenceEnd end,
    required CalendarLocalDate minimumLocalDate,
  }) {
    if (frequency != CalendarRecurrenceFrequency.monthly ||
        !_validIntervalAndEnd(
          interval: interval,
          end: end,
          minimumLocalDate: minimumLocalDate,
        )) {
      return null;
    }
    return CalendarRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: const <CalendarWeekday>[],
      monthDay: sourceLocalDate.day,
      end: end,
    );
  }

  static CalendarRecurrenceRule? tryParse(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null ||
        value['frequency'] is! String ||
        value['interval'] is! int) {
      return null;
    }
    final CalendarRecurrenceFrequency? frequency =
        CalendarRecurrenceFrequency.tryParse(value['frequency']! as String);
    final int interval = value['interval']! as int;
    final CalendarRecurrenceEnd? end = CalendarRecurrenceEnd.tryParse(
      value['end'],
    );
    if (frequency == null || interval < 1 || interval > 30 || end == null) {
      return null;
    }

    return switch (frequency) {
      CalendarRecurrenceFrequency.daily =>
        _hasExactKeys(value, const <String>{'frequency', 'interval', 'end'})
            ? CalendarRecurrenceRule._(
                frequency: frequency,
                interval: interval,
                weekdays: const <CalendarWeekday>[],
                monthDay: null,
                end: end,
              )
            : null,
      CalendarRecurrenceFrequency.weekly => _weeklyRule(
        value,
        frequency,
        interval,
        end,
      ),
      CalendarRecurrenceFrequency.monthly => _monthlyRule(
        value,
        frequency,
        interval,
        end,
      ),
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'frequency': frequency.wireValue,
    'interval': interval,
    if (frequency == CalendarRecurrenceFrequency.weekly)
      'weekdays': weekdays
          .map((CalendarWeekday weekday) => weekday.wireValue)
          .toList(growable: false),
    if (frequency == CalendarRecurrenceFrequency.monthly) 'monthDay': monthDay,
    'end': end.toJson(),
  };

  String get fingerprint => jsonEncode(toJson());

  bool startsOn(CalendarLocalDate date) {
    return switch (frequency) {
      CalendarRecurrenceFrequency.daily => true,
      CalendarRecurrenceFrequency.weekly => weekdays.contains(
        CalendarWeekday.fromDate(date),
      ),
      CalendarRecurrenceFrequency.monthly => monthDay == date.day,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarRecurrenceRule &&
        other.frequency == frequency &&
        other.interval == interval &&
        _listEquals(other.weekdays, weekdays) &&
        other.monthDay == monthDay &&
        other.end == end;
  }

  @override
  int get hashCode =>
      Object.hash(frequency, interval, Object.hashAll(weekdays), monthDay, end);
}

final class RecurringCalendarEventDraft {
  const RecurringCalendarEventDraft._({
    required this.event,
    required this.recurrenceRule,
  });

  final OneTimeCalendarEventDraft event;
  final CalendarRecurrenceRule recurrenceRule;

  HouseholdId get householdId => event.householdId;

  static RecurringCalendarEventDraft? tryCreate({
    required OneTimeCalendarEventDraft event,
    required CalendarRecurrenceRule recurrenceRule,
  }) {
    final CalendarRecurrenceEnd end = recurrenceRule.end;
    if (!recurrenceRule.startsOn(event.localStartDate) ||
        end is CalendarRecurrenceUntilEnd &&
            end.localDate.compareTo(event.localStartDate) < 0) {
      return null;
    }
    return RecurringCalendarEventDraft._(
      event: event,
      recurrenceRule: recurrenceRule,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'event': jsonDecode(event.fingerprint),
    'recurrenceRule': recurrenceRule.toJson(),
  });

  CreateRecurringCalendarEventRequest createRequest(
    CalendarEventCommandId idempotencyKey,
  ) {
    return CreateRecurringCalendarEventRequest(
      idempotencyKey: idempotencyKey,
      draft: this,
    );
  }
}

final class CreateRecurringCalendarEventRequest {
  const CreateRecurringCalendarEventRequest({
    required this.idempotencyKey,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final RecurringCalendarEventDraft draft;
}

final class RecurringCalendarEventSnapshot {
  const RecurringCalendarEventSnapshot._({
    required this.householdId,
    required this.seriesId,
    required this.firstOccurrenceId,
    required this.recurrenceRule,
    required this.materializedThrough,
    required this.materializedCount,
    required this.version,
    required this.created,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId firstOccurrenceId;
  final CalendarRecurrenceRule recurrenceRule;
  final CalendarLocalDate materializedThrough;
  final int materializedCount;
  final int version;
  final bool created;

  static RecurringCalendarEventSnapshot? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId firstOccurrenceId,
    required CalendarRecurrenceRule recurrenceRule,
    required CalendarLocalDate materializedThrough,
    required int materializedCount,
    required int version,
    required bool created,
  }) {
    return materializedCount < 1 || materializedCount > 366 || version < 1
        ? null
        : RecurringCalendarEventSnapshot._(
            householdId: householdId,
            seriesId: seriesId,
            firstOccurrenceId: firstOccurrenceId,
            recurrenceRule: recurrenceRule,
            materializedThrough: materializedThrough,
            materializedCount: materializedCount,
            version: version,
            created: created,
          );
  }
}

final class RecurringCalendarSeriesDetail {
  RecurringCalendarSeriesDetail._({
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.draft,
    required List<String> participantDisplayNames,
    required this.version,
  }) : participantDisplayNames = List<String>.unmodifiable(
         participantDisplayNames,
       );

  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final CalendarEventSeriesId seriesId;
  final CalendarEventRevisionId revisionId;
  final int revisionNumber;
  final RecurringCalendarEventDraft draft;
  final List<String> participantDisplayNames;
  final int version;

  HouseholdId get householdId => draft.householdId;

  static RecurringCalendarSeriesDetail? tryCreate({
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required CalendarEventSeriesId seriesId,
    required CalendarEventRevisionId revisionId,
    required int revisionNumber,
    required OneTimeCalendarEventDraft event,
    required CalendarRecurrenceRule recurrenceRule,
    required List<String> participantDisplayNames,
    required int version,
  }) {
    final RecurringCalendarEventDraft? draft =
        RecurringCalendarEventDraft.tryCreate(
          event: event,
          recurrenceRule: recurrenceRule,
        );
    if (draft == null ||
        revisionNumber < 1 ||
        version < 1 ||
        participantDisplayNames.length != event.participantMemberIds.length ||
        participantDisplayNames.any((String name) {
          final String normalized = name.trim();
          return normalized.isEmpty ||
              normalized != name ||
              normalized.length > 80;
        })) {
      return null;
    }
    return RecurringCalendarSeriesDetail._(
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      seriesId: seriesId,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      draft: draft,
      participantDisplayNames: participantDisplayNames,
      version: version,
    );
  }

  UpdateRecurringCalendarSeriesRequest updateRequest({
    required CalendarEventCommandId idempotencyKey,
    required RecurringCalendarEventDraft updatedDraft,
  }) {
    return UpdateRecurringCalendarSeriesRequest(
      idempotencyKey: idempotencyKey,
      seriesId: seriesId,
      expectedVersion: version,
      draft: updatedDraft,
    );
  }
}

final class UpdateRecurringCalendarSeriesRequest {
  const UpdateRecurringCalendarSeriesRequest({
    required this.idempotencyKey,
    required this.seriesId,
    required this.expectedVersion,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final CalendarEventSeriesId seriesId;
  final int expectedVersion;
  final RecurringCalendarEventDraft draft;
}

final class RecurringCalendarSeriesFromOccurrenceUpdateDraft {
  const RecurringCalendarSeriesFromOccurrenceUpdateDraft._({
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.effectiveLocalDate,
    required this.expectedVersion,
    required this.draft,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId effectiveOccurrenceId;
  final CalendarLocalDate effectiveLocalDate;
  final int expectedVersion;
  final RecurringCalendarEventDraft draft;

  static RecurringCalendarSeriesFromOccurrenceUpdateDraft? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId effectiveOccurrenceId,
    required CalendarLocalDate effectiveLocalDate,
    required CalendarLocalDate householdLocalDate,
    required int expectedVersion,
    required RecurringCalendarEventDraft draft,
  }) {
    final CalendarRecurrenceEnd end = draft.recurrenceRule.end;
    if (draft.householdId != householdId ||
        expectedVersion < 1 ||
        effectiveLocalDate.compareTo(householdLocalDate) < 0 ||
        draft.event.localStartDate.compareTo(effectiveLocalDate) < 0 ||
        end is CalendarRecurrenceUntilEnd &&
            end.localDate.compareTo(effectiveLocalDate) < 0) {
      return null;
    }
    return RecurringCalendarSeriesFromOccurrenceUpdateDraft._(
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      effectiveLocalDate: effectiveLocalDate,
      expectedVersion: expectedVersion,
      draft: draft,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'updateRecurringCalendarSeriesFromOccurrence',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'effectiveOccurrenceId': effectiveOccurrenceId.value,
    'effectiveLocalDate': effectiveLocalDate.value,
    'expectedVersion': expectedVersion,
    'draft': jsonDecode(draft.fingerprint),
  });

  UpdateRecurringCalendarSeriesFromOccurrenceRequest withId(
    CalendarEventCommandId idempotencyKey,
  ) {
    return UpdateRecurringCalendarSeriesFromOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      effectiveLocalDate: effectiveLocalDate,
      expectedVersion: expectedVersion,
      draft: draft,
    );
  }
}

final class UpdateRecurringCalendarSeriesFromOccurrenceRequest {
  const UpdateRecurringCalendarSeriesFromOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.effectiveLocalDate,
    required this.expectedVersion,
    required this.draft,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId effectiveOccurrenceId;
  final CalendarLocalDate effectiveLocalDate;
  final int expectedVersion;
  final RecurringCalendarEventDraft draft;
}

final class CancelRecurringCalendarSeriesRequest {
  const CancelRecurringCalendarSeriesRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.expectedVersion,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final int expectedVersion;
}

final class RecurringCalendarSeriesFromOccurrenceCancellationDraft {
  const RecurringCalendarSeriesFromOccurrenceCancellationDraft._({
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.effectiveLocalDate,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId effectiveOccurrenceId;
  final CalendarLocalDate effectiveLocalDate;
  final int expectedVersion;

  static RecurringCalendarSeriesFromOccurrenceCancellationDraft? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId effectiveOccurrenceId,
    required CalendarLocalDate effectiveLocalDate,
    required CalendarLocalDate householdLocalDate,
    required int expectedVersion,
  }) {
    if (expectedVersion < 1 ||
        effectiveLocalDate.compareTo(householdLocalDate) < 0) {
      return null;
    }
    return RecurringCalendarSeriesFromOccurrenceCancellationDraft._(
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      effectiveLocalDate: effectiveLocalDate,
      expectedVersion: expectedVersion,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'cancelRecurringCalendarSeriesFromOccurrence',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'effectiveOccurrenceId': effectiveOccurrenceId.value,
    'effectiveLocalDate': effectiveLocalDate.value,
    'expectedVersion': expectedVersion,
  });

  CancelRecurringCalendarSeriesFromOccurrenceRequest withId(
    CalendarEventCommandId idempotencyKey,
  ) {
    return CancelRecurringCalendarSeriesFromOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      effectiveLocalDate: effectiveLocalDate,
      expectedVersion: expectedVersion,
    );
  }
}

final class CancelRecurringCalendarSeriesFromOccurrenceRequest {
  const CancelRecurringCalendarSeriesFromOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.effectiveLocalDate,
    required this.expectedVersion,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId effectiveOccurrenceId;
  final CalendarLocalDate effectiveLocalDate;
  final int expectedVersion;
}

final class ResumeRecurringCalendarSeriesCancellationDraft {
  const ResumeRecurringCalendarSeriesCancellationDraft._({
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventCommandId cancellationIdempotencyKey;
  final int expectedVersion;

  static ResumeRecurringCalendarSeriesCancellationDraft? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarEventCommandId cancellationIdempotencyKey,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : ResumeRecurringCalendarSeriesCancellationDraft._(
            householdId: householdId,
            seriesId: seriesId,
            cancellationIdempotencyKey: cancellationIdempotencyKey,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'resumeRecurringCalendarSeriesCancellation',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'cancellationIdempotencyKey': cancellationIdempotencyKey.value,
    'expectedVersion': expectedVersion,
  });

  ResumeRecurringCalendarSeriesCancellationRequest withId(
    CalendarEventCommandId idempotencyKey,
  ) {
    return ResumeRecurringCalendarSeriesCancellationRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      cancellationIdempotencyKey: cancellationIdempotencyKey,
      expectedVersion: expectedVersion,
    );
  }
}

final class ResumeRecurringCalendarSeriesCancellationRequest {
  const ResumeRecurringCalendarSeriesCancellationRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.expectedVersion,
  });

  final CalendarEventCommandId idempotencyKey;
  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarEventCommandId cancellationIdempotencyKey;
  final int expectedVersion;
}

final class RecurringCalendarSeriesUpdateSnapshot {
  const RecurringCalendarSeriesUpdateSnapshot._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.effectiveLocalDate,
    required this.materializedThrough,
    required this.version,
    required this.rebuiltCount,
    required this.cancelledCount,
    required this.preservedExceptionCount,
    required this.changed,
  });

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final CalendarEventSeriesId seriesId;
  final CalendarEventRevisionId revisionId;
  final int revisionNumber;
  final CalendarLocalDate effectiveLocalDate;
  final CalendarLocalDate materializedThrough;
  final int version;
  final int rebuiltCount;
  final int cancelledCount;
  final int preservedExceptionCount;
  final bool changed;

  static RecurringCalendarSeriesUpdateSnapshot? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required CalendarEventSeriesId seriesId,
    required CalendarEventRevisionId revisionId,
    required int revisionNumber,
    required CalendarLocalDate effectiveLocalDate,
    required CalendarLocalDate materializedThrough,
    required int version,
    required int rebuiltCount,
    required int cancelledCount,
    required int preservedExceptionCount,
    required bool changed,
  }) {
    if (householdLocalDate.compareTo(effectiveLocalDate) > 0 ||
        materializedThrough.compareTo(effectiveLocalDate) < 0 ||
        revisionNumber < 1 ||
        version < 1 ||
        rebuiltCount < 0 ||
        cancelledCount < 0 ||
        preservedExceptionCount < 0) {
      return null;
    }
    return RecurringCalendarSeriesUpdateSnapshot._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      seriesId: seriesId,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      effectiveLocalDate: effectiveLocalDate,
      materializedThrough: materializedThrough,
      version: version,
      rebuiltCount: rebuiltCount,
      cancelledCount: cancelledCount,
      preservedExceptionCount: preservedExceptionCount,
      changed: changed,
    );
  }
}

final class RecurringCalendarSeriesCancellationSnapshot {
  const RecurringCalendarSeriesCancellationSnapshot._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedPastCount,
    required this.changed,
  });

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final CalendarEventSeriesId seriesId;
  final CalendarLocalDate effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedPastCount;
  final bool changed;

  static RecurringCalendarSeriesCancellationSnapshot? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required CalendarEventSeriesId seriesId,
    required CalendarLocalDate effectiveLocalDate,
    required int version,
    required int cancelledCount,
    required int preservedPastCount,
    required bool changed,
  }) {
    if (householdLocalDate != effectiveLocalDate ||
        version < 1 ||
        cancelledCount < 0 ||
        preservedPastCount < 0) {
      return null;
    }
    return RecurringCalendarSeriesCancellationSnapshot._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      seriesId: seriesId,
      effectiveLocalDate: effectiveLocalDate,
      version: version,
      cancelledCount: cancelledCount,
      preservedPastCount: preservedPastCount,
      changed: changed,
    );
  }
}

final class RecurringCalendarSeriesFromOccurrenceCancellationSnapshot {
  const RecurringCalendarSeriesFromOccurrenceCancellationSnapshot._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedPastCount,
    required this.terminalRevisionId,
    required this.terminalRevisionNumber,
    required this.changed,
  });

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final CalendarEventSeriesId seriesId;
  final CalendarLocalDate effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedPastCount;
  final CalendarEventRevisionId? terminalRevisionId;
  final int? terminalRevisionNumber;
  final bool changed;

  bool get retainsScheduledPrefix => terminalRevisionId != null;

  static RecurringCalendarSeriesFromOccurrenceCancellationSnapshot? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required CalendarEventSeriesId seriesId,
    required CalendarLocalDate effectiveLocalDate,
    required int version,
    required int cancelledCount,
    required int preservedPastCount,
    required CalendarEventRevisionId? terminalRevisionId,
    required int? terminalRevisionNumber,
    required bool changed,
  }) {
    if (effectiveLocalDate.compareTo(householdLocalDate) < 0 ||
        version < 1 ||
        cancelledCount < 1 ||
        preservedPastCount < 0 ||
        (terminalRevisionId == null) != (terminalRevisionNumber == null) ||
        terminalRevisionNumber != null && terminalRevisionNumber < 1) {
      return null;
    }
    return RecurringCalendarSeriesFromOccurrenceCancellationSnapshot._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      seriesId: seriesId,
      effectiveLocalDate: effectiveLocalDate,
      version: version,
      cancelledCount: cancelledCount,
      preservedPastCount: preservedPastCount,
      terminalRevisionId: terminalRevisionId,
      terminalRevisionNumber: terminalRevisionNumber,
      changed: changed,
    );
  }
}

final class RecurringCalendarSeriesCancellationResumeSnapshot {
  const RecurringCalendarSeriesCancellationResumeSnapshot._({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.restoredCount,
    required this.preservedPastCount,
    required this.revisionId,
    required this.revisionNumber,
    required this.changed,
  });

  final HouseholdId householdId;
  final CalendarEventSeriesId seriesId;
  final CalendarLocalDate effectiveLocalDate;
  final int version;
  final int restoredCount;
  final int preservedPastCount;
  final CalendarEventRevisionId revisionId;
  final int revisionNumber;
  final bool changed;

  static RecurringCalendarSeriesCancellationResumeSnapshot? tryCreate({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
    required CalendarLocalDate effectiveLocalDate,
    required int version,
    required int restoredCount,
    required int preservedPastCount,
    required CalendarEventRevisionId revisionId,
    required int revisionNumber,
    required bool changed,
  }) {
    if (version < 1 ||
        restoredCount < 1 ||
        preservedPastCount < 0 ||
        revisionNumber < 1) {
      return null;
    }
    return RecurringCalendarSeriesCancellationResumeSnapshot._(
      householdId: householdId,
      seriesId: seriesId,
      effectiveLocalDate: effectiveLocalDate,
      version: version,
      restoredCount: restoredCount,
      preservedPastCount: preservedPastCount,
      revisionId: revisionId,
      revisionNumber: revisionNumber,
      changed: changed,
    );
  }
}

bool _validIntervalAndEnd({
  required int interval,
  required CalendarRecurrenceEnd end,
  required CalendarLocalDate minimumLocalDate,
}) {
  if (interval < 1 || interval > 30) {
    return false;
  }
  return switch (end) {
    CalendarRecurrenceNeverEnds() => true,
    CalendarRecurrenceCountEnd(:final count) => count >= 1 && count <= 1000,
    CalendarRecurrenceUntilEnd(:final localDate) =>
      localDate.compareTo(minimumLocalDate) >= 0,
  };
}

CalendarRecurrenceRule? _weeklyRule(
  Map<String, Object?> value,
  CalendarRecurrenceFrequency frequency,
  int interval,
  CalendarRecurrenceEnd end,
) {
  if (!_hasExactKeys(value, const <String>{
        'frequency',
        'interval',
        'weekdays',
        'end',
      }) ||
      value['weekdays'] is! List<Object?>) {
    return null;
  }
  final List<CalendarWeekday> weekdays = <CalendarWeekday>[];
  for (final Object? raw in value['weekdays']! as List<Object?>) {
    final CalendarWeekday? weekday = raw is String
        ? CalendarWeekday.tryParse(raw)
        : null;
    if (weekday == null || weekdays.contains(weekday)) {
      return null;
    }
    weekdays.add(weekday);
  }
  return weekdays.isEmpty || weekdays.length > 7
      ? null
      : CalendarRecurrenceRule._(
          frequency: frequency,
          interval: interval,
          weekdays: weekdays,
          monthDay: null,
          end: end,
        );
}

CalendarRecurrenceRule? _monthlyRule(
  Map<String, Object?> value,
  CalendarRecurrenceFrequency frequency,
  int interval,
  CalendarRecurrenceEnd end,
) {
  if (!_hasExactKeys(value, const <String>{
        'frequency',
        'interval',
        'monthDay',
        'end',
      }) ||
      value['monthDay'] is! int) {
    return null;
  }
  final int monthDay = value['monthDay']! as int;
  return monthDay < 1 || monthDay > 31
      ? null
      : CalendarRecurrenceRule._(
          frequency: frequency,
          interval: interval,
          weekdays: const <CalendarWeekday>[],
          monthDay: monthDay,
          end: end,
        );
}

CalendarRecurrenceUntilEnd? _untilEnd(String value) {
  final CalendarLocalDate? date = CalendarLocalDate.tryParse(value);
  return date == null ? null : CalendarRecurrenceUntilEnd(date);
}

Map<String, Object?>? _stringObjectMap(Object? raw) {
  if (raw is! Map || raw.keys.any((Object? key) => key is! String)) {
    return null;
  }
  return Map<String, Object?>.from(raw);
}

bool _hasExactKeys(Map<String, Object?> value, Set<String> expected) {
  return value.length == expected.length &&
      value.keys.toSet().containsAll(expected);
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
