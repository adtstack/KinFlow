import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String notificationFailureMessage(
  AppLocalizations localizations,
  NotificationFailure failure,
) {
  return switch (failure.kind) {
    NotificationFailureKind.invalidInput =>
      localizations.notificationInvalidInputError,
    NotificationFailureKind.notFoundOrForbidden ||
    NotificationFailureKind.unauthenticated =>
      localizations.notificationPermissionError,
    NotificationFailureKind.versionConflict =>
      localizations.notificationVersionConflictError,
    NotificationFailureKind.snoozeUnavailable =>
      localizations.notificationSnoozeUnavailableError,
    NotificationFailureKind.temporarilyUnavailable ||
    NotificationFailureKind.invalidPayload ||
    NotificationFailureKind.unknown => localizations.notificationGenericError,
  };
}
