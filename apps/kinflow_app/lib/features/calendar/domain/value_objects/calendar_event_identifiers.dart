final RegExp _calendarUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
  r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class CalendarEventSeriesId {
  const CalendarEventSeriesId._(this.value);

  final String value;

  static CalendarEventSeriesId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _calendarUuidPattern.hasMatch(normalized)
        ? CalendarEventSeriesId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventSeriesId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class CalendarEventOccurrenceId {
  const CalendarEventOccurrenceId._(this.value);

  final String value;

  static CalendarEventOccurrenceId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _calendarUuidPattern.hasMatch(normalized)
        ? CalendarEventOccurrenceId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventOccurrenceId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class CalendarEventRevisionId {
  const CalendarEventRevisionId._(this.value);

  final String value;

  static CalendarEventRevisionId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _calendarUuidPattern.hasMatch(normalized)
        ? CalendarEventRevisionId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventRevisionId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class CalendarEventCommandId {
  const CalendarEventCommandId._(this.value);

  final String value;

  static CalendarEventCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _calendarUuidPattern.hasMatch(normalized)
        ? CalendarEventCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarEventCommandId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
