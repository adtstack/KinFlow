import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

void main() {
  group('ProviderChoreRepository', () {
    test('maps the exact capped household activation aggregate', () async {
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          activationProgressResult:
              ChoreDataSucceeded<HouseholdActivationProgressDataRecord>(
                HouseholdActivationProgressDataRecord(
                  householdId: _householdId.value,
                  adultParticipantProgress: 2,
                  choreCreationProgress: 3,
                  distinctAdultCompleterProgress: 1,
                  returnAfterFirstDayReached: true,
                ),
              ),
        ),
      );

      final LoadHouseholdActivationProgressResult result = await repository
          .loadHouseholdActivationProgress(_householdId);

      expect(result, isA<HouseholdActivationProgressLoaded>());
      final progress = (result as HouseholdActivationProgressLoaded).progress;
      expect(progress.householdId, _householdId);
      expect(progress.adultParticipantReached, isTrue);
      expect(progress.choreCreationReached, isTrue);
      expect(progress.distinctAdultCompleterReached, isFalse);
      expect(progress.completedMilestoneCount, 3);
    });

    test(
      'fails closed on mismatched or out-of-range activation rows',
      () async {
        for (final HouseholdActivationProgressDataRecord record
            in <HouseholdActivationProgressDataRecord>[
              const HouseholdActivationProgressDataRecord(
                householdId: '99999999-9999-4999-8999-999999999999',
                adultParticipantProgress: 1,
                choreCreationProgress: 0,
                distinctAdultCompleterProgress: 0,
                returnAfterFirstDayReached: false,
              ),
              HouseholdActivationProgressDataRecord(
                householdId: _householdId.value,
                adultParticipantProgress: 1,
                choreCreationProgress: 4,
                distinctAdultCompleterProgress: 0,
                returnAfterFirstDayReached: false,
              ),
            ]) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              ),
              activationProgressResult:
                  ChoreDataSucceeded<HouseholdActivationProgressDataRecord>(
                    record,
                  ),
            ),
          );

          final LoadHouseholdActivationProgressResult result = await repository
              .loadHouseholdActivationProgress(_householdId);
          expect(
            (result as LoadHouseholdActivationProgressFailed).failure.kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('maps the exact household weekly report aggregate', () async {
      final HouseholdWeeklyReportRequest request =
          HouseholdWeeklyReportRequest.tryCreate(
            householdId: _householdId,
            weekOffset: 0,
          )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          weeklyReportResult:
              ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>(
                _weeklyReportRecord(),
              ),
        ),
      );

      final LoadHouseholdWeeklyReportResult result = await repository
          .loadHouseholdWeeklyReport(request);

      expect(result, isA<HouseholdWeeklyReportLoaded>());
      final HouseholdWeeklyReport report =
          (result as HouseholdWeeklyReportLoaded).report;
      expect(report.householdId, _householdId);
      expect(report.weekStart.value, '2026-08-03');
      expect(report.weekEnd.value, '2026-08-09');
      expect(report.completedCount, 3);
      expect(report.completedByWeekEndPercent, 50);
      expect(report.members.map((member) => member.displayName), <String>[
        'Alex',
        'Sam',
      ]);
      expect(report.members.first.isViewer, isTrue);
    });

    test('fails closed when weekly contributor ordering is invalid', () async {
      final HouseholdWeeklyReportRequest request =
          HouseholdWeeklyReportRequest.tryCreate(
            householdId: _householdId,
            weekOffset: 0,
          )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          weeklyReportResult:
              ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>(
                _weeklyReportRecord(
                  members: const <HouseholdWeeklyReportMemberDataRecord>[
                    HouseholdWeeklyReportMemberDataRecord(
                      memberId: '33333333-3333-4333-8333-333333333334',
                      displayName: 'Sam',
                      completedCount: 1,
                      completedByWeekEndCount: 1,
                      isViewer: false,
                    ),
                    HouseholdWeeklyReportMemberDataRecord(
                      memberId: '33333333-3333-4333-8333-333333333333',
                      displayName: 'Alex',
                      completedCount: 2,
                      completedByWeekEndCount: 1,
                      isViewer: true,
                    ),
                  ],
                ),
              ),
        ),
      );

      final LoadHouseholdWeeklyReportResult result = await repository
          .loadHouseholdWeeklyReport(request);

      expect(
        (result as LoadHouseholdWeeklyReportFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test('maps server-local Today metadata and occurrences', () async {
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: ChoreDataSucceeded<TodayChoresDataRecord>(
            TodayChoresDataRecord(
              householdId: _householdId.value,
              householdTimezone: 'Asia/Seoul',
              householdLocalDate: '2026-08-06',
              occurrences: <ChoreOccurrenceDataRecord>[
                _record(recurrenceFrequency: 'daily', canManageSeries: true),
              ],
            ),
          ),
        ),
      );

      final LoadTodayChoresResult result = await repository.loadToday(
        _householdId,
      );

      expect(result, isA<TodayChoresLoaded>());
      final loaded = result as TodayChoresLoaded;
      expect(loaded.today.localDate.value, '2026-08-06');
      expect(loaded.today.householdTimezone, 'Asia/Seoul');
      expect(loaded.today.occurrences.single.title, 'Take out recycling');
      expect(loaded.today.occurrences.single.dueAt?.isUtc, isTrue);
      expect(
        loaded.today.occurrences.single.recurrenceFrequency,
        ChoreRecurrenceFrequency.daily,
      );
      expect(loaded.today.occurrences.single.seriesVersion, 1);
      expect(
        loaded.today.occurrences.single.recurrenceRule?.frequency,
        ChoreRecurrenceFrequency.daily,
      );
      expect(loaded.today.occurrences.single.canManageSeries, isTrue);
    });

    test('maps a strict filtered chore page and opaque continuation', () async {
      final ChoreListRequest request = ChoreListRequest.tryCreate(
        householdId: _householdId,
        view: ChoreListView.upcoming,
        limit: 2,
      )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          listResult: ChoreDataSucceeded<ChoreListPageDataRecord>(
            _choreListRecord(
              occurrences: <ChoreOccurrenceDataRecord>[
                _record(
                  occurrenceId: '55555555-5555-4555-8555-555555555551',
                  dueLocalDate: '2026-08-07',
                  dueLocalTime: '08:00',
                  dueAt: '2026-08-06T23:00:00Z',
                ),
                _record(
                  occurrenceId: '55555555-5555-4555-8555-555555555552',
                  dueLocalDate: '2026-08-08',
                  dueLocalTime: null,
                  dueAt: null,
                ),
              ],
              hasMore: true,
              pageCursor: '7b7d',
            ),
          ),
        ),
      );

      final LoadTodayChoresResult result = await repository.loadChoreList(
        request,
      );

      expect(result, isA<TodayChoresLoaded>());
      final TodayChores page = (result as TodayChoresLoaded).today;
      expect(page.view, ChoreListView.upcoming);
      expect(page.generatedAt, DateTime.parse('2026-08-06T10:30:00Z'));
      expect(page.occurrences, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor?.value, '7b7d');
      expect(page.pageLimit, 2);
    });

    test('maps an exact authoritative occurrence target', () async {
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          occurrenceTargetResult: ChoreDataSucceeded<ChoreOccurrenceDataRecord>(
            _record(
              recurrenceFrequency: 'daily',
              canManageSeries: true,
              canSetCompletion: true,
            ),
          ),
        ),
      );

      final LoadChoreOccurrenceTargetResult result = await repository
          .loadOccurrenceTarget(
            householdId: _householdId,
            occurrenceId: _occurrenceId,
          );

      expect(result, isA<ChoreOccurrenceTargetLoaded>());
      final ChoreOccurrence occurrence =
          (result as ChoreOccurrenceTargetLoaded).occurrence;
      expect(occurrence.id, _occurrenceId);
      expect(occurrence.title, 'Take out recycling');
      expect(occurrence.recurrenceFrequency, ChoreRecurrenceFrequency.daily);
      expect(occurrence.canManageSeries, isTrue);
      expect(occurrence.canSetCompletion, isTrue);
    });

    test('rejects a mismatched authoritative occurrence target', () async {
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          occurrenceTargetResult: ChoreDataSucceeded<ChoreOccurrenceDataRecord>(
            _record(occurrenceId: '55555555-5555-4555-8555-555555555552'),
          ),
        ),
      );

      final LoadChoreOccurrenceTargetResult result = await repository
          .loadOccurrenceTarget(
            householdId: _householdId,
            occurrenceId: _occurrenceId,
          );

      expect(
        (result as LoadChoreOccurrenceTargetFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test(
      'fails closed on inconsistent chore list query and ordering',
      () async {
        final ChoreListRequest request = ChoreListRequest.tryCreate(
          householdId: _householdId,
          view: ChoreListView.upcoming,
          limit: 2,
        )!;
        final List<ChoreListPageDataRecord> invalid = <ChoreListPageDataRecord>[
          _choreListRecord(listView: 'overdue'),
          _choreListRecord(generatedAt: '2026-08-06T10:30:00'),
          _choreListRecord(pageCursor: 'not-hex'),
          _choreListRecord(
            occurrences: <ChoreOccurrenceDataRecord>[
              _record(dueLocalDate: '2026-08-08'),
              _record(
                occurrenceId: '55555555-5555-4555-8555-555555555552',
                dueLocalDate: '2026-08-07',
              ),
            ],
          ),
          _choreListRecord(
            occurrences: <ChoreOccurrenceDataRecord>[
              _record(dueLocalDate: '2026-08-06'),
            ],
          ),
        ];

        for (final ChoreListPageDataRecord record in invalid) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              ),
              listResult: ChoreDataSucceeded<ChoreListPageDataRecord>(record),
            ),
          );
          final LoadTodayChoresResult result = await repository.loadChoreList(
            request,
          );
          expect(
            (result as LoadTodayChoresFailed).failure.kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('maps a strict occurrence history page and continuation', () async {
      final ChoreOccurrenceHistoryRequest request = _historyRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          historyResult:
              ChoreDataSucceeded<ChoreOccurrenceHistoryPageDataRecord>(
                ChoreOccurrenceHistoryPageDataRecord(
                  events: <ChoreOccurrenceHistoryDataRecord>[
                    _historyRecord(
                      historyEntryId:
                          'reschedule:61000000-0000-4000-8000-000000000702',
                      eventType: 'rescheduled',
                      occurredAt: '2026-08-07T02:00:00Z',
                      previousDueLocalDate: '2026-08-06',
                      previousDueLocalTime: '09:00:00',
                      newDueLocalDate: '2026-08-07',
                      newDueLocalTime: '18:30:00',
                    ),
                    _historyRecord(
                      historyEntryId:
                          'completion:61000000-0000-4000-8000-000000000701',
                      eventType: 'completed',
                      occurredAt: '2026-08-07T01:00:00Z',
                    ),
                  ],
                  hasMore: true,
                ),
              ),
        ),
      );

      final LoadChoreOccurrenceHistoryResult result = await repository
          .loadOccurrenceHistory(request);

      expect(result, isA<ChoreOccurrenceHistoryLoaded>());
      final ChoreOccurrenceHistoryPage page =
          (result as ChoreOccurrenceHistoryLoaded).page;
      expect(page.events, hasLength(2));
      expect(
        page.events.first.type,
        ChoreOccurrenceHistoryEventType.rescheduled,
      );
      expect(page.events.first.newDueLocalTime?.value, '18:30');
      expect(page.events.last.occurredAt.isUtc, isTrue);
      expect(page.hasMore, isTrue);
      expect(
        page.nextCursor?.entryId.value,
        'completion:61000000-0000-4000-8000-000000000701',
      );
    });

    test(
      'fails closed on malformed or inconsistent occurrence history',
      () async {
        final ChoreOccurrenceHistoryRequest request = _historyRequest();
        for (final List<ChoreOccurrenceHistoryDataRecord> events
            in <List<ChoreOccurrenceHistoryDataRecord>>[
              <ChoreOccurrenceHistoryDataRecord>[
                _historyRecord(
                  householdId: '99999999-9999-4999-8999-999999999999',
                ),
              ],
              <ChoreOccurrenceHistoryDataRecord>[
                _historyRecord(historyEntryId: 'completion:not-a-uuid'),
              ],
              <ChoreOccurrenceHistoryDataRecord>[
                _historyRecord(occurredAt: '2026-08-07T01:00:00'),
              ],
              <ChoreOccurrenceHistoryDataRecord>[
                _historyRecord(
                  historyEntryId:
                      'reschedule:61000000-0000-4000-8000-000000000701',
                  eventType: 'rescheduled',
                ),
              ],
              <ChoreOccurrenceHistoryDataRecord>[
                _historyRecord(
                  historyEntryId:
                      'completion:61000000-0000-4000-8000-000000000701',
                  occurredAt: '2026-08-07T01:00:00Z',
                ),
                _historyRecord(
                  historyEntryId:
                      'completion:61000000-0000-4000-8000-000000000702',
                  occurredAt: '2026-08-07T02:00:00Z',
                ),
              ],
            ]) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              ),
              historyResult:
                  ChoreDataSucceeded<ChoreOccurrenceHistoryPageDataRecord>(
                    ChoreOccurrenceHistoryPageDataRecord(
                      events: events,
                      hasMore: false,
                    ),
                  ),
            ),
          );

          final LoadChoreOccurrenceHistoryResult result = await repository
              .loadOccurrenceHistory(request);

          expect(
            (result as LoadChoreOccurrenceHistoryFailed).failure.kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('rejects history at or after the requested keyset cursor', () async {
      final ChoreHistoryEntryId entryId = ChoreHistoryEntryId.tryParse(
        'completion:61000000-0000-4000-8000-000000000701',
      )!;
      final ChoreOccurrenceHistoryRequest request =
          ChoreOccurrenceHistoryRequest.tryCreate(
            householdId: _householdId,
            occurrenceId: _occurrenceId,
            cursor: ChoreOccurrenceHistoryCursor.tryCreate(
              occurredAt: DateTime.parse('2026-08-07T01:00:00Z'),
              entryId: entryId,
            ),
          )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          historyResult:
              ChoreDataSucceeded<ChoreOccurrenceHistoryPageDataRecord>(
                ChoreOccurrenceHistoryPageDataRecord(
                  events: <ChoreOccurrenceHistoryDataRecord>[
                    _historyRecord(
                      historyEntryId:
                          'completion:61000000-0000-4000-8000-000000000702',
                      occurredAt: '2026-08-07T01:00:00Z',
                    ),
                  ],
                  hasMore: false,
                ),
              ),
        ),
      );

      final LoadChoreOccurrenceHistoryResult result = await repository
          .loadOccurrenceHistory(request);

      expect(
        (result as LoadChoreOccurrenceHistoryFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test(
      'fails closed on cross-household or malformed provider data',
      () async {
        for (final TodayChoresDataRecord record in <TodayChoresDataRecord>[
          TodayChoresDataRecord(
            householdId: '99999999-9999-4999-8999-999999999999',
            householdTimezone: 'Asia/Seoul',
            householdLocalDate: '2026-08-06',
            occurrences: const <ChoreOccurrenceDataRecord>[],
          ),
          TodayChoresDataRecord(
            householdId: _householdId.value,
            householdTimezone: 'not a timezone',
            householdLocalDate: '2026-08-06',
            occurrences: const <ChoreOccurrenceDataRecord>[],
          ),
          TodayChoresDataRecord(
            householdId: _householdId.value,
            householdTimezone: 'Asia/Seoul',
            householdLocalDate: '2026-08-06',
            occurrences: <ChoreOccurrenceDataRecord>[
              _record(dueAt: '2026-08-06T19:30:00'),
            ],
          ),
          TodayChoresDataRecord(
            householdId: _householdId.value,
            householdTimezone: 'Asia/Seoul',
            householdLocalDate: '2026-08-06',
            occurrences: <ChoreOccurrenceDataRecord>[
              _record(recurrenceFrequency: 'yearly'),
            ],
          ),
        ]) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: ChoreDataSucceeded<TodayChoresDataRecord>(record),
            ),
          );

          final LoadTodayChoresResult result = await repository.loadToday(
            _householdId,
          );
          expect(
            (result as LoadTodayChoresFailed).failure.kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('maps strict completion and reopen snapshots', () async {
      for (final ({bool completed, ChoreCompletionDataRecord record}) testCase
          in <({bool completed, ChoreCompletionDataRecord record})>[
            (completed: true, record: _completionRecord()),
            (
              completed: false,
              record: _completionRecord(
                status: 'scheduled',
                version: 3,
                completedByMemberId: null,
                completedAt: null,
              ),
            ),
          ]) {
        final SetChoreCompletionRequest request = _completionRequest(
          completed: testCase.completed,
          expectedVersion: testCase.completed ? 1 : 2,
        );
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            completionResult: ChoreDataSucceeded<ChoreCompletionDataRecord>(
              testCase.record,
            ),
          ),
        );

        final SetChoreCompletionResult result = await repository
            .setOccurrenceCompletion(request);

        expect(result, isA<ChoreCompletionSet>());
        final ChoreCompletionSnapshot snapshot =
            (result as ChoreCompletionSet).snapshot;
        expect(snapshot.householdId, request.householdId);
        expect(snapshot.occurrenceId, request.occurrenceId);
        expect(
          snapshot.status,
          testCase.completed
              ? ChoreOccurrenceStatus.completed
              : ChoreOccurrenceStatus.scheduled,
        );
        expect(snapshot.version, request.expectedVersion + 1);
        expect(snapshot.completedAt?.isUtc ?? !testCase.completed, isTrue);
      }
    });

    test('maps a strict recurring creation snapshot', () async {
      final CreateRecurringChoreRequest request = _recurringRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          recurringResult: ChoreDataSucceeded<RecurringChoreDataRecord>(
            _recurringRecord(),
          ),
        ),
      );

      final CreateRecurringChoreResult result = await repository
          .createRecurringChore(request);

      expect(result, isA<RecurringChoreCreated>());
      final RecurringChoreSnapshot snapshot =
          (result as RecurringChoreCreated).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(
        snapshot.recurrenceRule.fingerprint,
        request.recurrenceRule.fingerprint,
      );
      expect(snapshot.materializedThrough.value, '2027-08-06');
      expect(snapshot.materializedCount, 366);
      expect(snapshot.created, isTrue);
    });

    test('fails closed on inconsistent recurring snapshots', () async {
      final CreateRecurringChoreRequest request = _recurringRequest();
      for (final RecurringChoreDataRecord record in <RecurringChoreDataRecord>[
        _recurringRecord(householdId: '99999999-9999-4999-8999-999999999999'),
        _recurringRecord(seriesId: 'not-a-uuid'),
        _recurringRecord(
          recurrenceRule: <String, Object?>{
            'frequency': 'weekly',
            'interval': 1,
            'weekdays': <String>['TH'],
            'end': <String, Object?>{'type': 'never'},
          },
        ),
        _recurringRecord(materializedThrough: '2026-08-05'),
        _recurringRecord(materializedThrough: '2027-08-07'),
        _recurringRecord(materializedCount: 0),
      ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            recurringResult: ChoreDataSucceeded<RecurringChoreDataRecord>(
              record,
            ),
          ),
        );

        final CreateRecurringChoreResult result = await repository
            .createRecurringChore(request);

        expect(
          (result as CreateRecurringChoreFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('fails closed on inconsistent completion snapshots', () async {
      final SetChoreCompletionRequest request = _completionRequest();
      for (final ChoreCompletionDataRecord record
          in <ChoreCompletionDataRecord>[
            _completionRecord(
              householdId: '99999999-9999-4999-8999-999999999999',
            ),
            _completionRecord(
              occurrenceId: '66666666-6666-4666-8666-666666666666',
            ),
            _completionRecord(
              status: 'scheduled',
              completedByMemberId: null,
              completedAt: null,
            ),
            _completionRecord(version: 1),
            _completionRecord(completedByMemberId: null),
            _completionRecord(completedAt: null),
            _completionRecord(completedAt: '2026-08-06T10:30:00'),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            completionResult: ChoreDataSucceeded<ChoreCompletionDataRecord>(
              record,
            ),
          ),
        );

        final SetChoreCompletionResult result = await repository
            .setOccurrenceCompletion(request);

        expect(
          (result as SetChoreCompletionFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps a strict occurrence skip snapshot', () async {
      final SkipChoreOccurrenceRequest request = _skipRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          skipResult: ChoreDataSucceeded<ChoreOccurrenceSkipDataRecord>(
            _skipRecord(),
          ),
        ),
      );

      final SkipChoreOccurrenceResult result = await repository.skipOccurrence(
        request,
      );

      expect(result, isA<ChoreOccurrenceSkipped>());
      final ChoreOccurrenceSkipSnapshot snapshot =
          (result as ChoreOccurrenceSkipped).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.version, 2);
      expect(snapshot.changed, isTrue);
    });

    test('fails closed on inconsistent occurrence skip snapshots', () async {
      final SkipChoreOccurrenceRequest request = _skipRequest();
      for (final ChoreOccurrenceSkipDataRecord record
          in <ChoreOccurrenceSkipDataRecord>[
            _skipRecord(householdId: '99999999-9999-4999-8999-999999999999'),
            _skipRecord(occurrenceId: '66666666-6666-4666-8666-666666666666'),
            _skipRecord(status: 'scheduled'),
            _skipRecord(version: 1),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            skipResult: ChoreDataSucceeded<ChoreOccurrenceSkipDataRecord>(
              record,
            ),
          ),
        );

        final SkipChoreOccurrenceResult result = await repository
            .skipOccurrence(request);

        expect(
          (result as SkipChoreOccurrenceFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps a strict skipped-occurrence restore snapshot', () async {
      final RestoreSkippedChoreOccurrenceRequest request = _restoreRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          restoreResult: ChoreDataSucceeded<ChoreOccurrenceRestoreDataRecord>(
            _restoreRecord(),
          ),
        ),
      );

      final RestoreSkippedChoreOccurrenceResult result = await repository
          .restoreSkippedOccurrence(request);

      expect(result, isA<ChoreOccurrenceRestored>());
      final ChoreOccurrenceRestoreSnapshot snapshot =
          (result as ChoreOccurrenceRestored).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.version, 3);
      expect(snapshot.changed, isTrue);
    });

    test('fails closed on inconsistent occurrence restore snapshots', () async {
      final RestoreSkippedChoreOccurrenceRequest request = _restoreRequest();
      for (final ChoreOccurrenceRestoreDataRecord record
          in <ChoreOccurrenceRestoreDataRecord>[
            _restoreRecord(householdId: '99999999-9999-4999-8999-999999999999'),
            _restoreRecord(
              occurrenceId: '66666666-6666-4666-8666-666666666666',
            ),
            _restoreRecord(status: 'skipped'),
            _restoreRecord(version: 2),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            restoreResult: ChoreDataSucceeded<ChoreOccurrenceRestoreDataRecord>(
              record,
            ),
          ),
        );

        final RestoreSkippedChoreOccurrenceResult result = await repository
            .restoreSkippedOccurrence(request);

        expect(
          (result as RestoreSkippedChoreOccurrenceFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps a strict occurrence reschedule snapshot', () async {
      final RescheduleChoreOccurrenceRequest request = _rescheduleRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          rescheduleResult:
              ChoreDataSucceeded<ChoreOccurrenceRescheduleDataRecord>(
                _rescheduleRecord(),
              ),
        ),
      );

      final RescheduleChoreOccurrenceResult result = await repository
          .rescheduleOccurrence(request);

      expect(result, isA<ChoreOccurrenceRescheduled>());
      final ChoreOccurrenceRescheduleSnapshot snapshot =
          (result as ChoreOccurrenceRescheduled).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.dueLocalDate, request.dueLocalDate);
      expect(snapshot.dueLocalTime, request.dueLocalTime);
      expect(snapshot.dueAt, DateTime.parse('2026-08-07T09:30:00Z'));
      expect(snapshot.dueAt?.isUtc, isTrue);
      expect(snapshot.version, 2);
      expect(snapshot.changed, isTrue);
    });

    test('fails closed on inconsistent reschedule snapshots', () async {
      final RescheduleChoreOccurrenceRequest request = _rescheduleRequest();
      for (final ChoreOccurrenceRescheduleDataRecord record
          in <ChoreOccurrenceRescheduleDataRecord>[
            _rescheduleRecord(
              householdId: '99999999-9999-4999-8999-999999999999',
            ),
            _rescheduleRecord(
              occurrenceId: '66666666-6666-4666-8666-666666666666',
            ),
            _rescheduleRecord(dueLocalDate: '2026-08-08'),
            _rescheduleRecord(dueLocalTime: '18:31'),
            _rescheduleRecord(dueLocalTime: '25:00'),
            _rescheduleRecord(dueAt: '2026-08-07T18:30:00'),
            _rescheduleRecord(dueAt: null),
            _rescheduleRecord(status: 'completed'),
            _rescheduleRecord(version: 1),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            rescheduleResult:
                ChoreDataSucceeded<ChoreOccurrenceRescheduleDataRecord>(record),
          ),
        );

        final RescheduleChoreOccurrenceResult result = await repository
            .rescheduleOccurrence(request);

        expect(
          (result as RescheduleChoreOccurrenceFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps a strict occurrence reassignment snapshot', () async {
      final ReassignChoreOccurrenceRequest request = _reassignmentRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          reassignmentResult:
              ChoreDataSucceeded<ChoreOccurrenceReassignmentDataRecord>(
                _reassignmentRecord(),
              ),
        ),
      );

      final ReassignChoreOccurrenceResult result = await repository
          .reassignOccurrence(request);

      expect(result, isA<ChoreOccurrenceReassigned>());
      final ChoreOccurrenceReassignmentSnapshot snapshot =
          (result as ChoreOccurrenceReassigned).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.assigneeMemberId, request.assigneeMemberId);
      expect(snapshot.assigneeDisplayName, 'Sam');
      expect(snapshot.version, 2);
      expect(snapshot.changed, isTrue);
    });

    test('fails closed on inconsistent reassignment snapshots', () async {
      final ReassignChoreOccurrenceRequest request = _reassignmentRequest();
      for (final ChoreOccurrenceReassignmentDataRecord record
          in <ChoreOccurrenceReassignmentDataRecord>[
            _reassignmentRecord(
              householdId: '99999999-9999-4999-8999-999999999999',
            ),
            _reassignmentRecord(
              occurrenceId: '66666666-6666-4666-8666-666666666666',
            ),
            _reassignmentRecord(
              assigneeMemberId: '33333333-3333-4333-8333-333333333333',
            ),
            _reassignmentRecord(assigneeMemberId: 'not-a-uuid'),
            _reassignmentRecord(assigneeDisplayName: ''),
            _reassignmentRecord(assigneeDisplayName: ' Sam '),
            _reassignmentRecord(
              assigneeDisplayName: List<String>.filled(81, 'S').join(),
            ),
            _reassignmentRecord(status: 'completed'),
            _reassignmentRecord(version: 1),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            reassignmentResult:
                ChoreDataSucceeded<ChoreOccurrenceReassignmentDataRecord>(
                  record,
                ),
          ),
        );

        final ReassignChoreOccurrenceResult result = await repository
            .reassignOccurrence(request);

        expect(
          (result as ReassignChoreOccurrenceFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps a strict one-time chore update snapshot', () async {
      final UpdateOneTimeChoreRequest request = _oneTimeUpdateRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          oneTimeUpdateResult: ChoreDataSucceeded<OneTimeChoreUpdateDataRecord>(
            _oneTimeUpdateRecord(),
          ),
        ),
      );

      final UpdateOneTimeChoreResult result = await repository
          .updateOneTimeChore(request);

      expect(result, isA<OneTimeChoreUpdated>());
      final OneTimeChoreUpdateSnapshot snapshot =
          (result as OneTimeChoreUpdated).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.seriesId, request.seriesId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.revisionNumber, 2);
      expect(snapshot.dueLocalDate, request.dueLocalDate);
      expect(snapshot.dueLocalTime, request.dueLocalTime);
      expect(snapshot.dueAt, DateTime.parse('2026-08-07T09:30:00Z'));
      expect(snapshot.assigneeMemberId, request.assigneeMemberId);
      expect(snapshot.seriesVersion, 2);
      expect(snapshot.occurrenceVersion, 2);
      expect(snapshot.changed, isTrue);
    });

    test('fails closed on inconsistent one-time update snapshots', () async {
      final UpdateOneTimeChoreRequest request = _oneTimeUpdateRequest();
      for (final OneTimeChoreUpdateDataRecord record
          in <OneTimeChoreUpdateDataRecord>[
            _oneTimeUpdateRecord(
              householdId: '99999999-9999-4999-8999-999999999999',
            ),
            _oneTimeUpdateRecord(
              seriesId: '66666666-6666-4666-8666-666666666666',
            ),
            _oneTimeUpdateRecord(
              occurrenceId: '66666666-6666-4666-8666-666666666666',
            ),
            _oneTimeUpdateRecord(revisionId: 'not-a-uuid'),
            _oneTimeUpdateRecord(revisionNumber: 3),
            _oneTimeUpdateRecord(dueLocalDate: '2026-08-08'),
            _oneTimeUpdateRecord(dueLocalTime: null),
            _oneTimeUpdateRecord(dueAt: '2026-08-07T09:30:00'),
            _oneTimeUpdateRecord(
              assigneeMemberId: '33333333-3333-4333-8333-333333333333',
            ),
            _oneTimeUpdateRecord(seriesVersion: 1),
            _oneTimeUpdateRecord(occurrenceVersion: 1),
          ]) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            oneTimeUpdateResult:
                ChoreDataSucceeded<OneTimeChoreUpdateDataRecord>(record),
          ),
        );

        final UpdateOneTimeChoreResult result = await repository
            .updateOneTimeChore(request);

        expect(
          (result as UpdateOneTimeChoreFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      }
    });

    test('maps and validates a one-time chore deletion snapshot', () async {
      final DeleteOneTimeChoreRequest request = _oneTimeDeletionRequest();
      final ProviderChoreRepository validRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          oneTimeDeletionResult:
              ChoreDataSucceeded<OneTimeChoreDeletionDataRecord>(
                _oneTimeDeletionRecord(),
              ),
        ),
      );
      final ProviderChoreRepository invalidRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          oneTimeDeletionResult:
              ChoreDataSucceeded<OneTimeChoreDeletionDataRecord>(
                _oneTimeDeletionRecord(status: 'scheduled'),
              ),
        ),
      );

      final DeleteOneTimeChoreResult valid = await validRepository
          .deleteOneTimeChore(request);
      final DeleteOneTimeChoreResult invalid = await invalidRepository
          .deleteOneTimeChore(request);

      expect(valid, isA<OneTimeChoreDeleted>());
      final OneTimeChoreDeletionSnapshot snapshot =
          (valid as OneTimeChoreDeleted).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.seriesId, request.seriesId);
      expect(snapshot.occurrenceId, request.occurrenceId);
      expect(snapshot.seriesVersion, 2);
      expect(snapshot.occurrenceVersion, 2);
      expect(snapshot.changed, isTrue);
      expect(
        (invalid as DeleteOneTimeChoreFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test('maps a strict whole-series update snapshot', () async {
      final UpdateRepeatingChoreSeriesRequest request = _seriesUpdateRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesUpdateResult:
              ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                _seriesUpdateRecord(),
              ),
        ),
      );

      final UpdateRepeatingChoreSeriesResult result = await repository
          .updateRepeatingSeries(request);

      expect(result, isA<RepeatingChoreSeriesUpdated>());
      final RepeatingChoreSeriesUpdateSnapshot snapshot =
          (result as RepeatingChoreSeriesUpdated).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.seriesId, request.seriesId);
      expect(snapshot.effectiveLocalDate, request.effectiveLocalDate);
      expect(snapshot.revisionNumber, 2);
      expect(snapshot.version, 2);
      expect(snapshot.rebuiltCount, 31);
      expect(snapshot.cancelledCount, 335);
      expect(snapshot.changed, isTrue);
    });

    test('maps a server-owned selected-occurrence boundary snapshot', () async {
      final UpdateRepeatingChoreSeriesFromOccurrenceRequest request =
          _seriesFromOccurrenceUpdateRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesFromOccurrenceUpdateResult:
              ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                _seriesUpdateRecord(effectiveLocalDate: '2026-08-12'),
              ),
        ),
      );

      final UpdateRepeatingChoreSeriesResult result = await repository
          .updateRepeatingSeriesFromOccurrence(request);

      expect(result, isA<RepeatingChoreSeriesUpdated>());
      final RepeatingChoreSeriesUpdateSnapshot snapshot =
          (result as RepeatingChoreSeriesUpdated).snapshot;
      expect(snapshot.householdId, request.householdId);
      expect(snapshot.seriesId, request.seriesId);
      expect(snapshot.effectiveLocalDate.value, '2026-08-12');
      expect(snapshot.version, request.expectedVersion + 1);
    });

    test(
      'fails closed on an inconsistent selected-occurrence result',
      () async {
        final UpdateRepeatingChoreSeriesFromOccurrenceRequest request =
            _seriesFromOccurrenceUpdateRequest();
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            seriesFromOccurrenceUpdateResult:
                ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                  _seriesUpdateRecord(version: 1),
                ),
          ),
        );

        final UpdateRepeatingChoreSeriesResult result = await repository
            .updateRepeatingSeriesFromOccurrence(request);

        expect(
          (result as UpdateRepeatingChoreSeriesFailed).failure.kind,
          ChoreFailureKind.invalidPayload,
        );
      },
    );

    test(
      'accepts the server-authoritative date across local midnight',
      () async {
        final UpdateRepeatingChoreSeriesRequest request =
            _seriesUpdateRequest();
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
              ChoreDataFailureKind.temporarilyUnavailable,
            ),
            seriesUpdateResult:
                ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                  _seriesUpdateRecord(effectiveLocalDate: '2026-08-07'),
                ),
          ),
        );

        final UpdateRepeatingChoreSeriesResult result = await repository
            .updateRepeatingSeries(request);

        expect(
          (result as RepeatingChoreSeriesUpdated)
              .snapshot
              .effectiveLocalDate
              .value,
          '2026-08-07',
        );
      },
    );

    test('fails closed on an inconsistent whole-series update', () async {
      final UpdateRepeatingChoreSeriesRequest request = _seriesUpdateRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesUpdateResult:
              ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                _seriesUpdateRecord(version: 1),
              ),
        ),
      );

      final UpdateRepeatingChoreSeriesResult result = await repository
          .updateRepeatingSeries(request);

      expect(
        (result as UpdateRepeatingChoreSeriesFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test('maps and validates a whole-series cancellation snapshot', () async {
      final CancelRepeatingChoreSeriesRequest request =
          _seriesCancellationRequest();
      final ProviderChoreRepository validRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesCancellationResult:
              ChoreDataSucceeded<RepeatingChoreSeriesCancellationDataRecord>(
                _seriesCancellationRecord(),
              ),
        ),
      );
      final ProviderChoreRepository invalidRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesCancellationResult:
              ChoreDataSucceeded<RepeatingChoreSeriesCancellationDataRecord>(
                _seriesCancellationRecord(version: 1),
              ),
        ),
      );

      final CancelRepeatingChoreSeriesResult valid = await validRepository
          .cancelRepeatingSeries(request);
      final CancelRepeatingChoreSeriesResult invalid = await invalidRepository
          .cancelRepeatingSeries(request);

      expect(valid, isA<RepeatingChoreSeriesCancelled>());
      expect(
        (valid as RepeatingChoreSeriesCancelled).snapshot.cancelledCount,
        365,
      );
      expect(
        (invalid as CancelRepeatingChoreSeriesFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test(
      'maps selected-occurrence cancellation with or without a retained prefix',
      () async {
        final CancelRepeatingChoreSeriesFromOccurrenceRequest request =
            _seriesFromOccurrenceCancellationRequest();
        final ProviderChoreRepository retainedPrefixRepository =
            ProviderChoreRepository(
              _FakeChoreDataSource(
                loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                  ChoreDataFailureKind.temporarilyUnavailable,
                ),
                seriesFromOccurrenceCancellationResult:
                    ChoreDataSucceeded<
                      RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
                    >(_seriesFromOccurrenceCancellationRecord()),
              ),
            );
        final ProviderChoreRepository deletedSeriesRepository =
            ProviderChoreRepository(
              _FakeChoreDataSource(
                loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                  ChoreDataFailureKind.temporarilyUnavailable,
                ),
                seriesFromOccurrenceCancellationResult:
                    ChoreDataSucceeded<
                      RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
                    >(
                      _seriesFromOccurrenceCancellationRecord(
                        terminalRevisionId: null,
                        terminalRevisionNumber: null,
                      ),
                    ),
              ),
            );

        final CancelRepeatingChoreSeriesFromOccurrenceResult retained =
            await retainedPrefixRepository.cancelRepeatingSeriesFromOccurrence(
              request,
            );
        final CancelRepeatingChoreSeriesFromOccurrenceResult deleted =
            await deletedSeriesRepository.cancelRepeatingSeriesFromOccurrence(
              request,
            );

        expect(retained, isA<RepeatingChoreSeriesCancelledFromOccurrence>());
        final RepeatingChoreSeriesFromOccurrenceCancellationSnapshot snapshot =
            (retained as RepeatingChoreSeriesCancelledFromOccurrence).snapshot;
        expect(snapshot.effectiveLocalDate.value, '2026-08-12');
        expect(snapshot.cancelledCount, 19);
        expect(snapshot.preservedCompletedCount, 2);
        expect(snapshot.terminalRevisionNumber, 2);
        expect(snapshot.retainsScheduledPrefix, isTrue);
        expect(
          (deleted as RepeatingChoreSeriesCancelledFromOccurrence)
              .snapshot
              .retainsScheduledPrefix,
          isFalse,
        );
      },
    );

    test(
      'rejects inconsistent selected-occurrence cancellation pairs',
      () async {
        final CancelRepeatingChoreSeriesFromOccurrenceRequest request =
            _seriesFromOccurrenceCancellationRequest();
        for (final RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
            record
            in <RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>[
              _seriesFromOccurrenceCancellationRecord(
                terminalRevisionNumber: null,
              ),
              _seriesFromOccurrenceCancellationRecord(version: 1),
              _seriesFromOccurrenceCancellationRecord(cancelledCount: 0),
            ]) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              ),
              seriesFromOccurrenceCancellationResult:
                  ChoreDataSucceeded<
                    RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
                  >(record),
            ),
          );

          final CancelRepeatingChoreSeriesFromOccurrenceResult result =
              await repository.cancelRepeatingSeriesFromOccurrence(request);

          expect(
            (result as CancelRepeatingChoreSeriesFromOccurrenceFailed)
                .failure
                .kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('maps a strict selected-occurrence cancellation resume', () async {
      final ResumeRepeatingChoreSeriesCancellationRequest request =
          _seriesCancellationResumeRequest();
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          seriesCancellationResumeResult:
              ChoreDataSucceeded<
                RepeatingChoreSeriesCancellationResumeDataRecord
              >(_seriesCancellationResumeRecord()),
        ),
      );

      final ResumeRepeatingChoreSeriesCancellationResult result =
          await repository.resumeRepeatingSeriesCancellation(request);

      expect(result, isA<RepeatingChoreSeriesCancellationResumed>());
      final RepeatingChoreSeriesCancellationResumeSnapshot snapshot =
          (result as RepeatingChoreSeriesCancellationResumed).snapshot;
      expect(snapshot.effectiveLocalDate.value, '2026-08-12');
      expect(snapshot.version, 3);
      expect(snapshot.restoredCount, 19);
      expect(snapshot.preservedCompletedCount, 2);
      expect(snapshot.revisionNumber, 3);
    });

    test(
      'rejects malformed selected-occurrence cancellation resumes',
      () async {
        final ResumeRepeatingChoreSeriesCancellationRequest request =
            _seriesCancellationResumeRequest();
        for (final RepeatingChoreSeriesCancellationResumeDataRecord record
            in <RepeatingChoreSeriesCancellationResumeDataRecord>[
              _seriesCancellationResumeRecord(version: 2),
              _seriesCancellationResumeRecord(restoredCount: 0),
              _seriesCancellationResumeRecord(revisionId: 'not-a-uuid'),
              _seriesCancellationResumeRecord(revisionNumber: 0),
            ]) {
          final ProviderChoreRepository repository = ProviderChoreRepository(
            _FakeChoreDataSource(
              loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              ),
              seriesCancellationResumeResult:
                  ChoreDataSucceeded<
                    RepeatingChoreSeriesCancellationResumeDataRecord
                  >(record),
            ),
          );

          final ResumeRepeatingChoreSeriesCancellationResult result =
              await repository.resumeRepeatingSeriesCancellation(request);

          expect(
            (result as ResumeRepeatingChoreSeriesCancellationFailed)
                .failure
                .kind,
            ChoreFailureKind.invalidPayload,
          );
        }
      },
    );

    test('maps stable data failure kinds without provider details', () async {
      const Map<ChoreDataFailureKind, ChoreFailureKind>
      cases = <ChoreDataFailureKind, ChoreFailureKind>{
        ChoreDataFailureKind.unauthenticated: ChoreFailureKind.unauthenticated,
        ChoreDataFailureKind.invalidInput: ChoreFailureKind.invalidInput,
        ChoreDataFailureKind.notFoundOrForbidden:
            ChoreFailureKind.notFoundOrForbidden,
        ChoreDataFailureKind.idempotencyConflict:
            ChoreFailureKind.idempotencyConflict,
        ChoreDataFailureKind.invalidRecurrence:
            ChoreFailureKind.invalidRecurrence,
        ChoreDataFailureKind.staleVersion: ChoreFailureKind.staleVersion,
        ChoreDataFailureKind.invalidTransition:
            ChoreFailureKind.invalidTransition,
        ChoreDataFailureKind.featurePolicyUnavailable:
            ChoreFailureKind.featurePolicyUnavailable,
        ChoreDataFailureKind.featureLimitReached:
            ChoreFailureKind.featureLimitReached,
        ChoreDataFailureKind.temporarilyUnavailable:
            ChoreFailureKind.temporarilyUnavailable,
        ChoreDataFailureKind.invalidPayload: ChoreFailureKind.invalidPayload,
        ChoreDataFailureKind.unknown: ChoreFailureKind.internal,
      };

      for (final entry in cases.entries) {
        final ProviderChoreRepository repository = ProviderChoreRepository(
          _FakeChoreDataSource(
            loadResult: ChoreDataFailed<TodayChoresDataRecord>(entry.key),
          ),
        );
        final result = await repository.loadToday(_householdId);
        expect(
          (result as LoadTodayChoresFailed).failure.kind,
          entry.value,
          reason: entry.key.name,
        );
      }
    });

    test('maps a strict deleted one-time chore page', () async {
      final DeletedOneTimeChoreListRequest request =
          DeletedOneTimeChoreListRequest.tryCreate(
            householdId: _householdId,
            limit: 1,
          )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          deletedOneTimeChoresResult:
              ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>(
                _deletedOneTimeChorePageRecord(
                  items: <DeletedOneTimeChoreDataRecord>[
                    _deletedOneTimeChoreRecord(),
                  ],
                ),
              ),
        ),
      );

      final LoadDeletedOneTimeChoresResult result = await repository
          .loadDeletedOneTimeChores(request);

      expect(result, isA<DeletedOneTimeChoresLoaded>());
      final DeletedOneTimeChorePage page =
          (result as DeletedOneTimeChoresLoaded).page;
      expect(page.items.single.title, 'Take out recycling');
      expect(page.items.single.deletedAt.isUtc, isTrue);
      expect(page.items.single.dueAt?.isUtc, isTrue);
      expect(page.pageLimit, 1);
    });

    test('fails closed on an unsorted deleted chore page', () async {
      final DeletedOneTimeChoreListRequest request =
          DeletedOneTimeChoreListRequest.tryCreate(
            householdId: _householdId,
            limit: 2,
          )!;
      final ProviderChoreRepository repository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          deletedOneTimeChoresResult:
              ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>(
                _deletedOneTimeChorePageRecord(
                  limit: 2,
                  items: <DeletedOneTimeChoreDataRecord>[
                    _deletedOneTimeChoreRecord(
                      seriesId: '44444444-4444-4444-8444-444444444441',
                      occurrenceId: '55555555-5555-4555-8555-555555555551',
                      deletedAt: '2026-08-09T09:00:00Z',
                    ),
                    _deletedOneTimeChoreRecord(
                      seriesId: '44444444-4444-4444-8444-444444444442',
                      occurrenceId: '55555555-5555-4555-8555-555555555552',
                      deletedAt: '2026-08-09T10:00:00Z',
                    ),
                  ],
                ),
              ),
        ),
      );

      final LoadDeletedOneTimeChoresResult result = await repository
          .loadDeletedOneTimeChores(request);

      expect(
        (result as LoadDeletedOneTimeChoresFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });

    test('maps and validates exact one-time chore restore metadata', () async {
      final RestoreOneTimeChoreRequest request = _oneTimeRestoreRequest();
      final ProviderChoreRepository validRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          oneTimeRestoreResult:
              ChoreDataSucceeded<OneTimeChoreRestoreDataRecord>(
                _oneTimeRestoreRecord(),
              ),
        ),
      );
      final ProviderChoreRepository invalidRepository = ProviderChoreRepository(
        _FakeChoreDataSource(
          loadResult: const ChoreDataFailed<TodayChoresDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
          oneTimeRestoreResult:
              ChoreDataSucceeded<OneTimeChoreRestoreDataRecord>(
                _oneTimeRestoreRecord(status: 'cancelled'),
              ),
        ),
      );

      final RestoreOneTimeChoreResult valid = await validRepository
          .restoreOneTimeChore(request);
      final RestoreOneTimeChoreResult invalid = await invalidRepository
          .restoreOneTimeChore(request);

      expect(valid, isA<OneTimeChoreRestored>());
      expect((valid as OneTimeChoreRestored).snapshot.seriesVersion, 3);
      expect(
        (invalid as RestoreOneTimeChoreFailed).failure.kind,
        ChoreFailureKind.invalidPayload,
      );
    });
  });
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;

final ChoreOccurrenceId _occurrenceId = ChoreOccurrenceId.tryParse(
  '55555555-5555-4555-8555-555555555555',
)!;

HouseholdWeeklyReportDataRecord _weeklyReportRecord({
  List<HouseholdWeeklyReportMemberDataRecord> members =
      const <HouseholdWeeklyReportMemberDataRecord>[
        HouseholdWeeklyReportMemberDataRecord(
          memberId: '33333333-3333-4333-8333-333333333333',
          displayName: 'Alex',
          completedCount: 2,
          completedByWeekEndCount: 1,
          isViewer: true,
        ),
        HouseholdWeeklyReportMemberDataRecord(
          memberId: '33333333-3333-4333-8333-333333333334',
          displayName: 'Sam',
          completedCount: 1,
          completedByWeekEndCount: 1,
          isViewer: false,
        ),
      ],
}) {
  return HouseholdWeeklyReportDataRecord(
    householdId: _householdId.value,
    householdTimezone: 'Asia/Seoul',
    generatedAt: '2026-08-10T01:00:00Z',
    weekOffset: 0,
    weekStart: '2026-08-03',
    weekEnd: '2026-08-09',
    dueCount: 4,
    completedCount: 3,
    completedByWeekEndCount: 2,
    completedAfterWeekEndCount: 1,
    openCount: 1,
    skippedCount: 1,
    viewerCompletedCount: 2,
    members: members,
    otherMemberCompletedCount: 0,
    memberBreakdownTruncated: false,
  );
}

DeletedOneTimeChoreDataRecord _deletedOneTimeChoreRecord({
  String seriesId = '44444444-4444-4444-8444-444444444444',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String deletedAt = '2026-08-09T10:00:00Z',
}) {
  return DeletedOneTimeChoreDataRecord(
    householdId: _householdId.value,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    title: 'Take out recycling',
    description: 'Blue bin',
    assigneeMemberId: '33333333-3333-4333-8333-333333333333',
    assigneeDisplayName: 'Alex',
    dueLocalDate: '2026-08-09',
    dueLocalTime: '19:30',
    dueAt: '2026-08-09T10:30:00Z',
    deletedAt: deletedAt,
    seriesVersion: 2,
    occurrenceVersion: 2,
  );
}

DeletedOneTimeChorePageDataRecord _deletedOneTimeChorePageRecord({
  int limit = 1,
  List<DeletedOneTimeChoreDataRecord> items =
      const <DeletedOneTimeChoreDataRecord>[],
}) {
  return DeletedOneTimeChorePageDataRecord(
    householdId: _householdId.value,
    householdTimezone: 'Asia/Seoul',
    generatedAt: '2026-08-09T10:30:00Z',
    pageLimit: limit,
    hasMore: false,
    pageCursor: null,
    items: items,
  );
}

RestoreOneTimeChoreRequest _oneTimeRestoreRequest() {
  return OneTimeChoreRestoreDraft.tryCreate(
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    occurrenceId: _occurrenceId,
    expectedSeriesVersion: 2,
    expectedOccurrenceVersion: 2,
  )!.withId(ChoreCommandId.tryParse('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')!);
}

OneTimeChoreRestoreDataRecord _oneTimeRestoreRecord({
  String status = 'scheduled',
}) {
  return OneTimeChoreRestoreDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    occurrenceId: _occurrenceId.value,
    status: status,
    seriesVersion: 3,
    occurrenceVersion: 3,
    changed: true,
  );
}

ChoreOccurrenceHistoryRequest _historyRequest() {
  return ChoreOccurrenceHistoryRequest.tryCreate(
    householdId: _householdId,
    occurrenceId: _occurrenceId,
  )!;
}

ChoreOccurrenceHistoryDataRecord _historyRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String historyEntryId = 'completion:61000000-0000-4000-8000-000000000701',
  String eventType = 'completed',
  String actorMemberId = '33333333-3333-4333-8333-333333333333',
  String actorDisplayName = 'Alex',
  String? actingMemberId,
  String? actingDisplayName,
  String occurredAt = '2026-08-07T01:00:00Z',
  int occurrenceVersion = 2,
  String? previousDueLocalDate,
  String? previousDueLocalTime,
  String? newDueLocalDate,
  String? newDueLocalTime,
  String? previousAssigneeMemberId,
  String? previousAssigneeDisplayName,
  String? newAssigneeMemberId,
  String? newAssigneeDisplayName,
}) {
  return ChoreOccurrenceHistoryDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    historyEntryId: historyEntryId,
    eventType: eventType,
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

ChoreOccurrenceDataRecord _record({
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String dueLocalDate = '2026-08-06',
  String? dueLocalTime = '19:30',
  String? dueAt = '2026-08-06T10:30:00Z',
  String status = 'scheduled',
  String? recurrenceFrequency,
  bool canManageSeries = false,
  bool canSetCompletion = false,
}) {
  return ChoreOccurrenceDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    occurrenceId: occurrenceId,
    title: 'Take out recycling',
    description: 'Blue bin',
    assigneeMemberId: '33333333-3333-4333-8333-333333333333',
    assigneeDisplayName: 'Alex',
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    status: status,
    version: 1,
    recurrenceFrequency: recurrenceFrequency,
    seriesVersion: 1,
    seriesDefaultAssigneeMemberId: '33333333-3333-4333-8333-333333333333',
    seriesDueLocalTime: '19:30',
    recurrenceRule: recurrenceFrequency == null
        ? null
        : <String, Object?>{
            'frequency': 'daily',
            'interval': 1,
            'end': <String, Object?>{'type': 'never'},
          },
    canManageSeries: canManageSeries,
    canSetCompletion: canSetCompletion,
  );
}

ChoreListPageDataRecord _choreListRecord({
  String generatedAt = '2026-08-06T10:30:00Z',
  String listView = 'upcoming',
  bool hasMore = false,
  String? pageCursor,
  List<ChoreOccurrenceDataRecord> occurrences =
      const <ChoreOccurrenceDataRecord>[],
}) {
  return ChoreListPageDataRecord(
    householdId: _householdId.value,
    householdTimezone: 'Asia/Seoul',
    householdLocalDate: '2026-08-06',
    generatedAt: generatedAt,
    listView: listView,
    assigneeFilterMemberId: null,
    pageLimit: 2,
    hasMore: hasMore,
    pageCursor: pageCursor,
    occurrences: occurrences,
  );
}

UpdateRepeatingChoreSeriesRequest _seriesUpdateRequest() {
  final ChoreLocalDate effectiveDate = ChoreLocalDate.tryParse('2026-08-06')!;
  return UpdateRepeatingChoreSeriesRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    )!,
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    expectedVersion: 1,
    effectiveLocalDate: effectiveDate,
    title: 'Updated recycling',
    description: 'Use the blue bin',
    assigneeMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333334',
    )!,
    dueLocalTime: ChoreLocalTime.tryParse('20:00'),
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.weekly,
      startLocalDate: effectiveDate,
    ),
  );
}

UpdateRepeatingChoreSeriesFromOccurrenceRequest
_seriesFromOccurrenceUpdateRequest() {
  final ChoreLocalDate effectiveDate = ChoreLocalDate.tryParse('2026-08-12')!;
  return UpdateRepeatingChoreSeriesFromOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'edededed-eded-4ded-8ded-edededededed',
    )!,
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    effectiveOccurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 1,
    title: 'Updated from here',
    description: null,
    assigneeMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333334',
    )!,
    dueLocalTime: ChoreLocalTime.tryParse('20:00'),
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.weekly,
      startLocalDate: effectiveDate,
    ),
  );
}

RepeatingChoreSeriesUpdateDataRecord _seriesUpdateRecord({
  String effectiveLocalDate = '2026-08-06',
  int version = 2,
}) {
  return RepeatingChoreSeriesUpdateDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    revisionId: '77777777-7777-4777-8777-777777777777',
    revisionNumber: 2,
    effectiveLocalDate: effectiveLocalDate,
    version: version,
    rebuiltCount: 31,
    cancelledCount: 335,
    preservedCompletedCount: 1,
    changed: true,
  );
}

CancelRepeatingChoreSeriesRequest _seriesCancellationRequest() {
  return CancelRepeatingChoreSeriesRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
    )!,
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    expectedVersion: 1,
  );
}

RepeatingChoreSeriesCancellationDataRecord _seriesCancellationRecord({
  int version = 2,
}) {
  return RepeatingChoreSeriesCancellationDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    effectiveLocalDate: '2026-08-06',
    version: version,
    cancelledCount: 365,
    preservedCompletedCount: 1,
    changed: true,
  );
}

CancelRepeatingChoreSeriesFromOccurrenceRequest
_seriesFromOccurrenceCancellationRequest() {
  return CancelRepeatingChoreSeriesFromOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'fefefefe-fefe-4efe-8efe-fefefefefefe',
    )!,
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    effectiveOccurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 1,
  );
}

RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
_seriesFromOccurrenceCancellationRecord({
  int version = 2,
  int cancelledCount = 19,
  String? terminalRevisionId = '77777777-7777-4777-8777-777777777778',
  int? terminalRevisionNumber = 2,
}) {
  return RepeatingChoreSeriesFromOccurrenceCancellationDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    effectiveLocalDate: '2026-08-12',
    version: version,
    cancelledCount: cancelledCount,
    preservedCompletedCount: 2,
    terminalRevisionId: terminalRevisionId,
    terminalRevisionNumber: terminalRevisionNumber,
    changed: true,
  );
}

ResumeRepeatingChoreSeriesCancellationRequest
_seriesCancellationResumeRequest() {
  return ResumeRepeatingChoreSeriesCancellationRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'edededed-eded-4ded-8ded-edededededed',
    )!,
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    cancellationIdempotencyKey: ChoreCommandId.tryParse(
      'fefefefe-fefe-4efe-8efe-fefefefefefe',
    )!,
    expectedVersion: 2,
  );
}

RepeatingChoreSeriesCancellationResumeDataRecord
_seriesCancellationResumeRecord({
  int version = 3,
  int restoredCount = 19,
  String revisionId = '77777777-7777-4777-8777-777777777779',
  int revisionNumber = 3,
}) {
  return RepeatingChoreSeriesCancellationResumeDataRecord(
    householdId: _householdId.value,
    seriesId: '44444444-4444-4444-8444-444444444444',
    effectiveLocalDate: '2026-08-12',
    version: version,
    restoredCount: restoredCount,
    preservedCompletedCount: 2,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    changed: true,
  );
}

UpdateOneTimeChoreRequest _oneTimeUpdateRequest() {
  return OneTimeChoreUpdateDraft.tryCreate(
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    occurrenceId: _occurrenceId,
    expectedSeriesVersion: 1,
    expectedOccurrenceVersion: 1,
    title: 'Updated recycling',
    description: 'Use the blue bin',
    assigneeMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333334',
    )!,
    dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
    dueLocalTime: ChoreLocalTime.tryParse('18:30'),
  )!.withId(ChoreCommandId.tryParse('abababab-abab-4bab-8bab-abababababab')!);
}

OneTimeChoreUpdateDataRecord _oneTimeUpdateRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String revisionId = '77777777-7777-4777-8777-777777777778',
  int revisionNumber = 2,
  String dueLocalDate = '2026-08-07',
  String? dueLocalTime = '18:30',
  String? dueAt = '2026-08-07T09:30:00Z',
  String assigneeMemberId = '33333333-3333-4333-8333-333333333334',
  int seriesVersion = 2,
  int occurrenceVersion = 2,
}) {
  return OneTimeChoreUpdateDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    revisionId: revisionId,
    revisionNumber: revisionNumber,
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    assigneeMemberId: assigneeMemberId,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
    changed: true,
  );
}

DeleteOneTimeChoreRequest _oneTimeDeletionRequest() {
  return OneTimeChoreDeletionDraft.tryCreate(
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    occurrenceId: _occurrenceId,
    expectedSeriesVersion: 1,
    expectedOccurrenceVersion: 1,
  )!.withId(ChoreCommandId.tryParse('cdcdcdcd-cdcd-4dcd-8dcd-cdcdcdcdcdcd')!);
}

OneTimeChoreDeletionDataRecord _oneTimeDeletionRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String status = 'cancelled',
  int seriesVersion = 2,
  int occurrenceVersion = 2,
}) {
  return OneTimeChoreDeletionDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    occurrenceId: occurrenceId,
    status: status,
    seriesVersion: seriesVersion,
    occurrenceVersion: occurrenceVersion,
    changed: true,
  );
}

CreateRecurringChoreRequest _recurringRequest() {
  final ChoreLocalDate start = ChoreLocalDate.tryParse('2026-08-06')!;
  return CreateRecurringChoreRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    )!,
    householdId: _householdId,
    title: 'Take out recycling',
    description: 'Blue bin',
    assigneeMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333333',
    )!,
    startLocalDate: start,
    dueLocalTime: ChoreLocalTime.tryParse('19:30'),
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.daily,
      startLocalDate: start,
    ),
  );
}

RecurringChoreDataRecord _recurringRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  Map<String, Object?>? recurrenceRule,
  String materializedThrough = '2027-08-06',
  int materializedCount = 366,
}) {
  return RecurringChoreDataRecord(
    householdId: householdId,
    seriesId: seriesId,
    firstOccurrenceId: '55555555-5555-4555-8555-555555555555',
    recurrenceRule:
        recurrenceRule ??
        <String, Object?>{
          'frequency': 'daily',
          'interval': 1,
          'end': <String, Object?>{'type': 'never'},
        },
    materializedThrough: materializedThrough,
    materializedCount: materializedCount,
    created: true,
  );
}

SetChoreCompletionRequest _completionRequest({
  bool completed = true,
  int expectedVersion = 1,
}) {
  return SetChoreCompletionRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    )!,
    householdId: _householdId,
    occurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: expectedVersion,
    completed: completed,
  );
}

ChoreCompletionDataRecord _completionRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String status = 'completed',
  int version = 2,
  String? completedByMemberId = '33333333-3333-4333-8333-333333333333',
  String? completedAt = '2026-08-06T10:30:00Z',
}) {
  return ChoreCompletionDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    completedByMemberId: completedByMemberId,
    completedAt: completedAt,
    changed: true,
  );
}

SkipChoreOccurrenceRequest _skipRequest() {
  return SkipChoreOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    )!,
    householdId: _householdId,
    occurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 1,
  );
}

ChoreOccurrenceSkipDataRecord _skipRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String status = 'skipped',
  int version = 2,
}) {
  return ChoreOccurrenceSkipDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    changed: true,
  );
}

RestoreSkippedChoreOccurrenceRequest _restoreRequest() {
  return RestoreSkippedChoreOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    )!,
    householdId: _householdId,
    occurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 2,
  );
}

ChoreOccurrenceRestoreDataRecord _restoreRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String status = 'scheduled',
  int version = 3,
}) {
  return ChoreOccurrenceRestoreDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    status: status,
    version: version,
    changed: true,
  );
}

RescheduleChoreOccurrenceRequest _rescheduleRequest() {
  return RescheduleChoreOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    )!,
    householdId: _householdId,
    occurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 1,
    dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
    dueLocalTime: ChoreLocalTime.tryParse('18:30'),
  );
}

ChoreOccurrenceRescheduleDataRecord _rescheduleRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String dueLocalDate = '2026-08-07',
  String? dueLocalTime = '18:30',
  String? dueAt = '2026-08-07T09:30:00Z',
  String status = 'scheduled',
  int version = 2,
}) {
  return ChoreOccurrenceRescheduleDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    dueLocalDate: dueLocalDate,
    dueLocalTime: dueLocalTime,
    dueAt: dueAt,
    status: status,
    version: version,
    changed: true,
  );
}

ReassignChoreOccurrenceRequest _reassignmentRequest() {
  return ReassignChoreOccurrenceRequest(
    idempotencyKey: ChoreCommandId.tryParse(
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    )!,
    householdId: _householdId,
    occurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    expectedVersion: 1,
    assigneeMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333334',
    )!,
  );
}

ChoreOccurrenceReassignmentDataRecord _reassignmentRecord({
  String householdId = '22222222-2222-4222-8222-222222222222',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String assigneeMemberId = '33333333-3333-4333-8333-333333333334',
  String assigneeDisplayName = 'Sam',
  String status = 'scheduled',
  int version = 2,
}) {
  return ChoreOccurrenceReassignmentDataRecord(
    householdId: householdId,
    occurrenceId: occurrenceId,
    assigneeMemberId: assigneeMemberId,
    assigneeDisplayName: assigneeDisplayName,
    status: status,
    version: version,
    changed: true,
  );
}

final class _FakeChoreDataSource implements ChoreDataSource {
  _FakeChoreDataSource({
    required this.loadResult,
    this.activationProgressResult =
        const ChoreDataFailed<HouseholdActivationProgressDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.weeklyReportResult =
        const ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.listResult = const ChoreDataFailed<ChoreListPageDataRecord>(
      ChoreDataFailureKind.temporarilyUnavailable,
    ),
    this.occurrenceTargetResult =
        const ChoreDataFailed<ChoreOccurrenceDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.historyResult =
        const ChoreDataFailed<ChoreOccurrenceHistoryPageDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.deletedOneTimeChoresResult =
        const ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.completionResult = const ChoreDataFailed<ChoreCompletionDataRecord>(
      ChoreDataFailureKind.temporarilyUnavailable,
    ),
    this.oneTimeUpdateResult =
        const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.oneTimeDeletionResult =
        const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.oneTimeRestoreResult =
        const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.recurringResult = const ChoreDataFailed<RecurringChoreDataRecord>(
      ChoreDataFailureKind.temporarilyUnavailable,
    ),
    this.skipResult = const ChoreDataFailed<ChoreOccurrenceSkipDataRecord>(
      ChoreDataFailureKind.temporarilyUnavailable,
    ),
    this.restoreResult =
        const ChoreDataFailed<ChoreOccurrenceRestoreDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.rescheduleResult =
        const ChoreDataFailed<ChoreOccurrenceRescheduleDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.reassignmentResult =
        const ChoreDataFailed<ChoreOccurrenceReassignmentDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.seriesUpdateResult =
        const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.seriesFromOccurrenceUpdateResult =
        const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.seriesCancellationResult =
        const ChoreDataFailed<RepeatingChoreSeriesCancellationDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
    this.seriesFromOccurrenceCancellationResult =
        const ChoreDataFailed<
          RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
        >(ChoreDataFailureKind.temporarilyUnavailable),
    this.seriesCancellationResumeResult =
        const ChoreDataFailed<RepeatingChoreSeriesCancellationResumeDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
  });

  final ChoreDataResult<TodayChoresDataRecord> loadResult;
  final ChoreDataResult<HouseholdActivationProgressDataRecord>
  activationProgressResult;
  final ChoreDataResult<HouseholdWeeklyReportDataRecord> weeklyReportResult;
  final ChoreDataResult<ChoreListPageDataRecord> listResult;
  final ChoreDataResult<ChoreOccurrenceDataRecord> occurrenceTargetResult;
  final ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord> historyResult;
  final ChoreDataResult<DeletedOneTimeChorePageDataRecord>
  deletedOneTimeChoresResult;
  final ChoreDataResult<ChoreCompletionDataRecord> completionResult;
  final ChoreDataResult<OneTimeChoreUpdateDataRecord> oneTimeUpdateResult;
  final ChoreDataResult<OneTimeChoreDeletionDataRecord> oneTimeDeletionResult;
  final ChoreDataResult<OneTimeChoreRestoreDataRecord> oneTimeRestoreResult;
  final ChoreDataResult<RecurringChoreDataRecord> recurringResult;
  final ChoreDataResult<ChoreOccurrenceSkipDataRecord> skipResult;
  final ChoreDataResult<ChoreOccurrenceRestoreDataRecord> restoreResult;
  final ChoreDataResult<ChoreOccurrenceRescheduleDataRecord> rescheduleResult;
  final ChoreDataResult<ChoreOccurrenceReassignmentDataRecord>
  reassignmentResult;
  final ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>
  seriesUpdateResult;
  final ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>
  seriesFromOccurrenceUpdateResult;
  final ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord>
  seriesCancellationResult;
  final ChoreDataResult<
    RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
  >
  seriesFromOccurrenceCancellationResult;
  final ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>
  seriesCancellationResumeResult;

  @override
  Future<ChoreDataResult<TodayChoresDataRecord>> loadToday({
    required String householdId,
  }) async {
    return loadResult;
  }

  @override
  Future<ChoreDataResult<HouseholdActivationProgressDataRecord>>
  loadHouseholdActivationProgress({required String householdId}) async {
    return activationProgressResult;
  }

  @override
  Future<ChoreDataResult<HouseholdWeeklyReportDataRecord>>
  loadHouseholdWeeklyReport({
    required String householdId,
    required int weekOffset,
  }) async {
    return weeklyReportResult;
  }

  @override
  Future<ChoreDataResult<ChoreListPageDataRecord>> loadChoreList({
    required String householdId,
    required String view,
    required String? assigneeMemberId,
    required int limit,
    required String? afterCursor,
  }) async {
    return listResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> loadOccurrenceTarget({
    required String householdId,
    required String occurrenceId,
  }) async {
    return occurrenceTargetResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord>>
  loadOccurrenceHistory({
    required String householdId,
    required String occurrenceId,
    required int limit,
    required String? beforeOccurredAt,
    required String? beforeEntryId,
  }) async {
    return historyResult;
  }

  @override
  Future<ChoreDataResult<DeletedOneTimeChorePageDataRecord>>
  loadDeletedOneTimeChores({
    required String householdId,
    required int limit,
    required String? beforeCursor,
  }) async {
    return deletedOneTimeChoresResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> createOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    return const ChoreDataFailed<ChoreOccurrenceDataRecord>(
      ChoreDataFailureKind.temporarilyUnavailable,
    );
  }

  @override
  Future<ChoreDataResult<OneTimeChoreUpdateDataRecord>> updateOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    return oneTimeUpdateResult;
  }

  @override
  Future<ChoreDataResult<OneTimeChoreDeletionDataRecord>> deleteOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async {
    return oneTimeDeletionResult;
  }

  @override
  Future<ChoreDataResult<OneTimeChoreRestoreDataRecord>> restoreOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async {
    return oneTimeRestoreResult;
  }

  @override
  Future<ChoreDataResult<RecurringChoreDataRecord>> createRepeatingChore({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  }) async {
    return recurringResult;
  }

  @override
  Future<ChoreDataResult<ChoreCompletionDataRecord>> setCompletion({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required bool completed,
  }) async {
    return completionResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceSkipDataRecord>> skipOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) async {
    return skipResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceRestoreDataRecord>>
  restoreSkippedOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) async {
    return restoreResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceRescheduleDataRecord>>
  rescheduleOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) async {
    return rescheduleResult;
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceReassignmentDataRecord>>
  reassignOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String assigneeMemberId,
  }) async {
    return reassignmentResult;
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>>
  updateRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  }) async {
    return seriesUpdateResult;
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>>
  updateRepeatingSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
    required String title,
    required String? description,
    required String assigneeMemberId,
    required String? dueLocalTime,
    required Map<String, Object?> recurrenceRule,
  }) async {
    return seriesFromOccurrenceUpdateResult;
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord>>
  cancelRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async {
    return seriesCancellationResult;
  }

  @override
  Future<
    ChoreDataResult<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>
  >
  cancelRepeatingSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
  }) async {
    return seriesFromOccurrenceCancellationResult;
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>>
  resumeRepeatingSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  }) async {
    return seriesCancellationResumeResult;
  }
}
