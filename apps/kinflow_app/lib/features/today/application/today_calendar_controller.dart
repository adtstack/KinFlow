import 'dart:async';

import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/application/calendar_sync_session.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/application/today_calendar_state.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

final class TodayCalendarController {
  TodayCalendarController({
    required this._repository,
    CalendarSyncRepository? syncRepository,
    this._snapshotCache = const UnavailableTodayCalendarSnapshotCache(),
  }) {
    _syncSession = CalendarSyncSession(
      syncRepository,
      _synchronize,
      _setSyncStatus,
    );
  }

  static const int _pageLimit = 100;
  static const int _maximumTodayEvents = 500;

  final CalendarRepository _repository;
  final TodayCalendarSnapshotCache _snapshotCache;
  late final CalendarSyncSession _syncSession;
  final StreamController<TodayCalendarState> _states =
      StreamController<TodayCalendarState>.broadcast(sync: true);

  TodayCalendarState _state = const TodayCalendarInitial();
  TodayCalendarRequest? _currentRequest;
  HouseholdId? _syncedHouseholdId;
  CalendarSyncConnectionStatus _syncStatus =
      CalendarSyncConnectionStatus.disabled;
  Future<void> _pendingLoad = Future<void>.value();
  var _loadGeneration = 0;
  var _loadBusy = false;
  var _disposed = false;

  TodayCalendarState get state => _state;

  Stream<TodayCalendarState> get states => _states.stream;

  Future<void> load(TodayCalendarRequest request) {
    if (_disposed) {
      return _pendingLoad;
    }
    if (_loadBusy &&
        _currentRequest != null &&
        _currentRequest!.hasSameQuery(request)) {
      return _pendingLoad;
    }
    final TodayCalendarReady? ready = _state is TodayCalendarReady
        ? _state as TodayCalendarReady
        : null;
    final bool preserveContent =
        ready != null &&
        _currentRequest != null &&
        _currentRequest!.hasSameQuery(request);
    _currentRequest = request;
    final int generation = ++_loadGeneration;
    _loadBusy = true;
    if (preserveContent) {
      _emitFor(
        generation,
        TodayCalendarReady(
          ready.snapshot,
          refreshing: true,
          syncStatus: _syncStatus,
          cacheMetadata: ready.cacheMetadata,
        ),
      );
    } else {
      _emitFor(generation, const TodayCalendarLoading());
    }
    _pendingLoad =
        _load(
          request,
          retained: preserveContent ? ready.snapshot : null,
          retainedCacheMetadata: preserveContent ? ready.cacheMetadata : null,
          generation: generation,
        ).whenComplete(() {
          if (_loadGeneration == generation) {
            _loadBusy = false;
          }
        });
    return _pendingLoad;
  }

  Future<void> refresh() {
    final TodayCalendarRequest? request = _currentRequest;
    return request == null ? Future<void>.value() : load(request);
  }

  Future<void> resume() => _syncSession.resume();

  Future<void> reconnect() => _syncSession.reconnect();

  Future<void> _load(
    TodayCalendarRequest request, {
    required TodayCalendarSnapshot? retained,
    required ReadCacheMetadata? retainedCacheMetadata,
    required int generation,
  }) async {
    try {
      CalendarEventPageRequest pageRequest =
          CalendarEventPageRequest.initialAgenda(
            request.householdId,
            limit: _pageLimit,
          );
      CalendarEventPage? firstPage;
      CalendarEventProjection? previous;
      final Set<CalendarEventOccurrenceId> occurrenceIds =
          <CalendarEventOccurrenceId>{};
      final List<CalendarEventProjection> visible = <CalendarEventProjection>[];
      var examinedTodayEvents = 0;
      var reachedFutureDate = false;
      var truncated = false;

      while (true) {
        final LoadCalendarEventPageResult result = await _repository
            .loadEventPage(pageRequest);
        if (result case LoadCalendarEventPageFailed(:final failure)) {
          await _emitFailure(
            generation,
            request,
            failure,
            retained,
            retainedCacheMetadata,
          );
          return;
        }
        final CalendarEventPage page = (result as CalendarEventPageLoaded).page;
        firstPage ??= page;
        if (!_validPageContext(request, pageRequest, firstPage, page)) {
          await _emitFailure(
            generation,
            request,
            const CalendarFailure(CalendarFailureKind.invalidPayload),
            retained,
            retainedCacheMetadata,
          );
          return;
        }

        for (final CalendarEventProjection projection in page.items) {
          if (previous != null &&
              compareCalendarEventProjections(previous, projection) >= 0) {
            await _emitFailure(
              generation,
              request,
              const CalendarFailure(CalendarFailureKind.invalidPayload),
              retained,
              retainedCacheMetadata,
            );
            return;
          }
          previous = projection;
          if (!occurrenceIds.add(projection.event.occurrenceId)) {
            await _emitFailure(
              generation,
              request,
              const CalendarFailure(CalendarFailureKind.invalidPayload),
              retained,
              retainedCacheMetadata,
            );
            return;
          }
          final int dateOrder = projection.viewLocalDate.compareTo(
            firstPage.householdLocalDate,
          );
          if (dateOrder < 0) {
            await _emitFailure(
              generation,
              request,
              const CalendarFailure(CalendarFailureKind.invalidPayload),
              retained,
              retainedCacheMetadata,
            );
            return;
          }
          if (dateOrder > 0) {
            reachedFutureDate = true;
            break;
          }
          examinedTodayEvents += 1;
          if (_includesParticipant(projection, request)) {
            visible.add(projection);
          }
          if (examinedTodayEvents == _maximumTodayEvents) {
            truncated =
                page.hasMore ||
                page.items.last.event.occurrenceId !=
                    projection.event.occurrenceId;
            break;
          }
        }

        if (reachedFutureDate ||
            examinedTodayEvents >= _maximumTodayEvents ||
            !page.hasMore) {
          truncated =
              truncated ||
              examinedTodayEvents >= _maximumTodayEvents && page.hasMore;
          break;
        }
        final CalendarPageCursor? cursor = page.nextCursor;
        final CalendarEventPageRequest? continuation = cursor == null
            ? null
            : page.request.continuation(cursor);
        if (continuation == null) {
          await _emitFailure(
            generation,
            request,
            const CalendarFailure(CalendarFailureKind.invalidPayload),
            retained,
            retainedCacheMetadata,
          );
          return;
        }
        pageRequest = continuation;
      }

      final CalendarEventPage authoritative = firstPage;
      final TodayCalendarSnapshot? snapshot = TodayCalendarSnapshot.tryCreate(
        householdId: request.householdId,
        householdTimeZone: authoritative.householdTimeZone,
        localDate: authoritative.householdLocalDate,
        generatedAt: authoritative.generatedAt,
        participantMemberId: request.participantMemberId,
        events: visible,
        truncated: truncated,
      );
      if (snapshot == null) {
        await _emitFailure(
          generation,
          request,
          const CalendarFailure(CalendarFailureKind.invalidPayload),
          retained,
          retainedCacheMetadata,
        );
        return;
      }
      if (generation != _loadGeneration) {
        return;
      }
      await _writeSnapshotBestEffort(snapshot);
      _emitFor(
        generation,
        TodayCalendarReady(snapshot, syncStatus: _syncStatus),
      );
      if (generation == _loadGeneration &&
          _syncedHouseholdId != request.householdId) {
        _syncedHouseholdId = request.householdId;
        await _syncSession.start(request.householdId);
      }
    } on Object {
      await _emitFailure(
        generation,
        request,
        const CalendarFailure(CalendarFailureKind.internal),
        retained,
        retainedCacheMetadata,
      );
    }
  }

  bool _validPageContext(
    TodayCalendarRequest request,
    CalendarEventPageRequest expectedRequest,
    CalendarEventPage firstPage,
    CalendarEventPage page,
  ) {
    return page.householdId == request.householdId &&
        page.request.cursor == expectedRequest.cursor &&
        (expectedRequest.range == null ||
            page.request.hasSameQuery(expectedRequest)) &&
        page.request.view == CalendarViewMode.agenda &&
        page.range.startDate == page.householdLocalDate &&
        page.householdTimeZone == firstPage.householdTimeZone &&
        page.householdLocalDate == firstPage.householdLocalDate &&
        page.range == firstPage.range &&
        page.request.limit == _pageLimit;
  }

  bool _includesParticipant(
    CalendarEventProjection projection,
    TodayCalendarRequest request,
  ) {
    final participantMemberId = request.participantMemberId;
    return participantMemberId == null ||
        projection.event.participants.any(
          (participant) => participant.memberId == participantMemberId,
        );
  }

  Future<void> _emitFailure(
    int generation,
    TodayCalendarRequest request,
    CalendarFailure failure,
    TodayCalendarSnapshot? retained,
    ReadCacheMetadata? retainedCacheMetadata,
  ) async {
    if (generation != _loadGeneration) {
      return;
    }
    if (failure.invalidatesRetainedContent) {
      await _clearCacheBestEffort();
      _emitFor(generation, TodayCalendarLoadFailed(failure));
      return;
    }
    if (failure.kind == CalendarFailureKind.invalidPayload) {
      await _deleteCacheBestEffort();
    }
    if (retained != null) {
      _emitFor(
        generation,
        TodayCalendarReady(
          retained,
          refreshFailure: failure,
          syncStatus: _syncStatus,
          cacheMetadata: retainedCacheMetadata,
        ),
      );
      return;
    }
    if (failure.kind == CalendarFailureKind.temporarilyUnavailable) {
      final CachedTodayCalendarSnapshot? cached = await _readCacheBestEffort(
        request,
      );
      if (cached != null && generation == _loadGeneration) {
        _emitFor(
          generation,
          TodayCalendarReady(
            cached.snapshot,
            refreshFailure: failure,
            syncStatus: _syncStatus,
            cacheMetadata: cached.metadata,
          ),
        );
        return;
      }
    }
    _emitFor(generation, TodayCalendarLoadFailed(failure));
  }

  Future<CachedTodayCalendarSnapshot?> _readCacheBestEffort(
    TodayCalendarRequest request,
  ) async {
    try {
      return await _snapshotCache.read(request);
    } on Object {
      return null;
    }
  }

  Future<void> _writeSnapshotBestEffort(TodayCalendarSnapshot snapshot) async {
    try {
      await _snapshotCache.write(snapshot);
    } on Object {
      // Online authoritative content remains usable when local cache fails.
    }
  }

  Future<void> _deleteCacheBestEffort() async {
    try {
      await _snapshotCache.delete();
    } on Object {
      // A malformed local slot remains unreadable through strict decoding.
    }
  }

  Future<void> _clearCacheBestEffort() async {
    try {
      await _snapshotCache.clearAll();
    } on Object {
      // Current auth scope still gates every future read fail closed.
    }
  }

  void _emitFor(int generation, TodayCalendarState state) {
    if (generation != _loadGeneration) {
      return;
    }
    _emit(state);
  }

  void _emit(TodayCalendarState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    _states.add(state);
  }

  Future<void> _synchronize() async {
    if (_loadBusy) {
      await _pendingLoad;
    }
    if (_disposed) {
      return;
    }
    final TodayCalendarRequest? request = _currentRequest;
    if (request != null) {
      await load(request);
    }
  }

  void _setSyncStatus(CalendarSyncConnectionStatus status) {
    if (_disposed || _syncStatus == status) {
      return;
    }
    _syncStatus = status;
    final TodayCalendarState current = _state;
    if (current case TodayCalendarReady(
      :final snapshot,
      :final refreshing,
      :final refreshFailure,
      :final cacheMetadata,
    )) {
      _emit(
        TodayCalendarReady(
          snapshot,
          refreshing: refreshing,
          refreshFailure: refreshFailure,
          syncStatus: status,
          cacheMetadata: cacheMetadata,
        ),
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _syncSession.dispose();
    await _states.close();
  }
}
