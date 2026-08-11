import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class CalendarImportRouteContext {
  const CalendarImportRouteContext({
    required this.householdId,
    required this.householdTimeZone,
  });

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
}
