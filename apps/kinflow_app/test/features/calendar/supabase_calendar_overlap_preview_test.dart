import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_calendar_data_source.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test('strict parser maps ordered overlap rows and normalizes time', () {
    final CalendarOverlapPreviewDataRecord? record =
        calendarOverlapPreviewRecordFromPayload(
          <Object?>[
            _row(
              occurrenceId: calendarOccurrenceOneUuid,
              seriesId: calendarSeriesOneUuid,
              title: 'School pickup',
              startTime: '09:00:00',
            ),
            _row(
              occurrenceId: calendarOccurrenceTwoUuid,
              seriesId: calendarSeriesTwoUuid,
              title: 'Dentist',
              startTime: '10:00:00.000000',
            ),
          ],
          expectedHouseholdId: calendarHouseholdUuid,
          expectedWindowStartDate: '2026-08-08',
          expectedLimit: 10,
        );

    expect(record, isNotNull);
    expect(record!.generatedAt, '2026-08-08T00:00:00.000Z');
    expect(record.totalConflictCount, 2);
    expect(record.conflicts, hasLength(2));
    expect(record.conflicts.last.viewLocalStartTime, '10:00');
    expect(record.conflicts.first.participantDisplayNames, <String>['Alex']);
  });

  test('strict parser accepts the single metadata-only zero result', () {
    final Map<String, Object?> row = _row(
      occurrenceId: null,
      seriesId: null,
      title: null,
      startTime: null,
      total: 0,
    );

    final CalendarOverlapPreviewDataRecord? record =
        calendarOverlapPreviewRecordFromPayload(
          <Object?>[row],
          expectedHouseholdId: calendarHouseholdUuid,
          expectedWindowStartDate: '2026-08-08',
          expectedLimit: 10,
        );

    expect(record, isNotNull);
    expect(record!.candidateOccurrenceCount, 1);
    expect(record.conflicts, isEmpty);
    expect(record.truncated, isFalse);
  });

  test(
    'strict parser rejects extras, mixed metadata, and false truncation',
    () {
      final Map<String, Object?> extra = <String, Object?>{
        ..._row(
          occurrenceId: calendarOccurrenceOneUuid,
          seriesId: calendarSeriesOneUuid,
          title: 'Private event',
          startTime: '09:00',
        ),
        'description': 'must never be returned',
      };
      expect(
        calendarOverlapPreviewRecordFromPayload(
          <Object?>[extra],
          expectedHouseholdId: calendarHouseholdUuid,
          expectedWindowStartDate: '2026-08-08',
          expectedLimit: 10,
        ),
        isNull,
      );

      final Map<String, Object?> first = _row(
        occurrenceId: calendarOccurrenceOneUuid,
        seriesId: calendarSeriesOneUuid,
        title: 'One',
        startTime: '09:00',
      );
      final Map<String, Object?> mixed = <String, Object?>{
        ..._row(
          occurrenceId: calendarOccurrenceTwoUuid,
          seriesId: calendarSeriesTwoUuid,
          title: 'Two',
          startTime: '10:00',
        ),
        'checked_through_local_date': '2027-08-09',
      };
      expect(
        calendarOverlapPreviewRecordFromPayload(
          <Object?>[first, mixed],
          expectedHouseholdId: calendarHouseholdUuid,
          expectedWindowStartDate: '2026-08-08',
          expectedLimit: 10,
        ),
        isNull,
      );

      final Map<String, Object?> falseTruncation = <String, Object?>{
        ...first,
        'total_conflict_count': 2,
        'truncated': false,
      };
      expect(
        calendarOverlapPreviewRecordFromPayload(
          <Object?>[falseTruncation],
          expectedHouseholdId: calendarHouseholdUuid,
          expectedWindowStartDate: '2026-08-08',
          expectedLimit: 10,
        ),
        isNull,
      );
    },
  );
}

Map<String, Object?> _row({
  required String? occurrenceId,
  required String? seriesId,
  required String? title,
  required String? startTime,
  int total = 2,
}) {
  final bool metadataOnly = occurrenceId == null;
  return <String, Object?>{
    'household_id': calendarHouseholdUuid,
    'household_timezone': 'Asia/Seoul',
    'household_local_date': '2026-08-08',
    'generated_at': '2026-08-08T00:00:00+00:00',
    'checked_from_local_date': '2026-08-08',
    'checked_through_local_date': '2026-08-08',
    'candidate_occurrence_count': 1,
    'total_conflict_count': total,
    'truncated': false,
    'candidate_local_start_date': metadataOnly ? null : '2026-08-08',
    'conflicting_series_id': seriesId,
    'conflicting_occurrence_id': occurrenceId,
    'conflicting_title': title,
    'conflicting_is_all_day': metadataOnly ? null : false,
    'conflicting_view_local_start_date': metadataOnly ? null : '2026-08-08',
    'conflicting_view_local_start_time': startTime,
    'conflicting_duration_minutes': metadataOnly ? null : 60,
    'conflicting_all_day_end_date_exclusive': null,
    'conflicting_participant_member_ids': metadataOnly
        ? null
        : <String>[calendarMemberOneUuid],
    'conflicting_participant_display_names': metadataOnly
        ? null
        : <String>['Alex'],
  };
}
