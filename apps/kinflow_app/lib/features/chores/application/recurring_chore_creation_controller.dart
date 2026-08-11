import 'dart:async';

import 'package:kinflow_app/features/chores/application/recurring_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class RecurringChoreCreationController {
  factory RecurringChoreCreationController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
  }) => RecurringChoreCreationController._(repository, idGenerator);

  RecurringChoreCreationController._(this._repository, this._idGenerator);

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final StreamController<RecurringChoreCreationState> _states =
      StreamController<RecurringChoreCreationState>.broadcast(sync: true);

  RecurringChoreCreationState _state = const RecurringChoreCreationIdle();
  Future<void> _pending = Future<void>.value();
  String? _retryFingerprint;
  ChoreCommandId? _retryId;
  var _busy = false;
  var _disposed = false;

  RecurringChoreCreationState get state => _state;

  Stream<RecurringChoreCreationState> get states => _states.stream;

  Future<void> create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
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
      startLocalDate: startLocalDate,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) async {
    final ChoreLocalDate? parsedDate = ChoreLocalDate.tryParse(startLocalDate);
    final ChoreLocalTime? parsedTime = dueLocalTime == null
        ? null
        : ChoreLocalTime.tryParse(dueLocalTime);
    if (parsedDate == null || (dueLocalTime != null && parsedTime == null)) {
      _emit(
        const RecurringChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return;
    }
    final RecurringChoreDraft? draft = RecurringChoreDraft.tryCreate(
      householdId: householdId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: parsedDate,
      dueLocalTime: parsedTime,
      recurrenceRule: recurrenceRule,
    );
    if (draft == null) {
      _emit(
        const RecurringChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return;
    }
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emit(const RecurringChoreCreationSubmitting());

    final CreateRecurringChoreResult result;
    try {
      result = await _repository.createRecurringChore(draft.withId(_retryId!));
    } on Object {
      _emit(
        const RecurringChoreCreationFailed(
          ChoreFailure(ChoreFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case RecurringChoreCreated(:final snapshot):
        _emit(RecurringChoreCreationSucceeded(snapshot));
      case CreateRecurringChoreFailed(:final failure):
        _emit(RecurringChoreCreationFailed(failure));
    }
  }

  void reset() {
    if (_busy || _disposed) {
      return;
    }
    _retryFingerprint = null;
    _retryId = null;
    _emit(const RecurringChoreCreationIdle());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(RecurringChoreCreationState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
