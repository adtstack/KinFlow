import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/widgets/auth_session_lifecycle_host.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  testWidgets('mount restores once without a redundant session refresh', (
    WidgetTester tester,
  ) async {
    final AuthSession session = authSessionFixture();
    final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
      restoreResult: AuthSessionAvailable(session),
      refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
    );
    final _HostHarness harness = await _pumpHost(
      tester,
      repository: repository,
    );

    expect(repository.restoreCount, 1);
    expect(repository.refreshCount, 0);
    expect(find.byKey(const Key('authSessionLifecycle.child')), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('resume revalidates an authenticated app-shell session', (
    WidgetTester tester,
  ) async {
    final AuthSession session = authSessionFixture();
    final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
      restoreResult: AuthSessionAvailable(session),
      refreshResults: <AuthSessionResult>[AuthSessionAvailable(session)],
    );
    final _HostHarness harness = await _pumpHost(
      tester,
      repository: repository,
    );

    await _resumeAndSettle(tester, harness.controller);

    expect(repository.refreshCount, 1);
    expect(
      harness.container.read(authLifecycleProvider),
      isA<AuthAuthenticatedNoHousehold>(),
    );

    await harness.dispose(tester);
  });

  testWidgets('unauthenticated resume performs no provider refresh', (
    WidgetTester tester,
  ) async {
    final FakeAuthSessionRepository repository = FakeAuthSessionRepository();
    final RecordingSensitiveLocalStatePurger purger =
        RecordingSensitiveLocalStatePurger();
    final _HostHarness harness = await _pumpHost(
      tester,
      repository: repository,
      purger: purger,
    );

    await _resumeAndSettle(tester, harness.controller);

    expect(repository.refreshCount, 0);
    expect(purger.purgeCount, 1);
    expect(
      harness.container.read(authLifecycleProvider),
      isA<AuthUnauthenticated>(),
    );

    await harness.dispose(tester);
  });

  testWidgets('resume expiration purges before closing protected routes', (
    WidgetTester tester,
  ) async {
    final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      refreshResults: const <AuthSessionResult>[
        AuthSessionFailed(AuthFailure(AuthFailureKind.sessionExpired)),
      ],
    );
    final RecordingSensitiveLocalStatePurger purger =
        RecordingSensitiveLocalStatePurger();
    final _HostHarness harness = await _pumpHost(
      tester,
      repository: repository,
      purger: purger,
    );

    await _resumeAndSettle(tester, harness.controller);

    final AuthLifecycleState state = harness.container.read(
      authLifecycleProvider,
    );
    expect(repository.refreshCount, 1);
    expect(purger.purgeCount, 1);
    expect(state, isA<AuthUnauthenticated>());
    expect(state.failure?.kind, AuthFailureKind.sessionExpired);
    expect(state.permitsProtectedRoutes, isFalse);

    await harness.dispose(tester);
  });

  testWidgets('resume burst is single-flight with one trailing refresh', (
    WidgetTester tester,
  ) async {
    final AuthSession session = authSessionFixture();
    final Completer<AuthSessionResult> firstRefresh =
        Completer<AuthSessionResult>();
    var callbackCount = 0;
    final FakeAuthSessionRepository repository = FakeAuthSessionRepository(
      restoreResult: AuthSessionAvailable(session),
      refreshCallback: () {
        callbackCount += 1;
        if (callbackCount == 1) {
          return firstRefresh.future;
        }
        return Future<AuthSessionResult>.value(AuthSessionAvailable(session));
      },
    );
    final _HostHarness harness = await _pumpHost(
      tester,
      repository: repository,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.refreshCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.refreshCount, 1);

    firstRefresh.complete(AuthSessionAvailable(session));
    await tester.pumpAndSettle();
    await harness.controller.waitForPendingOperations();
    await tester.pump();

    expect(repository.refreshCount, 2);

    await harness.dispose(tester);
  });
}

Future<_HostHarness> _pumpHost(
  WidgetTester tester, {
  required FakeAuthSessionRepository repository,
  RecordingSensitiveLocalStatePurger? purger,
}) async {
  final RecordingSensitiveLocalStatePurger resolvedPurger =
      purger ?? RecordingSensitiveLocalStatePurger();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionRepositoryProvider.overrideWithValue(repository),
        authSignInLauncherProvider.overrideWithValue(FakeAuthSignInLauncher()),
        sensitiveLocalStatePurgerProvider.overrideWithValue(resolvedPurger),
        householdRepositoryProvider.overrideWithValue(
          FakeHouseholdRepository(),
        ),
        activeHouseholdSnapshotWriterProvider.overrideWithValue(
          const UnavailableActiveHouseholdSnapshotWriter(),
        ),
        activeHouseholdTransitionLocalStateProvider.overrideWithValue(
          const UnavailableActiveHouseholdTransitionLocalState(),
        ),
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: AuthSessionLifecycleHost(
          child: SizedBox(key: Key('authSessionLifecycle.child')),
        ),
      ),
    ),
  );
  final BuildContext context = tester.element(
    find.byKey(const Key('authSessionLifecycle.child')),
  );
  final ProviderContainer container = ProviderScope.containerOf(context);
  final AuthLifecycleController controller = container.read(
    authLifecycleControllerProvider,
  );
  await controller.waitForPendingOperations();
  await tester.pump();
  return _HostHarness(
    container: container,
    controller: controller,
    repository: repository,
  );
}

Future<void> _resumeAndSettle(
  WidgetTester tester,
  AuthLifecycleController controller,
) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await controller.waitForPendingOperations();
  await tester.pump();
}

final class _HostHarness {
  const _HostHarness({
    required this.container,
    required this.controller,
    required this.repository,
  });

  final ProviderContainer container;
  final AuthLifecycleController controller;
  final FakeAuthSessionRepository repository;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.close();
  }
}
