import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';
import 'package:kinflow_app/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:kinflow_app/features/analytics/presentation/screens/analytics_privacy_screen.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('default-off screen exposes exact privacy and SDK boundaries', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, repository: _FakeAnalyticsPreferenceRepository());

    expect(find.byKey(const Key('analyticsPrivacy.content')), findsOneWidget);
    expect(
      find.text('Off. Optional usage events are not sent.'),
      findsOneWidget,
    );
    expect(find.textContaining('no external SDK installed'), findsOneWidget);
    expect(find.textContaining('Sentry'), findsOneWidget);
    expect(find.textContaining('Firebase Messaging'), findsOneWidget);
    expect(find.textContaining('RevenueCat'), findsOneWidget);
    expect(find.textContaining('Google Sign-In and Supabase'), findsOneWidget);
    expect(find.textContaining('Managed Child mode'), findsOneWidget);
    expect(find.textContaining('adult@example.com'), findsNothing);
    expect(find.textContaining('household-secret'), findsNothing);
  });

  testWidgets('preference toggle saves once and reports unavailable sink', (
    WidgetTester tester,
  ) async {
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(
          saveResults: <AnalyticsPreferenceResult>[
            const AnalyticsPreferenceSucceeded(
              AnalyticsUsagePreference.granted,
            ),
          ],
        );
    await _pumpScreen(tester, repository: repository);

    await tester.tap(
      find.byKey(const Key('analyticsPrivacy.preferenceToggle')),
    );
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.savedPreferences, <AnalyticsUsagePreference>[
      AnalyticsUsagePreference.granted,
    ]);
    expect(
      find.textContaining('no external behavioral analytics sink'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('analyticsPrivacy.status.saved')),
      findsOneWidget,
    );
  });

  testWidgets('save failure preserves off and never exposes raw detail', (
    WidgetTester tester,
  ) async {
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(throwOnSave: true);
    await _pumpScreen(tester, repository: repository);

    await tester.tap(
      find.byKey(const Key('analyticsPrivacy.preferenceToggle')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('analyticsPrivacy.status.saveFailed')),
      findsOneWidget,
    );
    expect(find.textContaining('previous choice remains'), findsOneWidget);
    expect(find.textContaining('adult@example.com'), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('analyticsPrivacy.preferenceToggle')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('load failure retries into a complete default-off screen', (
    WidgetTester tester,
  ) async {
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(
          loadResults: <AnalyticsPreferenceResult>[
            const AnalyticsPreferenceFailed(
              AnalyticsPreferenceFailure(
                AnalyticsPreferenceFailureKind.temporarilyUnavailable,
              ),
            ),
            const AnalyticsPreferenceSucceeded(
              AnalyticsUsagePreference.withdrawn,
            ),
          ],
        );
    await _pumpScreen(tester, repository: repository);

    expect(find.byKey(const Key('analyticsPrivacy.error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('analyticsPrivacy.retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analyticsPrivacy.content')), findsOneWidget);
    expect(repository.loadCalls, 2);
  });

  testWidgets('Korean copy explains default off and no behavioral SDK', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _FakeAnalyticsPreferenceRepository(),
      locale: const Locale('ko'),
    );

    expect(find.text('분석 및 데이터 수집'), findsOneWidget);
    expect(find.textContaining('기본값은 꺼짐'), findsOneWidget);
    expect(find.textContaining('외부 SDK가 설치되어 있지 않습니다'), findsOneWidget);
  });

  testWidgets('pseudo locale remains scrollable at 200 percent text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      repository: _FakeAnalyticsPreferenceRepository(),
      locale: const Locale('en', 'XA'),
      configureDefaultView: false,
    );

    final Finder toggle = find.byKey(
      const Key('analyticsPrivacy.preferenceToggle'),
    );
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
    final Finder finalCard = find.byKey(
      const Key('analyticsPrivacy.neverCollected'),
    );
    await tester.ensureVisible(finalCard);
    await tester.pump();
    expect(finalCard, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings tile navigates to the protected analytics route', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.analyticsPrivacy,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: Key('analyticsPrivacy.routeTarget')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdPrivacyOwnerVisibilityProvider.overrideWith(
            (ref) async => false,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder tile = find.byKey(const Key('settings.analyticsPrivacy'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.analyticsPrivacy);
    expect(
      find.byKey(const Key('analyticsPrivacy.routeTarget')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AnalyticsPreferenceRepository repository,
  AnalyticsSink sink = const _FakeAnalyticsSink(),
  Locale locale = const Locale('en'),
  bool configureDefaultView = true,
}) async {
  if (configureDefaultView) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsPreferenceRepositoryProvider.overrideWithValue(repository),
        analyticsSinkProvider.overrideWithValue(sink),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnalyticsPrivacyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

final class _FakeAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  _FakeAnalyticsPreferenceRepository({
    List<AnalyticsPreferenceResult>? loadResults,
    List<AnalyticsPreferenceResult>? saveResults,
    this.throwOnSave = false,
  }) : loadResults =
           loadResults ??
           <AnalyticsPreferenceResult>[
             const AnalyticsPreferenceSucceeded(
               AnalyticsUsagePreference.withdrawn,
             ),
           ],
       saveResults = saveResults ?? <AnalyticsPreferenceResult>[];

  final List<AnalyticsPreferenceResult> loadResults;
  final List<AnalyticsPreferenceResult> saveResults;
  final bool throwOnSave;
  final List<AnalyticsUsagePreference> savedPreferences =
      <AnalyticsUsagePreference>[];
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<AnalyticsPreferenceResult> load() async {
    loadCalls += 1;
    return loadResults.length == 1
        ? loadResults.single
        : loadResults.removeAt(0);
  }

  @override
  Future<AnalyticsPreferenceResult> save(
    AnalyticsUsagePreference preference,
  ) async {
    saveCalls += 1;
    savedPreferences.add(preference);
    if (throwOnSave) throw StateError('adult@example.com private-write-error');
    return saveResults.isEmpty
        ? AnalyticsPreferenceSucceeded(preference)
        : saveResults.removeAt(0);
  }
}

final class _FakeAnalyticsSink implements AnalyticsSink {
  const _FakeAnalyticsSink();

  @override
  AnalyticsSinkAvailability get availability =>
      AnalyticsSinkAvailability.unavailable;

  @override
  Future<void> emit(AnalyticsEnvelope envelope) async {}
}
