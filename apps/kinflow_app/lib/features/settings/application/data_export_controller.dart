import 'dart:async';

import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/application/data_export_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

final class DataExportController {
  DataExportController(
    this._repository,
    this._commandIdGenerator,
    this._recentAuthenticationService,
    this._downloadLauncher,
  );

  final DataExportRepository _repository;
  final DataExportCommandIdGenerator _commandIdGenerator;
  final RecentAuthenticationService _recentAuthenticationService;
  final DataExportDownloadLauncher _downloadLauncher;
  final StreamController<DataExportState> _states =
      StreamController<DataExportState>.broadcast(sync: true);

  DataExportState _state = const DataExportInitial();
  Future<void> _pending = Future<void>.value();
  DataExportCommandId? _retryId;
  String? _retryFingerprint;
  bool _busy = false;
  bool _disposed = false;

  DataExportState get state => _state;

  Stream<DataExportState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    final DataExportReady? fallback =
        preserveContent && _state is DataExportReady
        ? _state as DataExportReady
        : null;
    if (fallback == null) {
      _emit(const DataExportLoading());
    } else {
      _emit(
        DataExportReady(
          preflight: fallback.preflight,
          latestRequest: fallback.latestRequest,
          isRefreshing: true,
          lastOpenedFormat: fallback.lastOpenedFormat,
        ),
      );
    }
    _pending = _load(fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> requestExport() {
    return _runAction((DataExportReady ready) async {
      if (!ready.preflight.canRequest) {
        _emitFailure(
          ready,
          ready.preflight.hasPendingRequest ||
                  ready.preflight.conflictingRequestPending
              ? DataExportFailureKind.alreadyPending
              : DataExportFailureKind.requestsPaused,
        );
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final DataExportResult<DataExportRequest> result;
      try {
        result = await _repository.requestExport(
          recentAuthenticationProof: proof,
          commandId: _commandId('request|personal-v1'),
        );
      } on Object {
        _emitFailure(ready, DataExportFailureKind.internal);
        return;
      }
      switch (result) {
        case DataExportSucceeded<DataExportRequest>(:final value):
          _clearRetry();
          _emit(
            DataExportReady(
              preflight: ready.preflight.withPending(value),
              latestRequest: value,
              lastOpenedFormat: ready.lastOpenedFormat,
            ),
          );
        case DataExportFailed<DataExportRequest>(:final failure):
          _emitReadyFailure(ready, failure);
      }
    });
  }

  Future<void> cancel() {
    return _runAction((DataExportReady ready) async {
      final DataExportRequest? request = ready.latestRequest;
      if (request == null || !request.cancellable) {
        _emitFailure(ready, DataExportFailureKind.notCancellable);
        return;
      }
      final String fingerprint =
          'cancel|${request.id.value}|${request.version}';
      final DataExportResult<DataExportRequest> result;
      try {
        result = await _repository.cancel(
          requestId: request.id,
          expectedVersion: request.version,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, DataExportFailureKind.internal);
        return;
      }
      switch (result) {
        case DataExportSucceeded<DataExportRequest>(:final value):
          _clearRetry();
          _emit(
            DataExportReady(
              preflight: ready.preflight.withoutPending(),
              latestRequest: value,
              lastOpenedFormat: ready.lastOpenedFormat,
            ),
          );
        case DataExportFailed<DataExportRequest>(:final failure):
          _emitReadyFailure(ready, failure);
      }
    });
  }

  Future<void> revoke() {
    return _runAction((DataExportReady ready) async {
      final DataExportRequest? request = ready.latestRequest;
      if (request == null ||
          request.status != DataExportRequestStatus.completed ||
          request.artifact.revokedAt != null ||
          request.artifact.purgedAt != null) {
        _emitFailure(ready, DataExportFailureKind.artifactUnavailable);
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'revoke|${request.id.value}|${request.artifact.version}';
      final DataExportResult<DataExportRequest> result;
      try {
        result = await _repository.revoke(
          requestId: request.id,
          expectedArtifactVersion: request.artifact.version,
          recentAuthenticationProof: proof,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, DataExportFailureKind.internal);
        return;
      }
      switch (result) {
        case DataExportSucceeded<DataExportRequest>(:final value):
          _clearRetry();
          _emit(
            DataExportReady(
              preflight: ready.preflight,
              latestRequest: value,
              lastOpenedFormat: ready.lastOpenedFormat,
            ),
          );
        case DataExportFailed<DataExportRequest>(:final failure):
          _emitReadyFailure(ready, failure);
      }
    });
  }

  Future<void> download(DataExportFormat format) {
    return _runAction((DataExportReady ready) async {
      final DataExportRequest? request = ready.latestRequest;
      if (request == null ||
          !request.artifact.available ||
          !ready.preflight.downloadsEnabled) {
        _emitFailure(
          ready,
          ready.preflight.downloadsEnabled
              ? DataExportFailureKind.artifactUnavailable
              : DataExportFailureKind.downloadsPaused,
        );
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final DataExportResult<DataExportDownload> result;
      try {
        result = await _repository.createDownload(
          requestId: request.id,
          format: format,
          recentAuthenticationProof: proof,
        );
      } on Object {
        _emitFailure(ready, DataExportFailureKind.internal);
        return;
      }
      switch (result) {
        case DataExportSucceeded<DataExportDownload>(:final value):
          final bool launched;
          try {
            launched = await _downloadLauncher.launch(value.uri);
          } on Object {
            _emitFailure(ready, DataExportFailureKind.launchFailed);
            return;
          }
          if (!launched) {
            _emitFailure(ready, DataExportFailureKind.launchFailed);
            return;
          }
          _emit(
            DataExportReady(
              preflight: ready.preflight,
              latestRequest: ready.latestRequest,
              lastOpenedFormat: value.format,
            ),
          );
        case DataExportFailed<DataExportDownload>(:final failure):
          _emitReadyFailure(ready, failure);
      }
    });
  }

  Future<void> _runAction(Future<void> Function(DataExportReady ready) action) {
    if (_busy || _disposed || _state is! DataExportReady) {
      return _pending;
    }
    final DataExportReady ready = _state as DataExportReady;
    _busy = true;
    _emit(
      DataExportReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        isSubmitting: true,
        lastOpenedFormat: ready.lastOpenedFormat,
      ),
    );
    _pending = action(ready).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(DataExportReady? fallback) async {
    final DataExportResult<DataExportPreflight> preflightResult;
    try {
      preflightResult = await _repository.loadPreflight();
    } on Object {
      _loadFailure(fallback, DataExportFailureKind.internal);
      return;
    }
    if (preflightResult case DataExportFailed<DataExportPreflight>(
      :final failure,
    )) {
      _loadFailure(fallback, failure.kind);
      return;
    }
    final DataExportPreflight preflight =
        (preflightResult as DataExportSucceeded<DataExportPreflight>).value;
    final DataExportResult<DataExportRequest?> requestResult;
    try {
      requestResult = await _repository.loadLatest(
        requestId: preflight.pendingRequestId,
      );
    } on Object {
      _loadFailure(fallback, DataExportFailureKind.internal);
      return;
    }
    if (requestResult case DataExportFailed<DataExportRequest?>(
      :final failure,
    )) {
      _loadFailure(fallback, failure.kind);
      return;
    }
    final DataExportRequest? latest =
        (requestResult as DataExportSucceeded<DataExportRequest?>).value;
    final DataExportPreflight normalized = latest?.status.isPending == true
        ? preflight.withPending(latest!)
        : preflight.withoutPending();
    _clearRetry();
    _emit(
      DataExportReady(
        preflight: normalized,
        latestRequest: latest,
        lastOpenedFormat: fallback?.lastOpenedFormat,
      ),
    );
  }

  Future<RecentAuthenticationProof?> _recentProof(DataExportReady ready) async {
    final RecentAuthenticationResult result;
    try {
      result = await _recentAuthenticationService.authenticate();
    } on Object {
      _emitFailure(ready, DataExportFailureKind.internal);
      return null;
    }
    return switch (result) {
      RecentAuthenticationCompleted(:final proof) => proof,
      RecentAuthenticationFailed(:final kind) => _recentFailure(ready, kind),
    };
  }

  RecentAuthenticationProof? _recentFailure(
    DataExportReady ready,
    RecentAuthenticationFailureKind kind,
  ) {
    _emitFailure(ready, switch (kind) {
      RecentAuthenticationFailureKind.cancelled =>
        DataExportFailureKind.recentAuthenticationCancelled,
      RecentAuthenticationFailureKind.accountChanged =>
        DataExportFailureKind.accountChanged,
      RecentAuthenticationFailureKind.unauthenticated ||
      RecentAuthenticationFailureKind.invalidProof =>
        DataExportFailureKind.recentAuthenticationRequired,
      RecentAuthenticationFailureKind.providerUnavailable ||
      RecentAuthenticationFailureKind.temporarilyUnavailable =>
        DataExportFailureKind.temporarilyUnavailable,
      RecentAuthenticationFailureKind.internal =>
        DataExportFailureKind.internal,
    });
    return null;
  }

  DataExportCommandId _commandId(String fingerprint) {
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

  void _loadFailure(DataExportReady? fallback, DataExportFailureKind kind) {
    final DataExportFailure failure = DataExportFailure(kind);
    if (fallback == null) {
      _emit(DataExportLoadFailed(failure));
      return;
    }
    _emit(
      DataExportReady(
        preflight: fallback.preflight,
        latestRequest: fallback.latestRequest,
        failure: failure,
        lastOpenedFormat: fallback.lastOpenedFormat,
      ),
    );
  }

  void _emitReadyFailure(DataExportReady ready, DataExportFailure failure) {
    _emit(
      DataExportReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        failure: failure,
        lastOpenedFormat: ready.lastOpenedFormat,
      ),
    );
  }

  void _emitFailure(DataExportReady ready, DataExportFailureKind kind) {
    _emitReadyFailure(ready, DataExportFailure(kind));
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(DataExportState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
