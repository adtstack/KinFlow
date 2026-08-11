import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_invite_dependencies.dart';
import '../../support/fakes/fake_invite_sharing_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';
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

  testWidgets(
    'pending invite resumes after provider session and can be accepted',
    (WidgetTester tester) async {
      final FakeInviteRepository inviteRepository = FakeInviteRepository();
      final _InviteHarness harness = await _pumpInviteApp(
        tester,
        inviteRepository: inviteRepository,
      );

      harness.router.go('/invite/$inviteTokenValue');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite.signIn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth.signIn.google')));
      await tester.pump();
      expect(harness.signInLauncher.requestCount, 1);

      harness.authRepository.emit(AuthSessionEstablished(authSessionFixture()));
      await tester.pumpAndSettle();

      final Uri inviteUri = harness.router.routeInformationProvider.value.uri;
      expect(inviteUri.path, '/invite');
      expect(inviteUri.queryParameters, isEmpty);
      expect(inviteUri.toString(), isNot(contains(inviteTokenValue)));
      expect(harness.pendingStore.read()?.value, inviteTokenValue);
      expect(find.byKey(const Key('invite.preview.summary')), findsOneWidget);

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
    },
  );

  testWidgets(
    'manual short code survives sign-in and uses code-specific acceptance',
    (WidgetTester tester) async {
      final FakeInviteRepository inviteRepository = FakeInviteRepository();
      final _InviteHarness harness = await _pumpInviteApp(
        tester,
        inviteRepository: inviteRepository,
      );

      expect(find.byKey(const Key('auth.inviteCode')), findsOneWidget);
      await tester.tap(find.byKey(const Key('auth.inviteCode')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.code.input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('invite.code.input')),
        ' 2345 abcd ',
      );
      await tester.tap(find.byKey(const Key('invite.code.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.preview.summary')), findsOneWidget);
      expect(inviteRepository.previewTokens, isEmpty);
      expect(inviteRepository.previewShortCodes.single.value, '2345ABCD');
      expect(harness.pendingStore.read(), isNull);
      expect(harness.pendingStore.readShortCode()?.value, '2345ABCD');

      await tester.tap(find.byKey(const Key('invite.signIn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth.signIn.google')));
      await tester.pump();
      harness.authRepository.emit(AuthSessionEstablished(authSessionFixture()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.preview.summary')), findsOneWidget);
      expect(harness.pendingStore.readShortCode()?.value, '2345ABCD');
      await tester.tap(find.byKey(const Key('invite.accept')));
      await tester.pumpAndSettle();

      expect(inviteRepository.acceptRequests, isEmpty);
      expect(inviteRepository.acceptShortCodeRequests, hasLength(1));
      expect(
        inviteRepository.acceptShortCodeRequests.single.shortCode.value,
        '2345ABCD',
      );
      expect(harness.pendingStore.readShortCode(), isNull);
      expect(find.byKey(const Key('today.screen')), findsOneWidget);
    },
  );

  testWidgets('manual invite entry keeps an AppBar back path to sign-in', (
    WidgetTester tester,
  ) async {
    final _InviteHarness harness = await _pumpInviteApp(tester);
    expect(harness.router.routeInformationProvider.value.uri.path, '/sign-in');

    final Finder inviteCode = find.byKey(const Key('auth.inviteCode'));
    await tester.ensureVisible(inviteCode);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(inviteCode).onPressed, isNotNull);
    await tester.tap(inviteCode);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite.open.screen')), findsOneWidget);
    expect(find.byKey(const Key('invite.open.back')), findsOneWidget);
    expect(find.byKey(const Key('invite.code.scroll')), findsOneWidget);
    expect(find.byKey(const Key('invite.code.icon')), findsOneWidget);
    expect(find.text('Household invitation'), findsOneWidget);
    expect(find.text('Enter an invite code'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('invite.code.input'))).dy,
      lessThan(280),
    );
    expect(
      tester.getSize(find.byKey(const Key('invite.code.icon'))),
      const Size.square(48),
    );

    await tester.tap(find.byKey(const Key('invite.open.back')));
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/sign-in');
    expect(find.byKey(const Key('auth.inviteCode')), findsOneWidget);
  });

  testWidgets('direct invite entry back falls safely to sign-in', (
    WidgetTester tester,
  ) async {
    final _InviteHarness harness = await _pumpInviteApp(tester);
    harness.router.go('/invite');
    await tester.pumpAndSettle();

    expect(harness.router.canPop(), isFalse);
    expect(find.byKey(const Key('invite.open.back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite.open.back')));
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/sign-in');
    expect(find.byKey(const Key('auth.inviteCode')), findsOneWidget);
  });

  testWidgets('manual short code validates locally before preview', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository();
    await _pumpInviteApp(tester, inviteRepository: inviteRepository);

    await tester.tap(find.byKey(const Key('auth.inviteCode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invite.code.input')),
      '1234-ABCI',
    );
    await tester.tap(find.byKey(const Key('invite.code.submit')));
    await tester.pump();

    expect(find.text('Enter a valid 8-character invite code.'), findsOneWidget);
    expect(inviteRepository.previewShortCodes, isEmpty);
  });

  testWidgets(
    'account switch discards an in-flight accept and previous invite state',
    (WidgetTester tester) async {
      final Completer<AcceptHouseholdInviteResult> acceptResponse =
          Completer<AcceptHouseholdInviteResult>();
      final FakeInviteRepository inviteRepository = FakeInviteRepository(
        acceptCallback: (_) => acceptResponse.future,
      );
      final _InviteHarness harness = await _pumpInviteApp(
        tester,
        restoreResult: AuthSessionAvailable(authSessionFixture()),
        householdRepository: FakeHouseholdRepository(
          loadResults: const <LoadActiveHouseholdResult>[
            NoActiveHousehold(),
            NoActiveHousehold(),
          ],
        ),
        inviteRepository: inviteRepository,
      );

      harness.router.go('/invite/$inviteTokenValue');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite.accept')));
      await tester.pump();
      expect(inviteRepository.acceptRequests, hasLength(1));

      harness.authRepository.emit(
        AuthSessionEstablished(
          authSessionFixture(userId: '77777777-7777-4777-8777-777777777777'),
        ),
      );
      await harness.container
          .read(authLifecycleControllerProvider)
          .waitForPendingOperations();
      await tester.pump();

      expect(harness.pendingStore.read(), isNull);
      expect(find.byKey(const Key('invite.missing')), findsOneWidget);
      expect(find.byKey(const Key('invite.preview.summary')), findsNothing);
      expect(find.byKey(const Key('today.screen')), findsNothing);

      acceptResponse.complete(
        HouseholdInviteAccepted(acceptedHouseholdInviteFixture()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite.missing')), findsOneWidget);
      expect(find.byKey(const Key('today.screen')), findsNothing);
    },
  );

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

  testWidgets('owner creates one-time link and code and can revoke them', (
    WidgetTester tester,
  ) async {
    final FakeInviteRepository inviteRepository = FakeInviteRepository(
      createResults: <CreateHouseholdInviteResult>[
        HouseholdInviteCreated(
          householdInviteFixture(rawShortCode: inviteShortCodeValue),
        ),
      ],
    );
    final FakeHouseholdInviteClipboard clipboard =
        FakeHouseholdInviteClipboard();
    await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
      inviteRepository: inviteRepository,
      inviteClipboard: clipboard,
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
    final SelectableText shortCode = tester.widget<SelectableText>(
      find.byKey(const Key('invite.create.code')),
    );
    expect(shortCode.data, inviteShortCodeValue);
    expect(find.byKey(const Key('invite.create.copyCode')), findsOneWidget);
    expect(
      inviteRepository.createRequests.single.targetEmail,
      'adult@example.com',
    );

    final Finder copyCode = find.byKey(const Key('invite.create.copyCode'));
    await tester.ensureVisible(copyCode);
    await tester.tap(copyCode);
    await tester.pumpAndSettle();
    expect(clipboard.shortCodeWrites, hasLength(1));
    expect(clipboard.shortCodeWrites.single.formatted, inviteShortCodeValue);
    expect(find.text('Invite code copied.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('invite.create.revoke')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite.create.revoke')));
    await tester.pumpAndSettle();

    expect(inviteRepository.revokeRequests, hasLength(1));
    expect(find.byKey(const Key('invite.create.submit')), findsOneWidget);
    expect(find.text(expectedLink), findsNothing);
    expect(find.byKey(const Key('invite.create.screen')), findsOneWidget);
  });

  testWidgets('owner opens native share sheet without claiming delivery', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdInviteShareGateway shareGateway =
        FakeHouseholdInviteShareGateway();
    final FakeHouseholdInviteClipboard clipboard =
        FakeHouseholdInviteClipboard();
    await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
      shareGateway: shareGateway,
      inviteClipboard: clipboard,
    );
    await _openCreatedInvite(tester);

    final Finder share = find.byKey(const Key('invite.create.share'));
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pumpAndSettle();

    expect(shareGateway.links, hasLength(1));
    expect(
      shareGateway.links.single.value,
      'https://auth.example.invalid/invite/$inviteTokenValue',
    );
    expect(shareGateway.chooserTitles, <String>['Share KinFlow invitation']);
    expect(clipboard.linkWrites, isEmpty);
    expect(
      find.text(
        'Share sheet opened. Confirm the recipient before sending; '
        'KinFlow cannot confirm delivery.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invite.create.actionStatus')), findsOneWidget);
  });

  testWidgets(
    'Korean unavailable share uses explicit copy and recovers from failure',
    (WidgetTester tester) async {
      final FakeHouseholdInviteShareGateway shareGateway =
          FakeHouseholdInviteShareGateway(
            results: <HouseholdInviteShareResult>[
              HouseholdInviteShareResult.unavailable,
            ],
          );
      final FakeHouseholdInviteClipboard clipboard =
          FakeHouseholdInviteClipboard(
            linkResults: <HouseholdInviteCopyResult>[
              HouseholdInviteCopyResult.failed,
              HouseholdInviteCopyResult.copied,
            ],
          );
      await _pumpInviteApp(
        tester,
        restoreResult: AuthSessionAvailable(authSessionFixture()),
        householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        locale: const Locale('ko'),
        shareGateway: shareGateway,
        inviteClipboard: clipboard,
      );
      await _openCreatedInvite(tester);

      final Finder share = find.byKey(const Key('invite.create.share'));
      await tester.ensureVisible(share);
      expect(find.text('링크 공유'), findsOneWidget);
      await tester.tap(share);
      await tester.pumpAndSettle();

      expect(clipboard.linkWrites, isEmpty);
      expect(
        find.text(
          '공유 시트를 열 수 없습니다. 아래의 링크 복사를 눌러 '
          '초대할 성인에게만 보내세요.',
        ),
        findsOneWidget,
      );

      final Finder copy = find.byKey(const Key('invite.create.copy'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.textContaining('초대를 복사하지 못했습니다.'), findsOneWidget);
      expect(clipboard.linkWrites, hasLength(1));

      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.text('초대 링크를 복사했습니다.'), findsOneWidget);
      expect(clipboard.linkWrites, hasLength(2));
      expect(
        clipboard.linkWrites.last.value,
        'https://auth.example.invalid/invite/$inviteTokenValue',
      );
    },
  );

  testWidgets('sender share recovery is scrollable at 200% pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpInviteApp(
      tester,
      restoreResult: AuthSessionAvailable(authSessionFixture()),
      householdResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
      locale: const Locale('en', 'XA'),
      shareGateway: FakeHouseholdInviteShareGateway(
        results: <HouseholdInviteShareResult>[
          HouseholdInviteShareResult.unavailable,
        ],
      ),
      inviteClipboard: FakeHouseholdInviteClipboard(),
    );
    await _openCreatedInvite(tester);

    final Finder share = find.byKey(const Key('invite.create.share'));
    await tester.ensureVisible(share);
    await tester.pump();
    expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
    await tester.tap(share);
    await tester.pumpAndSettle();

    final Finder copy = find.byKey(const Key('invite.create.copy'));
    await tester.ensureVisible(copy);
    await tester.pump();
    expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(find.byKey(const Key('invite.create.revoke')));
    await tester.pump();
    expect(tester.takeException(), isNull);
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
    required this.authRepository,
    required this.container,
    required this.signInLauncher,
    required this.router,
    required this.pendingStore,
  });

  final FakeAuthSessionRepository authRepository;
  final ProviderContainer container;
  final FakeAuthSignInLauncher signInLauncher;
  final GoRouter router;
  final EphemeralPendingInviteStore pendingStore;
}

Future<_InviteHarness> _pumpInviteApp(
  WidgetTester tester, {
  AuthSessionResult restoreResult = const AuthSessionAbsent(),
  LoadActiveHouseholdResult householdResult = const NoActiveHousehold(),
  HouseholdRepository? householdRepository,
  FakeInviteRepository? inviteRepository,
  HouseholdInviteShareGateway? shareGateway,
  HouseholdInviteClipboard? inviteClipboard,
  Locale? locale,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: restoreResult,
  );
  final FakeAuthSignInLauncher signInLauncher = FakeAuthSignInLauncher();
  final EphemeralPendingInviteStore pendingStore =
      EphemeralPendingInviteStore();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appRuntimePolicyRepositoryProvider.overrideWithValue(
        const FakeAllowedAppRuntimePolicyRepository(),
      ),
      appPublicConfigurationProvider.overrideWithValue(
        publicConfigurationFixture(environment: AppEnvironment.prod),
      ),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(signInLauncher),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        CompositeSensitiveLocalStatePurger(
          <SensitiveLocalStatePurgeParticipant>[pendingStore],
        ),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        createActiveHouseholdSnapshotWriter(),
      ),
      householdRepositoryProvider.overrideWithValue(
        householdRepository ??
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
      if (shareGateway != null)
        householdInviteShareGatewayProvider.overrideWithValue(shareGateway),
      if (inviteClipboard != null)
        householdInviteClipboardProvider.overrideWithValue(inviteClipboard),
      choreRepositoryProvider.overrideWithValue(FakeChoreRepository()),
      calendarRepositoryProvider.overrideWithValue(
        FakeCalendarRepository(
          eventList: calendarEventListFixture(localDate: '2026-08-06'),
        ),
      ),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
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
    authRepository: authRepository,
    container: container,
    signInLauncher: signInLauncher,
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

Future<void> _openCreatedInvite(WidgetTester tester) async {
  final Finder invite = find.byKey(const Key('today.invite'));
  await tester.ensureVisible(invite);
  await tester.pump();
  await tester.tap(invite);
  await tester.pumpAndSettle();
  final Finder submit = find.byKey(const Key('invite.create.submit'));
  await tester.ensureVisible(submit);
  await tester.pump();
  await tester.tap(submit);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('invite.create.link')), findsOneWidget);
}
