enum ChoreSyncConnectionStatus { disabled, connecting, live, disconnected }

sealed class ChoreSyncSignal {
  const ChoreSyncSignal();
}

final class ChoreSyncConnecting extends ChoreSyncSignal {
  const ChoreSyncConnecting();
}

final class ChoreSyncConnected extends ChoreSyncSignal {
  const ChoreSyncConnected();
}

final class ChoreSyncChanged extends ChoreSyncSignal {
  const ChoreSyncChanged(this.generation);

  final int generation;
}

final class ChoreSyncDisconnected extends ChoreSyncSignal {
  const ChoreSyncDisconnected();
}
