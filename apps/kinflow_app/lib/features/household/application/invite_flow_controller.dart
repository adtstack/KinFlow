import 'dart:async';

import 'package:kinflow_app/features/household/application/invite_flow_state.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class InviteFlowController {
  factory InviteFlowController({
    required InviteRepository repository,
    required InviteCommandIdGenerator idGenerator,
    required PendingInviteStore pendingInviteStore,
  }) {
    return InviteFlowController._(repository, idGenerator, pendingInviteStore);
  }

  InviteFlowController._(
    this._repository,
    this._idGenerator,
    this._pendingInviteStore,
  );

  final InviteRepository _repository;
  final InviteCommandIdGenerator _idGenerator;
  final PendingInviteStore _pendingInviteStore;
  final StreamController<InviteFlowState> _states =
      StreamController<InviteFlowState>.broadcast(sync: true);

  InviteFlowState _state = const InviteFlowIdle();
  Future<void> _pending = Future<void>.value();
  int? _tokenFingerprint;
  InviteCommandId? _acceptId;
  bool? _acceptSetActive;
  var _busy = false;
  var _disposed = false;

  InviteFlowState get state => _state;

  Stream<InviteFlowState> get states => _states.stream;

  bool capture(String rawToken) {
    if (_disposed) {
      return false;
    }
    final bool captured = _pendingInviteStore.capture(rawToken);
    if (!captured) {
      _emit(const InviteFlowMissing());
    }
    return captured;
  }

  Future<void> loadPreview() {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    _pending = _loadPreview().whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _loadPreview() async {
    final InviteToken? token = _pendingInviteStore.read();
    if (token == null) {
      _tokenFingerprint = null;
      _emit(const InviteFlowMissing());
      return;
    }
    if (_tokenFingerprint != token.hashCode) {
      _tokenFingerprint = token.hashCode;
      _acceptId = null;
      _acceptSetActive = null;
    }
    _emit(const InviteFlowLoading());
    final PreviewHouseholdInviteResult result;
    try {
      result = await _repository.previewInvite(token);
    } on Object {
      _emit(const InviteFlowFailed(InviteFailure(InviteFailureKind.internal)));
      return;
    }
    switch (result) {
      case HouseholdInvitePreviewed(:final preview):
        _emit(InviteFlowPreviewReady(preview));
      case PreviewHouseholdInviteFailed(:final failure):
        if (_isTerminal(failure)) {
          _pendingInviteStore.clear();
          _tokenFingerprint = null;
        }
        _emit(InviteFlowFailed(failure));
    }
  }

  Future<void> accept({required bool setActiveHousehold}) {
    final bool hasPreview =
        _state is InviteFlowPreviewReady ||
        _state is InviteFlowFailed &&
            (_state as InviteFlowFailed).preview != null;
    if (_busy || _disposed || !hasPreview) {
      return _pending;
    }
    _busy = true;
    _pending = _accept(
      setActiveHousehold: setActiveHousehold,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _accept({required bool setActiveHousehold}) async {
    final InviteToken? token = _pendingInviteStore.read();
    final InviteFlowState current = _state;
    final preview = switch (current) {
      InviteFlowPreviewReady(:final preview) => preview,
      InviteFlowFailed(:final preview?) => preview,
      _ => null,
    };
    if (token == null || preview == null) {
      _emit(const InviteFlowMissing());
      return;
    }
    if (_acceptId == null || _acceptSetActive != setActiveHousehold) {
      _acceptId = _idGenerator.generate();
      _acceptSetActive = setActiveHousehold;
    }
    _emit(InviteFlowAccepting(preview));
    final AcceptHouseholdInviteResult result;
    try {
      result = await _repository.acceptInvite(
        AcceptHouseholdInviteRequest(
          idempotencyKey: _acceptId!,
          token: token,
          setActiveHousehold: setActiveHousehold,
        ),
      );
    } on Object {
      _emit(
        InviteFlowFailed(
          const InviteFailure(InviteFailureKind.internal),
          preview: preview,
        ),
      );
      return;
    }
    switch (result) {
      case HouseholdInviteAccepted(:final acceptance):
        _pendingInviteStore.clear();
        _tokenFingerprint = null;
        _emit(InviteFlowAccepted(acceptance));
      case AcceptHouseholdInviteFailed(:final failure):
        if (_isTerminal(failure)) {
          _pendingInviteStore.clear();
          _tokenFingerprint = null;
        }
        _emit(InviteFlowFailed(failure, preview: preview));
    }
  }

  void clear() {
    if (_busy || _disposed) {
      return;
    }
    _pendingInviteStore.clear();
    _tokenFingerprint = null;
    _acceptId = null;
    _acceptSetActive = null;
    _emit(const InviteFlowMissing());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(InviteFlowState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }

  bool _isTerminal(InviteFailure failure) {
    return switch (failure.kind) {
      InviteFailureKind.invalid ||
      InviteFailureKind.expired ||
      InviteFailureKind.revoked ||
      InviteFailureKind.alreadyUsed => true,
      _ => false,
    };
  }
}
