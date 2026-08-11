import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/data_export_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/data_export_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_data_export_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  testWidgets('personal export requires confirmation and queues safely', (
    WidgetTester tester,
  ) async {
    final FakeDataExportRepository repository = FakeDataExportRepository();
    await _pumpScreen(tester, repository);

    final Finder request = find.byKey(const Key('dataExport.request'));
    await tester.ensureVisible(request);
    await tester.pump();
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(find.text('Create a personal export?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dataExport.confirm.create')));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, hasLength(1));
    expect(find.byKey(const Key('dataExport.status')), findsOneWidget);
    expect(find.text('Export queued'), findsOneWidget);
  });

  testWidgets('queued export can be confirmed cancelled', (
    WidgetTester tester,
  ) async {
    final DataExportRequest pending = dataExportRequestFixture();
    final FakeDataExportRepository repository = FakeDataExportRepository(
      preflightResult: DataExportSucceeded<DataExportPreflight>(
        dataExportPreflightFixture(pendingRequest: pending),
      ),
      latestResult: DataExportSucceeded<DataExportRequest?>(pending),
    );
    await _pumpScreen(tester, repository);

    final Finder cancel = find.byKey(const Key('dataExport.cancel'));
    await tester.ensureVisible(cancel);
    await tester.pump();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.text('Cancel this export?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dataExport.cancelConfirm.cancel')));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, hasLength(1));
    expect(find.text('Export request cancelled'), findsOneWidget);
    expect(find.byKey(const Key('dataExport.request')), findsOneWidget);
  });

  testWidgets('completed export opens one-time download and can be revoked', (
    WidgetTester tester,
  ) async {
    final DataExportRequest completed = dataExportRequestFixture(
      status: DataExportRequestStatus.completed,
      version: 3,
      artifactAvailable: true,
    );
    final FakeDataExportRepository repository = FakeDataExportRepository(
      latestResult: DataExportSucceeded<DataExportRequest?>(completed),
    );
    final FakeDataExportDownloadLauncher launcher =
        FakeDataExportDownloadLauncher();
    await _pumpScreen(tester, repository, launcher: launcher);

    final Finder download = find.byKey(const Key('dataExport.downloadJson'));
    await tester.ensureVisible(download);
    await tester.pump();
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(repository.downloadCalls.single.format, DataExportFormat.json);
    expect(launcher.launchedUris, hasLength(1));
    expect(find.byKey(const Key('dataExport.opened')), findsOneWidget);

    final Finder revoke = find.byKey(const Key('dataExport.revoke'));
    await tester.ensureVisible(revoke);
    await tester.pump();
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(find.text('Delete these export files now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dataExport.revokeConfirm.delete')));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, hasLength(1));
    expect(find.textContaining('revoked'), findsOneWidget);
    expect(find.byKey(const Key('dataExport.downloads')), findsNothing);
  });

  testWidgets('paused requests explain why creation is unavailable', (
    WidgetTester tester,
  ) async {
    final FakeDataExportRepository repository = FakeDataExportRepository(
      preflightResult: DataExportSucceeded<DataExportPreflight>(
        dataExportPreflightFixture(requestsEnabled: false),
      ),
    );
    await _pumpScreen(tester, repository);

    expect(find.byKey(const Key('dataExport.paused')), findsOneWidget);
    expect(find.byKey(const Key('dataExport.request')), findsNothing);
  });

  testWidgets('export controls remain usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      FakeDataExportRepository(),
      locale: const Locale('en', 'XA'),
    );

    final Finder request = find.byKey(const Key('dataExport.request'));
    await tester.ensureVisible(request);
    await tester.pump();
    expect(tester.getSize(request).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeDataExportRepository repository, {
  FakeDataExportDownloadLauncher? launcher,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataExportRepositoryProvider.overrideWithValue(repository),
        dataExportCommandIdGeneratorProvider.overrideWithValue(
          FakeDataExportCommandIdGenerator(),
        ),
        dataExportDownloadLauncherProvider.overrideWithValue(
          launcher ?? FakeDataExportDownloadLauncher(),
        ),
        recentAuthenticationServiceProvider.overrideWithValue(
          FakeRecentAuthenticationService(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DataExportScreen(),
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
