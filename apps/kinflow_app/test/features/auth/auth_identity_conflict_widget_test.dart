import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/presentation/providers/legal_support_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  testWidgets(
    'identity conflict stays generic and explicit retry is single-flight',
    (WidgetTester tester) async {
      final FakeAuthSignInLauncher signInLauncher = FakeAuthSignInLauncher(
        results: const <AuthSignInRequestResult>[
          AuthSignInRequestFailed(
            AuthFailure(AuthFailureKind.identityConflict),
          ),
          AuthSignInRequestStarted(),
        ],
      );
      final ProviderContainer container = await _pumpSignIn(
        tester,
        signInLauncher: signInLauncher,
        supportLauncher: _FakeLegalSupportResourceLauncher(),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auth.identityConflict')), findsOneWidget);
      expect(
        find.text('This account cannot be connected automatically'),
        findsOneWidget,
      );
      expect(find.textContaining('existing-account@example.com'), findsNothing);
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.textContaining('Apple'), findsNothing);

      final FilledButton retry = tester.widget<FilledButton>(
        find.byKey(const Key('auth.identityConflict.retry')),
      );
      retry.onPressed!();
      retry.onPressed!();
      await container
          .read(authLifecycleControllerProvider)
          .waitForPendingOperations();
      await tester.pump();

      expect(signInLauncher.requestCount, 2);
      expect(find.byKey(const Key('auth.identityConflict')), findsNothing);
      expect(find.text('Connecting to Google'), findsWidgets);
    },
  );

  testWidgets('support launch is single-flight and hides raw failures', (
    WidgetTester tester,
  ) async {
    final Completer<LegalSupportResourceLaunchResult> support =
        Completer<LegalSupportResourceLaunchResult>();
    final _FakeLegalSupportResourceLauncher supportLauncher =
        _FakeLegalSupportResourceLauncher(callback: () => support.future);
    await _pumpSignIn(
      tester,
      signInLauncher: FakeAuthSignInLauncher(
        results: const <AuthSignInRequestResult>[
          AuthSignInRequestFailed(
            AuthFailure(AuthFailureKind.identityConflict),
          ),
        ],
      ),
      supportLauncher: supportLauncher,
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth.identityConflict.support')));
    await tester.pump();

    expect(supportLauncher.launchCount, 1);
    expect(supportLauncher.resources, <LegalSupportResource>[
      LegalSupportResource.support,
    ]);
    final OutlinedButton pending = tester.widget<OutlinedButton>(
      find.byKey(const Key('auth.identityConflict.support')),
    );
    expect(pending.onPressed, isNull);

    support.complete(LegalSupportResourceLaunchResult.failed);
    await tester.pumpAndSettle();

    expect(
      find.text('Support could not be opened. Try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('support-token'), findsNothing);
  });

  testWidgets('support success is stable and contains no account context', (
    WidgetTester tester,
  ) async {
    final _FakeLegalSupportResourceLauncher supportLauncher =
        _FakeLegalSupportResourceLauncher(
          result: LegalSupportResourceLaunchResult.opened,
        );
    await _pumpSignIn(
      tester,
      signInLauncher: FakeAuthSignInLauncher(
        results: const <AuthSignInRequestResult>[
          AuthSignInRequestFailed(
            AuthFailure(AuthFailureKind.identityConflict),
          ),
        ],
      ),
      supportLauncher: supportLauncher,
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth.identityConflict.support')));
    await tester.pumpAndSettle();

    expect(find.text('Support opened outside KinFlow.'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('household'), findsNothing);
  });

  testWidgets('pseudo locale remains scrollable at compact 200 percent text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpSignIn(
      tester,
      locale: const Locale('en', 'XA'),
      signInLauncher: FakeAuthSignInLauncher(
        results: const <AuthSignInRequestResult>[
          AuthSignInRequestFailed(
            AuthFailure(AuthFailureKind.identityConflict),
          ),
        ],
      ),
      supportLauncher: _FakeLegalSupportResourceLauncher(),
    );
    await tester.ensureVisible(find.byKey(const Key('auth.signIn.google')));
    await tester.tap(find.byKey(const Key('auth.signIn.google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth.identityConflict')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('auth.identityConflict.support')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('auth.identityConflict.retry')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('auth.identityConflict.support')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpSignIn(
  WidgetTester tester, {
  required AuthSignInLauncher signInLauncher,
  required LegalSupportResourceLauncher supportLauncher,
  Locale locale = const Locale('en'),
}) async {
  final FakeAuthSessionRepository repository = FakeAuthSessionRepository();
  addTearDown(repository.close);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      authSignInLauncherProvider.overrideWithValue(signInLauncher),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        RecordingSensitiveLocalStatePurger(),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        const UnavailableActiveHouseholdSnapshotWriter(),
      ),
      householdRepositoryProvider.overrideWithValue(FakeHouseholdRepository()),
      legalSupportResourceLauncherProvider.overrideWithValue(supportLauncher),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SignInScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

final class _FakeLegalSupportResourceLauncher
    implements LegalSupportResourceLauncher {
  _FakeLegalSupportResourceLauncher({
    this.result = LegalSupportResourceLaunchResult.unavailable,
    this.callback,
  });

  final LegalSupportResourceLaunchResult result;
  final Future<LegalSupportResourceLaunchResult> Function()? callback;
  final List<LegalSupportResource> resources = <LegalSupportResource>[];
  int launchCount = 0;

  @override
  Future<LegalSupportResourceLaunchResult> launch(
    LegalSupportResource resource,
  ) async {
    launchCount += 1;
    resources.add(resource);
    return callback == null ? result : callback!();
  }
}
