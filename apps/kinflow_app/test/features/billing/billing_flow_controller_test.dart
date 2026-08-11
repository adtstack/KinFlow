import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_controller.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_state.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_confirmation_delay.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/billing_assignment_repository.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  group('BillingFlowController', () {
    test(
      'binds exact identity and loads server state before catalog',
      () async {
        final _Harness harness = _Harness(
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
          ],
        );

        await harness.controller.synchronize(
          userId: _userOne,
          householdId: _householdOne,
        );

        expect(harness.controller.state, isA<BillingFlowReady>());
        final BillingFlowSnapshot snapshot = harness.controller.state.snapshot!;
        expect(snapshot.context.userId, _userOne);
        expect(snapshot.context.householdId, _householdOne);
        expect(snapshot.entitlement.hasPlus, isFalse);
        expect(harness.port.boundUserIds, <AuthUserId>[_userOne]);
        expect(harness.port.catalogLoadCount, 1);
        expect(harness.repository.loadedHouseholds, <HouseholdId>[
          _householdOne,
        ]);

        await harness.dispose();
      },
    );

    test('unsupported store preserves the server entitlement', () async {
      final _Harness unsupported = _Harness(portAvailable: false);
      await unsupported.controller.synchronize(
        userId: _userOne,
        householdId: _householdOne,
      );
      final BillingFlowReady ready =
          unsupported.controller.state as BillingFlowReady;
      expect(ready.snapshot.entitlement.hasPlus, isFalse);
      expect(ready.snapshot.catalog, isNull);
      expect(
        ready.snapshot.catalogFailure!.kind,
        BillingFailureKind.unsupported,
      );
      expect(ready.snapshot.canPurchase, isFalse);
      expect(unsupported.port.boundUserIds, isEmpty);
      expect(unsupported.port.catalogLoadCount, 0);

      await unsupported.controller.restore();

      final BillingFlowReady afterRestore =
          unsupported.controller.state as BillingFlowReady;
      expect(afterRestore.actionFailure!.kind, BillingFailureKind.unsupported);
      expect(unsupported.port.restoreContexts, isEmpty);
      await unsupported.dispose();
    });

    test('mismatched provider identity fails before catalog load', () async {
      final _Harness mismatch = _Harness(
        identityResult: BillingIdentityBound(_userTwo),
      );
      await mismatch.controller.synchronize(
        userId: _userOne,
        householdId: _householdOne,
      );
      expect(
        (mismatch.controller.state as BillingFlowFailed).failure.kind,
        BillingFailureKind.identityConflict,
      );
      expect(mismatch.port.catalogLoadCount, 0);
      await mismatch.dispose();
    });

    test('catalog failure preserves status and disables purchase', () async {
      final _Harness harness = _Harness(
        catalogResult: const BillingCatalogFailed(
          BillingFailure(BillingFailureKind.networkUnavailable),
        ),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );

      await harness.ready();

      final BillingFlowReady initial =
          harness.controller.state as BillingFlowReady;
      expect(initial.snapshot.entitlement.hasPlus, isFalse);
      expect(initial.snapshot.catalog, isNull);
      expect(initial.snapshot.canPurchase, isFalse);
      expect(
        initial.snapshot.catalogFailure!.kind,
        BillingFailureKind.networkUnavailable,
      );

      await harness.controller.purchase(_monthly.id);

      final BillingFlowReady afterPurchase =
          harness.controller.state as BillingFlowReady;
      expect(
        afterPurchase.actionFailure!.kind,
        BillingFailureKind.networkUnavailable,
      );
      expect(harness.port.purchaseRequests, isEmpty);
      await harness.dispose();
    });

    test(
      'purchase stays pending until a newer server Plus owner state arrives',
      () async {
        final _Harness harness = _Harness(
          policyDelays: const <Duration>[
            Duration(seconds: 1),
            Duration(seconds: 2),
          ],
          purchaseResult: const BillingPurchaseStoreSucceeded(),
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            const EntitlementFailed<HouseholdEntitlement>(
              EntitlementFailure(EntitlementFailureKind.temporarilyUnavailable),
            ),
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(
              _plus(version: 2, owner: true),
            ),
          ],
        );
        final List<BillingFlowState> emitted = <BillingFlowState>[];
        final StreamSubscription<BillingFlowState> subscription = harness
            .controller
            .states
            .listen(emitted.add);
        await harness.ready();

        await harness.controller.purchase(_monthly.id);

        expect(harness.port.purchaseRequests, hasLength(1));
        expect(harness.port.purchaseRequests.single.context.userId, _userOne);
        expect(
          harness.port.purchaseRequests.single.context.householdId,
          _householdOne,
        );
        expect(
          emitted.whereType<BillingServerConfirmationPendingState>(),
          isNotEmpty,
        );
        expect(harness.delay.waits, const <Duration>[
          Duration(seconds: 1),
          Duration(seconds: 2),
        ]);
        final BillingFlowReady ready =
            harness.controller.state as BillingFlowReady;
        expect(ready.snapshot.entitlement.hasPlus, isTrue);
        expect(ready.snapshot.entitlement.isBillingOwner, isTrue);
        expect(ready.notice, BillingReadyNotice.purchaseServerConfirmed);

        await subscription.cancel();
        await harness.dispose();
      },
    );

    test(
      'purchase timeout remains pending and explicit refresh recovers',
      () async {
        final _Harness harness = _Harness(
          policyDelays: const <Duration>[Duration(seconds: 1)],
          purchaseResult: const BillingPurchaseStoreSucceeded(),
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(
              _plus(version: 2, owner: true),
            ),
          ],
        );
        await harness.ready();

        await harness.controller.purchase(_monthly.id);

        final BillingServerConfirmationPendingState pending =
            harness.controller.state as BillingServerConfirmationPendingState;
        expect(pending.attemptsCompleted, 2);
        expect(pending.snapshot.entitlement.hasPlus, isFalse);
        expect(harness.port.purchaseRequests, hasLength(1));

        await harness.controller.refreshServerStatus();

        final BillingFlowReady ready =
            harness.controller.state as BillingFlowReady;
        expect(ready.notice, BillingReadyNotice.purchaseServerConfirmed);
        expect(ready.snapshot.entitlement.hasPlus, isTrue);
        expect(harness.port.purchaseRequests, hasLength(1));

        await harness.dispose();
      },
    );

    test('purchase refresh requires a newer server entitlement', () async {
      final _Harness harness = _Harness(
        purchaseResult: const BillingPurchaseStoreSucceeded(),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
          EntitlementSucceeded<HouseholdEntitlement>(_plus()),
          EntitlementSucceeded<HouseholdEntitlement>(_plus(version: 2)),
        ],
      );
      await harness.ready();
      await harness.controller.purchase(_monthly.id);

      await harness.controller.refreshServerStatus();

      final BillingServerConfirmationPendingState stillPending =
          harness.controller.state as BillingServerConfirmationPendingState;
      expect(stillPending.snapshot.entitlement.hasPlus, isTrue);
      expect(stillPending.snapshot.entitlement.version, 1);

      await harness.controller.refreshServerStatus();

      final BillingFlowReady ready =
          harness.controller.state as BillingFlowReady;
      expect(ready.notice, BillingReadyNotice.purchaseServerConfirmed);
      expect(ready.snapshot.entitlement.version, 2);
      expect(harness.port.purchaseRequests, hasLength(1));
      await harness.dispose();
    });

    test('server Plus owned by another identity becomes conflict', () async {
      final _Harness harness = _Harness(
        purchaseResult: const BillingPurchaseStoreSucceeded(),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
          EntitlementSucceeded<HouseholdEntitlement>(
            _plus(version: 2, owner: false),
          ),
        ],
      );
      await harness.ready();

      await harness.controller.purchase(_monthly.id);

      final BillingFlowFailed failed =
          harness.controller.state as BillingFlowFailed;
      expect(failed.failure.kind, BillingFailureKind.identityConflict);
      expect(failed.snapshot!.entitlement.hasPlus, isTrue);
      expect(failed.snapshot!.entitlement.isBillingOwner, isFalse);

      await harness.dispose();
    });

    test('cancel and store pending remain non-authoritative states', () async {
      final _Harness cancelled = _Harness(
        purchaseResult: const BillingPurchaseCancelled(),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await cancelled.ready();
      await cancelled.controller.purchase(_monthly.id);
      final BillingFlowReady cancelledState =
          cancelled.controller.state as BillingFlowReady;
      expect(cancelledState.notice, BillingReadyNotice.purchaseCancelled);
      expect(cancelledState.snapshot.entitlement.hasPlus, isFalse);
      expect(cancelled.assignmentRepository.prepareCalls, hasLength(1));
      expect(cancelled.assignmentRepository.releaseCalls, hasLength(1));
      await cancelled.dispose();

      final _Harness pending = _Harness(
        purchaseResult: const BillingPurchasePending(),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await pending.ready();
      await pending.controller.purchase(_monthly.id);
      final BillingStorePendingState pendingState =
          pending.controller.state as BillingStorePendingState;
      expect(pendingState.operation, BillingOperationKind.purchase);
      expect(pendingState.snapshot.entitlement.hasPlus, isFalse);
      expect(pending.assignmentRepository.prepareCalls, hasLength(1));
      expect(pending.assignmentRepository.releaseCalls, isEmpty);
      await pending.dispose();
    });

    test('assignment preflight completes before the Store purchase', () async {
      late _Harness harness;
      harness = _Harness(
        purchaseCallback: (BillingPurchaseRequest _) async {
          expect(harness.assignmentRepository.prepareCalls, hasLength(1));
          expect(
            harness.assignmentRepository.prepareCalls.single.$1,
            _householdOne,
          );
          return const BillingPurchaseCancelled();
        },
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();

      await harness.controller.purchase(_monthly.id);

      expect(harness.port.purchaseRequests, hasLength(1));
      expect(harness.assignmentRepository.releaseCalls, hasLength(1));
      await harness.dispose();
    });

    test('assignment conflicts never call the Store', () async {
      for (final BillingAssignmentPrepareOutcome outcome
          in <BillingAssignmentPrepareOutcome>[
            BillingAssignmentPrepareOutcome.customerConflict,
            BillingAssignmentPrepareOutcome.householdConflict,
          ]) {
        final _Harness harness = _Harness(
          assignmentPrepareResult:
              BillingAssignmentSucceeded<BillingAssignmentPreparation>(
                _preparation(outcome: outcome),
              ),
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
          ],
        );
        await harness.ready();

        await harness.controller.purchase(_monthly.id);

        final BillingAssignmentConflictState conflict =
            harness.controller.state as BillingAssignmentConflictState;
        expect(
          conflict.issue,
          outcome == BillingAssignmentPrepareOutcome.customerConflict
              ? BillingAssignmentRemediationIssue.customerConflict
              : BillingAssignmentRemediationIssue.householdConflict,
        );
        expect(harness.port.purchaseRequests, isEmpty);
        expect(harness.assignmentRepository.releaseCalls, isEmpty);
        await harness.dispose();
      }
    });

    test('assignment conflict creates a support remediation request', () async {
      final _Harness harness = _Harness(
        assignmentPrepareResult:
            BillingAssignmentSucceeded<BillingAssignmentPreparation>(
              _preparation(
                outcome: BillingAssignmentPrepareOutcome.customerConflict,
              ),
            ),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();
      await harness.controller.purchase(_monthly.id);

      await harness.controller.requestAssignmentRemediation();

      final BillingAssignmentConflictState conflict =
          harness.controller.state as BillingAssignmentConflictState;
      expect(
        conflict.remediationRequest?.status,
        BillingAssignmentRemediationStatus.open,
      );
      expect(conflict.remediationFailure, isNull);
      expect(harness.assignmentRepository.remediationCalls, hasLength(1));
      expect(
        harness.assignmentRepository.remediationCalls.single.$2,
        BillingAssignmentRemediationIssue.customerConflict,
      );
      expect(harness.port.purchaseRequests, isEmpty);
      await harness.dispose();
    });

    test(
      'household switch invalidates an in-flight assignment preflight',
      () async {
        final Completer<BillingAssignmentResult<BillingAssignmentPreparation>>
        preparation =
            Completer<BillingAssignmentResult<BillingAssignmentPreparation>>();
        final _Harness harness = _Harness(
          assignmentPrepareCallback: (_, _) => preparation.future,
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(
              _free(householdId: _householdTwo),
            ),
          ],
        );
        await harness.ready();

        final Future<void> purchase = harness.controller.purchase(_monthly.id);
        await _drain();
        expect(
          harness.controller.state,
          isA<BillingAssignmentPreparingState>(),
        );
        final Future<void> switchHousehold = harness.controller.synchronize(
          userId: _userOne,
          householdId: _householdTwo,
        );
        preparation.complete(
          BillingAssignmentSucceeded<BillingAssignmentPreparation>(
            _preparation(),
          ),
        );
        await purchase;
        await switchHousehold;

        expect(harness.port.purchaseRequests, isEmpty);
        expect(
          harness.controller.state.snapshot?.context.householdId,
          _householdTwo,
        );
        await harness.dispose();
      },
    );

    test(
      'purchase failures preserve retryability without granting Plus',
      () async {
        final List<(BillingFailureKind, bool)> cases =
            <(BillingFailureKind, bool)>[
              (BillingFailureKind.networkUnavailable, true),
              (BillingFailureKind.providerRejected, false),
            ];
        for (final (BillingFailureKind kind, bool canRetry) in cases) {
          final _Harness harness = _Harness(
            purchaseResult: BillingPurchaseFailed(BillingFailure(kind)),
            entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
              EntitlementSucceeded<HouseholdEntitlement>(_free()),
            ],
          );
          await harness.ready();

          await harness.controller.purchase(_monthly.id);

          final BillingFlowFailed failed =
              harness.controller.state as BillingFlowFailed;
          expect(failed.failure.kind, kind);
          expect(failed.failure.canRetry, canRetry);
          expect(failed.operation, BillingOperationKind.purchase);
          expect(failed.snapshot!.entitlement.hasPlus, isFalse);
          expect(harness.port.purchaseRequests, hasLength(1));
          await harness.dispose();
        }
      },
    );

    test('duplicate purchase tap coalesces to one provider call', () async {
      final Completer<BillingPurchaseResult> purchase =
          Completer<BillingPurchaseResult>();
      final _Harness harness = _Harness(
        purchaseCallback: (_) => purchase.future,
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();

      final Future<void> first = harness.controller.purchase(_monthly.id);
      final Future<void> second = harness.controller.purchase(_monthly.id);
      await _drain();
      expect(harness.port.purchaseRequests, hasLength(1));

      purchase.complete(const BillingPurchaseCancelled());
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(harness.port.purchaseRequests, hasLength(1));

      await harness.dispose();
    });

    test(
      'already Plus blocks duplicate purchase at the port boundary',
      () async {
        final _Harness harness = _Harness(
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_plus()),
          ],
        );
        await harness.ready();

        await harness.controller.purchase(_monthly.id);

        expect(harness.port.purchaseRequests, isEmpty);
        final BillingFlowReady ready =
            harness.controller.state as BillingFlowReady;
        expect(ready.notice, BillingReadyNotice.alreadyActive);
        await harness.dispose();
      },
    );

    test('restore empty conflict pending and found stay distinct', () async {
      final List<(BillingRestoreResult, Type)> cases =
          <(BillingRestoreResult, Type)>[
            (const BillingRestoreEmpty(), BillingRestoreEmptyState),
            (const BillingRestoreConflict(), BillingRestoreConflictState),
            (const BillingRestorePending(), BillingStorePendingState),
          ];
      for (final (BillingRestoreResult result, Type expectedType) in cases) {
        final _Harness harness = _Harness(
          restoreResult: result,
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
          ],
        );
        await harness.ready();
        await harness.controller.restore();
        expect(harness.controller.state.runtimeType, expectedType);
        expect(harness.port.restoreContexts, <BillingOperationContext>[
          BillingOperationContext(userId: _userOne, householdId: _householdOne),
        ]);
        if (result is BillingRestoreEmpty || result is BillingRestoreConflict) {
          expect(harness.assignmentRepository.releaseCalls, hasLength(1));
        } else {
          expect(harness.assignmentRepository.releaseCalls, isEmpty);
        }
        await harness.dispose();
      }

      final _Harness found = _Harness(
        restoreResult: const BillingRestoreStoreRecordsFound(),
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_plus()),
          EntitlementSucceeded<HouseholdEntitlement>(_plus()),
        ],
      );
      await found.ready();
      await found.controller.restore();
      final BillingFlowReady ready = found.controller.state as BillingFlowReady;
      expect(ready.notice, BillingReadyNotice.restoreServerConfirmed);
      await found.dispose();
    });

    test('duplicate restore tap coalesces to one provider call', () async {
      final Completer<BillingRestoreResult> restore =
          Completer<BillingRestoreResult>();
      final _Harness harness = _Harness(
        restoreCallback: (_) => restore.future,
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();

      final Future<void> first = harness.controller.restore();
      final Future<void> second = harness.controller.restore();
      await _drain();
      expect(harness.port.restoreContexts, hasLength(1));

      restore.complete(const BillingRestoreEmpty());
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(harness.port.restoreContexts, hasLength(1));
      await harness.dispose();
    });

    test(
      'account switch invalidates in-flight completion before rebind',
      () async {
        final Completer<BillingPurchaseResult> purchase =
            Completer<BillingPurchaseResult>();
        final _Harness harness = _Harness(
          purchaseCallback: (_) => purchase.future,
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(
              _free(householdId: _householdTwo),
            ),
          ],
        );
        await harness.ready();

        final Future<void> oldPurchase = harness.controller.purchase(
          _monthly.id,
        );
        await _drain();
        final Future<void> switchAccount = harness.controller.synchronize(
          userId: _userTwo,
          householdId: _householdTwo,
        );
        purchase.complete(const BillingPurchaseCancelled());
        await oldPurchase;
        await switchAccount;

        final BillingFlowReady ready =
            harness.controller.state as BillingFlowReady;
        expect(ready.snapshot.context.userId, _userTwo);
        expect(ready.snapshot.context.householdId, _householdTwo);
        expect(ready.notice, isNull);
        expect(harness.port.clearCount, 1);
        expect(harness.port.boundUserIds, <AuthUserId>[_userOne, _userTwo]);

        await harness.dispose();
      },
    );

    test('identity clear failure blocks a new account bind', () async {
      final _Harness harness = _Harness(
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();
      harness.port.clearResult = const BillingIdentityClearFailed();

      await harness.controller.synchronize(
        userId: _userTwo,
        householdId: _householdTwo,
      );

      final BillingFlowFailed failed =
          harness.controller.state as BillingFlowFailed;
      expect(failed.failure.kind, BillingFailureKind.identityClearFailed);
      expect(harness.port.boundUserIds, <AuthUserId>[_userOne]);
      expect(harness.port.catalogLoadCount, 1);
      await harness.dispose();
    });

    test(
      'same user household switch reuses identity and reloads scope',
      () async {
        final _Harness harness = _Harness(
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(
              _plus(householdId: _householdTwo),
            ),
          ],
        );
        await harness.ready();

        await harness.controller.synchronize(
          userId: _userOne,
          householdId: _householdTwo,
        );

        final BillingFlowReady ready =
            harness.controller.state as BillingFlowReady;
        expect(ready.snapshot.context.userId, _userOne);
        expect(ready.snapshot.context.householdId, _householdTwo);
        expect(ready.snapshot.entitlement.householdId, _householdTwo);
        expect(ready.snapshot.entitlement.hasPlus, isTrue);
        expect(harness.port.boundUserIds, <AuthUserId>[_userOne]);
        expect(harness.port.clearCount, 0);
        expect(harness.port.catalogLoadCount, 2);
        await harness.dispose();
      },
    );

    test('logout clears provider identity and returns to initial', () async {
      final _Harness harness = _Harness(
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();

      await harness.controller.synchronize(userId: null, householdId: null);

      expect(harness.controller.state, isA<BillingFlowInitial>());
      expect(harness.port.clearCount, 1);
      await harness.dispose();
    });

    test(
      'client snapshot only triggers a server-authoritative refetch',
      () async {
        final _Harness harness = _Harness(
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
            EntitlementSucceeded<HouseholdEntitlement>(_plus(version: 2)),
          ],
        );
        await harness.ready();

        harness.port.emitSnapshot(_userOne);
        await _drain();
        expect(harness.controller.state.snapshot!.entitlement.hasPlus, isFalse);

        harness.port.emitSnapshot(_userOne);
        await _drain();
        expect(harness.controller.state.snapshot!.entitlement.hasPlus, isTrue);
        expect(harness.repository.loadedHouseholds, hasLength(3));
        await harness.dispose();
      },
    );

    test(
      'mismatched client snapshot fails closed and clears identity',
      () async {
        final _Harness harness = _Harness(
          entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
            EntitlementSucceeded<HouseholdEntitlement>(_free()),
          ],
        );
        await harness.ready();

        harness.port.emitSnapshot(_userTwo);
        await _drain();

        final BillingFlowFailed failed =
            harness.controller.state as BillingFlowFailed;
        expect(failed.failure.kind, BillingFailureKind.identityConflict);
        expect(harness.port.clearCount, 1);
        await harness.dispose();
      },
    );

    test('dispose invalidates an in-flight provider completion', () async {
      final Completer<BillingPurchaseResult> purchase =
          Completer<BillingPurchaseResult>();
      final _Harness harness = _Harness(
        purchaseCallback: (_) => purchase.future,
        entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
          EntitlementSucceeded<HouseholdEntitlement>(_free()),
        ],
      );
      await harness.ready();

      final Future<void> action = harness.controller.purchase(_monthly.id);
      await _drain();
      expect(harness.controller.state, isA<BillingFlowPurchasing>());

      await harness.controller.dispose();
      purchase.complete(const BillingPurchaseStoreSucceeded());
      await action;

      expect(harness.controller.state, isA<BillingFlowPurchasing>());
      expect(harness.repository.loadedHouseholds, hasLength(1));
      await harness.dispose();
    });
  });
}

final AuthUserId _userOne = AuthUserId.tryParse(
  '10000000-0000-4000-8000-000000000101',
)!;
final AuthUserId _userTwo = AuthUserId.tryParse(
  '10000000-0000-4000-8000-000000000102',
)!;
final HouseholdId _householdOne = HouseholdId.tryParse(
  '20000000-0000-4000-8000-000000000101',
)!;
final HouseholdId _householdTwo = HouseholdId.tryParse(
  '20000000-0000-4000-8000-000000000102',
)!;
final BillingPackage _monthly = BillingPackage.tryCreate(
  id: r'$rc_monthly',
  productId: 'kinflow.plus.monthly',
  localizedPrice: '₩4,900',
  periodCount: 1,
  periodUnit: BillingPeriodUnit.month,
)!;

BillingCatalog _catalog() {
  return BillingCatalog.tryCreate(
    currentOfferingId: 'current',
    offerings: <StoreOffering>[
      StoreOffering.tryCreate(
        id: 'current',
        packages: <BillingPackage>[_monthly],
      )!,
    ],
  )!;
}

HouseholdEntitlement _free({HouseholdId? householdId}) {
  return HouseholdEntitlement.tryCreate(
    householdId: householdId ?? _householdOne,
    entitlementKey: 'plus',
    plan: EntitlementPlan.free,
    status: HouseholdEntitlementStatus.none,
    source: EntitlementSource.none,
    currentPeriodEnd: null,
    willRenew: false,
    featureLimits: const <String, int>{},
    limitsFinalized: false,
    verifiedAt: DateTime.parse('2026-08-08T00:00:00Z'),
    version: 1,
    isBillingOwner: false,
  )!;
}

HouseholdEntitlement _plus({
  HouseholdId? householdId,
  int version = 1,
  bool owner = true,
}) {
  return HouseholdEntitlement.tryCreate(
    householdId: householdId ?? _householdOne,
    entitlementKey: 'plus',
    plan: EntitlementPlan.plus,
    status: HouseholdEntitlementStatus.active,
    source: EntitlementSource.playStore,
    currentPeriodEnd: DateTime.parse('2026-09-08T00:00:00Z'),
    willRenew: true,
    featureLimits: const <String, int>{'members': 10},
    limitsFinalized: true,
    verifiedAt: DateTime.parse(
      version > 1 ? '2026-08-08T00:01:00Z' : '2026-08-08T00:00:00Z',
    ),
    version: version,
    isBillingOwner: owner,
  )!;
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _Harness {
  _Harness({
    bool portAvailable = true,
    BillingIdentityResult? identityResult,
    BillingCatalogResult? catalogResult,
    BillingPurchaseResult purchaseResult = const BillingPurchaseCancelled(),
    BillingRestoreResult restoreResult = const BillingRestoreEmpty(),
    Future<BillingPurchaseResult> Function(BillingPurchaseRequest request)?
    purchaseCallback,
    Future<BillingRestoreResult> Function(BillingOperationContext context)?
    restoreCallback,
    Future<BillingAssignmentResult<BillingAssignmentPreparation>> Function(
      HouseholdId householdId,
      BillingAssignmentCommandId commandId,
    )?
    assignmentPrepareCallback,
    BillingAssignmentResult<BillingAssignmentPreparation>?
    assignmentPrepareResult,
    BillingAssignmentResult<BillingAssignmentRemediationRequest>?
    remediationResult,
    List<EntitlementResult<HouseholdEntitlement>> entitlementResults =
        const <EntitlementResult<HouseholdEntitlement>>[],
    List<Duration> policyDelays = const <Duration>[],
  }) : port = _FakeBillingPort(
         isAvailable: portAvailable,
         identityResult: identityResult,
         catalogResult: catalogResult,
         purchaseResult: purchaseResult,
         restoreResult: restoreResult,
         purchaseCallback: purchaseCallback,
         restoreCallback: restoreCallback,
       ),
       assignmentRepository = _FakeBillingAssignmentRepository(
         prepareCallback: assignmentPrepareCallback,
         prepareResult: assignmentPrepareResult,
         remediationResult: remediationResult,
       ),
       assignmentCommandIdGenerator =
           _FakeBillingAssignmentCommandIdGenerator(),
       repository = _FakeEntitlementRepository(entitlementResults),
       delay = _FakeConfirmationDelay() {
    controller = BillingFlowController(
      port: port,
      assignmentRepository: assignmentRepository,
      assignmentCommandIdGenerator: assignmentCommandIdGenerator,
      entitlementRepository: repository,
      confirmationDelay: delay,
      confirmationPolicy: BillingConfirmationPolicy.tryCreate(policyDelays)!,
    );
  }

  final _FakeBillingPort port;
  final _FakeBillingAssignmentRepository assignmentRepository;
  final _FakeBillingAssignmentCommandIdGenerator assignmentCommandIdGenerator;
  final _FakeEntitlementRepository repository;
  final _FakeConfirmationDelay delay;
  late final BillingFlowController controller;

  Future<void> ready() {
    return controller.synchronize(userId: _userOne, householdId: _householdOne);
  }

  Future<void> dispose() async {
    await controller.dispose();
    await port.dispose();
  }
}

final class _FakeBillingPort implements BillingPort {
  _FakeBillingPort({
    required this.isAvailable,
    this.identityResult,
    BillingCatalogResult? catalogResult,
    required this.purchaseResult,
    required this.restoreResult,
    this.purchaseCallback,
    this.restoreCallback,
  }) : catalogResult = catalogResult ?? BillingCatalogLoaded(_catalog());

  @override
  final bool isAvailable;
  final BillingIdentityResult? identityResult;
  final BillingCatalogResult catalogResult;
  final BillingPurchaseResult purchaseResult;
  final BillingRestoreResult restoreResult;
  final Future<BillingPurchaseResult> Function(BillingPurchaseRequest request)?
  purchaseCallback;
  final Future<BillingRestoreResult> Function(BillingOperationContext context)?
  restoreCallback;
  final StreamController<BillingClientSnapshot> _snapshots =
      StreamController<BillingClientSnapshot>.broadcast(sync: true);
  final List<AuthUserId> boundUserIds = <AuthUserId>[];
  final List<BillingPurchaseRequest> purchaseRequests =
      <BillingPurchaseRequest>[];
  final List<BillingOperationContext> restoreContexts =
      <BillingOperationContext>[];
  BillingIdentityClearResult clearResult = const BillingIdentityCleared();
  var catalogLoadCount = 0;
  var clearCount = 0;

  @override
  Stream<BillingClientSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<BillingIdentityResult> bindIdentity(AuthUserId userId) async {
    boundUserIds.add(userId);
    return identityResult ?? BillingIdentityBound(userId);
  }

  @override
  Future<BillingCatalogResult> loadCatalog() async {
    catalogLoadCount += 1;
    return catalogResult;
  }

  @override
  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request) async {
    purchaseRequests.add(request);
    final callback = purchaseCallback;
    return callback == null ? purchaseResult : callback(request);
  }

  @override
  Future<BillingRestoreResult> restore(BillingOperationContext context) async {
    restoreContexts.add(context);
    final callback = restoreCallback;
    return callback == null ? restoreResult : callback(context);
  }

  @override
  Future<BillingIdentityClearResult> clearIdentity() async {
    clearCount += 1;
    return clearResult;
  }

  void emitSnapshot(AuthUserId? userId) {
    _snapshots.add(
      BillingClientSnapshot.tryCreate(
        boundUserId: userId,
        change: BillingClientChange.storeStateChanged,
        observedAt: DateTime.parse('2026-08-08T00:00:00Z'),
      )!,
    );
  }

  Future<void> dispose() => _snapshots.close();
}

final class _FakeBillingAssignmentRepository
    implements BillingAssignmentRepository {
  _FakeBillingAssignmentRepository({
    this.prepareCallback,
    BillingAssignmentResult<BillingAssignmentPreparation>? prepareResult,
    BillingAssignmentResult<BillingAssignmentRemediationRequest>?
    remediationResult,
  }) : prepareResult =
           prepareResult ??
           BillingAssignmentSucceeded<BillingAssignmentPreparation>(
             _preparation(),
           ),
       remediationResult =
           remediationResult ??
           BillingAssignmentSucceeded<BillingAssignmentRemediationRequest>(
             _remediationRequest(),
           );

  final Future<BillingAssignmentResult<BillingAssignmentPreparation>> Function(
    HouseholdId householdId,
    BillingAssignmentCommandId commandId,
  )?
  prepareCallback;
  final BillingAssignmentResult<BillingAssignmentPreparation> prepareResult;
  final BillingAssignmentResult<BillingAssignmentRemediationRequest>
  remediationResult;
  final List<(HouseholdId, BillingAssignmentCommandId)> prepareCalls =
      <(HouseholdId, BillingAssignmentCommandId)>[];
  final List<(HouseholdId, int, BillingAssignmentCommandId)> releaseCalls =
      <(HouseholdId, int, BillingAssignmentCommandId)>[];
  final List<
    (HouseholdId, BillingAssignmentRemediationIssue, BillingAssignmentCommandId)
  >
  remediationCalls =
      <
        (
          HouseholdId,
          BillingAssignmentRemediationIssue,
          BillingAssignmentCommandId,
        )
      >[];

  @override
  Future<BillingAssignmentResult<BillingAssignmentPreparation>> prepare({
    required HouseholdId householdId,
    required BillingAssignmentCommandId commandId,
  }) async {
    prepareCalls.add((householdId, commandId));
    final callback = prepareCallback;
    return callback == null ? prepareResult : callback(householdId, commandId);
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRelease>> release({
    required HouseholdId householdId,
    required int expectedAssignmentVersion,
    required BillingAssignmentCommandId commandId,
  }) async {
    releaseCalls.add((householdId, expectedAssignmentVersion, commandId));
    return BillingAssignmentSucceeded<BillingAssignmentRelease>(
      BillingAssignmentRelease(
        outcome: BillingAssignmentReleaseOutcome.released,
        assignmentVersion: expectedAssignmentVersion + 1,
        duplicate: false,
      ),
    );
  }

  @override
  Future<BillingAssignmentResult<BillingHouseholdAssignmentStatus>> status(
    HouseholdId householdId,
  ) async {
    return BillingAssignmentSucceeded<BillingHouseholdAssignmentStatus>(
      BillingHouseholdAssignmentStatus.tryCreate(
        householdId: householdId,
        assignmentState: BillingAssignmentState.none,
        ownershipState: BillingAssignmentOwnershipState.unassigned,
        ownerMembershipState: BillingAssignmentOwnerMembershipState.none,
        canPrepare: true,
        requiresSupport: false,
        assignmentVersion: null,
        intentExpiresAt: null,
      )!,
    );
  }

  @override
  Future<BillingAssignmentResult<BillingAssignmentRemediationRequest>>
  requestRemediation({
    required HouseholdId householdId,
    required BillingAssignmentRemediationIssue issue,
    required BillingAssignmentCommandId commandId,
  }) async {
    remediationCalls.add((householdId, issue, commandId));
    return remediationResult;
  }
}

final class _FakeBillingAssignmentCommandIdGenerator
    implements BillingAssignmentCommandIdGenerator {
  var _counter = 1;

  @override
  BillingAssignmentCommandId generate() {
    final String suffix = _counter.toString().padLeft(12, '0');
    _counter += 1;
    return BillingAssignmentCommandId.tryParse(
      '86000000-0000-4000-8000-$suffix',
    )!;
  }
}

BillingAssignmentPreparation _preparation({
  BillingAssignmentPrepareOutcome outcome =
      BillingAssignmentPrepareOutcome.ready,
  BillingAssignmentBindingState? bindingState =
      BillingAssignmentBindingState.provisional,
  int? assignmentVersion = 1,
}) {
  final bool ready = outcome.isReady;
  return BillingAssignmentPreparation.tryCreate(
    intentId: '87000000-0000-4000-8000-000000000001',
    outcome: outcome,
    bindingState: ready ? bindingState : null,
    assignmentVersion: ready ? assignmentVersion : null,
    intentExpiresAt:
        ready && bindingState == BillingAssignmentBindingState.provisional
        ? DateTime.parse('2026-08-08T01:00:00Z')
        : null,
    requeuedJobCount: 0,
    duplicate: false,
  )!;
}

BillingAssignmentRemediationRequest _remediationRequest() {
  return BillingAssignmentRemediationRequest.tryCreate(
    requestId: '88000000-0000-4000-8000-000000000001',
    status: BillingAssignmentRemediationStatus.open,
    issue: BillingAssignmentRemediationIssue.customerConflict,
    duplicate: false,
  )!;
}

final class _FakeEntitlementRepository implements EntitlementRepository {
  _FakeEntitlementRepository(
    List<EntitlementResult<HouseholdEntitlement>> results,
  ) : _results = Queue<EntitlementResult<HouseholdEntitlement>>.of(results);

  final Queue<EntitlementResult<HouseholdEntitlement>> _results;
  final List<HouseholdId> loadedHouseholds = <HouseholdId>[];

  @override
  Future<EntitlementResult<HouseholdEntitlement>> load(
    HouseholdId householdId,
  ) async {
    loadedHouseholds.add(householdId);
    if (_results.isEmpty) {
      return EntitlementSucceeded<HouseholdEntitlement>(
        _free(householdId: householdId),
      );
    }
    return _results.removeFirst();
  }
}

final class _FakeConfirmationDelay implements BillingConfirmationDelay {
  final List<Duration> waits = <Duration>[];

  @override
  Future<void> wait(Duration duration) async {
    waits.add(duration);
  }
}
