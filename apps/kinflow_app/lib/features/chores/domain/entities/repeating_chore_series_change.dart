import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class RepeatingChoreSeriesUpdateDraft {
  const RepeatingChoreSeriesUpdateDraft._({
    required this.householdId,
    required this.seriesId,
    required this.expectedVersion,
    required this.effectiveLocalDate,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final int expectedVersion;
  final ChoreLocalDate effectiveLocalDate;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;

  static RepeatingChoreSeriesUpdateDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required int expectedVersion,
    required ChoreLocalDate effectiveLocalDate,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    final ChoreRecurrenceEnd end = recurrenceRule.end;
    if (expectedVersion < 1 ||
        normalizedTitle.isEmpty ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 4000 ||
        end is ChoreRecurrenceUntilEnd &&
            end.localDate.value.compareTo(effectiveLocalDate.value) < 0) {
      return null;
    }
    return RepeatingChoreSeriesUpdateDraft._(
      householdId: householdId,
      seriesId: seriesId,
      expectedVersion: expectedVersion,
      effectiveLocalDate: effectiveLocalDate,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'updateRepeatingChoreSeries',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'expectedVersion': expectedVersion,
    'effectiveLocalDate': effectiveLocalDate.value,
    'title': title,
    'description': description,
    'assigneeMemberId': assigneeMemberId.value,
    'dueLocalTime': dueLocalTime?.value,
    'recurrenceRule': recurrenceRule.toJson(),
  });

  UpdateRepeatingChoreSeriesRequest withId(ChoreCommandId idempotencyKey) {
    return UpdateRepeatingChoreSeriesRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      expectedVersion: expectedVersion,
      effectiveLocalDate: effectiveLocalDate,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }
}

final class UpdateRepeatingChoreSeriesRequest {
  const UpdateRepeatingChoreSeriesRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.expectedVersion,
    required this.effectiveLocalDate,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final int expectedVersion;
  final ChoreLocalDate effectiveLocalDate;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;
}

final class RepeatingChoreSeriesFromOccurrenceUpdateDraft {
  const RepeatingChoreSeriesFromOccurrenceUpdateDraft._({
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.expectedVersion,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId effectiveOccurrenceId;
  final int expectedVersion;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;

  static RepeatingChoreSeriesFromOccurrenceUpdateDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId effectiveOccurrenceId,
    required int expectedVersion,
    required ChoreLocalDate minimumLocalDate,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    final String normalizedTitle = title.trim();
    final String normalizedDescription = description.trim();
    final ChoreRecurrenceEnd end = recurrenceRule.end;
    if (expectedVersion < 1 ||
        normalizedTitle.isEmpty ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription.length > 4000 ||
        end is ChoreRecurrenceUntilEnd &&
            end.localDate.value.compareTo(minimumLocalDate.value) < 0) {
      return null;
    }
    return RepeatingChoreSeriesFromOccurrenceUpdateDraft._(
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      expectedVersion: expectedVersion,
      title: normalizedTitle,
      description: normalizedDescription.isEmpty ? null : normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'updateRepeatingChoreSeriesFromOccurrence',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'effectiveOccurrenceId': effectiveOccurrenceId.value,
    'expectedVersion': expectedVersion,
    'title': title,
    'description': description,
    'assigneeMemberId': assigneeMemberId.value,
    'dueLocalTime': dueLocalTime?.value,
    'recurrenceRule': recurrenceRule.toJson(),
  });

  UpdateRepeatingChoreSeriesFromOccurrenceRequest withId(
    ChoreCommandId idempotencyKey,
  ) {
    return UpdateRepeatingChoreSeriesFromOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      expectedVersion: expectedVersion,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      dueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
    );
  }
}

final class UpdateRepeatingChoreSeriesFromOccurrenceRequest {
  const UpdateRepeatingChoreSeriesFromOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.expectedVersion,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId effectiveOccurrenceId;
  final int expectedVersion;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;
}

final class RepeatingChoreSeriesUpdateSnapshot {
  const RepeatingChoreSeriesUpdateSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.effectiveLocalDate,
    required this.version,
    required this.rebuiltCount,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreRevisionId revisionId;
  final int revisionNumber;
  final ChoreLocalDate effectiveLocalDate;
  final int version;
  final int rebuiltCount;
  final int cancelledCount;
  final int preservedCompletedCount;
  final bool changed;
}

final class RepeatingChoreSeriesCancellationDraft {
  const RepeatingChoreSeriesCancellationDraft._({
    required this.householdId,
    required this.seriesId,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final int expectedVersion;

  static RepeatingChoreSeriesCancellationDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : RepeatingChoreSeriesCancellationDraft._(
            householdId: householdId,
            seriesId: seriesId,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'cancelRepeatingChoreSeries',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'expectedVersion': expectedVersion,
  });

  CancelRepeatingChoreSeriesRequest withId(ChoreCommandId idempotencyKey) {
    return CancelRepeatingChoreSeriesRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      expectedVersion: expectedVersion,
    );
  }
}

final class RepeatingChoreSeriesFromOccurrenceCancellationDraft {
  const RepeatingChoreSeriesFromOccurrenceCancellationDraft._({
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId effectiveOccurrenceId;
  final int expectedVersion;

  static RepeatingChoreSeriesFromOccurrenceCancellationDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId effectiveOccurrenceId,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : RepeatingChoreSeriesFromOccurrenceCancellationDraft._(
            householdId: householdId,
            seriesId: seriesId,
            effectiveOccurrenceId: effectiveOccurrenceId,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'cancelRepeatingChoreSeriesFromOccurrence',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'effectiveOccurrenceId': effectiveOccurrenceId.value,
    'expectedVersion': expectedVersion,
  });

  CancelRepeatingChoreSeriesFromOccurrenceRequest withId(
    ChoreCommandId idempotencyKey,
  ) {
    return CancelRepeatingChoreSeriesFromOccurrenceRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      effectiveOccurrenceId: effectiveOccurrenceId,
      expectedVersion: expectedVersion,
    );
  }
}

final class CancelRepeatingChoreSeriesFromOccurrenceRequest {
  const CancelRepeatingChoreSeriesFromOccurrenceRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.effectiveOccurrenceId,
    required this.expectedVersion,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId effectiveOccurrenceId;
  final int expectedVersion;
}

final class RepeatingChoreSeriesFromOccurrenceCancellationSnapshot {
  const RepeatingChoreSeriesFromOccurrenceCancellationSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.terminalRevisionId,
    required this.terminalRevisionNumber,
    required this.changed,
  }) : assert((terminalRevisionId == null) == (terminalRevisionNumber == null));

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreLocalDate effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedCompletedCount;
  final ChoreRevisionId? terminalRevisionId;
  final int? terminalRevisionNumber;
  final bool changed;

  bool get retainsScheduledPrefix => terminalRevisionId != null;
}

final class ResumeRepeatingChoreSeriesCancellationDraft {
  const ResumeRepeatingChoreSeriesCancellationDraft._({
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.expectedVersion,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreCommandId cancellationIdempotencyKey;
  final int expectedVersion;

  static ResumeRepeatingChoreSeriesCancellationDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreCommandId cancellationIdempotencyKey,
    required int expectedVersion,
  }) {
    return expectedVersion < 1
        ? null
        : ResumeRepeatingChoreSeriesCancellationDraft._(
            householdId: householdId,
            seriesId: seriesId,
            cancellationIdempotencyKey: cancellationIdempotencyKey,
            expectedVersion: expectedVersion,
          );
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'resumeRepeatingChoreSeriesCancellation',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'cancellationIdempotencyKey': cancellationIdempotencyKey.value,
    'expectedVersion': expectedVersion,
  });

  ResumeRepeatingChoreSeriesCancellationRequest withId(
    ChoreCommandId idempotencyKey,
  ) {
    return ResumeRepeatingChoreSeriesCancellationRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      cancellationIdempotencyKey: cancellationIdempotencyKey,
      expectedVersion: expectedVersion,
    );
  }
}

final class ResumeRepeatingChoreSeriesCancellationRequest {
  const ResumeRepeatingChoreSeriesCancellationRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.cancellationIdempotencyKey,
    required this.expectedVersion,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreCommandId cancellationIdempotencyKey;
  final int expectedVersion;
}

final class RepeatingChoreSeriesCancellationResumeSnapshot {
  const RepeatingChoreSeriesCancellationResumeSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.restoredCount,
    required this.preservedCompletedCount,
    required this.revisionId,
    required this.revisionNumber,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreLocalDate effectiveLocalDate;
  final int version;
  final int restoredCount;
  final int preservedCompletedCount;
  final ChoreRevisionId revisionId;
  final int revisionNumber;
  final bool changed;
}

final class CancelRepeatingChoreSeriesRequest {
  const CancelRepeatingChoreSeriesRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.seriesId,
    required this.expectedVersion,
  });

  final ChoreCommandId idempotencyKey;
  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final int expectedVersion;
}

final class RepeatingChoreSeriesCancellationSnapshot {
  const RepeatingChoreSeriesCancellationSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedCompletedCount,
    required this.changed,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreLocalDate effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedCompletedCount;
  final bool changed;
}

bool _containsControlCharacter(String value) {
  for (final int unit in value.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) {
      return true;
    }
  }
  return false;
}
