enum NotificationSyncConnectionStatus {
  disabled,
  connecting,
  live,
  disconnected,
}

sealed class NotificationSyncSignal {
  const NotificationSyncSignal();
}

final class NotificationSyncConnecting extends NotificationSyncSignal {
  const NotificationSyncConnecting();
}

final class NotificationSyncConnected extends NotificationSyncSignal {
  const NotificationSyncConnected();
}

final class NotificationSyncChanged extends NotificationSyncSignal {
  const NotificationSyncChanged(this.generation);

  final int generation;
}

final class NotificationSyncDisconnected extends NotificationSyncSignal {
  const NotificationSyncDisconnected();
}
