import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/infrastructure/timezone/bundled_timezone_database.dart';
import 'package:timezone/timezone.dart' as timezone;

final class TimezoneCalendarTimeResolver implements CalendarTimeResolver {
  TimezoneCalendarTimeResolver() {
    BundledTimezoneDatabase.initialize();
  }

  static const String bundledDatabaseVersion = BundledTimezoneDatabase.version;

  @override
  String get databaseVersion => bundledDatabaseVersion;

  @override
  CalendarTimeResolution resolve(CalendarZonedDateTimeIntent intent) {
    final timezone.Location? location = _location(intent.timeZone);
    if (location == null) {
      return UnsupportedCalendarTimeZone(intent.timeZone);
    }

    final DateTime localOnUtcTimeline = DateTime.utc(
      intent.localDate.toUtcCalendarDate().year,
      intent.localDate.toUtcCalendarDate().month,
      intent.localDate.toUtcCalendarDate().day,
      intent.localTime.hour,
      intent.localTime.minute,
    );
    final Set<Duration> offsets = location.zones
        .map((timezone.TimeZone zone) => zone.offset)
        .toSet();
    if (identical(location, timezone.UTC)) {
      offsets.add(Duration.zero);
    }

    final Map<int, DateTime> candidatesByMicrosecond = <int, DateTime>{};
    for (final Duration offset in offsets) {
      final DateTime candidate = localOnUtcTimeline.subtract(offset);
      final timezone.TZDateTime projected = timezone.TZDateTime.from(
        candidate,
        location,
      );
      if (_matchesIntent(projected, intent)) {
        candidatesByMicrosecond[candidate.microsecondsSinceEpoch] = candidate;
      }
    }
    final List<DateTime> candidates = candidatesByMicrosecond.values.toList()
      ..sort();
    if (candidates.isEmpty) {
      return NonexistentCalendarLocalTime(intent);
    }

    final bool overlap = candidates.length > 1;
    final DateTime selected =
        overlap && intent.overlapPolicy == CalendarDstOverlapPolicy.later
        ? candidates.last
        : candidates.first;
    final timezone.TZDateTime projected = timezone.TZDateTime.from(
      selected,
      location,
    );
    return ResolvedCalendarTime(
      instant: UtcInstant.tryFromDateTime(selected)!,
      utcOffset: projected.timeZoneOffset,
      kind: overlap
          ? intent.overlapPolicy == CalendarDstOverlapPolicy.earlier
                ? CalendarTimeResolutionKind.overlapEarlier
                : CalendarTimeResolutionKind.overlapLater
          : CalendarTimeResolutionKind.normal,
      candidateCount: candidates.length,
    );
  }

  @override
  bool supports(IanaTimeZoneId timeZone) => _location(timeZone) != null;

  timezone.Location? _location(IanaTimeZoneId timeZone) {
    if (timeZone.value == 'UTC') {
      return timezone.UTC;
    }
    try {
      return timezone.getLocation(timeZone.value);
    } on timezone.LocationNotFoundException {
      return null;
    }
  }

  bool _matchesIntent(
    timezone.TZDateTime projected,
    CalendarZonedDateTimeIntent intent,
  ) {
    final DateTime date = intent.localDate.toUtcCalendarDate();
    return projected.year == date.year &&
        projected.month == date.month &&
        projected.day == date.day &&
        projected.hour == intent.localTime.hour &&
        projected.minute == intent.localTime.minute &&
        projected.second == 0 &&
        projected.millisecond == 0 &&
        projected.microsecond == 0;
  }
}
