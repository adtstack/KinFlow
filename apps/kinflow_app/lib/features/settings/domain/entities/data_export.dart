import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

const String dataExportSchemaVersion = '2026-08-08-wp07-02a';

enum DataExportFormat {
  json('json'),
  text('text');

  const DataExportFormat(this.wireValue);

  final String wireValue;

  static DataExportFormat? tryParse(String value) {
    for (final DataExportFormat format in values) {
      if (format.wireValue == value) {
        return format;
      }
    }
    return null;
  }
}

enum DataExportRequestStatus {
  queued('queued'),
  verifying('verifying'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const DataExportRequestStatus(this.wireValue);

  final String wireValue;

  static DataExportRequestStatus? tryParse(String value) {
    for (final DataExportRequestStatus status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return null;
  }

  bool get isPending => switch (this) {
    queued || verifying || processing => true,
    completed || failed || cancelled => false,
  };
}

final class DataExportPreflight {
  const DataExportPreflight._({
    required this.canRequest,
    required this.pendingRequestId,
    required this.pendingStatus,
    required this.pendingRequestVersion,
    required this.conflictingRequestPending,
    required this.requestsEnabled,
    required this.downloadsEnabled,
    required this.artifactRetention,
    required this.downloadGrantLifetime,
    required this.evaluatedAt,
  });

  final bool canRequest;
  final DataExportRequestId? pendingRequestId;
  final DataExportRequestStatus? pendingStatus;
  final int? pendingRequestVersion;
  final bool conflictingRequestPending;
  final bool requestsEnabled;
  final bool downloadsEnabled;
  final Duration artifactRetention;
  final Duration downloadGrantLifetime;
  final DateTime evaluatedAt;

  bool get hasPendingRequest => pendingRequestId != null;

  static DataExportPreflight? tryCreate({
    required bool canRequest,
    required DataExportRequestId? pendingRequestId,
    required DataExportRequestStatus? pendingStatus,
    required int? pendingRequestVersion,
    required bool conflictingRequestPending,
    required bool requestsEnabled,
    required bool downloadsEnabled,
    required Duration artifactRetention,
    required Duration downloadGrantLifetime,
    required DateTime evaluatedAt,
  }) {
    final bool allPendingAbsent =
        pendingRequestId == null &&
        pendingStatus == null &&
        pendingRequestVersion == null;
    final bool allPendingPresent =
        pendingRequestId != null &&
        pendingStatus != null &&
        pendingRequestVersion != null;
    final bool expectedCanRequest =
        requestsEnabled &&
        !conflictingRequestPending &&
        pendingRequestId == null;
    if ((!allPendingAbsent && !allPendingPresent) ||
        pendingStatus != null && !pendingStatus.isPending ||
        pendingRequestVersion != null && pendingRequestVersion < 1 ||
        artifactRetention < const Duration(hours: 1) ||
        artifactRetention > const Duration(days: 7) ||
        downloadGrantLifetime < const Duration(minutes: 1) ||
        downloadGrantLifetime > const Duration(minutes: 15) ||
        !evaluatedAt.isUtc ||
        canRequest != expectedCanRequest) {
      return null;
    }
    return DataExportPreflight._(
      canRequest: canRequest,
      pendingRequestId: pendingRequestId,
      pendingStatus: pendingStatus,
      pendingRequestVersion: pendingRequestVersion,
      conflictingRequestPending: conflictingRequestPending,
      requestsEnabled: requestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      evaluatedAt: evaluatedAt,
    );
  }

  DataExportPreflight withPending(DataExportRequest request) {
    return DataExportPreflight._(
      canRequest: false,
      pendingRequestId: request.id,
      pendingStatus: request.status,
      pendingRequestVersion: request.version,
      conflictingRequestPending: false,
      requestsEnabled: requestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      evaluatedAt: evaluatedAt,
    );
  }

  DataExportPreflight withoutPending() {
    return DataExportPreflight._(
      canRequest: requestsEnabled && !conflictingRequestPending,
      pendingRequestId: null,
      pendingStatus: null,
      pendingRequestVersion: null,
      conflictingRequestPending: conflictingRequestPending,
      requestsEnabled: requestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      evaluatedAt: evaluatedAt,
    );
  }
}

final class DataExportArtifact {
  const DataExportArtifact._({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.expiresAt,
    required this.revokedAt,
    required this.purgedAt,
    required this.machineSizeBytes,
    required this.humanSizeBytes,
    required this.available,
  });

  final DataExportArtifactId id;
  final int version;
  final String schemaVersion;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? purgedAt;
  final int? machineSizeBytes;
  final int? humanSizeBytes;
  final bool available;

  static DataExportArtifact? tryCreate({
    required DataExportArtifactId id,
    required int version,
    required String schemaVersion,
    required DateTime? expiresAt,
    required DateTime? revokedAt,
    required DateTime? purgedAt,
    required int? machineSizeBytes,
    required int? humanSizeBytes,
    required bool available,
  }) {
    final bool sizesAbsent = machineSizeBytes == null && humanSizeBytes == null;
    final bool sizesPresent =
        machineSizeBytes != null && humanSizeBytes != null;
    if (version < 1 ||
        schemaVersion != dataExportSchemaVersion ||
        !_optionalUtc(expiresAt) ||
        !_optionalUtc(revokedAt) ||
        !_optionalUtc(purgedAt) ||
        (!sizesAbsent && !sizesPresent) ||
        machineSizeBytes != null &&
            (machineSizeBytes < 1 || machineSizeBytes > 10 * 1024 * 1024) ||
        humanSizeBytes != null &&
            (humanSizeBytes < 1 || humanSizeBytes > 10 * 1024 * 1024) ||
        available &&
            (expiresAt == null ||
                revokedAt != null ||
                purgedAt != null ||
                !sizesPresent)) {
      return null;
    }
    return DataExportArtifact._(
      id: id,
      version: version,
      schemaVersion: schemaVersion,
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      purgedAt: purgedAt,
      machineSizeBytes: machineSizeBytes,
      humanSizeBytes: humanSizeBytes,
      available: available,
    );
  }
}

final class DataExportRequest {
  const DataExportRequest._({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.processingStartedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.failureCode,
    required this.cancellable,
    required this.version,
    required this.artifact,
  });

  final DataExportRequestId id;
  final DataExportRequestStatus status;
  final DateTime requestedAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final String? failureCode;
  final bool cancellable;
  final int version;
  final DataExportArtifact artifact;

  static DataExportRequest? tryCreate({
    required DataExportRequestId id,
    required DataExportRequestStatus status,
    required DateTime requestedAt,
    required DateTime? processingStartedAt,
    required DateTime? completedAt,
    required DateTime? failedAt,
    required DateTime? cancelledAt,
    required String? failureCode,
    required bool cancellable,
    required int version,
    required DataExportArtifact artifact,
  }) {
    if (!requestedAt.isUtc ||
        version < 1 ||
        !_boundedTimestamp(processingStartedAt, requestedAt) ||
        !_boundedTimestamp(completedAt, processingStartedAt) ||
        !_boundedTimestamp(failedAt, processingStartedAt) ||
        !_boundedTimestamp(cancelledAt, requestedAt) ||
        !_validFailureCode(failureCode) ||
        !_validRequestShape(
          status: status,
          processingStartedAt: processingStartedAt,
          completedAt: completedAt,
          failedAt: failedAt,
          cancelledAt: cancelledAt,
          failureCode: failureCode,
          cancellable: cancellable,
          artifactAvailable: artifact.available,
        )) {
      return null;
    }
    return DataExportRequest._(
      id: id,
      status: status,
      requestedAt: requestedAt,
      processingStartedAt: processingStartedAt,
      completedAt: completedAt,
      failedAt: failedAt,
      cancelledAt: cancelledAt,
      failureCode: failureCode,
      cancellable: cancellable,
      version: version,
      artifact: artifact,
    );
  }
}

final class DataExportDownload {
  const DataExportDownload._({
    required this.format,
    required this.expiresAt,
    required this.uri,
  });

  final DataExportFormat format;
  final DateTime expiresAt;
  final Uri uri;

  static DataExportDownload? tryCreate({
    required DataExportFormat format,
    required DateTime expiresAt,
    required Uri uri,
  }) {
    final bool loopbackHttp =
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost');
    final List<String> tokens = uri.queryParametersAll['token'] ?? <String>[];
    if (!expiresAt.isUtc ||
        !(uri.scheme == 'https' || loopbackHttp) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.queryParametersAll.length != 1 ||
        tokens.length != 1 ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(tokens.single)) {
      return null;
    }
    return DataExportDownload._(format: format, expiresAt: expiresAt, uri: uri);
  }
}

bool _optionalUtc(DateTime? value) => value == null || value.isUtc;

bool _boundedTimestamp(DateTime? value, DateTime? lowerBound) {
  return value == null ||
      value.isUtc && lowerBound != null && !value.isBefore(lowerBound);
}

bool _validFailureCode(String? value) {
  return value == null ||
      <String>{
        'EXPORT_BUILD_UNAVAILABLE',
        'EXPORT_UPLOAD_UNAVAILABLE',
        'EXPORT_SIZE_LIMIT_EXCEEDED',
        'EXPORT_ATTEMPTS_EXHAUSTED',
        'PROCESSING_PRECONDITION_FAILED',
      }.contains(value);
}

bool _validRequestShape({
  required DataExportRequestStatus status,
  required DateTime? processingStartedAt,
  required DateTime? completedAt,
  required DateTime? failedAt,
  required DateTime? cancelledAt,
  required String? failureCode,
  required bool cancellable,
  required bool artifactAvailable,
}) {
  return switch (status) {
    DataExportRequestStatus.queued || DataExportRequestStatus.verifying =>
      processingStartedAt == null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt == null &&
          failureCode == null &&
          cancellable &&
          !artifactAvailable,
    DataExportRequestStatus.processing =>
      processingStartedAt != null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt == null &&
          !cancellable &&
          !artifactAvailable,
    DataExportRequestStatus.completed =>
      processingStartedAt != null &&
          completedAt != null &&
          failedAt == null &&
          cancelledAt == null &&
          failureCode == null &&
          !cancellable,
    DataExportRequestStatus.failed =>
      processingStartedAt != null &&
          completedAt == null &&
          failedAt != null &&
          cancelledAt == null &&
          failureCode != null &&
          !cancellable &&
          !artifactAvailable,
    DataExportRequestStatus.cancelled =>
      processingStartedAt == null &&
          completedAt == null &&
          failedAt == null &&
          cancelledAt != null &&
          failureCode == null &&
          !cancellable &&
          !artifactAvailable,
  };
}
