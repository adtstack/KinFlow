import 'dart:async';

import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';

typedef HouseholdDeletedCallback = Future<void> Function();

final class HouseholdPrivacyController {
  HouseholdPrivacyController(
    this._repository,
    this._commandIdGenerator,
    this._recentAuthenticationService,
    this._downloadLauncher,
    this._householdId,
    this._onHouseholdDeleted,
  );

  final HouseholdPrivacyRepository _repository;
  final HouseholdCommandIdGenerator _commandIdGenerator;
  final RecentAuthenticationService _recentAuthenticationService;
  final DataExportDownloadLauncher _downloadLauncher;
  final HouseholdId? _householdId;
  final HouseholdDeletedCallback _onHouseholdDeleted;
  final StreamController<HouseholdPrivacyState> _states =
      StreamController<HouseholdPrivacyState>.broadcast(sync: true);

  HouseholdPrivacyState _state = const HouseholdPrivacyInitial();
  Future<void> _pending = Future<void>.value();
  HouseholdCommandId? _retryId;
  String? _retryFingerprint;
  bool _busy = false;
  bool _disposed = false;

  HouseholdPrivacyState get state => _state;

  Stream<HouseholdPrivacyState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) {
      return _pending;
    }
    final HouseholdId? householdId = _householdId;
    if (householdId == null) {
      _emit(
        const HouseholdPrivacyLoadFailed(
          HouseholdPrivacyFailure(
            HouseholdPrivacyFailureKind.noActiveHousehold,
          ),
        ),
      );
      return _pending;
    }
    _busy = true;
    final HouseholdPrivacyReady? fallback =
        preserveContent && _state is HouseholdPrivacyReady
        ? _state as HouseholdPrivacyReady
        : null;
    if (fallback == null) {
      _emit(const HouseholdPrivacyLoading());
    } else {
      _emit(
        HouseholdPrivacyReady(
          preflight: fallback.preflight,
          latestRequest: fallback.latestRequest,
          isRefreshing: true,
          lastOpenedFormat: fallback.lastOpenedFormat,
        ),
      );
    }
    _pending = _load(householdId, fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> requestExport() {
    return _runAction((HouseholdPrivacyReady ready) async {
      if (!ready.preflight.canExport) {
        _emitFailure(
          ready,
          ready.preflight.pendingRequest != null ||
                  ready.preflight.conflictingRequestPending
              ? HouseholdPrivacyFailureKind.alreadyPending
              : HouseholdPrivacyFailureKind.exportRequestsPaused,
        );
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final HouseholdPrivacyResult<HouseholdPrivacyRequest> result;
      try {
        result = await _repository.requestExport(
          householdId: ready.preflight.household.id,
          recentAuthenticationProof: proof,
          commandId: _commandId(
            'request-export|${ready.preflight.household.id.value}',
          ),
        );
      } on Object {
        _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
        return;
      }
      _handleRequestResult(ready, result);
    });
  }

  Future<void> requestDeletion({
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
  }) {
    return _runAction((HouseholdPrivacyReady ready) async {
      if (!ready.preflight.canDelete) {
        _emitFailure(
          ready,
          ready.preflight.pendingRequest != null ||
                  ready.preflight.conflictingRequestPending
              ? HouseholdPrivacyFailureKind.alreadyPending
              : HouseholdPrivacyFailureKind.deletionRequestsPaused,
        );
        return;
      }
      if (confirmationName != ready.preflight.household.name ||
          !acknowledgeMemberAccessLoss ||
          !acknowledgeSharedDataRedaction) {
        _emitFailure(
          ready,
          confirmationName != ready.preflight.household.name
              ? HouseholdPrivacyFailureKind.confirmationMismatch
              : HouseholdPrivacyFailureKind.invalidInput,
        );
        return;
      }
      if (ready.preflight.activeSubscription &&
          !acknowledgeSubscriptionNotCancelled) {
        _emitFailure(
          ready,
          HouseholdPrivacyFailureKind.subscriptionAcknowledgmentRequired,
        );
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'request-deletion|${ready.preflight.household.id.value}|'
          '${ready.preflight.household.version}|$confirmationName';
      final HouseholdPrivacyResult<HouseholdPrivacyRequest> result;
      try {
        result = await _repository.requestDeletion(
          householdId: ready.preflight.household.id,
          expectedHouseholdVersion: ready.preflight.household.version,
          confirmationName: confirmationName,
          acknowledgeMemberAccessLoss: true,
          acknowledgeSharedDataRedaction: true,
          acknowledgeSubscriptionNotCancelled:
              acknowledgeSubscriptionNotCancelled,
          recentAuthenticationProof: proof,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
        return;
      }
      _handleRequestResult(ready, result);
    });
  }

  Future<void> cancel() {
    return _runAction((HouseholdPrivacyReady ready) async {
      final HouseholdPrivacyRequest? request = ready.latestRequest;
      if (request == null || !request.cancellable) {
        _emitFailure(ready, HouseholdPrivacyFailureKind.requestNotMutable);
        return;
      }
      final String fingerprint =
          'cancel|${request.kind.wireValue}|${request.id.value}|'
          '${request.version}';
      final HouseholdPrivacyResult<HouseholdPrivacyRequest> result;
      try {
        result = await _repository.cancel(
          requestId: request.id,
          kind: request.kind,
          expectedVersion: request.version,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
        return;
      }
      _handleRequestResult(ready, result);
    });
  }

  Future<void> revokeExport() {
    return _runAction((HouseholdPrivacyReady ready) async {
      final HouseholdPrivacyRequest? request = ready.latestRequest;
      final HouseholdExportArtifact? artifact = request?.artifact;
      if (request == null ||
          request.kind != HouseholdPrivacyRequestKind.export ||
          request.status != HouseholdPrivacyRequestStatus.completed ||
          artifact == null ||
          artifact.revokedAt != null ||
          artifact.purgedAt != null) {
        _emitFailure(ready, HouseholdPrivacyFailureKind.artifactUnavailable);
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'revoke|${request.id.value}|${artifact.version}';
      final HouseholdPrivacyResult<HouseholdPrivacyRequest> result;
      try {
        result = await _repository.revokeExport(
          requestId: request.id,
          expectedArtifactVersion: artifact.version,
          recentAuthenticationProof: proof,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
        return;
      }
      _handleRequestResult(ready, result);
    });
  }

  Future<void> download(HouseholdExportFormat format) {
    return _runAction((HouseholdPrivacyReady ready) async {
      final HouseholdPrivacyRequest? request = ready.latestRequest;
      if (request?.artifact?.available != true ||
          !ready.preflight.downloadsEnabled) {
        _emitFailure(
          ready,
          ready.preflight.downloadsEnabled
              ? HouseholdPrivacyFailureKind.artifactUnavailable
              : HouseholdPrivacyFailureKind.downloadsPaused,
        );
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final HouseholdPrivacyResult<HouseholdExportDownload> result;
      try {
        result = await _repository.createDownload(
          requestId: request!.id,
          format: format,
          recentAuthenticationProof: proof,
        );
      } on Object {
        _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
        return;
      }
      switch (result) {
        case HouseholdPrivacySucceeded<HouseholdExportDownload>(:final value):
          final bool launched;
          try {
            launched = await _downloadLauncher.launch(value.uri);
          } on Object {
            _emitFailure(ready, HouseholdPrivacyFailureKind.launchFailed);
            return;
          }
          if (!launched) {
            _emitFailure(ready, HouseholdPrivacyFailureKind.launchFailed);
            return;
          }
          _emit(
            HouseholdPrivacyReady(
              preflight: ready.preflight,
              latestRequest: ready.latestRequest,
              lastOpenedFormat: value.format,
            ),
          );
        case HouseholdPrivacyFailed<HouseholdExportDownload>(:final failure):
          _emitReadyFailure(ready, failure);
      }
    });
  }

  Future<void> _load(
    HouseholdId householdId,
    HouseholdPrivacyReady? fallback,
  ) async {
    HouseholdPrivacyRequest? refreshedRequest;
    final HouseholdPrivacyRequest? previous = fallback?.latestRequest;
    if (previous != null) {
      final HouseholdPrivacyResult<HouseholdPrivacyRequest> statusResult;
      try {
        statusResult = await _repository.loadStatus(previous.id);
      } on Object {
        _loadFailure(fallback, HouseholdPrivacyFailureKind.internal);
        return;
      }
      switch (statusResult) {
        case HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(:final value):
          refreshedRequest = value;
          if (_completedDeletion(value)) {
            _clearRetry();
            _emit(
              HouseholdPrivacyReady(
                preflight: fallback!.preflight.withRequest(value),
                latestRequest: value,
                lastOpenedFormat: fallback.lastOpenedFormat,
              ),
            );
            await _notifyHouseholdDeleted();
            return;
          }
        case HouseholdPrivacyFailed<HouseholdPrivacyRequest>(:final failure):
          _loadFailure(fallback, failure.kind);
          return;
      }
    }

    final HouseholdPrivacyResult<HouseholdPrivacyPreflight> preflightResult;
    try {
      preflightResult = await _repository.loadPreflight(householdId);
    } on Object {
      _loadFailure(fallback, HouseholdPrivacyFailureKind.internal);
      return;
    }
    switch (preflightResult) {
      case HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(:final value):
        final HouseholdPrivacyRequest? latest =
            value.pendingRequest ?? refreshedRequest;
        _clearRetry();
        _emit(
          HouseholdPrivacyReady(
            preflight: latest == null ? value : value.withRequest(latest),
            latestRequest: latest,
            lastOpenedFormat: fallback?.lastOpenedFormat,
          ),
        );
      case HouseholdPrivacyFailed<HouseholdPrivacyPreflight>(:final failure):
        _loadFailure(fallback, failure.kind);
    }
  }

  void _handleRequestResult(
    HouseholdPrivacyReady ready,
    HouseholdPrivacyResult<HouseholdPrivacyRequest> result,
  ) {
    switch (result) {
      case HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(:final value):
        _clearRetry();
        _emit(
          HouseholdPrivacyReady(
            preflight: ready.preflight.withRequest(value),
            latestRequest: value,
            lastOpenedFormat: ready.lastOpenedFormat,
          ),
        );
        if (_completedDeletion(value)) {
          unawaited(_notifyHouseholdDeleted());
        }
      case HouseholdPrivacyFailed<HouseholdPrivacyRequest>(:final failure):
        _emitReadyFailure(ready, failure);
    }
  }

  bool _completedDeletion(HouseholdPrivacyRequest request) =>
      request.kind == HouseholdPrivacyRequestKind.deletion &&
      request.status == HouseholdPrivacyRequestStatus.completed;

  Future<void> _notifyHouseholdDeleted() async {
    try {
      await _onHouseholdDeleted();
    } on Object {
      // Server state is authoritative. A later auth refresh will resolve it.
    }
  }

  Future<void> _runAction(
    Future<void> Function(HouseholdPrivacyReady ready) action,
  ) {
    if (_busy || _disposed || _state is! HouseholdPrivacyReady) {
      return _pending;
    }
    final HouseholdPrivacyReady ready = _state as HouseholdPrivacyReady;
    _busy = true;
    _emit(
      HouseholdPrivacyReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        isSubmitting: true,
        lastOpenedFormat: ready.lastOpenedFormat,
      ),
    );
    _pending = action(ready).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<RecentAuthenticationProof?> _recentProof(
    HouseholdPrivacyReady ready,
  ) async {
    final RecentAuthenticationResult result;
    try {
      result = await _recentAuthenticationService.authenticate();
    } on Object {
      _emitFailure(ready, HouseholdPrivacyFailureKind.internal);
      return null;
    }
    return switch (result) {
      RecentAuthenticationCompleted(:final proof) => proof,
      RecentAuthenticationFailed(:final kind) => _recentFailure(ready, kind),
    };
  }

  RecentAuthenticationProof? _recentFailure(
    HouseholdPrivacyReady ready,
    RecentAuthenticationFailureKind kind,
  ) {
    _emitFailure(ready, switch (kind) {
      RecentAuthenticationFailureKind.cancelled =>
        HouseholdPrivacyFailureKind.recentAuthenticationCancelled,
      RecentAuthenticationFailureKind.accountChanged =>
        HouseholdPrivacyFailureKind.accountChanged,
      RecentAuthenticationFailureKind.unauthenticated ||
      RecentAuthenticationFailureKind.invalidProof =>
        HouseholdPrivacyFailureKind.recentAuthenticationRequired,
      RecentAuthenticationFailureKind.providerUnavailable ||
      RecentAuthenticationFailureKind.temporarilyUnavailable =>
        HouseholdPrivacyFailureKind.temporarilyUnavailable,
      RecentAuthenticationFailureKind.internal =>
        HouseholdPrivacyFailureKind.internal,
    });
    return null;
  }

  HouseholdCommandId _commandId(String fingerprint) {
    if (_retryFingerprint != fingerprint || _retryId == null) {
      _retryFingerprint = fingerprint;
      _retryId = _commandIdGenerator.generate();
    }
    return _retryId!;
  }

  void _clearRetry() {
    _retryFingerprint = null;
    _retryId = null;
  }

  void _loadFailure(
    HouseholdPrivacyReady? fallback,
    HouseholdPrivacyFailureKind kind,
  ) {
    final HouseholdPrivacyFailure failure = HouseholdPrivacyFailure(kind);
    if (fallback == null) {
      _emit(HouseholdPrivacyLoadFailed(failure));
      return;
    }
    _emit(
      HouseholdPrivacyReady(
        preflight: fallback.preflight,
        latestRequest: fallback.latestRequest,
        failure: failure,
        lastOpenedFormat: fallback.lastOpenedFormat,
      ),
    );
  }

  void _emitReadyFailure(
    HouseholdPrivacyReady ready,
    HouseholdPrivacyFailure failure,
  ) {
    _emit(
      HouseholdPrivacyReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        failure: failure,
        lastOpenedFormat: ready.lastOpenedFormat,
      ),
    );
  }

  void _emitFailure(
    HouseholdPrivacyReady ready,
    HouseholdPrivacyFailureKind kind,
  ) {
    _emitReadyFailure(ready, HouseholdPrivacyFailure(kind));
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(HouseholdPrivacyState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
