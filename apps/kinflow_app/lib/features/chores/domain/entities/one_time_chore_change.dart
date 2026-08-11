import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class OneTimeChoreUpdateDraft {
  const OneTimeChoreUpdateDraft._({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedSeriesVersion,
    required this.expectedOccurrenceVersion,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedSeriesVersion;
  final int expectedOccurrenceVersion;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;

  static OneTimeChoreUpdateDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    if (expectedSeriesVersion < 1 ||
        expectedOccurrenceVersion < 1 ||
        normalizedTitle.isEmpty ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 4000) {
      return null;
    }
    return OneTimeChoreUpdateDraft._(
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: expectedSeriesVersion,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'updateOneTimeChore',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'occurrenceId': occurrenceId.value,
    'expectedSeriesVersion': expectedSeriesVersion,
    'expectedOccurrenceVersion': expectedOccurrenceVersion,
    'title': title,
    'description': description,
    'assigneeMemberId': assigneeMemberId.value,
    'dueLocalDate': dueLocalDate.value,
    'dueLocalTime': dueLocalTime?.value,
  });

  UpdateOneTimeChoreRequest withId(ChoreCommandId idempotencyKey) {
    return UpdateOneTimeChoreRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: expectedSeriesVersion,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
    );
  }
}

final class UpdateOneTimeChoreRequest {
  const UpdateOneTimeChoreRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedSeriesVersion,
    required this.expectedOccurrenceVersion,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedSeriesVersion;
  final int expectedOccurrenceVersion;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
}

final class OneTimeChoreUpdateSnapshot {
  const OneTimeChoreUpdateSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.revisionId,
    required this.revisionNumber,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.assigneeMemberId,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  }) : assert(revisionNumber >= 2),
       assert(seriesVersion > 1),
       assert(occurrenceVersion > 1),
       assert((dueLocalTime == null) == (dueAt == null));

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final ChoreRevisionId revisionId;
  final int revisionNumber;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final DateTime? dueAt;
  final HouseholdMemberId assigneeMemberId;
  final int seriesVersion;
  final int occurrenceVersion;
  final bool changed;
}

final class OneTimeChoreDeletionDraft {
  const OneTimeChoreDeletionDraft._({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedSeriesVersion,
    required this.expectedOccurrenceVersion,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedSeriesVersion;
  final int expectedOccurrenceVersion;

  static OneTimeChoreDeletionDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) {
    if (expectedSeriesVersion < 1 || expectedOccurrenceVersion < 1) {
      return null;
    }
    return OneTimeChoreDeletionDraft._(
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: expectedSeriesVersion,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'deleteOneTimeChore',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'occurrenceId': occurrenceId.value,
    'expectedSeriesVersion': expectedSeriesVersion,
    'expectedOccurrenceVersion': expectedOccurrenceVersion,
  });

  DeleteOneTimeChoreRequest withId(ChoreCommandId idempotencyKey) {
    return DeleteOneTimeChoreRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: expectedSeriesVersion,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
    );
  }
}

final class DeleteOneTimeChoreRequest {
  const DeleteOneTimeChoreRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.expectedSeriesVersion,
    required this.expectedOccurrenceVersion,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final int expectedSeriesVersion;
  final int expectedOccurrenceVersion;
}

final class OneTimeChoreDeletionSnapshot {
  const OneTimeChoreDeletionSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  }) : assert(seriesVersion > 1),
       assert(occurrenceVersion > 1);

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final int seriesVersion;
  final int occurrenceVersion;
  final bool changed;
}

bool _containsControlCharacter(String value) {
  return value.codeUnits.any(
    (int codeUnit) => codeUnit < 0x20 || codeUnit == 0x7f,
  );
}
