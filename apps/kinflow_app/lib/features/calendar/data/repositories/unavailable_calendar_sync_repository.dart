import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableCalendarSyncRepository
    implements CalendarSyncRepository {
  const UnavailableCalendarSyncRepository();

  @override
  Stream<CalendarSyncSignal> watch(HouseholdId householdId) =>
      const Stream<CalendarSyncSignal>.empty();
}
