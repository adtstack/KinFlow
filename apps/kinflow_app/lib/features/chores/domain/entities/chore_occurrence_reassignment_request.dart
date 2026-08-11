import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceReassignmentDraft {
  const ChoreOccurrenceReassignmentDraft._({
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.assigneeMemberId,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final HouseholdMemberId assigneeMemberId;

  static ChoreOccurrenceReassignmentDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required HouseholdMemberId assigneeMemberId,
  }) {
    return expectedVersion < 1
        ? null
        : ChoreOccurrenceReassignmentDraft._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            expectedVersion: expectedVersion,
            assigneeMemberId: assigneeMemberId,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'reassignOccurrence',
    'householdId': householdId.value,
    'occurrenceId': occurrenceId.value,
    'expectedVersion': expectedVersion,
    'assigneeMemberId': assigneeMemberId.value,
  });

  ReassignChoreOccurrenceRequest withId(ChoreCommandId idempotencyKey) {
    return ReassignChoreOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      assigneeMemberId: assigneeMemberId,
    );
  }
}

final class ReassignChoreOccurrenceRequest {
  const ReassignChoreOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.assigneeMemberId,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final HouseholdMemberId assigneeMemberId;
}

final class ChoreOccurrenceReassignmentSnapshot {
  const ChoreOccurrenceReassignmentSnapshot({
    required this.householdId,
    required this.occurrenceId,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.version,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final HouseholdMemberId assigneeMemberId;
  final String assigneeDisplayName;
  final int version;
  final bool changed;
}
