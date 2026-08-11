import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceRescheduleDraft {
  const ChoreOccurrenceRescheduleDraft._({
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;

  static ChoreOccurrenceRescheduleDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    return expectedVersion < 1
        ? null
        : ChoreOccurrenceRescheduleDraft._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            expectedVersion: expectedVersion,
            dueLocalDate: dueLocalDate,
            dueLocalTime: dueLocalTime,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'rescheduleOccurrence',
    'householdId': householdId.value,
    'occurrenceId': occurrenceId.value,
    'expectedVersion': expectedVersion,
    'dueLocalDate': dueLocalDate.value,
    'dueLocalTime': dueLocalTime?.value,
  });

  RescheduleChoreOccurrenceRequest withId(ChoreCommandId idempotencyKey) {
    return RescheduleChoreOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      occurrenceId: occurrenceId,
      expectedVersion: expectedVersion,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
  }
}

final class RescheduleChoreOccurrenceRequest {
  const RescheduleChoreOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.occurrenceId,
    required this.expectedVersion,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedVersion;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
}

final class ChoreOccurrenceRescheduleSnapshot {
  const ChoreOccurrenceRescheduleSnapshot({
    required this.householdId,
    required this.occurrenceId,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.version,
    required this.changed,
  }) : assert((dueLocalTime == null) == (dueAt == null));

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final DateTime? dueAt;
  final int version;
  final bool changed;
}
