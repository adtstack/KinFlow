import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

/// Content-free server projection used to navigate to one occurrence safely.
final class CalendarOccurrenceLocator {
  const CalendarOccurrenceLocator._({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.seriesId,
    required this.occurrenceId,
    required this.viewLocalDate,
    required this.seriesVersion,
    required this.occurrenceVersion,
  });

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final UtcInstant generatedAt;
  final CalendarEventSeriesId seriesId;
  final CalendarEventOccurrenceId occurrenceId;
  final CalendarLocalDate viewLocalDate;
  final int seriesVersion;
  final int occurrenceVersion;

  static CalendarOccurrenceLocator? tryCreate({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required CalendarLocalDate householdLocalDate,
    required UtcInstant generatedAt,
    required CalendarEventSeriesId seriesId,
    required CalendarEventOccurrenceId occurrenceId,
    required CalendarLocalDate viewLocalDate,
    required int seriesVersion,
    required int occurrenceVersion,
  }) {
    if (seriesVersion < 1 || occurrenceVersion < 1) {
      return null;
    }
    return CalendarOccurrenceLocator._(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      viewLocalDate: viewLocalDate,
      seriesVersion: seriesVersion,
      occurrenceVersion: occurrenceVersion,
    );
  }
}
