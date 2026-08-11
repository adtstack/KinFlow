enum CalendarSyncDataSignalKind { connecting, connected, changed, disconnected }

final class CalendarSyncDataSignal {
  const CalendarSyncDataSignal(this.kind, {this.generation});

  final CalendarSyncDataSignalKind kind;
  final int? generation;
}

abstract interface class CalendarSyncDataSource {
  Stream<CalendarSyncDataSignal> watchHousehold(String householdId);
}
