import 'dart:async';

import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

/// Coordinates invalidation-only Chore Realtime with authoritative refetches.
final class ChoreSyncSession {
  ChoreSyncSession(this._repository, this._refresh, this._onStatus);

  final ChoreSyncRepository? _repository;
  final Future<void> Function() _refresh;
  final void Function(ChoreSyncConnectionStatus status) _onStatus;

  StreamSubscription<ChoreSyncSignal>? _subscription;
  HouseholdId? _householdId;
  int? _lastGeneration;
  Future<void> _refreshDrain = Future<void>.value();
  var _subscriptionEpoch = 0;
  var _refreshRunning = false;
  var _refreshRequested = false;
  var _disposed = false;

  Future<void> start(HouseholdId householdId) async {
    if (_disposed) {
      return;
    }
    if (_householdId != householdId) {
      _lastGeneration = null;
    }
    _householdId = householdId;
    if (_repository == null) {
      _onStatus(ChoreSyncConnectionStatus.disabled);
      return;
    }
    await _replaceSubscription();
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _householdId = null;
    _lastGeneration = null;
    _refreshRequested = false;
    final StreamSubscription<ChoreSyncSignal>? previous = _subscription;
    _subscription = null;
    _subscriptionEpoch += 1;
    await previous?.cancel();
    if (!_disposed) {
      _onStatus(ChoreSyncConnectionStatus.disabled);
    }
  }

  Future<void> resume() async {
    if (_disposed || _householdId == null) {
      return;
    }
    requestRefresh();
    if (_repository != null) {
      await _replaceSubscription();
    }
    await _refreshDrain;
  }

  Future<void> reconnect() => resume();

  void requestRefresh() {
    if (_disposed || _householdId == null) {
      return;
    }
    _refreshRequested = true;
    if (_refreshRunning) {
      return;
    }
    _refreshRunning = true;
    _refreshDrain = _drainRefreshes();
  }

  Future<void> _replaceSubscription() async {
    final StreamSubscription<ChoreSyncSignal>? previous = _subscription;
    _subscription = null;
    final int epoch = ++_subscriptionEpoch;
    final HouseholdId? householdId = _householdId;
    if (_disposed || householdId == null || _repository == null) {
      await previous?.cancel();
      return;
    }
    _onStatus(ChoreSyncConnectionStatus.connecting);
    try {
      await previous?.cancel();
    } on Object {
      if (!_disposed && epoch == _subscriptionEpoch) {
        _onStatus(ChoreSyncConnectionStatus.disconnected);
      }
      return;
    }
    if (_disposed ||
        epoch != _subscriptionEpoch ||
        _householdId != householdId) {
      return;
    }
    try {
      _subscription = _repository
          .watch(householdId)
          .listen(
            (ChoreSyncSignal signal) {
              if (epoch == _subscriptionEpoch) {
                _handleSignal(signal);
              }
            },
            onError: (Object _, StackTrace _) {
              if (!_disposed && epoch == _subscriptionEpoch) {
                _onStatus(ChoreSyncConnectionStatus.disconnected);
              }
            },
            onDone: () {
              if (!_disposed && epoch == _subscriptionEpoch) {
                _onStatus(ChoreSyncConnectionStatus.disconnected);
              }
            },
          );
    } on Object {
      if (!_disposed && epoch == _subscriptionEpoch) {
        _onStatus(ChoreSyncConnectionStatus.disconnected);
      }
    }
  }

  void _handleSignal(ChoreSyncSignal signal) {
    if (_disposed || _householdId == null) {
      return;
    }
    switch (signal) {
      case ChoreSyncConnecting():
        _onStatus(ChoreSyncConnectionStatus.connecting);
      case ChoreSyncConnected():
        _onStatus(ChoreSyncConnectionStatus.live);
        // Closes the initial-query/subscription and reconnect gaps.
        requestRefresh();
      case ChoreSyncChanged(:final generation):
        final int? previous = _lastGeneration;
        if (previous != null && generation <= previous) {
          return;
        }
        _lastGeneration = generation;
        requestRefresh();
      case ChoreSyncDisconnected():
        _onStatus(ChoreSyncConnectionStatus.disconnected);
    }
  }

  Future<void> _drainRefreshes() async {
    try {
      while (_refreshRequested && !_disposed && _householdId != null) {
        _refreshRequested = false;
        try {
          await _refresh();
        } on Object {
          // Controllers translate refresh errors into typed retained-content
          // states. A transport exception must not terminate the signal loop.
        }
      }
    } finally {
      _refreshRunning = false;
      if (_refreshRequested && !_disposed && _householdId != null) {
        requestRefresh();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _householdId = null;
    _refreshRequested = false;
    _subscriptionEpoch += 1;
    await _subscription?.cancel();
    _subscription = null;
    await _refreshDrain;
  }
}
