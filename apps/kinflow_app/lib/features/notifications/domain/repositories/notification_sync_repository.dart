import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';

abstract interface class NotificationSyncRepository {
  Stream<NotificationSyncSignal> watch(AuthUserId authUserId);
}
