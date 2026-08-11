import 'dart:async';

import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

/// Coordinates invalidation-only Realtime with authoritative full refetches.
final class CalendarSyncSession {
  CalendarSyncSession(this._repository, this._refresh, this._onStatus);

  final CalendarSyncRepository? _repository;
  final Future<void> Function() _refresh;
  final void Function(CalendarSyncConnectionStatus status) _onStatus;

  StreamSubscription<CalendarSyncSignal>? _subscription;
  HouseholdId? _householdId;
  int? _lastGeneration;
  Future<void> _refreshDrain = Future<void>.value();
  var _refreshRunning = false;
  var _refreshRequested = false;
  var _disposed = false;

  Future<void> start(HouseholdId householdId) async {
    if (_disposed) {
      return;
    }
    if (_repository == null) {
      _householdId = householdId;
      _onStatus(CalendarSyncConnectionStatus.disabled);
      return;
    }
    if (_householdId != householdId) {
      _lastGeneration = null;
    }
    _householdId = householdId;
    await _replaceSubscription();
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
    if (_disposed) {
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
    await _subscription?.cancel();
    _subscription = null;
    if (_disposed || _householdId == null || _repository == null) {
      return;
    }
    _onStatus(CalendarSyncConnectionStatus.connecting);
    try {
      _subscription = _repository
          .watch(_householdId!)
          .listen(
            _handleSignal,
            onError: (Object _, StackTrace _) {
              if (!_disposed) {
                _onStatus(CalendarSyncConnectionStatus.disconnected);
              }
            },
            onDone: () {
              if (!_disposed) {
                _onStatus(CalendarSyncConnectionStatus.disconnected);
              }
            },
          );
    } on Object {
      _onStatus(CalendarSyncConnectionStatus.disconnected);
    }
  }

  void _handleSignal(CalendarSyncSignal signal) {
    if (_disposed) {
      return;
    }
    switch (signal) {
      case CalendarSyncConnecting():
        _onStatus(CalendarSyncConnectionStatus.connecting);
      case CalendarSyncConnected():
        _onStatus(CalendarSyncConnectionStatus.live);
        // Closes the initial-query/subscription and reconnect gaps.
        requestRefresh();
      case CalendarSyncChanged(:final generation):
        final int? previous = _lastGeneration;
        if (previous != null && generation <= previous) {
          return;
        }
        _lastGeneration = generation;
        requestRefresh();
      case CalendarSyncDisconnected():
        _onStatus(CalendarSyncConnectionStatus.disconnected);
    }
  }

  Future<void> _drainRefreshes() async {
    try {
      while (_refreshRequested && !_disposed) {
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
      if (_refreshRequested && !_disposed) {
        requestRefresh();
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _refreshRequested = false;
    await _subscription?.cancel();
    await _refreshDrain;
  }
}
