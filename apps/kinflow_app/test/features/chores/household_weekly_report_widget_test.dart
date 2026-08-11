import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_weekly_report_card.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_weekly_report_sheet.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;

  testWidgets('summary card opens without exposing member names', (
    WidgetTester tester,
  ) async {
    var openCount = 0;
    await _pump(
      tester,
      SingleChildScrollView(
        child: HouseholdWeeklyReportCard(
          report: householdWeeklyReportFixture(householdId: householdId),
          onOpen: () => openCount += 1,
        ),
      ),
    );

    expect(find.byKey(const Key('today.weeklyReport.card')), findsOneWidget);
    expect(
      find.text('2 of 4 due chores completed by the end of the week'),
      findsOneWidget,
    );
    expect(find.textContaining('Alex'), findsNothing);
    expect(find.textContaining('Sam'), findsNothing);
    await tester.tap(find.byKey(const Key('today.weeklyReport.card')));
    expect(openCount, 1);
  });

  testWidgets('detail shows contributions and navigates closed weeks', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository();
    await _pump(
      tester,
      HouseholdWeeklyReportSheet(
        repository: repository,
        householdId: householdId,
        initialReport: householdWeeklyReportFixture(householdId: householdId),
      ),
    );

    expect(find.text('Contributions'), findsOneWidget);
    expect(find.text('You completed 2'), findsOneWidget);
    expect(find.text('Alex: 2 completed'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('weeklyReport.newer')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('weeklyReport.older')));
    await tester.pumpAndSettle();

    expect(repository.weeklyReportRequests, hasLength(1));
    expect(repository.weeklyReportRequests.single.weekOffset, 1);
    expect(find.byKey(const Key('weeklyReport.scroll')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(
        const Key('weeklyReport.member.33333333-3333-4333-8333-333333333334'),
      ),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('weeklyReport.scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sam: 1 completed'), findsOneWidget);
  });

  testWidgets('failure remains local to the sheet and retries its week', (
    WidgetTester tester,
  ) async {
    final FakeChoreRepository repository = FakeChoreRepository(
      weeklyReportResults: <LoadHouseholdWeeklyReportResult>[
        const LoadHouseholdWeeklyReportFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        HouseholdWeeklyReportLoaded(
          householdWeeklyReportFixture(householdId: householdId),
        ),
      ],
    );
    await _pump(
      tester,
      HouseholdWeeklyReportSheet(
        repository: repository,
        householdId: householdId,
      ),
      locale: const Locale('ko'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weeklyReport.error')), findsOneWidget);
    expect(
      find.text('오늘의 집안일은 계속 사용할 수 있습니다. 준비되면 이 리포트만 다시 시도해 주세요.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('weeklyReport.retry')));
    await tester.pumpAndSettle();

    expect(repository.weeklyReportRequests, hasLength(2));
    expect(find.byKey(const Key('weeklyReport.summary')), findsOneWidget);
  });

  testWidgets('pseudo locale is scrollable at 200 percent text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pump(
      tester,
      HouseholdWeeklyReportSheet(
        repository: FakeChoreRepository(),
        householdId: householdId,
        initialReport: householdWeeklyReportFixture(householdId: householdId),
      ),
      locale: const Locale('en', 'XA'),
    );

    final Finder viewer = find.byKey(
      const Key('weeklyReport.viewerContribution'),
    );
    await tester.scrollUntilVisible(
      viewer,
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('weeklyReport.scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weeklyReport.scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}
