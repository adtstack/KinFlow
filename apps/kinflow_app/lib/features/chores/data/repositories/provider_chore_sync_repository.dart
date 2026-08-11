import 'package:kinflow_app/features/chores/data/datasources/chore_sync_data_source.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderChoreSyncRepository implements ChoreSyncRepository {
  const ProviderChoreSyncRepository(this._dataSource);

  final ChoreSyncDataSource _dataSource;

  @override
  Stream<ChoreSyncSignal> watch(HouseholdId householdId) async* {
    await for (final ChoreSyncDataSignal signal in _dataSource.watchHousehold(
      householdId.value,
    )) {
      switch (signal.kind) {
        case ChoreSyncDataSignalKind.connecting:
          yield const ChoreSyncConnecting();
        case ChoreSyncDataSignalKind.connected:
          yield const ChoreSyncConnected();
        case ChoreSyncDataSignalKind.changed:
          final int? generation = signal.generation;
          if (generation == null || generation < 1) {
            yield const ChoreSyncDisconnected();
          } else {
            yield ChoreSyncChanged(generation);
          }
        case ChoreSyncDataSignalKind.disconnected:
          yield const ChoreSyncDisconnected();
      }
    }
  }
}
