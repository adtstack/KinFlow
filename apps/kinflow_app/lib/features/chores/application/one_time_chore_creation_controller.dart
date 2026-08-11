import 'dart:async';

import 'package:kinflow_app/features/chores/application/one_time_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class OneTimeChoreCreationController {
  factory OneTimeChoreCreationController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
  }) {
    return OneTimeChoreCreationController._(repository, idGenerator);
  }

  OneTimeChoreCreationController._(this._repository, this._idGenerator);

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final StreamController<OneTimeChoreCreationState> _states =
      StreamController<OneTimeChoreCreationState>.broadcast(sync: true);

  OneTimeChoreCreationState _state = const OneTimeChoreCreationIdle();
  Future<void> _pending = Future<void>.value();
  String? _retryFingerprint;
  ChoreCommandId? _retryId;
  var _busy = false;
  var _disposed = false;

  OneTimeChoreCreationState get state => _state;

  Stream<OneTimeChoreCreationState> get states => _states.stream;

  Future<void> create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _create(
      householdId: householdId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    final ChoreLocalDate? parsedDate = ChoreLocalDate.tryParse(dueLocalDate);
    final ChoreLocalTime? parsedTime = dueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(dueLocalTime);
    if (parsedDate == null || (dueLocalTime != null && parsedTime == null)) {
      _emit(
        const OneTimeChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return;
    }
    final OneTimeChoreDraft? draft = OneTimeChoreDraft.tryCreate(
      householdId: householdId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: parsedDate,
      dueLocalTime: parsedTime,
    );
    if (draft == null) {
      _emit(
        const OneTimeChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return;
    }
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emit(const OneTimeChoreCreationSubmitting());

    final CreateOneTimeChoreResult result;
    try {
      result = await _repository.createOneTimeChore(draft.withId(_retryId!));
    } on Object {
      _emit(
        const OneTimeChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case OneTimeChoreCreated(:final occurrence):
        _emit(OneTimeChoreCreationSucceeded(occurrence));
      case CreateOneTimeChoreFailed(:final failure):
        _emit(OneTimeChoreCreationFailed(failure));
    }
  }

  void reset() {
    if (_busy || _disposed) {
      return;
    }
    _retryFingerprint = null;
    _retryId = null;
    _emit(const OneTimeChoreCreationIdle());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(OneTimeChoreCreationState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
