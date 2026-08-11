import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/household_privacy_identifiers.dart';

const String householdPrivacySchemaVersion = '2026-08-08-wp07-02b';
const int householdExportMaximumFileBytes = 20 * 1024 * 1024;

enum HouseholdExportFormat {
  json('json'),
  text('text');

  const HouseholdExportFormat(this.wireValue);

  final String wireValue;

  static HouseholdExportFormat? tryParse(String value) {
    for (final HouseholdExportFormat format in values) {
      if (format.wireValue == value) {
        return format;
      }
    }
    return null;
  }
}

enum HouseholdPrivacyRequestKind {
  export('export'),
  deletion('deletion');

  const HouseholdPrivacyRequestKind(this.wireValue);

  final String wireValue;

  static HouseholdPrivacyRequestKind? tryParse(String value) {
    for (final HouseholdPrivacyRequestKind kind in values) {
      if (kind.wireValue == value) {
        return kind;
      }
    }
    return null;
  }
}

enum HouseholdPrivacyRequestStatus {
  queued('queued'),
  verifying('verifying'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const HouseholdPrivacyRequestStatus(this.wireValue);

  final String wireValue;

  static HouseholdPrivacyRequestStatus? tryParse(String value) {
    for (final HouseholdPrivacyRequestStatus status in values) {
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

final class HouseholdPrivacyHousehold {
  const HouseholdPrivacyHousehold._({
    required this.id,
    required this.name,
    required this.version,
  });

  final HouseholdId id;
  final String name;
  final int version;

  static HouseholdPrivacyHousehold? tryCreate({
    required HouseholdId id,
    required String name,
    required int version,
  }) {
    if (!_validHouseholdName(name) || version < 1) {
      return null;
    }
    return HouseholdPrivacyHousehold._(id: id, name: name, version: version);
  }
}

final class HouseholdExportArtifact {
  const HouseholdExportArtifact._({
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

  final HouseholdExportArtifactId id;
  final int version;
  final String schemaVersion;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? purgedAt;
  final int? machineSizeBytes;
  final int? humanSizeBytes;
  final bool available;

  static HouseholdExportArtifact? tryCreate({
    required HouseholdExportArtifactId id,
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
        schemaVersion != householdPrivacySchemaVersion ||
        !_optionalUtc(expiresAt) ||
        !_optionalUtc(revokedAt) ||
        !_optionalUtc(purgedAt) ||
        (!sizesAbsent && !sizesPresent) ||
        !_validExportSize(machineSizeBytes) ||
        !_validExportSize(humanSizeBytes) ||
        available &&
            (expiresAt == null ||
                revokedAt != null ||
                purgedAt != null ||
                !sizesPresent)) {
      return null;
    }
    return HouseholdExportArtifact._(
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

final class HouseholdDeletionProgress {
  const HouseholdDeletionProgress._({
    required this.retentionBlocked,
    required this.retentionReviewAt,
    required this.accessRevokedAt,
    required this.redactedAt,
    required this.billingUnlinkedAt,
  });

  final bool retentionBlocked;
  final DateTime? retentionReviewAt;
  final DateTime? accessRevokedAt;
  final DateTime? redactedAt;
  final DateTime? billingUnlinkedAt;

  static HouseholdDeletionProgress? tryCreate({
    required bool retentionBlocked,
    required DateTime? retentionReviewAt,
    required DateTime? accessRevokedAt,
    required DateTime? redactedAt,
    required DateTime? billingUnlinkedAt,
  }) {
    if (!_optionalUtc(retentionReviewAt) ||
        !_optionalUtc(accessRevokedAt) ||
        !_optionalUtc(redactedAt) ||
        !_optionalUtc(billingUnlinkedAt) ||
        !retentionBlocked && retentionReviewAt != null) {
      return null;
    }
    return HouseholdDeletionProgress._(
      retentionBlocked: retentionBlocked,
      retentionReviewAt: retentionReviewAt,
      accessRevokedAt: accessRevokedAt,
      redactedAt: redactedAt,
      billingUnlinkedAt: billingUnlinkedAt,
    );
  }
}

final class HouseholdPrivacyRequest {
  const HouseholdPrivacyRequest._({
    required this.id,
    required this.kind,
    required this.householdId,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
    required this.processingStartedAt,
    required this.completedAt,
    required this.failedAt,
    required this.cancelledAt,
    required this.failureCode,
    required this.cancellable,
    required this.version,
    required this.activeSubscriptionAtRequest,
    required this.artifact,
    required this.deletion,
  });

  final HouseholdPrivacyRequestId id;
  final HouseholdPrivacyRequestKind kind;
  final HouseholdId householdId;
  final HouseholdPrivacyRequestStatus status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final String? failureCode;
  final bool cancellable;
  final int version;
  final bool activeSubscriptionAtRequest;
  final HouseholdExportArtifact? artifact;
  final HouseholdDeletionProgress? deletion;

  static HouseholdPrivacyRequest? tryCreate({
    required HouseholdPrivacyRequestId id,
    required HouseholdPrivacyRequestKind kind,
    required HouseholdId householdId,
    required HouseholdPrivacyRequestStatus status,
    required DateTime requestedAt,
    required DateTime scheduledFor,
    required DateTime? processingStartedAt,
    required DateTime? completedAt,
    required DateTime? failedAt,
    required DateTime? cancelledAt,
    required String? failureCode,
    required bool cancellable,
    required int version,
    required bool activeSubscriptionAtRequest,
    required HouseholdExportArtifact? artifact,
    required HouseholdDeletionProgress? deletion,
  }) {
    final bool kindShape = switch (kind) {
      HouseholdPrivacyRequestKind.export =>
        artifact != null && deletion == null,
      HouseholdPrivacyRequestKind.deletion =>
        artifact == null && deletion != null,
    };
    final bool statusShape = switch (status) {
      HouseholdPrivacyRequestStatus.queued ||
      HouseholdPrivacyRequestStatus.verifying =>
        completedAt == null &&
            failedAt == null &&
            cancelledAt == null &&
            failureCode == null &&
            cancellable,
      HouseholdPrivacyRequestStatus.processing =>
        processingStartedAt != null &&
            completedAt == null &&
            failedAt == null &&
            cancelledAt == null &&
            failureCode == null &&
            !cancellable,
      HouseholdPrivacyRequestStatus.completed =>
        processingStartedAt != null &&
            completedAt != null &&
            failedAt == null &&
            cancelledAt == null &&
            failureCode == null &&
            !cancellable,
      HouseholdPrivacyRequestStatus.failed =>
        failedAt != null &&
            completedAt == null &&
            cancelledAt == null &&
            _validFailureCode(failureCode) &&
            !cancellable,
      HouseholdPrivacyRequestStatus.cancelled =>
        cancelledAt != null &&
            completedAt == null &&
            failedAt == null &&
            failureCode == null &&
            !cancellable,
    };
    if (!kindShape ||
        !statusShape ||
        version < 1 ||
        !requestedAt.isUtc ||
        !scheduledFor.isUtc ||
        scheduledFor.isBefore(requestedAt) ||
        !_boundedTimestamp(processingStartedAt, requestedAt) ||
        !_boundedTimestamp(completedAt, processingStartedAt) ||
        !_boundedTimestamp(failedAt, requestedAt) ||
        !_boundedTimestamp(cancelledAt, requestedAt)) {
      return null;
    }
    return HouseholdPrivacyRequest._(
      id: id,
      kind: kind,
      householdId: householdId,
      status: status,
      requestedAt: requestedAt,
      scheduledFor: scheduledFor,
      processingStartedAt: processingStartedAt,
      completedAt: completedAt,
      failedAt: failedAt,
      cancelledAt: cancelledAt,
      failureCode: failureCode,
      cancellable: cancellable,
      version: version,
      activeSubscriptionAtRequest: activeSubscriptionAtRequest,
      artifact: artifact,
      deletion: deletion,
    );
  }
}

final class HouseholdPrivacyPreflight {
  const HouseholdPrivacyPreflight._({
    required this.household,
    required this.memberCount,
    required this.activeSubscription,
    required this.canExport,
    required this.canDelete,
    required this.conflictingRequestPending,
    required this.pendingRequest,
    required this.exportRequestsEnabled,
    required this.deletionRequestsEnabled,
    required this.downloadsEnabled,
    required this.artifactRetention,
    required this.downloadGrantLifetime,
    required this.deletionCancellationWindow,
    required this.retentionBlocked,
    required this.retentionReviewAt,
    required this.evaluatedAt,
  });

  final HouseholdPrivacyHousehold household;
  final int memberCount;
  final bool activeSubscription;
  final bool canExport;
  final bool canDelete;
  final bool conflictingRequestPending;
  final HouseholdPrivacyRequest? pendingRequest;
  final bool exportRequestsEnabled;
  final bool deletionRequestsEnabled;
  final bool downloadsEnabled;
  final Duration artifactRetention;
  final Duration downloadGrantLifetime;
  final Duration deletionCancellationWindow;
  final bool retentionBlocked;
  final DateTime? retentionReviewAt;
  final DateTime evaluatedAt;

  static HouseholdPrivacyPreflight? tryCreate({
    required HouseholdPrivacyHousehold household,
    required int memberCount,
    required bool activeSubscription,
    required bool canExport,
    required bool canDelete,
    required bool conflictingRequestPending,
    required HouseholdPrivacyRequest? pendingRequest,
    required bool exportRequestsEnabled,
    required bool deletionRequestsEnabled,
    required bool downloadsEnabled,
    required Duration artifactRetention,
    required Duration downloadGrantLifetime,
    required Duration deletionCancellationWindow,
    required bool retentionBlocked,
    required DateTime? retentionReviewAt,
    required DateTime evaluatedAt,
  }) {
    final bool requestConflict =
        pendingRequest != null || conflictingRequestPending;
    if (memberCount < 1 ||
        pendingRequest != null && pendingRequest.householdId != household.id ||
        pendingRequest != null && !pendingRequest.status.isPending ||
        canExport != (exportRequestsEnabled && !requestConflict) ||
        canDelete != (deletionRequestsEnabled && !requestConflict) ||
        artifactRetention < const Duration(hours: 1) ||
        artifactRetention > const Duration(days: 7) ||
        downloadGrantLifetime < const Duration(minutes: 1) ||
        downloadGrantLifetime > const Duration(minutes: 15) ||
        deletionCancellationWindow < const Duration(hours: 1) ||
        deletionCancellationWindow > const Duration(days: 7) ||
        !evaluatedAt.isUtc ||
        !_optionalUtc(retentionReviewAt) ||
        !retentionBlocked && retentionReviewAt != null) {
      return null;
    }
    return HouseholdPrivacyPreflight._(
      household: household,
      memberCount: memberCount,
      activeSubscription: activeSubscription,
      canExport: canExport,
      canDelete: canDelete,
      conflictingRequestPending: conflictingRequestPending,
      pendingRequest: pendingRequest,
      exportRequestsEnabled: exportRequestsEnabled,
      deletionRequestsEnabled: deletionRequestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      deletionCancellationWindow: deletionCancellationWindow,
      retentionBlocked: retentionBlocked,
      retentionReviewAt: retentionReviewAt,
      evaluatedAt: evaluatedAt,
    );
  }

  HouseholdPrivacyPreflight withRequest(HouseholdPrivacyRequest request) {
    return HouseholdPrivacyPreflight._(
      household: household,
      memberCount: memberCount,
      activeSubscription: activeSubscription,
      canExport: false,
      canDelete: false,
      conflictingRequestPending: false,
      pendingRequest: request.status.isPending ? request : null,
      exportRequestsEnabled: exportRequestsEnabled,
      deletionRequestsEnabled: deletionRequestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      deletionCancellationWindow: deletionCancellationWindow,
      retentionBlocked: request.deletion == null
          ? retentionBlocked
          : request.deletion!.retentionBlocked,
      retentionReviewAt: request.deletion == null
          ? retentionReviewAt
          : request.deletion!.retentionReviewAt,
      evaluatedAt: evaluatedAt,
    )._normalizeAvailability();
  }

  HouseholdPrivacyPreflight _normalizeAvailability() {
    if (pendingRequest != null) {
      return this;
    }
    return HouseholdPrivacyPreflight._(
      household: household,
      memberCount: memberCount,
      activeSubscription: activeSubscription,
      canExport: exportRequestsEnabled && !conflictingRequestPending,
      canDelete: deletionRequestsEnabled && !conflictingRequestPending,
      conflictingRequestPending: conflictingRequestPending,
      pendingRequest: null,
      exportRequestsEnabled: exportRequestsEnabled,
      deletionRequestsEnabled: deletionRequestsEnabled,
      downloadsEnabled: downloadsEnabled,
      artifactRetention: artifactRetention,
      downloadGrantLifetime: downloadGrantLifetime,
      deletionCancellationWindow: deletionCancellationWindow,
      retentionBlocked: retentionBlocked,
      retentionReviewAt: retentionReviewAt,
      evaluatedAt: evaluatedAt,
    );
  }
}

final class HouseholdExportDownload {
  const HouseholdExportDownload._({
    required this.format,
    required this.expiresAt,
    required this.uri,
  });

  final HouseholdExportFormat format;
  final DateTime expiresAt;
  final Uri uri;

  static HouseholdExportDownload? tryCreate({
    required HouseholdExportFormat format,
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
    return HouseholdExportDownload._(
      format: format,
      expiresAt: expiresAt,
      uri: uri,
    );
  }
}

bool _validHouseholdName(String value) =>
    value.isNotEmpty &&
    value.length <= 80 &&
    !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(value);

bool _validExportSize(int? value) =>
    value == null || value >= 1 && value <= householdExportMaximumFileBytes;

bool _validFailureCode(String? value) =>
    value != null &&
    value.isNotEmpty &&
    value.length <= 120 &&
    !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(value);

bool _optionalUtc(DateTime? value) => value == null || value.isUtc;

bool _boundedTimestamp(DateTime? value, DateTime? lowerBound) =>
    value == null ||
    value.isUtc && lowerBound != null && !value.isBefore(lowerBound);
