import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

enum CalendarTimeResolutionKind {
  normal('normal'),
  overlapEarlier('overlap_earlier'),
  overlapLater('overlap_later');

  const CalendarTimeResolutionKind(this.wireValue);

  final String wireValue;

  static CalendarTimeResolutionKind? tryParse(String value) {
    return switch (value) {
      'normal' => CalendarTimeResolutionKind.normal,
      'overlap_earlier' => CalendarTimeResolutionKind.overlapEarlier,
      'overlap_later' => CalendarTimeResolutionKind.overlapLater,
      _ => null,
    };
  }
}

sealed class CalendarTimeResolution {
  const CalendarTimeResolution();
}

final class ResolvedCalendarTime extends CalendarTimeResolution {
  const ResolvedCalendarTime({
    required this.instant,
    required this.utcOffset,
    required this.kind,
    required this.candidateCount,
  });

  final UtcInstant instant;
  final Duration utcOffset;
  final CalendarTimeResolutionKind kind;
  final int candidateCount;
}

final class NonexistentCalendarLocalTime extends CalendarTimeResolution {
  const NonexistentCalendarLocalTime(this.intent);

  final CalendarZonedDateTimeIntent intent;
}

final class UnsupportedCalendarTimeZone extends CalendarTimeResolution {
  const UnsupportedCalendarTimeZone(this.timeZone);

  final IanaTimeZoneId timeZone;
}

abstract interface class CalendarTimeResolver {
  String get databaseVersion;

  bool supports(IanaTimeZoneId timeZone);

  CalendarTimeResolution resolve(CalendarZonedDateTimeIntent intent);
}
