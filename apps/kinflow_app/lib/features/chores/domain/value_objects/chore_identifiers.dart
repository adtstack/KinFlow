final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final RegExp _localDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _localTimePattern = RegExp(
  r'^([01]\d|2[0-3]):([0-5]\d)(?::00(?:\.0{1,6})?)?$',
);

final RegExp _historyEntryPattern = RegExp(
  r'^(completion|reschedule|assignment):'
  r'[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class ChoreSeriesId {
  const ChoreSeriesId._(this.value);

  final String value;

  static ChoreSeriesId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? ChoreSeriesId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreSeriesId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreOccurrenceId {
  const ChoreOccurrenceId._(this.value);

  final String value;

  static ChoreOccurrenceId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? ChoreOccurrenceId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreOccurrenceId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreRevisionId {
  const ChoreRevisionId._(this.value);

  final String value;

  static ChoreRevisionId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? ChoreRevisionId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreRevisionId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreCommandId {
  const ChoreCommandId._(this.value);

  final String value;

  static ChoreCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? ChoreCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreCommandId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreHistoryEntryId {
  const ChoreHistoryEntryId._(this.value);

  final String value;

  static ChoreHistoryEntryId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _historyEntryPattern.hasMatch(normalized)
        ? ChoreHistoryEntryId._(normalized)
        : null;
  }

  String get source => value.substring(0, value.indexOf(':'));

  @override
  bool operator ==(Object other) {
    return other is ChoreHistoryEntryId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreLocalDate {
  const ChoreLocalDate._(this.value);

  final String value;

  static ChoreLocalDate? tryParse(String value) {
    final RegExpMatch? match = _localDatePattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return ChoreLocalDate._(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  static ChoreLocalDate fromDateTime(DateTime value) {
    return ChoreLocalDate._(
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}',
    );
  }

  DateTime toDateTime() {
    final List<int> parts = value
        .split('-')
        .map(int.parse)
        .toList(growable: false);
    return DateTime(parts[0], parts[1], parts[2]);
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreLocalDate && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class ChoreLocalTime {
  const ChoreLocalTime._(this.value, this.hour, this.minute);

  final String value;
  final int hour;
  final int minute;

  static ChoreLocalTime? tryParse(String value) {
    final RegExpMatch? match = _localTimePattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    return ChoreLocalTime._(
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}',
      hour,
      minute,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChoreLocalTime && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
