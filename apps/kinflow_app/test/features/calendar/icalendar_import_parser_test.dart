import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_import.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

void main() {
  final IcalendarImportParser parser = IcalendarImportParser(
    TimezoneCalendarTimeResolver(),
  );
  final IanaTimeZoneId householdZone = IanaTimeZoneId.tryParse('Asia/Seoul')!;

  test('unfolds RFC lines, unescapes text, and parses all-day ranges', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:all-day-1@example.test',
        'DTSTART;VALUE=DATE:20260809',
        'DTEND;VALUE=DATE:20260812',
        r'SUMMARY:Family\, trip',
        r'DESCRIPTION:Bring snacks\; water\nMeet ',
        ' at the station',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(document.totalEventCount, 1);
    final CalendarImportCandidate candidate = document.candidates.single;
    expect(candidate.title, 'Family, trip');
    expect(candidate.description, 'Bring snacks; water\nMeet at the station');
    expect(candidate.isAllDay, isTrue);
    expect(candidate.localStartDate.value, '2026-08-09');
    expect(candidate.allDayEndDateExclusive!.value, '2026-08-12');
    expect(candidate.timeZone, isNull);
  });

  test('supports implicit all-day end and positive date duration', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:implicit@example.test',
        'DTSTART;VALUE=DATE:20260809',
        'SUMMARY:Implicit day',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:duration@example.test',
        'DTSTART;VALUE=DATE:20260810',
        'DURATION:P2D',
        'SUMMARY:Two days',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(
      document.candidates.map(
        (CalendarImportCandidate value) => value.allDayEndDateExclusive!.value,
      ),
      <String>['2026-08-10', '2026-08-12'],
    );
  });

  test('normalizes UTC, floating, and exact IANA timed events', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:utc@example.test',
        'DTSTART:20260809T010000Z',
        'DTEND:20260809T023000Z',
        'SUMMARY:UTC event',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:floating@example.test',
        'DTSTART:20260809T090000',
        'DURATION:PT45M',
        'SUMMARY:Floating event',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:tzid@example.test',
        'DTSTART;TZID=America/New_York:20260809T090000',
        'DTEND;TZID=America/New_York:20260809T100000',
        'SUMMARY:Zoned event',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(document.candidates, hasLength(3));
    expect(document.candidates[0].timeZone!.value, 'UTC');
    expect(document.candidates[0].durationMinutes, 90);
    expect(document.candidates[1].timeZone!.value, 'Asia/Seoul');
    expect(document.candidates[1].usesHouseholdTimeZone, isTrue);
    expect(document.candidates[1].durationMinutes, 45);
    expect(document.candidates[2].timeZone!.value, 'America/New_York');
    expect(document.candidates[2].durationMinutes, 60);
  });

  test('computes timed DTEND from instants across a DST transition', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:dst-duration@example.test',
        'DTSTART;TZID=America/New_York:20261101T013000',
        'DTEND;TZID=America/New_York:20261101T023000',
        'SUMMARY:Fallback event',
        'END:VEVENT',
      ]),
      householdZone,
    );

    final CalendarImportCandidate candidate = document.candidates.single;
    expect(candidate.durationMinutes, 120);
    expect(candidate.usesOverlapEarlier, isTrue);
  });

  test('applies nominal day duration across DST and skips a gap start', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:nominal-day@example.test',
        'DTSTART;TZID=America/New_York:20260307T090000',
        'DURATION:P1D',
        'SUMMARY:Nominal day',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:gap@example.test',
        'DTSTART;TZID=America/New_York:20260308T023000',
        'DURATION:PT30M',
        'SUMMARY:Gap',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(document.candidates.single.durationMinutes, 1380);
    expect(document.unsupportedEventCount, 1);
  });

  test('rejects oversized durations and date overflow without throwing', () {
    final String huge = '9' * 300;
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:huge-day@example.test',
        'DTSTART;VALUE=DATE:20260809',
        'DURATION:P${huge}D',
        'SUMMARY:Huge day',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:huge-hour@example.test',
        'DTSTART:20260809T010000Z',
        'DURATION:PT${huge}H',
        'SUMMARY:Huge hour',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:end-overflow@example.test',
        'DTSTART;VALUE=DATE:99991231',
        'SUMMARY:End overflow',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(document.candidates, isEmpty);
    expect(document.unsupportedEventCount, 3);
  });

  test('maps the strict daily weekly and monthly recurrence subset', () {
    final CalendarImportDocument document = _parsed(
      parser,
      _calendar(<String>[
        'BEGIN:VEVENT',
        'UID:daily@example.test',
        'DTSTART:20260810T090000Z',
        'DURATION:PT30M',
        'RRULE:FREQ=DAILY;INTERVAL=2;COUNT=5',
        'SUMMARY:Daily',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:weekly@example.test',
        'DTSTART:20260810T100000Z',
        'DURATION:PT30M',
        'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=8',
        'SUMMARY:Weekly',
        'END:VEVENT',
        'BEGIN:VEVENT',
        'UID:monthly@example.test',
        'DTSTART;VALUE=DATE:20260810',
        'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=10;UNTIL=20270810',
        'SUMMARY:Monthly',
        'END:VEVENT',
      ]),
      householdZone,
    );

    expect(document.candidates, hasLength(3));
    final CalendarRecurrenceRule daily = document.candidates[0].recurrenceRule!;
    expect(daily.frequency, CalendarRecurrenceFrequency.daily);
    expect(daily.interval, 2);
    expect((daily.end as CalendarRecurrenceCountEnd).count, 5);
    final CalendarRecurrenceRule weekly =
        document.candidates[1].recurrenceRule!;
    expect(weekly.weekdays, <CalendarWeekday>[
      CalendarWeekday.monday,
      CalendarWeekday.wednesday,
    ]);
    final CalendarRecurrenceRule monthly =
        document.candidates[2].recurrenceRule!;
    expect(monthly.monthDay, 10);
    expect(
      (monthly.end as CalendarRecurrenceUntilEnd).localDate.value,
      '2027-08-10',
    );
  });

  test(
    'aggregates invalid unsupported and duplicate events without UID output',
    () {
      final CalendarImportDocument document = _parsed(
        parser,
        _calendar(<String>[
          'BEGIN:VEVENT',
          'UID:kept@example.test',
          'DTSTART;VALUE=DATE:20260809',
          'SUMMARY:Kept',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:kept@example.test',
          'DTSTART;VALUE=DATE:20260810',
          'SUMMARY:Duplicate',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:unsupported@example.test',
          'DTSTART:20260810T090001Z',
          'DURATION:PT30M',
          'SUMMARY:Seconds',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:invalid@example.test',
          'SUMMARY:Missing start',
          'END:VEVENT',
        ]),
        householdZone,
      );

      expect(document.candidates.single.title, 'Kept');
      expect(document.invalidEventCount, 1);
      expect(document.unsupportedEventCount, 1);
      expect(document.duplicateEventCount, 1);
    },
  );

  test(
    'skips exceptions unknown zones mismatched end and broad recurrence',
    () {
      final CalendarImportDocument document = _parsed(
        parser,
        _calendar(<String>[
          'BEGIN:VEVENT',
          'UID:exception@example.test',
          'DTSTART:20260810T090000Z',
          'DURATION:PT30M',
          'EXDATE:20260811T090000Z',
          'SUMMARY:Exception',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:zone@example.test',
          'DTSTART;TZID=Custom/Unknown:20260810T090000',
          'DURATION:PT30M',
          'SUMMARY:Unknown zone',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:mismatch@example.test',
          'DTSTART;TZID=Asia/Seoul:20260810T090000',
          'DTEND:20260810T100000Z',
          'SUMMARY:Mismatch',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:yearly@example.test',
          'DTSTART;VALUE=DATE:20260810',
          'RRULE:FREQ=YEARLY',
          'SUMMARY:Yearly',
          'END:VEVENT',
        ]),
        householdZone,
      );

      expect(document.candidates, isEmpty);
      expect(document.unsupportedEventCount, 4);
    },
  );

  test('rejects fatal structure version size and event-count violations', () {
    expect(
      parser.parse(
        content: 'BEGIN:VCALENDAR\nVERSION:1.0\nEND:VCALENDAR',
        householdTimeZone: householdZone,
      ),
      isA<CalendarImportParseFailed>().having(
        (CalendarImportParseFailed value) => value.kind,
        'kind',
        CalendarImportParseFailureKind.unsupportedVersion,
      ),
    );
    expect(
      parser.parse(
        content: 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VEVENT',
        householdTimeZone: householdZone,
      ),
      isA<CalendarImportParseFailed>().having(
        (CalendarImportParseFailed value) => value.kind,
        'kind',
        CalendarImportParseFailureKind.invalidStructure,
      ),
    );
    expect(
      parser.parse(
        content: 'x' * (IcalendarImportParser.maximumBytes + 1),
        householdTimeZone: householdZone,
      ),
      isA<CalendarImportParseFailed>().having(
        (CalendarImportParseFailed value) => value.kind,
        'kind',
        CalendarImportParseFailureKind.tooLarge,
      ),
    );
    final List<String> events = <String>[];
    for (var index = 0; index <= IcalendarImportParser.maximumEvents; index++) {
      events.addAll(<String>[
        'BEGIN:VEVENT',
        'UID:$index@example.test',
        'DTSTART;VALUE=DATE:20260809',
        'SUMMARY:Event $index',
        'END:VEVENT',
      ]);
    }
    expect(
      parser.parse(
        content: _calendar(events),
        householdTimeZone: householdZone,
      ),
      isA<CalendarImportParseFailed>().having(
        (CalendarImportParseFailed value) => value.kind,
        'kind',
        CalendarImportParseFailureKind.tooManyEvents,
      ),
    );
  });
}

CalendarImportDocument _parsed(
  IcalendarImportParser parser,
  String content,
  IanaTimeZoneId householdZone,
) {
  final CalendarImportParseResult result = parser.parse(
    content: content,
    householdTimeZone: householdZone,
  );
  expect(result, isA<CalendarImportParsed>());
  return (result as CalendarImportParsed).document;
}

String _calendar(List<String> content) {
  return <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//KinFlow Test//EN',
    ...content,
    'END:VCALENDAR',
    '',
  ].join('\r\n');
}
