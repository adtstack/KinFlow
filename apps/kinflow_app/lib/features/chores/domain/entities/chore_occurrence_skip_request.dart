import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceSkipDraft {
  const ChoreOccurrenceSkipDraft._({
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;

  static ChoreOccurrenceSkipDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : ChoreOccurrenceSkipDraft._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'skipOccurrence',
    'householdId': householdId.value,
    'occurrenceId': occurrenceId.value,
    'expectedVersion': expectedVersion,
  });

  SkipChoreOccurrenceRequest withId(ChoreCommandId idempotencyKey) {
    return SkipChoreOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
    );
  }
}

final class SkipChoreOccurrenceRequest {
  const SkipChoreOccurrenceRequest({
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

final class ChoreOccurrenceSkipSnapshot {
  const ChoreOccurrenceSkipSnapshot({
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
