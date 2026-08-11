enum CalendarSyncConnectionStatus { disabled, connecting, live, disconnected }

sealed class CalendarSyncSignal {
  const CalendarSyncSignal();
}

final class CalendarSyncConnecting extends CalendarSyncSignal {
  const CalendarSyncConnecting();
}

final class CalendarSyncConnected extends CalendarSyncSignal {
  const CalendarSyncConnected();
}

final class CalendarSyncChanged extends CalendarSyncSignal {
  const CalendarSyncChanged(this.generation);

  final int generation;
}

final class CalendarSyncDisconnected extends CalendarSyncSignal {
  const CalendarSyncDisconnected();
}
