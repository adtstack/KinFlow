import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets(
    'direct route loads latest detail and existing activity surface',
    (WidgetTester tester) async {
      final ChoreOccurrence occurrence = choreOccurrenceFixture(
        title: 'Take out recycling',
        description: 'Use the blue bin',
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(occurrence),
        ],
      );
      final ProviderContainer container = await _pumpTargetApp(
        tester,
        choreRepository: repository,
      );

      container
          .read(appRouterProvider)
          .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chore.target.screen')), findsOneWidget);
      expect(find.byKey(const Key('chore.target.details')), findsOneWidget);
      expect(find.text('Take out recycling'), findsOneWidget);
      expect(find.text('Use the blue bin'), findsOneWidget);
      expect(find.byKey(const Key('chore.history.empty')), findsOneWidget);
      expect(
        find.byKey(const Key('chore.target.completionAction')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('layout.primaryNavigation')), findsNothing);
      expect(repository.occurrenceTargetRequests, hasLength(1));
      expect(
        repository.occurrenceTargetRequests.single.occurrenceId,
        occurrence.id,
      );
    },
  );

  testWidgets('transient failure retries without showing cached detail', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        const LoadChoreOccurrenceTargetFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );

    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.target.error')), findsOneWidget);
    expect(find.byKey(const Key('chore.target.details')), findsNothing);

    await tester.tap(find.byKey(const Key('chore.target.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.target.details')), findsOneWidget);
    expect(repository.occurrenceTargetRequests, hasLength(2));
  });

  testWidgets('missing and forbidden target shares one safe recovery state', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: FakeChoreRepository(
        occurrenceTargetResults: const <LoadChoreOccurrenceTargetResult>[
          LoadChoreOccurrenceTargetFailed(
            ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
          ),
        ],
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.target.unavailable')), findsOneWidget);
    expect(find.byKey(const Key('chore.target.retry')), findsNothing);
    expect(
      find.byKey(const Key('chore.target.openNotifications')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chore.target.openChores')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid occurrence path fails closed to the safe 404 route', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: FakeChoreRepository(),
    );

    container.read(appRouterProvider).go('/chores/occurrence/not-a-uuid');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route.notFound')), findsOneWidget);
    expect(find.byKey(const Key('chore.target.screen')), findsNothing);
  });

  testWidgets('resume refetches the authoritative occurrence target', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(occurrence),
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );

    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();
    expect(repository.occurrenceTargetRequests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.occurrenceTargetRequests, hasLength(2));
    expect(find.byKey(const Key('chore.target.details')), findsOneWidget);
  });

  testWidgets('scheduled target completes and reconciles to reopen action', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence scheduled = choreOccurrenceFixture(
      title: 'Take out recycling',
      canSetCompletion: true,
    );
    final ChoreOccurrence completed = choreOccurrenceFixture(
      title: 'Take out recycling',
      status: ChoreOccurrenceStatus.completed,
      version: 2,
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(scheduled),
        ChoreOccurrenceTargetLoaded(completed),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(scheduled.id));
    await tester.pumpAndSettle();

    expect(find.text('Mark complete'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chore.target.completionAction')));
    await tester.pumpAndSettle();

    expect(repository.completionRequests, hasLength(1));
    expect(repository.completionRequests.single.completed, isTrue);
    expect(repository.occurrenceTargetRequests, hasLength(2));
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Reopen chore'), findsOneWidget);
    expect(find.byKey(const Key('chore.target.actionError')), findsNothing);
  });

  testWidgets('completed target reopens from the exact detail', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence completed = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.completed,
      version: 4,
      canSetCompletion: true,
    );
    final ChoreOccurrence reopened = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.scheduled,
      version: 5,
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(completed),
        ChoreOccurrenceTargetLoaded(reopened),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(completed.id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chore.target.completionAction')));
    await tester.pumpAndSettle();

    expect(repository.completionRequests.single.completed, isFalse);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
  });

  testWidgets('non-actionable historical target remains readable', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence historical = choreOccurrenceFixture(
      title: 'Deleted series history',
      status: ChoreOccurrenceStatus.completed,
      canSetCompletion: false,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(historical),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(historical.id));
    await tester.pumpAndSettle();

    expect(find.text('Deleted series history'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(
      find.byKey(const Key('chore.target.completionAction')),
      findsNothing,
    );
    expect(repository.completionRequests, isEmpty);
  });

  testWidgets('typed completion failure keeps detail and retry action', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
      completionResults: const <SetChoreCompletionResult>[
        SetChoreCompletionFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chore.target.completionAction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chore.target.actionError')), findsOneWidget);
    expect(find.byKey(const Key('chore.target.details')), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);
  });

  testWidgets('chores runtime policy disables target mutation before I/O', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: repository,
      disabledFeatures: const <AppRuntimeFeature>{AppRuntimeFeature.chores},
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();

    final ButtonStyleButton action = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('chore.target.completionAction')),
    );
    expect(action.onPressed, isNull);
    expect(repository.completionRequests, isEmpty);
  });

  testWidgets('action surface fits compact pseudo locale at 200 percent', (
    WidgetTester tester,
  ) async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      description: 'A complete localized description',
      canSetCompletion: true,
    );
    final ProviderContainer container = await _pumpTargetApp(
      tester,
      choreRepository: FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(occurrence),
        ],
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );
    container
        .read(appRouterProvider)
        .go(AppRoutes.choreOccurrenceLocation(occurrence.id));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('chore.target.completionAction')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('chore.history.scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chore.target.completionAction')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpTargetApp(
  WidgetTester tester, {
  required ChoreRepository choreRepository,
  Locale? locale,
  Size? size,
  double textScaleFactor = 1,
  Set<AppRuntimeFeature> disabledFeatures = const <AppRuntimeFeature>{},
}) async {
  if (size != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
    refreshCallback: () async => AuthSessionAvailable(authSessionFixture()),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appRuntimePolicyRepositoryProvider.overrideWithValue(
        _TargetRuntimePolicyRepository(disabledFeatures),
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
      householdRepositoryProvider.overrideWithValue(
        FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
      ),
      householdMemberRepositoryProvider.overrideWithValue(
        FakeHouseholdMemberRepository(),
      ),
      householdCommandIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCommandIdGenerator(),
      ),
      recentAuthenticationServiceProvider.overrideWithValue(
        FakeRecentAuthenticationService(),
      ),
      choreRepositoryProvider.overrideWithValue(choreRepository),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
      calendarRepositoryProvider.overrideWithValue(
        FakeCalendarRepository(
          eventList: calendarEventListFixture(localDate: '2026-08-06'),
        ),
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
  return container;
}

Future<void> _successfulInitialization() async {}

final class _TargetRuntimePolicyRepository
    implements AppRuntimePolicyRepository {
  const _TargetRuntimePolicyRepository(this.disabledFeatures);

  final Set<AppRuntimeFeature> disabledFeatures;

  @override
  Future<AppRuntimePolicyResult> load() async {
    return AppRuntimePolicySucceeded(
      runtimePolicySnapshotFixture(disabledFeatures: disabledFeatures),
    );
  }
}
