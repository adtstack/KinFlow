import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/presentation/providers/legal_support_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/legal_support_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('hub maps all external actions to enum-only destinations', (
    WidgetTester tester,
  ) async {
    final _FakeLegalSupportLauncher launcher = _FakeLegalSupportLauncher();
    await _pumpScreen(tester, launcher);

    expect(find.textContaining('https://'), findsNothing);
    expect(
      find.byKey(const Key('legalSupport.privacy.export')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('legalSupport.privacy.delete')),
      findsOneWidget,
    );

    for (final (Key key, LegalSupportResource expected)
        in <(Key, LegalSupportResource)>[
          (const Key('legalSupport.terms.open'), LegalSupportResource.terms),
          (
            const Key('legalSupport.privacy.open'),
            LegalSupportResource.privacy,
          ),
          (
            const Key('legalSupport.support.open'),
            LegalSupportResource.support,
          ),
        ]) {
      final Finder action = find.byKey(key);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(launcher.resources.last, expected);
      expect(
        find.byKey(const Key('legalSupport.status.opened')),
        findsOneWidget,
      );
    }

    expect(launcher.resources, <LegalSupportResource>[
      LegalSupportResource.terms,
      LegalSupportResource.privacy,
      LegalSupportResource.support,
    ]);
  });

  testWidgets('launch is single-flight and disables every external action', (
    WidgetTester tester,
  ) async {
    final Completer<LegalSupportResourceLaunchResult> pending =
        Completer<LegalSupportResourceLaunchResult>();
    final _FakeLegalSupportLauncher launcher = _FakeLegalSupportLauncher(
      pending: pending,
    );
    await _pumpScreen(tester, launcher);

    await tester.tap(find.byKey(const Key('legalSupport.terms.open')));
    await tester.pump();

    expect(
      find.byKey(const Key('legalSupport.status.opening')),
      findsOneWidget,
    );
    expect(launcher.resources, <LegalSupportResource>[
      LegalSupportResource.terms,
    ]);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('legalSupport.privacy.open')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('legalSupport.support.open')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(LegalSupportResourceLaunchResult.opened);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalSupport.status.opened')), findsOneWidget);
  });

  testWidgets('unavailable launch is recoverable and never records consent', (
    WidgetTester tester,
  ) async {
    final _FakeLegalSupportLauncher launcher = _FakeLegalSupportLauncher(
      results: <LegalSupportResourceLaunchResult>[
        LegalSupportResourceLaunchResult.unavailable,
        LegalSupportResourceLaunchResult.opened,
      ],
    );
    await _pumpScreen(tester, launcher);

    await tester.tap(find.byKey(const Key('legalSupport.terms.open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('legalSupport.status.failure')),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not grant or withdraw consent'),
      findsOneWidget,
    );

    final Finder privacy = find.byKey(const Key('legalSupport.privacy.open'));
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legalSupport.status.failure')), findsNothing);
    expect(find.byKey(const Key('legalSupport.status.opened')), findsOneWidget);
  });

  testWidgets('pseudo locale stays scrollable with 200 percent text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    final _FakeLegalSupportLauncher launcher = _FakeLegalSupportLauncher();
    await _pumpScreen(tester, launcher, locale: const Locale('en', 'XA'));

    final Finder support = find.byKey(const Key('legalSupport.support.open'));
    await tester.ensureVisible(support);
    await tester.pump();
    expect(tester.getSize(support).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeLegalSupportLauncher launcher, {
  Locale locale = const Locale('en'),
}) async {
  if (locale != const Locale('en', 'XA')) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legalSupportResourceLauncherProvider.overrideWithValue(launcher),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LegalSupportScreen(),
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

final class _FakeLegalSupportLauncher implements LegalSupportResourceLauncher {
  _FakeLegalSupportLauncher({
    this.pending,
    List<LegalSupportResourceLaunchResult>? results,
  }) : _results = results ?? <LegalSupportResourceLaunchResult>[];

  final Completer<LegalSupportResourceLaunchResult>? pending;
  final List<LegalSupportResourceLaunchResult> _results;
  final List<LegalSupportResource> resources = <LegalSupportResource>[];

  @override
  Future<LegalSupportResourceLaunchResult> launch(
    LegalSupportResource resource,
  ) async {
    resources.add(resource);
    final Completer<LegalSupportResourceLaunchResult>? pending = this.pending;
    if (pending != null) return pending.future;
    return _results.isEmpty
        ? LegalSupportResourceLaunchResult.opened
        : _results.removeAt(0);
  }
}
