enum NotificationSyncDataSignalKind {
  connecting,
  connected,
  changed,
  disconnected,
}

final class NotificationSyncDataSignal {
  const NotificationSyncDataSignal(this.kind, {this.generation});

  final NotificationSyncDataSignalKind kind;
  final int? generation;
}

abstract interface class NotificationSyncDataSource {
  Stream<NotificationSyncDataSignal> watchUser(String authUserId);
}
