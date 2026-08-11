import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceRestoreDraft {
  const ChoreOccurrenceRestoreDraft._({
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;

  static ChoreOccurrenceRestoreDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : ChoreOccurrenceRestoreDraft._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'restoreSkippedOccurrence',
    'householdId': householdId.value,
    'occurrenceId': occurrenceId.value,
    'expectedVersion': expectedVersion,
  });

  RestoreSkippedChoreOccurrenceRequest withId(ChoreCommandId idempotencyKey) {
    return RestoreSkippedChoreOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
    );
  }
}

final class RestoreSkippedChoreOccurrenceRequest {
  const RestoreSkippedChoreOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
}

final class ChoreOccurrenceRestoreSnapshot {
  const ChoreOccurrenceRestoreSnapshot({
    required this.householdId,
    required this.occurrenceId,
    required this.version,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int version;
  final bool changed;
}
