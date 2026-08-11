import 'dart:convert';

final RegExp _localDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _localTimePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
final RegExp _utcInstantPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:'
  r'[0-5]\d(?:\.\d{1,6})?Z$',
);
final RegExp _ianaTimeZonePattern = RegExp(
  r'^(?:UTC|[A-Za-z][A-Za-z0-9._+-]*'
  r'(?:/[A-Za-z0-9][A-Za-z0-9._+-]*)+)$',
);

final class CalendarLocalDate implements Comparable<CalendarLocalDate> {
  const CalendarLocalDate._(this.value);

  final String value;

  int get year => _parts[0];

  int get month => _parts[1];

  int get day => _parts[2];

  int get weekday => toUtcCalendarDate().weekday;

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  CalendarLocalDate get firstDayOfMonth =>
      CalendarLocalDate._(_formatDate(year, month, 1));

  List<int> get _parts =>
      value.split('-').map(int.parse).toList(growable: false);

  static CalendarLocalDate? tryParse(String value) {
    final RegExpMatch? match = _localDatePattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (year < 1 || year > 9999) {
      return null;
    }
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return CalendarLocalDate._(_formatDate(year, month, day));
  }

  static CalendarLocalDate fromDateTime(DateTime value) {
    return CalendarLocalDate._(_formatDate(value.year, value.month, value.day));
  }

  CalendarLocalDate addDays(int days) {
    return fromDateTime(toUtcCalendarDate().add(Duration(days: days)));
  }

  CalendarLocalDate addMonthsClamped(int months) {
    final int absoluteMonth = year * 12 + month - 1 + months;
    final int targetYear = absoluteMonth ~/ 12;
    final int targetMonth = absoluteMonth % 12 + 1;
    final int targetLastDay = DateTime.utc(targetYear, targetMonth + 1, 0).day;
    return CalendarLocalDate._(
      _formatDate(
        targetYear,
        targetMonth,
        day > targetLastDay ? targetLastDay : day,
      ),
    );
  }

  int differenceInDays(CalendarLocalDate other) {
    return toUtcCalendarDate().difference(other.toUtcCalendarDate()).inDays;
  }

  DateTime toUtcCalendarDate() {
    final List<int> parts = _parts;
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  @override
  int compareTo(CalendarLocalDate other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) {
    return other is CalendarLocalDate && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class CalendarLocalTime implements Comparable<CalendarLocalTime> {
  const CalendarLocalTime._(this.value, this.hour, this.minute);

  final String value;
  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  static CalendarLocalTime? tryParse(String value) {
    final RegExpMatch? match = _localTimePattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    return CalendarLocalTime._(
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}',
      hour,
      minute,
    );
  }

  @override
  int compareTo(CalendarLocalTime other) {
    return minutesSinceMidnight.compareTo(other.minutesSinceMidnight);
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarLocalTime && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class IanaTimeZoneId {
  const IanaTimeZoneId._(this.value);

  final String value;

  static IanaTimeZoneId? tryParse(String value) {
    final String normalized = value.trim();
    if (normalized.length > 100 || !_ianaTimeZonePattern.hasMatch(normalized)) {
      return null;
    }
    return IanaTimeZoneId._(normalized);
  }

  @override
  bool operator ==(Object other) {
    return other is IanaTimeZoneId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class UtcInstant implements Comparable<UtcInstant> {
  const UtcInstant._(this.dateTime);

  final DateTime dateTime;

  String get value => dateTime.toIso8601String();

  static UtcInstant? tryParse(String value) {
    final String normalized = value.trim();
    if (!_utcInstantPattern.hasMatch(normalized)) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(normalized);
    if (parsed == null || !parsed.isUtc) {
      return null;
    }
    return UtcInstant._(parsed);
  }

  static UtcInstant? tryFromDateTime(DateTime value) {
    return value.isUtc ? UtcInstant._(value) : null;
  }

  @override
  int compareTo(UtcInstant other) => dateTime.compareTo(other.dateTime);

  @override
  bool operator ==(Object other) {
    return other is UtcInstant && other.dateTime == dateTime;
  }

  @override
  int get hashCode => dateTime.hashCode;

  @override
  String toString() => value;
}

final class CalendarAllDayRange {
  const CalendarAllDayRange._({
    required this.startDate,
    required this.endDateExclusive,
  });

  final CalendarLocalDate startDate;
  final CalendarLocalDate endDateExclusive;

  int get dayCount => endDateExclusive.differenceInDays(startDate);

  static CalendarAllDayRange? tryCreate({
    required CalendarLocalDate startDate,
    required CalendarLocalDate endDateExclusive,
  }) {
    if (startDate.compareTo(endDateExclusive) >= 0) {
      return null;
    }
    return CalendarAllDayRange._(
      startDate: startDate,
      endDateExclusive: endDateExclusive,
    );
  }

  static CalendarAllDayRange? tryParseExact(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null ||
        !_hasExactKeys(value, const <String>{
          'startDate',
          'endDateExclusive',
        }) ||
        value['startDate'] is! String ||
        value['endDateExclusive'] is! String) {
      return null;
    }
    final CalendarLocalDate? startDate = CalendarLocalDate.tryParse(
      value['startDate']! as String,
    );
    final CalendarLocalDate? endDateExclusive = CalendarLocalDate.tryParse(
      value['endDateExclusive']! as String,
    );
    if (startDate == null || endDateExclusive == null) {
      return null;
    }
    return tryCreate(startDate: startDate, endDateExclusive: endDateExclusive);
  }

  bool contains(CalendarLocalDate date) {
    return startDate.compareTo(date) <= 0 &&
        date.compareTo(endDateExclusive) < 0;
  }

  bool overlaps(CalendarAllDayRange other) {
    return startDate.compareTo(other.endDateExclusive) < 0 &&
        other.startDate.compareTo(endDateExclusive) < 0;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'startDate': startDate.value,
    'endDateExclusive': endDateExclusive.value,
  };

  @override
  bool operator ==(Object other) {
    return other is CalendarAllDayRange &&
        other.startDate == startDate &&
        other.endDateExclusive == endDateExclusive;
  }

  @override
  int get hashCode => Object.hash(startDate, endDateExclusive);
}

enum CalendarDstGapPolicy {
  reject;

  String get wireValue => name;

  static CalendarDstGapPolicy? tryParse(String value) {
    return value == 'reject' ? CalendarDstGapPolicy.reject : null;
  }
}

enum CalendarDstOverlapPolicy {
  earlier,
  later;

  String get wireValue => name;

  static CalendarDstOverlapPolicy? tryParse(String value) {
    return switch (value) {
      'earlier' => CalendarDstOverlapPolicy.earlier,
      'later' => CalendarDstOverlapPolicy.later,
      _ => null,
    };
  }
}

final class CalendarZonedDateTimeIntent {
  const CalendarZonedDateTimeIntent._({
    required this.localDate,
    required this.localTime,
    required this.timeZone,
    required this.gapPolicy,
    required this.overlapPolicy,
  });

  final CalendarLocalDate localDate;
  final CalendarLocalTime localTime;
  final IanaTimeZoneId timeZone;
  final CalendarDstGapPolicy gapPolicy;
  final CalendarDstOverlapPolicy overlapPolicy;

  String get fingerprint => jsonEncode(toJson());

  static CalendarZonedDateTimeIntent create({
    required CalendarLocalDate localDate,
    required CalendarLocalTime localTime,
    required IanaTimeZoneId timeZone,
    CalendarDstOverlapPolicy overlapPolicy = CalendarDstOverlapPolicy.earlier,
  }) {
    return CalendarZonedDateTimeIntent._(
      localDate: localDate,
      localTime: localTime,
      timeZone: timeZone,
      gapPolicy: CalendarDstGapPolicy.reject,
      overlapPolicy: overlapPolicy,
    );
  }

  static CalendarZonedDateTimeIntent? tryParseExact(Object? raw) {
    final Map<String, Object?>? value = _stringObjectMap(raw);
    if (value == null ||
        !_hasExactKeys(value, const <String>{
          'localDate',
          'localTime',
          'timezone',
          'gapPolicy',
          'overlapPolicy',
        }) ||
        value.values.any((Object? item) => item is! String)) {
      return null;
    }
    final CalendarLocalDate? localDate = CalendarLocalDate.tryParse(
      value['localDate']! as String,
    );
    final CalendarLocalTime? localTime = CalendarLocalTime.tryParse(
      value['localTime']! as String,
    );
    final IanaTimeZoneId? timeZone = IanaTimeZoneId.tryParse(
      value['timezone']! as String,
    );
    final CalendarDstGapPolicy? gapPolicy = CalendarDstGapPolicy.tryParse(
      value['gapPolicy']! as String,
    );
    final CalendarDstOverlapPolicy? overlapPolicy =
        CalendarDstOverlapPolicy.tryParse(value['overlapPolicy']! as String);
    if (localDate == null ||
        localTime == null ||
        timeZone == null ||
        gapPolicy == null ||
        gapPolicy != CalendarDstGapPolicy.reject ||
        overlapPolicy == null) {
      return null;
    }
    return CalendarZonedDateTimeIntent._(
      localDate: localDate,
      localTime: localTime,
      timeZone: timeZone,
      gapPolicy: gapPolicy,
      overlapPolicy: overlapPolicy,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'localDate': localDate.value,
    'localTime': localTime.value,
    'timezone': timeZone.value,
    'gapPolicy': gapPolicy.wireValue,
    'overlapPolicy': overlapPolicy.wireValue,
  };

  @override
  bool operator ==(Object other) {
    return other is CalendarZonedDateTimeIntent &&
        other.localDate == localDate &&
        other.localTime == localTime &&
        other.timeZone == timeZone &&
        other.gapPolicy == gapPolicy &&
        other.overlapPolicy == overlapPolicy;
  }

  @override
  int get hashCode =>
      Object.hash(localDate, localTime, timeZone, gapPolicy, overlapPolicy);
}

String _formatDate(int year, int month, int day) {
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

Map<String, Object?>? _stringObjectMap(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    return null;
  }
  final Map<String, Object?> value = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    if (entry.key is! String) {
      return null;
    }
    value[entry.key! as String] = entry.value;
  }
  return value;
}

bool _hasExactKeys(Map<String, Object?> value, Set<String> keys) {
  return value.length == keys.length && value.keys.toSet().containsAll(keys);
}
