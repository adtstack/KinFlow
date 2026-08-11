import 'dart:async';

import 'package:kinflow_app/features/analytics/application/analytics_preference_state.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

final class AnalyticsPreferenceController {
  AnalyticsPreferenceController(this._repository);

  final AnalyticsPreferenceRepository _repository;
  final StreamController<AnalyticsPreferenceState> _states =
      StreamController<AnalyticsPreferenceState>.broadcast(sync: true);

  AnalyticsPreferenceState _state = const AnalyticsPreferenceInitial();
  Future<void> _pending = Future<void>.value();
  bool _busy = false;
  bool _disposed = false;

  AnalyticsPreferenceState get state => _state;

  Stream<AnalyticsPreferenceState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) return _pending;
    _busy = true;
    final AnalyticsPreferenceReady? fallback =
        preserveContent && _state is AnalyticsPreferenceReady
        ? _state as AnalyticsPreferenceReady
        : null;
    _emit(
      fallback == null
          ? const AnalyticsPreferenceLoading()
          : AnalyticsPreferenceReady(
              preference: fallback.preference,
              isRefreshing: true,
              saveCount: fallback.saveCount,
            ),
    );
    _pending = _load(fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> save(AnalyticsUsagePreference preference) {
    if (_busy || _disposed || _state is! AnalyticsPreferenceReady) {
      return _pending;
    }
    final AnalyticsPreferenceReady current = _state as AnalyticsPreferenceReady;
    if (current.preference == preference) {
      return Future<void>.value();
    }
    _busy = true;
    _emit(
      AnalyticsPreferenceReady(
        preference: current.preference,
        isSaving: true,
        saveCount: current.saveCount,
      ),
    );
    _pending = _save(current, preference).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(AnalyticsPreferenceReady? fallback) async {
    final AnalyticsPreferenceResult result;
    try {
      result = await _repository.load();
    } on Object {
      _loadFailure(fallback, AnalyticsPreferenceFailureKind.internal);
      return;
    }
    switch (result) {
      case AnalyticsPreferenceSucceeded(:final preference):
        _emit(
          AnalyticsPreferenceReady(
            preference: preference,
            saveCount: fallback?.saveCount ?? 0,
          ),
        );
      case AnalyticsPreferenceFailed(:final failure):
        _loadFailure(fallback, failure.kind);
    }
  }

  Future<void> _save(
    AnalyticsPreferenceReady previous,
    AnalyticsUsagePreference preference,
  ) async {
    final AnalyticsPreferenceResult result;
    try {
      result = await _repository.save(preference);
    } on Object {
      _saveFailure(previous, AnalyticsPreferenceFailureKind.internal);
      return;
    }
    switch (result) {
      case AnalyticsPreferenceSucceeded(:final preference):
        _emit(
          AnalyticsPreferenceReady(
            preference: preference,
            saveCount: previous.saveCount + 1,
          ),
        );
      case AnalyticsPreferenceFailed(:final failure):
        _saveFailure(previous, failure.kind);
    }
  }

  void _loadFailure(
    AnalyticsPreferenceReady? fallback,
    AnalyticsPreferenceFailureKind kind,
  ) {
    final AnalyticsPreferenceFailure failure = AnalyticsPreferenceFailure(kind);
    _emit(
      fallback == null
          ? AnalyticsPreferenceLoadFailed(failure)
          : AnalyticsPreferenceReady(
              preference: fallback.preference,
              failure: failure,
              saveCount: fallback.saveCount,
            ),
    );
  }

  void _saveFailure(
    AnalyticsPreferenceReady previous,
    AnalyticsPreferenceFailureKind kind,
  ) {
    _emit(
      AnalyticsPreferenceReady(
        preference: previous.preference,
        failure: AnalyticsPreferenceFailure(kind),
        saveCount: previous.saveCount,
      ),
    );
  }

  void _emit(AnalyticsPreferenceState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }
}
