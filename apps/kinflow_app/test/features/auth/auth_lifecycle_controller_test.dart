import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  group('AuthLifecycleController', () {
    test('restores no session by purging stale local state', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository();
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });

      await controller.start();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(repository.restoreCount, 1);
      expect(purger.purgeCount, 1);
    });

    test(
      'restores a valid session without exposing tokens or purging',
      () async {
        final AuthSession session = authSessionFixture();
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
        );
        final RecordingSensitiveLocalStatePurger purger =
            RecordingSensitiveLocalStatePurger();
        final AuthLifecycleController controller = _controller(
          repository: repository,
          purger: purger,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });

        await controller.start();

        expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
        expect(controller.state.session, session);
        expect(
          controller.state.toString(),
          isNot(contains(session.userId.value)),
        );
        expect(purger.purgeCount, 0);
      },
    );

    test('restores the server-selected active household', () async {
      final AuthSession session = authSessionFixture();
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(session),
      );
      final FakeHouseholdRepository householdRepository =
          FakeHouseholdRepository(
            defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
          );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        householdRepository: householdRepository,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });

      await controller.start();

      expect(controller.state, isA<AuthAuthenticatedActiveHousehold>());
      expect(controller.state.activeHousehold, activeHouseholdFixture());
      expect(householdRepository.loadCount, 1);
    });

    test(
      'restores a cached household with explicit cache provenance',
      () async {
        final AuthSession session = authSessionFixture();
        final ReadCacheMetadata metadata = ReadCacheMetadata(
          validatedAt: DateTime.parse('2026-08-08T01:00:00.000Z'),
          expiresAt: DateTime.parse('2026-08-08T03:00:00.000Z'),
        );
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
        );
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            defaultLoadResult: ActiveHouseholdLoaded(
              activeHouseholdFixture(),
              cacheMetadata: metadata,
            ),
          ),
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });

        await controller.start();

        expect(controller.state, isA<AuthAuthenticatedActiveHousehold>());
        expect(controller.state.activeHouseholdCacheMetadata, metadata);
        expect(controller.state.permitsProtectedRoutes, isTrue);
      },
    );

    test(
      'household activation locks when its local snapshot cannot be replaced',
      () async {
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(authSessionFixture()),
        );
        final _RecordingHouseholdSnapshotWriter writer =
            _RecordingHouseholdSnapshotWriter(result: false);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          activeHouseholdSnapshotWriter: writer,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        await controller.markActiveHousehold(activeHouseholdFixture());

        expect(writer.households, <ActiveHousehold>[activeHouseholdFixture()]);
        expect(controller.state, isA<AuthLocked>());
        expect(
          controller.state.failure?.kind,
          AuthFailureKind.localPurgeFailed,
        );
        expect(controller.state.permitsProtectedRoutes, isFalse);
      },
    );

    test(
      'first explicit selection clears household-bound state before exposure',
      () async {
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(authSessionFixture()),
        );
        final _RecordingHouseholdSnapshotWriter writer =
            _RecordingHouseholdSnapshotWriter(result: true);
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          activeHouseholdSnapshotWriter: writer,
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        final bool committed = await controller.commitActiveHousehold(
          activeHouseholdFixture(),
        );

        expect(committed, isTrue);
        expect(transition.households, <ActiveHousehold>[
          activeHouseholdFixture(),
        ]);
        expect(writer.households, isEmpty);
      },
    );

    test(
      'active household switch uses the isolated local transition',
      () async {
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(authSessionFixture()),
        );
        final ActiveHousehold previous = activeHouseholdFixture();
        final ActiveHousehold next = activeHouseholdFixture(
          householdId: '22222222-2222-4222-8222-222222222223',
          memberId: '33333333-3333-4333-8333-333333333334',
        );
        final _RecordingHouseholdSnapshotWriter writer =
            _RecordingHouseholdSnapshotWriter(result: true);
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            defaultLoadResult: ActiveHouseholdLoaded(previous),
          ),
          activeHouseholdSnapshotWriter: writer,
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        final bool committed = await controller.commitActiveHousehold(next);

        expect(committed, isTrue);
        expect(transition.households, <ActiveHousehold>[next]);
        expect(writer.households, isEmpty);
        expect(controller.state.activeHousehold, next);
      },
    );

    test('failed household transition locks household content', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
      );
      final ActiveHousehold previous = activeHouseholdFixture();
      final ActiveHousehold next = activeHouseholdFixture(
        householdId: '22222222-2222-4222-8222-222222222223',
        memberId: '33333333-3333-4333-8333-333333333334',
      );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        householdRepository: FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(previous),
        ),
        activeHouseholdTransitionLocalState: _RecordingHouseholdTransition(
          result: false,
        ),
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      expect(await controller.commitActiveHousehold(next), isFalse);
      expect(controller.state, isA<AuthLocked>());
      expect(controller.state.failure?.kind, AuthFailureKind.localPurgeFailed);
      expect(controller.state.permitsProtectedRoutes, isFalse);
    });

    test(
      'departure commits the authoritative fallback without another lookup',
      () async {
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(authSessionFixture()),
        );
        final FakeHouseholdRepository householdRepository =
            FakeHouseholdRepository(
              defaultLoadResult: ActiveHouseholdLoaded(
                activeHouseholdFixture(),
              ),
            );
        final ActiveHousehold fallback = activeHouseholdFixture(
          householdId: '22222222-2222-4222-8222-222222222223',
          memberId: '33333333-3333-4333-8333-333333333334',
        );
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: householdRepository,
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        expect(await controller.commitHouseholdDeparture(fallback), isTrue);

        expect(transition.households, <ActiveHousehold>[fallback]);
        expect(transition.clearCount, 0);
        expect(controller.state, isA<AuthAuthenticatedActiveHousehold>());
        expect(controller.state.activeHousehold, fallback);
        expect(householdRepository.loadCount, 1);
      },
    );

    test('departure without fallback commits no-household state', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
      );
      final _RecordingHouseholdTransition transition =
          _RecordingHouseholdTransition(result: true);
      final AuthLifecycleController controller = _controller(
        repository: repository,
        householdRepository: FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
        activeHouseholdTransitionLocalState: transition,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      expect(await controller.commitHouseholdDeparture(null), isTrue);

      expect(transition.households, isEmpty);
      expect(transition.clearCount, 1);
      expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
      expect(controller.state.permitsProtectedRoutes, isTrue);
    });

    test('failed departure clear locks all protected content', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
      );
      final _RecordingHouseholdTransition transition =
          _RecordingHouseholdTransition(result: true, clearResult: false);
      final AuthLifecycleController controller = _controller(
        repository: repository,
        householdRepository: FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
        activeHouseholdTransitionLocalState: transition,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      expect(await controller.commitHouseholdDeparture(null), isFalse);

      expect(transition.clearCount, 1);
      expect(controller.state, isA<AuthLocked>());
      expect(controller.state.failure?.kind, AuthFailureKind.localPurgeFailed);
      expect(controller.state.permitsProtectedRoutes, isFalse);
    });

    test(
      'household lookup failure stays closed until retry succeeds',
      () async {
        final AuthSession session = authSessionFixture();
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
        );
        final FakeHouseholdRepository householdRepository =
            FakeHouseholdRepository(
              loadResults: <LoadActiveHouseholdResult>[
                const LoadActiveHouseholdFailed(
                  HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
                ),
                ActiveHouseholdLoaded(activeHouseholdFixture()),
              ],
            );
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: householdRepository,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });

        await controller.start();

        expect(controller.state, isA<AuthHouseholdResolutionFailed>());
        expect(controller.state.permitsProtectedRoutes, isFalse);
        expect(
          controller.state.householdFailure?.kind,
          HouseholdFailureKind.temporarilyUnavailable,
        );

        await controller.retryHouseholdResolution();

        expect(controller.state, isA<AuthAuthenticatedActiveHousehold>());
        expect(householdRepository.loadCount, 2);
      },
    );

    test('repository exceptions cannot be mistaken for no household', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
      );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        householdRepository: FakeHouseholdRepository(
          loadCallback: () async {
            throw StateError('raw-household-provider-detail');
          },
        ),
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });

      await controller.start();

      expect(controller.state, isA<AuthHouseholdResolutionFailed>());
      expect(
        controller.state.householdFailure?.kind,
        HouseholdFailureKind.internal,
      );
      expect(controller.state, isNot(isA<AuthAuthenticatedNoHousehold>()));
    });

    test('locks when restore cannot safely determine the session', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: const AuthSessionFailed(
          AuthFailure(AuthFailureKind.temporarilyUnavailable),
        ),
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });

      await controller.start();

      expect(controller.state, isA<AuthLocked>());
      expect(controller.state.permitsProtectedRoutes, isFalse);
      expect(
        controller.state.failure?.kind,
        AuthFailureKind.temporarilyUnavailable,
      );
      expect(purger.purgeCount, 1);
    });

    test('refreshes the same user without a purge', () async {
      final AuthSession session = authSessionFixture();
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(session),
        refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      final List<AuthLifecycleState> states = <AuthLifecycleState>[];
      final StreamSubscription<AuthLifecycleState> subscription = controller
          .states
          .listen(states.add);
      addTearDown(() async {
        await subscription.cancel();
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      await controller.refresh();

      expect(states, contains(isA<AuthRefreshing>()));
      expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
      expect(repository.refreshCount, 1);
      expect(purger.purgeCount, 0);
    });

    test(
      'same-household resume revalidation preserves protected context',
      () async {
        final AuthSession session = authSessionFixture();
        final ActiveHousehold household = activeHouseholdFixture();
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
          refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
        );
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            loadResults: <LoadActiveHouseholdResult>[
              ActiveHouseholdLoaded(household),
              ActiveHouseholdLoaded(household),
            ],
          ),
          activeHouseholdTransitionLocalState: transition,
        );
        final List<AuthLifecycleState> states = <AuthLifecycleState>[];
        final StreamSubscription<AuthLifecycleState> subscription = controller
            .states
            .listen(states.add);
        addTearDown(() async {
          await subscription.cancel();
          await controller.dispose();
          await repository.close();
        });
        await controller.start();
        states.clear();

        await controller.revalidateOnResume();

        expect(controller.state.activeHousehold, household);
        expect(states, isEmpty);
        expect(transition.households, isEmpty);
        expect(transition.clearCount, 0);
      },
    );

    test(
      'resume revalidation purges before exposing a household change',
      () async {
        final AuthSession session = authSessionFixture();
        final ActiveHousehold previous = activeHouseholdFixture();
        final ActiveHousehold next = activeHouseholdFixture(
          householdId: '22222222-2222-4222-8222-222222222223',
          memberId: '33333333-3333-4333-8333-333333333334',
        );
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
          refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
        );
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            loadResults: <LoadActiveHouseholdResult>[
              ActiveHouseholdLoaded(previous),
              ActiveHouseholdLoaded(next),
            ],
          ),
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        await controller.revalidateOnResume();

        expect(transition.households, <ActiveHousehold>[next]);
        expect(controller.state, isA<AuthAuthenticatedActiveHousehold>());
        expect(controller.state.activeHousehold, next);
      },
    );

    test(
      'resume revalidation clears local state after remote departure',
      () async {
        final AuthSession session = authSessionFixture();
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
          refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
        );
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            loadResults: <LoadActiveHouseholdResult>[
              ActiveHouseholdLoaded(activeHouseholdFixture()),
              const NoActiveHousehold(),
            ],
          ),
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        await controller.revalidateOnResume();

        expect(transition.clearCount, 1);
        expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
        expect(controller.state.activeHousehold, isNull);
      },
    );

    test(
      'resolution retry compares against the last private household context',
      () async {
        final AuthSession session = authSessionFixture();
        final ActiveHousehold previous = activeHouseholdFixture();
        final ActiveHousehold next = activeHouseholdFixture(
          householdId: '22222222-2222-4222-8222-222222222223',
          memberId: '33333333-3333-4333-8333-333333333334',
        );
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
          refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
        );
        final _RecordingHouseholdTransition transition =
            _RecordingHouseholdTransition(result: true);
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            loadResults: <LoadActiveHouseholdResult>[
              ActiveHouseholdLoaded(previous),
              const LoadActiveHouseholdFailed(
                HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
              ),
              ActiveHouseholdLoaded(next),
            ],
          ),
          activeHouseholdTransitionLocalState: transition,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        await controller.revalidateOnResume();
        expect(controller.state, isA<AuthHouseholdResolutionFailed>());

        await controller.retryHouseholdResolution();

        expect(transition.households, <ActiveHousehold>[next]);
        expect(controller.state.activeHousehold, next);
      },
    );

    test(
      'failed resume transition never exposes the new household context',
      () async {
        final AuthSession session = authSessionFixture();
        final ActiveHousehold previous = activeHouseholdFixture();
        final ActiveHousehold next = activeHouseholdFixture(
          householdId: '22222222-2222-4222-8222-222222222223',
          memberId: '33333333-3333-4333-8333-333333333334',
        );
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(session),
          refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
        );
        final AuthLifecycleController controller = _controller(
          repository: repository,
          householdRepository: FakeHouseholdRepository(
            loadResults: <LoadActiveHouseholdResult>[
              ActiveHouseholdLoaded(previous),
              ActiveHouseholdLoaded(next),
            ],
          ),
          activeHouseholdTransitionLocalState: _RecordingHouseholdTransition(
            result: false,
          ),
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        await controller.revalidateOnResume();

        expect(controller.state, isA<AuthLocked>());
        expect(
          controller.state.failure?.kind,
          AuthFailureKind.localPurgeFailed,
        );
        expect(controller.state.activeHousehold, isNull);
        expect(controller.state.permitsProtectedRoutes, isFalse);
      },
    );

    test('expired refresh purges and becomes unauthenticated', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
        refreshResults: const <AuthSessionResult>[
          AuthSessionFailed(AuthFailure(AuthFailureKind.sessionExpired)),
        ],
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      await controller.refresh();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(controller.state.failure?.kind, AuthFailureKind.sessionExpired);
      expect(purger.purgeCount, 1);
    });

    test('logout purges even when provider sign-out fails', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
        signOutResults: const <AuthSignOutResult>[
          AuthSignOutFailed(
            AuthFailure(AuthFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      await controller.logout();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(
        controller.state.failure?.kind,
        AuthFailureKind.temporarilyUnavailable,
      );
      expect(repository.signOutCount, 1);
      expect(purger.purgeCount, 1);
    });

    test('logout remains safe and idempotent after session clear', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(authSessionFixture()),
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      await controller.logout();
      await controller.logout();

      expect(controller.state, isA<AuthUnauthenticated>());
      expect(repository.signOutCount, 2);
      expect(purger.purgeCount, 2);
    });

    test('account switch stays locked until purge completes', () async {
      final Completer<SensitiveLocalStatePurgeResult> purge =
          Completer<SensitiveLocalStatePurgeResult>();
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger(
            results: <FutureOr<SensitiveLocalStatePurgeResult> Function()>[
              () => purge.future,
            ],
          );
      final AuthSession first = authSessionFixture();
      final AuthSession second = authSessionFixture(
        userId: '22222222-2222-4222-8222-222222222222',
      );
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(first),
      );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        if (!purge.isCompleted) {
          purge.complete(const SensitiveLocalStatePurged());
        }
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      repository.emit(AuthSessionEstablished(second));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, isA<AuthLocked>());
      expect(controller.state.permitsProtectedRoutes, isFalse);
      expect(purger.purgeCount, 1);

      purge.complete(const SensitiveLocalStatePurged());
      await controller.waitForPendingOperations();

      expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
      expect(controller.state.session, second);
    });

    test('account switch remains locked when local purge fails', () async {
      final AuthSession first = authSessionFixture();
      final AuthSession second = authSessionFixture(
        userId: '22222222-2222-4222-8222-222222222222',
      );
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(first),
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger(
            results: <FutureOr<SensitiveLocalStatePurgeResult> Function()>[
              () => const SensitiveLocalStatePurgeFailed(
                failedParticipantCount: 1,
              ),
            ],
          );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      repository.emit(AuthSessionEstablished(second));
      await controller.waitForPendingOperations();

      expect(controller.state, isA<AuthLocked>());
      expect(controller.state.failure?.kind, AuthFailureKind.localPurgeFailed);
      expect(controller.state.session, isNull);
    });

    test('same-user provider event does not purge', () async {
      final AuthSession session = authSessionFixture();
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
        restoreResult: AuthSessionAvailable(session),
      );
      final RecordingSensitiveLocalStatePurger purger =
          RecordingSensitiveLocalStatePurger();
      final AuthLifecycleController controller = _controller(
        repository: repository,
        purger: purger,
      );
      final List<AuthLifecycleState> states = <AuthLifecycleState>[];
      final StreamSubscription<AuthLifecycleState> subscription = controller
          .states
          .listen(states.add);
      addTearDown(() async {
        await subscription.cancel();
        await controller.dispose();
        await repository.close();
      });
      await controller.start();
      states.clear();

      repository.emit(AuthSessionEstablished(session));
      await controller.waitForPendingOperations();

      expect(controller.state.session, session);
      expect(states, isEmpty);
      expect(purger.purgeCount, 0);
    });

    test(
      'provider session revocation purges and blocks protected routes',
      () async {
        final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
          restoreResult: AuthSessionAvailable(authSessionFixture()),
        );
        final RecordingSensitiveLocalStatePurger purger =
            RecordingSensitiveLocalStatePurger();
        final AuthLifecycleController controller = _controller(
          repository: repository,
          purger: purger,
        );
        addTearDown(() async {
          await controller.dispose();
          await repository.close();
        });
        await controller.start();

        repository.emit(
          const AuthSessionTerminated(AuthSessionTerminationReason.revoked),
        );
        await controller.waitForPendingOperations();

        expect(controller.state, isA<AuthUnauthenticated>());
        expect(controller.state.permitsProtectedRoutes, isFalse);
        expect(controller.state.failure?.kind, AuthFailureKind.sessionRevoked);
        expect(purger.purgeCount, 1);
      },
    );

    test('sign-in request waits for a provider session event', () async {
      final FakeAuthSessionRepository repository = FakeAuthSessionRepository();
      final FakeAuthSignInLauncher launcher = FakeAuthSignInLauncher(
        results: const <AuthSignInRequestResult>[AuthSignInRequestStarted()],
      );
      final AuthLifecycleController controller = _controller(
        repository: repository,
        launcher: launcher,
      );
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      await controller.requestSignIn();
      expect(controller.state, isA<AuthAuthenticating>());

      repository.emit(AuthSessionEstablished(authSessionFixture()));
      await controller.waitForPendingOperations();

      expect(controller.state, isA<AuthAuthenticatedNoHousehold>());
      expect(launcher.requestCount, 1);
    });
  });

  test(
    'composite purger attempts every participant and reports failures',
    () async {
      final _PurgeParticipant first = _PurgeParticipant(shouldFail: true);
      final _PurgeParticipant second = _PurgeParticipant();
      final CompositeSensitiveLocalStatePurger purger =
          CompositeSensitiveLocalStatePurger(
            <SensitiveLocalStatePurgeParticipant>[first, second],
          );

      final SensitiveLocalStatePurgeResult result = await purger.purge();

      expect(result, isA<SensitiveLocalStatePurgeFailed>());
      expect(
        (result as SensitiveLocalStatePurgeFailed).failedParticipantCount,
        1,
      );
      expect(first.callCount, 1);
      expect(second.callCount, 1);
    },
  );
}

AuthLifecycleController _controller({
  required FakeAuthSessionRepository repository,
  SensitiveLocalStatePurger? purger,
  AuthSignInLauncher? launcher,
  HouseholdRepository? householdRepository,
  ActiveHouseholdSnapshotWriter? activeHouseholdSnapshotWriter,
  ActiveHouseholdTransitionLocalState? activeHouseholdTransitionLocalState,
}) {
  return AuthLifecycleController(
    repository: repository,
    signInLauncher: launcher ?? FakeAuthSignInLauncher(),
    localStatePurger: purger ?? RecordingSensitiveLocalStatePurger(),
    householdRepository: householdRepository ?? FakeHouseholdRepository(),
    activeHouseholdSnapshotWriter:
        activeHouseholdSnapshotWriter ??
        const UnavailableActiveHouseholdSnapshotWriter(),
    activeHouseholdTransitionLocalState:
        activeHouseholdTransitionLocalState ??
        const UnavailableActiveHouseholdTransitionLocalState(),
  );
}

final class _RecordingHouseholdSnapshotWriter
    implements ActiveHouseholdSnapshotWriter {
  _RecordingHouseholdSnapshotWriter({required this.result});

  final bool result;
  final List<ActiveHousehold> households = <ActiveHousehold>[];
  var clearCount = 0;

  @override
  Future<bool> replace(ActiveHousehold household) async {
    households.add(household);
    return result;
  }

  @override
  Future<bool> clear() async {
    clearCount += 1;
    return result;
  }
}

final class _RecordingHouseholdTransition
    implements ActiveHouseholdTransitionLocalState {
  _RecordingHouseholdTransition({required this.result, bool? clearResult})
    : clearResult = clearResult ?? result;

  final bool result;
  final bool clearResult;
  final List<ActiveHousehold> households = <ActiveHousehold>[];
  var clearCount = 0;

  @override
  Future<bool> replaceAfterSwitch(ActiveHousehold household) async {
    households.add(household);
    return result;
  }

  @override
  Future<bool> clearAfterDeparture() async {
    clearCount += 1;
    return clearResult;
  }
}

final class _PurgeParticipant implements SensitiveLocalStatePurgeParticipant {
  _PurgeParticipant({this.shouldFail = false});

  final bool shouldFail;
  var callCount = 0;

  @override
  Future<void> purgeSensitiveLocalState() async {
    callCount += 1;
    if (shouldFail) {
      throw StateError('synthetic purge failure');
    }
  }
}
