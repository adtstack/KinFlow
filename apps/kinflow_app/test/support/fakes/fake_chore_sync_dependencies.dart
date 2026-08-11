import 'dart:async';

import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class FakeChoreSyncRepository implements ChoreSyncRepository {
  final List<StreamController<ChoreSyncSignal>> controllers =
      <StreamController<ChoreSyncSignal>>[];
  final List<HouseholdId> watchedHouseholds = <HouseholdId>[];

  int get watchCount => controllers.length;

  StreamController<ChoreSyncSignal> get latest => controllers.last;

  bool hasListenerAt(int index) => controllers[index].hasListener;

  void addAt(int index, ChoreSyncSignal signal) {
    if (!controllers[index].isClosed) {
      controllers[index].add(signal);
    }
  }

  @override
  Stream<ChoreSyncSignal> watch(HouseholdId householdId) {
    final StreamController<ChoreSyncSignal> controller =
        StreamController<ChoreSyncSignal>.broadcast(sync: true);
    watchedHouseholds.add(householdId);
    controllers.add(controller);
    return controller.stream;
  }

  void addToAll(ChoreSyncSignal signal) {
    for (final StreamController<ChoreSyncSignal> controller in controllers) {
      if (!controller.isClosed) {
        controller.add(signal);
      }
    }
  }

  Future<void> dispose() async {
    for (final StreamController<ChoreSyncSignal> controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}
