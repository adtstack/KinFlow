import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class CalendarSyncRepository {
  Stream<CalendarSyncSignal> watch(HouseholdId householdId);
}
