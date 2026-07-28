import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  testWidgets('no-household session is forced through validated onboarding', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdRepository repository = FakeHouseholdRepository();
    await _pumpOnboarding(tester, repository: repository);

    expect(find.byKey(const Key('household.onboarding')), findsOneWidget);
    expect(find.byKey(const Key('today.screen')), findsNothing);

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
    expect(repository.createRequests.single.timezone, 'Asia/Seoul');
    expect(find.byKey(const Key('today.empty')), findsOneWidget);
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
    expect(find.byKey(const Key('today.empty')), findsOneWidget);
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
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(createAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        createSensitiveLocalStatePurger(),
      ),
      householdRepositoryProvider.overrideWithValue(repository),
      householdCreationIdGeneratorProvider.overrideWithValue(
        generator ?? FakeHouseholdCreationIdGenerator(),
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
