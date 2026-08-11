import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

final class UnavailableNotificationRepository
    implements NotificationRepository {
  const UnavailableNotificationRepository();

  static const NotificationFailure _failure = NotificationFailure(
    NotificationFailureKind.temporarilyUnavailable,
  );

  @override
  Future<NotificationResult<NotificationSnapshot>> loadSnapshot(
    HouseholdId householdId,
  ) async => const NotificationFailed<NotificationSnapshot>(_failure);

  @override
  Future<NotificationResult<NotificationInboxPage>> loadMore({
    required HouseholdId householdId,
    required NotificationInboxCursor cursor,
  }) async => const NotificationFailed<NotificationInboxPage>(_failure);

  @override
  Future<NotificationResult<NotificationReadReceipt>> markAllRead(
    HouseholdId householdId,
  ) async => const NotificationFailed<NotificationReadReceipt>(_failure);

  @override
  Future<NotificationResult<NotificationReadReceipt>> markRead({
    required HouseholdId householdId,
    required List<NotificationInboxItemId> itemIds,
  }) async => const NotificationFailed<NotificationReadReceipt>(_failure);

  @override
  Future<NotificationResult<NotificationPreference>> updatePreference(
    NotificationPreference preference,
  ) async => const NotificationFailed<NotificationPreference>(_failure);

  @override
  Future<NotificationResult<NotificationSnoozeReceipt>> snoozeCalendar({
    required HouseholdId householdId,
    required NotificationInboxItemId inboxItemId,
    required int snoozeMinutes,
    required NotificationSnoozeCommandId commandId,
    required int expectedItemVersion,
  }) async => const NotificationFailed<NotificationSnoozeReceipt>(_failure);

  @override
  Future<NotificationResult<NotificationPushTarget?>> resolvePushTarget(
    NotificationPushEnvelope envelope,
  ) async => const NotificationFailed<NotificationPushTarget?>(_failure);
}
