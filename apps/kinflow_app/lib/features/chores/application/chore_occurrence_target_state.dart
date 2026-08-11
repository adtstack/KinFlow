import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class ChoreOccurrenceTargetState {
  const ChoreOccurrenceTargetState();
}

final class ChoreOccurrenceTargetInitial extends ChoreOccurrenceTargetState {
  const ChoreOccurrenceTargetInitial();
}

final class ChoreOccurrenceTargetLoading extends ChoreOccurrenceTargetState {
  const ChoreOccurrenceTargetLoading({
    required this.householdId,
    required this.occurrenceId,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
}

final class ChoreOccurrenceTargetReady extends ChoreOccurrenceTargetState {
  const ChoreOccurrenceTargetReady({
    required this.householdId,
    required this.occurrence,
    this.actionInFlight = false,
    this.actionFailure,
    this.refreshFailure,
  });

  final HouseholdId householdId;
  final ChoreOccurrence occurrence;
  final bool actionInFlight;
  final ChoreFailure? actionFailure;
  final ChoreFailure? refreshFailure;
}

final class ChoreOccurrenceTargetLoadFailed extends ChoreOccurrenceTargetState {
  const ChoreOccurrenceTargetLoadFailed({
    required this.householdId,
    required this.occurrenceId,
    required this.failure,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final ChoreFailure failure;
}
