import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';

abstract interface class NotificationRepository {
  Future<NotificationResult<NotificationSnapshot>> loadSnapshot(
    HouseholdId householdId,
  );

  Future<NotificationResult<NotificationInboxPage>> loadMore({
    required HouseholdId householdId,
    required NotificationInboxCursor cursor,
  });

  Future<NotificationResult<NotificationPreference>> updatePreference(
    NotificationPreference preference,
  );

  Future<NotificationResult<NotificationReadReceipt>> markRead({
    required HouseholdId householdId,
    required List<NotificationInboxItemId> itemIds,
  });

  Future<NotificationResult<NotificationReadReceipt>> markAllRead(
    HouseholdId householdId,
  );

  Future<NotificationResult<NotificationSnoozeReceipt>> snoozeCalendar({
    required HouseholdId householdId,
    required NotificationInboxItemId inboxItemId,
    required int snoozeMinutes,
    required NotificationSnoozeCommandId commandId,
    required int expectedItemVersion,
  });

  Future<NotificationResult<NotificationPushTarget?>> resolvePushTarget(
    NotificationPushEnvelope envelope,
  );
}

sealed class NotificationResult<T> {
  const NotificationResult();
}

final class NotificationSucceeded<T> extends NotificationResult<T> {
  const NotificationSucceeded(this.value);

  final T value;
}

final class NotificationFailed<T> extends NotificationResult<T> {
  const NotificationFailed(this.failure);

  final NotificationFailure failure;
}

final class NotificationReadReceipt {
  const NotificationReadReceipt({
    required this.markedCount,
    required this.unreadCount,
    required this.markedAt,
  });

  final int markedCount;
  final int unreadCount;
  final DateTime markedAt;
}
