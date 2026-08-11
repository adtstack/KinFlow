import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_activation_progress_card.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;

  testWidgets('renders four milestones and dispatches incomplete actions', (
    WidgetTester tester,
  ) async {
    var inviteCount = 0;
    var createCount = 0;
    await _pumpCard(
      tester,
      state: HouseholdActivationProgressReady(
        progress: householdActivationProgressFixture(
          householdId: householdId,
          adultParticipantProgress: 1,
          choreCreationProgress: 2,
          distinctAdultCompleterProgress: 1,
        ),
      ),
      householdId: householdId,
      onInvite: () => inviteCount += 1,
      onCreate: () => createCount += 1,
    );

    expect(find.byKey(const Key('today.activation.ready')), findsOneWidget);
    expect(find.byKey(const Key('today.activation.adult')), findsOneWidget);
    expect(find.byKey(const Key('today.activation.chores')), findsOneWidget);
    expect(
      find.byKey(const Key('today.activation.completers')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today.activation.return')), findsOneWidget);
    expect(
      find.text('1 of 2 adults have joined this household.'),
      findsOneWidget,
    );
    expect(find.text('2 of 3 chores have been created.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('today.activation.invite')));
    await tester.tap(find.byKey(const Key('today.activation.create')));
    expect(inviteCount, 1);
    expect(createCount, 1);
  });

  testWidgets('keeps completed state and disables actions for saved Today', (
    WidgetTester tester,
  ) async {
    await _pumpCard(
      tester,
      state: HouseholdActivationProgressReady(
        progress: householdActivationProgressFixture(
          householdId: householdId,
          adultParticipantProgress: 1,
          choreCreationProgress: 2,
        ),
      ),
      householdId: householdId,
      readOnly: true,
    );

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('today.activation.invite')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('today.activation.create')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('today.activation.readOnly')), findsOneWidget);

    await _pumpCard(
      tester,
      state: HouseholdActivationProgressReady(
        progress: householdActivationProgressFixture(
          householdId: householdId,
          adultParticipantProgress: 2,
          choreCreationProgress: 3,
          distinctAdultCompleterProgress: 2,
          returnAfterFirstDayReached: true,
        ),
      ),
      householdId: householdId,
    );
    expect(
      find.text(
        'Your household completed all four getting-started milestones.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('today.activation.invite')), findsNothing);
    expect(find.byKey(const Key('today.activation.create')), findsNothing);
  });

  testWidgets('localizes failure and retries only the card', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;
    await _pumpCard(
      tester,
      state: HouseholdActivationProgressFailed(
        householdId: householdId,
        failure: const ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
      ),
      householdId: householdId,
      locale: const Locale('ko'),
      onRetry: () => retryCount += 1,
    );

    expect(find.text('가족과 함께 시작하기'), findsOneWidget);
    expect(find.byKey(const Key('today.activation.failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today.activation.retry')));
    expect(retryCount, 1);
  });

  testWidgets('pseudo locale remains scrollable at 200 percent text', (
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

    await _pumpCard(
      tester,
      state: HouseholdActivationProgressReady(
        progress: householdActivationProgressFixture(
          householdId: householdId,
          adultParticipantProgress: 1,
          choreCreationProgress: 2,
          distinctAdultCompleterProgress: 1,
        ),
      ),
      householdId: householdId,
      locale: const Locale('en', 'XA'),
    );

    final Finder create = find.byKey(const Key('today.activation.create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required HouseholdActivationProgressState state,
  required HouseholdId householdId,
  Locale locale = const Locale('en'),
  bool readOnly = false,
  VoidCallback? onInvite,
  VoidCallback? onCreate,
  VoidCallback? onRetry,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: HouseholdActivationProgressCard(
            state: state,
            expectedHouseholdId: householdId,
            readOnly: readOnly,
            onInvite: onInvite ?? () {},
            onCreateChore: onCreate ?? () {},
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    ),
  );
}
