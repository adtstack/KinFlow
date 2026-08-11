import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class OneTimeChoreTrashState {
  const OneTimeChoreTrashState();
}

final class OneTimeChoreTrashInitial extends OneTimeChoreTrashState {
  const OneTimeChoreTrashInitial();
}

final class OneTimeChoreTrashLoading extends OneTimeChoreTrashState {
  const OneTimeChoreTrashLoading();
}

final class OneTimeChoreTrashReady extends OneTimeChoreTrashState {
  OneTimeChoreTrashReady({
    required this.householdId,
    required this.householdTimezone,
    required this.generatedAt,
    required this.pageLimit,
    required this.hasMore,
    required this.nextCursor,
    required List<DeletedOneTimeChore> items,
    this.restoringOccurrenceId,
    this.restoredOccurrenceId,
    this.actionFailure,
    this.refreshing = false,
    this.refreshFailure,
    this.loadingMore = false,
    this.loadMoreFailure,
  }) : assert(!refreshing || !loadingMore),
       assert(restoringOccurrenceId == null || actionFailure == null),
       assert(!loadingMore || loadMoreFailure == null),
       items = List<DeletedOneTimeChore>.unmodifiable(items);

  final HouseholdId householdId;
  final String householdTimezone;
  final DateTime generatedAt;
  final int pageLimit;
  final bool hasMore;
  final DeletedOneTimeChoreCursor? nextCursor;
  final List<DeletedOneTimeChore> items;
  final ChoreOccurrenceId? restoringOccurrenceId;
  final ChoreOccurrenceId? restoredOccurrenceId;
  final ChoreFailure? actionFailure;
  final bool refreshing;
  final ChoreFailure? refreshFailure;
  final bool loadingMore;
  final ChoreFailure? loadMoreFailure;
}

final class OneTimeChoreTrashLoadFailed extends OneTimeChoreTrashState {
  const OneTimeChoreTrashLoadFailed(this.failure);

  final ChoreFailure failure;
}
