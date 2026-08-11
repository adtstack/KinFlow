import 'dart:async';

import 'package:kinflow_app/features/chores/application/chore_occurrence_target_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceTargetController {
  factory ChoreOccurrenceTargetController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
  }) => ChoreOccurrenceTargetController._(repository, idGenerator);

  ChoreOccurrenceTargetController._(this._repository, this._idGenerator);

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final StreamController<ChoreOccurrenceTargetState> _states =
      StreamController<ChoreOccurrenceTargetState>.broadcast(sync: true);

  ChoreOccurrenceTargetState _state = const ChoreOccurrenceTargetInitial();
  HouseholdId? _householdId;
  ChoreOccurrenceId? _occurrenceId;
  Future<void>? _pendingLoad;
  Future<void>? _pendingAction;
  String? _retryFingerprint;
  ChoreCommandId? _retryId;
  var _scopeVersion = 0;
  var _disposed = false;

  ChoreOccurrenceTargetState get state => _state;

  Stream<ChoreOccurrenceTargetState> get states => _states.stream;

  Future<void> load({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_disposed) return Future<void>.value();
    final Future<void>? pendingAction = _pendingAction;
    if (_householdId == householdId &&
        _occurrenceId == occurrenceId &&
        pendingAction != null) {
      return pendingAction;
    }
    final Future<void>? pendingLoad = _pendingLoad;
    if (_householdId == householdId &&
        _occurrenceId == occurrenceId &&
        pendingLoad != null) {
      return pendingLoad;
    }

    final bool scopeChanged =
        _householdId != householdId || _occurrenceId != occurrenceId;
    if (scopeChanged) {
      _pendingAction = null;
      _retryFingerprint = null;
      _retryId = null;
    }
    _householdId = householdId;
    _occurrenceId = occurrenceId;
    final int scopeVersion = ++_scopeVersion;
    _emit(
      ChoreOccurrenceTargetLoading(
        householdId: householdId,
        occurrenceId: occurrenceId,
      ),
    );
    final Future<void> load = _load(
      householdId: householdId,
      occurrenceId: occurrenceId,
      scopeVersion: scopeVersion,
    );
    _pendingLoad = load;
    unawaited(
      load.whenComplete(() {
        if (_scopeVersion == scopeVersion) {
          _pendingLoad = null;
        }
      }),
    );
    return load;
  }

  Future<void> retry() {
    final HouseholdId? householdId = _householdId;
    final ChoreOccurrenceId? occurrenceId = _occurrenceId;
    return householdId == null || occurrenceId == null
        ? Future<void>.value()
        : load(householdId: householdId, occurrenceId: occurrenceId);
  }

  Future<void> setCompleted({required bool completed}) {
    if (_disposed) return Future<void>.value();
    final Future<void>? pendingAction = _pendingAction;
    if (pendingAction != null) return pendingAction;
    final Future<void>? pendingLoad = _pendingLoad;
    if (pendingLoad != null) return pendingLoad;

    final ChoreOccurrenceTargetReady? ready =
        _state is ChoreOccurrenceTargetReady
        ? _state as ChoreOccurrenceTargetReady
        : null;
    if (ready == null ||
        !ready.occurrence.canSetCompletion ||
        completed ==
            (ready.occurrence.status == ChoreOccurrenceStatus.completed)) {
      return Future<void>.value();
    }
    final ChoreCompletionDraft? draft = ChoreCompletionDraft.tryCreate(
      householdId: ready.householdId,
      occurrenceId: ready.occurrence.id,
      expectedVersion: ready.occurrence.version,
      completed: completed,
    );
    if (draft == null) {
      _emit(
        ChoreOccurrenceTargetReady(
          householdId: ready.householdId,
          occurrence: ready.occurrence,
          actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return Future<void>.value();
    }
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }

    final int scopeVersion = _scopeVersion;
    _emit(
      ChoreOccurrenceTargetReady(
        householdId: ready.householdId,
        occurrence: ready.occurrence,
        actionInFlight: true,
      ),
    );
    final Future<void> action = _setCompletion(
      ready: ready,
      draft: draft,
      idempotencyKey: _retryId!,
      scopeVersion: scopeVersion,
    );
    _pendingAction = action;
    unawaited(
      action.whenComplete(() {
        if (identical(_pendingAction, action)) {
          _pendingAction = null;
        }
      }),
    );
    return action;
  }

  Future<void> _load({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int scopeVersion,
  }) async {
    final LoadChoreOccurrenceTargetResult result;
    try {
      result = await _repository.loadOccurrenceTarget(
        householdId: householdId,
        occurrenceId: occurrenceId,
      );
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emit(
          ChoreOccurrenceTargetLoadFailed(
            householdId: householdId,
            occurrenceId: occurrenceId,
            failure: const ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case ChoreOccurrenceTargetLoaded(:final occurrence):
        if (occurrence.id != occurrenceId) {
          _emit(
            ChoreOccurrenceTargetLoadFailed(
              householdId: householdId,
              occurrenceId: occurrenceId,
              failure: const ChoreFailure(ChoreFailureKind.invalidPayload),
            ),
          );
        } else {
          _emit(
            ChoreOccurrenceTargetReady(
              householdId: householdId,
              occurrence: occurrence,
            ),
          );
        }
      case LoadChoreOccurrenceTargetFailed(:final failure):
        _emit(
          ChoreOccurrenceTargetLoadFailed(
            householdId: householdId,
            occurrenceId: occurrenceId,
            failure: failure,
          ),
        );
    }
  }

  Future<void> _setCompletion({
    required ChoreOccurrenceTargetReady ready,
    required ChoreCompletionDraft draft,
    required ChoreCommandId idempotencyKey,
    required int scopeVersion,
  }) async {
    final SetChoreCompletionResult result;
    try {
      result = await _repository.setOccurrenceCompletion(
        draft.withId(idempotencyKey),
      );
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emitActionFailure(
          ready,
          const ChoreFailure(ChoreFailureKind.internal),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case ChoreCompletionSet(:final snapshot):
        final ChoreOccurrenceStatus expectedStatus = draft.completed
            ? ChoreOccurrenceStatus.completed
            : ChoreOccurrenceStatus.scheduled;
        if (snapshot.householdId != ready.householdId ||
            snapshot.occurrenceId != ready.occurrence.id ||
            snapshot.status != expectedStatus ||
            snapshot.version != ready.occurrence.version + 1) {
          _emitActionFailure(
            ready,
            const ChoreFailure(ChoreFailureKind.invalidPayload),
          );
          return;
        }
        _retryFingerprint = null;
        _retryId = null;
        final ChoreOccurrence reconciled = ready.occurrence.copyWith(
          status: snapshot.status,
          version: snapshot.version,
        );
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: ready.householdId,
            occurrence: reconciled,
            actionInFlight: true,
          ),
        );
        await _refreshAfterMutation(
          householdId: ready.householdId,
          occurrence: reconciled,
          scopeVersion: scopeVersion,
        );
      case SetChoreCompletionFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition ||
              failure.kind == ChoreFailureKind.notFoundOrForbidden ||
              failure.kind == ChoreFailureKind.unauthenticated:
        await _reconcileActionFailure(
          ready: ready,
          actionFailure: failure,
          scopeVersion: scopeVersion,
        );
      case SetChoreCompletionFailed(:final failure):
        _emitActionFailure(ready, failure);
    }
  }

  Future<void> _refreshAfterMutation({
    required HouseholdId householdId,
    required ChoreOccurrence occurrence,
    required int scopeVersion,
  }) async {
    final LoadChoreOccurrenceTargetResult result;
    try {
      result = await _repository.loadOccurrenceTarget(
        householdId: householdId,
        occurrenceId: occurrence.id,
      );
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: householdId,
            occurrence: occurrence,
            refreshFailure: const ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case ChoreOccurrenceTargetLoaded(:final occurrence):
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: householdId,
            occurrence: occurrence,
          ),
        );
      case LoadChoreOccurrenceTargetFailed(:final failure):
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: householdId,
            occurrence: occurrence,
            refreshFailure: failure,
          ),
        );
    }
  }

  Future<void> _reconcileActionFailure({
    required ChoreOccurrenceTargetReady ready,
    required ChoreFailure actionFailure,
    required int scopeVersion,
  }) async {
    final LoadChoreOccurrenceTargetResult result;
    try {
      result = await _repository.loadOccurrenceTarget(
        householdId: ready.householdId,
        occurrenceId: ready.occurrence.id,
      );
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: ready.householdId,
            occurrence: ready.occurrence,
            actionFailure: actionFailure,
            refreshFailure: const ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case ChoreOccurrenceTargetLoaded(:final occurrence):
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: ready.householdId,
            occurrence: occurrence,
            actionFailure: actionFailure,
          ),
        );
      case LoadChoreOccurrenceTargetFailed(:final failure)
          when failure.kind == ChoreFailureKind.notFoundOrForbidden ||
              failure.kind == ChoreFailureKind.unauthenticated:
        _emit(
          ChoreOccurrenceTargetLoadFailed(
            householdId: ready.householdId,
            occurrenceId: ready.occurrence.id,
            failure: failure,
          ),
        );
      case LoadChoreOccurrenceTargetFailed(:final failure):
        _emit(
          ChoreOccurrenceTargetReady(
            householdId: ready.householdId,
            occurrence: ready.occurrence,
            actionFailure: actionFailure,
            refreshFailure: failure,
          ),
        );
    }
  }

  void _emitActionFailure(
    ChoreOccurrenceTargetReady ready,
    ChoreFailure failure,
  ) {
    _emit(
      ChoreOccurrenceTargetReady(
        householdId: ready.householdId,
        occurrence: ready.occurrence,
        actionFailure: failure,
      ),
    );
  }

  bool _isCurrent(int scopeVersion) =>
      !_disposed && _scopeVersion == scopeVersion;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _scopeVersion += 1;
    await _states.close();
  }

  void _emit(ChoreOccurrenceTargetState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }
}
