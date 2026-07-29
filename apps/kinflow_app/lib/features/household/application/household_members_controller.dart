import 'dart:async';

import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdMembersController {
  HouseholdMembersController({
    required HouseholdMemberRepository repository,
    required HouseholdCommandIdGenerator idGenerator,
    required RecentAuthenticationService recentAuthenticationService,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _recentAuthenticationService = recentAuthenticationService;

  final HouseholdMemberRepository _repository;
  final HouseholdCommandIdGenerator _idGenerator;
  final RecentAuthenticationService _recentAuthenticationService;
  final StreamController<HouseholdMembersState> _states =
      StreamController<HouseholdMembersState>.broadcast(sync: true);

  HouseholdMembersState _state = const HouseholdMembersInitial();
  Future<void> _pending = Future<void>.value();
  HouseholdCommandId? _retryId;
  String? _retryFingerprint;
  var _busy = false;
  var _disposed = false;

  HouseholdMembersState get state => _state;

  Stream<HouseholdMembersState> get states => _states.stream;

  Future<void> load(HouseholdId householdId) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _load(
      householdId,
      initial: true,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> changeRole(HouseholdMember target, HouseholdMemberRole newRole) {
    return _runAction((HouseholdMemberRoster roster) async {
      final HouseholdMember actor = roster.currentMember;
      final bool allowed =
          actor.id != target.id &&
          target.role != HouseholdMemberRole.owner &&
          newRole != HouseholdMemberRole.owner &&
          target.role != newRole &&
          (actor.role == HouseholdMemberRole.owner ||
              actor.role == HouseholdMemberRole.admin &&
                  target.role == HouseholdMemberRole.member &&
                  newRole == HouseholdMemberRole.admin);
      if (!allowed) {
        _emitFailure(roster, HouseholdMemberFailureKind.roleNotAllowed);
        return;
      }

      final RecentAuthenticationProof? proof = await _recentProof(roster);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'change-role|${roster.householdId.value}|${target.id.value}|'
          '${target.version}|${newRole.name}';
      final HouseholdMemberCommandResult result = await _repository.changeRole(
        ChangeHouseholdMemberRoleCommand(
          idempotencyKey: _commandId(fingerprint),
          householdId: roster.householdId,
          memberId: target.id,
          role: newRole,
          expectedVersion: target.version,
          recentAuthenticationProof: proof,
        ),
      );
      await _handleMutationResult(result, roster);
    });
  }

  Future<void> removeMember(HouseholdMember target) {
    return _runAction((HouseholdMemberRoster roster) async {
      final HouseholdMember actor = roster.currentMember;
      final bool allowed =
          actor.id != target.id &&
          target.role != HouseholdMemberRole.owner &&
          (actor.role == HouseholdMemberRole.owner ||
              actor.role == HouseholdMemberRole.admin &&
                  target.role == HouseholdMemberRole.member);
      if (!allowed) {
        _emitFailure(roster, HouseholdMemberFailureKind.permissionDenied);
        return;
      }
      final String fingerprint =
          'remove|${roster.householdId.value}|${target.id.value}|'
          '${target.version}';
      final HouseholdMemberCommandResult result = await _repository
          .removeMember(
            RemoveHouseholdMemberCommand(
              idempotencyKey: _commandId(fingerprint),
              householdId: roster.householdId,
              memberId: target.id,
              expectedVersion: target.version,
            ),
          );
      await _handleMutationResult(result, roster);
    });
  }

  Future<void> leaveHousehold() {
    return _runAction((HouseholdMemberRoster roster) async {
      final HouseholdMember actor = roster.currentMember;
      if (actor.role == HouseholdMemberRole.owner) {
        _emitFailure(roster, HouseholdMemberFailureKind.ownerTransferRequired);
        return;
      }
      final String fingerprint =
          'leave|${roster.householdId.value}|${actor.version}';
      final HouseholdMemberCommandResult result = await _repository
          .leaveHousehold(
            LeaveHouseholdCommand(
              idempotencyKey: _commandId(fingerprint),
              householdId: roster.householdId,
              expectedVersion: actor.version,
            ),
          );
      switch (result) {
        case HouseholdMemberCommandCompleted():
          _clearRetry();
          _emit(const HouseholdMembersLeft());
        case HouseholdMemberCommandFailed(:final failure):
          _emit(HouseholdMembersReady(roster, failure: failure));
      }
    });
  }

  Future<void> transferOwner(HouseholdMember target) {
    return _runAction((HouseholdMemberRoster roster) async {
      final HouseholdMember actor = roster.currentMember;
      if (actor.role != HouseholdMemberRole.owner ||
          actor.id == target.id ||
          target.role == HouseholdMemberRole.owner) {
        _emitFailure(roster, HouseholdMemberFailureKind.roleNotAllowed);
        return;
      }
      final RecentAuthenticationProof? proof = await _recentProof(roster);
      if (proof == null) {
        return;
      }
      final String fingerprint =
          'transfer-owner|${roster.householdId.value}|${target.id.value}|'
          '${roster.householdVersion}';
      final HouseholdMemberCommandResult result = await _repository
          .transferOwner(
            TransferHouseholdOwnerCommand(
              idempotencyKey: _commandId(fingerprint),
              householdId: roster.householdId,
              newOwnerMemberId: target.id,
              expectedVersion: roster.householdVersion,
              recentAuthenticationProof: proof,
            ),
          );
      await _handleMutationResult(result, roster);
    });
  }

  Future<void> _runAction(
    Future<void> Function(HouseholdMemberRoster roster) action,
  ) {
    if (_busy || _disposed || _state is! HouseholdMembersReady) {
      return _pending;
    }
    final HouseholdMemberRoster roster =
        (_state as HouseholdMembersReady).roster;
    _busy = true;
    _emit(HouseholdMembersReady(roster, isSubmitting: true));
    _pending = action(roster).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<RecentAuthenticationProof?> _recentProof(
    HouseholdMemberRoster roster,
  ) async {
    final RecentAuthenticationResult result = await _recentAuthenticationService
        .authenticate();
    return switch (result) {
      RecentAuthenticationCompleted(:final proof) => proof,
      RecentAuthenticationFailed(:final kind) => _handleRecentAuthFailure(
        roster,
        kind,
      ),
    };
  }

  RecentAuthenticationProof? _handleRecentAuthFailure(
    HouseholdMemberRoster roster,
    RecentAuthenticationFailureKind kind,
  ) {
    final HouseholdMemberFailureKind failureKind = switch (kind) {
      RecentAuthenticationFailureKind.cancelled =>
        HouseholdMemberFailureKind.recentAuthenticationCancelled,
      RecentAuthenticationFailureKind.accountChanged =>
        HouseholdMemberFailureKind.accountChanged,
      RecentAuthenticationFailureKind.unauthenticated ||
      RecentAuthenticationFailureKind.invalidProof =>
        HouseholdMemberFailureKind.recentAuthenticationRequired,
      RecentAuthenticationFailureKind.providerUnavailable ||
      RecentAuthenticationFailureKind.temporarilyUnavailable =>
        HouseholdMemberFailureKind.temporarilyUnavailable,
      RecentAuthenticationFailureKind.internal =>
        HouseholdMemberFailureKind.internal,
    };
    _emitFailure(roster, failureKind);
    return null;
  }

  Future<void> _handleMutationResult(
    HouseholdMemberCommandResult result,
    HouseholdMemberRoster roster,
  ) async {
    switch (result) {
      case HouseholdMemberCommandCompleted():
        _clearRetry();
        await _load(roster.householdId, initial: false, fallback: roster);
      case HouseholdMemberCommandFailed(:final failure):
        _emit(HouseholdMembersReady(roster, failure: failure));
    }
  }

  Future<void> _load(
    HouseholdId householdId, {
    required bool initial,
    HouseholdMemberRoster? fallback,
  }) async {
    if (initial) {
      _emit(const HouseholdMembersLoading());
    }
    final LoadHouseholdMemberRosterResult result;
    try {
      result = await _repository.loadRoster(householdId);
    } on Object {
      if (fallback != null) {
        _emit(
          HouseholdMembersReady(
            fallback,
            failure: const HouseholdMemberFailure(
              HouseholdMemberFailureKind.internal,
            ),
          ),
        );
        return;
      }
      _emit(
        const HouseholdMembersLoadFailed(
          HouseholdMemberFailure(HouseholdMemberFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case HouseholdMemberRosterLoaded(:final roster):
        _emit(HouseholdMembersReady(roster));
      case LoadHouseholdMemberRosterFailed(:final failure):
        if (fallback != null) {
          _emit(HouseholdMembersReady(fallback, failure: failure));
        } else {
          _emit(HouseholdMembersLoadFailed(failure));
        }
    }
  }

  HouseholdCommandId _commandId(String fingerprint) {
    if (_retryFingerprint != fingerprint || _retryId == null) {
      _retryFingerprint = fingerprint;
      _retryId = _idGenerator.generate();
    }
    return _retryId!;
  }

  void _clearRetry() {
    _retryFingerprint = null;
    _retryId = null;
  }

  void _emitFailure(
    HouseholdMemberRoster roster,
    HouseholdMemberFailureKind kind,
  ) {
    _emit(HouseholdMembersReady(roster, failure: HouseholdMemberFailure(kind)));
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(HouseholdMembersState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
