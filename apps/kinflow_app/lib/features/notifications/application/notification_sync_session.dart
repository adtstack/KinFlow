import 'dart:async';

import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';

/// Coordinates invalidation-only Notification Realtime with authoritative
/// Notification Center snapshot refetches.
final class NotificationSyncSession {
  NotificationSyncSession(this._repository, this._refresh, this._onStatus);

  final NotificationSyncRepository? _repository;
  final Future<void> Function() _refresh;
  final void Function(NotificationSyncConnectionStatus status) _onStatus;

  StreamSubscription<NotificationSyncSignal>? _subscription;
  AuthUserId? _authUserId;
  int? _lastGeneration;
  Future<void> _refreshDrain = Future<void>.value();
  var _subscriptionEpoch = 0;
  var _refreshRunning = false;
  var _refreshRequested = false;
  var _disposed = false;

  Future<void> start(AuthUserId authUserId) async {
    if (_disposed) {
      return;
    }
    if (_authUserId != authUserId) {
      _lastGeneration = null;
    }
    _authUserId = authUserId;
    if (_repository == null) {
      _onStatus(NotificationSyncConnectionStatus.disabled);
      return;
    }
    await _replaceSubscription();
  }

  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _authUserId = null;
    _lastGeneration = null;
    _refreshRequested = false;
    final StreamSubscription<NotificationSyncSignal>? previous = _subscription;
    _subscription = null;
    _subscriptionEpoch += 1;
    await previous?.cancel();
    if (!_disposed) {
      _onStatus(NotificationSyncConnectionStatus.disabled);
    }
  }

  Future<void> resume() async {
    if (_disposed || _authUserId == null) {
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
    if (_disposed || _authUserId == null) {
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
    final StreamSubscription<NotificationSyncSignal>? previous = _subscription;
    _subscription = null;
    final int epoch = ++_subscriptionEpoch;
    final AuthUserId? authUserId = _authUserId;
    if (_disposed || authUserId == null || _repository == null) {
      await previous?.cancel();
      return;
    }
    _onStatus(NotificationSyncConnectionStatus.connecting);
    try {
      await previous?.cancel();
    } on Object {
      if (!_disposed && epoch == _subscriptionEpoch) {
        _onStatus(NotificationSyncConnectionStatus.disconnected);
      }
      return;
    }
    if (_disposed || epoch != _subscriptionEpoch || _authUserId != authUserId) {
      return;
    }
    try {
      _subscription = _repository
          .watch(authUserId)
          .listen(
            (NotificationSyncSignal signal) {
              if (epoch == _subscriptionEpoch) {
                _handleSignal(signal);
              }
            },
            onError: (Object _, StackTrace _) {
              if (!_disposed && epoch == _subscriptionEpoch) {
                _onStatus(NotificationSyncConnectionStatus.disconnected);
              }
            },
            onDone: () {
              if (!_disposed && epoch == _subscriptionEpoch) {
                _onStatus(NotificationSyncConnectionStatus.disconnected);
              }
            },
          );
    } on Object {
      if (!_disposed && epoch == _subscriptionEpoch) {
        _onStatus(NotificationSyncConnectionStatus.disconnected);
      }
    }
  }

  void _handleSignal(NotificationSyncSignal signal) {
    if (_disposed || _authUserId == null) {
      return;
    }
    switch (signal) {
      case NotificationSyncConnecting():
        _onStatus(NotificationSyncConnectionStatus.connecting);
      case NotificationSyncConnected():
        _onStatus(NotificationSyncConnectionStatus.live);
        // Closes the initial-query/subscription and reconnect gaps.
        requestRefresh();
      case NotificationSyncChanged(:final generation):
        final int? previous = _lastGeneration;
        if (previous != null && generation <= previous) {
          return;
        }
        _lastGeneration = generation;
        requestRefresh();
      case NotificationSyncDisconnected():
        _onStatus(NotificationSyncConnectionStatus.disconnected);
    }
  }

  Future<void> _drainRefreshes() async {
    try {
      while (_refreshRequested && !_disposed && _authUserId != null) {
        _refreshRequested = false;
        try {
          await _refresh();
        } on Object {
          // The controller retains content or purges it from typed failures.
          // A transport exception must not terminate the signal loop.
        }
      }
    } finally {
      _refreshRunning = false;
      if (_refreshRequested && !_disposed && _authUserId != null) {
        requestRefresh();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _authUserId = null;
    _refreshRequested = false;
    _subscriptionEpoch += 1;
    await _subscription?.cancel();
    _subscription = null;
    await _refreshDrain;
  }
}
