import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum ChoreOccurrenceHistoryEventType {
  completed,
  reopened,
  skipped,
  restored,
  rescheduled,
  reassigned,
}

final class ChoreOccurrenceHistoryCursor {
  const ChoreOccurrenceHistoryCursor._({
    required this.occurredAt,
    required this.entryId,
  });

  final DateTime occurredAt;
  final ChoreHistoryEntryId entryId;

  static ChoreOccurrenceHistoryCursor? tryCreate({
    required DateTime occurredAt,
    required ChoreHistoryEntryId entryId,
  }) {
    return occurredAt.isUtc
        ? ChoreOccurrenceHistoryCursor._(
            occurredAt: occurredAt,
            entryId: entryId,
          )
        : null;
  }
}

final class ChoreOccurrenceHistoryRequest {
  const ChoreOccurrenceHistoryRequest._({
    required this.householdId,
    required this.occurrenceId,
    required this.limit,
    required this.cursor,
  });

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final int limit;
  final ChoreOccurrenceHistoryCursor? cursor;

  static ChoreOccurrenceHistoryRequest? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    int limit = 20,
    ChoreOccurrenceHistoryCursor? cursor,
  }) {
    return limit >= 1 && limit <= 100
        ? ChoreOccurrenceHistoryRequest._(
            householdId: householdId,
            occurrenceId: occurrenceId,
            limit: limit,
            cursor: cursor,
          )
        : null;
  }
}

final class ChoreOccurrenceHistoryEvent {
  const ChoreOccurrenceHistoryEvent._({
    required this.id,
    required this.type,
    required this.actorMemberId,
    required this.actorDisplayName,
    required this.actingMemberId,
    required this.actingDisplayName,
    required this.occurredAt,
    required this.occurrenceVersion,
    required this.previousDueLocalDate,
    required this.previousDueLocalTime,
    required this.newDueLocalDate,
    required this.newDueLocalTime,
    required this.previousAssigneeMemberId,
    required this.previousAssigneeDisplayName,
    required this.newAssigneeMemberId,
    required this.newAssigneeDisplayName,
  });

  final ChoreHistoryEntryId id;
  final ChoreOccurrenceHistoryEventType type;
  final HouseholdMemberId actorMemberId;
  final String actorDisplayName;
  final HouseholdMemberId? actingMemberId;
  final String? actingDisplayName;
  final DateTime occurredAt;
  final int occurrenceVersion;
  final ChoreLocalDate? previousDueLocalDate;
  final ChoreLocalTime? previousDueLocalTime;
  final ChoreLocalDate? newDueLocalDate;
  final ChoreLocalTime? newDueLocalTime;
  final HouseholdMemberId? previousAssigneeMemberId;
  final String? previousAssigneeDisplayName;
  final HouseholdMemberId? newAssigneeMemberId;
  final String? newAssigneeDisplayName;

  static ChoreOccurrenceHistoryEvent? tryCreate({
    required ChoreHistoryEntryId id,
    required ChoreOccurrenceHistoryEventType type,
    required HouseholdMemberId actorMemberId,
    required String actorDisplayName,
    required HouseholdMemberId? actingMemberId,
    required String? actingDisplayName,
    required DateTime occurredAt,
    required int occurrenceVersion,
    required ChoreLocalDate? previousDueLocalDate,
    required ChoreLocalTime? previousDueLocalTime,
    required ChoreLocalDate? newDueLocalDate,
    required ChoreLocalTime? newDueLocalTime,
    required HouseholdMemberId? previousAssigneeMemberId,
    required String? previousAssigneeDisplayName,
    required HouseholdMemberId? newAssigneeMemberId,
    required String? newAssigneeDisplayName,
  }) {
    final String expectedSource = switch (type) {
      ChoreOccurrenceHistoryEventType.completed ||
      ChoreOccurrenceHistoryEventType.reopened ||
      ChoreOccurrenceHistoryEventType.skipped ||
      ChoreOccurrenceHistoryEventType.restored => 'completion',
      ChoreOccurrenceHistoryEventType.rescheduled => 'reschedule',
      ChoreOccurrenceHistoryEventType.reassigned => 'assignment',
    };
    final bool actingShapeValid =
        (actingMemberId == null) == (actingDisplayName == null) &&
        (actingDisplayName == null || _validDisplayName(actingDisplayName));
    final bool scheduleShapeValid =
        type == ChoreOccurrenceHistoryEventType.rescheduled
        ? previousDueLocalDate != null &&
              newDueLocalDate != null &&
              (previousDueLocalDate != newDueLocalDate ||
                  previousDueLocalTime != newDueLocalTime) &&
              previousAssigneeMemberId == null &&
              previousAssigneeDisplayName == null &&
              newAssigneeMemberId == null &&
              newAssigneeDisplayName == null
        : previousDueLocalDate == null &&
              previousDueLocalTime == null &&
              newDueLocalDate == null &&
              newDueLocalTime == null;
    final bool assignmentShapeValid =
        type == ChoreOccurrenceHistoryEventType.reassigned
        ? previousAssigneeMemberId != null &&
              newAssigneeMemberId != null &&
              previousAssigneeMemberId != newAssigneeMemberId &&
              _validDisplayName(previousAssigneeDisplayName) &&
              _validDisplayName(newAssigneeDisplayName) &&
              previousDueLocalDate == null &&
              previousDueLocalTime == null &&
              newDueLocalDate == null &&
              newDueLocalTime == null
        : previousAssigneeMemberId == null &&
              previousAssigneeDisplayName == null &&
              newAssigneeMemberId == null &&
              newAssigneeDisplayName == null;
    if (id.source != expectedSource ||
        !_validDisplayName(actorDisplayName) ||
        !actingShapeValid ||
        !occurredAt.isUtc ||
        occurrenceVersion < 1 ||
        !scheduleShapeValid ||
        !assignmentShapeValid) {
      return null;
    }
    return ChoreOccurrenceHistoryEvent._(
      id: id,
      type: type,
      actorMemberId: actorMemberId,
      actorDisplayName: actorDisplayName,
      actingMemberId: actingMemberId,
      actingDisplayName: actingDisplayName,
      occurredAt: occurredAt,
      occurrenceVersion: occurrenceVersion,
      previousDueLocalDate: previousDueLocalDate,
      previousDueLocalTime: previousDueLocalTime,
      newDueLocalDate: newDueLocalDate,
      newDueLocalTime: newDueLocalTime,
      previousAssigneeMemberId: previousAssigneeMemberId,
      previousAssigneeDisplayName: previousAssigneeDisplayName,
      newAssigneeMemberId: newAssigneeMemberId,
      newAssigneeDisplayName: newAssigneeDisplayName,
    );
  }
}

final class ChoreOccurrenceHistoryPage {
  ChoreOccurrenceHistoryPage._({
    required this.householdId,
    required this.occurrenceId,
    required List<ChoreOccurrenceHistoryEvent> events,
    required this.hasMore,
  }) : events = List<ChoreOccurrenceHistoryEvent>.unmodifiable(events);

  final HouseholdId householdId;
  final ChoreOccurrenceId occurrenceId;
  final List<ChoreOccurrenceHistoryEvent> events;
  final bool hasMore;

  ChoreOccurrenceHistoryCursor? get nextCursor {
    if (!hasMore || events.isEmpty) {
      return null;
    }
    final ChoreOccurrenceHistoryEvent last = events.last;
    return ChoreOccurrenceHistoryCursor.tryCreate(
      occurredAt: last.occurredAt,
      entryId: last.id,
    );
  }

  static ChoreOccurrenceHistoryPage? tryCreate({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required List<ChoreOccurrenceHistoryEvent> events,
    required bool hasMore,
  }) {
    if (events.length > 100 || hasMore && events.isEmpty) {
      return null;
    }
    final Set<ChoreHistoryEntryId> ids = <ChoreHistoryEntryId>{};
    ChoreOccurrenceHistoryEvent? previous;
    for (final ChoreOccurrenceHistoryEvent event in events) {
      if (!ids.add(event.id)) {
        return null;
      }
      if (previous != null && _compareHistory(previous, event) >= 0) {
        return null;
      }
      previous = event;
    }
    return ChoreOccurrenceHistoryPage._(
      householdId: householdId,
      occurrenceId: occurrenceId,
      events: events,
      hasMore: hasMore,
    );
  }
}

int _compareHistory(
  ChoreOccurrenceHistoryEvent left,
  ChoreOccurrenceHistoryEvent right,
) {
  final int timeComparison = right.occurredAt.compareTo(left.occurredAt);
  return timeComparison != 0
      ? timeComparison
      : right.id.value.compareTo(left.id.value);
}

bool _validDisplayName(String? value) {
  if (value == null) {
    return false;
  }
  final String normalized = value.trim();
  return normalized.isNotEmpty &&
      normalized == value &&
      normalized.length <= 80 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(normalized);
}
