enum ChoreSyncDataSignalKind { connecting, connected, changed, disconnected }

final class ChoreSyncDataSignal {
  const ChoreSyncDataSignal(this.kind, {this.generation});

  final ChoreSyncDataSignalKind kind;
  final int? generation;
}

abstract interface class ChoreSyncDataSource {
  Stream<ChoreSyncDataSignal> watchHousehold(String householdId);
}
