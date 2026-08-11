import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum ChoreRecurrenceFrequency {
  daily,
  weekly,
  monthly;

  String get wireValue => name;

  static ChoreRecurrenceFrequency? tryParse(String value) {
    return switch (value) {
      'daily' => ChoreRecurrenceFrequency.daily,
      'weekly' => ChoreRecurrenceFrequency.weekly,
      'monthly' => ChoreRecurrenceFrequency.monthly,
      _ => null,
    };
  }
}

enum ChoreWeekday {
  monday('MO', DateTime.monday),
  tuesday('TU', DateTime.tuesday),
  wednesday('WE', DateTime.wednesday),
  thursday('TH', DateTime.thursday),
  friday('FR', DateTime.friday),
  saturday('SA', DateTime.saturday),
  sunday('SU', DateTime.sunday);

  const ChoreWeekday(this.wireValue, this.dateTimeValue);

  final String wireValue;
  final int dateTimeValue;

  static ChoreWeekday? tryParse(String value) {
    for (final ChoreWeekday weekday in values) {
      if (weekday.wireValue == value) {
        return weekday;
      }
    }
    return null;
  }

  static ChoreWeekday fromDateTime(DateTime value) {
    return values.firstWhere(
      (ChoreWeekday weekday) => weekday.dateTimeValue == value.weekday,
    );
  }
}

sealed class ChoreRecurrenceEnd {
  const ChoreRecurrenceEnd();

  Map<String, Object?> toJson();

  static ChoreRecurrenceEnd? tryParse(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null || value['type'] is! String) {
      return null;
    }
    return switch (value['type']) {
      'never' when _hasExactKeys(value, const <String>{'type'}) =>
        const ChoreRecurrenceNeverEnds(),
      'count'
          when _hasExactKeys(value, const <String>{'type', 'count'}) &&
              value['count'] is int &&
              (value['count']! as int) >= 1 &&
              (value['count']! as int) <= 1000 =>
        ChoreRecurrenceCountEnd(value['count']! as int),
      'until'
          when _hasExactKeys(value, const <String>{'type', 'localDate'}) &&
              value['localDate'] is String =>
        _untilEnd(value['localDate']! as String),
      _ => null,
    };
  }
}

final class ChoreRecurrenceNeverEnds extends ChoreRecurrenceEnd {
  const ChoreRecurrenceNeverEnds();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{'type': 'never'};
}

final class ChoreRecurrenceCountEnd extends ChoreRecurrenceEnd {
  const ChoreRecurrenceCountEnd(this.count);

  final int count;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'count',
    'count': count,
  };
}

final class ChoreRecurrenceUntilEnd extends ChoreRecurrenceEnd {
  const ChoreRecurrenceUntilEnd(this.localDate);

  final ChoreLocalDate localDate;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'until',
    'localDate': localDate.value,
  };
}

final class ChoreRecurrenceRule {
  ChoreRecurrenceRule._({
    required this.frequency,
    required this.interval,
    required List<ChoreWeekday> weekdays,
    required this.monthDay,
    required this.end,
  }) : weekdays = List<ChoreWeekday>.unmodifiable(weekdays);

  final ChoreRecurrenceFrequency frequency;
  final int interval;
  final List<ChoreWeekday> weekdays;
  final int? monthDay;
  final ChoreRecurrenceEnd end;

  static ChoreRecurrenceRule anchored({
    required ChoreRecurrenceFrequency frequency,
    required ChoreLocalDate startLocalDate,
  }) => tryAnchored(
    frequency: frequency,
    startLocalDate: startLocalDate,
    interval: 1,
    end: const ChoreRecurrenceNeverEnds(),
  )!;

  static ChoreRecurrenceRule? tryAnchored({
    required ChoreRecurrenceFrequency frequency,
    required ChoreLocalDate startLocalDate,
    required int interval,
    required ChoreRecurrenceEnd end,
  }) {
    if (!_validIntervalAndEnd(
      interval: interval,
      end: end,
      minimumLocalDate: startLocalDate,
    )) {
      return null;
    }
    final DateTime start = startLocalDate.toDateTime();
    return ChoreRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: frequency == ChoreRecurrenceFrequency.weekly
          ? <ChoreWeekday>[ChoreWeekday.fromDateTime(start)]
          : const <ChoreWeekday>[],
      monthDay: frequency == ChoreRecurrenceFrequency.monthly
          ? start.day
          : null,
      end: end,
    );
  }

  ChoreRecurrenceRule? tryWithIntervalAndEnd({
    required int interval,
    required ChoreRecurrenceEnd end,
    required ChoreLocalDate minimumLocalDate,
  }) {
    if (!_validIntervalAndEnd(
      interval: interval,
      end: end,
      minimumLocalDate: minimumLocalDate,
    )) {
      return null;
    }
    return ChoreRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays,
      monthDay: monthDay,
      end: end,
    );
  }

  ChoreRecurrenceRule? tryWithWeeklyWeekdays({
    required Iterable<ChoreWeekday> weekdays,
    required int interval,
    required ChoreRecurrenceEnd end,
    required ChoreLocalDate minimumLocalDate,
    ChoreLocalDate? requiredStartLocalDate,
  }) {
    if (frequency != ChoreRecurrenceFrequency.weekly ||
        !_validIntervalAndEnd(
          interval: interval,
          end: end,
          minimumLocalDate: minimumLocalDate,
        )) {
      return null;
    }
    final List<ChoreWeekday> provided = weekdays.toList(growable: false);
    final Set<ChoreWeekday> selected = provided.toSet();
    final ChoreWeekday? requiredWeekday = requiredStartLocalDate == null
        ? null
        : ChoreWeekday.fromDateTime(requiredStartLocalDate.toDateTime());
    if (provided.isEmpty ||
        provided.length > ChoreWeekday.values.length ||
        selected.length != provided.length ||
        requiredWeekday != null && !selected.contains(requiredWeekday)) {
      return null;
    }
    final List<ChoreWeekday> canonical = ChoreWeekday.values
        .where(selected.contains)
        .toList(growable: false);
    return ChoreRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: canonical,
      monthDay: null,
      end: end,
    );
  }

  ChoreRecurrenceRule? tryWithMonthlyDay({
    required int monthDay,
    required int interval,
    required ChoreRecurrenceEnd end,
    required ChoreLocalDate minimumLocalDate,
  }) {
    if (frequency != ChoreRecurrenceFrequency.monthly ||
        monthDay < 1 ||
        monthDay > 31 ||
        !_validIntervalAndEnd(
          interval: interval,
          end: end,
          minimumLocalDate: minimumLocalDate,
        )) {
      return null;
    }
    return ChoreRecurrenceRule._(
      frequency: frequency,
      interval: interval,
      weekdays: const <ChoreWeekday>[],
      monthDay: monthDay,
      end: end,
    );
  }

  static ChoreRecurrenceRule? tryParse(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null ||
        value['frequency'] is! String ||
        value['interval'] is! int) {
      return null;
    }
    final ChoreRecurrenceFrequency? frequency =
        ChoreRecurrenceFrequency.tryParse(value['frequency']! as String);
    final int interval = value['interval']! as int;
    final ChoreRecurrenceEnd? end = ChoreRecurrenceEnd.tryParse(value['end']);
    if (frequency == null || interval < 1 || interval > 30 || end == null) {
      return null;
    }

    switch (frequency) {
      case ChoreRecurrenceFrequency.daily:
        if (!_hasExactKeys(value, const <String>{
          'frequency',
          'interval',
          'end',
        })) {
          return null;
        }
        return ChoreRecurrenceRule._(
          frequency: frequency,
          interval: interval,
          weekdays: const <ChoreWeekday>[],
          monthDay: null,
          end: end,
        );
      case ChoreRecurrenceFrequency.weekly:
        if (!_hasExactKeys(value, const <String>{
              'frequency',
              'interval',
              'weekdays',
              'end',
            }) ||
            value['weekdays'] is! List<Object?>) {
          return null;
        }
        final List<ChoreWeekday> weekdays = <ChoreWeekday>[];
        for (final Object? rawWeekday in value['weekdays']! as List<Object?>) {
          final ChoreWeekday? weekday = rawWeekday is String
              ? ChoreWeekday.tryParse(rawWeekday)
              : null;
          if (weekday == null || weekdays.contains(weekday)) {
            return null;
          }
          weekdays.add(weekday);
        }
        if (weekdays.isEmpty || weekdays.length > 7) {
          return null;
        }
        return ChoreRecurrenceRule._(
          frequency: frequency,
          interval: interval,
          weekdays: weekdays,
          monthDay: null,
          end: end,
        );
      case ChoreRecurrenceFrequency.monthly:
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
        if (monthDay < 1 || monthDay > 31) {
          return null;
        }
        return ChoreRecurrenceRule._(
          frequency: frequency,
          interval: interval,
          weekdays: const <ChoreWeekday>[],
          monthDay: monthDay,
          end: end,
        );
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'frequency': frequency.wireValue,
      'interval': interval,
      if (frequency == ChoreRecurrenceFrequency.weekly)
        'weekdays': weekdays
            .map((ChoreWeekday weekday) => weekday.wireValue)
            .toList(growable: false),
      if (frequency == ChoreRecurrenceFrequency.monthly) 'monthDay': monthDay,
      'end': end.toJson(),
    };
  }

  String get fingerprint => jsonEncode(toJson());

  bool startsOn(ChoreLocalDate date) {
    final DateTime value = date.toDateTime();
    return switch (frequency) {
      ChoreRecurrenceFrequency.daily => true,
      ChoreRecurrenceFrequency.weekly => weekdays.contains(
        ChoreWeekday.fromDateTime(value),
      ),
      ChoreRecurrenceFrequency.monthly => monthDay == value.day,
    };
  }
}

final class RecurringChoreDraft {
  const RecurringChoreDraft._({
    required this.householdId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.startLocalDate,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final HouseholdId householdId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate startLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;

  static RecurringChoreDraft? tryCreate({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate startLocalDate,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    final ChoreRecurrenceEnd end = recurrenceRule.end;
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 4000 ||
        !recurrenceRule.startsOn(startLocalDate) ||
        end is ChoreRecurrenceUntilEnd &&
            end.localDate.value.compareTo(startLocalDate.value) < 0) {
      return null;
    }
    return RecurringChoreDraft._(
      householdId: householdId,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'householdId': householdId.value,
    'title': title,
    'description': description,
    'assigneeMemberId': assigneeMemberId.value,
    'startLocalDate': startLocalDate.value,
    'dueLocalTime': dueLocalTime?.value,
    'recurrenceRule': recurrenceRule.toJson(),
  });

  CreateRecurringChoreRequest withId(ChoreCommandId idempotencyKey) {
    return CreateRecurringChoreRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }
}

final class CreateRecurringChoreRequest {
  const CreateRecurringChoreRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.startLocalDate,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate startLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;
}

final class RecurringChoreSnapshot {
  const RecurringChoreSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.firstOccurrenceId,
    required this.recurrenceRule,
    required this.materializedThrough,
    required this.materializedCount,
    required this.created,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId firstOccurrenceId;
  final ChoreRecurrenceRule recurrenceRule;
  final ChoreLocalDate materializedThrough;
  final int materializedCount;
  final bool created;
}

ChoreRecurrenceUntilEnd? _untilEnd(String value) {
  final ChoreLocalDate? date = ChoreLocalDate.tryParse(value);
  return date == null ? null : ChoreRecurrenceUntilEnd(date);
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

bool _containsControlCharacter(String value) {
  return value.codeUnits.any(
    (int codeUnit) => codeUnit < 32 || codeUnit == 127,
  );
}

bool _validIntervalAndEnd({
  required int interval,
  required ChoreRecurrenceEnd end,
  required ChoreLocalDate minimumLocalDate,
}) {
  if (interval < 1 || interval > 30) {
    return false;
  }
  return switch (end) {
    ChoreRecurrenceNeverEnds() => true,
    ChoreRecurrenceCountEnd(:final count) => count >= 1 && count <= 1000,
    ChoreRecurrenceUntilEnd(:final localDate) =>
      localDate.value.compareTo(minimumLocalDate.value) >= 0,
  };
}
