import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

String dataExportFailureMessage(
  AppLocalizations localizations,
  DataExportFailure failure,
) {
  return switch (failure.kind) {
    DataExportFailureKind.unauthenticated ||
    DataExportFailureKind.permissionDenied ||
    DataExportFailureKind.notFound => localizations.dataExportPermissionError,
    DataExportFailureKind.recentAuthenticationRequired =>
      localizations.dataExportRecentAuthError,
    DataExportFailureKind.recentAuthenticationCancelled =>
      localizations.dataExportRecentAuthCancelled,
    DataExportFailureKind.accountChanged =>
      localizations.dataExportAccountChangedError,
    DataExportFailureKind.requestsPaused => localizations.dataExportPausedError,
    DataExportFailureKind.downloadsPaused =>
      localizations.dataExportDownloadsPausedError,
    DataExportFailureKind.idempotencyConflict ||
    DataExportFailureKind.versionConflict ||
    DataExportFailureKind.notCancellable =>
      localizations.dataExportConflictError,
    DataExportFailureKind.alreadyPending =>
      localizations.dataExportPendingError,
    DataExportFailureKind.artifactUnavailable =>
      localizations.dataExportUnavailableError,
    DataExportFailureKind.exportTooLarge =>
      localizations.dataExportTooLargeError,
    DataExportFailureKind.launchFailed => localizations.dataExportLaunchError,
    DataExportFailureKind.invalidInput ||
    DataExportFailureKind.temporarilyUnavailable ||
    DataExportFailureKind.invalidPayload ||
    DataExportFailureKind.internal ||
    DataExportFailureKind.unknown => localizations.dataExportGenericError,
  };
}
