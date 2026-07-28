import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

import '../../support/fakes/fake_auth_dependencies.dart';

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
      addTearDown(() async {
        await controller.dispose();
        await repository.close();
      });
      await controller.start();

      repository.emit(AuthSessionEstablished(session));
      await controller.waitForPendingOperations();

      expect(controller.state.session, session);
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
}) {
  return AuthLifecycleController(
    repository: repository,
    signInLauncher: launcher ?? FakeAuthSignInLauncher(),
    localStatePurger: purger ?? RecordingSensitiveLocalStatePurger(),
  );
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
