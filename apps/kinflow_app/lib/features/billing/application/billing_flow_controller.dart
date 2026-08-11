import 'dart:async';

import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_state.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_confirmation_delay.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_assignment_failure.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class BillingFlowController {
  factory BillingFlowController({
    required BillingPort port,
    required BillingAssignmentRepository assignmentRepository,
    required BillingAssignmentCommandIdGenerator assignmentCommandIdGenerator,
    required EntitlementRepository entitlementRepository,
    required BillingConfirmationDelay confirmationDelay,
    required BillingConfirmationPolicy confirmationPolicy,
  }) {
    return BillingFlowController._(
      port,
      assignmentRepository,
      assignmentCommandIdGenerator,
      entitlementRepository,
      confirmationDelay,
      confirmationPolicy,
    );
  }

  BillingFlowController._(
    this._port,
    this._assignmentRepository,
    this._assignmentCommandIdGenerator,
    this._entitlementRepository,
    this._confirmationDelay,
    this._confirmationPolicy,
  ) {
    _snapshotSubscription = _port.snapshots.listen(
      _onClientSnapshot,
      onError: (Object _, StackTrace _) => _onClientSnapshotError(),
    );
  }

  final BillingPort _port;
  final BillingAssignmentRepository _assignmentRepository;
  final BillingAssignmentCommandIdGenerator _assignmentCommandIdGenerator;
  final EntitlementRepository _entitlementRepository;
  final BillingConfirmationDelay _confirmationDelay;
  final BillingConfirmationPolicy _confirmationPolicy;
  final StreamController<BillingFlowState> _states =
      StreamController<BillingFlowState>.broadcast(sync: true);

  late final StreamSubscription<BillingClientSnapshot> _snapshotSubscription;
  BillingFlowState _state = const BillingFlowInitial();
  Future<void> _operationTail = Future<void>.value();
  Future<void> _activeAction = Future<void>.value();
  AuthUserId? _boundUserId;
  var _identityMayBeBound = false;
  var _actionBusy = false;
  var _switching = false;
  var _disposed = false;
  var _generation = 0;

  BillingFlowState get state => _state;

  Stream<BillingFlowState> get states => _states.stream;

  Future<void> synchronize({
    required AuthUserId? userId,
    required HouseholdId? householdId,
  }) {
    if (_disposed) return Future<void>.value();
    final int generation = ++_generation;
    final BillingOperationContext? context =
        userId != null && householdId != null
        ? BillingOperationContext(userId: userId, householdId: householdId)
        : null;
    _switching = true;
    _emit(
      context == null
          ? const BillingFlowInitial()
          : BillingFlowLoading(context),
    );
    return _enqueue(
      () => _synchronize(
        generation: generation,
        userId: userId,
        householdId: householdId,
        context: context,
      ),
    );
  }

  Future<void> purchase(BillingPackageId packageId) {
    if (_disposed || _actionBusy) return _activeAction;
    final BillingFlowState current = _state;
    if (current is! BillingFlowReady) return Future<void>.value();
    final BillingFlowSnapshot snapshot = current.snapshot;
    if (snapshot.entitlement.hasPlus) {
      _emit(
        BillingFlowReady(snapshot, notice: BillingReadyNotice.alreadyActive),
      );
      return Future<void>.value();
    }
    final BillingCatalog? catalog = snapshot.catalog;
    if (catalog == null) {
      _emit(
        BillingFlowReady(
          snapshot,
          actionFailure:
              snapshot.catalogFailure ??
              const BillingFailure(BillingFailureKind.catalogUnavailable),
        ),
      );
      return Future<void>.value();
    }
    final BillingPackage? package = catalog.packageById(packageId);
    if (package == null) {
      _emit(
        BillingFlowReady(
          snapshot,
          actionFailure: const BillingFailure(BillingFailureKind.invalidInput),
        ),
      );
      return Future<void>.value();
    }
    return _startAction(
      () => _purchase(
        generation: _generation,
        snapshot: snapshot,
        package: package,
      ),
    );
  }

  Future<void> restore() {
    if (_disposed || _actionBusy) return _activeAction;
    final BillingFlowState current = _state;
    if (current is! BillingFlowReady) return Future<void>.value();
    if (!_port.isAvailable) {
      _emit(
        BillingFlowReady(
          current.snapshot,
          actionFailure: const BillingFailure(BillingFailureKind.unsupported),
        ),
      );
      return Future<void>.value();
    }
    return _startAction(
      () => _restore(generation: _generation, snapshot: current.snapshot),
    );
  }

  Future<void> requestAssignmentRemediation() {
    if (_disposed || _actionBusy) return _activeAction;
    final BillingFlowState current = _state;
    final BillingFlowSnapshot? snapshot = current.snapshot;
    final BillingAssignmentRemediationIssue? issue = switch (current) {
      BillingAssignmentConflictState(:final issue) => issue,
      BillingRestoreConflictState() =>
        BillingAssignmentRemediationIssue.restoreConflict,
      _ => null,
    };
    if (snapshot == null || issue == null) return Future<void>.value();
    return _startAction(
      () => _requestAssignmentRemediation(
        generation: _generation,
        snapshot: snapshot,
        issue: issue,
        previousState: current,
      ),
    );
  }

  Future<void> refreshServerStatus() {
    if (_disposed || _actionBusy) return _activeAction;
    final BillingFlowSnapshot? snapshot = _state.snapshot;
    if (snapshot == null ||
        _state is BillingFlowPurchasing ||
        _state is BillingFlowRestoring) {
      return Future<void>.value();
    }
    final BillingOperationKind? operation = switch (_state) {
      BillingStorePendingState(:final operation) => operation,
      BillingServerConfirmationPendingState(:final operation) => operation,
      BillingFlowFailed(:final operation) => operation,
      _ => null,
    };
    return _startAction(
      () => _refreshServerStatus(
        generation: _generation,
        snapshot: snapshot,
        operation: operation,
        previousState: _state,
      ),
    );
  }

  void returnToReady() {
    if (_disposed || _actionBusy) return;
    final BillingFlowState current = _state;
    final BillingFlowSnapshot? snapshot = current.snapshot;
    if (snapshot == null ||
        current is BillingFlowPurchasing ||
        current is BillingFlowRestoring ||
        current is BillingStorePendingState ||
        current is BillingServerConfirmationPendingState ||
        current is BillingFlowFailed &&
            (current.failure.kind == BillingFailureKind.identityConflict ||
                current.failure.kind ==
                    BillingFailureKind.identityClearFailed ||
                current.failure.kind == BillingFailureKind.unauthenticated)) {
      return;
    }
    _emit(BillingFlowReady(snapshot));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    await _snapshotSubscription.cancel();
    await _states.close();
  }

  Future<void> _synchronize({
    required int generation,
    required AuthUserId? userId,
    required HouseholdId? householdId,
    required BillingOperationContext? context,
  }) async {
    try {
      final bool incompleteContext = (userId == null) != (householdId == null);
      if (userId == null || householdId == null) {
        if (_identityMayBeBound && !await _clearIdentity()) {
          _fail(
            generation,
            const BillingFailure(BillingFailureKind.identityClearFailed),
          );
          return;
        }
        if (!_isCurrent(generation)) return;
        _emit(
          incompleteContext
              ? const BillingFlowFailed(
                  failure: BillingFailure(BillingFailureKind.invalidInput),
                )
              : const BillingFlowInitial(),
        );
        return;
      }
      final EntitlementResult<HouseholdEntitlement> entitlementResult =
          await _loadEntitlement(context!.householdId);
      if (!_isCurrent(generation)) return;
      final HouseholdEntitlement? entitlement = switch (entitlementResult) {
        EntitlementSucceeded<HouseholdEntitlement>(:final value) => value,
        EntitlementFailed<HouseholdEntitlement>() => null,
      };
      if (entitlement == null) {
        _fail(
          generation,
          _billingFailureForEntitlement(
            (entitlementResult as EntitlementFailed<HouseholdEntitlement>)
                .failure,
          ),
          context: context,
        );
        return;
      }
      BillingFlowSnapshot snapshot = BillingFlowSnapshot(
        context: context,
        catalog: null,
        entitlement: entitlement,
      );
      if (!_port.isAvailable) {
        _emit(
          BillingFlowReady(
            snapshot.withCatalog(
              catalog: null,
              failure: const BillingFailure(BillingFailureKind.unsupported),
            ),
          ),
        );
        return;
      }
      if (_identityMayBeBound && _boundUserId != userId) {
        if (!await _clearIdentity()) {
          _fail(
            generation,
            const BillingFailure(BillingFailureKind.identityClearFailed),
            context: context,
            snapshot: snapshot,
          );
          return;
        }
      }
      if (!_isCurrent(generation)) return;
      if (!_identityMayBeBound) {
        final BillingIdentityResult identityResult;
        try {
          identityResult = await _port.bindIdentity(userId);
        } on Object {
          _fail(
            generation,
            const BillingFailure(BillingFailureKind.storeUnavailable),
            context: context,
            snapshot: snapshot,
          );
          return;
        }
        if (!_isCurrent(generation)) return;
        switch (identityResult) {
          case BillingIdentityBound(:final userId)
              when userId == context.userId:
            _identityMayBeBound = true;
            _boundUserId = userId;
          case BillingIdentityBound():
            _identityMayBeBound = true;
            _boundUserId = null;
            _fail(
              generation,
              const BillingFailure(BillingFailureKind.identityConflict),
              context: context,
              snapshot: snapshot,
            );
            return;
          case BillingIdentityFailed(:final failure):
            if (failure.kind == BillingFailureKind.identityConflict) {
              _identityMayBeBound = true;
              _boundUserId = null;
            }
            _fail(generation, failure, context: context, snapshot: snapshot);
            return;
        }
      }

      final BillingCatalogResult catalogResult;
      try {
        catalogResult = await _port.loadCatalog();
      } on Object {
        _emit(
          BillingFlowReady(
            snapshot.withCatalog(
              catalog: null,
              failure: const BillingFailure(
                BillingFailureKind.catalogUnavailable,
              ),
            ),
          ),
        );
        return;
      }
      if (!_isCurrent(generation)) return;
      switch (catalogResult) {
        case BillingCatalogLoaded(:final catalog):
          snapshot = snapshot.withCatalog(catalog: catalog, failure: null);
          _emit(BillingFlowReady(snapshot));
        case BillingCatalogFailed(:final failure):
          _emit(
            BillingFlowReady(
              snapshot.withCatalog(catalog: null, failure: failure),
            ),
          );
      }
    } on Object {
      _fail(
        generation,
        const BillingFailure(BillingFailureKind.unknown),
        context: context,
      );
    } finally {
      if (_isCurrent(generation)) _switching = false;
    }
  }

  Future<void> _purchase({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingPackage package,
  }) async {
    _emit(
      BillingAssignmentPreparingState(snapshot, BillingOperationKind.purchase),
    );
    final BillingAssignmentPreparation? preparation = await _prepareAssignment(
      generation: generation,
      snapshot: snapshot,
      operation: BillingOperationKind.purchase,
    );
    if (!_isCurrent(generation) || preparation == null) return;
    if (!preparation.outcome.isReady) {
      _emitAssignmentConflict(
        snapshot: snapshot,
        operation: BillingOperationKind.purchase,
        outcome: preparation.outcome,
      );
      return;
    }
    _emit(BillingFlowPurchasing(snapshot, package));
    final BillingPurchaseResult result;
    try {
      result = await _port.purchase(
        BillingPurchaseRequest(context: snapshot.context, package: package),
      );
    } on Object {
      _emitActionFailure(
        generation: generation,
        snapshot: snapshot,
        operation: BillingOperationKind.purchase,
        failure: const BillingFailure(BillingFailureKind.storeUnavailable),
      );
      return;
    }
    if (!_isCurrent(generation)) return;
    switch (result) {
      case BillingPurchaseStoreSucceeded():
        await _confirmServer(
          generation: generation,
          baseline: snapshot,
          operation: BillingOperationKind.purchase,
          allowExistingEntitlement: false,
        );
      case BillingPurchaseCancelled():
        await _releasePreparation(
          generation: generation,
          snapshot: snapshot,
          preparation: preparation,
        );
        if (!_isCurrent(generation)) return;
        _emit(
          BillingFlowReady(
            snapshot,
            notice: BillingReadyNotice.purchaseCancelled,
          ),
        );
      case BillingPurchasePending():
        _emit(
          BillingStorePendingState(snapshot, BillingOperationKind.purchase),
        );
      case BillingPurchaseFailed(:final failure):
        if (!failure.canRetry) {
          await _releasePreparation(
            generation: generation,
            snapshot: snapshot,
            preparation: preparation,
          );
        }
        _emitActionFailure(
          generation: generation,
          snapshot: snapshot,
          operation: BillingOperationKind.purchase,
          failure: failure,
        );
    }
  }

  Future<void> _restore({
    required int generation,
    required BillingFlowSnapshot snapshot,
  }) async {
    _emit(
      BillingAssignmentPreparingState(snapshot, BillingOperationKind.restore),
    );
    final BillingAssignmentPreparation? preparation = await _prepareAssignment(
      generation: generation,
      snapshot: snapshot,
      operation: BillingOperationKind.restore,
    );
    if (!_isCurrent(generation) || preparation == null) return;
    if (!preparation.outcome.isReady) {
      _emitAssignmentConflict(
        snapshot: snapshot,
        operation: BillingOperationKind.restore,
        outcome: preparation.outcome,
      );
      return;
    }
    _emit(BillingFlowRestoring(snapshot));
    final BillingRestoreResult result;
    try {
      result = await _port.restore(snapshot.context);
    } on Object {
      _emitActionFailure(
        generation: generation,
        snapshot: snapshot,
        operation: BillingOperationKind.restore,
        failure: const BillingFailure(BillingFailureKind.storeUnavailable),
      );
      return;
    }
    if (!_isCurrent(generation)) return;
    switch (result) {
      case BillingRestoreStoreRecordsFound():
        await _confirmServer(
          generation: generation,
          baseline: snapshot,
          operation: BillingOperationKind.restore,
          allowExistingEntitlement: true,
        );
      case BillingRestoreEmpty():
        await _releasePreparation(
          generation: generation,
          snapshot: snapshot,
          preparation: preparation,
        );
        if (!_isCurrent(generation)) return;
        _emit(BillingRestoreEmptyState(snapshot));
      case BillingRestoreConflict():
        await _releasePreparation(
          generation: generation,
          snapshot: snapshot,
          preparation: preparation,
        );
        if (!_isCurrent(generation)) return;
        _emit(BillingRestoreConflictState(snapshot));
      case BillingRestorePending():
        _emit(BillingStorePendingState(snapshot, BillingOperationKind.restore));
      case BillingRestoreFailed(:final failure):
        if (!failure.canRetry) {
          await _releasePreparation(
            generation: generation,
            snapshot: snapshot,
            preparation: preparation,
          );
        }
        _emitActionFailure(
          generation: generation,
          snapshot: snapshot,
          operation: BillingOperationKind.restore,
          failure: failure,
        );
    }
  }

  Future<BillingAssignmentPreparation?> _prepareAssignment({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingOperationKind operation,
  }) async {
    final BillingAssignmentResult<BillingAssignmentPreparation> result;
    try {
      result = await _assignmentRepository.prepare(
        householdId: snapshot.context.householdId,
        commandId: _assignmentCommandIdGenerator.generate(),
      );
    } on Object {
      _emitActionFailure(
        generation: generation,
        snapshot: snapshot,
        operation: operation,
        failure: const BillingFailure(BillingFailureKind.serverUnavailable),
      );
      return null;
    }
    if (!_isCurrent(generation)) return null;
    return switch (result) {
      BillingAssignmentSucceeded<BillingAssignmentPreparation>(:final value) =>
        value,
      BillingAssignmentFailed<BillingAssignmentPreparation>(:final failure) =>
        _assignmentPrepareFailure(
          generation: generation,
          snapshot: snapshot,
          operation: operation,
          failure: failure,
        ),
    };
  }

  BillingAssignmentPreparation? _assignmentPrepareFailure({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingOperationKind operation,
    required BillingAssignmentFailure failure,
  }) {
    _emitActionFailure(
      generation: generation,
      snapshot: snapshot,
      operation: operation,
      failure: _billingFailureForAssignment(failure),
    );
    return null;
  }

  void _emitAssignmentConflict({
    required BillingFlowSnapshot snapshot,
    required BillingOperationKind operation,
    required BillingAssignmentPrepareOutcome outcome,
  }) {
    final BillingAssignmentRemediationIssue issue = switch (outcome) {
      BillingAssignmentPrepareOutcome.customerConflict =>
        BillingAssignmentRemediationIssue.customerConflict,
      BillingAssignmentPrepareOutcome.householdConflict =>
        BillingAssignmentRemediationIssue.householdConflict,
      BillingAssignmentPrepareOutcome.ready ||
      BillingAssignmentPrepareOutcome.alreadyReady => throw StateError(
        'Ready assignment cannot be emitted as a conflict.',
      ),
    };
    _emit(
      BillingAssignmentConflictState(
        snapshot: snapshot,
        operation: operation,
        issue: issue,
      ),
    );
  }

  Future<void> _releasePreparation({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingAssignmentPreparation preparation,
  }) async {
    if (preparation.bindingState != BillingAssignmentBindingState.provisional ||
        preparation.assignmentVersion == null ||
        !_isCurrent(generation)) {
      return;
    }
    try {
      await _assignmentRepository.release(
        householdId: snapshot.context.householdId,
        expectedAssignmentVersion: preparation.assignmentVersion!,
        commandId: _assignmentCommandIdGenerator.generate(),
      );
    } on Object {
      // Release is compensation only. The server-side bounded expiry remains
      // authoritative if this best-effort cleanup cannot complete.
    }
  }

  Future<void> _requestAssignmentRemediation({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingAssignmentRemediationIssue issue,
    required BillingFlowState previousState,
  }) async {
    final BillingAssignmentResult<BillingAssignmentRemediationRequest> result;
    try {
      result = await _assignmentRepository.requestRemediation(
        householdId: snapshot.context.householdId,
        issue: issue,
        commandId: _assignmentCommandIdGenerator.generate(),
      );
    } on Object {
      if (_isCurrent(generation)) {
        _emitRemediationResult(
          previousState: previousState,
          request: null,
          failure: const BillingFailure(BillingFailureKind.serverUnavailable),
        );
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    switch (result) {
      case BillingAssignmentSucceeded<BillingAssignmentRemediationRequest>(
        :final value,
      ):
        _emitRemediationResult(
          previousState: previousState,
          request: value,
          failure: null,
        );
      case BillingAssignmentFailed<BillingAssignmentRemediationRequest>(
        :final failure,
      ):
        _emitRemediationResult(
          previousState: previousState,
          request: null,
          failure: _billingFailureForAssignment(failure),
        );
    }
  }

  void _emitRemediationResult({
    required BillingFlowState previousState,
    required BillingAssignmentRemediationRequest? request,
    required BillingFailure? failure,
  }) {
    switch (previousState) {
      case BillingAssignmentConflictState(
        :final snapshot,
        :final operation,
        :final issue,
      ):
        _emit(
          BillingAssignmentConflictState(
            snapshot: snapshot,
            operation: operation,
            issue: issue,
            remediationRequest: request,
            remediationFailure: failure,
          ),
        );
      case BillingRestoreConflictState(:final snapshot):
        _emit(
          BillingRestoreConflictState(
            snapshot,
            remediationRequest: request,
            remediationFailure: failure,
          ),
        );
      default:
        return;
    }
  }

  Future<void> _confirmServer({
    required int generation,
    required BillingFlowSnapshot baseline,
    required BillingOperationKind operation,
    required bool allowExistingEntitlement,
  }) async {
    BillingFlowSnapshot latest = baseline;
    BillingFailure? lastFailure;
    for (
      var attempt = 0;
      attempt < _confirmationPolicy.attempts;
      attempt += 1
    ) {
      if (attempt > 0) {
        try {
          await _confirmationDelay.wait(
            _confirmationPolicy.delays[attempt - 1],
          );
        } on Object {
          lastFailure = const BillingFailure(
            BillingFailureKind.serverUnavailable,
          );
        }
      }
      if (!_isCurrent(generation)) return;
      _emit(
        BillingServerConfirmationPendingState(
          snapshot: latest,
          operation: operation,
          attemptsCompleted: attempt,
          lastFailure: lastFailure,
        ),
      );
      final EntitlementResult<HouseholdEntitlement> result =
          await _loadEntitlement(latest.context.householdId);
      if (!_isCurrent(generation)) return;
      switch (result) {
        case EntitlementSucceeded<HouseholdEntitlement>(:final value):
          latest = latest.withEntitlement(value);
          lastFailure = null;
          if (_isConfirmed(
            value: value,
            baseline: baseline.entitlement,
            allowExisting: allowExistingEntitlement,
          )) {
            _emit(
              BillingFlowReady(
                latest,
                notice: operation == BillingOperationKind.purchase
                    ? BillingReadyNotice.purchaseServerConfirmed
                    : BillingReadyNotice.restoreServerConfirmed,
              ),
            );
            return;
          }
          if (value.hasPlus && !value.isBillingOwner) {
            if (operation == BillingOperationKind.restore) {
              _emit(BillingRestoreConflictState(latest));
            } else {
              _emitActionFailure(
                generation: generation,
                snapshot: latest,
                operation: operation,
                failure: const BillingFailure(
                  BillingFailureKind.identityConflict,
                ),
              );
            }
            return;
          }
        case EntitlementFailed<HouseholdEntitlement>(:final failure):
          lastFailure = _billingFailureForEntitlement(failure);
          if (!lastFailure.canRetry) {
            _emitActionFailure(
              generation: generation,
              snapshot: latest,
              operation: operation,
              failure: lastFailure,
            );
            return;
          }
      }
    }
    _emit(
      BillingServerConfirmationPendingState(
        snapshot: latest,
        operation: operation,
        attemptsCompleted: _confirmationPolicy.attempts,
        lastFailure: lastFailure,
      ),
    );
  }

  Future<void> _refreshServerStatus({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingOperationKind? operation,
    required BillingFlowState previousState,
  }) async {
    final EntitlementResult<HouseholdEntitlement> result =
        await _loadEntitlement(snapshot.context.householdId);
    if (!_isCurrent(generation)) return;
    switch (result) {
      case EntitlementSucceeded<HouseholdEntitlement>(:final value):
        final BillingFlowSnapshot latest = snapshot.withEntitlement(value);
        final bool serverConfirmed =
            operation != null &&
            _isConfirmed(
              value: value,
              baseline: snapshot.entitlement,
              allowExisting: operation == BillingOperationKind.restore,
            );
        if (serverConfirmed) {
          _emit(
            BillingFlowReady(
              latest,
              notice: operation == BillingOperationKind.purchase
                  ? BillingReadyNotice.purchaseServerConfirmed
                  : BillingReadyNotice.restoreServerConfirmed,
            ),
          );
          return;
        }
        if (operation != null && value.hasPlus && !value.isBillingOwner) {
          if (operation == BillingOperationKind.restore) {
            _emit(BillingRestoreConflictState(latest));
          } else {
            _emitActionFailure(
              generation: generation,
              snapshot: latest,
              operation: operation,
              failure: const BillingFailure(
                BillingFailureKind.identityConflict,
              ),
            );
          }
          return;
        }
        _emit(_withRefreshedSnapshot(previousState, latest));
      case EntitlementFailed<HouseholdEntitlement>(:final failure):
        final BillingFailure mapped = _billingFailureForEntitlement(failure);
        if (!mapped.canRetry) {
          _emitActionFailure(
            generation: generation,
            snapshot: snapshot,
            operation: operation,
            failure: mapped,
          );
        } else {
          _emit(_withRefreshFailure(previousState, snapshot, mapped));
        }
    }
  }

  BillingFlowState _withRefreshedSnapshot(
    BillingFlowState previous,
    BillingFlowSnapshot snapshot,
  ) {
    return switch (previous) {
      BillingStorePendingState(:final operation) => BillingStorePendingState(
        snapshot,
        operation,
      ),
      BillingServerConfirmationPendingState(
        :final operation,
        :final attemptsCompleted,
      ) =>
        BillingServerConfirmationPendingState(
          snapshot: snapshot,
          operation: operation,
          attemptsCompleted: attemptsCompleted,
        ),
      BillingRestoreEmptyState() => BillingRestoreEmptyState(snapshot),
      BillingAssignmentConflictState(
        :final operation,
        :final issue,
        :final remediationRequest,
        :final remediationFailure,
      ) =>
        BillingAssignmentConflictState(
          snapshot: snapshot,
          operation: operation,
          issue: issue,
          remediationRequest: remediationRequest,
          remediationFailure: remediationFailure,
        ),
      BillingRestoreConflictState(
        :final remediationRequest,
        :final remediationFailure,
      ) =>
        BillingRestoreConflictState(
          snapshot,
          remediationRequest: remediationRequest,
          remediationFailure: remediationFailure,
        ),
      _ => BillingFlowReady(
        snapshot,
        notice: BillingReadyNotice.serverRefreshed,
      ),
    };
  }

  BillingFlowState _withRefreshFailure(
    BillingFlowState previous,
    BillingFlowSnapshot snapshot,
    BillingFailure failure,
  ) {
    return switch (previous) {
      BillingServerConfirmationPendingState(
        :final operation,
        :final attemptsCompleted,
      ) =>
        BillingServerConfirmationPendingState(
          snapshot: snapshot,
          operation: operation,
          attemptsCompleted: attemptsCompleted,
          lastFailure: failure,
        ),
      BillingStorePendingState(:final operation) =>
        BillingServerConfirmationPendingState(
          snapshot: snapshot,
          operation: operation,
          attemptsCompleted: 0,
          lastFailure: failure,
        ),
      BillingAssignmentConflictState(
        :final operation,
        :final issue,
        :final remediationRequest,
      ) =>
        BillingAssignmentConflictState(
          snapshot: snapshot,
          operation: operation,
          issue: issue,
          remediationRequest: remediationRequest,
          remediationFailure: failure,
        ),
      BillingRestoreConflictState(:final remediationRequest) =>
        BillingRestoreConflictState(
          snapshot,
          remediationRequest: remediationRequest,
          remediationFailure: failure,
        ),
      _ => BillingFlowReady(snapshot, actionFailure: failure),
    };
  }

  Future<EntitlementResult<HouseholdEntitlement>> _loadEntitlement(
    HouseholdId householdId,
  ) async {
    try {
      return await _entitlementRepository.load(householdId);
    } on Object {
      return const EntitlementFailed<HouseholdEntitlement>(
        EntitlementFailure(EntitlementFailureKind.temporarilyUnavailable),
      );
    }
  }

  bool _isConfirmed({
    required HouseholdEntitlement value,
    required HouseholdEntitlement baseline,
    required bool allowExisting,
  }) {
    if (!value.hasPlus || !value.isBillingOwner) return false;
    return allowExisting ||
        value.version > baseline.version ||
        value.verifiedAt.isAfter(baseline.verifiedAt);
  }

  BillingFailure _billingFailureForEntitlement(EntitlementFailure failure) {
    return BillingFailure(switch (failure.kind) {
      EntitlementFailureKind.unauthenticated =>
        BillingFailureKind.unauthenticated,
      EntitlementFailureKind.invalidInput => BillingFailureKind.invalidInput,
      EntitlementFailureKind.notFoundOrForbidden =>
        BillingFailureKind.serverAuthorization,
      EntitlementFailureKind.temporarilyUnavailable =>
        BillingFailureKind.serverUnavailable,
      EntitlementFailureKind.invalidPayload =>
        BillingFailureKind.invalidServerState,
      EntitlementFailureKind.unknown => BillingFailureKind.unknown,
    });
  }

  BillingFailure _billingFailureForAssignment(
    BillingAssignmentFailure failure,
  ) {
    return BillingFailure(switch (failure.kind) {
      BillingAssignmentFailureKind.unauthenticated =>
        BillingFailureKind.unauthenticated,
      BillingAssignmentFailureKind.invalidInput =>
        BillingFailureKind.invalidInput,
      BillingAssignmentFailureKind.authorization =>
        BillingFailureKind.serverAuthorization,
      BillingAssignmentFailureKind.versionConflict ||
      BillingAssignmentFailureKind.invalidPayload =>
        BillingFailureKind.invalidServerState,
      BillingAssignmentFailureKind.temporarilyUnavailable =>
        BillingFailureKind.serverUnavailable,
      BillingAssignmentFailureKind.unknown => BillingFailureKind.unknown,
    });
  }

  Future<bool> _clearIdentity() async {
    final BillingIdentityClearResult result;
    try {
      result = await _port.clearIdentity();
    } on Object {
      return false;
    }
    if (result is! BillingIdentityCleared) return false;
    _identityMayBeBound = false;
    _boundUserId = null;
    return true;
  }

  void _onClientSnapshot(BillingClientSnapshot snapshot) {
    if (_disposed ||
        _switching ||
        _state is BillingFlowInitial ||
        _state is BillingFlowLoading) {
      return;
    }
    final BillingOperationContext? context = _state.context;
    if (context == null) return;
    if (snapshot.boundUserId != context.userId) {
      final int generation = ++_generation;
      _emit(
        BillingFlowFailed(
          failure: const BillingFailure(BillingFailureKind.identityConflict),
          context: context,
          snapshot: _state.snapshot,
        ),
      );
      unawaited(_enqueue(() => _clearAfterIdentityMismatch(generation)));
      return;
    }
    if (!_actionBusy && _state.snapshot != null) {
      unawaited(refreshServerStatus());
    }
  }

  void _onClientSnapshotError() {
    if (_disposed || _switching || _actionBusy) return;
    final BillingFlowSnapshot? snapshot = _state.snapshot;
    if (snapshot == null) return;
    _emit(
      BillingFlowReady(
        snapshot,
        actionFailure: const BillingFailure(
          BillingFailureKind.storeUnavailable,
        ),
      ),
    );
  }

  Future<void> _clearAfterIdentityMismatch(int generation) async {
    if (!await _clearIdentity() && _isCurrent(generation)) {
      _emit(
        BillingFlowFailed(
          failure: const BillingFailure(BillingFailureKind.identityClearFailed),
        ),
      );
    }
  }

  void _emitActionFailure({
    required int generation,
    required BillingFlowSnapshot snapshot,
    required BillingOperationKind? operation,
    required BillingFailure failure,
  }) {
    if (!_isCurrent(generation)) return;
    _emit(
      BillingFlowFailed(
        failure: failure,
        context: snapshot.context,
        snapshot: snapshot,
        operation: operation,
      ),
    );
  }

  void _fail(
    int generation,
    BillingFailure failure, {
    BillingOperationContext? context,
    BillingFlowSnapshot? snapshot,
  }) {
    if (!_isCurrent(generation)) return;
    _emit(
      BillingFlowFailed(failure: failure, context: context, snapshot: snapshot),
    );
  }

  Future<void> _startAction(Future<void> Function() operation) {
    if (_actionBusy || _disposed) return _activeAction;
    _actionBusy = true;
    _activeAction = _enqueue(operation).whenComplete(() => _actionBusy = false);
    return _activeAction;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> run = _operationTail.then((_) => operation());
    _operationTail = run.catchError((Object _, StackTrace _) {});
    return run;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emit(BillingFlowState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }
}
