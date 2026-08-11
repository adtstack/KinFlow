import 'dart:async';

import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_state.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

final class AppRuntimePolicyController {
  AppRuntimePolicyController(this._repository);

  final AppRuntimePolicyRepository _repository;
  final StreamController<AppRuntimePolicyState> _states =
      StreamController<AppRuntimePolicyState>.broadcast(sync: true);

  AppRuntimePolicyState _state = const AppRuntimePolicyInitial();
  Future<void> _pending = Future<void>.value();
  var _busy = false;
  var _disposed = false;

  AppRuntimePolicyState get state => _state;

  Stream<AppRuntimePolicyState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) return _pending;
    final AppRuntimePolicyReady? fallback =
        preserveContent && _state is AppRuntimePolicyReady
        ? _state as AppRuntimePolicyReady
        : null;
    _busy = true;
    _emit(
      fallback == null
          ? const AppRuntimePolicyLoading()
          : AppRuntimePolicyReady(
              snapshot: fallback.snapshot,
              isRefreshing: true,
            ),
    );
    _pending = _load(fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(AppRuntimePolicyReady? fallback) async {
    final AppRuntimePolicyResult result;
    try {
      result = await _repository.load();
    } on Object {
      _failure(
        fallback,
        const AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
      );
      return;
    }
    switch (result) {
      case AppRuntimePolicySucceeded(:final snapshot):
        _emit(AppRuntimePolicyReady(snapshot: snapshot));
      case AppRuntimePolicyFailed(:final failure):
        _failure(fallback, failure);
    }
  }

  void _failure(
    AppRuntimePolicyReady? fallback,
    AppRuntimePolicyFailure failure,
  ) {
    _emit(
      fallback == null
          ? AppRuntimePolicyLoadFailed(failure)
          : AppRuntimePolicyReady(
              snapshot: fallback.snapshot,
              refreshFailure: failure,
            ),
    );
  }

  void _emit(AppRuntimePolicyState next) {
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
