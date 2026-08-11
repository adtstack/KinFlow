import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class ChoreCompletionOutboxEnqueueResult {
  const ChoreCompletionOutboxEnqueueResult();
}

final class ChoreCompletionOutboxEnqueued
    extends ChoreCompletionOutboxEnqueueResult {
  const ChoreCompletionOutboxEnqueued(this.item, {required this.created});

  final PendingChoreCompletion item;
  final bool created;
}

final class ChoreCompletionOutboxOccupied
    extends ChoreCompletionOutboxEnqueueResult {
  const ChoreCompletionOutboxOccupied(this.item);

  final PendingChoreCompletion item;
}

final class ChoreCompletionOutboxUnavailable
    extends ChoreCompletionOutboxEnqueueResult {
  const ChoreCompletionOutboxUnavailable();
}

abstract interface class ChoreCompletionOutbox {
  bool get isAvailable;

  Future<PendingChoreCompletion?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  });

  Future<ChoreCompletionOutboxEnqueueResult> enqueue({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
  });

  Future<PendingChoreCompletion?> markNextAttempt(
    PendingChoreCompletion expected,
  );

  Future<PendingChoreCompletion?> exhaustAutomaticAttempts(
    PendingChoreCompletion expected,
  );

  Future<bool> clear();
}

final class UnavailableChoreCompletionOutbox implements ChoreCompletionOutbox {
  const UnavailableChoreCompletionOutbox();

  @override
  bool get isAvailable => false;

  @override
  Future<PendingChoreCompletion?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  }) async => null;

  @override
  Future<ChoreCompletionOutboxEnqueueResult> enqueue({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
  }) async => const ChoreCompletionOutboxUnavailable();

  @override
  Future<PendingChoreCompletion?> markNextAttempt(
    PendingChoreCompletion expected,
  ) async => null;

  @override
  Future<PendingChoreCompletion?> exhaustAutomaticAttempts(
    PendingChoreCompletion expected,
  ) async => null;

  @override
  Future<bool> clear() async => false;
}
