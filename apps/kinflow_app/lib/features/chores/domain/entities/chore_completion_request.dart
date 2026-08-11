import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreCompletionDraft {
  const ChoreCompletionDraft._({
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.completed,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final bool completed;

  static ChoreCompletionDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required bool completed,
  }) {
    return expectedVersion < 1
        ? null
        : ChoreCompletionDraft._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            expectedVersion: expectedVersion,
            completed: completed,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'householdId': householdId.value,
    'occurrenceId': occurrenceId.value,
    'expectedVersion': expectedVersion,
    'completed': completed,
  });

  SetChoreCompletionRequest withId(ChoreCommandId idempotencyKey) {
    return SetChoreCompletionRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      completed: completed,
    );
  }
}

final class SetChoreCompletionRequest {
  const SetChoreCompletionRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.completed,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final bool completed;
}

final class ChoreCompletionSnapshot {
  const ChoreCompletionSnapshot({
    required this.householdId,
    required this.occurrenceId,
    required this.status,
    required this.version,
    required this.completedByMemberId,
    required this.completedAt,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final ChoreOccurrenceStatus status;
  final int version;
  final HouseholdMemberId? completedByMemberId;
  final DateTime? completedAt;
  final bool changed;
}
