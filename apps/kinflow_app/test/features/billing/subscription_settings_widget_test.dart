import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:kinflow_app/features/billing/presentation/screens/subscription_settings_screen.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_controller.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_profile_preferences_dependencies.dart';
import '../../support/fakes/fake_subscription_dependencies.dart';

void main() {
  testWidgets('Owner sees exact Store terms and confirms household purchase', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness();
    await _pumpScreen(tester, harness);

    expect(find.text('Kim family'), findsOneWidget);
    expect(find.text('₩4,900 · every month'), findsOneWidget);
    expect(find.textContaining('kinflow.plus.monthly'), findsNothing);
    expect(find.textContaining(r'$rc_monthly'), findsNothing);

    final Finder purchase = find.byKey(const Key('subscription.purchase.0'));
    await tester.ensureVisible(purchase);
    await tester.tap(purchase);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('subscription.confirmPurchase')),
      findsOneWidget,
    );
    expect(find.textContaining('Kim family'), findsWidgets);
    expect(find.textContaining('₩4,900'), findsWidgets);
    expect(find.textContaining('server confirmation'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('subscription.confirmPurchase.submit')),
    );
    await tester.pumpAndSettle();

    expect(harness.port.purchaseRequests, hasLength(1));
    expect(
      harness.port.purchaseRequests.single.context.householdId,
      subscriptionTestHouseholdId,
    );
    expect(find.byKey(const Key('subscription.notice')), findsOneWidget);
    expect(find.textContaining('cancelled'), findsOneWidget);
  });

  testWidgets('Member can inspect status but cannot purchase or restore', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness();
    await _pumpScreen(
      tester,
      harness,
      profile: profilePreferencesFixture(role: ProfileHouseholdRole.member),
    );

    expect(find.byKey(const Key('subscription.adminRequired')), findsOneWidget);
    final FilledButton purchase = tester.widget<FilledButton>(
      find.byKey(const Key('subscription.purchase.0')),
    );
    final OutlinedButton restore = tester.widget<OutlinedButton>(
      find.byKey(const Key('subscription.restore')),
    );
    expect(purchase.onPressed, isNull);
    expect(restore.onPressed, isNull);
    expect(harness.port.purchaseRequests, isEmpty);
    expect(harness.port.restoreContexts, isEmpty);
  });

  testWidgets('server Plus billing owner opens the matching Store manager', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness(
      entitlementResults: <EntitlementResult<HouseholdEntitlement>>[
        EntitlementSucceeded<HouseholdEntitlement>(
          subscriptionPlusEntitlementFixture(),
        ),
      ],
    );
    final FakeBillingExternalLinkLauncher launcher =
        FakeBillingExternalLinkLauncher();
    await _pumpScreen(tester, harness, externalLauncher: launcher);

    expect(find.text('Plus'), findsOneWidget);
    expect(find.byKey(const Key('subscription.purchase.0')), findsNothing);
    expect(find.byKey(const Key('subscription.restore')), findsNothing);
    await tester.tap(find.byKey(const Key('subscription.manage')));
    await tester.pump();

    expect(launcher.links, <BillingExternalLink>[
      BillingExternalLink.googlePlaySubscriptions,
    ]);
  });

  testWidgets(
    'pending Store state hides duplicate actions and offers refresh',
    (WidgetTester tester) async {
      final SubscriptionTestHarness harness = SubscriptionTestHarness(
        purchaseResult: const BillingPurchasePending(),
      );
      await _pumpScreen(tester, harness);

      final Finder purchase = find.byKey(const Key('subscription.purchase.0'));
      await tester.ensureVisible(purchase);
      await tester.tap(purchase);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('subscription.confirmPurchase.submit')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subscription.pending')), findsOneWidget);
      expect(find.byKey(const Key('subscription.purchase.0')), findsNothing);
      expect(find.byKey(const Key('subscription.restore')), findsNothing);
      expect(find.byKey(const Key('subscription.refresh')), findsOneWidget);
      expect(harness.port.purchaseRequests, hasLength(1));
    },
  );

  testWidgets('assignment conflict stops before Store and opens review', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness(
      prepareOutcome: BillingAssignmentPrepareOutcome.householdConflict,
    );
    await _pumpScreen(tester, harness);

    final Finder purchase = find.byKey(const Key('subscription.purchase.0'));
    await tester.ensureVisible(purchase);
    await tester.tap(purchase);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('subscription.confirmPurchase.submit')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription.conflict')), findsOneWidget);
    expect(harness.port.purchaseRequests, isEmpty);
    expect(find.textContaining('billing identifier'), findsOneWidget);

    final Finder remediation = find.byKey(
      const Key('subscription.remediation'),
    );
    await tester.ensureVisible(remediation);
    await tester.tap(remediation);
    await tester.pumpAndSettle();

    expect(harness.assignmentRepository.remediationCount, 1);
    expect(find.textContaining('review request is open'), findsOneWidget);
  });

  testWidgets('empty restore is distinct and returns to safe options', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness();
    await _pumpScreen(tester, harness);

    final Finder restore = find.byKey(const Key('subscription.restore'));
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('subscription.confirmRestore.submit')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription.restoreEmpty')), findsOneWidget);
    expect(harness.port.restoreContexts, hasLength(1));
    await tester.tap(find.byKey(const Key('subscription.return')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscription.restore')), findsOneWidget);
  });

  testWidgets('catalog failure preserves server status without offers', (
    WidgetTester tester,
  ) async {
    final SubscriptionTestHarness harness = SubscriptionTestHarness(
      catalogResult: const BillingCatalogFailed(
        BillingFailure(BillingFailureKind.catalogUnavailable),
      ),
    );
    await _pumpScreen(tester, harness);

    expect(find.byKey(const Key('subscription.statusCard')), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('No billing owner'), findsOneWidget);
    expect(
      find.byKey(const Key('subscription.storeUnavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('subscription.purchase.0')), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('subscription.restore')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('controls remain usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    final SubscriptionTestHarness harness = SubscriptionTestHarness();
    await _pumpScreen(tester, harness, locale: const Locale('en', 'XA'));

    final Finder purchase = find.byKey(const Key('subscription.purchase.0'));
    await tester.ensureVisible(purchase);
    await tester.pump();
    expect(tester.getSize(purchase).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  SubscriptionTestHarness harness, {
  ProfilePreferences? profile,
  FakeBillingExternalLinkLauncher? externalLauncher,
  Locale locale = const Locale('en'),
}) async {
  if (locale != const Locale('en', 'XA')) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);
  }
  final FakeProfilePreferencesRepository profileRepository =
      FakeProfilePreferencesRepository(
        loadResult: ProfilePreferencesSucceeded(
          profile ?? profilePreferencesFixture(),
        ),
      );
  final ProfilePreferencesController profileController =
      ProfilePreferencesController(
        profileRepository,
        FakeProfileLocalePreferenceSink(),
      );
  await profileController.synchronize('subscription-test-scope');
  await harness.ready();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      billingFlowControllerProvider.overrideWithValue(harness.controller),
      billingExternalLinkLauncherProvider.overrideWithValue(
        externalLauncher ?? FakeBillingExternalLinkLauncher(),
      ),
      profilePreferencesControllerProvider.overrideWithValue(profileController),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await harness.dispose();
    await profileController.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SubscriptionSettingsScreen(),
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
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
