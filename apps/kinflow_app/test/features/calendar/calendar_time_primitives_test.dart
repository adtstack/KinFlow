import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

void main() {
  group('Calendar time value objects', () {
    test('parses strict dates and preserves calendar arithmetic', () {
      final CalendarLocalDate leapDay = _date('2028-02-29');

      expect(leapDay.value, '2028-02-29');
      expect(leapDay.addDays(1).value, '2028-03-01');
      expect(_date('2026-12-31').addDays(1).value, '2027-01-01');
      expect(_date('2026-07-16').differenceInDays(_date('2026-07-14')), 2);
      expect(CalendarLocalDate.tryParse('2027-02-29'), isNull);
      expect(CalendarLocalDate.tryParse('2026-2-01'), isNull);
      expect(CalendarLocalDate.tryParse('0000-01-01'), isNull);
    });

    test('keeps local time at minute precision', () {
      final CalendarLocalTime value = _time('09:05');

      expect(value.hour, 9);
      expect(value.minute, 5);
      expect(value.minutesSinceMidnight, 545);
      expect(value.compareTo(_time('09:06')), lessThan(0));
      expect(CalendarLocalTime.tryParse('09:05:00'), isNull);
      expect(CalendarLocalTime.tryParse('24:00'), isNull);
      expect(CalendarLocalTime.tryParse('9:05'), isNull);
    });

    test('accepts only explicit UTC Z instants', () {
      final UtcInstant value = UtcInstant.tryParse('2026-07-14T00:00:00Z')!;

      expect(value.dateTime, DateTime.utc(2026, 7, 14));
      expect(value.value, '2026-07-14T00:00:00.000Z');
      expect(UtcInstant.tryFromDateTime(DateTime.utc(2026, 7, 14)), value);
      expect(UtcInstant.tryParse('2026-07-14T00:00:00+00:00'), isNull);
      expect(UtcInstant.tryFromDateTime(DateTime(2026, 7, 14)), isNull);
    });

    test('accepts canonical IANA shapes and rejects abbreviations', () {
      expect(_zone('Asia/Seoul').value, 'Asia/Seoul');
      expect(_zone('America/Argentina/Buenos_Aires').value, contains('/'));
      expect(_zone('Etc/GMT+5').value, 'Etc/GMT+5');
      expect(_zone('UTC').value, 'UTC');
      expect(IanaTimeZoneId.tryParse('PST'), isNull);
      expect(IanaTimeZoneId.tryParse('utc'), isNull);
      expect(IanaTimeZoneId.tryParse('Asia Seoul'), isNull);
    });
  });

  group('CalendarAllDayRange', () {
    test('uses an inclusive start and exclusive end', () {
      final CalendarAllDayRange range = _range('2026-07-14', '2026-07-16');

      expect(range.dayCount, 2);
      expect(range.contains(_date('2026-07-14')), isTrue);
      expect(range.contains(_date('2026-07-15')), isTrue);
      expect(range.contains(_date('2026-07-16')), isFalse);
      expect(range.overlaps(_range('2026-07-15', '2026-07-17')), isTrue);
      expect(range.overlaps(_range('2026-07-16', '2026-07-17')), isFalse);
    });

    test('round trips exact date-only JSON without a timezone', () {
      final CalendarAllDayRange range = _range('2026-01-01', '2026-01-02');

      expect(CalendarAllDayRange.tryParseExact(range.toJson()), range);
      expect(range.toJson(), <String, Object?>{
        'startDate': '2026-01-01',
        'endDateExclusive': '2026-01-02',
      });
      expect(
        CalendarAllDayRange.tryParseExact(<String, Object?>{
          ...range.toJson(),
          'timezone': 'Pacific/Auckland',
        }),
        isNull,
      );
      expect(
        CalendarAllDayRange.tryCreate(
          startDate: _date('2026-01-01'),
          endDateExclusive: _date('2026-01-01'),
        ),
        isNull,
      );
    });
  });

  group('CalendarZonedDateTimeIntent serialization', () {
    test('round trips exact policy keys with earlier as the default', () {
      final CalendarZonedDateTimeIntent intent = _intent(
        '2026-07-14',
        '09:00',
        'Asia/Seoul',
      );

      expect(intent.toJson(), <String, Object?>{
        'localDate': '2026-07-14',
        'localTime': '09:00',
        'timezone': 'Asia/Seoul',
        'gapPolicy': 'reject',
        'overlapPolicy': 'earlier',
      });
      expect(
        CalendarZonedDateTimeIntent.tryParseExact(intent.toJson()),
        intent,
      );
      expect(intent.fingerprint, contains('"gapPolicy":"reject"'));
    });

    test('retains later overlap and rejects extra or unknown policy', () {
      final CalendarZonedDateTimeIntent later = _intent(
        '2026-11-01',
        '01:30',
        'America/Los_Angeles',
        overlapPolicy: CalendarDstOverlapPolicy.later,
      );

      expect(
        CalendarZonedDateTimeIntent.tryParseExact(
          later.toJson(),
        )?.overlapPolicy,
        CalendarDstOverlapPolicy.later,
      );
      expect(
        CalendarZonedDateTimeIntent.tryParseExact(<String, Object?>{
          ...later.toJson(),
          'offset': '-08:00',
        }),
        isNull,
      );
      expect(
        CalendarZonedDateTimeIntent.tryParseExact(<String, Object?>{
          ...later.toJson(),
          'gapPolicy': 'shift_forward',
        }),
        isNull,
      );
    });
  });

  group('TimezoneCalendarTimeResolver', () {
    final TimezoneCalendarTimeResolver resolver =
        TimezoneCalendarTimeResolver();

    test('exposes the pinned database and validates actual zones', () {
      expect(resolver.databaseVersion, '2025c');
      expect(resolver.supports(_zone('UTC')), isTrue);
      expect(resolver.supports(_zone('Asia/Seoul')), isTrue);
      expect(resolver.supports(_zone('America/Not_A_Zone')), isFalse);
      expect(
        resolver.resolve(_intent('2026-07-14', '09:00', 'America/Not_A_Zone')),
        isA<UnsupportedCalendarTimeZone>(),
      );
    });

    test('resolves basic Seoul and UTC local intent exactly', () {
      _expectResolved(
        resolver.resolve(_intent('2026-07-14', '09:00', 'Asia/Seoul')),
        instant: '2026-07-14T00:00:00.000Z',
        offset: const Duration(hours: 9),
        kind: CalendarTimeResolutionKind.normal,
      );
      _expectResolved(
        resolver.resolve(_intent('2026-07-14', '09:00', 'UTC')),
        instant: '2026-07-14T09:00:00.000Z',
        offset: Duration.zero,
        kind: CalendarTimeResolutionKind.normal,
      );
    });

    test('preserves weekly Los Angeles wall time across spring DST', () {
      _expectResolved(
        resolver.resolve(_intent('2026-03-01', '08:00', 'America/Los_Angeles')),
        instant: '2026-03-01T16:00:00.000Z',
        offset: const Duration(hours: -8),
        kind: CalendarTimeResolutionKind.normal,
      );
      _expectResolved(
        resolver.resolve(_intent('2026-03-08', '08:00', 'America/Los_Angeles')),
        instant: '2026-03-08T15:00:00.000Z',
        offset: const Duration(hours: -7),
        kind: CalendarTimeResolutionKind.normal,
      );
    });

    test('preserves weekly Los Angeles wall time across fall DST', () {
      _expectResolved(
        resolver.resolve(_intent('2026-10-25', '08:00', 'America/Los_Angeles')),
        instant: '2026-10-25T15:00:00.000Z',
        offset: const Duration(hours: -7),
        kind: CalendarTimeResolutionKind.normal,
      );
      _expectResolved(
        resolver.resolve(_intent('2026-11-01', '08:00', 'America/Los_Angeles')),
        instant: '2026-11-01T16:00:00.000Z',
        offset: const Duration(hours: -8),
        kind: CalendarTimeResolutionKind.normal,
      );
    });

    test('rejects Los Angeles and Berlin spring gaps', () {
      expect(
        resolver.resolve(_intent('2026-03-08', '02:30', 'America/Los_Angeles')),
        isA<NonexistentCalendarLocalTime>(),
      );
      expect(
        resolver.resolve(_intent('2026-03-29', '02:30', 'Europe/Berlin')),
        isA<NonexistentCalendarLocalTime>(),
      );
    });

    test('selects explicit earlier and later Los Angeles overlap instants', () {
      final ResolvedCalendarTime earlier =
          resolver.resolve(
                _intent('2026-11-01', '01:30', 'America/Los_Angeles'),
              )
              as ResolvedCalendarTime;
      final ResolvedCalendarTime later =
          resolver.resolve(
                _intent(
                  '2026-11-01',
                  '01:30',
                  'America/Los_Angeles',
                  overlapPolicy: CalendarDstOverlapPolicy.later,
                ),
              )
              as ResolvedCalendarTime;

      expect(earlier.instant.value, '2026-11-01T08:30:00.000Z');
      expect(earlier.utcOffset, const Duration(hours: -7));
      expect(earlier.kind, CalendarTimeResolutionKind.overlapEarlier);
      expect(earlier.candidateCount, 2);
      expect(later.instant.value, '2026-11-01T09:30:00.000Z');
      expect(later.utcOffset, const Duration(hours: -8));
      expect(later.kind, CalendarTimeResolutionKind.overlapLater);
      expect(later.candidateCount, 2);
      expect(
        later.instant.dateTime.difference(earlier.instant.dateTime),
        1.hours,
      );
    });

    test('handles Lord Howe thirty-minute gaps and overlaps', () {
      expect(
        resolver.resolve(_intent('2026-10-04', '02:15', 'Australia/Lord_Howe')),
        isA<NonexistentCalendarLocalTime>(),
      );
      final ResolvedCalendarTime earlier =
          resolver.resolve(
                _intent('2026-04-05', '01:45', 'Australia/Lord_Howe'),
              )
              as ResolvedCalendarTime;
      final ResolvedCalendarTime later =
          resolver.resolve(
                _intent(
                  '2026-04-05',
                  '01:45',
                  'Australia/Lord_Howe',
                  overlapPolicy: CalendarDstOverlapPolicy.later,
                ),
              )
              as ResolvedCalendarTime;

      expect(earlier.candidateCount, 2);
      expect(later.candidateCount, 2);
      expect(
        later.instant.dateTime.difference(earlier.instant.dateTime),
        const Duration(minutes: 30),
      );
    });
  });
}

extension on int {
  Duration get hours => Duration(hours: this);
}

CalendarLocalDate _date(String value) => CalendarLocalDate.tryParse(value)!;

CalendarLocalTime _time(String value) => CalendarLocalTime.tryParse(value)!;

IanaTimeZoneId _zone(String value) => IanaTimeZoneId.tryParse(value)!;

CalendarAllDayRange _range(String start, String endExclusive) {
  return CalendarAllDayRange.tryCreate(
    startDate: _date(start),
    endDateExclusive: _date(endExclusive),
  )!;
}

CalendarZonedDateTimeIntent _intent(
  String date,
  String time,
  String timeZone, {
  CalendarDstOverlapPolicy overlapPolicy = CalendarDstOverlapPolicy.earlier,
}) {
  return CalendarZonedDateTimeIntent.create(
    localDate: _date(date),
    localTime: _time(time),
    timeZone: _zone(timeZone),
    overlapPolicy: overlapPolicy,
  );
}

void _expectResolved(
  CalendarTimeResolution result, {
  required String instant,
  required Duration offset,
  required CalendarTimeResolutionKind kind,
}) {
  expect(result, isA<ResolvedCalendarTime>());
  final ResolvedCalendarTime resolved = result as ResolvedCalendarTime;
  expect(resolved.instant.value, instant);
  expect(resolved.utcOffset, offset);
  expect(resolved.kind, kind);
  expect(resolved.candidateCount, 1);
}
