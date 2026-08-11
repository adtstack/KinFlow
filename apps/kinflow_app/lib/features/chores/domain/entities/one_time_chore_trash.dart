import 'dart:convert';

import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class DeletedOneTimeChoreCursor {
  const DeletedOneTimeChoreCursor._(this.value);

  final String value;

  static final RegExp _validValue = RegExp(r'^[0-9a-f]+$');

  static DeletedOneTimeChoreCursor? tryParse(String value) {
    return value.length >= 2 &&
            value.length <= 1000 &&
            value.length.isEven &&
            _validValue.hasMatch(value)
        ? DeletedOneTimeChoreCursor._(value)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is DeletedOneTimeChoreCursor && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class DeletedOneTimeChoreListRequest {
  const DeletedOneTimeChoreListRequest._({
    required this.householdId,
    required this.limit,
    required this.cursor,
  });

  final HouseholdId householdId;
  final int limit;
  final DeletedOneTimeChoreCursor? cursor;

  static DeletedOneTimeChoreListRequest? tryCreate({
    required HouseholdId householdId,
    int limit = 30,
    DeletedOneTimeChoreCursor? cursor,
  }) {
    return limit >= 1 && limit <= 100
        ? DeletedOneTimeChoreListRequest._(
            householdId: householdId,
            limit: limit,
            cursor: cursor,
          )
        : null;
  }

  DeletedOneTimeChoreListRequest get firstPage =>
      DeletedOneTimeChoreListRequest._(
        householdId: householdId,
        limit: limit,
        cursor: null,
      );

  DeletedOneTimeChoreListRequest continuation(
    DeletedOneTimeChoreCursor nextCursor,
  ) {
    return DeletedOneTimeChoreListRequest._(
      householdId: householdId,
      limit: limit,
      cursor: nextCursor,
    );
  }
}

final class DeletedOneTimeChore {
  const DeletedOneTimeChore._({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.dueLocalDate,
    required this.dueLocalTime,
    required this.dueAt,
    required this.deletedAt,
    required this.seriesVersion,
    required this.occurrenceVersion,
  });

  final HouseholdId householdId;
  final ChoreSeriesId seriesId;
  final ChoreOccurrenceId occurrenceId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final String assigneeDisplayName;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final DateTime? dueAt;
  final DateTime deletedAt;
  final int seriesVersion;
  final int occurrenceVersion;

  static DeletedOneTimeChore? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String? description,
    required HouseholdMemberId assigneeMemberId,
    required String assigneeDisplayName,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
    required DateTime? dueAt,
    required DateTime deletedAt,
    required int seriesVersion,
    required int occurrenceVersion,
  }) {
    final String normalizedTitle = title.trim();
    final String? normalizedDescription = description?.trim();
    final String normalizedAssigneeName = assigneeDisplayName.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle != title ||
        normalizedTitle.length > 160 ||
        _containsControlCharacter(normalizedTitle) ||
        normalizedDescription != description ||
        (normalizedDescription?.length ?? 0) > 4000 ||
        normalizedAssigneeName.isEmpty ||
        normalizedAssigneeName != assigneeDisplayName ||
        normalizedAssigneeName.length > 160 ||
        _containsControlCharacter(normalizedAssigneeName) ||
        (dueLocalTime == null) != (dueAt == null) ||
        dueAt != null && !dueAt.isUtc ||
        !deletedAt.isUtc ||
        seriesVersion <= 1 ||
        occurrenceVersion <= 1) {
      return null;
    }
    return DeletedOneTimeChore._(
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      title: normalizedTitle,
      description: normalizedDescription,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: normalizedAssigneeName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt,
      deletedAt: deletedAt,
      seriesVersion: seriesVersion,
      occurrenceVersion: occurrenceVersion,
    );
  }
}

final class DeletedOneTimeChorePage {
  DeletedOneTimeChorePage._({
    required this.householdId,
    required this.householdTimezone,
    required this.generatedAt,
    required this.pageLimit,
    required this.hasMore,
    required this.nextCursor,
    required List<DeletedOneTimeChore> items,
  }) : items = List<DeletedOneTimeChore>.unmodifiable(items);

  final HouseholdId householdId;
  final String householdTimezone;
  final DateTime generatedAt;
  final int pageLimit;
  final bool hasMore;
  final DeletedOneTimeChoreCursor? nextCursor;
  final List<DeletedOneTimeChore> items;

  static DeletedOneTimeChorePage? tryCreate({
    required HouseholdId householdId,
    required String householdTimezone,
    required DateTime generatedAt,
    required int pageLimit,
    required bool hasMore,
    required DeletedOneTimeChoreCursor? nextCursor,
    required List<DeletedOneTimeChore> items,
  }) {
    if (householdTimezone.trim() != householdTimezone ||
        householdTimezone.isEmpty ||
        householdTimezone.length > 255 ||
        !generatedAt.isUtc ||
        pageLimit < 1 ||
        pageLimit > 100 ||
        items.length > pageLimit ||
        hasMore != (nextCursor != null) ||
        hasMore && items.length != pageLimit ||
        items.any(
          (DeletedOneTimeChore item) => item.householdId != householdId,
        ) ||
        items
                .map((DeletedOneTimeChore item) => item.occurrenceId)
                .toSet()
                .length !=
            items.length ||
        items.map((DeletedOneTimeChore item) => item.seriesId).toSet().length !=
            items.length) {
      return null;
    }
    for (var index = 1; index < items.length; index += 1) {
      if (compareDeletedOneTimeChores(items[index - 1], items[index]) >= 0) {
        return null;
      }
    }
    return DeletedOneTimeChorePage._(
      householdId: householdId,
      householdTimezone: householdTimezone,
      generatedAt: generatedAt,
      pageLimit: pageLimit,
      hasMore: hasMore,
      nextCursor: nextCursor,
      items: items,
    );
  }
}

int compareDeletedOneTimeChores(
  DeletedOneTimeChore left,
  DeletedOneTimeChore right,
) {
  final int deletedAtComparison = right.deletedAt.compareTo(left.deletedAt);
  return deletedAtComparison != 0
      ? deletedAtComparison
      : right.seriesId.value.compareTo(left.seriesId.value);
}

final class OneTimeChoreRestoreDraft {
  const OneTimeChoreRestoreDraft._({
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

  static OneTimeChoreRestoreDraft? tryCreate({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) {
    return expectedSeriesVersion > 1 && expectedOccurrenceVersion > 1
        ? OneTimeChoreRestoreDraft._(
            householdId: householdId,
            seriesId: seriesId,
            occurrenceId: occurrenceId,
            expectedSeriesVersion: expectedSeriesVersion,
            expectedOccurrenceVersion: expectedOccurrenceVersion,
          )
        : null;
  }

  String get fingerprint => jsonEncode(<String, Object?>{
    'operation': 'restoreOneTimeChore',
    'householdId': householdId.value,
    'seriesId': seriesId.value,
    'occurrenceId': occurrenceId.value,
    'expectedSeriesVersion': expectedSeriesVersion,
    'expectedOccurrenceVersion': expectedOccurrenceVersion,
  });

  RestoreOneTimeChoreRequest withId(ChoreCommandId idempotencyKey) {
    return RestoreOneTimeChoreRequest(
      idempotencyKey: idempotencyKey,
      householdId: householdId,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      expectedSeriesVersion: expectedSeriesVersion,
      expectedOccurrenceVersion: expectedOccurrenceVersion,
    );
  }
}

final class RestoreOneTimeChoreRequest {
  const RestoreOneTimeChoreRequest({
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

final class OneTimeChoreRestoreSnapshot {
  const OneTimeChoreRestoreSnapshot({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.seriesVersion,
    required this.occurrenceVersion,
    required this.changed,
  }) : assert(seriesVersion > 2),
       assert(occurrenceVersion > 2);

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
