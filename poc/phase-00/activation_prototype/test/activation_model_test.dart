import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_activation_poc/activation_model.dart';

void main() {
  group('ActivationModel', () {
    test('requires three chores, both adults, and next-day revisit', () {
      final model = ActivationModel();

      expect(model.createHousehold('초록집'), isTrue);
      expect(model.acceptInvite(), isTrue);
      model.seedRecommendedChores();

      expect(model.hasMinimumChores, isTrue);
      expect(model.completeChore('chore-1'), isTrue);
      expect(model.completeChore('chore-2'), isFalse);
      expect(model.bothAdultsCompleted, isFalse);

      model.switchActor(AdultActor.invitedAdult);
      expect(model.completeChore('chore-2'), isTrue);
      expect(model.bothAdultsCompleted, isTrue);
      expect(model.isActivated, isFalse);

      expect(model.visitNextDayToday(), isTrue);
      expect(model.isActivated, isTrue);
      expect(model.completedStepCount, 5);
    });

    test('does not accept empty household or chore titles', () {
      final model = ActivationModel();

      expect(model.createHousehold('   '), isFalse);
      expect(model.acceptInvite(), isFalse);
      expect(
        model.addChore(title: ' ', assignee: AdultActor.coordinator),
        isFalse,
      );
    });

    test('reset removes all disposable prototype state', () {
      final model = ActivationModel()
        ..createHousehold('초록집')
        ..acceptInvite()
        ..seedRecommendedChores();

      model.reset();

      expect(model.householdCreated, isFalse);
      expect(model.inviteAccepted, isFalse);
      expect(model.chores, isEmpty);
      expect(model.events, isEmpty);
      expect(model.activeActor, AdultActor.coordinator);
    });
  });
}
