import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class PendingChoreCompletion {
  const PendingChoreCompletion._({
    required this.householdId,
    required this.actorMemberId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
    required this.attemptCount,
  });

  static const Duration maximumAge = Duration(minutes: 30);
  static const int maximumAutomaticAttempts = 3;

  final HouseholdId householdId;
  final HouseholdMemberId actorMemberId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final ChoreCommandId idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int attemptCount;

  static PendingChoreCompletion? tryCreate({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
    required DateTime createdAt,
    required DateTime expiresAt,
    required int attemptCount,
  }) {
    if (expectedVersion < 1 ||
        !createdAt.isUtc ||
        !expiresAt.isUtc ||
        !expiresAt.isAfter(createdAt) ||
        expiresAt.isAfter(createdAt.add(maximumAge)) ||
        attemptCount < 0 ||
        attemptCount > maximumAutomaticAttempts) {
      return null;
    }
    return PendingChoreCompletion._(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      attemptCount: attemptCount,
    );
  }

  bool get canAttemptAutomatically => attemptCount < maximumAutomaticAttempts;

  PendingChoreCompletion? nextAttempt() {
    if (!canAttemptAutomatically) {
      return null;
    }
    return PendingChoreCompletion._(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      attemptCount: attemptCount + 1,
    );
  }

  PendingChoreCompletion exhaustAutomaticAttempts() {
    return PendingChoreCompletion._(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      attemptCount: maximumAutomaticAttempts,
    );
  }

  SetChoreCompletionRequest get request => SetChoreCompletionRequest(
    idempotencyKey: idempotencyKey,
    householdId: householdId,
    occurrenceId: occurrenceId,
    expectedVersion: expectedVersion,
    completed: true,
  );

  bool hasSameCommand(PendingChoreCompletion other) {
    return householdId == other.householdId &&
        actorMemberId == other.actorMemberId &&
        occurrenceId == other.occurrenceId &&
        expectedVersion == other.expectedVersion &&
        idempotencyKey == other.idempotencyKey &&
        createdAt == other.createdAt &&
        expiresAt == other.expiresAt;
  }

  @override
  bool operator ==(Object other) {
    return other is PendingChoreCompletion &&
        hasSameCommand(other) &&
        attemptCount == other.attemptCount;
  }

  @override
  int get hashCode => Object.hash(
    householdId,
    actorMemberId,
    occurrenceId,
    expectedVersion,
    idempotencyKey,
    createdAt,
    expiresAt,
    attemptCount,
  );
}
