import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;

  test('derives milestone and complete state from capped progress', () {
    final HouseholdActivationProgress partial =
        HouseholdActivationProgress.tryCreate(
          householdId: householdId,
          adultParticipantProgress: 2,
          choreCreationProgress: 3,
          distinctAdultCompleterProgress: 1,
          returnAfterFirstDayReached: true,
        )!;
    final HouseholdActivationProgress complete =
        HouseholdActivationProgress.tryCreate(
          householdId: householdId,
          adultParticipantProgress: 2,
          choreCreationProgress: 3,
          distinctAdultCompleterProgress: 2,
          returnAfterFirstDayReached: true,
        )!;

    expect(partial.completedMilestoneCount, 3);
    expect(partial.distinctAdultCompleterReached, isFalse);
    expect(partial.isComplete, isFalse);
    expect(complete.completedMilestoneCount, 4);
    expect(complete.isComplete, isTrue);
  });

  test('rejects every out-of-range aggregate count', () {
    for (final ({int adults, int chores, int completers}) values
        in <({int adults, int chores, int completers})>[
          (adults: -1, chores: 0, completers: 0),
          (adults: 3, chores: 0, completers: 0),
          (adults: 0, chores: -1, completers: 0),
          (adults: 0, chores: 4, completers: 0),
          (adults: 0, chores: 0, completers: -1),
          (adults: 0, chores: 0, completers: 3),
        ]) {
      expect(
        HouseholdActivationProgress.tryCreate(
          householdId: householdId,
          adultParticipantProgress: values.adults,
          choreCreationProgress: values.chores,
          distinctAdultCompleterProgress: values.completers,
          returnAfterFirstDayReached: false,
        ),
        isNull,
      );
    }
  });
}
