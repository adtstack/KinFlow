import 'dart:async';

import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';

final class FakeNotificationSyncRepository
    implements NotificationSyncRepository {
  final List<StreamController<NotificationSyncSignal>> controllers =
      <StreamController<NotificationSyncSignal>>[];
  final List<AuthUserId> watchedUsers = <AuthUserId>[];

  int get watchCount => controllers.length;

  StreamController<NotificationSyncSignal> get latest => controllers.last;

  bool hasListenerAt(int index) => controllers[index].hasListener;

  void addAt(int index, NotificationSyncSignal signal) {
    if (!controllers[index].isClosed) {
      controllers[index].add(signal);
    }
  }

  @override
  Stream<NotificationSyncSignal> watch(AuthUserId authUserId) {
    final StreamController<NotificationSyncSignal> controller =
        StreamController<NotificationSyncSignal>.broadcast(sync: true);
    watchedUsers.add(authUserId);
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final StreamController<NotificationSyncSignal> controller
        in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}
