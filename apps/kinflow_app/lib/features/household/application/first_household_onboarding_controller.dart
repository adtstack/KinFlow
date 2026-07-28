import 'dart:async';

import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class FirstHouseholdOnboardingController {
  factory FirstHouseholdOnboardingController({
    required HouseholdRepository repository,
    required HouseholdCreationIdGenerator idGenerator,
  }) {
    return FirstHouseholdOnboardingController._(repository, idGenerator);
  }

  FirstHouseholdOnboardingController._(this._repository, this._idGenerator);

  final HouseholdRepository _repository;
  final HouseholdCreationIdGenerator _idGenerator;
  final StreamController<FirstHouseholdOnboardingState> _states =
      StreamController<FirstHouseholdOnboardingState>.broadcast(sync: true);

  FirstHouseholdOnboardingState _state = const FirstHouseholdOnboardingIdle();
  Future<void> _pending = Future<void>.value();
  String? _retryFingerprint;
  HouseholdCreationId? _retryId;
  var _submitting = false;
  var _disposed = false;

  FirstHouseholdOnboardingState get state => _state;

  Stream<FirstHouseholdOnboardingState> get states => _states.stream;

  Future<void> submit({
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) {
    if (_submitting || _disposed) {
      return _pending;
    }
    _submitting = true;
    _pending = _submit(
      householdName: householdName,
      ownerDisplayName: ownerDisplayName,
      locale: locale,
      timezone: timezone,
    ).whenComplete(() => _submitting = false);
    return _pending;
  }

  Future<void> _submit({
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) async {
    final FirstHouseholdDraft? draft = FirstHouseholdDraft.tryCreate(
      householdName: householdName,
      ownerDisplayName: ownerDisplayName,
      locale: locale,
      timezone: timezone,
    );
    if (draft == null) {
      _emit(
        const FirstHouseholdOnboardingFailed(
          HouseholdFailure(HouseholdFailureKind.invalidInput),
        ),
      );
      return;
    }

    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    final CreateFirstHouseholdRequest request = draft.withId(_retryId!);
    _emit(const FirstHouseholdOnboardingSubmitting());

    final CreateFirstHouseholdResult result;
    try {
      result = await _repository.createFirstHousehold(request);
    } on Object {
      _emit(
        const FirstHouseholdOnboardingFailed(
          HouseholdFailure(HouseholdFailureKind.internal),
        ),
      );
      return;
    }

    switch (result) {
      case FirstHouseholdCreated(:final household):
        _emit(FirstHouseholdOnboardingSucceeded(household));
      case CreateFirstHouseholdFailed(:final failure):
        _emit(FirstHouseholdOnboardingFailed(failure));
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(FirstHouseholdOnboardingState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
