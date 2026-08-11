import 'dart:async';

import 'package:kinflow_app/features/household/application/household_selection_state.dart';
import 'package:kinflow_app/features/household/application/ports/active_household_committer.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdSelectionController {
  factory HouseholdSelectionController({
    required HouseholdSelectionRepository repository,
    required ActiveHouseholdCommitter committer,
  }) {
    return HouseholdSelectionController._(repository, committer);
  }

  HouseholdSelectionController._(this._repository, this._committer);

  final HouseholdSelectionRepository _repository;
  final ActiveHouseholdCommitter _committer;
  final StreamController<HouseholdSelectionState> _states =
      StreamController<HouseholdSelectionState>.broadcast(sync: true);

  HouseholdSelectionState _state = const HouseholdSelectionInitial();
  Future<void> _pending = Future<void>.value();
  var _busy = false;
  var _disposed = false;

  HouseholdSelectionState get state => _state;

  Stream<HouseholdSelectionState> get states => _states.stream;

  Future<void> load() {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _emit(const HouseholdSelectionLoading());
    _pending = _load().whenComplete(() => _busy = false);
    return _pending;
  }

  Future<bool> switchActiveHousehold(HouseholdId targetHouseholdId) async {
    if (_busy || _disposed || _state is! HouseholdSelectionReady) {
      return false;
    }
    final HouseholdSelectionReady ready = _state as HouseholdSelectionReady;
    final HouseholdSelection? target = _findTarget(
      ready.snapshot,
      targetHouseholdId,
    );
    if (target == null || target.isActive) {
      return false;
    }

    var succeeded = false;
    _busy = true;
    _emit(
      HouseholdSelectionReady(
        ready.snapshot,
        isSwitching: true,
        successfulSwitchCount: ready.successfulSwitchCount,
      ),
    );
    _pending = _switch(ready, target)
        .then((bool value) {
          succeeded = value;
        })
        .whenComplete(() => _busy = false);
    await _pending;
    return succeeded;
  }

  Future<bool> rejectSwitch(HouseholdSelectionFailureKind kind) async {
    if (_busy || _disposed || _state is! HouseholdSelectionReady) {
      return false;
    }
    final HouseholdSelectionReady ready = _state as HouseholdSelectionReady;
    _emitReadyFailure(ready, kind);
    return false;
  }

  Future<void> _load() async {
    final LoadHouseholdSelectionsResult result;
    try {
      result = await _repository.load();
    } on Object {
      _emit(
        const HouseholdSelectionLoadFailed(
          HouseholdSelectionFailure(HouseholdSelectionFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case HouseholdSelectionsLoaded(:final snapshot):
        _emit(HouseholdSelectionReady(snapshot));
      case LoadHouseholdSelectionsFailed(:final failure):
        _emit(HouseholdSelectionLoadFailed(failure));
    }
  }

  Future<bool> _switch(
    HouseholdSelectionReady previous,
    HouseholdSelection target,
  ) async {
    final SwitchActiveHouseholdResult result;
    try {
      result = await _repository.switchActiveHousehold(
        targetHouseholdId: target.householdId,
        expectedSelectionVersion: previous.snapshot.selectionVersion,
      );
    } on Object {
      _emitReadyFailure(previous, HouseholdSelectionFailureKind.internal);
      return false;
    }
    switch (result) {
      case SwitchActiveHouseholdFailed(:final failure):
        _emit(
          HouseholdSelectionReady(
            previous.snapshot,
            failure: failure,
            successfulSwitchCount: previous.successfulSwitchCount,
          ),
        );
        return false;
      case ActiveHouseholdSwitched(:final commit):
        final bool committed;
        try {
          committed = await _committer.commitActiveHousehold(
            commit.activeHousehold,
          );
        } on Object {
          _emitReadyFailure(
            previous,
            HouseholdSelectionFailureKind.localStateUnavailable,
          );
          return false;
        }
        if (!committed) {
          _emitReadyFailure(
            previous,
            HouseholdSelectionFailureKind.localStateUnavailable,
          );
          return false;
        }
        _emit(
          HouseholdSelectionReady(
            previous.snapshot.activate(
              commit.activeHousehold.householdId,
              version: commit.selectionVersion,
            ),
            successfulSwitchCount: previous.successfulSwitchCount + 1,
          ),
        );
        return true;
    }
  }

  HouseholdSelection? _findTarget(
    HouseholdSelectionSnapshot snapshot,
    HouseholdId targetHouseholdId,
  ) {
    for (final HouseholdSelection household in snapshot.households) {
      if (household.householdId == targetHouseholdId) {
        return household;
      }
    }
    return null;
  }

  void _emitReadyFailure(
    HouseholdSelectionReady previous,
    HouseholdSelectionFailureKind kind,
  ) {
    _emit(
      HouseholdSelectionReady(
        previous.snapshot,
        failure: HouseholdSelectionFailure(kind),
        successfulSwitchCount: previous.successfulSwitchCount,
      ),
    );
  }

  void _emit(HouseholdSelectionState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }
}
