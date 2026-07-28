import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_invite_dependencies.dart';
import '../../support/fixtures/app_public_configuration_fixture.dart';

void main() {
  testWidgets('deep link token is captured then scrubbed before sign-in', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository();
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      inviteRepository: inviteRepository,
    );

    harness.router.go('/invite/$inviteTokenValue');
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/invite');
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      isNot(contains(inviteTokenValue)),
    );
    expect(find.text('Alex invited you to join Kim Home.'), findsOneWidget);
    expect(find.byKey(const Key('invite.signIn')), findsOneWidget);
    expect(harness.pendingStore.read()?.value, inviteTokenValue);

    await tester.tap(find.byKey(const Key('invite.signIn')));
    await tester.pumpAndSettle();

    final Uri signInUri = harness.router.routeInformationProvider.value.uri;
    expect(signInUri.path, '/sign-in');
    expect(signInUri.queryParameters, <String, String>{'continue': 'invite'});
    expect(signInUri.toString(), isNot(contains(inviteTokenValue)));
    expect(harness.pendingStore.read()?.value, inviteTokenValue);
  });

  testWidgets('signed-in adult with no household accepts and enters Today', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository();
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      inviteRepository: inviteRepository,
    );
    harness.router.go('/invite/$inviteTokenValue');
    await tester.pumpAndSettle();

    final FilledButton accept = tester.widget<FilledButton>(
      find.byKey(const Key('invite.accept')),
    );
    expect(accept.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('invite.accept')));
    await tester.pumpAndSettle();

    expect(inviteRepository.acceptRequests, hasLength(1));
    expect(inviteRepository.acceptRequests.single.setActiveHousehold, isTrue);
    expect(harness.pendingStore.read(), isNull);
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
  });

  testWidgets('existing household requires explicit switch confirmation', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository();
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
      inviteRepository: inviteRepository,
    );
    harness.router.go('/invite/$inviteTokenValue');
    await tester.pumpAndSettle();

    FilledButton accept = tester.widget<FilledButton>(
      find.byKey(const Key('invite.accept')),
    );
    expect(accept.onPressed, isNull);
    await tester.tap(find.byKey(const Key('invite.switch.confirm')));
    await tester.pump();
    accept = tester.widget<FilledButton>(
      find.byKey(const Key('invite.accept')),
    );
    expect(accept.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('invite.accept')));
    await tester.pumpAndSettle();
    expect(inviteRepository.acceptRequests, hasLength(1));
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
  });

  testWidgets('owner creates one-time link and can revoke it', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository();
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
      inviteRepository: inviteRepository,
    );

    await tester.tap(find.byKey(const Key('today.invite')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invite.create.email')),
      ' Adult@Example.COM ',
    );
    await tester.tap(find.byKey(const Key('invite.create.submit')));
    await tester.pumpAndSettle();

    const String expectedLink =
        'https://auth.example.invalid/invite/$inviteTokenValue';
    final SelectableText link = tester.widget<SelectableText>(
      find.byKey(const Key('invite.create.link')),
    );
    expect(link.data, expectedLink);
    expect(
      inviteRepository.createRequests.single.targetEmail,
      'adult@example.com',
    );

    await tester.tap(find.byKey(const Key('invite.create.revoke')));
    await tester.pumpAndSettle();

    expect(inviteRepository.revokeRequests, hasLength(1));
    expect(find.byKey(const Key('invite.create.submit')), findsOneWidget);
    expect(find.text(expectedLink), findsNothing);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/family/invite',
    );
  });

  testWidgets('Korean invite copy is selected by locale', (
    WidgetTester tester,
  ) async {
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      locale: const Locale('ko'),
    );
    harness.router.go('/invite/$inviteTokenValue');
    await tester.pumpAndSettle();

    expect(find.text('가구 초대'), findsOneWidget);
    expect(find.text('Alex님이 Kim Home 가구에 초대했습니다.'), findsOneWidget);
    expect(find.text('로그인하고 수락'), findsOneWidget);
  });

  testWidgets('invite remains scrollable at 200% pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    final _InviteHarness harness = await _pumpInviteApp(
      tester,
      locale: const Locale('en', 'XA'),
    );
    harness.router.go('/invite/$inviteTokenValue');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('invite.signIn')));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('invite.signIn'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

final class _InviteHarness {
  const _InviteHarness({
    required this.container,
    required this.router,
    required this.pendingStore,
  });

  final ProviderContainer container;
  final GoRouter router;
  final EphemeralPendingInviteStore pendingStore;
}

Future<_InviteHarness> _pumpInviteApp(
  WidgetTester tester, {
  AuthSessionResult restoreResult = const AuthSessionAbsent(),
  LoadActiveHouseholdResult householdResult = const NoActiveHousehold(),
  FakeInviteRepository? inviteRepository,
  Locale? locale,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: restoreResult,
  );
  final EphemeralPendingInviteStore pendingStore =
      EphemeralPendingInviteStore();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appPublicConfigurationProvider.overrideWithValue(
        publicConfigurationFixture(environment: AppEnvironment.prod),
      ),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(FakeAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        RecordingSensitiveLocalStatePurger(),
      ),
      householdRepositoryProvider.overrideWithValue(
        FakeHouseholdRepository(defaultLoadResult: householdResult),
      ),
      householdCreationIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCreationIdGenerator(),
      ),
      inviteRepositoryProvider.overrideWithValue(
        inviteRepository ?? FakeInviteRepository(),
      ),
      inviteCommandIdGeneratorProvider.overrideWithValue(
        FakeInviteCommandIdGenerator(),
      ),
      pendingInviteStoreProvider.overrideWithValue(pendingStore),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(authRepository.close);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
  return _InviteHarness(
    container: container,
    router: container.read(appRouterProvider),
    pendingStore: pendingStore,
  );
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _successfulInitialization() async {}
