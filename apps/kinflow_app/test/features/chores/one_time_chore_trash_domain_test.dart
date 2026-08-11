import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  group('DeletedOneTimeChoreCursor', () {
    test('accepts only bounded even lowercase hexadecimal cursors', () {
      expect(DeletedOneTimeChoreCursor.tryParse('7b7d')?.value, '7b7d');
      expect(DeletedOneTimeChoreCursor.tryParse('7B7D'), isNull);
      expect(DeletedOneTimeChoreCursor.tryParse('abc'), isNull);
      expect(DeletedOneTimeChoreCursor.tryParse('zz'), isNull);
      expect(DeletedOneTimeChoreCursor.tryParse(''), isNull);
    });
  });

  test('builds a strictly ordered bounded trash page', () {
    final DeletedOneTimeChoreCursor cursor = DeletedOneTimeChoreCursor.tryParse(
      '7b7d',
    )!;
    final DeletedOneTimeChorePage? page = DeletedOneTimeChorePage.tryCreate(
      householdId: _householdId,
      householdTimezone: 'Asia/Seoul',
      generatedAt: DateTime.parse('2026-08-09T10:30:00Z'),
      pageLimit: 2,
      hasMore: true,
      nextCursor: cursor,
      items: <DeletedOneTimeChore>[
        _item(
          seriesId: '44444444-4444-4444-8444-444444444449',
          occurrenceId: '55555555-5555-4555-8555-555555555559',
        ),
        _item(
          seriesId: '44444444-4444-4444-8444-444444444448',
          occurrenceId: '55555555-5555-4555-8555-555555555558',
        ),
      ],
    );

    expect(page, isNotNull);
    expect(page!.hasMore, isTrue);
    expect(page.nextCursor, cursor);
    expect(page.items, hasLength(2));
  });

  test('rejects unsorted, duplicate, and incomplete timing payloads', () {
    final DeletedOneTimeChore newer = _item(
      seriesId: '44444444-4444-4444-8444-444444444441',
      occurrenceId: '55555555-5555-4555-8555-555555555551',
      deletedAt: DateTime.parse('2026-08-09T11:00:00Z'),
    );
    final DeletedOneTimeChore older = _item(
      seriesId: '44444444-4444-4444-8444-444444444442',
      occurrenceId: '55555555-5555-4555-8555-555555555552',
      deletedAt: DateTime.parse('2026-08-09T10:00:00Z'),
    );
    expect(
      DeletedOneTimeChorePage.tryCreate(
        householdId: _householdId,
        householdTimezone: 'Asia/Seoul',
        generatedAt: DateTime.parse('2026-08-09T10:30:00Z'),
        pageLimit: 2,
        hasMore: false,
        nextCursor: null,
        items: <DeletedOneTimeChore>[older, newer],
      ),
      isNull,
    );
    expect(
      DeletedOneTimeChorePage.tryCreate(
        householdId: _householdId,
        householdTimezone: 'Asia/Seoul',
        generatedAt: DateTime.parse('2026-08-09T10:30:00Z'),
        pageLimit: 2,
        hasMore: false,
        nextCursor: null,
        items: <DeletedOneTimeChore>[newer, newer],
      ),
      isNull,
    );
    expect(
      DeletedOneTimeChore.tryCreate(
        householdId: _householdId,
        seriesId: _seriesId,
        occurrenceId: _occurrenceId,
        title: 'Take out recycling',
        description: null,
        assigneeMemberId: _memberId,
        assigneeDisplayName: 'Alex',
        dueLocalDate: _date,
        dueLocalTime: ChoreLocalTime.tryParse('19:30'),
        dueAt: null,
        deletedAt: DateTime.parse('2026-08-09T10:00:00Z'),
        seriesVersion: 2,
        occurrenceVersion: 2,
      ),
      isNull,
    );
  });

  test(
    'restore draft preserves exact post-delete versions and fingerprint',
    () {
      final OneTimeChoreRestoreDraft draft = OneTimeChoreRestoreDraft.tryCreate(
        householdId: _householdId,
        seriesId: _seriesId,
        occurrenceId: _occurrenceId,
        expectedSeriesVersion: 2,
        expectedOccurrenceVersion: 3,
      )!;
      final RestoreOneTimeChoreRequest request = draft.withId(_commandId);

      expect(draft.fingerprint, contains('restoreOneTimeChore'));
      expect(request.idempotencyKey, _commandId);
      expect(request.expectedSeriesVersion, 2);
      expect(request.expectedOccurrenceVersion, 3);
      expect(
        OneTimeChoreRestoreDraft.tryCreate(
          householdId: _householdId,
          seriesId: _seriesId,
          occurrenceId: _occurrenceId,
          expectedSeriesVersion: 1,
          expectedOccurrenceVersion: 2,
        ),
        isNull,
      );
    },
  );
}

DeletedOneTimeChore _item({
  required String seriesId,
  required String occurrenceId,
  DateTime? deletedAt,
}) {
  return DeletedOneTimeChore.tryCreate(
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse(seriesId)!,
    occurrenceId: ChoreOccurrenceId.tryParse(occurrenceId)!,
    title: 'Take out recycling',
    description: 'Blue bin',
    assigneeMemberId: _memberId,
    assigneeDisplayName: 'Alex',
    dueLocalDate: _date,
    dueLocalTime: ChoreLocalTime.tryParse('19:30'),
    dueAt: DateTime.parse('2026-08-09T10:30:00Z'),
    deletedAt: deletedAt ?? DateTime.parse('2026-08-09T10:00:00Z'),
    seriesVersion: 2,
    occurrenceVersion: 2,
  )!;
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
final HouseholdMemberId _memberId = HouseholdMemberId.tryParse(
  '33333333-3333-4333-8333-333333333333',
)!;
final ChoreSeriesId _seriesId = ChoreSeriesId.tryParse(
  '44444444-4444-4444-8444-444444444444',
)!;
final ChoreOccurrenceId _occurrenceId = ChoreOccurrenceId.tryParse(
  '55555555-5555-4555-8555-555555555555',
)!;
final ChoreCommandId _commandId = ChoreCommandId.tryParse(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
)!;
final ChoreLocalDate _date = ChoreLocalDate.tryParse('2026-08-09')!;
