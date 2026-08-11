import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/diagnostic_report_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/diagnostic_report_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_diagnostic_dependencies.dart';

void main() {
  testWidgets('previews only allowlisted fields and copies exact safe JSON', (
    WidgetTester tester,
  ) async {
    final DiagnosticReport report = diagnosticReportFixture();
    final FakeDiagnosticClipboard clipboard = FakeDiagnosticClipboard();
    await _pumpScreen(tester, report: report, clipboard: clipboard);

    for (final String value in <String>[
      report.appBuild.applicationId,
      report.appBuild.version,
      report.appBuild.buildNumber,
      report.environment.wireValue,
      report.contractVersion,
      report.devicePlatform.wireValue,
      report.incidentId.value,
      report.generatedAt.toIso8601String(),
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(find.textContaining('adult@example.com'), findsNothing);
    expect(find.textContaining('household-secret'), findsNothing);
    expect(find.textContaining('device-model-secret'), findsNothing);
    expect(
      find.textContaining('may be recorded in PII-filtered app diagnostics'),
      findsOneWidget,
    );

    final Finder copy = find.byKey(const Key('diagnostics.copy'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();

    expect(clipboard.writes, <String>[report.toClipboardText()]);
    expect(jsonDecode(clipboard.writes.single), equals(report.toSafeJson()));
    final Finder status = find.byKey(const Key('diagnostics.status.copied'));
    expect(status, findsOneWidget);
    final Finder liveRegion = find.descendant(
      of: status,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion, findsWidgets);
  });

  testWidgets('clipboard failure is recoverable without replacing report', (
    WidgetTester tester,
  ) async {
    final DiagnosticReport report = diagnosticReportFixture();
    final FakeDiagnosticClipboard clipboard = FakeDiagnosticClipboard(
      results: <bool>[false, true],
    );
    await _pumpScreen(tester, report: report, clipboard: clipboard);

    final Finder copy = find.byKey(const Key('diagnostics.copy'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diagnostics.status.copyFailed')),
      findsOneWidget,
    );
    expect(find.text(report.incidentId.value), findsOneWidget);

    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostics.status.copied')), findsOneWidget);
    expect(clipboard.writes, hasLength(2));
  });

  testWidgets('initial metadata failure can retry to a complete report', (
    WidgetTester tester,
  ) async {
    final DiagnosticReport report = diagnosticReportFixture();
    final FakeDiagnosticReportRepository repository =
        FakeDiagnosticReportRepository(
          results: <DiagnosticReportResult>[
            const DiagnosticReportFailed(
              DiagnosticReportFailure(
                DiagnosticReportFailureKind.invalidMetadata,
              ),
            ),
            DiagnosticReportSucceeded(report),
          ],
        );
    await _pumpScreen(
      tester,
      repository: repository,
      clipboard: FakeDiagnosticClipboard(),
    );

    expect(find.byKey(const Key('diagnostics.error')), findsOneWidget);
    expect(find.textContaining('does not match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('diagnostics.retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostics.report')), findsOneWidget);
    expect(find.text(report.incidentId.value), findsOneWidget);
    expect(repository.createCalls, 2);
  });

  testWidgets('Korean locale explains included and excluded data', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      report: diagnosticReportFixture(),
      clipboard: FakeDiagnosticClipboard(),
      locale: const Locale('ko'),
    );

    expect(find.text('포함되는 정보'), findsOneWidget);
    expect(find.text('포함되지 않는 정보'), findsOneWidget);
    expect(find.text('진단 정보 복사'), findsOneWidget);
  });

  testWidgets('pseudo locale stays scrollable at 200 percent text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      report: diagnosticReportFixture(),
      clipboard: FakeDiagnosticClipboard(),
      locale: const Locale('en', 'XA'),
      configureDefaultView: false,
    );

    final Finder copy = find.byKey(const Key('diagnostics.copy'));
    await tester.ensureVisible(copy);
    await tester.pump();
    expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings tile navigates to the protected diagnostics route', (
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
          path: AppRoutes.diagnostics,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: Key('diagnostics.routeTarget')),
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

    final Finder tile = find.byKey(const Key('settings.diagnostics'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.diagnostics);
    expect(find.byKey(const Key('diagnostics.routeTarget')), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiagnosticReport? report,
  DiagnosticReportRepository? repository,
  required DiagnosticClipboard clipboard,
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
        diagnosticReportRepositoryProvider.overrideWithValue(
          repository ??
              FakeDiagnosticReportRepository(
                results: <DiagnosticReportResult>[
                  DiagnosticReportSucceeded(
                    report ?? diagnosticReportFixture(),
                  ),
                ],
              ),
        ),
        diagnosticClipboardProvider.overrideWithValue(clipboard),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DiagnosticReportScreen(),
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
