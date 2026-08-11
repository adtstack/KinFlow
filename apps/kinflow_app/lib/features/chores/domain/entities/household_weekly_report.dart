import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdWeeklyReportRequest {
  const HouseholdWeeklyReportRequest._({
    required this.householdId,
    required this.weekOffset,
  });

  static const int latestWeekOffset = 0;
  static const int oldestWeekOffset = 11;

  final HouseholdId householdId;
  final int weekOffset;

  static HouseholdWeeklyReportRequest? tryCreate({
    required HouseholdId householdId,
    required int weekOffset,
  }) {
    if (weekOffset < latestWeekOffset || weekOffset > oldestWeekOffset) {
      return null;
    }
    return HouseholdWeeklyReportRequest._(
      householdId: householdId,
      weekOffset: weekOffset,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HouseholdWeeklyReportRequest &&
        other.householdId == householdId &&
        other.weekOffset == weekOffset;
  }

  @override
  int get hashCode => Object.hash(householdId, weekOffset);
}

final class HouseholdWeeklyReportMember {
  const HouseholdWeeklyReportMember._({
    required this.memberId,
    required this.displayName,
    required this.completedCount,
    required this.completedByWeekEndCount,
    required this.isViewer,
  });

  final HouseholdMemberId memberId;
  final String displayName;
  final int completedCount;
  final int completedByWeekEndCount;
  final bool isViewer;

  static HouseholdWeeklyReportMember? tryCreate({
    required HouseholdMemberId memberId,
    required String displayName,
    required int completedCount,
    required int completedByWeekEndCount,
    required bool isViewer,
  }) {
    if (displayName.isEmpty ||
        displayName != displayName.trim() ||
        displayName.length > 80 ||
        _containsControlCharacter(displayName) ||
        completedCount < 1 ||
        completedByWeekEndCount < 0 ||
        completedByWeekEndCount > completedCount) {
      return null;
    }
    return HouseholdWeeklyReportMember._(
      memberId: memberId,
      displayName: displayName,
      completedCount: completedCount,
      completedByWeekEndCount: completedByWeekEndCount,
      isViewer: isViewer,
    );
  }
}

final class HouseholdWeeklyReport {
  HouseholdWeeklyReport._({
    required this.householdId,
    required this.householdTimezone,
    required this.generatedAt,
    required this.weekOffset,
    required this.weekStart,
    required this.weekEnd,
    required this.dueCount,
    required this.completedCount,
    required this.completedByWeekEndCount,
    required this.completedAfterWeekEndCount,
    required this.openCount,
    required this.skippedCount,
    required this.viewerCompletedCount,
    required List<HouseholdWeeklyReportMember> members,
    required this.otherMemberCompletedCount,
    required this.memberBreakdownTruncated,
  }) : members = List<HouseholdWeeklyReportMember>.unmodifiable(members);

  static const int maximumNamedMembers = 20;

  final HouseholdId householdId;
  final String householdTimezone;
  final DateTime generatedAt;
  final int weekOffset;
  final ChoreLocalDate weekStart;
  final ChoreLocalDate weekEnd;
  final int dueCount;
  final int completedCount;
  final int completedByWeekEndCount;
  final int completedAfterWeekEndCount;
  final int openCount;
  final int skippedCount;
  final int viewerCompletedCount;
  final List<HouseholdWeeklyReportMember> members;
  final int otherMemberCompletedCount;
  final bool memberBreakdownTruncated;

  static HouseholdWeeklyReport? tryCreate({
    required HouseholdId householdId,
    required String householdTimezone,
    required DateTime generatedAt,
    required int weekOffset,
    required ChoreLocalDate weekStart,
    required ChoreLocalDate weekEnd,
    required int dueCount,
    required int completedCount,
    required int completedByWeekEndCount,
    required int completedAfterWeekEndCount,
    required int openCount,
    required int skippedCount,
    required int viewerCompletedCount,
    required List<HouseholdWeeklyReportMember> members,
    required int otherMemberCompletedCount,
    required bool memberBreakdownTruncated,
  }) {
    final DateTime start = weekStart.toDateTime();
    final DateTime end = weekEnd.toDateTime();
    final Set<HouseholdMemberId> memberIds = members
        .map((HouseholdWeeklyReportMember member) => member.memberId)
        .toSet();
    final List<HouseholdWeeklyReportMember> viewerMembers = members
        .where((HouseholdWeeklyReportMember member) => member.isViewer)
        .toList(growable: false);
    final int namedCompletedCount = members.fold<int>(
      0,
      (int count, HouseholdWeeklyReportMember member) =>
          count + member.completedCount,
    );
    final int namedByWeekEndCount = members.fold<int>(
      0,
      (int count, HouseholdWeeklyReportMember member) =>
          count + member.completedByWeekEndCount,
    );

    if (!_isPlausibleTimezone(householdTimezone) ||
        !generatedAt.isUtc ||
        weekOffset < HouseholdWeeklyReportRequest.latestWeekOffset ||
        weekOffset > HouseholdWeeklyReportRequest.oldestWeekOffset ||
        start.weekday != DateTime.monday ||
        end.difference(start).inDays != 6 ||
        <int>[
          dueCount,
          completedCount,
          completedByWeekEndCount,
          completedAfterWeekEndCount,
          openCount,
          skippedCount,
          viewerCompletedCount,
          otherMemberCompletedCount,
        ].any((int count) => count < 0) ||
        completedCount !=
            completedByWeekEndCount + completedAfterWeekEndCount ||
        dueCount != completedCount + openCount ||
        viewerCompletedCount > completedCount ||
        members.length > maximumNamedMembers ||
        memberIds.length != members.length ||
        namedCompletedCount + otherMemberCompletedCount != completedCount ||
        namedByWeekEndCount > completedByWeekEndCount ||
        viewerMembers.length > 1 ||
        (viewerMembers.isNotEmpty &&
            viewerMembers.single.completedCount != viewerCompletedCount) ||
        (!memberBreakdownTruncated &&
            viewerCompletedCount > 0 &&
            viewerMembers.isEmpty) ||
        (memberBreakdownTruncated &&
            (members.length != maximumNamedMembers ||
                otherMemberCompletedCount == 0))) {
      return null;
    }

    return HouseholdWeeklyReport._(
      householdId: householdId,
      householdTimezone: householdTimezone,
      generatedAt: generatedAt,
      weekOffset: weekOffset,
      weekStart: weekStart,
      weekEnd: weekEnd,
      dueCount: dueCount,
      completedCount: completedCount,
      completedByWeekEndCount: completedByWeekEndCount,
      completedAfterWeekEndCount: completedAfterWeekEndCount,
      openCount: openCount,
      skippedCount: skippedCount,
      viewerCompletedCount: viewerCompletedCount,
      members: members,
      otherMemberCompletedCount: otherMemberCompletedCount,
      memberBreakdownTruncated: memberBreakdownTruncated,
    );
  }

  bool get hasDueChores => dueCount > 0;

  bool get isEmpty => dueCount == 0 && skippedCount == 0;

  bool get canLoadOlder =>
      weekOffset < HouseholdWeeklyReportRequest.oldestWeekOffset;

  bool get canLoadNewer =>
      weekOffset > HouseholdWeeklyReportRequest.latestWeekOffset;

  int? get completedByWeekEndPercent =>
      dueCount == 0 ? null : (completedByWeekEndCount * 100 / dueCount).round();
}

bool _containsControlCharacter(String value) {
  for (final int codeUnit in value.codeUnits) {
    if (codeUnit < 0x20 || codeUnit == 0x7f) {
      return true;
    }
  }
  return false;
}

bool _isPlausibleTimezone(String value) {
  return value.isNotEmpty &&
      value == value.trim() &&
      value.length <= 100 &&
      !_containsControlCharacter(value);
}
