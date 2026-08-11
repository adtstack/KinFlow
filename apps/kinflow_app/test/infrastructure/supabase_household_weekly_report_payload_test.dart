import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_data_source.dart';

void main() {
  test('parses the one exact weekly report row and member shape', () {
    final HouseholdWeeklyReportDataRecord? record =
        householdWeeklyReportRecordFromPayload(
          <Object?>[_payload()],
          expectedHouseholdId: _householdId,
          expectedWeekOffset: 0,
        );

    expect(record, isNotNull);
    expect(record!.householdTimezone, 'Asia/Seoul');
    expect(record.weekStart, '2026-08-03');
    expect(record.completedCount, 3);
    expect(record.members, hasLength(2));
    expect(record.members.first.displayName, 'Alex');
    expect(record.members.first.isViewer, isTrue);
  });

  test('rejects missing, extra, or multiple outer rows', () {
    final Map<String, Object?> missing = _payload()..remove('due_count');
    final Map<String, Object?> extra = _payload()..['email'] = 'hidden@test';

    expect(_parse(<Object?>[missing]), isNull);
    expect(_parse(<Object?>[extra]), isNull);
    expect(_parse(const <Object?>[]), isNull);
    expect(_parse(<Object?>[_payload(), _payload()]), isNull);
  });

  test('rejects mismatched scope and mistyped counts', () {
    final Map<String, Object?> wrongOffset = _payload()..['week_offset'] = 1;
    final Map<String, Object?> wrongHousehold = _payload()
      ..['household_id'] = '99999999-9999-4999-8999-999999999999';
    final Map<String, Object?> wrongCount = _payload()..['due_count'] = '4';
    final Map<String, Object?> negativeCount = _payload()..['open_count'] = -1;

    expect(_parse(<Object?>[wrongOffset]), isNull);
    expect(_parse(<Object?>[wrongHousehold]), isNull);
    expect(_parse(<Object?>[wrongCount]), isNull);
    expect(_parse(<Object?>[negativeCount]), isNull);
  });

  test('rejects non-exact contributor rows and payloads over the cap', () {
    final Map<String, Object?> memberWithExtra = Map<String, Object?>.of(
      (_payload()['member_breakdown']! as List<Object?>).first!
          as Map<String, Object?>,
    )..['email'] = 'hidden@test';
    final Map<String, Object?> extraMemberPayload = _payload()
      ..['member_breakdown'] = <Object?>[memberWithExtra];
    final Map<String, Object?> tooManyPayload = _payload()
      ..['member_breakdown'] = List<Object?>.generate(
        21,
        (int index) => <String, Object?>{
          'memberId': 'member-$index',
          'displayName': 'Member $index',
          'completedCount': 1,
          'completedByWeekEndCount': 1,
          'isViewer': false,
        },
      );

    expect(_parse(<Object?>[extraMemberPayload]), isNull);
    expect(_parse(<Object?>[tooManyPayload]), isNull);
  });
}

const String _householdId = '22222222-2222-4222-8222-222222222222';

HouseholdWeeklyReportDataRecord? _parse(Object? payload) {
  return householdWeeklyReportRecordFromPayload(
    payload,
    expectedHouseholdId: _householdId,
    expectedWeekOffset: 0,
  );
}

Map<String, Object?> _payload() {
  return <String, Object?>{
    'household_id': _householdId,
    'household_timezone': 'Asia/Seoul',
    'generated_at': '2026-08-10T01:00:00Z',
    'week_offset': 0,
    'week_start': '2026-08-03',
    'week_end': '2026-08-09',
    'due_count': 4,
    'completed_count': 3,
    'completed_by_week_end_count': 2,
    'completed_after_week_end_count': 1,
    'open_count': 1,
    'skipped_count': 1,
    'viewer_completed_count': 2,
    'member_breakdown': <Object?>[
      <String, Object?>{
        'memberId': '33333333-3333-4333-8333-333333333333',
        'displayName': 'Alex',
        'completedCount': 2,
        'completedByWeekEndCount': 1,
        'isViewer': true,
      },
      <String, Object?>{
        'memberId': '33333333-3333-4333-8333-333333333334',
        'displayName': 'Sam',
        'completedCount': 1,
        'completedByWeekEndCount': 1,
        'isViewer': false,
      },
    ],
    'other_member_completed_count': 0,
    'member_breakdown_truncated': false,
  };
}
