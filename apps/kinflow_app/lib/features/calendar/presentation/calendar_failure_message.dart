import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String calendarFailureMessage(
  AppLocalizations localizations,
  CalendarFailure failure,
) {
  return switch (failure.kind) {
    CalendarFailureKind.invalidInput => localizations.calendarInvalidError,
    CalendarFailureKind.notFoundOrForbidden ||
    CalendarFailureKind.unauthenticated =>
      localizations.calendarPermissionError,
    CalendarFailureKind.idempotencyConflict =>
      localizations.calendarRetryConflictError,
    CalendarFailureKind.staleVersion =>
      localizations.calendarVersionConflictError,
    CalendarFailureKind.nonexistentLocalTime =>
      localizations.calendarNonexistentTimeError,
    CalendarFailureKind.transitionNotAllowed =>
      localizations.calendarOccurrenceTransitionError,
    CalendarFailureKind.featurePolicyUnavailable =>
      localizations.featurePolicyUnavailableError,
    CalendarFailureKind.featureLimitReached =>
      localizations.featureLimitReachedError,
    CalendarFailureKind.temporarilyUnavailable ||
    CalendarFailureKind.invalidPayload ||
    CalendarFailureKind.internal => localizations.calendarGenericError,
  };
}
