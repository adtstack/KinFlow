import 'dart:async';

import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

final class AccountDeletionController {
  AccountDeletionController(
    this._repository,
    this._commandIdGenerator,
    this._recentAuthenticationService,
  );

  final AccountDeletionRepository _repository;
  final AccountDeletionCommandIdGenerator _commandIdGenerator;
  final RecentAuthenticationService _recentAuthenticationService;
  final StreamController<AccountDeletionState> _states =
      StreamController<AccountDeletionState>.broadcast(sync: true);

  AccountDeletionState _state = const AccountDeletionInitial();
  Future<void> _pending = Future<void>.value();
  AccountDeletionCommandId? _retryId;
  String? _retryFingerprint;
  bool _busy = false;
  bool _disposed = false;

  AccountDeletionState get state => _state;

  Stream<AccountDeletionState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    final AccountDeletionReady? fallback =
        preserveContent && _state is AccountDeletionReady
        ? _state as AccountDeletionReady
        : null;
    if (fallback == null) {
      _emit(const AccountDeletionLoading());
    } else {
      _emit(
        AccountDeletionReady(
          preflight: fallback.preflight,
          latestRequest: fallback.latestRequest,
          isRefreshing: true,
        ),
      );
    }
    _pending = _load(fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> requestDeletion({required bool subscriptionAcknowledged}) {
    return _runAction((AccountDeletionReady ready) async {
      if (!ready.preflight.canRequest) {
        _emitFailure(
          ready,
          ready.preflight.requiresOwnerTransfer
              ? AccountDeletionFailureKind.ownerTransferRequired
              : ready.preflight.hasPendingRequest
              ? AccountDeletionFailureKind.alreadyPending
              : AccountDeletionFailureKind.requestsPaused,
        );
        return;
      }
      if (ready.preflight.hasActiveSubscription && !subscriptionAcknowledged) {
        _emitFailure(
          ready,
          AccountDeletionFailureKind.subscriptionAcknowledgementRequired,
        );
        return;
      }

      final RecentAuthenticationProof? proof = await _recentProof(ready);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'request|subscriptionAcknowledged=$subscriptionAcknowledged';
      final AccountDeletionResult<AccountDeletionRequest> result;
      try {
        result = await _repository.requestDeletion(
          subscriptionAcknowledged: subscriptionAcknowledged,
          recentAuthenticationProof: proof,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, AccountDeletionFailureKind.internal);
        return;
      }
      switch (result) {
        case AccountDeletionSucceeded<AccountDeletionRequest>(:final value):
          _clearRetry();
          _emit(
            AccountDeletionReady(
              preflight: ready.preflight.withPending(value),
              latestRequest: value,
              logoutRequested: true,
            ),
          );
        case AccountDeletionFailed<AccountDeletionRequest>(:final failure):
          _emit(
            AccountDeletionReady(
              preflight: ready.preflight,
              latestRequest: ready.latestRequest,
              failure: failure,
            ),
          );
      }
    });
  }

  Future<void> cancel() {
    return _runAction((AccountDeletionReady ready) async {
      final AccountDeletionRequest? request = ready.latestRequest;
      if (request == null || !request.cancellable) {
        _emitFailure(ready, AccountDeletionFailureKind.notCancellable);
        return;
      }
      final String fingerprint =
          'cancel|${request.id.value}|${request.version}';
      final AccountDeletionResult<AccountDeletionRequest> result;
      try {
        result = await _repository.cancel(
          requestId: request.id,
          expectedVersion: request.version,
          commandId: _commandId(fingerprint),
        );
      } on Object {
        _emitFailure(ready, AccountDeletionFailureKind.internal);
        return;
      }
      switch (result) {
        case AccountDeletionSucceeded<AccountDeletionRequest>(:final value):
          _clearRetry();
          _emit(
            AccountDeletionReady(
              preflight: ready.preflight.withoutPending(),
              latestRequest: value,
            ),
          );
        case AccountDeletionFailed<AccountDeletionRequest>(:final failure):
          _emit(
            AccountDeletionReady(
              preflight: ready.preflight,
              latestRequest: ready.latestRequest,
              failure: failure,
            ),
          );
      }
    });
  }

  void acknowledgeLogoutRequest() {
    if (_state case final AccountDeletionReady ready
        when ready.logoutRequested) {
      _emit(
        AccountDeletionReady(
          preflight: ready.preflight,
          latestRequest: ready.latestRequest,
          failure: ready.failure,
        ),
      );
    }
  }

  Future<void> _runAction(
    Future<void> Function(AccountDeletionReady ready) action,
  ) {
    if (_busy || _disposed || _state is! AccountDeletionReady) {
      return _pending;
    }
    final AccountDeletionReady ready = _state as AccountDeletionReady;
    _busy = true;
    _emit(
      AccountDeletionReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        isSubmitting: true,
      ),
    );
    _pending = action(ready).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(AccountDeletionReady? fallback) async {
    final AccountDeletionResult<AccountDeletionPreflight> preflightResult;
    try {
      preflightResult = await _repository.loadPreflight();
    } on Object {
      _loadFailure(fallback, AccountDeletionFailureKind.internal);
      return;
    }
    if (preflightResult case AccountDeletionFailed<AccountDeletionPreflight>(
      :final failure,
    )) {
      _loadFailure(fallback, failure.kind);
      return;
    }
    final AccountDeletionPreflight preflight =
        (preflightResult as AccountDeletionSucceeded<AccountDeletionPreflight>)
            .value;

    final AccountDeletionResult<AccountDeletionRequest?> requestResult;
    try {
      requestResult = await _repository.loadLatest(
        requestId: preflight.pendingRequestId,
      );
    } on Object {
      _loadFailure(fallback, AccountDeletionFailureKind.internal);
      return;
    }
    if (requestResult case AccountDeletionFailed<AccountDeletionRequest?>(
      :final failure,
    )) {
      _loadFailure(fallback, failure.kind);
      return;
    }
    final AccountDeletionRequest? latest =
        (requestResult as AccountDeletionSucceeded<AccountDeletionRequest?>)
            .value;
    if (preflight.pendingRequestId != null &&
        (latest == null || latest.id != preflight.pendingRequestId)) {
      _loadFailure(fallback, AccountDeletionFailureKind.invalidPayload);
      return;
    }
    final AccountDeletionPreflight normalized = latest?.status.isPending == true
        ? preflight.withPending(latest!)
        : preflight.withoutPending();
    _clearRetry();
    _emit(AccountDeletionReady(preflight: normalized, latestRequest: latest));
  }

  Future<RecentAuthenticationProof?> _recentProof(
    AccountDeletionReady ready,
  ) async {
    final RecentAuthenticationResult result;
    try {
      result = await _recentAuthenticationService.authenticate();
    } on Object {
      _emitFailure(ready, AccountDeletionFailureKind.internal);
      return null;
    }
    return switch (result) {
      RecentAuthenticationCompleted(:final proof) => proof,
      RecentAuthenticationFailed(:final kind) => _recentFailure(ready, kind),
    };
  }

  RecentAuthenticationProof? _recentFailure(
    AccountDeletionReady ready,
    RecentAuthenticationFailureKind kind,
  ) {
    _emitFailure(ready, switch (kind) {
      RecentAuthenticationFailureKind.cancelled =>
        AccountDeletionFailureKind.recentAuthenticationCancelled,
      RecentAuthenticationFailureKind.accountChanged =>
        AccountDeletionFailureKind.accountChanged,
      RecentAuthenticationFailureKind.unauthenticated ||
      RecentAuthenticationFailureKind.invalidProof =>
        AccountDeletionFailureKind.recentAuthenticationRequired,
      RecentAuthenticationFailureKind.providerUnavailable ||
      RecentAuthenticationFailureKind.temporarilyUnavailable =>
        AccountDeletionFailureKind.temporarilyUnavailable,
      RecentAuthenticationFailureKind.internal =>
        AccountDeletionFailureKind.internal,
    });
    return null;
  }

  AccountDeletionCommandId _commandId(String fingerprint) {
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
    AccountDeletionReady? fallback,
    AccountDeletionFailureKind kind,
  ) {
    final AccountDeletionFailure failure = AccountDeletionFailure(kind);
    if (fallback == null) {
      _emit(AccountDeletionLoadFailed(failure));
      return;
    }
    _emit(
      AccountDeletionReady(
        preflight: fallback.preflight,
        latestRequest: fallback.latestRequest,
        failure: failure,
      ),
    );
  }

  void _emitFailure(
    AccountDeletionReady ready,
    AccountDeletionFailureKind kind,
  ) {
    _emit(
      AccountDeletionReady(
        preflight: ready.preflight,
        latestRequest: ready.latestRequest,
        failure: AccountDeletionFailure(kind),
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(AccountDeletionState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
