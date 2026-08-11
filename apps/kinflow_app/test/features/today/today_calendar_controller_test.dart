import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/application/today_calendar_controller.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/application/today_calendar_state.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'loads only the server-local Today events for one participant',
    () async {
      final OneTimeCalendarEvent included = calendarEventFixture(
        title: 'Alex event',
      );
      final OneTimeCalendarEvent excludedParticipant = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'Jamie event',
        participants: <CalendarEventParticipant>[
          CalendarEventParticipant.tryCreate(
            memberId: calendarMemberTwoId(),
            displayName: 'Jamie',
          )!,
        ],
      );
      final OneTimeCalendarEvent tomorrow = _timedEvent(3, dayOffset: 1);
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[
            included,
            excludedParticipant,
            tomorrow,
          ],
        ),
      );
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await controller.load(
        TodayCalendarRequest(
          householdId: calendarHouseholdId(),
          participantMemberId: calendarMemberOneId(),
        ),
      );

      final TodayCalendarReady state = controller.state as TodayCalendarReady;
      expect(state.snapshot.localDate.value, '2026-08-07');
      expect(state.snapshot.events.map((item) => item.event.title), <String>[
        'Alex event',
      ]);
      expect(repository.pageRequests, hasLength(1));
      expect(repository.pageRequests.single.range, isNull);
      expect(repository.pageRequests.single.limit, 100);
    },
  );

  test('continues bounded pages until the first future-day event', () async {
    final List<OneTimeCalendarEvent> firstEvents =
        List<OneTimeCalendarEvent>.generate(100, _timedEvent, growable: false);
    final FakeCalendarRepository repository = FakeCalendarRepository(
      pageResults: <LoadCalendarEventPageResult>[
        CalendarEventPageLoaded(
          calendarEventPageFixture(
            events: firstEvents,
            limit: 100,
            hasMore: true,
            nextCursor: 'aa',
          ),
        ),
        CalendarEventPageLoaded(
          calendarEventPageFixture(
            events: <OneTimeCalendarEvent>[
              _timedEvent(100),
              _timedEvent(101, dayOffset: 1),
            ],
            limit: 100,
            requestCursor: 'aa',
          ),
        ),
      ],
    );
    final TodayCalendarController controller = TodayCalendarController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.load(_everyoneRequest());

    final TodayCalendarReady state = controller.state as TodayCalendarReady;
    expect(state.snapshot.events, hasLength(101));
    expect(state.snapshot.truncated, isFalse);
    expect(repository.pageRequests, hasLength(2));
    expect(repository.pageRequests.last.cursor?.value, 'aa');
  });

  test(
    'caps a pathological Today at 500 events and reports truncation',
    () async {
      final List<LoadCalendarEventPageResult> pages =
          <LoadCalendarEventPageResult>[];
      const List<String> cursors = <String>['aa', 'bb', 'cc', 'dd', 'ee'];
      for (var pageIndex = 0; pageIndex < 5; pageIndex += 1) {
        pages.add(
          CalendarEventPageLoaded(
            calendarEventPageFixture(
              events: List<OneTimeCalendarEvent>.generate(
                100,
                (int itemIndex) => _timedEvent(pageIndex * 100 + itemIndex),
                growable: false,
              ),
              limit: 100,
              requestCursor: pageIndex == 0 ? null : cursors[pageIndex - 1],
              hasMore: true,
              nextCursor: cursors[pageIndex],
            ),
          ),
        );
      }
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: pages,
      );
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await controller.load(_everyoneRequest());

      final TodayCalendarReady state = controller.state as TodayCalendarReady;
      expect(state.snapshot.events, hasLength(500));
      expect(state.snapshot.truncated, isTrue);
      expect(repository.pageRequests, hasLength(5));
    },
  );

  test(
    'retains the last successful Calendar source when refresh fails',
    () async {
      final CalendarEventPage page = calendarEventPageFixture(
        events: <OneTimeCalendarEvent>[calendarEventFixture()],
        limit: 100,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(page),
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await controller.load(_everyoneRequest());
      await controller.refresh();

      final TodayCalendarReady state = controller.state as TodayCalendarReady;
      expect(state.snapshot.events, hasLength(1));
      expect(
        state.refreshFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
    },
  );

  test(
    'discards retained Calendar source when household access is lost',
    () async {
      final CalendarEventPage page = calendarEventPageFixture(
        events: <OneTimeCalendarEvent>[calendarEventFixture()],
        limit: 100,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(page),
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
          ),
        ],
      );
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await controller.load(_everyoneRequest());
      await controller.refresh();

      final TodayCalendarLoadFailed state =
          controller.state as TodayCalendarLoadFailed;
      expect(state.failure.kind, CalendarFailureKind.notFoundOrForbidden);
    },
  );

  test(
    'fails closed when the Calendar source resolves another local day',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(
            calendarEventPageFixture(
              localDate: '2026-08-06',
              rangeStartDate: '2026-08-07',
              limit: 100,
            ),
          ),
        ],
      );
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
      );
      addTearDown(controller.dispose);

      await controller.load(_everyoneRequest());

      expect(
        (controller.state as TodayCalendarLoadFailed).failure.kind,
        CalendarFailureKind.invalidPayload,
      );
    },
  );

  test('a newer member filter wins over a late previous response', () async {
    final Completer<LoadCalendarEventPageResult> everyone =
        Completer<LoadCalendarEventPageResult>();
    final Completer<LoadCalendarEventPageResult> me =
        Completer<LoadCalendarEventPageResult>();
    var loadIndex = 0;
    final FakeCalendarRepository repository = FakeCalendarRepository(
      pageLoader: (CalendarEventPageRequest _) {
        loadIndex += 1;
        return loadIndex == 1 ? everyone.future : me.future;
      },
    );
    final TodayCalendarController controller = TodayCalendarController(
      repository: repository,
    );
    addTearDown(controller.dispose);

    final Future<void> everyoneLoad = controller.load(_everyoneRequest());
    final Future<void> meLoad = controller.load(
      TodayCalendarRequest(
        householdId: calendarHouseholdId(),
        participantMemberId: calendarMemberOneId(),
      ),
    );
    expect(repository.pageRequests, hasLength(2));

    me.complete(
      CalendarEventPageLoaded(
        calendarEventPageFixture(
          events: <OneTimeCalendarEvent>[
            calendarEventFixture(title: 'Latest Me event'),
          ],
          limit: 100,
        ),
      ),
    );
    await meLoad;
    everyone.complete(
      CalendarEventPageLoaded(
        calendarEventPageFixture(
          events: <OneTimeCalendarEvent>[
            calendarEventFixture(title: 'Late Everyone event'),
          ],
          limit: 100,
        ),
      ),
    );
    await everyoneLoad;

    final TodayCalendarReady state = controller.state as TodayCalendarReady;
    expect(state.snapshot.participantMemberId, calendarMemberOneId());
    expect(state.snapshot.events.single.event.title, 'Latest Me event');
  });

  test(
    'retains Today content while disconnected and refetches on reconnect',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(events: [calendarEventFixture()]),
      );
      final _TodaySyncRepository syncRepository = _TodaySyncRepository();
      final TodayCalendarController controller = TodayCalendarController(
        repository: repository,
        syncRepository: syncRepository,
      );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });
      await controller.load(_everyoneRequest());

      syncRepository.latest.add(const CalendarSyncDisconnected());

      final TodayCalendarReady disconnected =
          controller.state as TodayCalendarReady;
      expect(
        disconnected.syncStatus,
        CalendarSyncConnectionStatus.disconnected,
      );
      expect(disconnected.snapshot.events.single.event.title, 'Family dinner');

      await controller.reconnect();
      expect(syncRepository.watchCount, 2);
      expect(repository.pageRequests, hasLength(2));
      syncRepository.latest.add(const CalendarSyncConnected());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        (controller.state as TodayCalendarReady).syncStatus,
        CalendarSyncConnectionStatus.live,
      );
      expect(repository.pageRequests, hasLength(3));
    },
  );

  test(
    'restores an encrypted snapshot after restart and replaces it on retry',
    () async {
      final _MemoryTodayCalendarSnapshotCache cache =
          _MemoryTodayCalendarSnapshotCache();
      final TodayCalendarController online = TodayCalendarController(
        repository: FakeCalendarRepository(
          eventList: calendarEventListFixture(
            events: <OneTimeCalendarEvent>[
              calendarEventFixture(title: 'Cached family event'),
            ],
          ),
        ),
        snapshotCache: cache,
      );
      await online.load(_everyoneRequest());
      await online.dispose();
      expect(cache.writeCount, 1);

      final FakeCalendarRepository reconnecting = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
          CalendarEventPageLoaded(
            calendarEventPageFixture(
              events: <OneTimeCalendarEvent>[
                calendarEventFixture(title: 'Fresh family event'),
              ],
              limit: 100,
            ),
          ),
        ],
      );
      final TodayCalendarController restarted = TodayCalendarController(
        repository: reconnecting,
        snapshotCache: cache,
      );
      addTearDown(restarted.dispose);

      await restarted.load(_everyoneRequest());

      final TodayCalendarReady offline = restarted.state as TodayCalendarReady;
      expect(offline.isReadOnlyCache, isTrue);
      expect(offline.snapshot.events.single.event.title, 'Cached family event');
      expect(
        offline.refreshFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      expect(cache.readCount, 1);

      await restarted.refresh();

      final TodayCalendarReady recovered =
          restarted.state as TodayCalendarReady;
      expect(recovered.isReadOnlyCache, isFalse);
      expect(
        recovered.snapshot.events.single.event.title,
        'Fresh family event',
      );
      expect(recovered.refreshFailure, isNull);
      expect(cache.writeCount, 2);
    },
  );

  test(
    'clears every retained cache slot when household access is lost',
    () async {
      final _MemoryTodayCalendarSnapshotCache cache =
          _MemoryTodayCalendarSnapshotCache()
            ..stored = _cachedSnapshot(<OneTimeCalendarEvent>[
              calendarEventFixture(),
            ]);
      final TodayCalendarController controller = TodayCalendarController(
        repository: FakeCalendarRepository(
          pageResults: const <LoadCalendarEventPageResult>[
            LoadCalendarEventPageFailed(
              CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
            ),
          ],
        ),
        snapshotCache: cache,
      );
      addTearDown(controller.dispose);

      await controller.load(_everyoneRequest());

      expect(controller.state, isA<TodayCalendarLoadFailed>());
      expect(cache.clearCount, 1);
      expect(cache.readCount, 0);
      expect(cache.stored, isNull);
    },
  );
}

TodayCalendarRequest _everyoneRequest() => TodayCalendarRequest(
  householdId: calendarHouseholdId(),
  participantMemberId: null,
);

OneTimeCalendarEvent _timedEvent(int index, {int dayOffset = 0}) {
  final int minute = index % 1440;
  final int hour = minute ~/ 60;
  final int minuteOfHour = minute % 60;
  final DateTime localDate = DateTime.utc(2026, 8, 7 + dayOffset);
  final DateTime startsAt = DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day - 1,
    15 + hour,
    minuteOfHour,
  );
  return calendarEventFixture(
    seriesId: '44444444-4444-4444-8444-${index.toString().padLeft(12, '0')}',
    occurrenceId:
        '55555555-5555-4555-8555-${index.toString().padLeft(12, '0')}',
    title: 'Event $index',
    localStartDate:
        '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}',
    localStartTime:
        '${hour.toString().padLeft(2, '0')}:'
        '${minuteOfHour.toString().padLeft(2, '0')}',
    startsAt: startsAt.toIso8601String(),
  );
}

final class _TodaySyncRepository implements CalendarSyncRepository {
  final List<StreamController<CalendarSyncSignal>> _controllers =
      <StreamController<CalendarSyncSignal>>[];

  int get watchCount => _controllers.length;

  StreamController<CalendarSyncSignal> get latest => _controllers.last;

  @override
  Stream<CalendarSyncSignal> watch(HouseholdId householdId) {
    final StreamController<CalendarSyncSignal> controller =
        StreamController<CalendarSyncSignal>.broadcast(sync: true);
    _controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final StreamController<CalendarSyncSignal> controller
        in _controllers) {
      await controller.close();
    }
  }
}

CachedTodayCalendarSnapshot _cachedSnapshot(List<OneTimeCalendarEvent> events) {
  final CalendarEventPage page = calendarEventPageFixture(
    events: events,
    limit: 100,
  );
  final TodayCalendarSnapshot snapshot = TodayCalendarSnapshot.tryCreate(
    householdId: page.householdId,
    householdTimeZone: page.householdTimeZone,
    localDate: page.householdLocalDate,
    generatedAt: page.generatedAt,
    participantMemberId: null,
    events: page.items,
    truncated: false,
  )!;
  return CachedTodayCalendarSnapshot(
    snapshot: snapshot,
    metadata: ReadCacheMetadata(
      validatedAt: snapshot.generatedAt.dateTime,
      expiresAt: snapshot.generatedAt.dateTime.add(const Duration(hours: 2)),
    ),
  );
}

final class _MemoryTodayCalendarSnapshotCache
    implements TodayCalendarSnapshotCache {
  CachedTodayCalendarSnapshot? stored;
  var readCount = 0;
  var writeCount = 0;
  var deleteCount = 0;
  var clearCount = 0;

  @override
  Future<CachedTodayCalendarSnapshot?> read(
    TodayCalendarRequest request,
  ) async {
    readCount += 1;
    final CachedTodayCalendarSnapshot? value = stored;
    return value != null &&
            value.snapshot.householdId == request.householdId &&
            value.snapshot.participantMemberId == request.participantMemberId
        ? value
        : null;
  }

  @override
  Future<bool> write(TodayCalendarSnapshot snapshot) async {
    writeCount += 1;
    stored = CachedTodayCalendarSnapshot(
      snapshot: snapshot,
      metadata: ReadCacheMetadata(
        validatedAt: snapshot.generatedAt.dateTime,
        expiresAt: snapshot.generatedAt.dateTime.add(const Duration(hours: 2)),
      ),
    );
    return true;
  }

  @override
  Future<bool> delete() async {
    deleteCount += 1;
    stored = null;
    return true;
  }

  @override
  Future<bool> clearAll() async {
    clearCount += 1;
    stored = null;
    return true;
  }
}
