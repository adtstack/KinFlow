import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum ChoreOccurrenceStatus { scheduled, completed }

final class ChoreOccurrence {
  const ChoreOccurrence({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.assigneeMemberId,
    required this.assigneeDisplayName,
    required this.dueLocalDate,
    required this.status,
    required this.version,
    this.description,
    this.dueLocalTime,
    this.dueAt,
    this.recurrenceFrequency,
    this.seriesVersion = 1,
    this.seriesDefaultAssigneeMemberId,
    this.seriesDueLocalTime,
    this.recurrenceRule,
    this.canManageSeries = false,
    this.canSetCompletion = false,
  }) : assert((dueLocalTime == null) == (dueAt == null)),
       assert(
         !canManageSeries ||
             recurrenceRule != null && seriesDefaultAssigneeMemberId != null,
       );

  final ChoreOccurrenceId id;
  final ChoreSeriesId seriesId;
  final String title;
  final String? description;
  final HouseholdMemberId assigneeMemberId;
  final String assigneeDisplayName;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
  final DateTime? dueAt;
  final ChoreRecurrenceFrequency? recurrenceFrequency;
  final ChoreOccurrenceStatus status;
  final int version;
  final int seriesVersion;
  final HouseholdMemberId? seriesDefaultAssigneeMemberId;
  final ChoreLocalTime? seriesDueLocalTime;
  final ChoreRecurrenceRule? recurrenceRule;
  final bool canManageSeries;
  final bool canSetCompletion;

  bool get canManageOneTime =>
      recurrenceFrequency == null &&
      recurrenceRule == null &&
      status == ChoreOccurrenceStatus.scheduled;

  ChoreOccurrence copyWith({ChoreOccurrenceStatus? status, int? version}) {
    return ChoreOccurrence(
      id: id,
      seriesId: seriesId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: assigneeDisplayName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt,
      recurrenceFrequency: recurrenceFrequency,
      status: status ?? this.status,
      version: version ?? this.version,
      seriesVersion: seriesVersion,
      seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
      seriesDueLocalTime: seriesDueLocalTime,
      recurrenceRule: recurrenceRule,
      canManageSeries: canManageSeries,
      canSetCompletion: canSetCompletion,
    );
  }

  ChoreOccurrence rescheduled({
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
    required DateTime? dueAt,
    int? version,
  }) {
    if ((dueLocalTime == null) != (dueAt == null)) {
      throw ArgumentError(
        'A timed occurrence requires both local and UTC time.',
      );
    }
    return ChoreOccurrence(
      id: id,
      seriesId: seriesId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: assigneeDisplayName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt,
      recurrenceFrequency: recurrenceFrequency,
      status: status,
      version: version ?? this.version,
      seriesVersion: seriesVersion,
      seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
      seriesDueLocalTime: seriesDueLocalTime,
      recurrenceRule: recurrenceRule,
      canManageSeries: canManageSeries,
      canSetCompletion: canSetCompletion,
    );
  }

  ChoreOccurrence reassigned({
    required HouseholdMemberId assigneeMemberId,
    required String assigneeDisplayName,
    int? version,
  }) {
    if (assigneeDisplayName.trim().isEmpty ||
        assigneeDisplayName != assigneeDisplayName.trim()) {
      throw ArgumentError('An assignee display name must be normalized.');
    }
    return ChoreOccurrence(
      id: id,
      seriesId: seriesId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: assigneeDisplayName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt,
      recurrenceFrequency: recurrenceFrequency,
      status: status,
      version: version ?? this.version,
      seriesVersion: seriesVersion,
      seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
      seriesDueLocalTime: seriesDueLocalTime,
      recurrenceRule: recurrenceRule,
      canManageSeries: canManageSeries,
      canSetCompletion: canSetCompletion,
    );
  }

  ChoreOccurrence seriesUpdated({
    required String title,
    required String? description,
    required HouseholdMemberId assigneeMemberId,
    required String assigneeDisplayName,
    required ChoreLocalTime? dueLocalTime,
    required DateTime? dueAt,
    required ChoreRecurrenceRule recurrenceRule,
    required int seriesVersion,
  }) {
    if ((dueLocalTime == null) != (dueAt == null)) {
      throw ArgumentError(
        'A timed occurrence requires both local and UTC time.',
      );
    }
    return ChoreOccurrence(
      id: id,
      seriesId: seriesId,
      title: title,
      description: description,
      assigneeMemberId: assigneeMemberId,
      assigneeDisplayName: assigneeDisplayName,
      dueLocalDate: dueLocalDate,
      dueLocalTime: dueLocalTime,
      dueAt: dueAt,
      recurrenceFrequency: recurrenceRule.frequency,
      status: status,
      version: version,
      seriesVersion: seriesVersion,
      seriesDefaultAssigneeMemberId: assigneeMemberId,
      seriesDueLocalTime: dueLocalTime,
      recurrenceRule: recurrenceRule,
      canManageSeries: canManageSeries,
      canSetCompletion: canSetCompletion,
    );
  }
}

final class TodayChores {
  TodayChores({
    required this.householdId,
    required this.householdTimezone,
    required this.localDate,
    required List<ChoreOccurrence> occurrences,
    this.view = ChoreListView.today,
    this.assigneeFilterMemberId,
    this.generatedAt,
    this.pageLimit = 30,
    this.hasMore = false,
    this.nextCursor,
  }) : assert(pageLimit >= 1 && pageLimit <= 100),
       assert(!hasMore || nextCursor != null),
       assert(nextCursor == null || hasMore),
       assert(generatedAt == null || generatedAt.isUtc),
       occurrences = List<ChoreOccurrence>.unmodifiable(occurrences);

  final HouseholdId householdId;
  final String householdTimezone;
  final ChoreLocalDate localDate;
  final List<ChoreOccurrence> occurrences;
  final ChoreListView view;
  final HouseholdMemberId? assigneeFilterMemberId;
  final DateTime? generatedAt;
  final int pageLimit;
  final bool hasMore;
  final ChoreListCursor? nextCursor;

  bool matches(ChoreOccurrence occurrence) {
    if (assigneeFilterMemberId != null &&
        occurrence.assigneeMemberId != assigneeFilterMemberId) {
      return false;
    }
    final int dateComparison = occurrence.dueLocalDate.value.compareTo(
      localDate.value,
    );
    return switch (view) {
      ChoreListView.today =>
        dateComparison == 0 &&
            (occurrence.status == ChoreOccurrenceStatus.scheduled ||
                occurrence.status == ChoreOccurrenceStatus.completed),
      ChoreListView.upcoming =>
        dateComparison > 0 &&
            occurrence.status == ChoreOccurrenceStatus.scheduled,
      ChoreListView.overdue =>
        dateComparison < 0 &&
            occurrence.status == ChoreOccurrenceStatus.scheduled,
      ChoreListView.completed =>
        occurrence.status == ChoreOccurrenceStatus.completed,
    };
  }

  TodayChores applyOccurrence(ChoreOccurrence occurrence) {
    final List<ChoreOccurrence> updated = occurrences
        .where((ChoreOccurrence item) => item.id != occurrence.id)
        .toList(growable: true);
    if (matches(occurrence)) {
      updated.add(occurrence);
      updated.sort((ChoreOccurrence left, ChoreOccurrence right) {
        return _compareChoreListOccurrences(view, left, right);
      });
    }
    return _copyWithOccurrences(updated);
  }

  TodayChores? appendPage(TodayChores page) {
    if (householdId != page.householdId ||
        householdTimezone != page.householdTimezone ||
        localDate != page.localDate ||
        view != page.view ||
        assigneeFilterMemberId != page.assigneeFilterMemberId ||
        pageLimit != page.pageLimit) {
      return null;
    }
    final List<ChoreOccurrence> merged = <ChoreOccurrence>[
      ...occurrences,
      ...page.occurrences,
    ];
    if (merged.map((ChoreOccurrence item) => item.id).toSet().length !=
        merged.length) {
      return null;
    }
    for (var index = 1; index < merged.length; index += 1) {
      if (_compareChoreListOccurrences(
            view,
            merged[index - 1],
            merged[index],
          ) >=
          0) {
        return null;
      }
    }
    return TodayChores(
      householdId: householdId,
      householdTimezone: householdTimezone,
      localDate: localDate,
      occurrences: merged,
      view: view,
      assigneeFilterMemberId: assigneeFilterMemberId,
      generatedAt: generatedAt,
      pageLimit: pageLimit,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  TodayChores replaceOccurrence(ChoreOccurrence replacement) {
    return _copyWithOccurrences(
      occurrences
          .map(
            (ChoreOccurrence occurrence) =>
                occurrence.id == replacement.id ? replacement : occurrence,
          )
          .toList(growable: false),
    );
  }

  TodayChores removeOccurrence(ChoreOccurrenceId occurrenceId) {
    return _copyWithOccurrences(
      occurrences
          .where((ChoreOccurrence occurrence) => occurrence.id != occurrenceId)
          .toList(growable: false),
    );
  }

  TodayChores removeSeries(ChoreSeriesId seriesId) {
    return _copyWithOccurrences(
      occurrences
          .where(
            (ChoreOccurrence occurrence) => occurrence.seriesId != seriesId,
          )
          .toList(growable: false),
    );
  }

  TodayChores insertOccurrenceAt(
    ChoreOccurrence occurrence, {
    required int index,
  }) {
    final List<ChoreOccurrence> updated = occurrences
        .where((ChoreOccurrence item) => item.id != occurrence.id)
        .toList(growable: true);
    final int safeIndex = index < 0
        ? 0
        : index > updated.length
        ? updated.length
        : index;
    updated.insert(safeIndex, occurrence);
    return _copyWithOccurrences(updated);
  }

  TodayChores applyReschedule(ChoreOccurrence occurrence) {
    return applyOccurrence(occurrence);
  }

  TodayChores _copyWithOccurrences(List<ChoreOccurrence> updated) {
    return TodayChores(
      householdId: householdId,
      householdTimezone: householdTimezone,
      localDate: localDate,
      occurrences: updated,
      view: view,
      assigneeFilterMemberId: assigneeFilterMemberId,
      generatedAt: generatedAt,
      pageLimit: pageLimit,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }
}

int _compareChoreListOccurrences(
  ChoreListView view,
  ChoreOccurrence left,
  ChoreOccurrence right,
) {
  final int dateComparison = left.dueLocalDate.value.compareTo(
    right.dueLocalDate.value,
  );
  if (dateComparison != 0) {
    return view == ChoreListView.completed ? -dateComparison : dateComparison;
  }
  final ChoreLocalTime? leftLocalTime = left.dueLocalTime;
  final ChoreLocalTime? rightLocalTime = right.dueLocalTime;
  if (leftLocalTime == null && rightLocalTime != null) {
    return 1;
  }
  if (leftLocalTime != null && rightLocalTime == null) {
    return -1;
  }
  if (leftLocalTime != null && rightLocalTime != null) {
    final int localTimeComparison = leftLocalTime.value.compareTo(
      rightLocalTime.value,
    );
    if (localTimeComparison != 0) {
      return view == ChoreListView.completed
          ? -localTimeComparison
          : localTimeComparison;
    }
  }
  final DateTime? leftDueAt = left.dueAt;
  final DateTime? rightDueAt = right.dueAt;
  if (leftDueAt != null && rightDueAt != null) {
    final int dueAtComparison = leftDueAt.compareTo(rightDueAt);
    if (dueAtComparison != 0) {
      return view == ChoreListView.completed
          ? -dueAtComparison
          : dueAtComparison;
    }
  }
  final int idComparison = left.id.value.compareTo(right.id.value);
  return view == ChoreListView.completed ? -idComparison : idComparison;
}
