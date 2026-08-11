import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  testWidgets(
    'requests a generic code and verifies without rendering secrets',
    (WidgetTester tester) async {
      final _FakeEmailOtpService service = _FakeEmailOtpService();
      await _pumpSignIn(tester, service: service);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const Key('auth.email.address')), findsOneWidget);
      expect(find.byKey(const Key('auth.brandMark')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('auth.email.entry'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('auth.signIn.google'))).dy,
        ),
      );
      final TextField emailField = tester.widget<TextField>(
        find.byKey(const Key('auth.email.address')),
      );
      expect(emailField.decoration?.helperMaxLines, 100);
      await tester.enterText(
        find.byKey(const Key('auth.email.address')),
        ' Adult.User@Example.COM ',
      );
      await tester.tap(find.byKey(const Key('auth.email.send')));
      await tester.pumpAndSettle();

      expect(service.requestCount, 1);
      expect(service.requestedEmails.single.value, 'adult.user@example.com');
      expect(find.byKey(const Key('auth.email.code')), findsOneWidget);
      expect(find.textContaining('a•••@example.com'), findsOneWidget);
      expect(find.textContaining('adult.user@example.com'), findsNothing);
      expect(find.textContaining('If this address can be used'), findsNothing);

      await tester.enterText(find.byKey(const Key('auth.email.otp')), '123456');
      await tester.tap(find.byKey(const Key('auth.email.verify')));
      await tester.pump();

      expect(service.verifyCount, 1);
      expect(service.verifiedCodes.single.value, '123456');
      expect(find.byKey(const Key('auth.email.verified')), findsOneWidget);
      expect(find.text('123456'), findsNothing);
      expect(find.textContaining('adult.user@example.com'), findsNothing);
    },
  );

  testWidgets('invalid email and malformed code fail before provider I/O', (
    WidgetTester tester,
  ) async {
    final _FakeEmailOtpService service = _FakeEmailOtpService();
    await _pumpSignIn(tester, service: service);

    await tester.enterText(
      find.byKey(const Key('auth.email.address')),
      'invalid email',
    );
    await tester.tap(find.byKey(const Key('auth.email.send')));
    await tester.pump();

    expect(service.requestCount, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth.email.address')),
      'adult@example.com',
    );
    await tester.tap(find.byKey(const Key('auth.email.send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth.email.otp')), '12345');
    await tester.tap(find.byKey(const Key('auth.email.verify')));
    await tester.pump();

    expect(service.verifyCount, 0);
    expect(find.text('Enter the newest valid 6-digit code.'), findsOneWidget);
  });

  testWidgets('request is single-flight and disables competing actions', (
    WidgetTester tester,
  ) async {
    final Completer<AuthEmailOtpRequestResult> pending =
        Completer<AuthEmailOtpRequestResult>();
    final _FakeEmailOtpService service = _FakeEmailOtpService(
      requestCallback: (_) => pending.future,
    );
    await _pumpSignIn(tester, service: service);
    await tester.enterText(
      find.byKey(const Key('auth.email.address')),
      'adult@example.com',
    );

    final FilledButton send = tester.widget<FilledButton>(
      find.byKey(const Key('auth.email.send')),
    );
    send.onPressed!();
    send.onPressed!();
    await tester.pump();

    expect(service.requestCount, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('auth.inviteCode')))
          .onPressed,
      isNull,
    );
    pending.complete(const AuthEmailOtpRequestAccepted());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth.email.code')), findsOneWidget);
  });

  testWidgets(
    'incorrect code is retryable and raw provider data stays hidden',
    (WidgetTester tester) async {
      var verificationAttempt = 0;
      final _FakeEmailOtpService service = _FakeEmailOtpService(
        verificationCallback: ({required email, required code}) {
          verificationAttempt += 1;
          return verificationAttempt == 1
              ? const AuthEmailOtpVerificationFailed(
                  AuthEmailOtpFailure(AuthEmailOtpFailureKind.invalidCode),
                )
              : AuthEmailOtpVerified(authSessionFixture());
        },
      );
      await _pumpSignIn(tester, service: service);
      await _requestCode(tester);

      await tester.enterText(find.byKey(const Key('auth.email.otp')), '111111');
      await tester.tap(find.byKey(const Key('auth.email.verify')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the newest valid 6-digit code.'), findsOneWidget);
      expect(find.textContaining('provider-token'), findsNothing);
      expect(find.byKey(const Key('auth.email.otp')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('auth.email.otp')), '222222');
      await tester.tap(find.byKey(const Key('auth.email.verify')));
      await tester.pump();
      expect(find.byKey(const Key('auth.email.verified')), findsOneWidget);
    },
  );

  testWidgets(
    'early resend is locally rate limited and change email recovers',
    (WidgetTester tester) async {
      final _FakeEmailOtpService service = _FakeEmailOtpService();
      await _pumpSignIn(tester, service: service);
      await _requestCode(tester);

      await tester.tap(find.byKey(const Key('auth.email.resend')));
      await tester.pump();

      expect(service.requestCount, 1);
      expect(
        find.text('Please wait before requesting or checking another code.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('auth.email.change')));
      await tester.tap(find.byKey(const Key('auth.email.change')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth.email.address')), findsOneWidget);
      expect(find.byKey(const Key('auth.email.otp')), findsNothing);
    },
  );

  testWidgets('provider failure is localized in Korean without raw details', (
    WidgetTester tester,
  ) async {
    final _FakeEmailOtpService service = _FakeEmailOtpService(
      requestCallback: (_) => const AuthEmailOtpRequestFailed(
        AuthEmailOtpFailure(AuthEmailOtpFailureKind.temporarilyUnavailable),
      ),
    );
    await _pumpSignIn(tester, service: service, locale: const Locale('ko'));
    await tester.enterText(
      find.byKey(const Key('auth.email.address')),
      'adult@example.com',
    );
    await tester.tap(find.byKey(const Key('auth.email.send')));
    await tester.pumpAndSettle();

    expect(
      find.text('현재 이메일 로그인을 사용할 수 없습니다. 나중에 다시 시도해 주세요.'),
      findsOneWidget,
    );
    expect(find.textContaining('provider-token'), findsNothing);
  });

  testWidgets('expanded sign-in uses a branded two-column composition', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSignIn(tester, service: _FakeEmailOtpService());

    expect(find.byKey(const Key('auth.signIn.expanded')), findsOneWidget);
    expect(find.byKey(const Key('auth.signIn.compact')), findsNothing);
    final Finder brand = find.byKey(const Key('auth.brandMark'));
    final Finder panel = find.byKey(const Key('auth.signIn.panel'));
    expect(tester.getCenter(brand).dx, lessThan(tester.getCenter(panel).dx));
    expect(tester.getSize(panel).width, 480);

    final double shortBar = tester
        .getSize(find.byKey(const Key('auth.brandBar.1')))
        .height;
    final double tallBar = tester
        .getSize(find.byKey(const Key('auth.brandBar.2')))
        .height;
    final double middleBar = tester
        .getSize(find.byKey(const Key('auth.brandBar.3')))
        .height;
    expect(tallBar, greaterThan(middleBar));
    expect(middleBar, greaterThan(shortBar));
  });

  testWidgets('dark expanded sign-in keeps hero text contrast', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSignIn(
      tester,
      service: _FakeEmailOtpService(),
      theme: AppTheme.dark,
    );

    final Finder heroFinder = find.byKey(const Key('auth.signIn.heroSurface'));
    final DecoratedBox hero = tester.widget<DecoratedBox>(heroFinder);
    final BoxDecoration decoration = hero.decoration as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    final Color foreground = AppTheme.dark.colorScheme.onSurface;

    expect(gradient.colors, const <Color>[
      AppBrandColors.darkPrimaryContainer,
      AppBrandColors.darkMintContainer,
    ]);
    for (final Color background in gradient.colors) {
      expect(
        _contrastRatio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground on dark hero $background',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('pseudo locale flow is scrollable at compact 200 percent', (
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
      service: _FakeEmailOtpService(),
      locale: const Locale('en', 'XA'),
    );

    await tester.ensureVisible(find.byKey(const Key('auth.email.address')));
    await tester.enterText(
      find.byKey(const Key('auth.email.address')),
      'adult@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('auth.email.send')));
    expect(
      tester.getSize(find.byKey(const Key('auth.email.send'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('auth.email.send')));
    await tester.pumpAndSettle();

    for (final String key in <String>[
      'auth.email.verify',
      'auth.email.resend',
      'auth.email.change',
    ]) {
      final Finder action = find.byKey(Key(key));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google identity conflict keeps OTP out of recovery surface', (
    WidgetTester tester,
  ) async {
    final FakeAuthSignInLauncher google = FakeAuthSignInLauncher(
      results: const <AuthSignInRequestResult>[
        AuthSignInRequestFailed(AuthFailure(AuthFailureKind.identityConflict)),
      ],
    );
    await _pumpSignIn(
      tester,
      service: _FakeEmailOtpService(),
      signInLauncher: google,
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth.identityConflict')), findsOneWidget);
    expect(find.byKey(const Key('auth.email.entry')), findsNothing);
    expect(find.byKey(const Key('auth.email.code')), findsNothing);
  });
}

Future<void> _requestCode(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('auth.email.address')),
    'adult@example.com',
  );
  await tester.tap(find.byKey(const Key('auth.email.send')));
  await tester.pumpAndSettle();
}

Future<void> _pumpSignIn(
  WidgetTester tester, {
  required AuthEmailOtpService service,
  Locale locale = const Locale('en'),
  AuthSignInLauncher? signInLauncher,
  ThemeData? theme,
}) async {
  final FakeAuthSessionRepository repository = FakeAuthSessionRepository();
  addTearDown(repository.close);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      authSignInLauncherProvider.overrideWithValue(
        signInLauncher ?? FakeAuthSignInLauncher(),
      ),
      authEmailOtpServiceProvider.overrideWithValue(service),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        RecordingSensitiveLocalStatePurger(),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        const UnavailableActiveHouseholdSnapshotWriter(),
      ),
      householdRepositoryProvider.overrideWithValue(FakeHouseholdRepository()),
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
        theme: theme,
        home: const SignInScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _contrastRatio(Color foreground, Color background) {
  final double foregroundLuminance = foreground.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

typedef _RequestCallback =
    FutureOr<AuthEmailOtpRequestResult> Function(AuthEmailAddress email);
typedef _VerificationCallback =
    FutureOr<AuthEmailOtpVerificationResult> Function({
      required AuthEmailAddress email,
      required AuthEmailOtpCode code,
    });

final class _FakeEmailOtpService implements AuthEmailOtpService {
  _FakeEmailOtpService({this.requestCallback, this.verificationCallback});

  final _RequestCallback? requestCallback;
  final _VerificationCallback? verificationCallback;
  final List<AuthEmailAddress> requestedEmails = <AuthEmailAddress>[];
  final List<AuthEmailOtpCode> verifiedCodes = <AuthEmailOtpCode>[];
  var requestCount = 0;
  var verifyCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<AuthEmailOtpRequestResult> requestCode(AuthEmailAddress email) async {
    requestCount += 1;
    requestedEmails.add(email);
    return await requestCallback?.call(email) ??
        const AuthEmailOtpRequestAccepted();
  }

  @override
  Future<AuthEmailOtpVerificationResult> verifyCode({
    required AuthEmailAddress email,
    required AuthEmailOtpCode code,
  }) async {
    verifyCount += 1;
    verifiedCodes.add(code);
    return await verificationCallback?.call(email: email, code: code) ??
        AuthEmailOtpVerified(authSessionFixture());
  }
}
