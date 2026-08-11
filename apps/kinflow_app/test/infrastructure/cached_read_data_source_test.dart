import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/features/chores/data/repositories/provider_chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/infrastructure/cache/cached_chore_data_source.dart';
import 'package:kinflow_app/infrastructure/cache/cached_household_data_source.dart';

void main() {
  group('CachedHouseholdDataSource', () {
    test(
      'falls back to the exact cached active household on a transient error',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeHouseholdDataSource delegate = _FakeHouseholdDataSource(
          const ActiveHouseholdDataFound(
            ActiveHouseholdRecord(
              householdId: _householdId,
              memberId: _memberId,
            ),
          ),
        );
        final CachedHouseholdDataSource source = CachedHouseholdDataSource(
          delegate,
          cache,
        );

        expect(
          await source.loadActiveHousehold(),
          isA<ActiveHouseholdDataFound>(),
        );
        delegate.loadResult = const LoadActiveHouseholdDataFailed(
          HouseholdDataFailureKind.temporarilyUnavailable,
        );
        final LoadActiveHouseholdDataResult fallback = await source
            .loadActiveHousehold();

        expect(fallback, isA<ActiveHouseholdDataFound>());
        final ActiveHouseholdDataFound found =
            fallback as ActiveHouseholdDataFound;
        expect(found.record.householdId, _householdId);
        expect(found.record.memberId, _memberId);
        expect(found.cacheMetadata, cache.metadata);
      },
    );

    test(
      'clears stale household data and old chore slots on transitions',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await cache.write(
          ReadCacheSlot.activeHousehold,
          householdId: _householdId,
          payload: const <String, Object?>{
            'householdId': _householdId,
            'memberId': _memberId,
          },
        );
        await cache.write(
          ReadCacheSlot.choreList,
          householdId: _householdId,
          payload: const <Object?>['old-list'],
        );
        await cache.write(
          ReadCacheSlot.todayChores,
          householdId: _householdId,
          payload: const <Object?>['old-today'],
        );
        await cache.write(
          ReadCacheSlot.todayCalendar,
          householdId: _householdId,
          payload: const <Object?>['old-calendar'],
        );
        final _FakeHouseholdDataSource delegate = _FakeHouseholdDataSource(
          const ActiveHouseholdDataFound(
            ActiveHouseholdRecord(
              householdId: _otherHouseholdId,
              memberId: _memberId,
            ),
          ),
        );
        final CachedHouseholdDataSource source = CachedHouseholdDataSource(
          delegate,
          cache,
        );

        await source.loadActiveHousehold();

        expect(cache.records.keys, <ReadCacheSlot>[
          ReadCacheSlot.activeHousehold,
        ]);
        expect(
          cache.records[ReadCacheSlot.activeHousehold]?.householdId,
          _otherHouseholdId,
        );

        delegate.loadResult = const ActiveHouseholdDataAbsent();
        await source.loadActiveHousehold();
        expect(cache.records, isEmpty);
        expect(cache.clearCount, 1);
      },
    );

    test(
      'fails closed when an authoritative household cannot replace cache',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache()
          ..writeSucceeds = false;
        final CachedHouseholdDataSource source = CachedHouseholdDataSource(
          _FakeHouseholdDataSource(
            const ActiveHouseholdDataFound(
              ActiveHouseholdRecord(
                householdId: _householdId,
                memberId: _memberId,
              ),
            ),
          ),
          cache,
        );

        final LoadActiveHouseholdDataResult result = await source
            .loadActiveHousehold();

        expect(result, isA<LoadActiveHouseholdDataFailed>());
        expect(
          (result as LoadActiveHouseholdDataFailed).kind,
          HouseholdDataFailureKind.unknown,
        );
      },
    );

    test(
      'fails closed when authoritative absence cannot purge cache',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await cache.write(
          ReadCacheSlot.activeHousehold,
          householdId: _householdId,
          payload: const <String, Object?>{
            'householdId': _householdId,
            'memberId': _memberId,
          },
        );
        cache.clearSucceeds = false;
        final CachedHouseholdDataSource source = CachedHouseholdDataSource(
          _FakeHouseholdDataSource(const ActiveHouseholdDataAbsent()),
          cache,
        );

        final LoadActiveHouseholdDataResult result = await source
            .loadActiveHousehold();

        expect(result, isA<LoadActiveHouseholdDataFailed>());
        expect(cache.records, contains(ReadCacheSlot.activeHousehold));
      },
    );
  });

  group('CachedChoreDataSource', () {
    test(
      'delegates activation progress without reading or writing cache',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource()
          ..activationProgressResult =
              const ChoreDataSucceeded<HouseholdActivationProgressDataRecord>(
                HouseholdActivationProgressDataRecord(
                  householdId: _householdId,
                  adultParticipantProgress: 2,
                  choreCreationProgress: 3,
                  distinctAdultCompleterProgress: 1,
                  returnAfterFirstDayReached: true,
                ),
              );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        final ChoreDataResult<HouseholdActivationProgressDataRecord> result =
            await source.loadHouseholdActivationProgress(
              householdId: _householdId,
            );

        expect(
          result,
          isA<ChoreDataSucceeded<HouseholdActivationProgressDataRecord>>(),
        );
        expect(delegate.activationProgressHouseholds, <String>[_householdId]);
        expect(cache.records, isEmpty);
        expect(cache.readCount, 0);
        expect(cache.deleteCount, 0);
        expect(cache.clearCount, 0);
      },
    );

    test(
      'delegates weekly reports without creating a persistent fallback',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          weeklyReportResult:
              ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>(
                HouseholdWeeklyReportDataRecord(
                  householdId: _householdId,
                  householdTimezone: 'Asia/Seoul',
                  generatedAt: '2026-08-10T01:00:00Z',
                  weekOffset: 0,
                  weekStart: '2026-08-03',
                  weekEnd: '2026-08-09',
                  dueCount: 0,
                  completedCount: 0,
                  completedByWeekEndCount: 0,
                  completedAfterWeekEndCount: 0,
                  openCount: 0,
                  skippedCount: 0,
                  viewerCompletedCount: 0,
                  members: <HouseholdWeeklyReportMemberDataRecord>[],
                  otherMemberCompletedCount: 0,
                  memberBreakdownTruncated: false,
                ),
              ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        final ChoreDataResult<HouseholdWeeklyReportDataRecord> result =
            await source.loadHouseholdWeeklyReport(
              householdId: _householdId,
              weekOffset: 0,
            );

        expect(
          result,
          isA<ChoreDataSucceeded<HouseholdWeeklyReportDataRecord>>(),
        );
        expect(delegate.weeklyReportRequests, <Object>[
          (householdId: _householdId, weekOffset: 0),
        ]);
        expect(cache.records, isEmpty);
        expect(cache.readCount, 0);
        expect(cache.deleteCount, 0);
        expect(cache.clearCount, 0);
      },
    );

    test(
      'delegates occurrence target failures without stale cache fallback',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await cache.write(
          ReadCacheSlot.choreList,
          householdId: _householdId,
          payload: const <Object?>['stale-list'],
        );
        final _FakeChoreDataSource delegate = _FakeChoreDataSource()
          ..occurrenceTargetResult =
              const ChoreDataFailed<ChoreOccurrenceDataRecord>(
                ChoreDataFailureKind.temporarilyUnavailable,
              );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        final ChoreDataResult<ChoreOccurrenceDataRecord> result = await source
            .loadOccurrenceTarget(
              householdId: _householdId,
              occurrenceId: '55555555-5555-4555-8555-555555555555',
            );

        expect(result, isA<ChoreDataFailed<ChoreOccurrenceDataRecord>>());
        expect(delegate.occurrenceTargetLoadCount, 1);
        expect(cache.readCount, 0);
        expect(cache.records, contains(ReadCacheSlot.choreList));
      },
    );

    test(
      'serves a strict cached Today snapshot on a transient error',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource()
          ..todayResult = ChoreDataSucceeded<TodayChoresDataRecord>(
            _todayRecord(),
          );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );
        await source.loadToday(householdId: _householdId);
        delegate.todayResult = const ChoreDataFailed<TodayChoresDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        );

        final ChoreDataResult<TodayChoresDataRecord> fallback = await source
            .loadToday(householdId: _householdId);

        expect(fallback, isA<ChoreDataSucceeded<TodayChoresDataRecord>>());
        final ChoreDataSucceeded<TodayChoresDataRecord> succeeded =
            fallback as ChoreDataSucceeded<TodayChoresDataRecord>;
        expect(succeeded.value.occurrences.single.title, 'Today recycling');
        expect(succeeded.cacheMetadata, cache.metadata);
      },
    );

    test(
      'serves a strict cached first page with its next cursor metadata',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          listResult: ChoreDataSucceeded<ChoreListPageDataRecord>(
            _choreListPage(hasMore: true, pageCursor: '7b7d'),
          ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );
        await source.loadChoreList(
          householdId: _householdId,
          view: 'upcoming',
          assigneeMemberId: null,
          limit: 1,
          afterCursor: null,
        );
        delegate.listResult = const ChoreDataFailed<ChoreListPageDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        );

        final ChoreDataResult<ChoreListPageDataRecord> fallback = await source
            .loadChoreList(
              householdId: _householdId,
              view: 'upcoming',
              assigneeMemberId: null,
              limit: 1,
              afterCursor: null,
            );

        expect(fallback, isA<ChoreDataSucceeded<ChoreListPageDataRecord>>());
        final ChoreDataSucceeded<ChoreListPageDataRecord> succeeded =
            fallback as ChoreDataSucceeded<ChoreListPageDataRecord>;
        expect(succeeded.value.occurrences.single.title, 'Take out recycling');
        expect(succeeded.value.hasMore, isTrue);
        expect(succeeded.value.pageCursor, '7b7d');
        expect(succeeded.cacheMetadata, cache.metadata);
      },
    );

    test('keeps a valid cache when a different query misses offline', () async {
      final _MemoryReadCache cache = _MemoryReadCache();
      final _FakeChoreDataSource delegate = _FakeChoreDataSource(
        listResult: ChoreDataSucceeded<ChoreListPageDataRecord>(
          _choreListPage(),
        ),
      );
      final CachedChoreDataSource source = CachedChoreDataSource(
        delegate,
        cache,
      );
      await source.loadChoreList(
        householdId: _householdId,
        view: 'upcoming',
        assigneeMemberId: null,
        limit: 1,
        afterCursor: null,
      );
      delegate.listResult = const ChoreDataFailed<ChoreListPageDataRecord>(
        ChoreDataFailureKind.temporarilyUnavailable,
      );
      cache.deleteCount = 0;

      final ChoreDataResult<ChoreListPageDataRecord> result = await source
          .loadChoreList(
            householdId: _householdId,
            view: 'today',
            assigneeMemberId: null,
            limit: 1,
            afterCursor: null,
          );

      expect(result, isA<ChoreDataFailed<ChoreListPageDataRecord>>());
      expect(cache.records, contains(ReadCacheSlot.choreList));
      expect(cache.deleteCount, 0);
    });

    test('never uses first-page cache for a continuation request', () async {
      final _MemoryReadCache cache = _MemoryReadCache();
      await cache.write(
        ReadCacheSlot.choreList,
        householdId: _householdId,
        payload: const <Object?>['cached-first-page'],
      );
      final _FakeChoreDataSource delegate = _FakeChoreDataSource(
        listResult: const ChoreDataFailed<ChoreListPageDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        ),
      );
      final CachedChoreDataSource source = CachedChoreDataSource(
        delegate,
        cache,
      );

      final ChoreDataResult<ChoreListPageDataRecord> result = await source
          .loadChoreList(
            householdId: _householdId,
            view: 'upcoming',
            assigneeMemberId: null,
            limit: 1,
            afterCursor: '7b7d',
          );

      expect(result, isA<ChoreDataFailed<ChoreListPageDataRecord>>());
      expect(cache.readCount, 0);
      expect(cache.records, contains(ReadCacheSlot.choreList));
    });

    test('trash reads delegate directly without persistent fallback', () async {
      final _MemoryReadCache cache = _MemoryReadCache();
      await _seedChoreReads(cache);
      cache.deleteCount = 0;
      final _FakeChoreDataSource delegate = _FakeChoreDataSource(
        deletedOneTimeChoresResult:
            ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>(
              DeletedOneTimeChorePageDataRecord(
                householdId: _householdId,
                householdTimezone: 'Asia/Seoul',
                generatedAt: '2026-08-09T01:00:00.000Z',
                pageLimit: 30,
                hasMore: false,
                pageCursor: null,
                items: const <DeletedOneTimeChoreDataRecord>[],
              ),
            ),
      );
      final CachedChoreDataSource source = CachedChoreDataSource(
        delegate,
        cache,
      );

      final ChoreDataResult<DeletedOneTimeChorePageDataRecord> result =
          await source.loadDeletedOneTimeChores(
            householdId: _householdId,
            limit: 30,
            beforeCursor: null,
          );

      expect(
        result,
        isA<ChoreDataSucceeded<DeletedOneTimeChorePageDataRecord>>(),
      );
      expect(delegate.deletedOneTimeChoresLoadCount, 1);
      expect(
        cache.records.keys,
        containsAll(
          ReadCacheSlot.values.where(
            (ReadCacheSlot slot) =>
                slot == ReadCacheSlot.choreList ||
                slot == ReadCacheSlot.todayChores,
          ),
        ),
      );
      expect(cache.readCount, 0);
      expect(cache.deleteCount, 0);
    });

    test(
      'deletes corrupt fallback payloads and clears on auth failures',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await cache.write(
          ReadCacheSlot.choreList,
          householdId: _householdId,
          payload: const <Object?>[
            <String, Object?>{
              'household_id': _householdId,
              'list_view': 'upcoming',
              'assignee_filter_member_id': null,
              'page_limit': 1,
            },
          ],
        );
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          listResult: const ChoreDataFailed<ChoreListPageDataRecord>(
            ChoreDataFailureKind.temporarilyUnavailable,
          ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        await source.loadChoreList(
          householdId: _householdId,
          view: 'upcoming',
          assigneeMemberId: null,
          limit: 1,
          afterCursor: null,
        );
        expect(cache.records, isNot(contains(ReadCacheSlot.choreList)));

        await cache.write(
          ReadCacheSlot.todayChores,
          householdId: _householdId,
          payload: const <Object?>['cached-today'],
        );
        delegate.todayResult = const ChoreDataFailed<TodayChoresDataRecord>(
          ChoreDataFailureKind.unauthenticated,
        );
        await source.loadToday(householdId: _householdId);
        expect(cache.records, isEmpty);
        expect(cache.clearCount, 1);
      },
    );

    test('invalidates both chore views after a successful mutation', () async {
      final _MemoryReadCache cache = _MemoryReadCache();
      await cache.write(
        ReadCacheSlot.choreList,
        householdId: _householdId,
        payload: const <Object?>['list'],
      );
      await cache.write(
        ReadCacheSlot.todayChores,
        householdId: _householdId,
        payload: const <Object?>['today'],
      );
      final _FakeChoreDataSource delegate = _FakeChoreDataSource(
        completionResult: const ChoreDataSucceeded<ChoreCompletionDataRecord>(
          ChoreCompletionDataRecord(
            householdId: _householdId,
            occurrenceId: _occurrenceId,
            status: 'completed',
            version: 2,
            completedByMemberId: _memberId,
            completedAt: '2026-08-08T01:01:00.000Z',
            changed: true,
          ),
        ),
      );
      final CachedChoreDataSource source = CachedChoreDataSource(
        delegate,
        cache,
      );

      await source.setCompletion(
        idempotencyKey: '77777777-7777-4777-8777-777777777777',
        householdId: _householdId,
        occurrenceId: _occurrenceId,
        expectedVersion: 1,
        completed: true,
      );

      expect(cache.records, isEmpty);
      expect(cache.deleteCount, 2);
    });

    test(
      'forwards the selected occurrence and invalidates reads after series edit',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await _seedChoreReads(cache);
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          seriesFromOccurrenceUpdateResult:
              const ChoreDataSucceeded<RepeatingChoreSeriesUpdateDataRecord>(
                RepeatingChoreSeriesUpdateDataRecord(
                  householdId: _householdId,
                  seriesId: _seriesId,
                  revisionId: '77777777-7777-4777-8777-777777777777',
                  revisionNumber: 2,
                  effectiveLocalDate: '2026-08-12',
                  version: 2,
                  rebuiltCount: 47,
                  cancelledCount: 307,
                  preservedCompletedCount: 1,
                  changed: true,
                ),
              ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        await source.updateRepeatingSeriesFromOccurrence(
          idempotencyKey: '77777777-7777-4777-8777-777777777777',
          householdId: _householdId,
          seriesId: _seriesId,
          effectiveOccurrenceId: _occurrenceId,
          expectedVersion: 1,
          title: 'Future recycling',
          description: 'Blue bin',
          assigneeMemberId: _memberId,
          dueLocalTime: '19:30:00',
          recurrenceRule: const <String, Object?>{
            'frequency': 'daily',
            'interval': 1,
            'end': <String, Object?>{'type': 'never'},
          },
        );

        expect(delegate.seriesFromOccurrenceIds, <String>[_occurrenceId]);
        expect(cache.records, isEmpty);
        expect(cache.deleteCount, 2);
      },
    );

    test(
      'forwards selected cancellation boundary and invalidates chore reads',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        await _seedChoreReads(cache);
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          seriesFromOccurrenceCancellationResult:
              const ChoreDataSucceeded<
                RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
              >(
                RepeatingChoreSeriesFromOccurrenceCancellationDataRecord(
                  householdId: _householdId,
                  seriesId: _seriesId,
                  effectiveLocalDate: '2026-08-12',
                  version: 2,
                  cancelledCount: 19,
                  preservedCompletedCount: 2,
                  terminalRevisionId: '77777777-7777-4777-8777-777777777778',
                  terminalRevisionNumber: 2,
                  changed: true,
                ),
              ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );

        await source.cancelRepeatingSeriesFromOccurrence(
          idempotencyKey: '77777777-7777-4777-8777-777777777777',
          householdId: _householdId,
          seriesId: _seriesId,
          effectiveOccurrenceId: _occurrenceId,
          expectedVersion: 1,
        );

        expect(delegate.seriesFromOccurrenceCancellationIds, <String>[
          _occurrenceId,
        ]);
        expect(cache.records, isEmpty);
        expect(cache.deleteCount, 2);
      },
    );

    test('forwards cancellation Undo and invalidates chore reads', () async {
      final _MemoryReadCache cache = _MemoryReadCache();
      await _seedChoreReads(cache);
      final _FakeChoreDataSource delegate = _FakeChoreDataSource(
        seriesCancellationResumeResult:
            const ChoreDataSucceeded<
              RepeatingChoreSeriesCancellationResumeDataRecord
            >(
              RepeatingChoreSeriesCancellationResumeDataRecord(
                householdId: _householdId,
                seriesId: _seriesId,
                effectiveLocalDate: '2026-08-12',
                version: 3,
                restoredCount: 19,
                preservedCompletedCount: 2,
                revisionId: '77777777-7777-4777-8777-777777777779',
                revisionNumber: 3,
                changed: true,
              ),
            ),
      );
      final CachedChoreDataSource source = CachedChoreDataSource(
        delegate,
        cache,
      );

      await source.resumeRepeatingSeriesCancellation(
        idempotencyKey: '88888888-8888-4888-8888-888888888888',
        householdId: _householdId,
        seriesId: _seriesId,
        cancellationIdempotencyKey: '77777777-7777-4777-8777-777777777777',
        expectedVersion: 2,
      );

      expect(delegate.seriesCancellationResumeRequests, <String>[
        '77777777-7777-4777-8777-777777777777:2',
      ]);
      expect(cache.records, isEmpty);
      expect(cache.deleteCount, 2);
    });

    test(
      'invalidates reads after one-time update, deletion, and restore',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          oneTimeUpdateResult:
              const ChoreDataSucceeded<OneTimeChoreUpdateDataRecord>(
                OneTimeChoreUpdateDataRecord(
                  householdId: _householdId,
                  seriesId: _seriesId,
                  occurrenceId: _occurrenceId,
                  revisionId: '77777777-7777-4777-8777-777777777777',
                  revisionNumber: 2,
                  dueLocalDate: '2026-08-09',
                  dueLocalTime: null,
                  dueAt: null,
                  assigneeMemberId: _memberId,
                  seriesVersion: 2,
                  occurrenceVersion: 2,
                  changed: true,
                ),
              ),
          oneTimeDeletionResult:
              const ChoreDataSucceeded<OneTimeChoreDeletionDataRecord>(
                OneTimeChoreDeletionDataRecord(
                  householdId: _householdId,
                  seriesId: _seriesId,
                  occurrenceId: _occurrenceId,
                  status: 'cancelled',
                  seriesVersion: 3,
                  occurrenceVersion: 3,
                  changed: true,
                ),
              ),
          oneTimeRestoreResult:
              const ChoreDataSucceeded<OneTimeChoreRestoreDataRecord>(
                OneTimeChoreRestoreDataRecord(
                  householdId: _householdId,
                  seriesId: _seriesId,
                  occurrenceId: _occurrenceId,
                  status: 'scheduled',
                  seriesVersion: 4,
                  occurrenceVersion: 4,
                  changed: true,
                ),
              ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );
        await _seedChoreReads(cache);

        await source.updateOneTimeChore(
          idempotencyKey: '77777777-7777-4777-8777-777777777777',
          householdId: _householdId,
          seriesId: _seriesId,
          occurrenceId: _occurrenceId,
          expectedSeriesVersion: 1,
          expectedOccurrenceVersion: 1,
          title: 'Updated recycling',
          description: null,
          assigneeMemberId: _memberId,
          dueLocalDate: '2026-08-09',
          dueLocalTime: null,
        );

        expect(cache.records, isEmpty);
        expect(cache.deleteCount, 2);
        await _seedChoreReads(cache);

        await source.deleteOneTimeChore(
          idempotencyKey: '88888888-8888-4888-8888-888888888888',
          householdId: _householdId,
          seriesId: _seriesId,
          occurrenceId: _occurrenceId,
          expectedSeriesVersion: 2,
          expectedOccurrenceVersion: 2,
        );

        expect(cache.records, isEmpty);
        expect(cache.deleteCount, 4);
        await _seedChoreReads(cache);

        await source.restoreOneTimeChore(
          idempotencyKey: '99999999-9999-4999-8999-999999999999',
          householdId: _householdId,
          seriesId: _seriesId,
          occurrenceId: _occurrenceId,
          expectedSeriesVersion: 3,
          expectedOccurrenceVersion: 3,
        );

        expect(cache.records, isEmpty);
        expect(cache.deleteCount, 6);
      },
    );

    test(
      'repository preserves cache metadata after strict domain mapping',
      () async {
        final _MemoryReadCache cache = _MemoryReadCache();
        final _FakeChoreDataSource delegate = _FakeChoreDataSource(
          listResult: ChoreDataSucceeded<ChoreListPageDataRecord>(
            _choreListPage(),
          ),
        );
        final CachedChoreDataSource source = CachedChoreDataSource(
          delegate,
          cache,
        );
        final ProviderChoreRepository repository = ProviderChoreRepository(
          source,
        );
        final ChoreListRequest request = ChoreListRequest.tryCreate(
          householdId: HouseholdId.tryParse(_householdId)!,
          view: ChoreListView.upcoming,
          limit: 1,
        )!;
        await repository.loadChoreList(request);
        delegate.listResult = const ChoreDataFailed<ChoreListPageDataRecord>(
          ChoreDataFailureKind.temporarilyUnavailable,
        );

        final LoadTodayChoresResult result = await repository.loadChoreList(
          request,
        );

        expect(result, isA<TodayChoresLoaded>());
        final TodayChoresLoaded loaded = result as TodayChoresLoaded;
        expect(loaded.cacheMetadata, cache.metadata);
        expect(loaded.today.occurrences.single.id.value, _occurrenceId);
      },
    );
  });
}

const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _otherHouseholdId = '99999999-9999-4999-8999-999999999999';
const String _memberId = '33333333-3333-4333-8333-333333333333';
const String _seriesId = '44444444-4444-4444-8444-444444444444';
const String _occurrenceId = '55555555-5555-4555-8555-555555555555';

Future<void> _seedChoreReads(_MemoryReadCache cache) async {
  await cache.write(
    ReadCacheSlot.choreList,
    householdId: _householdId,
    payload: const <Object?>['list'],
  );
  await cache.write(
    ReadCacheSlot.todayChores,
    householdId: _householdId,
    payload: const <Object?>['today'],
  );
}

TodayChoresDataRecord _todayRecord() {
  return TodayChoresDataRecord(
    householdId: _householdId,
    householdTimezone: 'Asia/Seoul',
    householdLocalDate: '2026-08-08',
    occurrences: const <ChoreOccurrenceDataRecord>[
      ChoreOccurrenceDataRecord(
        householdId: _householdId,
        seriesId: _seriesId,
        occurrenceId: _occurrenceId,
        title: 'Today recycling',
        description: null,
        assigneeMemberId: _memberId,
        assigneeDisplayName: 'Alex',
        dueLocalDate: '2026-08-08',
        dueLocalTime: null,
        dueAt: null,
        status: 'scheduled',
        version: 1,
        seriesVersion: 1,
        seriesDefaultAssigneeMemberId: _memberId,
      ),
    ],
  );
}

ChoreListPageDataRecord _choreListPage({
  bool hasMore = false,
  String? pageCursor,
}) {
  return ChoreListPageDataRecord(
    householdId: _householdId,
    householdTimezone: 'Asia/Seoul',
    householdLocalDate: '2026-08-08',
    generatedAt: '2026-08-08T01:00:00.000Z',
    listView: 'upcoming',
    assigneeFilterMemberId: null,
    pageLimit: 1,
    hasMore: hasMore,
    pageCursor: pageCursor,
    occurrences: <ChoreOccurrenceDataRecord>[
      const ChoreOccurrenceDataRecord(
        householdId: _householdId,
        seriesId: _seriesId,
        occurrenceId: _occurrenceId,
        title: 'Take out recycling',
        description: null,
        assigneeMemberId: _memberId,
        assigneeDisplayName: 'Alex',
        dueLocalDate: '2026-08-09',
        dueLocalTime: '08:00:00',
        dueAt: '2026-08-08T23:00:00.000Z',
        status: 'scheduled',
        version: 1,
        seriesVersion: 1,
        seriesDefaultAssigneeMemberId: _memberId,
      ),
    ],
  );
}

final class _MemoryReadCache implements ReadCache {
  _MemoryReadCache()
    : metadata = ReadCacheMetadata(
        validatedAt: DateTime.parse('2026-08-08T01:00:00.000Z'),
        expiresAt: DateTime.parse('2026-08-08T03:00:00.000Z'),
      );

  final ReadCacheMetadata metadata;
  final Map<ReadCacheSlot, ReadCacheRecord> records =
      <ReadCacheSlot, ReadCacheRecord>{};
  var readCount = 0;
  var deleteCount = 0;
  var clearCount = 0;
  var writeSucceeds = true;
  var clearSucceeds = true;

  @override
  Future<ReadCacheRecord?> read(
    ReadCacheSlot slot, {
    String? expectedHouseholdId,
  }) async {
    readCount += 1;
    final ReadCacheRecord? record = records[slot];
    if (record != null &&
        expectedHouseholdId != null &&
        record.householdId != expectedHouseholdId) {
      records.remove(slot);
      deleteCount += 1;
      return null;
    }
    return record;
  }

  @override
  Future<bool> write(
    ReadCacheSlot slot, {
    required String householdId,
    required Object? payload,
    DateTime? validatedAt,
  }) async {
    if (!writeSucceeds) {
      return false;
    }
    records[slot] = ReadCacheRecord(
      householdId: householdId,
      payload: payload,
      metadata: validatedAt == null
          ? metadata
          : ReadCacheMetadata(
              validatedAt: validatedAt,
              expiresAt: validatedAt.add(const Duration(hours: 2)),
            ),
    );
    return true;
  }

  @override
  Future<bool> delete(ReadCacheSlot slot) async {
    deleteCount += 1;
    records.remove(slot);
    return true;
  }

  @override
  Future<bool> clear() async {
    clearCount += 1;
    if (!clearSucceeds) {
      return false;
    }
    records.clear();
    return true;
  }
}

final class _FakeHouseholdDataSource implements HouseholdDataSource {
  _FakeHouseholdDataSource(this.loadResult);

  LoadActiveHouseholdDataResult loadResult;

  @override
  Future<LoadActiveHouseholdDataResult> loadActiveHousehold() async =>
      loadResult;

  @override
  Future<CreateFirstHouseholdDataResult> createFirstHousehold({
    required String idempotencyKey,
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) async =>
      const CreateFirstHouseholdDataFailed(HouseholdDataFailureKind.unknown);
}

final class _FakeChoreDataSource implements ChoreDataSource {
  _FakeChoreDataSource({
    this.listResult = const ChoreDataFailed<ChoreListPageDataRecord>(
      ChoreDataFailureKind.unknown,
    ),
    this.completionResult = const ChoreDataFailed<ChoreCompletionDataRecord>(
      ChoreDataFailureKind.unknown,
    ),
    this.oneTimeUpdateResult =
        const ChoreDataFailed<OneTimeChoreUpdateDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.oneTimeDeletionResult =
        const ChoreDataFailed<OneTimeChoreDeletionDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.deletedOneTimeChoresResult =
        const ChoreDataFailed<DeletedOneTimeChorePageDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.oneTimeRestoreResult =
        const ChoreDataFailed<OneTimeChoreRestoreDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.weeklyReportResult =
        const ChoreDataFailed<HouseholdWeeklyReportDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.seriesFromOccurrenceUpdateResult =
        const ChoreDataFailed<RepeatingChoreSeriesUpdateDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
    this.seriesFromOccurrenceCancellationResult =
        const ChoreDataFailed<
          RepeatingChoreSeriesFromOccurrenceCancellationDataRecord
        >(ChoreDataFailureKind.unknown),
    this.seriesCancellationResumeResult =
        const ChoreDataFailed<RepeatingChoreSeriesCancellationResumeDataRecord>(
          ChoreDataFailureKind.unknown,
        ),
  });

  ChoreDataResult<TodayChoresDataRecord> todayResult =
      const ChoreDataFailed<TodayChoresDataRecord>(
        ChoreDataFailureKind.unknown,
      );
  ChoreDataResult<HouseholdActivationProgressDataRecord>
  activationProgressResult =
      const ChoreDataFailed<HouseholdActivationProgressDataRecord>(
        ChoreDataFailureKind.unknown,
      );
  final List<String> activationProgressHouseholds = <String>[];
  ChoreDataResult<HouseholdWeeklyReportDataRecord> weeklyReportResult;
  final List<({String householdId, int weekOffset})> weeklyReportRequests =
      <({String householdId, int weekOffset})>[];
  ChoreDataResult<ChoreListPageDataRecord> listResult;
  ChoreDataResult<ChoreOccurrenceDataRecord> occurrenceTargetResult =
      const ChoreDataFailed<ChoreOccurrenceDataRecord>(
        ChoreDataFailureKind.unknown,
      );
  ChoreDataResult<ChoreCompletionDataRecord> completionResult;
  ChoreDataResult<OneTimeChoreUpdateDataRecord> oneTimeUpdateResult;
  ChoreDataResult<OneTimeChoreDeletionDataRecord> oneTimeDeletionResult;
  ChoreDataResult<DeletedOneTimeChorePageDataRecord> deletedOneTimeChoresResult;
  ChoreDataResult<OneTimeChoreRestoreDataRecord> oneTimeRestoreResult;
  ChoreDataResult<RepeatingChoreSeriesUpdateDataRecord>
  seriesFromOccurrenceUpdateResult;
  final List<String> seriesFromOccurrenceIds = <String>[];
  ChoreDataResult<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>
  seriesFromOccurrenceCancellationResult;
  final List<String> seriesFromOccurrenceCancellationIds = <String>[];
  ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>
  seriesCancellationResumeResult;
  final List<String> seriesCancellationResumeRequests = <String>[];
  var deletedOneTimeChoresLoadCount = 0;
  var occurrenceTargetLoadCount = 0;

  @override
  Future<ChoreDataResult<TodayChoresDataRecord>> loadToday({
    required String householdId,
  }) async => todayResult;

  @override
  Future<ChoreDataResult<HouseholdActivationProgressDataRecord>>
  loadHouseholdActivationProgress({required String householdId}) async {
    activationProgressHouseholds.add(householdId);
    return activationProgressResult;
  }

  @override
  Future<ChoreDataResult<HouseholdWeeklyReportDataRecord>>
  loadHouseholdWeeklyReport({
    required String householdId,
    required int weekOffset,
  }) async {
    weeklyReportRequests.add((
      householdId: householdId,
      weekOffset: weekOffset,
    ));
    return weeklyReportResult;
  }

  @override
  Future<ChoreDataResult<ChoreListPageDataRecord>> loadChoreList({
    required String householdId,
    required String view,
    required String? assigneeMemberId,
    required int limit,
    required String? afterCursor,
  }) async => listResult;

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> loadOccurrenceTarget({
    required String householdId,
    required String occurrenceId,
  }) async {
    occurrenceTargetLoadCount += 1;
    return occurrenceTargetResult;
  }

  @override
  Future<ChoreDataResult<DeletedOneTimeChorePageDataRecord>>
  loadDeletedOneTimeChores({
    required String householdId,
    required int limit,
    required String? beforeCursor,
  }) async {
    deletedOneTimeChoresLoadCount += 1;
    return deletedOneTimeChoresResult;
  }

  @override
  Future<ChoreDataResult<ChoreCompletionDataRecord>> setCompletion({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required bool completed,
  }) async => completionResult;

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
  }) async => oneTimeUpdateResult;

  @override
  Future<ChoreDataResult<OneTimeChoreDeletionDataRecord>> deleteOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async => oneTimeDeletionResult;

  @override
  Future<ChoreDataResult<OneTimeChoreRestoreDataRecord>> restoreOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) async => oneTimeRestoreResult;

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
    seriesFromOccurrenceIds.add(effectiveOccurrenceId);
    return seriesFromOccurrenceUpdateResult;
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
    seriesFromOccurrenceCancellationIds.add(effectiveOccurrenceId);
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
    seriesCancellationResumeRequests.add(
      '$cancellationIdempotencyKey:$expectedVersion',
    );
    return seriesCancellationResumeResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('${invocation.memberName} is not used by this test');
  }
}
