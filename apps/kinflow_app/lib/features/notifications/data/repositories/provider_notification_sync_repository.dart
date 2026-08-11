import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_sync_data_source.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';

final class ProviderNotificationSyncRepository
    implements NotificationSyncRepository {
  const ProviderNotificationSyncRepository(this._dataSource);

  final NotificationSyncDataSource _dataSource;

  @override
  Stream<NotificationSyncSignal> watch(AuthUserId authUserId) async* {
    await for (final NotificationSyncDataSignal signal in _dataSource.watchUser(
      authUserId.value,
    )) {
      switch (signal.kind) {
        case NotificationSyncDataSignalKind.connecting:
          yield const NotificationSyncConnecting();
        case NotificationSyncDataSignalKind.connected:
          yield const NotificationSyncConnected();
        case NotificationSyncDataSignalKind.changed:
          final int? generation = signal.generation;
          if (generation == null || generation < 1) {
            yield const NotificationSyncDisconnected();
          } else {
            yield NotificationSyncChanged(generation);
          }
        case NotificationSyncDataSignalKind.disconnected:
          yield const NotificationSyncDisconnected();
      }
    }
  }
}
