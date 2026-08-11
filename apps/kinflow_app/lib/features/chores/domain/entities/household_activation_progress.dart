import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdActivationProgress {
  const HouseholdActivationProgress._({
    required this.householdId,
    required this.adultParticipantProgress,
    required this.choreCreationProgress,
    required this.distinctAdultCompleterProgress,
    required this.returnAfterFirstDayReached,
  });

  static const int adultParticipantGoal = 2;
  static const int choreCreationGoal = 3;
  static const int distinctAdultCompleterGoal = 2;
  static const int milestoneCount = 4;

  final HouseholdId householdId;
  final int adultParticipantProgress;
  final int choreCreationProgress;
  final int distinctAdultCompleterProgress;
  final bool returnAfterFirstDayReached;

  static HouseholdActivationProgress? tryCreate({
    required HouseholdId householdId,
    required int adultParticipantProgress,
    required int choreCreationProgress,
    required int distinctAdultCompleterProgress,
    required bool returnAfterFirstDayReached,
  }) {
    if (adultParticipantProgress < 0 ||
        adultParticipantProgress > adultParticipantGoal ||
        choreCreationProgress < 0 ||
        choreCreationProgress > choreCreationGoal ||
        distinctAdultCompleterProgress < 0 ||
        distinctAdultCompleterProgress > distinctAdultCompleterGoal) {
      return null;
    }
    return HouseholdActivationProgress._(
      householdId: householdId,
      adultParticipantProgress: adultParticipantProgress,
      choreCreationProgress: choreCreationProgress,
      distinctAdultCompleterProgress: distinctAdultCompleterProgress,
      returnAfterFirstDayReached: returnAfterFirstDayReached,
    );
  }

  bool get adultParticipantReached =>
      adultParticipantProgress == adultParticipantGoal;

  bool get choreCreationReached => choreCreationProgress == choreCreationGoal;

  bool get distinctAdultCompleterReached =>
      distinctAdultCompleterProgress == distinctAdultCompleterGoal;

  int get completedMilestoneCount =>
      (adultParticipantReached ? 1 : 0) +
      (choreCreationReached ? 1 : 0) +
      (distinctAdultCompleterReached ? 1 : 0) +
      (returnAfterFirstDayReached ? 1 : 0);

  bool get isComplete => completedMilestoneCount == milestoneCount;
}
