import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_invite_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets(
    'Owner sees allowed actions and confirms a recent-auth role change',
    (WidgetTester tester) async {
      final FakeHouseholdMemberRepository memberRepository =
          FakeHouseholdMemberRepository();
      final FakeRecentAuthenticationService recent =
          FakeRecentAuthenticationService();
      final _MembersHarness harness = await _pumpMembersApp(
        tester,
        memberRepository: memberRepository,
        recentAuthenticationService: recent,
      );

      expect(find.byKey(const Key('members.screen')), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.byKey(const Key('members.leave')), findsNothing);
      expect(find.byKey(const Key('members.invite')), findsOneWidget);

      await tester.tap(find.byKey(const Key('members.invite')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, AppRoutes.inviteCreate);
      expect(find.byKey(const Key('invite.create.screen')), findsOneWidget);
      final Finder back = find.byKey(const Key('layout.back'));
      expect(back, findsOneWidget);
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, AppRoutes.householdMembers);

      final Key targetMenu = Key(
        'members.menu.${memberRepository.defaultRoster.members.last.id.value}',
      );
      await tester.tap(find.byKey(targetMenu));
      await tester.pumpAndSettle();
      expect(find.text('Change to Admin'), findsOneWidget);
      expect(find.text('Transfer Owner'), findsOneWidget);
      expect(find.text('Remove from household'), findsOneWidget);

      await tester.tap(find.text('Change to Admin'));
      await tester.pumpAndSettle();
      expect(find.text('Change this role?'), findsOneWidget);
      expect(find.textContaining('Google'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(memberRepository.changeRoleCommands, isEmpty);

      await tester.tap(find.byKey(targetMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change to Admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('members.confirm.action')));
      await tester.pumpAndSettle();

      expect(memberRepository.changeRoleCommands, hasLength(1));
      expect(recent.authenticateCount, 1);
      expect(harness.router.state.uri.path, AppRoutes.householdMembers);
    },
  );

  testWidgets('member roster remains usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    final FakeHouseholdMemberRepository repository =
        FakeHouseholdMemberRepository(
          roster: householdMemberRosterFixture(
            currentRole: HouseholdMemberRole.member,
            otherRole: HouseholdMemberRole.owner,
          ),
        );
    await _pumpMembersApp(
      tester,
      memberRepository: repository,
      recentAuthenticationService: FakeRecentAuthenticationService(),
      locale: const Locale('en', 'XA'),
    );

    expect(find.byKey(const Key('members.invite')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('members.leave')));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('members.leave'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('members.leave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('members.confirm.title')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('members.confirm.action')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leave commits the server fallback and routes without auth refresh',
    (WidgetTester tester) async {
      final fallback = activeHouseholdFixture(
        householdId: '22222222-2222-4222-8222-222222222223',
        memberId: '33333333-3333-4333-8333-333333333335',
      );
      final FakeHouseholdMemberRepository memberRepository =
          FakeHouseholdMemberRepository(
            roster: householdMemberRosterFixture(
              currentRole: HouseholdMemberRole.member,
              otherRole: HouseholdMemberRole.owner,
            ),
            leaveResults: <HouseholdMemberCommandResult>[
              HouseholdLeaveCompleted(fallback),
            ],
          );
      final _MembersHarness harness = await _pumpMembersApp(
        tester,
        memberRepository: memberRepository,
        recentAuthenticationService: FakeRecentAuthenticationService(),
      );

      await tester.ensureVisible(find.byKey(const Key('members.leave')));
      await tester.tap(find.byKey(const Key('members.leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final AuthLifecycleState authState = harness.container.read(
        authLifecycleProvider,
      );
      expect(memberRepository.leaveCommands, hasLength(1));
      expect(authState, isA<AuthAuthenticatedActiveHousehold>());
      expect(authState.activeHousehold, fallback);
      expect(harness.authRepository.refreshCount, 0);
      expect(harness.householdRepository.loadCount, 1);
      expect(harness.router.state.uri.path, AppRoutes.today);
    },
  );

  testWidgets('local handoff failure locks and hides the departed roster', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdMemberRepository memberRepository =
        FakeHouseholdMemberRepository(
          roster: householdMemberRosterFixture(
            currentRole: HouseholdMemberRole.member,
            otherRole: HouseholdMemberRole.owner,
          ),
        );
    final _MembersHarness harness = await _pumpMembersApp(
      tester,
      memberRepository: memberRepository,
      recentAuthenticationService: FakeRecentAuthenticationService(),
      activeHouseholdTransitionLocalState: const _FailingHouseholdTransition(),
    );

    await tester.ensureVisible(find.byKey(const Key('members.leave')));
    await tester.tap(find.byKey(const Key('members.leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('members.confirm.action')));
    await tester.pumpAndSettle();

    final AuthLifecycleState authState = harness.container.read(
      authLifecycleProvider,
    );
    expect(authState, isA<AuthLocked>());
    expect(authState.permitsProtectedRoutes, isFalse);
    expect(harness.router.state.uri.path, AppRoutes.signIn);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('Sam'), findsNothing);
    expect(harness.authRepository.refreshCount, 0);
  });
}

final class _MembersHarness {
  const _MembersHarness({
    required this.container,
    required this.router,
    required this.authRepository,
    required this.householdRepository,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeAuthSessionRepository authRepository;
  final FakeHouseholdRepository householdRepository;
}

Future<_MembersHarness> _pumpMembersApp(
  WidgetTester tester, {
  required FakeHouseholdMemberRepository memberRepository,
  required FakeRecentAuthenticationService recentAuthenticationService,
  ActiveHouseholdTransitionLocalState? activeHouseholdTransitionLocalState,
  Locale? locale,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
  );
  final FakeHouseholdRepository householdRepository = FakeHouseholdRepository(
    defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appRuntimePolicyRepositoryProvider.overrideWithValue(
        const FakeAllowedAppRuntimePolicyRepository(),
      ),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(createAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        createSensitiveLocalStatePurger(),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        createActiveHouseholdSnapshotWriter(),
      ),
      if (activeHouseholdTransitionLocalState != null)
        activeHouseholdTransitionLocalStateProvider.overrideWithValue(
          activeHouseholdTransitionLocalState,
        ),
      householdRepositoryProvider.overrideWithValue(householdRepository),
      householdMemberRepositoryProvider.overrideWithValue(memberRepository),
      householdCommandIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCommandIdGenerator(),
      ),
      inviteRepositoryProvider.overrideWithValue(FakeInviteRepository()),
      inviteCommandIdGeneratorProvider.overrideWithValue(
        FakeInviteCommandIdGenerator(),
      ),
      recentAuthenticationServiceProvider.overrideWithValue(
        recentAuthenticationService,
      ),
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
  final GoRouter router = container.read(appRouterProvider);
  router.go(AppRoutes.householdMembers);
  await tester.pumpAndSettle();
  return _MembersHarness(
    container: container,
    router: router,
    authRepository: authRepository,
    householdRepository: householdRepository,
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

final class _FailingHouseholdTransition
    implements ActiveHouseholdTransitionLocalState {
  const _FailingHouseholdTransition();

  @override
  Future<bool> replaceAfterSwitch(ActiveHousehold household) async => false;

  @override
  Future<bool> clearAfterDeparture() async => false;
}
