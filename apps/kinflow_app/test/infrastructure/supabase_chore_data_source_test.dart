import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_data_source.dart';

void main() {
  group('Supabase chore payload contract', () {
    test('accepts only one exact capped activation progress row', () {
      final Map<String, Object?> valid = <String, Object?>{
        'household_id': '22222222-2222-4222-8222-222222222222',
        'adult_participant_progress': 2,
        'chore_creation_progress': 3,
        'distinct_adult_completer_progress': 1,
        'return_after_first_day_reached': true,
      };

      final HouseholdActivationProgressDataRecord? record =
          householdActivationProgressRecordFromPayload(<Map<String, Object?>>[
            valid,
          ], expectedHouseholdId: '22222222-2222-4222-8222-222222222222');

      expect(record?.adultParticipantProgress, 2);
      expect(record?.choreCreationProgress, 3);
      expect(record?.distinctAdultCompleterProgress, 1);
      expect(record?.returnAfterFirstDayReached, isTrue);

      for (final Object? invalid in <Object?>[
        const <Object?>[],
        <Map<String, Object?>>[valid, valid],
        <Map<String, Object?>>[Map<String, Object?>.of(valid)..['extra'] = 1],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)..remove('chore_creation_progress'),
        ],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)
            ..['household_id'] = '99999999-9999-4999-8999-999999999999',
        ],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)..['adult_participant_progress'] = 3,
        ],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)..['chore_creation_progress'] = -1,
        ],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)
            ..['distinct_adult_completer_progress'] = 2.0,
        ],
        <Map<String, Object?>>[
          Map<String, Object?>.of(valid)
            ..['return_after_first_day_reached'] = 'yes',
        ],
        valid,
      ]) {
        expect(
          householdActivationProgressRecordFromPayload(
            invalid,
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
          ),
          isNull,
        );
      }
    });

    test('accepts one metadata-only row for an empty Today', () {
      final TodayChoresDataRecord? record = todayChoresRecordFromPayload(
        <Map<String, Object?>>[_todayRow()],
      );

      expect(record?.householdTimezone, 'Asia/Seoul');
      expect(record?.householdLocalDate, '2026-08-06');
      expect(record?.occurrences, isEmpty);
    });

    test('accepts strict Today item and create result shapes', () {
      final Map<String, Object?> todayItem = _todayRow()
        ..addAll(<String, Object?>{
          'occurrence_id': '55555555-5555-4555-8555-555555555555',
          'series_id': '44444444-4444-4444-8444-444444444444',
          'title': 'Take out recycling',
          'description': null,
          'assignee_member_id': '33333333-3333-4333-8333-333333333333',
          'assignee_display_name': 'Alex',
          'due_local_time': '19:30:00',
          'due_at': '2026-08-06T10:30:00+00:00',
          'status': 'scheduled',
          'version': 1,
          'recurrence_frequency': 'daily',
          'series_version': 1,
          'series_default_assignee_member_id':
              '33333333-3333-4333-8333-333333333333',
          'series_due_local_time': '19:30:00',
          'recurrence_rule': <String, Object?>{
            'frequency': 'daily',
            'interval': 1,
            'end': <String, Object?>{'type': 'never'},
          },
          'can_manage_series': true,
        });
      final TodayChoresDataRecord? today = todayChoresRecordFromPayload(
        <Map<String, Object?>>[todayItem],
      );
      const Set<String> createdKeys = <String>{
        'household_id',
        'series_id',
        'occurrence_id',
        'title',
        'description',
        'assignee_member_id',
        'assignee_display_name',
        'due_local_date',
        'due_local_time',
        'due_at',
        'status',
        'version',
        'created',
      };
      final ChoreOccurrenceDataRecord? created =
          choreOccurrenceRecordFromPayload(<String, Object?>{
            'household_id': '22222222-2222-4222-8222-222222222222',
            'series_id': '44444444-4444-4444-8444-444444444444',
            'occurrence_id': '55555555-5555-4555-8555-555555555555',
            'title': 'Take out recycling',
            'description': null,
            'assignee_member_id': '33333333-3333-4333-8333-333333333333',
            'assignee_display_name': 'Alex',
            'due_local_date': '2026-08-06',
            'due_local_time': '19:30:00',
            'due_at': '2026-08-06T10:30:00+00:00',
            'status': 'scheduled',
            'version': 1,
            'created': true,
          }, expectedKeys: createdKeys);

      expect(today?.occurrences.single.title, 'Take out recycling');
      expect(today?.occurrences.single.recurrenceFrequency, 'daily');
      expect(today?.occurrences.single.seriesVersion, 1);
      expect(today?.occurrences.single.canManageSeries, isTrue);
      expect(created?.version, 1);
      expect(
        choreOccurrenceRecordFromPayload(<String, Object?>{
          'household_id': '22222222-2222-4222-8222-222222222222',
          'series_id': '44444444-4444-4444-8444-444444444444',
          'occurrence_id': '55555555-5555-4555-8555-555555555555',
          'title': 'Take out recycling',
          'description': null,
          'assignee_member_id': '33333333-3333-4333-8333-333333333333',
          'assignee_display_name': 'Alex',
          'due_local_date': '2026-08-06',
          'due_local_time': null,
          'due_at': null,
          'status': 'scheduled',
          'version': 1,
          'created': 'yes',
        }, expectedKeys: createdKeys),
        isNull,
      );
    });

    test('accepts only the exact occurrence target projection', () {
      final ChoreOccurrenceDataRecord? record =
          choreOccurrenceTargetRecordFromPayload(_occurrenceTargetRow());

      expect(record?.occurrenceId, '55555555-5555-4555-8555-555555555551');
      expect(record?.recurrenceFrequency, 'daily');
      expect(record?.seriesVersion, 1);
      expect(record?.canManageSeries, isTrue);
      expect(record?.canSetCompletion, isTrue);

      expect(
        choreOccurrenceTargetRecordFromPayload(
          _occurrenceTargetRow()..['household_timezone'] = 'Asia/Seoul',
        ),
        isNull,
      );
      expect(
        choreOccurrenceTargetRecordFromPayload(
          _occurrenceTargetRow()..remove('occurrence_id'),
        ),
        isNull,
      );
      expect(
        choreOccurrenceTargetRecordFromPayload(
          _occurrenceTargetRow()..['can_manage_series'] = 'yes',
        ),
        isNull,
      );
      expect(
        choreOccurrenceTargetRecordFromPayload(
          _occurrenceTargetRow()..['can_set_completion'] = 'yes',
        ),
        isNull,
      );
      expect(
        choreOccurrenceTargetRecordFromPayload(
          _occurrenceTargetRow()..remove('can_set_completion'),
        ),
        isNull,
      );
    });

    test('accepts strict empty and populated chore list pages', () {
      final ChoreListPageDataRecord? empty = choreListPageFromPayload(
        <Map<String, Object?>>[_choreListRow()],
        expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
        expectedView: 'upcoming',
        expectedAssigneeMemberId: null,
        expectedLimit: 2,
      );
      final ChoreListPageDataRecord? page = choreListPageFromPayload(
        <Map<String, Object?>>[
          _choreListItem(
            occurrenceId: '55555555-5555-4555-8555-555555555551',
            dueLocalDate: '2026-08-07',
            dueLocalTime: '08:00:00',
            dueAt: '2026-08-06T23:00:00+00:00',
            hasMore: true,
            pageCursor: '7b7d',
          ),
          _choreListItem(
            occurrenceId: '55555555-5555-4555-8555-555555555552',
            dueLocalDate: '2026-08-08',
            dueLocalTime: null,
            dueAt: null,
            hasMore: true,
            pageCursor: '7b7d',
          ),
        ],
        expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
        expectedView: 'upcoming',
        expectedAssigneeMemberId: null,
        expectedLimit: 2,
      );

      expect(empty?.occurrences, isEmpty);
      expect(empty?.generatedAt, '2026-08-06T10:30:00+00:00');
      expect(page?.occurrences, hasLength(2));
      expect(page?.hasMore, isTrue);
      expect(page?.pageCursor, '7b7d');
      expect(page?.occurrences.last.dueLocalDate, '2026-08-08');
    });

    test('rejects inconsistent chore list metadata and page shapes', () {
      for (final Object? payload in <Object?>[
        const <Object?>[],
        <Map<String, Object?>>[_choreListRow()..['unexpected'] = true],
        <Map<String, Object?>>[
          _choreListRow()
            ..['household_id'] = '99999999-9999-4999-8999-999999999999',
        ],
        <Map<String, Object?>>[
          _choreListRow()
            ..['has_more'] = true
            ..['page_cursor'] = '7b7d',
        ],
        <Map<String, Object?>>[
          _choreListItem(hasMore: false, pageCursor: '7b7d'),
        ],
        <Map<String, Object?>>[
          _choreListItem(hasMore: true, pageCursor: '7b7d'),
          _choreListItem(
            occurrenceId: '55555555-5555-4555-8555-555555555552',
            hasMore: true,
            pageCursor: '7b7e',
          ),
        ],
        _choreListRow(),
      ]) {
        expect(
          choreListPageFromPayload(
            payload,
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedView: 'upcoming',
            expectedAssigneeMemberId: null,
            expectedLimit: 2,
          ),
          isNull,
        );
      }
    });

    test('accepts a strict recurring creation result shape', () {
      final RecurringChoreDataRecord? record = recurringChoreRecordFromPayload(
        _recurringRow(),
      );

      expect(record?.householdId, '22222222-2222-4222-8222-222222222222');
      expect(record?.materializedThrough, '2027-08-06');
      expect(record?.materializedCount, 366);
      expect(record?.recurrenceRule, <String, Object?>{
        'frequency': 'daily',
        'interval': 1,
        'end': <String, Object?>{'type': 'never'},
      });
    });

    test('rejects malformed recurring creation result shapes', () {
      for (final Object? payload in <Object?>[
        _recurringRow()..['unexpected'] = true,
        _recurringRow()..remove('first_occurrence_id'),
        _recurringRow()..['recurrence_rule'] = 'daily',
        _recurringRow()..['materialized_count'] = 366.0,
        _recurringRow()..['created'] = 'yes',
        <Object?>[_recurringRow()],
      ]) {
        expect(recurringChoreRecordFromPayload(payload), isNull);
      }
    });

    test('rejects unknown, missing, mistyped, and inconsistent rows', () {
      expect(todayChoresRecordFromPayload(const <Object>[]), isNull);
      expect(
        todayChoresRecordFromPayload(<Map<String, Object?>>[
          _todayRow()..['unexpected'] = true,
        ]),
        isNull,
      );
      expect(
        todayChoresRecordFromPayload(<Map<String, Object?>>[
          _todayRow()..['description'] = 'orphan notes',
        ]),
        isNull,
      );
      expect(
        todayChoresRecordFromPayload(<Map<String, Object?>>[
          _todayRow(),
          _todayItem(),
        ]),
        isNull,
      );
      expect(
        choreOccurrenceRecordFromPayload(<String, Object?>{
          'household_id': '22222222-2222-4222-8222-222222222222',
        }),
        isNull,
      );
    });

    test('accepts strict completion and reopen result shapes', () {
      final ChoreCompletionDataRecord? completed =
          choreCompletionRecordFromPayload(_completionRow());
      final ChoreCompletionDataRecord? reopened =
          choreCompletionRecordFromPayload(
            _completionRow()
              ..['status'] = 'scheduled'
              ..['version'] = 3
              ..['completed_by_member_id'] = null
              ..['completed_at'] = null,
          );

      expect(completed?.status, 'completed');
      expect(completed?.version, 2);
      expect(completed?.changed, isTrue);
      expect(reopened?.status, 'scheduled');
      expect(reopened?.completedByMemberId, isNull);
      expect(reopened?.completedAt, isNull);
    });

    test('rejects malformed completion result shapes', () {
      for (final Object? payload in <Object?>[
        _completionRow()..['unexpected'] = true,
        _completionRow()..remove('occurrence_id'),
        _completionRow()..['version'] = 2.0,
        _completionRow()..['changed'] = 'yes',
        _completionRow()..['completed_at'] = 123,
        <Object?>[_completionRow()],
      ]) {
        expect(choreCompletionRecordFromPayload(payload), isNull);
      }
    });

    test('accepts a strict occurrence skip result shape', () {
      final ChoreOccurrenceSkipDataRecord? skipped =
          choreOccurrenceSkipRecordFromPayload(_skipRow());

      expect(skipped?.householdId, '22222222-2222-4222-8222-222222222222');
      expect(skipped?.occurrenceId, '55555555-5555-4555-8555-555555555555');
      expect(skipped?.status, 'skipped');
      expect(skipped?.version, 2);
      expect(skipped?.changed, isTrue);
    });

    test('rejects malformed occurrence skip result shapes', () {
      for (final Object? payload in <Object?>[
        _skipRow()..['unexpected'] = true,
        _skipRow()..remove('occurrence_id'),
        _skipRow()..['version'] = 2.0,
        _skipRow()..['changed'] = 'yes',
        <Object?>[_skipRow()],
      ]) {
        expect(choreOccurrenceSkipRecordFromPayload(payload), isNull);
      }
    });

    test('accepts a strict skipped-occurrence restore result shape', () {
      final ChoreOccurrenceRestoreDataRecord? restored =
          choreOccurrenceRestoreRecordFromPayload(_restoreRow());

      expect(restored?.householdId, '22222222-2222-4222-8222-222222222222');
      expect(restored?.occurrenceId, '55555555-5555-4555-8555-555555555555');
      expect(restored?.status, 'scheduled');
      expect(restored?.version, 3);
      expect(restored?.changed, isTrue);
    });

    test('rejects malformed occurrence restore result shapes', () {
      for (final Object? payload in <Object?>[
        _restoreRow()..['unexpected'] = true,
        _restoreRow()..remove('occurrence_id'),
        _restoreRow()..['version'] = 3.0,
        _restoreRow()..['changed'] = 'yes',
        <Object?>[_restoreRow()],
      ]) {
        expect(choreOccurrenceRestoreRecordFromPayload(payload), isNull);
      }
    });

    test('accepts strict timed and all-day reschedule result shapes', () {
      final ChoreOccurrenceRescheduleDataRecord? timed =
          choreOccurrenceRescheduleRecordFromPayload(_rescheduleRow());
      final ChoreOccurrenceRescheduleDataRecord? allDay =
          choreOccurrenceRescheduleRecordFromPayload(
            _rescheduleRow()
              ..['due_local_time'] = null
              ..['due_at'] = null
              ..['changed'] = false,
          );

      expect(timed?.householdId, '22222222-2222-4222-8222-222222222222');
      expect(timed?.occurrenceId, '55555555-5555-4555-8555-555555555555');
      expect(timed?.dueLocalDate, '2026-08-07');
      expect(timed?.dueLocalTime, '18:30:00');
      expect(timed?.dueAt, '2026-08-07T09:30:00+00:00');
      expect(timed?.status, 'scheduled');
      expect(timed?.version, 2);
      expect(timed?.changed, isTrue);
      expect(allDay?.dueLocalTime, isNull);
      expect(allDay?.dueAt, isNull);
      expect(allDay?.changed, isFalse);
    });

    test('rejects malformed occurrence reschedule result shapes', () {
      for (final Object? payload in <Object?>[
        _rescheduleRow()..['unexpected'] = true,
        _rescheduleRow()..remove('occurrence_id'),
        _rescheduleRow()..['version'] = 2.0,
        _rescheduleRow()..['changed'] = 'yes',
        _rescheduleRow()..['due_local_time'] = 1830,
        _rescheduleRow()..['due_at'] = 123,
        <Object?>[_rescheduleRow()],
      ]) {
        expect(choreOccurrenceRescheduleRecordFromPayload(payload), isNull);
      }
    });

    test('accepts a strict occurrence reassignment result shape', () {
      final ChoreOccurrenceReassignmentDataRecord? record =
          choreOccurrenceReassignmentRecordFromPayload(_reassignmentRow());

      expect(record?.householdId, '22222222-2222-4222-8222-222222222222');
      expect(record?.occurrenceId, '55555555-5555-4555-8555-555555555555');
      expect(record?.assigneeMemberId, '33333333-3333-4333-8333-333333333334');
      expect(record?.assigneeDisplayName, 'Sam');
      expect(record?.status, 'scheduled');
      expect(record?.version, 2);
      expect(record?.changed, isTrue);
    });

    test('rejects malformed occurrence reassignment result shapes', () {
      for (final Object? payload in <Object?>[
        _reassignmentRow()..['unexpected'] = true,
        _reassignmentRow()..remove('occurrence_id'),
        _reassignmentRow()..['assignee_member_id'] = 123,
        _reassignmentRow()..['assignee_display_name'] = null,
        _reassignmentRow()..['version'] = 2.0,
        _reassignmentRow()..['changed'] = 'yes',
        <Object?>[_reassignmentRow()],
      ]) {
        expect(choreOccurrenceReassignmentRecordFromPayload(payload), isNull);
      }
    });

    test('accepts strict one-time chore lifecycle result shapes', () {
      final OneTimeChoreUpdateDataRecord? updated =
          oneTimeChoreUpdateRecordFromPayload(_oneTimeUpdateRow());
      final OneTimeChoreUpdateDataRecord? allDay =
          oneTimeChoreUpdateRecordFromPayload(
            _oneTimeUpdateRow()
              ..['due_local_time'] = null
              ..['due_at'] = null
              ..['changed'] = false,
          );
      final OneTimeChoreDeletionDataRecord? deleted =
          oneTimeChoreDeletionRecordFromPayload(_oneTimeDeletionRow());

      expect(updated?.revisionNumber, 2);
      expect(updated?.dueLocalDate, '2026-08-07');
      expect(updated?.dueLocalTime, '18:30:00');
      expect(updated?.dueAt, '2026-08-07T09:30:00+00:00');
      expect(updated?.seriesVersion, 2);
      expect(updated?.occurrenceVersion, 2);
      expect(allDay?.dueLocalTime, isNull);
      expect(allDay?.dueAt, isNull);
      expect(allDay?.changed, isFalse);
      expect(deleted?.status, 'cancelled');
      expect(deleted?.seriesVersion, 2);
      expect(deleted?.occurrenceVersion, 2);
      expect(deleted?.changed, isTrue);
    });

    test('rejects malformed one-time chore lifecycle result shapes', () {
      for (final Object? payload in <Object?>[
        _oneTimeUpdateRow()..['unexpected'] = true,
        _oneTimeUpdateRow()..remove('revision_id'),
        _oneTimeUpdateRow()..['revision_number'] = 2.0,
        _oneTimeUpdateRow()..['due_local_time'] = 1830,
        _oneTimeUpdateRow()..['due_at'] = 123,
        _oneTimeUpdateRow()..['series_version'] = 2.0,
        _oneTimeUpdateRow()..['occurrence_version'] = '2',
        _oneTimeUpdateRow()..['changed'] = 'yes',
        <Object?>[_oneTimeUpdateRow()],
      ]) {
        expect(oneTimeChoreUpdateRecordFromPayload(payload), isNull);
      }
      for (final Object? payload in <Object?>[
        _oneTimeDeletionRow()..['unexpected'] = true,
        _oneTimeDeletionRow()..remove('occurrence_id'),
        _oneTimeDeletionRow()..['status'] = null,
        _oneTimeDeletionRow()..['series_version'] = 2.0,
        _oneTimeDeletionRow()..['occurrence_version'] = '2',
        _oneTimeDeletionRow()..['changed'] = 'yes',
        <Object?>[_oneTimeDeletionRow()],
      ]) {
        expect(oneTimeChoreDeletionRecordFromPayload(payload), isNull);
      }
    });

    test('accepts strict empty and populated deleted one-time pages', () {
      final DeletedOneTimeChorePageDataRecord? empty =
          deletedOneTimeChorePageFromPayload(
            <Map<String, Object?>>[_deletedOneTimeChoreRow()],
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedLimit: 2,
          );
      final DeletedOneTimeChorePageDataRecord? populated =
          deletedOneTimeChorePageFromPayload(
            <Map<String, Object?>>[
              _deletedOneTimeChoreItem(
                occurrenceId: '55555555-5555-4555-8555-555555555551',
                seriesId: '44444444-4444-4444-8444-444444444441',
                hasMore: true,
                pageCursor: '7b7d',
              ),
              _deletedOneTimeChoreItem(
                occurrenceId: '55555555-5555-4555-8555-555555555552',
                seriesId: '44444444-4444-4444-8444-444444444442',
                hasMore: true,
                pageCursor: '7b7d',
              ),
            ],
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedLimit: 2,
          );

      expect(empty?.items, isEmpty);
      expect(empty?.householdTimezone, 'Asia/Seoul');
      expect(populated?.items, hasLength(2));
      expect(populated?.hasMore, isTrue);
      expect(populated?.pageCursor, '7b7d');
      expect(populated?.items.first.deletedAt, '2026-08-09T10:30:00+00:00');
    });

    test('rejects inconsistent deleted page metadata and partial rows', () {
      for (final Object? payload in <Object?>[
        const <Object?>[],
        <Map<String, Object?>>[
          _deletedOneTimeChoreRow()..['unexpected'] = true,
        ],
        <Map<String, Object?>>[
          _deletedOneTimeChoreRow()..['title'] = 'Partial item',
        ],
        <Map<String, Object?>>[
          _deletedOneTimeChoreRow()
            ..['has_more'] = true
            ..['page_cursor'] = '7b7d',
        ],
        <Map<String, Object?>>[
          _deletedOneTimeChoreItem(hasMore: true, pageCursor: '7b7d'),
          _deletedOneTimeChoreItem(
            occurrenceId: '55555555-5555-4555-8555-555555555552',
            hasMore: true,
            pageCursor: '7b7e',
          ),
        ],
        <Map<String, Object?>>[
          _deletedOneTimeChoreItem()..['series_version'] = 2.0,
        ],
      ]) {
        expect(
          deletedOneTimeChorePageFromPayload(
            payload,
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedLimit: 2,
          ),
          isNull,
        );
      }
    });

    test('accepts and rejects exact one-time restore result shapes', () {
      final OneTimeChoreRestoreDataRecord? restored =
          oneTimeChoreRestoreRecordFromPayload(_oneTimeRestoreRow());

      expect(restored?.status, 'scheduled');
      expect(restored?.seriesVersion, 3);
      expect(restored?.occurrenceVersion, 3);
      expect(restored?.changed, isTrue);
      for (final Object? payload in <Object?>[
        _oneTimeRestoreRow()..['unexpected'] = true,
        _oneTimeRestoreRow()..remove('series_id'),
        _oneTimeRestoreRow()..['series_version'] = 3.0,
        _oneTimeRestoreRow()..['changed'] = 'yes',
        <Object?>[_oneTimeRestoreRow()],
      ]) {
        expect(oneTimeChoreRestoreRecordFromPayload(payload), isNull);
      }
    });

    test('accepts strict repeating-series change result shapes', () {
      final RepeatingChoreSeriesUpdateDataRecord? updated =
          repeatingChoreSeriesUpdateRecordFromPayload(_seriesUpdateRow());
      final RepeatingChoreSeriesCancellationDataRecord? cancelled =
          repeatingChoreSeriesCancellationRecordFromPayload(
            _seriesCancellationRow(),
          );
      final RepeatingChoreSeriesFromOccurrenceCancellationDataRecord?
      cancelledFromOccurrence =
          repeatingChoreSeriesFromOccurrenceCancellationRecordFromPayload(
            _seriesFromOccurrenceCancellationRow(),
          );
      final RepeatingChoreSeriesFromOccurrenceCancellationDataRecord?
      cancelledWithoutPrefix =
          repeatingChoreSeriesFromOccurrenceCancellationRecordFromPayload(
            _seriesFromOccurrenceCancellationRow(
              terminalRevisionId: null,
              terminalRevisionNumber: null,
            ),
          );
      final RepeatingChoreSeriesCancellationResumeDataRecord? resumed =
          repeatingChoreSeriesCancellationResumeRecordFromPayload(
            _seriesCancellationResumeRow(),
          );

      expect(updated?.revisionNumber, 2);
      expect(updated?.effectiveLocalDate, '2026-08-06');
      expect(updated?.rebuiltCount, 31);
      expect(updated?.cancelledCount, 335);
      expect(updated?.preservedCompletedCount, 1);
      expect(cancelled?.version, 2);
      expect(cancelled?.cancelledCount, 365);
      expect(cancelled?.changed, isTrue);
      expect(cancelledFromOccurrence?.effectiveLocalDate, '2026-08-12');
      expect(cancelledFromOccurrence?.terminalRevisionNumber, 2);
      expect(cancelledWithoutPrefix?.terminalRevisionId, isNull);
      expect(cancelledWithoutPrefix?.terminalRevisionNumber, isNull);
      expect(resumed?.effectiveLocalDate, '2026-08-12');
      expect(resumed?.version, 3);
      expect(resumed?.restoredCount, 19);
      expect(resumed?.revisionNumber, 3);
    });

    test('rejects malformed repeating-series change result shapes', () {
      for (final Object? payload in <Object?>[
        _seriesUpdateRow()..['unexpected'] = true,
        _seriesUpdateRow()..remove('revision_id'),
        _seriesUpdateRow()..['revision_number'] = 2.0,
        _seriesUpdateRow()..['changed'] = 'yes',
        <Object?>[_seriesUpdateRow()],
      ]) {
        expect(repeatingChoreSeriesUpdateRecordFromPayload(payload), isNull);
      }
      for (final Object? payload in <Object?>[
        _seriesCancellationRow()..['unexpected'] = true,
        _seriesCancellationRow()..remove('series_id'),
        _seriesCancellationRow()..['cancelled_count'] = 365.0,
        _seriesCancellationRow()..['changed'] = 'yes',
        <Object?>[_seriesCancellationRow()],
      ]) {
        expect(
          repeatingChoreSeriesCancellationRecordFromPayload(payload),
          isNull,
        );
      }
      for (final Object? payload in <Object?>[
        _seriesFromOccurrenceCancellationRow()..['unexpected'] = true,
        _seriesFromOccurrenceCancellationRow()..remove('effective_local_date'),
        _seriesFromOccurrenceCancellationRow()
          ..['terminal_revision_number'] = 2.0,
        _seriesFromOccurrenceCancellationRow(terminalRevisionNumber: null),
        _seriesFromOccurrenceCancellationRow(terminalRevisionId: null),
        <Object?>[_seriesFromOccurrenceCancellationRow()],
      ]) {
        expect(
          repeatingChoreSeriesFromOccurrenceCancellationRecordFromPayload(
            payload,
          ),
          isNull,
        );
      }
      for (final Object? payload in <Object?>[
        _seriesCancellationResumeRow()..['unexpected'] = true,
        _seriesCancellationResumeRow()..remove('revision_id'),
        _seriesCancellationResumeRow()..['restored_count'] = 19.0,
        _seriesCancellationResumeRow()..['changed'] = 'yes',
        <Object?>[_seriesCancellationResumeRow()],
      ]) {
        expect(
          repeatingChoreSeriesCancellationResumeRecordFromPayload(payload),
          isNull,
        );
      }
    });

    test('accepts empty and strict occurrence history pages', () {
      final ChoreOccurrenceHistoryPageDataRecord? empty =
          choreOccurrenceHistoryPageFromPayload(
            const <Object?>[],
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedOccurrenceId: '55555555-5555-4555-8555-555555555555',
          );
      final ChoreOccurrenceHistoryPageDataRecord?
      page = choreOccurrenceHistoryPageFromPayload(
        <Map<String, Object?>>[
          _historyRow(),
          _historyRow(
            historyEntryId: 'reschedule:61000000-0000-4000-8000-000000000702',
            eventType: 'rescheduled',
            previousDueLocalDate: '2026-08-06',
            previousDueLocalTime: '09:00:00',
            newDueLocalDate: '2026-08-07',
            newDueLocalTime: '18:30:00',
          ),
          _historyRow(
            historyEntryId: 'assignment:61000000-0000-4000-8000-000000000703',
            eventType: 'reassigned',
            previousAssigneeMemberId: '33333333-3333-4333-8333-333333333333',
            previousAssigneeDisplayName: 'Alex',
            newAssigneeMemberId: '33333333-3333-4333-8333-333333333334',
            newAssigneeDisplayName: 'Sam',
          ),
        ],
        expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
        expectedOccurrenceId: '55555555-5555-4555-8555-555555555555',
      );

      expect(empty?.events, isEmpty);
      expect(empty?.hasMore, isFalse);
      expect(page?.events, hasLength(3));
      expect(page?.events[1].newDueLocalTime, '18:30:00');
      expect(page?.events[2].newAssigneeDisplayName, 'Sam');
    });

    test('rejects malformed occurrence history payload variants', () {
      for (final Object? payload in <Object?>[
        <Map<String, Object?>>[_historyRow()..['unexpected'] = true],
        <Map<String, Object?>>[
          _historyRow(householdId: '99999999-9999-4999-8999-999999999999'),
        ],
        <Map<String, Object?>>[_historyRow(eventType: 'deleted')],
        <Map<String, Object?>>[
          _historyRow(
            historyEntryId: 'assignment:61000000-0000-4000-8000-000000000701',
          ),
        ],
        <Map<String, Object?>>[
          _historyRow(actingMemberId: '33333333-3333-4333-8333-333333333334'),
        ],
        <Map<String, Object?>>[
          _historyRow(
            historyEntryId: 'reschedule:61000000-0000-4000-8000-000000000702',
            eventType: 'rescheduled',
          ),
        ],
        <Map<String, Object?>>[
          _historyRow(
            historyEntryId: 'assignment:61000000-0000-4000-8000-000000000703',
            eventType: 'reassigned',
          ),
        ],
        <Map<String, Object?>>[
          _historyRow(hasMore: true),
          _historyRow(
            historyEntryId: 'completion:61000000-0000-4000-8000-000000000702',
            hasMore: false,
          ),
        ],
        _historyRow(),
      ]) {
        expect(
          choreOccurrenceHistoryPageFromPayload(
            payload,
            expectedHouseholdId: '22222222-2222-4222-8222-222222222222',
            expectedOccurrenceId: '55555555-5555-4555-8555-555555555555',
          ),
          isNull,
        );
      }
    });

    test('maps provider codes to stable failure kinds', () {
      expect(
        choreDataFailureFromProviderCode('KFC01'),
        ChoreDataFailureKind.unauthenticated,
      );
      expect(
        choreDataFailureFromProviderCode('KFC02'),
        ChoreDataFailureKind.invalidInput,
      );
      expect(
        choreDataFailureFromProviderCode('KFC03'),
        ChoreDataFailureKind.notFoundOrForbidden,
      );
      expect(
        choreDataFailureFromProviderCode('KFC04'),
        ChoreDataFailureKind.idempotencyConflict,
      );
      expect(
        choreDataFailureFromProviderCode('KFC07'),
        ChoreDataFailureKind.invalidRecurrence,
      );
      expect(
        choreDataFailureFromProviderCode('KFC05'),
        ChoreDataFailureKind.staleVersion,
      );
      expect(
        choreDataFailureFromProviderCode('KFC06'),
        ChoreDataFailureKind.invalidTransition,
      );
      expect(
        choreDataFailureFromProviderCode('KFB10'),
        ChoreDataFailureKind.featurePolicyUnavailable,
      );
      expect(
        choreDataFailureFromProviderCode('KFB11'),
        ChoreDataFailureKind.featurePolicyUnavailable,
      );
      expect(
        choreDataFailureFromProviderCode('KFB12'),
        ChoreDataFailureKind.featureLimitReached,
      );
      expect(
        choreDataFailureFromProviderCode('PGRST116'),
        ChoreDataFailureKind.temporarilyUnavailable,
      );
      expect(
        choreDataFailureFromProviderCode(null),
        ChoreDataFailureKind.unknown,
      );
    });
  });
}

Map<String, Object?> _todayItem() {
  return _todayRow()..addAll(<String, Object?>{
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'title': 'Take out recycling',
    'description': null,
    'assignee_member_id': '33333333-3333-4333-8333-333333333333',
    'assignee_display_name': 'Alex',
    'due_local_time': '19:30:00',
    'due_at': '2026-08-06T10:30:00+00:00',
    'status': 'scheduled',
    'version': 1,
    'recurrence_frequency': 'daily',
    'series_version': 1,
    'series_default_assignee_member_id': '33333333-3333-4333-8333-333333333333',
    'series_due_local_time': '19:30:00',
    'recurrence_rule': <String, Object?>{
      'frequency': 'daily',
      'interval': 1,
      'end': <String, Object?>{'type': 'never'},
    },
    'can_manage_series': true,
  });
}

Map<String, Object?> _occurrenceTargetRow() {
  final Map<String, Object?> row = _choreListItem();
  for (final String key in <String>{
    'household_timezone',
    'household_local_date',
    'generated_at',
    'list_view',
    'assignee_filter_member_id',
    'page_limit',
    'has_more',
    'page_cursor',
  }) {
    row.remove(key);
  }
  row['can_set_completion'] = true;
  return row;
}

Map<String, Object?> _choreListItem({
  String occurrenceId = '55555555-5555-4555-8555-555555555551',
  String dueLocalDate = '2026-08-07',
  String? dueLocalTime = '08:00:00',
  String? dueAt = '2026-08-06T23:00:00+00:00',
  bool hasMore = false,
  String? pageCursor,
}) {
  return _choreListRow(
    hasMore: hasMore,
    pageCursor: pageCursor,
  )..addAll(<String, Object?>{
    'occurrence_id': occurrenceId,
    'series_id': '44444444-4444-4444-8444-444444444444',
    'title': 'Take out recycling',
    'description': null,
    'assignee_member_id': '33333333-3333-4333-8333-333333333333',
    'assignee_display_name': 'Alex',
    'due_local_date': dueLocalDate,
    'due_local_time': dueLocalTime,
    'due_at': dueAt,
    'status': 'scheduled',
    'version': 1,
    'recurrence_frequency': 'daily',
    'series_version': 1,
    'series_default_assignee_member_id': '33333333-3333-4333-8333-333333333333',
    'series_due_local_time': '08:00:00',
    'recurrence_rule': <String, Object?>{
      'frequency': 'daily',
      'interval': 1,
      'end': <String, Object?>{'type': 'never'},
    },
    'can_manage_series': true,
  });
}

Map<String, Object?> _choreListRow({bool hasMore = false, String? pageCursor}) {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'household_timezone': 'Asia/Seoul',
    'household_local_date': '2026-08-06',
    'generated_at': '2026-08-06T10:30:00+00:00',
    'list_view': 'upcoming',
    'assignee_filter_member_id': null,
    'page_limit': 2,
    'has_more': hasMore,
    'page_cursor': pageCursor,
    'occurrence_id': null,
    'series_id': null,
    'title': null,
    'description': null,
    'assignee_member_id': null,
    'assignee_display_name': null,
    'due_local_date': null,
    'due_local_time': null,
    'due_at': null,
    'status': null,
    'version': null,
    'recurrence_frequency': null,
    'series_version': null,
    'series_default_assignee_member_id': null,
    'series_due_local_time': null,
    'recurrence_rule': null,
    'can_manage_series': null,
  };
}

Map<String, Object?> _historyRow({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String historyEntryId = 'completion:61000000-0000-4000-8000-000000000701',
  String eventType = 'completed',
  String? actingMemberId,
  String? actingDisplayName,
  String? previousDueLocalDate,
  String? previousDueLocalTime,
  String? newDueLocalDate,
  String? newDueLocalTime,
  String? previousAssigneeMemberId,
  String? previousAssigneeDisplayName,
  String? newAssigneeMemberId,
  String? newAssigneeDisplayName,
  bool hasMore = false,
}) {
  return <String, Object?>{
    'household_id': householdId,
    'occurrence_id': occurrenceId,
    'history_entry_id': historyEntryId,
    'event_type': eventType,
    'actor_member_id': '33333333-3333-4333-8333-333333333333',
    'actor_display_name': 'Alex',
    'acting_member_id': actingMemberId,
    'acting_display_name': actingDisplayName,
    'occurred_at': '2026-08-07T01:00:00+00:00',
    'occurrence_version': 2,
    'previous_due_local_date': previousDueLocalDate,
    'previous_due_local_time': previousDueLocalTime,
    'new_due_local_date': newDueLocalDate,
    'new_due_local_time': newDueLocalTime,
    'previous_assignee_member_id': previousAssigneeMemberId,
    'previous_assignee_display_name': previousAssigneeDisplayName,
    'new_assignee_member_id': newAssigneeMemberId,
    'new_assignee_display_name': newAssigneeDisplayName,
    'has_more': hasMore,
  };
}

Map<String, Object?> _recurringRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'first_occurrence_id': '55555555-5555-4555-8555-555555555555',
    'recurrence_rule': <String, Object?>{
      'frequency': 'daily',
      'interval': 1,
      'end': <String, Object?>{'type': 'never'},
    },
    'materialized_through': '2027-08-06',
    'materialized_count': 366,
    'created': true,
  };
}

Map<String, Object?> _completionRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'status': 'completed',
    'version': 2,
    'completed_by_member_id': '33333333-3333-4333-8333-333333333333',
    'completed_at': '2026-08-06T10:30:00+00:00',
    'changed': true,
  };
}

Map<String, Object?> _skipRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'status': 'skipped',
    'version': 2,
    'changed': true,
  };
}

Map<String, Object?> _restoreRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'status': 'scheduled',
    'version': 3,
    'changed': true,
  };
}

Map<String, Object?> _rescheduleRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'due_local_date': '2026-08-07',
    'due_local_time': '18:30:00',
    'due_at': '2026-08-07T09:30:00+00:00',
    'status': 'scheduled',
    'version': 2,
    'changed': true,
  };
}

Map<String, Object?> _reassignmentRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'assignee_member_id': '33333333-3333-4333-8333-333333333334',
    'assignee_display_name': 'Sam',
    'status': 'scheduled',
    'version': 2,
    'changed': true,
  };
}

Map<String, Object?> _oneTimeUpdateRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'revision_id': '77777777-7777-4777-8777-777777777778',
    'revision_number': 2,
    'due_local_date': '2026-08-07',
    'due_local_time': '18:30:00',
    'due_at': '2026-08-07T09:30:00+00:00',
    'assignee_member_id': '33333333-3333-4333-8333-333333333334',
    'series_version': 2,
    'occurrence_version': 2,
    'changed': true,
  };
}

Map<String, Object?> _oneTimeDeletionRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'status': 'cancelled',
    'series_version': 2,
    'occurrence_version': 2,
    'changed': true,
  };
}

Map<String, Object?> _oneTimeRestoreRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'occurrence_id': '55555555-5555-4555-8555-555555555555',
    'status': 'scheduled',
    'series_version': 3,
    'occurrence_version': 3,
    'changed': true,
  };
}

Map<String, Object?> _deletedOneTimeChoreRow({
  bool hasMore = false,
  String? pageCursor,
}) {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'household_timezone': 'Asia/Seoul',
    'generated_at': '2026-08-09T11:00:00+00:00',
    'page_limit': 2,
    'has_more': hasMore,
    'page_cursor': pageCursor,
    'occurrence_id': null,
    'series_id': null,
    'title': null,
    'description': null,
    'assignee_member_id': null,
    'assignee_display_name': null,
    'due_local_date': null,
    'due_local_time': null,
    'due_at': null,
    'deleted_at': null,
    'series_version': null,
    'occurrence_version': null,
  };
}

Map<String, Object?> _deletedOneTimeChoreItem({
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  bool hasMore = false,
  String? pageCursor,
}) {
  return _deletedOneTimeChoreRow(hasMore: hasMore, pageCursor: pageCursor)
    ..addAll(<String, Object?>{
      'occurrence_id': occurrenceId,
      'series_id': seriesId,
      'title': 'Take out recycling',
      'description': 'Blue bin',
      'assignee_member_id': '33333333-3333-4333-8333-333333333333',
      'assignee_display_name': 'Alex',
      'due_local_date': '2026-08-09',
      'due_local_time': '19:30:00',
      'due_at': '2026-08-09T10:30:00+00:00',
      'deleted_at': '2026-08-09T10:30:00+00:00',
      'series_version': 2,
      'occurrence_version': 2,
    });
}

Map<String, Object?> _todayRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'household_timezone': 'Asia/Seoul',
    'household_local_date': '2026-08-06',
    'occurrence_id': null,
    'series_id': null,
    'title': null,
    'description': null,
    'assignee_member_id': null,
    'assignee_display_name': null,
    'due_local_time': null,
    'due_at': null,
    'status': null,
    'version': null,
    'recurrence_frequency': null,
    'series_version': null,
    'series_default_assignee_member_id': null,
    'series_due_local_time': null,
    'recurrence_rule': null,
    'can_manage_series': null,
  };
}

Map<String, Object?> _seriesUpdateRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'revision_id': '77777777-7777-4777-8777-777777777777',
    'revision_number': 2,
    'effective_local_date': '2026-08-06',
    'version': 2,
    'rebuilt_count': 31,
    'cancelled_count': 335,
    'preserved_completed_count': 1,
    'changed': true,
  };
}

Map<String, Object?> _seriesCancellationRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'effective_local_date': '2026-08-06',
    'version': 2,
    'cancelled_count': 365,
    'preserved_completed_count': 1,
    'changed': true,
  };
}

Map<String, Object?> _seriesFromOccurrenceCancellationRow({
  String? terminalRevisionId = '77777777-7777-4777-8777-777777777778',
  int? terminalRevisionNumber = 2,
}) {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'effective_local_date': '2026-08-12',
    'version': 2,
    'cancelled_count': 19,
    'preserved_completed_count': 2,
    'terminal_revision_id': terminalRevisionId,
    'terminal_revision_number': terminalRevisionNumber,
    'changed': true,
  };
}

Map<String, Object?> _seriesCancellationResumeRow() {
  return <String, Object?>{
    'household_id': '22222222-2222-4222-8222-222222222222',
    'series_id': '44444444-4444-4444-8444-444444444444',
    'effective_local_date': '2026-08-12',
    'version': 3,
    'restored_count': 19,
    'preserved_completed_count': 2,
    'revision_id': '77777777-7777-4777-8777-777777777779',
    'revision_number': 3,
    'changed': true,
  };
}
