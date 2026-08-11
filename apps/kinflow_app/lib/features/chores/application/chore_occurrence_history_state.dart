import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class ChoreOccurrenceHistoryState {
  const ChoreOccurrenceHistoryState();
}

final class ChoreOccurrenceHistoryInitial extends ChoreOccurrenceHistoryState {
  const ChoreOccurrenceHistoryInitial();
}

final class ChoreOccurrenceHistoryLoading extends ChoreOccurrenceHistoryState {
  const ChoreOccurrenceHistoryLoading();
}

final class ChoreOccurrenceHistoryReady extends ChoreOccurrenceHistoryState {
  ChoreOccurrenceHistoryReady({
    required this.householdId,
    required this.occurrenceId,
    required List<ChoreOccurrenceHistoryEvent> events,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailure,
  }) : assert(!loadingMore || loadMoreFailure == null),
       events = List<ChoreOccurrenceHistoryEvent>.unmodifiable(events);

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final List<ChoreOccurrenceHistoryEvent> events;
  final bool hasMore;
  final bool loadingMore;
  final ChoreFailure? loadMoreFailure;
}

final class ChoreOccurrenceHistoryLoadFailed
    extends ChoreOccurrenceHistoryState {
  const ChoreOccurrenceHistoryLoadFailed(this.failure);

  final ChoreFailure failure;
}
