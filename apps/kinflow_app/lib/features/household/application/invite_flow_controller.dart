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
  final Set<Future<void>> _operations = <Future<void>>{};
  int? _credentialFingerprint;
  InviteCommandId? _acceptId;
  bool? _acceptSetActive;
  var _operationRevision = 0;
  int? _busyRevision;
  var _disposed = false;

  InviteFlowState get state => _state;

  Stream<InviteFlowState> get states => _states.stream;

  bool capture(String rawToken) {
    if (_disposed) {
      return false;
    }
    _advanceOperationRevision();
    final bool captured = _pendingInviteStore.capture(rawToken);
    if (!captured) {
      _emit(const InviteFlowMissing());
    } else {
      _emit(const InviteFlowIdle());
    }
    return captured;
  }

  bool captureShortCode(String rawShortCode) {
    if (_disposed) {
      return false;
    }
    _advanceOperationRevision();
    final bool captured = _pendingInviteStore.captureShortCode(rawShortCode);
    if (!captured) {
      _emit(const InviteFlowMissing());
    } else {
      _emit(const InviteFlowIdle());
    }
    return captured;
  }

  Future<void> loadPreview() {
    if (_disposed || _busyRevision == _operationRevision) {
      return _pending;
    }
    return _startOperation(_loadPreview);
  }

  Future<void> _loadPreview(int revision) async {
    final InviteToken? token = _pendingInviteStore.read();
    final InviteShortCode? shortCode = _pendingInviteStore.readShortCode();
    if (token == null && shortCode == null ||
        token != null && shortCode != null) {
      if (_isCurrent(revision)) {
        _credentialFingerprint = null;
        if (token != null && shortCode != null) {
          _pendingInviteStore.clear();
        }
        _emit(const InviteFlowMissing());
      }
      return;
    }
    final int fingerprint = Object.hash(token, shortCode);
    if (_credentialFingerprint != fingerprint) {
      _credentialFingerprint = fingerprint;
      _acceptId = null;
      _acceptSetActive = null;
    }
    _emit(const InviteFlowLoading());
    final PreviewHouseholdInviteResult result;
    try {
      result = token != null
          ? await _repository.previewInvite(token)
          : await _repository.previewInviteByShortCode(shortCode!);
    } on Object {
      if (_isCurrent(revision)) {
        _emit(
          const InviteFlowFailed(InviteFailure(InviteFailureKind.internal)),
        );
      }
      return;
    }
    if (!_isCurrent(revision)) {
      return;
    }
    switch (result) {
      case HouseholdInvitePreviewed(:final preview):
        _emit(InviteFlowPreviewReady(preview));
      case PreviewHouseholdInviteFailed(:final failure):
        if (_isTerminal(failure)) {
          _pendingInviteStore.clear();
          _credentialFingerprint = null;
        }
        _emit(InviteFlowFailed(failure));
    }
  }

  Future<void> accept({required bool setActiveHousehold}) {
    final bool hasPreview =
        _state is InviteFlowPreviewReady ||
        _state is InviteFlowFailed &&
            (_state as InviteFlowFailed).preview != null;
    if (_disposed || _busyRevision == _operationRevision || !hasPreview) {
      return _pending;
    }
    return _startOperation(
      (int revision) =>
          _accept(revision: revision, setActiveHousehold: setActiveHousehold),
    );
  }

  Future<void> _accept({
    required int revision,
    required bool setActiveHousehold,
  }) async {
    final InviteToken? token = _pendingInviteStore.read();
    final InviteShortCode? shortCode = _pendingInviteStore.readShortCode();
    final InviteFlowState current = _state;
    final preview = switch (current) {
      InviteFlowPreviewReady(:final preview) => preview,
      InviteFlowFailed(:final preview?) => preview,
      _ => null,
    };
    if ((token == null && shortCode == null ||
            token != null && shortCode != null) ||
        preview == null) {
      if (_isCurrent(revision)) {
        _emit(const InviteFlowMissing());
      }
      return;
    }
    if (_acceptId == null || _acceptSetActive != setActiveHousehold) {
      _acceptId = _idGenerator.generate();
      _acceptSetActive = setActiveHousehold;
    }
    _emit(InviteFlowAccepting(preview));
    final AcceptHouseholdInviteResult result;
    try {
      result = token != null
          ? await _repository.acceptInvite(
              AcceptHouseholdInviteRequest(
                idempotencyKey: _acceptId!,
                token: token,
                setActiveHousehold: setActiveHousehold,
              ),
            )
          : await _repository.acceptInviteByShortCode(
              AcceptHouseholdInviteByShortCodeRequest(
                idempotencyKey: _acceptId!,
                shortCode: shortCode!,
                setActiveHousehold: setActiveHousehold,
              ),
            );
    } on Object {
      if (_isCurrent(revision)) {
        _emit(
          InviteFlowFailed(
            const InviteFailure(InviteFailureKind.internal),
            preview: preview,
          ),
        );
      }
      return;
    }
    if (!_isCurrent(revision)) {
      return;
    }
    switch (result) {
      case HouseholdInviteAccepted(:final acceptance):
        _pendingInviteStore.clear();
        _credentialFingerprint = null;
        _emit(InviteFlowAccepted(acceptance));
      case AcceptHouseholdInviteFailed(:final failure):
        if (_isTerminal(failure)) {
          _pendingInviteStore.clear();
          _credentialFingerprint = null;
        }
        _emit(InviteFlowFailed(failure, preview: preview));
    }
  }

  void clear() {
    if (_disposed) {
      return;
    }
    _advanceOperationRevision();
    _pendingInviteStore.clear();
    _emit(const InviteFlowMissing());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _operationRevision += 1;
    _busyRevision = null;
    await Future.wait<void>(List<Future<void>>.of(_operations));
    await _states.close();
  }

  Future<void> _startOperation(
    Future<void> Function(int revision) operationBody,
  ) {
    final int revision = _operationRevision;
    _busyRevision = revision;
    late final Future<void> operation;
    operation = operationBody(revision).whenComplete(() {
      _operations.remove(operation);
      if (_operationRevision == revision && _busyRevision == revision) {
        _busyRevision = null;
      }
    });
    _operations.add(operation);
    _pending = operation;
    return operation;
  }

  void _advanceOperationRevision() {
    _operationRevision += 1;
    _busyRevision = null;
    _pending = Future<void>.value();
    _credentialFingerprint = null;
    _acceptId = null;
    _acceptSetActive = null;
  }

  bool _isCurrent(int revision) {
    return !_disposed && _operationRevision == revision;
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
