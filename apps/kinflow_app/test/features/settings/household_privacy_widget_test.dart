import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_controller.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/household_privacy_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_data_export_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_household_privacy_dependencies.dart';

void main() {
  testWidgets('Owner confirms and queues a household export', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository();
    await _pumpScreen(tester, repository);

    final Finder request = find.byKey(
      const Key('householdPrivacy.requestExport'),
    );
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(find.text('Create a household export?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('householdPrivacy.exportConfirm.submit')),
    );
    await tester.pumpAndSettle();

    expect(repository.exportCalls, hasLength(1));
    expect(find.byKey(const Key('householdPrivacy.status')), findsOneWidget);
    expect(find.text('Queued during the cancellation window'), findsOneWidget);
  });

  testWidgets('deletion requires exact name and every relevant impact', (
    WidgetTester tester,
  ) async {
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository(
          preflightResult: HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(
            householdPrivacyPreflightFixture(activeSubscription: true),
          ),
        );
    await _pumpScreen(tester, repository);

    final Finder request = find.byKey(
      const Key('householdPrivacy.requestDeletion'),
    );
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();

    final Finder submit = find.byKey(
      const Key('householdPrivacy.delete.submit'),
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('householdPrivacy.delete.name')),
      'Kim family',
    );
    for (final String key in <String>[
      'householdPrivacy.delete.memberAck',
      'householdPrivacy.delete.redactionAck',
      'householdPrivacy.delete.subscriptionAck',
    ]) {
      final Finder acknowledgment = find.byKey(Key(key));
      await tester.ensureVisible(acknowledgment);
      await tester.pumpAndSettle();
      await tester.tap(acknowledgment);
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.deletionCalls, hasLength(1));
    expect(repository.deletionCalls.single.confirmationName, 'Kim family');
    expect(
      repository.deletionCalls.single.acknowledgeSubscriptionNotCancelled,
      isTrue,
    );
  });

  testWidgets('completed export opens one-time download and can be revoked', (
    WidgetTester tester,
  ) async {
    final HouseholdPrivacyRequest completed = householdPrivacyRequestFixture(
      status: HouseholdPrivacyRequestStatus.completed,
      artifactAvailable: true,
      version: 3,
    );
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository(
          exportResults: <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
            HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(completed),
          ],
        );
    final FakeDataExportDownloadLauncher launcher =
        FakeDataExportDownloadLauncher();
    await _pumpScreen(tester, repository, launcher: launcher);

    final Finder request = find.byKey(
      const Key('householdPrivacy.requestExport'),
    );
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('householdPrivacy.exportConfirm.submit')),
    );
    await tester.pumpAndSettle();

    final Finder download = find.byKey(
      const Key('householdPrivacy.downloadJson'),
    );
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(repository.downloadCalls.single.format, HouseholdExportFormat.json);
    expect(launcher.launchedUris, hasLength(1));
    expect(find.byKey(const Key('householdPrivacy.opened')), findsOneWidget);

    final Finder revoke = find.byKey(const Key('householdPrivacy.revoke'));
    await tester.ensureVisible(revoke);
    await tester.pumpAndSettle();
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('householdPrivacy.revokeConfirm.submit')),
    );
    await tester.pumpAndSettle();
    expect(repository.revokeCalls, hasLength(1));
    expect(find.byKey(const Key('householdPrivacy.downloads')), findsNothing);
  });

  testWidgets('controls remain usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      FakeHouseholdPrivacyRepository(),
      locale: const Locale('en', 'XA'),
    );

    final Finder request = find.byKey(
      const Key('householdPrivacy.requestExport'),
    );
    await tester.ensureVisible(request);
    await tester.pump();
    expect(tester.getSize(request).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeHouseholdPrivacyRepository repository, {
  FakeDataExportDownloadLauncher? launcher,
  Locale locale = const Locale('en'),
}) async {
  final HouseholdPrivacyController controller = HouseholdPrivacyController(
    repository,
    FakeHouseholdCommandIdGenerator(),
    FakeRecentAuthenticationService(),
    launcher ?? FakeDataExportDownloadLauncher(),
    householdPrivacyHouseholdFixture().id,
    () async {},
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      householdPrivacyControllerProvider.overrideWithValue(controller),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    unawaited(controller.dispose());
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HouseholdPrivacyScreen(),
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
