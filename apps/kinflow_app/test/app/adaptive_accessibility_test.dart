import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/providers/foundation_dependencies.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../support/fakes/fake_auth_dependencies.dart';
import '../support/fakes/fake_foundation_repository.dart';

void main() {
  const List<({String key, Size size})> layoutScenarios =
      <({String key, Size size})>[
        (key: 'layout.compact', size: Size(390, 844)),
        (key: 'layout.medium', size: Size(700, 800)),
        (key: 'layout.expanded', size: Size(1200, 800)),
      ];

  for (final ({String key, Size size}) scenario in layoutScenarios) {
    testWidgets('selects ${scenario.key} from available width', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, size: scenario.size);

      expect(find.byKey(Key(scenario.key)), findsOneWidget);
      if (scenario.key == 'layout.compact') {
        expect(find.byKey(const Key('layout.primaryNavigation')), findsNothing);
      } else {
        expect(
          find.byKey(const Key('layout.primaryNavigation')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('exposes headings, navigation, status, and retry semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await _pumpApp(tester, size: const Size(1200, 800));

      expect(find.semantics.byLabel('Primary navigation'), findsOne);
      expect(
        tester.getSemantics(find.byKey(const Key('layout.pageHeading'))),
        isSemantics(label: 'KinFlow', isHeader: true),
      );
      expect(
        tester.getSemantics(find.text('KinFlow is ready')),
        isSemantics(label: 'KinFlow is ready', isHeader: true),
      );

      await _pumpApp(
        tester,
        size: const Size(390, 844),
        repository: FakeFoundationRepository(
          results: <LoadFoundationResult>[
            const FoundationLoadFailed(FoundationUnavailable()),
          ],
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('foundation.retry'))),
        isSemantics(
          label: 'Try again',
          hint: 'Runs this check again',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  const List<({Locale locale, String layoutKey, Size size})> scaleScenarios =
      <({Locale locale, String layoutKey, Size size})>[
        (
          locale: Locale('ko'),
          layoutKey: 'layout.compact',
          size: Size(320, 568),
        ),
        (
          locale: Locale('en', 'XA'),
          layoutKey: 'layout.medium',
          size: Size(700, 600),
        ),
        (
          locale: Locale('en', 'XA'),
          layoutKey: 'layout.expanded',
          size: Size(1000, 700),
        ),
      ];

  for (final scenario in scaleScenarios) {
    testWidgets('${scenario.layoutKey} has no blocker overflow at 200% text', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        locale: scenario.locale,
        size: scenario.size,
        textScaleFactor: 2,
      );

      expect(find.byKey(Key(scenario.layoutKey)), findsOneWidget);
      expect(find.byKey(const Key('layout.scrollableStatus')), findsOneWidget);
      expect(find.byKey(const Key('foundation.ready')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry action remains at least 48dp at 200% text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      locale: const Locale('ko'),
      repository: FakeFoundationRepository(
        results: <LoadFoundationResult>[
          const FoundationLoadFailed(FoundationUnavailable()),
        ],
      ),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.ensureVisible(find.byKey(const Key('foundation.retry')));
    await tester.pump();
    final Size retrySize = tester.getSize(
      find.byKey(const Key('foundation.retry')),
    );

    expect(retrySize.width, greaterThanOrEqualTo(48));
    expect(retrySize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in remains scrollable at 200% text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      authenticated: false,
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    expect(find.byKey(const Key('auth.signIn')), findsOneWidget);
    expect(find.byKey(const Key('auth.signIn.google')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('auth.signIn.google')));
    expect(
      tester.getSize(find.byKey(const Key('auth.signIn.google'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('forced RTL mirrors the expanded rail without declaring Arabic', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(1200, 800));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'XA'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AppResponsiveScaffold(
            title: '[!! Adaptive title !!]',
            body: SizedBox.expand(key: Key('rtl.body')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect navigation = tester.getRect(
      find.byKey(const Key('layout.primaryNavigation')),
    );
    final Rect content = tester.getRect(
      find.byKey(const Key('layout.content')),
    );

    expect(
      Directionality.of(tester.element(find.byKey(const Key('rtl.body')))),
      TextDirection.rtl,
    );
    expect(navigation.left, greaterThan(content.left));
    expect(find.text('[!! Ĥômē page !!]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required Size size,
  bool authenticated = true,
  Locale? locale,
  FoundationRepository? repository,
  double textScaleFactor = 1,
}) async {
  _configureView(tester, size: size, textScaleFactor: textScaleFactor);
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: authenticated
        ? AuthSessionAvailable(authSessionFixture())
        : const AuthSessionAbsent(),
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
      foundationRepositoryProvider.overrideWithValue(
        repository ?? createFoundationRepository(),
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
  double textScaleFactor = 1,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _successfulInitialization() async {}
