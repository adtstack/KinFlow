import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/household/application/household_selection_controller.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_selection_providers.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_selection_screen.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_household_selection_dependencies.dart';

void main() {
  testWidgets('confirms a non-current household and routes to Today', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpSelection(tester);

    expect(find.byKey(const Key('householdSelection.screen')), findsOneWidget);
    expect(find.text('Alpha family'), findsOneWidget);
    expect(find.textContaining('Current household'), findsOneWidget);
    final Finder current = find.byKey(
      Key('householdSelection.household.$householdSelectionAId'),
    );
    expect(
      tester
          .widget<ListTile>(
            find.descendant(of: current, matching: find.byType(ListTile)),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(
      find.byKey(Key('householdSelection.household.$householdSelectionBId')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Switch active household?'), findsOneWidget);
    expect(find.textContaining('Beta family'), findsWidgets);

    await tester.tap(find.byKey(const Key('householdSelection.confirmSwitch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.state.uri.path, AppRoutes.today);
    expect(find.byKey(const Key('today.placeholder')), findsOneWidget);
  });

  testWidgets('remains usable at 200% pseudo text on a narrow screen', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpSelection(tester, locale: const Locale('en', 'XA'));

    final Finder target = find.byKey(
      Key('householdSelection.household.$householdSelectionBId'),
    );
    await tester.ensureVisible(target);
    await tester.pump();

    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const Key('householdSelection.confirmSwitch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the household selection surface in Korean', (
    WidgetTester tester,
  ) async {
    await _pumpSelection(tester, locale: const Locale('ko'));

    expect(find.text('가구 전환'), findsOneWidget);
    expect(find.text('현재 가구'), findsOneWidget);
    expect(find.text('소유자'), findsOneWidget);
  });
}

Future<GoRouter> _pumpSelection(WidgetTester tester, {Locale? locale}) async {
  final HouseholdSelectionController controller = HouseholdSelectionController(
    repository: FakeHouseholdSelectionRepository(
      loadResult: HouseholdSelectionsLoaded(
        householdSelectionSnapshotFixture(),
      ),
      switchResult: ActiveHouseholdSwitched(
        HouseholdSelectionCommit(
          activeHousehold: switchedActiveHouseholdFixture(),
          selectionVersion: 5,
          changed: true,
        ),
      ),
    ),
    committer: FakeActiveHouseholdCommitter(),
  );
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.householdSwitch,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.householdSwitch,
        builder: (_, _) => const HouseholdSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SizedBox(key: Key('settings.placeholder')),
      ),
      GoRoute(
        path: AppRoutes.today,
        builder: (_, _) => const SizedBox(key: Key('today.placeholder')),
      ),
    ],
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      householdSelectionControllerProvider.overrideWithValue(controller),
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ).overrideWithValue(false),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
    unawaited(controller.dispose());
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const Key('householdSelection.list')), findsOneWidget);
  return router;
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
