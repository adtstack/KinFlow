import 'dart:async';

import 'package:kinflow_app/features/household/application/invite_creation_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final RegExp _inviteEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+$');

final class InviteCreationController {
  factory InviteCreationController({
    required InviteRepository repository,
    required InviteCommandIdGenerator idGenerator,
  }) {
    return InviteCreationController._(repository, idGenerator);
  }

  InviteCreationController._(this._repository, this._idGenerator);

  final InviteRepository _repository;
  final InviteCommandIdGenerator _idGenerator;
  final StreamController<InviteCreationState> _states =
      StreamController<InviteCreationState>.broadcast(sync: true);

  InviteCreationState _state = const InviteCreationIdle();
  Future<void> _pending = Future<void>.value();
  String? _retryFingerprint;
  InviteCommandId? _retryId;
  var _busy = false;
  var _disposed = false;

  InviteCreationState get state => _state;

  Stream<InviteCreationState> get states => _states.stream;

  Future<void> create({
    required HouseholdId householdId,
    required String targetEmail,
  }) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _create(
      householdId: householdId,
      targetEmail: targetEmail,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _create({
    required HouseholdId householdId,
    required String targetEmail,
  }) async {
    final String normalizedEmail = targetEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty &&
        (normalizedEmail.length > 254 ||
            !_inviteEmailPattern.hasMatch(normalizedEmail))) {
      _emit(
        const InviteCreationFailed(
          InviteFailure(InviteFailureKind.invalidInput),
        ),
      );
      return;
    }
    final String fingerprint =
        '${householdId.value}|$normalizedEmail|member|168';
    if (_retryFingerprint != fingerprint || _retryId == null) {
      _retryFingerprint = fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emit(const InviteCreationSubmitting());

    final CreateHouseholdInviteResult result;
    try {
      result = await _repository.createInvite(
        CreateHouseholdInviteRequest(
          idempotencyKey: _retryId!,
          householdId: householdId,
          role: HouseholdInviteRole.member,
          expiresInHours: 168,
          targetEmail: normalizedEmail.isEmpty ? null : normalizedEmail,
        ),
      );
    } on Object {
      _emit(
        const InviteCreationFailed(InviteFailure(InviteFailureKind.internal)),
      );
      return;
    }
    switch (result) {
      case HouseholdInviteCreated(:final invite):
        _emit(InviteCreationSucceeded(invite));
      case CreateHouseholdInviteFailed(:final failure):
        _emit(InviteCreationFailed(failure));
    }
  }

  Future<void> revoke() {
    if (_busy || _disposed || _state is! InviteCreationSucceeded) {
      return _pending;
    }
    final HouseholdInvite invite = (_state as InviteCreationSucceeded).invite;
    _busy = true;
    _pending = _revoke(invite).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _revoke(HouseholdInvite invite) async {
    _emit(InviteCreationRevoking(invite));
    final RevokeHouseholdInviteResult result;
    try {
      result = await _repository.revokeInvite(
        RevokeHouseholdInviteRequest(
          idempotencyKey: _idGenerator.generate(),
          householdId: invite.householdId,
          inviteId: invite.id,
        ),
      );
    } on Object {
      _emit(
        InviteCreationFailed(
          const InviteFailure(InviteFailureKind.internal),
          invite: invite,
        ),
      );
      return;
    }
    switch (result) {
      case HouseholdInviteRevoked():
        _retryFingerprint = null;
        _retryId = null;
        _emit(const InviteCreationIdle());
      case RevokeHouseholdInviteFailed(:final failure):
        _emit(InviteCreationFailed(failure, invite: invite));
    }
  }

  void startNewInvite() {
    if (_busy || _disposed) {
      return;
    }
    _retryFingerprint = null;
    _retryId = null;
    _emit(const InviteCreationIdle());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(InviteCreationState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
