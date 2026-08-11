import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/account_deletion_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/account_deletion_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_account_deletion_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  testWidgets(
    'active subscription acknowledgement gates request and accepted request logs out',
    (WidgetTester tester) async {
      final AccountDeletionRequest accepted = accountDeletionRequestFixture(
        activeSubscriptionAtRequest: true,
      );
      final FakeAccountDeletionRepository repository =
          FakeAccountDeletionRepository(
            preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
              accountDeletionPreflightFixture(hasActiveSubscription: true),
            ),
            requestResults: <AccountDeletionResult<AccountDeletionRequest>>[
              AccountDeletionSucceeded<AccountDeletionRequest>(accepted),
            ],
          );
      var acceptedHandlerCount = 0;
      await _pumpScreen(
        tester,
        repository,
        onAccepted: () async => acceptedHandlerCount += 1,
      );

      expect(
        find.byKey(const Key('accountDeletion.subscription')),
        findsOneWidget,
      );
      final Finder request = find.byKey(const Key('accountDeletion.request'));
      await tester.ensureVisible(request);
      await tester.pump();
      expect(tester.widget<FilledButton>(request).onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('accountDeletion.subscriptionAcknowledgement')),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(request).onPressed, isNotNull);

      await tester.tap(request);
      await tester.pumpAndSettle();
      expect(find.text('Schedule account deletion?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('accountDeletion.confirm.delete')));
      await tester.pumpAndSettle();

      expect(repository.requestCalls, hasLength(1));
      expect(repository.requestCalls.single.subscriptionAcknowledged, isTrue);
      expect(acceptedHandlerCount, 1);
      expect(find.byKey(const Key('accountDeletion.status')), findsOneWidget);
    },
  );

  testWidgets('queued request can be confirmed cancelled and requested again', (
    WidgetTester tester,
  ) async {
    final AccountDeletionRequest pending = accountDeletionRequestFixture();
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository(
          preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
            accountDeletionPreflightFixture(pendingRequest: pending),
          ),
          latestResult: AccountDeletionSucceeded<AccountDeletionRequest?>(
            pending,
          ),
        );
    await _pumpScreen(tester, repository);

    final Finder cancel = find.byKey(const Key('accountDeletion.cancel'));
    await tester.ensureVisible(cancel);
    await tester.pump();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('Cancel account deletion?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('accountDeletion.cancelConfirm.cancel')),
    );
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, hasLength(1));
    expect(find.text('Account deletion cancelled'), findsOneWidget);
    expect(find.byKey(const Key('accountDeletion.request')), findsOneWidget);
  });

  testWidgets('household owner receives a transfer-first blocker', (
    WidgetTester tester,
  ) async {
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository(
          preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
            accountDeletionPreflightFixture(ownerHouseholdCount: 2),
          ),
        );
    await _pumpScreen(tester, repository);

    expect(find.byKey(const Key('accountDeletion.ownerBlock')), findsOneWidget);
    expect(find.textContaining('2 active household'), findsOneWidget);
    final Finder request = find.byKey(const Key('accountDeletion.request'));
    await tester.ensureVisible(request);
    await tester.pump();
    expect(tester.widget<FilledButton>(request).onPressed, isNull);
  });

  testWidgets('deletion controls remain usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      FakeAccountDeletionRepository(),
      locale: const Locale('en', 'XA'),
    );

    final Finder request = find.byKey(const Key('accountDeletion.request'));
    await tester.ensureVisible(request);
    await tester.pump();
    expect(tester.getSize(request).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeAccountDeletionRepository repository, {
  Future<void> Function()? onAccepted,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repository),
        accountDeletionCommandIdGeneratorProvider.overrideWithValue(
          FakeAccountDeletionCommandIdGenerator(),
        ),
        recentAuthenticationServiceProvider.overrideWithValue(
          FakeRecentAuthenticationService(),
        ),
        accountDeletionAcceptedHandlerProvider.overrideWithValue(
          onAccepted ?? () async {},
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountDeletionScreen(),
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
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
