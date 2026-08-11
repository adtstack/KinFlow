import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_calendar_data_source.dart';

const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _seriesId = '44444444-4444-4444-8444-444444444444';

void main() {
  group('Supabase calendar payload contract', () {
    test('accepts one strict metadata envelope for an empty list', () {
      final CalendarEventListDataRecord? record =
          calendarEventListRecordFromPayload(
            <Map<String, Object?>>[_emptyRow()],
            expectedHouseholdId: _householdId,
            expectedLimit: 100,
          );

      expect(record?.householdTimezone, 'Asia/Seoul');
      expect(record?.householdLocalDate, '2026-08-07');
      expect(record?.events, isEmpty);
    });

    test('normalizes provider time and timestamptz representations', () {
      final CalendarEventListDataRecord? record =
          calendarEventListRecordFromPayload(
            <Map<String, Object?>>[_timedRow()],
            expectedHouseholdId: _householdId,
            expectedLimit: 100,
          );

      expect(record?.events.single.localStartTime, '19:00');
      expect(record?.events.single.startsAt, '2026-08-07T10:00:00.000Z');
      expect(record?.events.single.endsAt, '2026-08-07T11:00:00.000Z');
      expect(record?.events.single.participantDisplayNames, <String>['Alex']);
    });

    test('accepts all-day date-only fields without timezone pollution', () {
      final CalendarEventDataRecord? record = calendarEventRecordFromPayload(
        _allDayRow(),
        expectedHouseholdId: _householdId,
      );

      expect(record?.isAllDay, isTrue);
      expect(record?.allDayEndDateExclusive, '2026-08-10');
      expect(record?.timezone, isNull);
      expect(record?.startsAt, isNull);
    });

    test('accepts only one exact content-free occurrence locator row', () {
      final Map<String, Object?> row = <String, Object?>{
        'household_id': _householdId,
        'household_timezone': 'Asia/Seoul',
        'household_local_date': '2026-08-08',
        'generated_at': '2026-08-07T15:00:00+00:00',
        'series_id': _seriesId,
        'occurrence_id': _occurrenceId,
        'view_local_date': '2026-08-09',
        'series_version': 3,
        'occurrence_version': 2,
      };

      final CalendarOccurrenceLocatorDataRecord? record =
          calendarOccurrenceLocatorRecordFromPayload(
            <Map<String, Object?>>[row],
            expectedHouseholdId: _householdId,
            expectedOccurrenceId: _occurrenceId,
          );

      expect(record?.generatedAt, '2026-08-07T15:00:00.000Z');
      expect(record?.viewLocalDate, '2026-08-09');
      expect(
        calendarOccurrenceLocatorRecordFromPayload(
          <Map<String, Object?>>[
            <String, Object?>{...row, 'title': 'private'},
          ],
          expectedHouseholdId: _householdId,
          expectedOccurrenceId: _occurrenceId,
        ),
        isNull,
      );
    });

    test('requires exact create and update marker shapes', () {
      final CalendarEventDataRecord? created =
          calendarEventCreatedRecordFromPayload(
            _timedRow()..['created'] = false,
            expectedHouseholdId: _householdId,
          );
      final CalendarEventDataRecord? updated =
          calendarEventUpdatedRecordFromPayload(
            _timedRow()
              ..['version'] = 2
              ..['occurrence_version'] = 2
              ..['changed'] = true,
            expectedHouseholdId: _householdId,
          );

      expect(created?.version, 1);
      expect(updated?.version, 2);
      expect(
        calendarEventCreatedRecordFromPayload(
          _timedRow()..['created'] = 'yes',
          expectedHouseholdId: _householdId,
        ),
        isNull,
      );
      expect(
        calendarEventUpdatedRecordFromPayload(
          _timedRow()..['changed'] = 1,
          expectedHouseholdId: _householdId,
        ),
        isNull,
      );
    });

    test('accepts strict idempotent deletion snapshots', () {
      final CalendarEventDeletionDataRecord? record =
          calendarEventDeletionRecordFromPayload(
            <String, Object?>{
              'household_id': _householdId,
              'series_id': _seriesId,
              'occurrence_id': '55555555-5555-4555-8555-555555555555',
              'version': 2,
              'occurrence_version': 2,
              'deleted': true,
              'changed': false,
            },
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );

      expect(record?.deleted, isTrue);
      expect(record?.changed, isFalse);
    });

    test('rejects extra, missing, mixed envelope, and local timestamps', () {
      for (final Object? payload in <Object?>[
        const <Object?>[],
        <Map<String, Object?>>[_timedRow()..['unexpected'] = true],
        <Map<String, Object?>>[_timedRow()..remove('series_id')],
        <Map<String, Object?>>[_emptyRow(), _timedRow()],
        <Map<String, Object?>>[
          _timedRow()..['household_timezone'] = 'America/Los_Angeles',
          _timedRow(),
        ],
        <Map<String, Object?>>[
          _timedRow()..['starts_at'] = '2026-08-07T10:00:00',
        ],
      ]) {
        expect(
          calendarEventListRecordFromPayload(
            payload,
            expectedHouseholdId: _householdId,
            expectedLimit: 100,
          ),
          isNull,
        );
      }
    });

    test('accepts a strict projected event page and its keyset metadata', () {
      final CalendarEventPageDataRecord? record =
          calendarEventPageRecordFromPayload(
            <Map<String, Object?>>[
              _pageRow()
                ..['page_limit'] = 1
                ..['has_more'] = true
                ..['page_cursor'] = 'aa',
            ],
            expectedHouseholdId: _householdId,
            expectedViewMode: 'agenda',
            expectedRangeStartDate: '2026-08-07',
            expectedRangeEndDateExclusive: '2026-11-05',
            expectedLimit: 1,
          );

      expect(record?.items.single.viewLocalDate, '2026-08-07');
      expect(record?.items.single.viewLocalTime, '19:00');
      expect(record?.hasMore, isTrue);
      expect(record?.pageCursor, 'aa');
    });

    test('accepts recurring metadata in the v2 projected event page', () {
      final CalendarEventPageDataRecord? record =
          calendarEventPageRecordFromPayload(
            <Map<String, Object?>>[
              _pageRow()
                ..['recurrence_rule'] = <String, Object?>{
                  'frequency': 'weekly',
                  'interval': 1,
                  'weekdays': <String>['FR'],
                  'end': <String, Object?>{
                    'type': 'until',
                    'localDate': '2026-11-27',
                  },
                }
                ..['revision_number'] = 2,
            ],
            expectedHouseholdId: _householdId,
            expectedViewMode: 'agenda',
            expectedRangeStartDate: '2026-08-07',
            expectedRangeEndDateExclusive: '2026-11-05',
            expectedLimit: 30,
          );

      expect(record?.items.single.event.recurrenceRule?['frequency'], 'weekly');
      expect(record?.items.single.event.recurrenceLocalStartDate, '2026-08-07');
      expect(record?.items.single.event.revisionNumber, 2);
      expect(record?.items.single.event.isException, isFalse);
    });

    test('accepts exactly one metadata-only empty page row', () {
      final CalendarEventPageDataRecord? record =
          calendarEventPageRecordFromPayload(
            <Map<String, Object?>>[_emptyPageRow()],
            expectedHouseholdId: _householdId,
            expectedViewMode: 'day',
            expectedRangeStartDate: '2026-08-08',
            expectedRangeEndDateExclusive: '2026-08-09',
            expectedLimit: 30,
          );

      expect(record?.items, isEmpty);
      expect(record?.rangeStartDate, '2026-08-08');
    });

    test('rejects non-integer limits and inconsistent page metadata', () {
      expect(
        calendarEventPageRecordFromPayload(
          <Map<String, Object?>>[_pageRow()..['page_limit'] = 30.0],
          expectedHouseholdId: _householdId,
          expectedViewMode: 'agenda',
          expectedRangeStartDate: '2026-08-07',
          expectedRangeEndDateExclusive: '2026-11-05',
          expectedLimit: 30,
        ),
        isNull,
      );
      expect(
        calendarEventPageRecordFromPayload(
          <Map<String, Object?>>[
            _pageRow(),
            _pageRow()..['generated_at'] = '2026-08-08T00:00:00Z',
          ],
          expectedHouseholdId: _householdId,
          expectedViewMode: 'agenda',
          expectedRangeStartDate: '2026-08-07',
          expectedRangeEndDateExclusive: '2026-11-05',
          expectedLimit: 30,
        ),
        isNull,
      );
    });

    test('accepts strict content-free month count rows', () {
      final List<Map<String, Object?>> rows = List.generate(
        31,
        (int index) => _monthRow(index + 1),
      );

      final CalendarMonthSummaryDataRecord? record =
          calendarMonthSummaryRecordFromPayload(
            rows,
            expectedHouseholdId: _householdId,
            expectedMonthStartDate: '2026-08-01',
          );

      expect(record?.days, hasLength(31));
      expect(record?.days[6].eventCount, 2);
      expect(rows.first.containsKey('title'), isFalse);
    });

    test('accepts one strict recurring creation snapshot', () {
      final RecurringCalendarEventDataRecord? record =
          recurringCalendarEventRecordFromPayload(
            _recurringCreatedRow(),
            expectedHouseholdId: _householdId,
          );

      expect(record?.seriesId, _seriesId);
      expect(record?.recurrenceRule['frequency'], 'weekly');
      expect(record?.materializedCount, 17);
      expect(record?.created, isTrue);
    });

    test('rejects malformed or widened recurring creation snapshots', () {
      for (final Object? payload in <Object?>[
        _recurringCreatedRow()..['materialized_count'] = 17.0,
        _recurringCreatedRow()..['recurrence_rule'] = 'weekly',
        _recurringCreatedRow()..['unexpected'] = true,
        _recurringCreatedRow()..remove('first_occurrence_id'),
      ]) {
        expect(
          recurringCalendarEventRecordFromPayload(
            payload,
            expectedHouseholdId: _householdId,
          ),
          isNull,
        );
      }
    });

    test('accepts strict whole-series detail and command envelopes', () {
      final CalendarRecurringSeriesDetailDataRecord? detail =
          calendarRecurringSeriesDetailRecordFromPayload(
            _recurringSeriesDetailRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );
      final CalendarRecurringSeriesUpdateDataRecord? update =
          calendarRecurringSeriesUpdateRecordFromPayload(
            _recurringSeriesUpdateRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );
      final CalendarRecurringSeriesCancellationDataRecord? cancellation =
          calendarRecurringSeriesCancellationRecordFromPayload(
            _recurringSeriesCancellationRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );
      final CalendarRecurringSeriesFromOccurrenceCancellationDataRecord?
      selectedCancellation =
          calendarRecurringSeriesFromOccurrenceCancellationRecordFromPayload(
            _recurringSeriesFromOccurrenceCancellationRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );
      final CalendarRecurringSeriesCancellationResumeDataRecord? resumed =
          calendarRecurringSeriesCancellationResumeRecordFromPayload(
            _recurringSeriesCancellationResumeRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
          );

      expect(detail?.localStartTime, '09:30');
      expect(detail?.participantDisplayNames, const <String>['Alex']);
      expect(update?.preservedExceptionCount, 1);
      expect(cancellation?.preservedPastCount, 4);
      expect(selectedCancellation?.terminalRevisionId, _revisionId);
      expect(selectedCancellation?.terminalRevisionNumber, 5);
      expect(resumed?.restoredCount, 53);
      expect(resumed?.revisionNumber, 6);
    });

    test('rejects widened and mismatched whole-series envelopes', () {
      expect(
        calendarRecurringSeriesDetailRecordFromPayload(
          _recurringSeriesDetailRow()..['title'] = null,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesUpdateRecordFromPayload(
          _recurringSeriesUpdateRow()..['unexpected'] = true,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesCancellationRecordFromPayload(
          _recurringSeriesCancellationRow()..['series_id'] = 'different',
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesFromOccurrenceCancellationRecordFromPayload(
          _recurringSeriesFromOccurrenceCancellationRow()
            ..['terminal_revision_number'] = null,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesCancellationResumeRecordFromPayload(
          _recurringSeriesCancellationResumeRow()..['unexpected'] = true,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesCancellationResumeRecordFromPayload(
          _recurringSeriesCancellationResumeRow()..['revision_id'] = null,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
      expect(
        calendarRecurringSeriesFromOccurrenceCancellationRecordFromPayload(
          _recurringSeriesFromOccurrenceCancellationRow()
            ..['unexpected'] = true,
          expectedHouseholdId: _householdId,
          expectedSeriesId: _seriesId,
        ),
        isNull,
      );
    });

    test('accepts strict update and cancellation occurrence envelopes', () {
      final CalendarOccurrenceCommandDataRecord? updated =
          calendarOccurrenceCommandRecordFromPayload(
            _occurrenceCommandRow(),
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
            expectedOccurrenceId: _occurrenceId,
          );
      final CalendarOccurrenceCommandDataRecord? cancelled =
          calendarOccurrenceCommandRecordFromPayload(
            _occurrenceCommandRow()
              ..['revision_id'] = null
              ..['occurrence_version'] = 3
              ..['cancelled'] = true
              ..['changed'] = false,
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
            expectedOccurrenceId: _occurrenceId,
          );

      expect(updated?.revisionId, _revisionId);
      expect(updated?.exceptionVersion, 1);
      expect(updated?.changed, isTrue);
      expect(cancelled?.revisionId, isNull);
      expect(cancelled?.cancelled, isTrue);
      expect(cancelled?.changed, isFalse);
    });

    test('rejects widened, mismatched, and weak occurrence envelopes', () {
      for (final Object? payload in <Object?>[
        _occurrenceCommandRow()..['unexpected'] = true,
        _occurrenceCommandRow()..remove('exception_version'),
        _occurrenceCommandRow()..['occurrence_version'] = 2.0,
        _occurrenceCommandRow()..['cancelled'] = 'yes',
        _occurrenceCommandRow()..['household_id'] = 'different',
      ]) {
        expect(
          calendarOccurrenceCommandRecordFromPayload(
            payload,
            expectedHouseholdId: _householdId,
            expectedSeriesId: _seriesId,
            expectedOccurrenceId: _occurrenceId,
          ),
          isNull,
        );
      }
    });
  });

  test('maps stable public error codes without exposing provider text', () {
    expect(
      calendarDataFailureFromProviderCode('KFE01'),
      CalendarDataFailureKind.unauthenticated,
    );
    expect(
      calendarDataFailureFromProviderCode('KFE05'),
      CalendarDataFailureKind.staleVersion,
    );
    expect(
      calendarDataFailureFromProviderCode('KFE06'),
      CalendarDataFailureKind.nonexistentLocalTime,
    );
    expect(
      calendarDataFailureFromProviderCode('KFE07'),
      CalendarDataFailureKind.invalidInput,
    );
    expect(
      calendarDataFailureFromProviderCode('KFE08'),
      CalendarDataFailureKind.transitionNotAllowed,
    );
    expect(
      calendarDataFailureFromProviderCode('KFB10'),
      CalendarDataFailureKind.featurePolicyUnavailable,
    );
    expect(
      calendarDataFailureFromProviderCode('KFB11'),
      CalendarDataFailureKind.featurePolicyUnavailable,
    );
    expect(
      calendarDataFailureFromProviderCode('KFB12'),
      CalendarDataFailureKind.featureLimitReached,
    );
    expect(
      calendarDataFailureFromProviderCode('PGRST500'),
      CalendarDataFailureKind.temporarilyUnavailable,
    );
    expect(
      calendarDataFailureFromProviderCode('XX000'),
      CalendarDataFailureKind.unknown,
    );
  });
}

const String _occurrenceId = '55555555-5555-4555-8555-555555555555';
const String _revisionId = '77777777-7777-4777-8777-777777777777';

Map<String, Object?> _timedRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': _seriesId,
  'occurrence_id': '55555555-5555-4555-8555-555555555555',
  'title': 'Family dinner',
  'description': 'Bring dessert',
  'is_all_day': false,
  'local_start_date': '2026-08-07',
  'local_start_time': '19:00:00',
  'duration_minutes': 60,
  'all_day_end_date_exclusive': null,
  'timezone': 'Asia/Seoul',
  'overlap_policy': 'earlier',
  'starts_at': '2026-08-07T10:00:00+00:00',
  'ends_at': '2026-08-07T11:00:00+00:00',
  'dst_resolution': 'normal',
  'utc_offset_seconds': 32400,
  'participant_member_ids': <String>['33333333-3333-4333-8333-333333333333'],
  'participant_display_names': <String>['Alex'],
  'version': 1,
  'occurrence_version': 1,
};

Map<String, Object?> _allDayRow() => _timedRow()
  ..['is_all_day'] = true
  ..['local_start_time'] = null
  ..['duration_minutes'] = null
  ..['all_day_end_date_exclusive'] = '2026-08-10'
  ..['timezone'] = null
  ..['overlap_policy'] = null
  ..['starts_at'] = null
  ..['ends_at'] = null
  ..['dst_resolution'] = null
  ..['utc_offset_seconds'] = null;

Map<String, Object?> _emptyRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': null,
  'occurrence_id': null,
  'title': null,
  'description': null,
  'is_all_day': null,
  'local_start_date': null,
  'local_start_time': null,
  'duration_minutes': null,
  'all_day_end_date_exclusive': null,
  'timezone': null,
  'overlap_policy': null,
  'starts_at': null,
  'ends_at': null,
  'dst_resolution': null,
  'utc_offset_seconds': null,
  'participant_member_ids': null,
  'participant_display_names': null,
  'version': null,
  'occurrence_version': null,
};

Map<String, Object?> _pageRow() => _timedRow()
  ..addAll(<String, Object?>{
    'recurrence_rule': null,
    'recurrence_local_start_date': '2026-08-07',
    'revision_number': 1,
    'is_exception': false,
    'generated_at': '2026-08-07T00:00:00Z',
    'view_mode': 'agenda',
    'range_start_date': '2026-08-07',
    'range_end_date_exclusive': '2026-11-05',
    'page_limit': 30,
    'has_more': false,
    'page_cursor': null,
    'view_local_date': '2026-08-07',
    'view_local_time': '19:00:00',
  });

Map<String, Object?> _emptyPageRow() => _emptyRow()
  ..addAll(<String, Object?>{
    'recurrence_rule': null,
    'recurrence_local_start_date': null,
    'revision_number': null,
    'is_exception': null,
    'generated_at': '2026-08-07T00:00:00Z',
    'view_mode': 'day',
    'range_start_date': '2026-08-08',
    'range_end_date_exclusive': '2026-08-09',
    'page_limit': 30,
    'has_more': false,
    'page_cursor': null,
    'view_local_date': null,
    'view_local_time': null,
  });

Map<String, Object?> _monthRow(int day) => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'generated_at': '2026-08-07T00:00:00Z',
  'month_start_date': '2026-08-01',
  'month_end_date_exclusive': '2026-09-01',
  'day_date': '2026-08-${day.toString().padLeft(2, '0')}',
  'event_count': day == 7 ? 2 : 0,
  'all_day_count': day == 7 ? 1 : 0,
  'timed_count': day == 7 ? 1 : 0,
};

Map<String, Object?> _recurringCreatedRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': _seriesId,
  'first_occurrence_id': '55555555-5555-4555-8555-555555555555',
  'recurrence_rule': <String, Object?>{
    'frequency': 'weekly',
    'interval': 1,
    'weekdays': <String>['FR'],
    'end': <String, Object?>{'type': 'until', 'localDate': '2026-11-27'},
  },
  'materialized_through': '2026-11-27',
  'materialized_count': 17,
  'version': 1,
  'created': true,
};

Map<String, Object?> _recurringSeriesDetailRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': _seriesId,
  'revision_id': _revisionId,
  'revision_number': 3,
  'title': 'Family call',
  'description': null,
  'is_all_day': false,
  'local_start_date': '2026-08-07',
  'local_start_time': '09:30:00',
  'duration_minutes': 30,
  'all_day_end_date_exclusive': null,
  'timezone': 'Asia/Seoul',
  'overlap_policy': 'earlier',
  'recurrence_rule': <String, Object?>{
    'frequency': 'weekly',
    'interval': 1,
    'weekdays': <String>['FR'],
    'end': <String, Object?>{'type': 'never'},
  },
  'participant_member_ids': <String>['33333333-3333-4333-8333-333333333333'],
  'participant_display_names': <String>['Alex'],
  'version': 2,
};

Map<String, Object?> _recurringSeriesUpdateRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': _seriesId,
  'revision_id': _revisionId,
  'revision_number': 4,
  'effective_local_date': '2026-08-07',
  'materialized_through': '2027-08-07',
  'version': 3,
  'rebuilt_count': 52,
  'cancelled_count': 314,
  'preserved_exception_count': 1,
  'changed': true,
};

Map<String, Object?> _recurringSeriesCancellationRow() => <String, Object?>{
  'household_id': _householdId,
  'household_timezone': 'Asia/Seoul',
  'household_local_date': '2026-08-07',
  'series_id': _seriesId,
  'effective_local_date': '2026-08-07',
  'version': 4,
  'cancelled_count': 53,
  'preserved_past_count': 4,
  'changed': true,
};

Map<String, Object?> _recurringSeriesFromOccurrenceCancellationRow() =>
    <String, Object?>{
      ..._recurringSeriesCancellationRow(),
      'effective_local_date': '2026-08-12',
      'terminal_revision_id': _revisionId,
      'terminal_revision_number': 5,
    };

Map<String, Object?> _recurringSeriesCancellationResumeRow() =>
    <String, Object?>{
      'household_id': _householdId,
      'series_id': _seriesId,
      'effective_local_date': '2026-08-12',
      'version': 5,
      'restored_count': 53,
      'preserved_past_count': 4,
      'revision_id': _revisionId,
      'revision_number': 6,
      'changed': true,
    };

Map<String, Object?> _occurrenceCommandRow() => <String, Object?>{
  'household_id': _householdId,
  'series_id': _seriesId,
  'occurrence_id': _occurrenceId,
  'revision_id': _revisionId,
  'occurrence_version': 2,
  'exception_version': 1,
  'cancelled': false,
  'changed': true,
};
