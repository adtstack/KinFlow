import 'dart:convert';

import 'package:kinflow_app/features/calendar/domain/entities/calendar_import.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

final class IcalendarImportParser {
  const IcalendarImportParser(this._timeResolver);

  static const int maximumBytes = 262144;
  static const int maximumEvents = 50;

  final CalendarTimeResolver _timeResolver;

  CalendarImportParseResult parse({
    required String content,
    required IanaTimeZoneId householdTimeZone,
  }) {
    if (utf8.encode(content).length > maximumBytes) {
      return const CalendarImportParseFailed(
        CalendarImportParseFailureKind.tooLarge,
      );
    }
    final _CalendarStructureResult structure = _parseStructure(content);
    if (structure.failure != null) {
      return CalendarImportParseFailed(structure.failure!);
    }
    final List<List<_ContentLine>> events = structure.events!;
    if (events.length > maximumEvents) {
      return const CalendarImportParseFailed(
        CalendarImportParseFailureKind.tooManyEvents,
      );
    }

    final List<CalendarImportCandidate> candidates =
        <CalendarImportCandidate>[];
    final Set<String> sourceUids = <String>{};
    var invalid = 0;
    var unsupported = 0;
    var duplicate = 0;
    for (var index = 0; index < events.length; index += 1) {
      final List<_ContentLine> properties = events[index];
      final List<_ContentLine> uidLines = _named(properties, 'UID');
      if (uidLines.length != 1 ||
          uidLines.single.parameters.isNotEmpty ||
          uidLines.single.value.trim().isEmpty) {
        invalid += 1;
        continue;
      }
      final String uid = uidLines.single.value;
      if (!sourceUids.add(uid)) {
        duplicate += 1;
        continue;
      }
      final _EventParseResult result = _parseEvent(
        index: index,
        properties: properties,
        householdTimeZone: householdTimeZone,
      );
      switch (result.kind) {
        case _EventParseKind.supported:
          candidates.add(result.candidate!);
        case _EventParseKind.invalid:
          invalid += 1;
        case _EventParseKind.unsupported:
          unsupported += 1;
      }
    }
    return CalendarImportParsed(
      CalendarImportDocument(
        candidates: candidates,
        invalidEventCount: invalid,
        unsupportedEventCount: unsupported,
        duplicateEventCount: duplicate,
      ),
    );
  }

  _CalendarStructureResult _parseStructure(String content) {
    if (content.contains('\r') && content.contains(RegExp(r'\r(?!\n)'))) {
      return const _CalendarStructureResult.failed(
        CalendarImportParseFailureKind.invalidStructure,
      );
    }
    final List<String> physicalLines = content
        .replaceAll('\r\n', '\n')
        .split('\n');
    final List<String> unfolded = <String>[];
    for (final String line in physicalLines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfolded.isEmpty) {
          return const _CalendarStructureResult.failed(
            CalendarImportParseFailureKind.invalidStructure,
          );
        }
        unfolded[unfolded.length - 1] += line.substring(1);
      } else if (line.isNotEmpty) {
        unfolded.add(line);
      }
    }
    if (unfolded.isEmpty) {
      return const _CalendarStructureResult.failed(
        CalendarImportParseFailureKind.invalidStructure,
      );
    }

    final List<String> componentStack = <String>[];
    final List<List<_ContentLine>> events = <List<_ContentLine>>[];
    List<_ContentLine>? currentEvent;
    var versionCount = 0;
    var versionSupported = false;
    var calendarCount = 0;
    var calendarClosed = false;
    for (final String raw in unfolded) {
      final _ContentLine? line = _ContentLine.tryParse(raw);
      if (line == null) {
        return const _CalendarStructureResult.failed(
          CalendarImportParseFailureKind.invalidStructure,
        );
      }
      if (line.name == 'BEGIN' || line.name == 'END') {
        if (line.parameters.isNotEmpty ||
            !_componentNamePattern.hasMatch(line.value)) {
          return const _CalendarStructureResult.failed(
            CalendarImportParseFailureKind.invalidStructure,
          );
        }
        final String component = line.value.toUpperCase();
        if (line.name == 'BEGIN') {
          if (componentStack.isEmpty) {
            if (component != 'VCALENDAR' || calendarClosed) {
              return const _CalendarStructureResult.failed(
                CalendarImportParseFailureKind.invalidStructure,
              );
            }
            calendarCount += 1;
          } else if (component == 'VEVENT' &&
              componentStack.length == 1 &&
              componentStack.single == 'VCALENDAR') {
            currentEvent = <_ContentLine>[];
          } else if (component == 'VEVENT' ||
              componentStack.contains('VEVENT') && component != 'VALARM') {
            return const _CalendarStructureResult.failed(
              CalendarImportParseFailureKind.invalidStructure,
            );
          }
          componentStack.add(component);
        } else {
          if (componentStack.isEmpty || componentStack.last != component) {
            return const _CalendarStructureResult.failed(
              CalendarImportParseFailureKind.invalidStructure,
            );
          }
          if (component == 'VEVENT') {
            events.add(currentEvent ?? const <_ContentLine>[]);
            currentEvent = null;
          }
          componentStack.removeLast();
          if (component == 'VCALENDAR') calendarClosed = true;
        }
        continue;
      }
      if (componentStack.isEmpty || calendarClosed) {
        return const _CalendarStructureResult.failed(
          CalendarImportParseFailureKind.invalidStructure,
        );
      }
      if (componentStack.length == 1 &&
          componentStack.single == 'VCALENDAR' &&
          line.name == 'VERSION') {
        versionCount += 1;
        versionSupported =
            line.parameters.isEmpty && line.value.trim() == '2.0';
      }
      if (componentStack.length == 2 && componentStack.last == 'VEVENT') {
        currentEvent!.add(line);
      }
    }
    if (componentStack.isNotEmpty || calendarCount != 1 || !calendarClosed) {
      return const _CalendarStructureResult.failed(
        CalendarImportParseFailureKind.invalidStructure,
      );
    }
    if (versionCount != 1 || !versionSupported) {
      return const _CalendarStructureResult.failed(
        CalendarImportParseFailureKind.unsupportedVersion,
      );
    }
    return _CalendarStructureResult.succeeded(events);
  }

  _EventParseResult _parseEvent({
    required int index,
    required List<_ContentLine> properties,
    required IanaTimeZoneId householdTimeZone,
  }) {
    if (_named(properties, 'DTSTART').length != 1 ||
        _named(properties, 'SUMMARY').length != 1 ||
        _named(properties, 'DESCRIPTION').length > 1 ||
        _named(properties, 'DTEND').length > 1 ||
        _named(properties, 'DURATION').length > 1 ||
        _named(properties, 'RRULE').length > 1 ||
        _named(properties, 'DTEND').isNotEmpty &&
            _named(properties, 'DURATION').isNotEmpty) {
      return const _EventParseResult.invalid();
    }
    if (const <String>{
      'RECURRENCE-ID',
      'EXDATE',
      'RDATE',
    }.any((String name) => _named(properties, name).isNotEmpty)) {
      return const _EventParseResult.unsupported();
    }
    final String? title = _decodeText(
      _named(properties, 'SUMMARY').single.value,
    );
    final List<_ContentLine> descriptionLines = _named(
      properties,
      'DESCRIPTION',
    );
    final String? decodedDescription = descriptionLines.isEmpty
        ? ''
        : _decodeText(descriptionLines.single.value);
    if (title == null || decodedDescription == null) {
      return const _EventParseResult.invalid();
    }
    final String normalizedTitle = title.trim();
    final String normalizedDescription = decodedDescription.trim();

    final _TemporalValueResult startResult = _parseTemporal(
      _named(properties, 'DTSTART').single,
      householdTimeZone: householdTimeZone,
    );
    if (startResult.kind != _ValueParseKind.supported) {
      return startResult.kind == _ValueParseKind.unsupported
          ? const _EventParseResult.unsupported()
          : const _EventParseResult.invalid();
    }
    final _TemporalValue start = startResult.value!;

    CalendarLocalDate? allDayEnd;
    int? durationMinutes;
    var usesOverlapEarlier = false;
    if (start.isDate) {
      final List<_ContentLine> endLines = _named(properties, 'DTEND');
      final List<_ContentLine> durationLines = _named(properties, 'DURATION');
      if (endLines.isNotEmpty) {
        final _TemporalValueResult parsedEnd = _parseTemporal(
          endLines.single,
          householdTimeZone: householdTimeZone,
        );
        if (parsedEnd.kind != _ValueParseKind.supported ||
            parsedEnd.value == null ||
            !parsedEnd.value!.isDate) {
          return parsedEnd.kind == _ValueParseKind.unsupported
              ? const _EventParseResult.unsupported()
              : const _EventParseResult.invalid();
        }
        allDayEnd = parsedEnd.value!.date;
      } else if (durationLines.isNotEmpty) {
        final int? days = _parseAllDayDuration(durationLines.single);
        if (days == null) return const _EventParseResult.unsupported();
        allDayEnd = _tryAddDays(start.date, days);
      } else {
        allDayEnd = _tryAddDays(start.date, 1);
      }
      if (allDayEnd == null || allDayEnd.compareTo(start.date) <= 0) {
        return const _EventParseResult.unsupported();
      }
    } else {
      final CalendarTimeResolution startResolution = _timeResolver.resolve(
        start.intent!,
      );
      if (startResolution is! ResolvedCalendarTime) {
        return const _EventParseResult.unsupported();
      }
      usesOverlapEarlier =
          startResolution.kind == CalendarTimeResolutionKind.overlapEarlier;
      final List<_ContentLine> endLines = _named(properties, 'DTEND');
      final List<_ContentLine> durationLines = _named(properties, 'DURATION');
      if (endLines.isNotEmpty) {
        final _TemporalValueResult parsedEnd = _parseTemporal(
          endLines.single,
          householdTimeZone: householdTimeZone,
        );
        if (parsedEnd.kind != _ValueParseKind.supported ||
            parsedEnd.value == null ||
            parsedEnd.value!.isDate ||
            !start.sameZoneKind(parsedEnd.value!)) {
          return const _EventParseResult.unsupported();
        }
        final CalendarTimeResolution endResolution = _timeResolver.resolve(
          parsedEnd.value!.intent!,
        );
        if (endResolution is! ResolvedCalendarTime) {
          return const _EventParseResult.unsupported();
        }
        usesOverlapEarlier =
            usesOverlapEarlier ||
            endResolution.kind == CalendarTimeResolutionKind.overlapEarlier;
        final Duration duration = endResolution.instant.dateTime.difference(
          startResolution.instant.dateTime,
        );
        if (duration.inSeconds % 60 != 0) {
          return const _EventParseResult.unsupported();
        }
        durationMinutes = duration.inMinutes;
      } else if (durationLines.isNotEmpty) {
        final _TimedDuration? duration = _parseTimedDuration(
          durationLines.single,
        );
        if (duration == null) {
          return const _EventParseResult.unsupported();
        }
        if (duration.nominalDays == 0) {
          durationMinutes = duration.exactMinutes;
        } else {
          final CalendarLocalDate? nominalEndDate = _tryAddDays(
            start.date,
            duration.nominalDays,
          );
          if (nominalEndDate == null) {
            return const _EventParseResult.unsupported();
          }
          final CalendarZonedDateTimeIntent nominalEndIntent =
              CalendarZonedDateTimeIntent.create(
                localDate: nominalEndDate,
                localTime: start.time!,
                timeZone: start.zone!,
                overlapPolicy: CalendarDstOverlapPolicy.earlier,
              );
          final CalendarTimeResolution nominalEndResolution = _timeResolver
              .resolve(nominalEndIntent);
          if (nominalEndResolution is! ResolvedCalendarTime) {
            return const _EventParseResult.unsupported();
          }
          usesOverlapEarlier =
              usesOverlapEarlier ||
              nominalEndResolution.kind ==
                  CalendarTimeResolutionKind.overlapEarlier;
          final Duration nominalDuration = nominalEndResolution.instant.dateTime
              .difference(startResolution.instant.dateTime);
          if (nominalDuration.inSeconds % 60 != 0) {
            return const _EventParseResult.unsupported();
          }
          durationMinutes = nominalDuration.inMinutes + duration.exactMinutes;
        }
      } else {
        return const _EventParseResult.unsupported();
      }
      if (durationMinutes < 1 || durationMinutes > 10080) {
        return const _EventParseResult.unsupported();
      }
    }

    CalendarRecurrenceRule? recurrenceRule;
    final List<_ContentLine> recurrenceLines = _named(properties, 'RRULE');
    if (recurrenceLines.isNotEmpty) {
      final _RecurrenceResult recurrence = _parseRecurrence(
        recurrenceLines.single,
        start: start,
      );
      if (recurrence.kind != _ValueParseKind.supported) {
        return recurrence.kind == _ValueParseKind.unsupported
            ? const _EventParseResult.unsupported()
            : const _EventParseResult.invalid();
      }
      recurrenceRule = recurrence.rule;
    }

    final CalendarImportCandidate? candidate =
        CalendarImportCandidate.tryCreate(
          sourceIndex: index,
          title: normalizedTitle,
          description: normalizedDescription.isEmpty
              ? null
              : normalizedDescription,
          isAllDay: start.isDate,
          localStartDate: start.date,
          localStartTime: start.time,
          durationMinutes: durationMinutes,
          allDayEndDateExclusive: allDayEnd,
          timeZone: start.zone,
          overlapPolicy: start.isDate ? null : CalendarDstOverlapPolicy.earlier,
          recurrenceRule: recurrenceRule,
          usesHouseholdTimeZone: start.usesHouseholdTimeZone,
          usesOverlapEarlier: usesOverlapEarlier,
        );
    return candidate == null
        ? const _EventParseResult.invalid()
        : _EventParseResult.supported(candidate);
  }

  _TemporalValueResult _parseTemporal(
    _ContentLine line, {
    required IanaTimeZoneId householdTimeZone,
  }) {
    if (line.parameters.keys.any(
      (String key) => key != 'VALUE' && key != 'TZID',
    )) {
      return const _TemporalValueResult.unsupported();
    }
    final String? valueType = line.parameters['VALUE']?.toUpperCase();
    if (valueType != null && valueType != 'DATE' && valueType != 'DATE-TIME') {
      return const _TemporalValueResult.unsupported();
    }
    final bool isDate =
        valueType == 'DATE' ||
        valueType == null && _dateValuePattern.hasMatch(line.value);
    if (isDate) {
      if (line.parameters.containsKey('TZID') ||
          !_dateValuePattern.hasMatch(line.value)) {
        return const _TemporalValueResult.invalid();
      }
      final CalendarLocalDate? date = _parseDate(line.value);
      return date == null
          ? const _TemporalValueResult.invalid()
          : _TemporalValueResult.supported(_TemporalValue.date(date));
    }
    final RegExpMatch? match = _dateTimeValuePattern.firstMatch(line.value);
    if (match == null) return const _TemporalValueResult.invalid();
    if (match.group(4) != '00') {
      return const _TemporalValueResult.unsupported();
    }
    final CalendarLocalDate? date = _parseDate(match.group(1)!);
    final CalendarLocalTime? time = CalendarLocalTime.tryParse(
      '${match.group(2)}:${match.group(3)}',
    );
    if (date == null || time == null) {
      return const _TemporalValueResult.invalid();
    }
    final bool utc = match.group(5) == 'Z';
    final String? rawTzid = line.parameters['TZID'];
    if (utc && rawTzid != null) {
      return const _TemporalValueResult.invalid();
    }
    final _TemporalZoneKind zoneKind;
    final IanaTimeZoneId? zone;
    if (utc) {
      zoneKind = _TemporalZoneKind.utc;
      zone = IanaTimeZoneId.tryParse('UTC');
    } else if (rawTzid == null) {
      zoneKind = _TemporalZoneKind.floating;
      zone = householdTimeZone;
    } else {
      zoneKind = _TemporalZoneKind.tzid;
      zone = IanaTimeZoneId.tryParse(_stripQuotes(rawTzid));
    }
    if (zone == null || !_timeResolver.supports(zone)) {
      return const _TemporalValueResult.unsupported();
    }
    return _TemporalValueResult.supported(
      _TemporalValue.dateTime(
        date: date,
        time: time,
        zone: zone,
        zoneKind: zoneKind,
      ),
    );
  }

  _RecurrenceResult _parseRecurrence(
    _ContentLine line, {
    required _TemporalValue start,
  }) {
    if (line.parameters.isNotEmpty) {
      return const _RecurrenceResult.unsupported();
    }
    final Map<String, String> values = <String, String>{};
    for (final String part in line.value.split(';')) {
      final int equals = part.indexOf('=');
      if (equals <= 0 || equals == part.length - 1) {
        return const _RecurrenceResult.invalid();
      }
      final String key = part.substring(0, equals).toUpperCase();
      final String value = part.substring(equals + 1).toUpperCase();
      if (!values.containsKey(key)) {
        values[key] = value;
      } else {
        return const _RecurrenceResult.invalid();
      }
    }
    const Set<String> allowed = <String>{
      'FREQ',
      'INTERVAL',
      'COUNT',
      'UNTIL',
      'BYDAY',
      'BYMONTHDAY',
    };
    if (values.keys.any((String key) => !allowed.contains(key)) ||
        values['FREQ'] == null ||
        values.containsKey('COUNT') && values.containsKey('UNTIL')) {
      return const _RecurrenceResult.unsupported();
    }
    final CalendarRecurrenceFrequency? frequency = switch (values['FREQ']) {
      'DAILY' => CalendarRecurrenceFrequency.daily,
      'WEEKLY' => CalendarRecurrenceFrequency.weekly,
      'MONTHLY' => CalendarRecurrenceFrequency.monthly,
      _ => null,
    };
    if (frequency == null) return const _RecurrenceResult.unsupported();
    final int? interval = values['INTERVAL'] == null
        ? 1
        : int.tryParse(values['INTERVAL']!);
    if (interval == null || interval < 1 || interval > 30) {
      return const _RecurrenceResult.unsupported();
    }
    final CalendarRecurrenceEnd end;
    if (values['COUNT'] != null) {
      final int? count = int.tryParse(values['COUNT']!);
      if (count == null || count < 1 || count > 1000) {
        return const _RecurrenceResult.unsupported();
      }
      end = CalendarRecurrenceCountEnd(count);
    } else if (values['UNTIL'] != null) {
      if (!start.isDate) return const _RecurrenceResult.unsupported();
      final CalendarLocalDate? until = _parseDate(values['UNTIL']!);
      if (until == null || until.compareTo(start.date) < 0) {
        return const _RecurrenceResult.invalid();
      }
      end = CalendarRecurrenceUntilEnd(until);
    } else {
      end = const CalendarRecurrenceNeverEnds();
    }

    CalendarRecurrenceRule? rule = CalendarRecurrenceRule.tryAnchored(
      frequency: frequency,
      startLocalDate: start.date,
      interval: interval,
      end: end,
    );
    if (rule == null) return const _RecurrenceResult.invalid();
    switch (frequency) {
      case CalendarRecurrenceFrequency.daily:
        if (values.containsKey('BYDAY') || values.containsKey('BYMONTHDAY')) {
          return const _RecurrenceResult.unsupported();
        }
      case CalendarRecurrenceFrequency.weekly:
        if (values.containsKey('BYMONTHDAY')) {
          return const _RecurrenceResult.unsupported();
        }
        final String? rawDays = values['BYDAY'];
        if (rawDays != null) {
          final List<String> tokens = rawDays.split(',');
          final List<CalendarWeekday> weekdays = tokens
              .map(CalendarWeekday.tryParse)
              .whereType<CalendarWeekday>()
              .toList(growable: false);
          if (weekdays.length != tokens.length) {
            return const _RecurrenceResult.unsupported();
          }
          rule = rule.tryWithWeeklyWeekdays(
            weekdays: weekdays,
            sourceLocalDate: start.date,
            interval: interval,
            end: end,
            minimumLocalDate: start.date,
          );
          if (rule == null) return const _RecurrenceResult.unsupported();
        }
      case CalendarRecurrenceFrequency.monthly:
        if (values.containsKey('BYDAY')) {
          return const _RecurrenceResult.unsupported();
        }
        final String? rawMonthDay = values['BYMONTHDAY'];
        if (rawMonthDay != null &&
            (int.tryParse(rawMonthDay) != start.date.day ||
                rawMonthDay.contains(','))) {
          return const _RecurrenceResult.unsupported();
        }
        rule = rule.tryWithMonthlyStartDate(
          sourceLocalDate: start.date,
          interval: interval,
          end: end,
          minimumLocalDate: start.date,
        );
    }
    return _RecurrenceResult.supported(rule!);
  }
}

final RegExp _componentNamePattern = RegExp(r'^[A-Za-z0-9-]+$');
final RegExp _propertyNamePattern = RegExp(r'^[A-Za-z0-9-]+$');
final RegExp _dateValuePattern = RegExp(r'^\d{8}$');
final RegExp _dateTimeValuePattern = RegExp(
  r'^(\d{8})T(\d{2})(\d{2})(\d{2})(Z)?$',
);

List<_ContentLine> _named(List<_ContentLine> lines, String name) => lines
    .where((_ContentLine line) => line.name == name)
    .toList(growable: false);

CalendarLocalDate? _parseDate(String raw) {
  if (!_dateValuePattern.hasMatch(raw)) return null;
  return CalendarLocalDate.tryParse(
    '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}',
  );
}

String? _decodeText(String raw) {
  final StringBuffer buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final String character = raw[index];
    if (character != r'\') {
      buffer.write(character);
      continue;
    }
    if (index + 1 >= raw.length) return null;
    index += 1;
    switch (raw[index]) {
      case r'\':
        buffer.write(r'\');
      case 'n' || 'N':
        buffer.write('\n');
      case ',':
        buffer.write(',');
      case ';':
        buffer.write(';');
      default:
        return null;
    }
  }
  return buffer.toString();
}

const int _maximumCalendarSpanDays = 3652059;
const int _maximumTimedDurationMinutes = 10080;

CalendarLocalDate? _tryAddDays(CalendarLocalDate start, int days) {
  if (days < 1 || days > _maximumCalendarSpanDays) return null;
  final DateTime added = start.toUtcCalendarDate().add(Duration(days: days));
  final String value =
      '${added.year.toString().padLeft(4, '0')}-'
      '${added.month.toString().padLeft(2, '0')}-'
      '${added.day.toString().padLeft(2, '0')}';
  return CalendarLocalDate.tryParse(value);
}

int? _parseAllDayDuration(_ContentLine line) {
  if (line.parameters.isNotEmpty) return null;
  final RegExpMatch? match = RegExp(
    r'^P(?:(\d+)D|(\d+)W)$',
  ).firstMatch(line.value);
  if (match == null) return null;
  final String? rawDays = match.group(1);
  final String? rawWeeks = match.group(2);
  final int? parsed = int.tryParse(rawDays ?? rawWeeks!);
  if (parsed == null || parsed < 1) return null;
  final int days;
  if (rawDays != null) {
    days = parsed;
  } else {
    if (parsed > _maximumCalendarSpanDays ~/ 7) return null;
    days = parsed * 7;
  }
  if (days > _maximumCalendarSpanDays) return null;
  return days > 0 ? days : null;
}

_TimedDuration? _parseTimedDuration(_ContentLine line) {
  if (line.parameters.isNotEmpty) return null;
  final RegExpMatch? match = RegExp(
    r'^P(?:(\d+)W|(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?)$',
  ).firstMatch(line.value);
  if (match == null ||
      match.group(1) == null &&
          match.group(2) == null &&
          match.group(3) == null &&
          match.group(4) == null) {
    return null;
  }
  final List<int> values = <int>[];
  for (final String? raw in <String?>[
    match.group(1),
    match.group(2),
    match.group(3),
    match.group(4),
  ]) {
    if (raw == null) {
      values.add(0);
      continue;
    }
    final int? value = int.tryParse(raw);
    if (value == null || value > _maximumTimedDurationMinutes) return null;
    values.add(value);
  }
  final int nominalDays = values[0] * 7 + values[1];
  final int exactMinutes = values[2] * 60 + values[3];
  final int nominalMinutes = nominalDays * 1440 + exactMinutes;
  if (nominalMinutes < 1 || nominalMinutes > _maximumTimedDurationMinutes) {
    return null;
  }
  return _TimedDuration(nominalDays: nominalDays, exactMinutes: exactMinutes);
}

String _stripQuotes(String value) {
  return value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;
}

final class _ContentLine {
  const _ContentLine({
    required this.name,
    required this.parameters,
    required this.value,
  });

  final String name;
  final Map<String, String> parameters;
  final String value;

  static _ContentLine? tryParse(String raw) {
    var quoted = false;
    var delimiter = -1;
    for (var index = 0; index < raw.length; index += 1) {
      if (raw[index] == '"') quoted = !quoted;
      if (raw[index] == ':' && !quoted) {
        delimiter = index;
        break;
      }
    }
    if (quoted || delimiter <= 0) return null;
    final List<String>? head = _splitQuoted(raw.substring(0, delimiter), ';');
    if (head == null || head.isEmpty) return null;
    final String name = head.first.toUpperCase();
    if (!_propertyNamePattern.hasMatch(name)) return null;
    final Map<String, String> parameters = <String, String>{};
    for (final String rawParameter in head.skip(1)) {
      final int equals = rawParameter.indexOf('=');
      if (equals <= 0 || equals == rawParameter.length - 1) return null;
      final String key = rawParameter.substring(0, equals).toUpperCase();
      final String value = rawParameter.substring(equals + 1);
      if (!_propertyNamePattern.hasMatch(key) ||
          value.contains('^') ||
          parameters.containsKey(key)) {
        return null;
      }
      parameters[key] = value;
    }
    return _ContentLine(
      name: name,
      parameters: Map<String, String>.unmodifiable(parameters),
      value: raw.substring(delimiter + 1),
    );
  }
}

List<String>? _splitQuoted(String value, String delimiter) {
  final List<String> parts = <String>[];
  final StringBuffer current = StringBuffer();
  var quoted = false;
  for (var index = 0; index < value.length; index += 1) {
    final String character = value[index];
    if (character == '"') quoted = !quoted;
    if (character == delimiter && !quoted) {
      if (current.isEmpty) return null;
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(character);
    }
  }
  if (quoted || current.isEmpty) return null;
  parts.add(current.toString());
  return parts;
}

final class _CalendarStructureResult {
  const _CalendarStructureResult.succeeded(this.events) : failure = null;
  const _CalendarStructureResult.failed(this.failure) : events = null;

  final List<List<_ContentLine>>? events;
  final CalendarImportParseFailureKind? failure;
}

enum _EventParseKind { supported, invalid, unsupported }

final class _EventParseResult {
  const _EventParseResult.supported(this.candidate)
    : kind = _EventParseKind.supported;
  const _EventParseResult.invalid()
    : kind = _EventParseKind.invalid,
      candidate = null;
  const _EventParseResult.unsupported()
    : kind = _EventParseKind.unsupported,
      candidate = null;

  final _EventParseKind kind;
  final CalendarImportCandidate? candidate;
}

enum _ValueParseKind { supported, invalid, unsupported }

final class _TemporalValueResult {
  const _TemporalValueResult.supported(this.value)
    : kind = _ValueParseKind.supported;
  const _TemporalValueResult.invalid()
    : kind = _ValueParseKind.invalid,
      value = null;
  const _TemporalValueResult.unsupported()
    : kind = _ValueParseKind.unsupported,
      value = null;

  final _ValueParseKind kind;
  final _TemporalValue? value;
}

enum _TemporalZoneKind { date, utc, floating, tzid }

final class _TemporalValue {
  const _TemporalValue.date(this.date)
    : time = null,
      zone = null,
      zoneKind = _TemporalZoneKind.date;

  const _TemporalValue.dateTime({
    required this.date,
    required this.time,
    required this.zone,
    required this.zoneKind,
  });

  final CalendarLocalDate date;
  final CalendarLocalTime? time;
  final IanaTimeZoneId? zone;
  final _TemporalZoneKind zoneKind;

  bool get isDate => zoneKind == _TemporalZoneKind.date;
  bool get usesHouseholdTimeZone => zoneKind == _TemporalZoneKind.floating;
  CalendarZonedDateTimeIntent? get intent => isDate
      ? null
      : CalendarZonedDateTimeIntent.create(
          localDate: date,
          localTime: time!,
          timeZone: zone!,
          overlapPolicy: CalendarDstOverlapPolicy.earlier,
        );

  bool sameZoneKind(_TemporalValue other) {
    return zoneKind == other.zoneKind && zone == other.zone;
  }
}

final class _RecurrenceResult {
  const _RecurrenceResult.supported(this.rule)
    : kind = _ValueParseKind.supported;
  const _RecurrenceResult.invalid()
    : kind = _ValueParseKind.invalid,
      rule = null;
  const _RecurrenceResult.unsupported()
    : kind = _ValueParseKind.unsupported,
      rule = null;

  final _ValueParseKind kind;
  final CalendarRecurrenceRule? rule;
}

final class _TimedDuration {
  const _TimedDuration({required this.nominalDays, required this.exactMinutes});

  final int nominalDays;
  final int exactMinutes;
}
