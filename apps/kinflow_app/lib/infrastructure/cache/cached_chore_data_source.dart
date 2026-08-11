import 'package:kinflow_app/features/chores/data/datasources/chore_data_source.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_chore_data_source.dart';

final class CachedChoreDataSource implements ChoreDataSource {
  const CachedChoreDataSource(this._delegate, this._cache);

  final ChoreDataSource _delegate;
  final ReadCache _cache;

  @override
  Future<ChoreDataResult<TodayChoresDataRecord>> loadToday({
    required String householdId,
  }) async {
    final ChoreDataResult<TodayChoresDataRecord> result = await _delegate
        .loadToday(householdId: householdId);
    switch (result) {
      case ChoreDataSucceeded<TodayChoresDataRecord>(:final value):
        await _cache.write(
          ReadCacheSlot.todayChores,
          householdId: householdId,
          payload: _todayPayload(value),
        );
        return result;
      case ChoreDataFailed<TodayChoresDataRecord>(
        kind: ChoreDataFailureKind.temporarilyUnavailable,
      ):
        final ReadCacheRecord? cached = await _cache.read(
          ReadCacheSlot.todayChores,
          expectedHouseholdId: householdId,
        );
        final TodayChoresDataRecord? value = todayChoresRecordFromPayload(
          cached?.payload,
        );
        if (cached == null ||
            value == null ||
            value.householdId != householdId) {
          if (cached != null) {
            await _cache.delete(ReadCacheSlot.todayChores);
          }
          return result;
        }
        return ChoreDataSucceeded<TodayChoresDataRecord>(
          value,
          cacheMetadata: cached.metadata,
        );
      case ChoreDataFailed<TodayChoresDataRecord>(:final kind):
        await _handleAuthoritativeFailure(kind, ReadCacheSlot.todayChores);
        return result;
    }
  }

  @override
  Future<ChoreDataResult<HouseholdActivationProgressDataRecord>>
  loadHouseholdActivationProgress({required String householdId}) {
    return _delegate.loadHouseholdActivationProgress(householdId: householdId);
  }

  @override
  Future<ChoreDataResult<HouseholdWeeklyReportDataRecord>>
  loadHouseholdWeeklyReport({
    required String householdId,
    required int weekOffset,
  }) {
    return _delegate.loadHouseholdWeeklyReport(
      householdId: householdId,
      weekOffset: weekOffset,
    );
  }

  @override
  Future<ChoreDataResult<ChoreListPageDataRecord>> loadChoreList({
    required String householdId,
    required String view,
    required String? assigneeMemberId,
    required int limit,
    required String? afterCursor,
  }) async {
    final ChoreDataResult<ChoreListPageDataRecord> result = await _delegate
        .loadChoreList(
          householdId: householdId,
          view: view,
          assigneeMemberId: assigneeMemberId,
          limit: limit,
          afterCursor: afterCursor,
        );
    switch (result) {
      case ChoreDataSucceeded<ChoreListPageDataRecord>(:final value):
        if (afterCursor == null) {
          await _cache.write(
            ReadCacheSlot.choreList,
            householdId: householdId,
            payload: _choreListPayload(value),
            validatedAt: DateTime.tryParse(value.generatedAt)?.toUtc(),
          );
        }
        return result;
      case ChoreDataFailed<ChoreListPageDataRecord>(
        kind: ChoreDataFailureKind.temporarilyUnavailable,
      ):
        if (afterCursor != null) {
          return result;
        }
        final ReadCacheRecord? cached = await _cache.read(
          ReadCacheSlot.choreList,
          expectedHouseholdId: householdId,
        );
        if (cached != null &&
            _containsDifferentChoreListQuery(
              cached.payload,
              expectedHouseholdId: householdId,
              expectedView: view,
              expectedAssigneeMemberId: assigneeMemberId,
              expectedLimit: limit,
            )) {
          return result;
        }
        final ChoreListPageDataRecord? value = choreListPageFromPayload(
          cached?.payload,
          expectedHouseholdId: householdId,
          expectedView: view,
          expectedAssigneeMemberId: assigneeMemberId,
          expectedLimit: limit,
        );
        if (cached == null || value == null) {
          if (cached != null && value == null) {
            await _cache.delete(ReadCacheSlot.choreList);
          }
          return result;
        }
        return ChoreDataSucceeded<ChoreListPageDataRecord>(
          value,
          cacheMetadata: cached.metadata,
        );
      case ChoreDataFailed<ChoreListPageDataRecord>(:final kind):
        await _handleAuthoritativeFailure(kind, ReadCacheSlot.choreList);
        return result;
    }
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceDataRecord>> loadOccurrenceTarget({
    required String householdId,
    required String occurrenceId,
  }) {
    return _delegate.loadOccurrenceTarget(
      householdId: householdId,
      occurrenceId: occurrenceId,
    );
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceHistoryPageDataRecord>>
  loadOccurrenceHistory({
    required String householdId,
    required String occurrenceId,
    required int limit,
    required String? beforeOccurredAt,
    required String? beforeEntryId,
  }) {
    return _delegate.loadOccurrenceHistory(
      householdId: householdId,
      occurrenceId: occurrenceId,
      limit: limit,
      beforeOccurredAt: beforeOccurredAt,
      beforeEntryId: beforeEntryId,
    );
  }

  @override
  Future<ChoreDataResult<DeletedOneTimeChorePageDataRecord>>
  loadDeletedOneTimeChores({
    required String householdId,
    required int limit,
    required String? beforeCursor,
  }) {
    return _delegate.loadDeletedOneTimeChores(
      householdId: householdId,
      limit: limit,
      beforeCursor: beforeCursor,
    );
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
  }) {
    return _mutation<ChoreOccurrenceDataRecord>(
      householdId,
      () => _delegate.createOneTimeChore(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        dueLocalDate: dueLocalDate,
        dueLocalTime: dueLocalTime,
      ),
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
  }) {
    return _mutation<OneTimeChoreUpdateDataRecord>(
      householdId,
      () => _delegate.updateOneTimeChore(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        expectedSeriesVersion: expectedSeriesVersion,
        expectedOccurrenceVersion: expectedOccurrenceVersion,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        dueLocalDate: dueLocalDate,
        dueLocalTime: dueLocalTime,
      ),
    );
  }

  @override
  Future<ChoreDataResult<OneTimeChoreDeletionDataRecord>> deleteOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) {
    return _mutation<OneTimeChoreDeletionDataRecord>(
      householdId,
      () => _delegate.deleteOneTimeChore(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        expectedSeriesVersion: expectedSeriesVersion,
        expectedOccurrenceVersion: expectedOccurrenceVersion,
      ),
    );
  }

  @override
  Future<ChoreDataResult<OneTimeChoreRestoreDataRecord>> restoreOneTimeChore({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedSeriesVersion,
    required int expectedOccurrenceVersion,
  }) {
    return _mutation<OneTimeChoreRestoreDataRecord>(
      householdId,
      () => _delegate.restoreOneTimeChore(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        expectedSeriesVersion: expectedSeriesVersion,
        expectedOccurrenceVersion: expectedOccurrenceVersion,
      ),
    );
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
  }) {
    return _mutation<RecurringChoreDataRecord>(
      householdId,
      () => _delegate.createRepeatingChore(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        startLocalDate: startLocalDate,
        dueLocalTime: dueLocalTime,
        recurrenceRule: recurrenceRule,
      ),
    );
  }

  @override
  Future<ChoreDataResult<ChoreCompletionDataRecord>> setCompletion({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required bool completed,
  }) {
    return _mutation<ChoreCompletionDataRecord>(
      householdId,
      () => _delegate.setCompletion(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: expectedVersion,
        completed: completed,
      ),
    );
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceSkipDataRecord>> skipOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) {
    return _mutation<ChoreOccurrenceSkipDataRecord>(
      householdId,
      () => _delegate.skipOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: expectedVersion,
      ),
    );
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceRestoreDataRecord>>
  restoreSkippedOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
  }) {
    return _mutation<ChoreOccurrenceRestoreDataRecord>(
      householdId,
      () => _delegate.restoreSkippedOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: expectedVersion,
      ),
    );
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
  }) {
    return _mutation<ChoreOccurrenceRescheduleDataRecord>(
      householdId,
      () => _delegate.rescheduleOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: expectedVersion,
        dueLocalDate: dueLocalDate,
        dueLocalTime: dueLocalTime,
      ),
    );
  }

  @override
  Future<ChoreDataResult<ChoreOccurrenceReassignmentDataRecord>>
  reassignOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String occurrenceId,
    required int expectedVersion,
    required String assigneeMemberId,
  }) {
    return _mutation<ChoreOccurrenceReassignmentDataRecord>(
      householdId,
      () => _delegate.reassignOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        occurrenceId: occurrenceId,
        expectedVersion: expectedVersion,
        assigneeMemberId: assigneeMemberId,
      ),
    );
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
  }) {
    return _mutation<RepeatingChoreSeriesUpdateDataRecord>(
      householdId,
      () => _delegate.updateRepeatingSeries(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        expectedVersion: expectedVersion,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        dueLocalTime: dueLocalTime,
        recurrenceRule: recurrenceRule,
      ),
    );
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
  }) {
    return _mutation<RepeatingChoreSeriesUpdateDataRecord>(
      householdId,
      () => _delegate.updateRepeatingSeriesFromOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        effectiveOccurrenceId: effectiveOccurrenceId,
        expectedVersion: expectedVersion,
        title: title,
        description: description,
        assigneeMemberId: assigneeMemberId,
        dueLocalTime: dueLocalTime,
        recurrenceRule: recurrenceRule,
      ),
    );
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationDataRecord>>
  cancelRepeatingSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) {
    return _mutation<RepeatingChoreSeriesCancellationDataRecord>(
      householdId,
      () => _delegate.cancelRepeatingSeries(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        expectedVersion: expectedVersion,
      ),
    );
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
  }) {
    return _mutation<RepeatingChoreSeriesFromOccurrenceCancellationDataRecord>(
      householdId,
      () => _delegate.cancelRepeatingSeriesFromOccurrence(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        effectiveOccurrenceId: effectiveOccurrenceId,
        expectedVersion: expectedVersion,
      ),
    );
  }

  @override
  Future<ChoreDataResult<RepeatingChoreSeriesCancellationResumeDataRecord>>
  resumeRepeatingSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  }) {
    return _mutation<RepeatingChoreSeriesCancellationResumeDataRecord>(
      householdId,
      () => _delegate.resumeRepeatingSeriesCancellation(
        idempotencyKey: idempotencyKey,
        householdId: householdId,
        seriesId: seriesId,
        cancellationIdempotencyKey: cancellationIdempotencyKey,
        expectedVersion: expectedVersion,
      ),
    );
  }

  Future<ChoreDataResult<T>> _mutation<T>(
    String householdId,
    Future<ChoreDataResult<T>> Function() operation,
  ) async {
    final ChoreDataResult<T> result = await operation();
    switch (result) {
      case ChoreDataSucceeded<T>():
        await _invalidateReads();
      case ChoreDataFailed<T>(:final kind)
          when kind == ChoreDataFailureKind.unauthenticated ||
              kind == ChoreDataFailureKind.notFoundOrForbidden:
        await _cache.clear();
      case ChoreDataFailed<T>():
        break;
    }
    return result;
  }

  Future<void> _handleAuthoritativeFailure(
    ChoreDataFailureKind kind,
    ReadCacheSlot slot,
  ) async {
    if (kind == ChoreDataFailureKind.unauthenticated ||
        kind == ChoreDataFailureKind.notFoundOrForbidden) {
      await _cache.clear();
    } else if (kind == ChoreDataFailureKind.invalidPayload) {
      await _cache.delete(slot);
    }
  }

  Future<void> _invalidateReads() async {
    await Future.wait<bool>(<Future<bool>>[
      _cache.delete(ReadCacheSlot.choreList),
      _cache.delete(ReadCacheSlot.todayChores),
    ]);
  }

  bool _containsDifferentChoreListQuery(
    Object? payload, {
    required String expectedHouseholdId,
    required String expectedView,
    required String? expectedAssigneeMemberId,
    required int expectedLimit,
  }) {
    if (payload is! List<dynamic> || payload.isEmpty) {
      return false;
    }
    final Object? firstRawRow = payload.first;
    if (firstRawRow is! Map ||
        firstRawRow.keys.any((Object? key) => key is! String)) {
      return false;
    }
    final Map<String, Object?> firstRow = Map<String, Object?>.from(
      firstRawRow,
    );
    final Object? householdId = firstRow['household_id'];
    final Object? view = firstRow['list_view'];
    final Object? assigneeMemberId = firstRow['assignee_filter_member_id'];
    final Object? limit = firstRow['page_limit'];
    if (householdId is! String ||
        householdId != expectedHouseholdId ||
        view is! String ||
        assigneeMemberId != null && assigneeMemberId is! String ||
        limit is! int) {
      return false;
    }
    return view != expectedView ||
        assigneeMemberId != expectedAssigneeMemberId ||
        limit != expectedLimit;
  }

  List<Map<String, Object?>> _todayPayload(TodayChoresDataRecord record) {
    final List<ChoreOccurrenceDataRecord?> items = record.occurrences.isEmpty
        ? <ChoreOccurrenceDataRecord?>[null]
        : record.occurrences;
    return items
        .map(
          (ChoreOccurrenceDataRecord? item) => <String, Object?>{
            'household_id': record.householdId,
            'household_timezone': record.householdTimezone,
            'household_local_date': record.householdLocalDate,
            'occurrence_id': item?.occurrenceId,
            'series_id': item?.seriesId,
            'title': item?.title,
            'description': item?.description,
            'assignee_member_id': item?.assigneeMemberId,
            'assignee_display_name': item?.assigneeDisplayName,
            'due_local_time': item?.dueLocalTime,
            'due_at': item?.dueAt,
            'status': item?.status,
            'version': item?.version,
            'recurrence_frequency': item?.recurrenceFrequency,
            'series_version': item?.seriesVersion,
            'series_default_assignee_member_id':
                item?.seriesDefaultAssigneeMemberId,
            'series_due_local_time': item?.seriesDueLocalTime,
            'recurrence_rule': item?.recurrenceRule,
            'can_manage_series': item?.canManageSeries,
          },
        )
        .toList(growable: false);
  }

  List<Map<String, Object?>> _choreListPayload(ChoreListPageDataRecord record) {
    final List<ChoreOccurrenceDataRecord?> items = record.occurrences.isEmpty
        ? <ChoreOccurrenceDataRecord?>[null]
        : record.occurrences;
    return items
        .map(
          (ChoreOccurrenceDataRecord? item) => <String, Object?>{
            'household_id': record.householdId,
            'household_timezone': record.householdTimezone,
            'household_local_date': record.householdLocalDate,
            'generated_at': record.generatedAt,
            'list_view': record.listView,
            'assignee_filter_member_id': record.assigneeFilterMemberId,
            'page_limit': record.pageLimit,
            'has_more': record.hasMore,
            'page_cursor': record.pageCursor,
            'occurrence_id': item?.occurrenceId,
            'series_id': item?.seriesId,
            'title': item?.title,
            'description': item?.description,
            'assignee_member_id': item?.assigneeMemberId,
            'assignee_display_name': item?.assigneeDisplayName,
            'due_local_date': item?.dueLocalDate,
            'due_local_time': item?.dueLocalTime,
            'due_at': item?.dueAt,
            'status': item?.status,
            'version': item?.version,
            'recurrence_frequency': item?.recurrenceFrequency,
            'series_version': item?.seriesVersion,
            'series_default_assignee_member_id':
                item?.seriesDefaultAssigneeMemberId,
            'series_due_local_time': item?.seriesDueLocalTime,
            'recurrence_rule': item?.recurrenceRule,
            'can_manage_series': item?.canManageSeries,
          },
        )
        .toList(growable: false);
  }
}
