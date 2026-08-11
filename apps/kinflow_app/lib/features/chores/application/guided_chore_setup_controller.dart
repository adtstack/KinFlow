import 'dart:async';

import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class GuidedChoreSetupController {
  factory GuidedChoreSetupController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
    required GuidedChoreSetupResumeStore resumeStore,
  }) => GuidedChoreSetupController._(repository, idGenerator, resumeStore);

  GuidedChoreSetupController._(
    this._repository,
    this._idGenerator,
    this._resumeStore,
  );

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final GuidedChoreSetupResumeStore _resumeStore;
  final StreamController<GuidedChoreSetupState> _states =
      StreamController<GuidedChoreSetupState>.broadcast(sync: true);

  GuidedChoreSetupState _state = const GuidedChoreSetupInitial();
  Future<void> _pending = Future<void>.value();
  HouseholdId? _householdId;
  HouseholdMemberId? _assigneeMemberId;
  ChoreLocalDate? _startLocalDate;
  String? _householdTimezone;
  GuidedChoreSetupResumePlan? _plan;
  var _resumed = false;
  var _busy = false;
  var _disposed = false;

  GuidedChoreSetupState get state => _state;

  Stream<GuidedChoreSetupState> get states => _states.stream;

  Future<void> load({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
  }) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _load(
      householdId: householdId,
      assigneeMemberId: assigneeMemberId,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
  }) async {
    _emit(const GuidedChoreSetupLoading());
    final LoadTodayChoresResult result;
    try {
      result = await _repository.loadToday(householdId);
    } on Object {
      _emit(
        const GuidedChoreSetupLoadFailed(
          ChoreFailure(ChoreFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case TodayChoresLoaded(:final today, :final cacheMetadata):
        if (today.householdId != householdId) {
          _emit(
            const GuidedChoreSetupLoadFailed(
              ChoreFailure(ChoreFailureKind.invalidPayload),
            ),
          );
          return;
        }
        if (cacheMetadata != null) {
          _emit(
            const GuidedChoreSetupLoadFailed(
              ChoreFailure(ChoreFailureKind.offlineReadOnly),
            ),
          );
          return;
        }
        _householdId = householdId;
        _assigneeMemberId = assigneeMemberId;
        _startLocalDate = today.localDate;
        _householdTimezone = today.householdTimezone;
        _plan = null;
        _resumed = false;
        final GuidedChoreSetupResumePlan? storedPlan = await _readStoredPlan(
          householdId: householdId,
          assigneeMemberId: assigneeMemberId,
        );
        if (storedPlan != null) {
          _startLocalDate = storedPlan.startLocalDate;
          _householdTimezone = storedPlan.householdTimezone;
          _plan = storedPlan;
          _resumed = true;
          await _continuePlan(storedPlan);
          return;
        }
        _emit(
          GuidedChoreSetupReady(
            startLocalDate: today.localDate,
            householdTimezone: today.householdTimezone,
          ),
        );
      case LoadTodayChoresFailed(:final failure):
        _emit(GuidedChoreSetupLoadFailed(failure));
    }
  }

  Future<void> submit(List<GuidedChoreSetupInput> inputs) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _submit(inputs).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _submit(List<GuidedChoreSetupInput> inputs) async {
    final HouseholdId? householdId = _householdId;
    final HouseholdMemberId? assigneeMemberId = _assigneeMemberId;
    final ChoreLocalDate? startLocalDate = _startLocalDate;
    final String? householdTimezone = _householdTimezone;
    if (householdId == null ||
        assigneeMemberId == null ||
        startLocalDate == null ||
        householdTimezone == null) {
      _emit(
        const GuidedChoreSetupLoadFailed(
          ChoreFailure(ChoreFailureKind.invalidTransition),
        ),
      );
      return;
    }

    final GuidedChoreSetupDraft? draft = GuidedChoreSetupDraft.tryCreate(
      householdId: householdId,
      assigneeMemberId: assigneeMemberId,
      startLocalDate: startLocalDate,
      inputs: inputs,
    );
    final GuidedChoreSetupResumePlan? existingPlan = _plan;
    if (draft == null) {
      _emitSubmissionFailure(
        const ChoreFailure(ChoreFailureKind.invalidInput),
        plan: existingPlan,
      );
      return;
    }
    if (existingPlan != null) {
      if (existingPlan.draft.fingerprint != draft.fingerprint) {
        _emitSubmissionFailure(
          const ChoreFailure(ChoreFailureKind.invalidTransition),
          plan: existingPlan,
        );
        return;
      }
      await _continuePlan(existingPlan);
      return;
    }

    final List<ChoreCommandId> ids;
    try {
      ids = List<ChoreCommandId>.generate(
        GuidedChoreSetupDraft.requiredEntryCount,
        (_) => _idGenerator.generate(),
        growable: false,
      );
    } on Object {
      _emitSubmissionFailure(const ChoreFailure(ChoreFailureKind.internal));
      return;
    }
    final GuidedChoreSetupResumePlan? newPlan =
        GuidedChoreSetupResumePlan.tryCreate(
          householdId: householdId,
          assigneeMemberId: assigneeMemberId,
          startLocalDate: startLocalDate,
          householdTimezone: householdTimezone,
          inputs: inputs,
          commandIds: ids,
          completedCount: 0,
        );
    if (newPlan == null || !await _writeStoredPlan(newPlan)) {
      _emitSubmissionFailure(const ChoreFailure(ChoreFailureKind.internal));
      return;
    }
    _plan = newPlan;
    await _continuePlan(newPlan);
  }

  Future<void> _continuePlan(GuidedChoreSetupResumePlan initialPlan) async {
    GuidedChoreSetupResumePlan plan = initialPlan;
    _emitSubmitting(plan);
    for (
      var index = plan.completedCount;
      index < plan.draft.entries.length;
      index += 1
    ) {
      final CreateRecurringChoreResult result;
      try {
        result = await _repository.createRecurringChore(
          plan.draft.entries[index].draft.withId(plan.commandIds[index]),
        );
      } on Object {
        _emitSubmissionFailure(
          const ChoreFailure(ChoreFailureKind.internal),
          plan: plan,
        );
        return;
      }
      switch (result) {
        case RecurringChoreCreated(:final snapshot):
          if (snapshot.householdId != plan.householdId) {
            _emitSubmissionFailure(
              const ChoreFailure(ChoreFailureKind.invalidPayload),
              plan: plan,
            );
            return;
          }
          final GuidedChoreSetupResumePlan checkpoint = plan.withCompletedCount(
            index + 1,
          )!;
          if (!await _writeStoredPlan(checkpoint)) {
            _emitSubmissionFailure(
              const ChoreFailure(ChoreFailureKind.internal),
              plan: plan,
            );
            return;
          }
          plan = checkpoint;
          _plan = plan;
          _emitSubmitting(plan);
        case CreateRecurringChoreFailed(:final failure):
          _emitSubmissionFailure(failure, plan: plan);
          return;
      }
    }
    if (!await _clearStoredPlan()) {
      _emitSubmissionFailure(
        const ChoreFailure(ChoreFailureKind.internal),
        plan: plan,
      );
      return;
    }
    _plan = null;
    _resumed = false;
    _emit(GuidedChoreSetupSucceeded(createdCount: plan.completedCount));
  }

  Future<bool> discard() {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    if (_busy) {
      return _pending.then((_) => discard());
    }
    _busy = true;
    final Future<bool> operation = _discard().whenComplete(() => _busy = false);
    _pending = operation.then<void>((_) {});
    return operation;
  }

  Future<bool> _discard() async {
    if (await _clearStoredPlan()) {
      _plan = null;
      _resumed = false;
      return true;
    }
    _emitSubmissionFailure(
      const ChoreFailure(ChoreFailureKind.internal),
      plan: _plan,
    );
    return false;
  }

  void _emitSubmitting(GuidedChoreSetupResumePlan plan) {
    _emit(
      GuidedChoreSetupSubmitting(
        startLocalDate: plan.startLocalDate,
        householdTimezone: plan.householdTimezone,
        completedCount: plan.completedCount,
        frozenInputs: plan.inputs,
        resumed: _resumed,
      ),
    );
  }

  Future<GuidedChoreSetupResumePlan?> _readStoredPlan({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
  }) async {
    try {
      return await _resumeStore.read(
        expectedHouseholdId: householdId,
        expectedAssigneeMemberId: assigneeMemberId,
      );
    } on Object {
      return null;
    }
  }

  Future<bool> _writeStoredPlan(GuidedChoreSetupResumePlan plan) async {
    try {
      return await _resumeStore.write(plan);
    } on Object {
      return false;
    }
  }

  Future<bool> _clearStoredPlan() async {
    try {
      return await _resumeStore.clear();
    } on Object {
      return false;
    }
  }

  void _emitSubmissionFailure(
    ChoreFailure failure, {
    GuidedChoreSetupResumePlan? plan,
  }) {
    final ChoreLocalDate? startLocalDate =
        plan?.startLocalDate ?? _startLocalDate;
    final String? householdTimezone =
        plan?.householdTimezone ?? _householdTimezone;
    if (startLocalDate == null || householdTimezone == null) {
      _emit(GuidedChoreSetupLoadFailed(failure));
      return;
    }
    _emit(
      GuidedChoreSetupSubmissionFailed(
        startLocalDate: startLocalDate,
        householdTimezone: householdTimezone,
        completedCount: plan?.completedCount ?? 0,
        failure: failure,
        draftFrozen: plan != null,
        frozenInputs: plan?.inputs ?? const <GuidedChoreSetupInput>[],
        resumed: _resumed,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(GuidedChoreSetupState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
