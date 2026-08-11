import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_sync_data_source.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';

import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test(
    'maps every data signal and fails malformed generations closed',
    () async {
      final _FakeChoreSyncDataSource dataSource = _FakeChoreSyncDataSource();
      final ProviderChoreSyncRepository repository =
          ProviderChoreSyncRepository(dataSource);
      final Future<List<ChoreSyncSignal>> result = repository
          .watch(activeHouseholdFixture().householdId)
          .take(5)
          .toList();
      await Future<void>.delayed(Duration.zero);

      dataSource.controller
        ..add(const ChoreSyncDataSignal(ChoreSyncDataSignalKind.connecting))
        ..add(const ChoreSyncDataSignal(ChoreSyncDataSignalKind.connected))
        ..add(
          const ChoreSyncDataSignal(
            ChoreSyncDataSignalKind.changed,
            generation: 4,
          ),
        )
        ..add(const ChoreSyncDataSignal(ChoreSyncDataSignalKind.changed))
        ..add(const ChoreSyncDataSignal(ChoreSyncDataSignalKind.disconnected));

      expect(await result, <Object>[
        isA<ChoreSyncConnecting>(),
        isA<ChoreSyncConnected>(),
        isA<ChoreSyncChanged>().having(
          (ChoreSyncChanged signal) => signal.generation,
          'generation',
          4,
        ),
        isA<ChoreSyncDisconnected>(),
        isA<ChoreSyncDisconnected>(),
      ]);
      expect(
        dataSource.householdId,
        activeHouseholdFixture().householdId.value,
      );
      await dataSource.dispose();
    },
  );
}

final class _FakeChoreSyncDataSource implements ChoreSyncDataSource {
  final StreamController<ChoreSyncDataSignal> controller =
      StreamController<ChoreSyncDataSignal>.broadcast(sync: true);
  String? householdId;

  @override
  Stream<ChoreSyncDataSignal> watchHousehold(String householdId) {
    this.householdId = householdId;
    return controller.stream;
  }

  Future<void> dispose() => controller.close();
}
