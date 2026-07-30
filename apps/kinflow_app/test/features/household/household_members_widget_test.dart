import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';

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
      await tester.tap(find.text('Continue'));
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

    await tester.ensureVisible(find.byKey(const Key('members.leave')));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('members.leave'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

final class _MembersHarness {
  const _MembersHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
}

Future<_MembersHarness> _pumpMembersApp(
  WidgetTester tester, {
  required FakeHouseholdMemberRepository memberRepository,
  required FakeRecentAuthenticationService recentAuthenticationService,
  Locale? locale,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(createAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        createSensitiveLocalStatePurger(),
      ),
      householdRepositoryProvider.overrideWithValue(
        FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
      ),
      householdMemberRepositoryProvider.overrideWithValue(memberRepository),
      householdCommandIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCommandIdGenerator(),
      ),
      recentAuthenticationServiceProvider.overrideWithValue(
        recentAuthenticationService,
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
  return _MembersHarness(container: container, router: router);
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
