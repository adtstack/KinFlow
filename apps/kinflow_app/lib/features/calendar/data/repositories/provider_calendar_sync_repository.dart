import 'package:kinflow_app/features/calendar/data/datasources/calendar_sync_data_source.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderCalendarSyncRepository implements CalendarSyncRepository {
  const ProviderCalendarSyncRepository(this._dataSource);

  final CalendarSyncDataSource _dataSource;

  @override
  Stream<CalendarSyncSignal> watch(HouseholdId householdId) async* {
    await for (final CalendarSyncDataSignal signal
        in _dataSource.watchHousehold(householdId.value)) {
      switch (signal.kind) {
        case CalendarSyncDataSignalKind.connecting:
          yield const CalendarSyncConnecting();
        case CalendarSyncDataSignalKind.connected:
          yield const CalendarSyncConnected();
        case CalendarSyncDataSignalKind.changed:
          final int? generation = signal.generation;
          if (generation == null || generation < 1) {
            yield const CalendarSyncDisconnected();
          } else {
            yield CalendarSyncChanged(generation);
          }
        case CalendarSyncDataSignalKind.disconnected:
          yield const CalendarSyncDisconnected();
      }
    }
  }
}
