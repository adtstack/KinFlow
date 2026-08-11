import 'dart:async';

import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdActivationProgressController {
  factory HouseholdActivationProgressController({
    required ChoreRepository repository,
  }) => HouseholdActivationProgressController._(repository);

  HouseholdActivationProgressController._(this._repository);

  final ChoreRepository _repository;
  final StreamController<HouseholdActivationProgressState> _states =
      StreamController<HouseholdActivationProgressState>.broadcast(sync: true);

  HouseholdActivationProgressState _state =
      const HouseholdActivationProgressInitial();
  HouseholdId? _pendingHouseholdId;
  Future<void>? _pendingLoad;
  var _requestVersion = 0;
  var _disposed = false;

  HouseholdActivationProgressState get state => _state;

  Stream<HouseholdActivationProgressState> get states => _states.stream;

  Future<void> load(HouseholdId householdId, {bool preserveContent = false}) {
    if (_disposed) {
      return Future<void>.value();
    }
    final Future<void>? pendingLoad = _pendingLoad;
    if (_pendingHouseholdId == householdId && pendingLoad != null) {
      return pendingLoad;
    }

    final int requestVersion = ++_requestVersion;
    _pendingHouseholdId = householdId;
    final HouseholdActivationProgressState currentState = _state;
    if (preserveContent &&
        currentState is HouseholdActivationProgressReady &&
        currentState.progress.householdId == householdId) {
      _emit(
        HouseholdActivationProgressReady(
          progress: currentState.progress,
          refreshing: true,
        ),
      );
    } else {
      _emit(HouseholdActivationProgressLoading(householdId));
    }

    final Future<void> load = _load(householdId, requestVersion);
    _pendingLoad = load;
    unawaited(
      load.whenComplete(() {
        if (_requestVersion == requestVersion) {
          _pendingHouseholdId = null;
          _pendingLoad = null;
        }
      }),
    );
    return load;
  }

  Future<void> _load(HouseholdId householdId, int requestVersion) async {
    final LoadHouseholdActivationProgressResult result;
    try {
      result = await _repository.loadHouseholdActivationProgress(householdId);
    } on Object {
      if (_isCurrent(requestVersion)) {
        _emit(
          HouseholdActivationProgressFailed(
            householdId: householdId,
            failure: const ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(requestVersion)) {
      return;
    }
    switch (result) {
      case HouseholdActivationProgressLoaded(:final progress):
        if (progress.householdId != householdId) {
          _emit(
            HouseholdActivationProgressFailed(
              householdId: householdId,
              failure: const ChoreFailure(ChoreFailureKind.invalidPayload),
            ),
          );
          return;
        }
        _emit(HouseholdActivationProgressReady(progress: progress));
      case LoadHouseholdActivationProgressFailed(:final failure):
        _emit(
          HouseholdActivationProgressFailed(
            householdId: householdId,
            failure: failure,
          ),
        );
    }
  }

  bool _isCurrent(int requestVersion) =>
      !_disposed && _requestVersion == requestVersion;

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _requestVersion += 1;
    await _states.close();
  }

  void _emit(HouseholdActivationProgressState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
