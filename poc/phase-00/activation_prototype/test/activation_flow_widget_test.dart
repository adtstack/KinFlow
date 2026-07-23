import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_activation_poc/main.dart';

void main() {
  testWidgets('completes the adult two-person activation loop', (tester) async {
    await tester.pumpWidget(const KinFlowActivationApp());

    await tester.enterText(find.byKey(const Key('householdNameField')), '초록집');
    await tester.tap(find.byKey(const Key('createHouseholdButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acceptInviteButton')));
    await tester.pumpAndSettle();
    final seedChores = find.byKey(const Key('seedChoresButton'));
    await tester.ensureVisible(seedChores);
    await tester.pumpAndSettle();
    await tester.tap(seedChores);
    await tester.pumpAndSettle();

    final firstAdultChore = find.byKey(const Key('complete-chore-1'));
    await tester.ensureVisible(firstAdultChore);
    await tester.tap(firstAdultChore);
    await tester.pumpAndSettle();

    final secondAdult = find.byKey(const Key('actor-invitedAdult'));
    await tester.ensureVisible(secondAdult);
    await tester.tap(secondAdult);
    await tester.pumpAndSettle();

    final secondAdultChore = find.byKey(const Key('complete-chore-2'));
    await tester.ensureVisible(secondAdultChore);
    await tester.tap(secondAdultChore);
    await tester.pumpAndSettle();

    final nextDay = find.byKey(const Key('nextDayButton'));
    await tester.ensureVisible(nextDay);
    await tester.tap(nextDay);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activationComplete')), findsOneWidget);
    expect(find.text('Activation 루프 완료'), findsOneWidget);
  });
}
