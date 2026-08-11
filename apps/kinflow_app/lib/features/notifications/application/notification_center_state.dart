import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';

sealed class NotificationCenterState {
  const NotificationCenterState();
}

final class NotificationCenterInitial extends NotificationCenterState {
  const NotificationCenterInitial();
}

final class NotificationCenterLoading extends NotificationCenterState {
  const NotificationCenterLoading();
}

final class NotificationCenterReady extends NotificationCenterState {
  const NotificationCenterReady(
    this.snapshot, {
    this.actionPending = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.actionFailure,
    this.loadMoreFailure,
    this.syncStatus = NotificationSyncConnectionStatus.disabled,
  });

  final NotificationSnapshot snapshot;
  final bool actionPending;
  final bool refreshing;
  final bool loadingMore;
  final NotificationFailure? actionFailure;
  final NotificationFailure? loadMoreFailure;
  final NotificationSyncConnectionStatus syncStatus;

  bool get busy => actionPending || refreshing || loadingMore;
}

final class NotificationCenterLoadFailed extends NotificationCenterState {
  const NotificationCenterLoadFailed(this.failure);

  final NotificationFailure failure;
}
