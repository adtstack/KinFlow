import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String choreFailureMessage(
  AppLocalizations localizations,
  ChoreFailure failure,
) {
  return switch (failure.kind) {
    ChoreFailureKind.invalidInput => localizations.choreCreateInvalidError,
    ChoreFailureKind.notFoundOrForbidden ||
    ChoreFailureKind.unauthenticated => localizations.chorePermissionError,
    ChoreFailureKind.idempotencyConflict =>
      localizations.choreActionConflictError,
    ChoreFailureKind.invalidRecurrence =>
      localizations.choreRecurrenceInvalidError,
    ChoreFailureKind.staleVersion => localizations.choreVersionConflictError,
    ChoreFailureKind.invalidTransition =>
      localizations.choreTransitionConflictError,
    ChoreFailureKind.featurePolicyUnavailable =>
      localizations.featurePolicyUnavailableError,
    ChoreFailureKind.featureLimitReached =>
      localizations.featureLimitReachedError,
    ChoreFailureKind.offlineReadOnly => localizations.choreOfflineReadOnlyError,
    _ => localizations.choreGenericError,
  };
}
