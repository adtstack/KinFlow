import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/data/services/ephemeral_pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_invite_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets('no-household session is forced through validated onboarding', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdRepository repository = FakeHouseholdRepository();
    await _pumpOnboarding(tester, repository: repository);

    expect(find.byKey(const Key('household.onboarding')), findsOneWidget);
    expect(find.byKey(const Key('today.screen')), findsNothing);
    expect(
      find.byKey(const Key('household.additionalSettings')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('household.locale')), findsNothing);
    expect(find.byKey(const Key('household.timezone')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('household.create')));
    await tester.tap(find.byKey(const Key('household.create')));
    await tester.pump();

    expect(
      find.text('Enter 1–80 characters without control characters.'),
      findsNWidgets(2),
    );
    expect(repository.createCount, 0);

    await tester.enterText(
      find.byKey(const Key('household.ownerDisplayName')),
      ' Alex ',
    );
    await tester.enterText(
      find.byKey(const Key('household.name')),
      ' Kim Home ',
    );
    await tester.ensureVisible(find.byKey(const Key('household.create')));
    await tester.tap(find.byKey(const Key('household.create')));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(repository.createRequests.single.ownerDisplayName, 'Alex');
    expect(repository.createRequests.single.householdName, 'Kim Home');
    expect(repository.createRequests.single.locale, 'en');
    expect(repository.createRequests.single.timezone, 'UTC');
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(find.byKey(const Key('chore.guided.screen')), findsNothing);
  });

  testWidgets('safe retry reuses the same command ID and reaches Today', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdRepository repository = FakeHouseholdRepository(
      createResults: <CreateFirstHouseholdResult>[
        const CreateFirstHouseholdFailed(
          HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
        ),
        FirstHouseholdCreated(activeHouseholdFixture()),
      ],
    );
    final FakeHouseholdCreationIdGenerator generator =
        FakeHouseholdCreationIdGenerator();
    await _pumpOnboarding(tester, repository: repository, generator: generator);
    await tester.enterText(
      find.byKey(const Key('household.ownerDisplayName')),
      'Alex',
    );
    await tester.enterText(find.byKey(const Key('household.name')), 'Kim Home');

    await tester.ensureVisible(find.byKey(const Key('household.create')));
    await tester.tap(find.byKey(const Key('household.create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('household.onboardingError')), findsOneWidget);
    expect(
      find.text(
        "We couldn't create the household. Your request is safe to retry.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('raw-provider'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('household.create')));
    await tester.tap(find.byKey(const Key('household.create')));
    await tester.pumpAndSettle();

    expect(generator.generateCount, 1);
    expect(
      repository.createRequests.first.idempotencyKey,
      repository.createRequests.last.idempotencyKey,
    );
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
    expect(find.byKey(const Key('chore.guided.screen')), findsNothing);
  });

  testWidgets('household timezone is searched and selected before create', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdRepository repository = FakeHouseholdRepository();
    await _pumpOnboarding(tester, repository: repository);

    await _expandAdditionalSettings(tester);
    final Finder timezone = find.byKey(const Key('household.timezone'));
    final EditableText editable = tester.widget<EditableText>(
      find.descendant(of: timezone, matching: find.byType(EditableText)),
    );
    expect(editable.readOnly, isTrue);
    await _selectTimezone(
      tester,
      field: timezone,
      query: 'london',
      identifier: 'Europe/London',
    );

    await tester.enterText(
      find.byKey(const Key('household.ownerDisplayName')),
      'Alex',
    );
    await tester.enterText(
      find.byKey(const Key('household.name')),
      'London Home',
    );
    final Finder create = find.byKey(const Key('household.create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(repository.createRequests.single.timezone, 'Europe/London');
    expect(find.byKey(const Key('today.screen')), findsOneWidget);
  });

  testWidgets('Korean onboarding copy is selected by app locale', (
    WidgetTester tester,
  ) async {
    await _pumpOnboarding(
      tester,
      repository: FakeHouseholdRepository(),
      locale: const Locale('ko'),
    );

    expect(find.text('함께 사용할 집 만들기'), findsOneWidget);
    expect(find.text('가구 만들기'), findsOneWidget);
    expect(find.text('추가 설정'), findsOneWidget);
    expect(find.byKey(const Key('household.timezone')), findsNothing);

    await _expandAdditionalSettings(tester);
    final Finder timezone = find.byKey(const Key('household.timezone'));
    final EditableText editable = tester.widget<EditableText>(
      find.descendant(of: timezone, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, 'Asia/Seoul');
    expect(
      tester
          .state<FormFieldState<String>>(
            find.byKey(const Key('household.locale')),
          )
          .value,
      'ko',
    );
  });

  testWidgets('onboarding offers manual invite code entry', (
    WidgetTester tester,
  ) async {
    await _pumpOnboarding(tester, repository: FakeHouseholdRepository());

    await tester.ensureVisible(find.byKey(const Key('household.inviteCode')));
    await tester.tap(find.byKey(const Key('household.inviteCode')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite.code.input')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('household.onboarding')), findsOneWidget);
    expect(find.byKey(const Key('invite.code.input')), findsNothing);
  });

  testWidgets('onboarding remains scrollable at 200% pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpOnboarding(
      tester,
      repository: FakeHouseholdRepository(),
      locale: const Locale('en', 'XA'),
    );

    expect(find.byKey(const Key('household.onboardingScroll')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('household.create')));
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const Key('household.create'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpOnboarding(
  WidgetTester tester, {
  required HouseholdRepository repository,
  FakeHouseholdCreationIdGenerator? generator,
  Locale? locale,
}) async {
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
  );
  addTearDown(authRepository.close);
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
      householdRepositoryProvider.overrideWithValue(repository),
      householdCreationIdGeneratorProvider.overrideWithValue(
        generator ?? FakeHouseholdCreationIdGenerator(),
      ),
      inviteRepositoryProvider.overrideWithValue(FakeInviteRepository()),
      inviteCommandIdGeneratorProvider.overrideWithValue(
        FakeInviteCommandIdGenerator(),
      ),
      pendingInviteStoreProvider.overrideWithValue(
        EphemeralPendingInviteStore(),
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
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
  return container;
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

Future<void> _selectTimezone(
  WidgetTester tester, {
  required Finder field,
  required String query,
  required String identifier,
}) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('timezonePicker.search')), query);
  await tester.pumpAndSettle();
  final Finder result = find.byKey(Key('timezonePicker.result.$identifier'));
  await tester.ensureVisible(result);
  await tester.tap(result);
  await tester.pumpAndSettle();
}

Future<void> _expandAdditionalSettings(WidgetTester tester) async {
  final Finder additionalSettings = find.byKey(
    const Key('household.additionalSettings'),
  );
  await tester.ensureVisible(additionalSettings);
  await tester.tap(additionalSettings);
  await tester.pumpAndSettle();
}
