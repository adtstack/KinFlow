import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  test('accepts only the twelve supported closed-week offsets', () {
    for (var offset = 0; offset <= 11; offset += 1) {
      expect(
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: _householdId,
          weekOffset: offset,
        ),
        isNotNull,
      );
    }
    expect(
      HouseholdWeeklyReportRequest.tryCreate(
        householdId: _householdId,
        weekOffset: -1,
      ),
      isNull,
    );
    expect(
      HouseholdWeeklyReportRequest.tryCreate(
        householdId: _householdId,
        weekOffset: 12,
      ),
      isNull,
    );
  });

  test('creates an immutable, internally consistent weekly aggregate', () {
    final List<HouseholdWeeklyReportMember> source =
        <HouseholdWeeklyReportMember>[
          _member(
            id: '33333333-3333-4333-8333-333333333333',
            name: 'Alex',
            completed: 2,
            byWeekEnd: 1,
            isViewer: true,
          ),
          _member(
            id: '33333333-3333-4333-8333-333333333334',
            name: 'Sam',
            completed: 1,
            byWeekEnd: 1,
          ),
        ];
    final HouseholdWeeklyReport report = _report(members: source)!;
    source.clear();

    expect(report.members, hasLength(2));
    expect(report.completedByWeekEndPercent, 50);
    expect(report.hasDueChores, isTrue);
    expect(report.isEmpty, isFalse);
    expect(report.canLoadNewer, isFalse);
    expect(report.canLoadOlder, isTrue);
    expect(
      () => report.members.add(
        _member(
          id: '33333333-3333-4333-8333-333333333335',
          name: 'Taylor',
          completed: 1,
          byWeekEnd: 1,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('rejects inconsistent count equations and week boundaries', () {
    expect(_report(dueCount: 5), isNull);
    expect(_report(completedAfterWeekEndCount: 2), isNull);
    expect(_report(viewerCompletedCount: 1), isNull);
    expect(_report(weekStart: '2026-08-04', weekEnd: '2026-08-10'), isNull);
  });

  test('rejects unsafe member breakdown and truncation combinations', () {
    expect(
      _report(
        members: <HouseholdWeeklyReportMember>[
          _member(
            id: '33333333-3333-4333-8333-333333333333',
            name: 'Alex',
            completed: 2,
            byWeekEnd: 1,
          ),
          _member(
            id: '33333333-3333-4333-8333-333333333334',
            name: 'Sam',
            completed: 1,
            byWeekEnd: 1,
          ),
        ],
      ),
      isNull,
    );
    expect(_report(memberBreakdownTruncated: true), isNull);
    expect(
      HouseholdWeeklyReportMember.tryCreate(
        memberId: _memberId,
        displayName: ' Alex ',
        completedCount: 1,
        completedByWeekEndCount: 1,
        isViewer: true,
      ),
      isNull,
    );
  });
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
final HouseholdMemberId _memberId = HouseholdMemberId.tryParse(
  '33333333-3333-4333-8333-333333333333',
)!;

HouseholdWeeklyReportMember _member({
  required String id,
  required String name,
  required int completed,
  required int byWeekEnd,
  bool isViewer = false,
}) {
  return HouseholdWeeklyReportMember.tryCreate(
    memberId: HouseholdMemberId.tryParse(id)!,
    displayName: name,
    completedCount: completed,
    completedByWeekEndCount: byWeekEnd,
    isViewer: isViewer,
  )!;
}

HouseholdWeeklyReport? _report({
  String weekStart = '2026-08-03',
  String weekEnd = '2026-08-09',
  int dueCount = 4,
  int completedCount = 3,
  int completedByWeekEndCount = 2,
  int completedAfterWeekEndCount = 1,
  int openCount = 1,
  int viewerCompletedCount = 2,
  List<HouseholdWeeklyReportMember>? members,
  bool memberBreakdownTruncated = false,
}) {
  return HouseholdWeeklyReport.tryCreate(
    householdId: _householdId,
    householdTimezone: 'Asia/Seoul',
    generatedAt: DateTime.parse('2026-08-10T01:00:00Z'),
    weekOffset: 0,
    weekStart: ChoreLocalDate.tryParse(weekStart)!,
    weekEnd: ChoreLocalDate.tryParse(weekEnd)!,
    dueCount: dueCount,
    completedCount: completedCount,
    completedByWeekEndCount: completedByWeekEndCount,
    completedAfterWeekEndCount: completedAfterWeekEndCount,
    openCount: openCount,
    skippedCount: 1,
    viewerCompletedCount: viewerCompletedCount,
    members:
        members ??
        <HouseholdWeeklyReportMember>[
          _member(
            id: '33333333-3333-4333-8333-333333333333',
            name: 'Alex',
            completed: 2,
            byWeekEnd: 1,
            isViewer: true,
          ),
          _member(
            id: '33333333-3333-4333-8333-333333333334',
            name: 'Sam',
            completed: 1,
            byWeekEnd: 1,
          ),
        ],
    otherMemberCompletedCount: 0,
    memberBreakdownTruncated: memberBreakdownTruncated,
  );
}
