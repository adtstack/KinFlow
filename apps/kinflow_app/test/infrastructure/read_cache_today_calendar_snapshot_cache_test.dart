import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';
import 'package:kinflow_app/infrastructure/cache/read_cache_today_calendar_snapshot_cache.dart';

import '../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test('round-trips the exact assembled Today Calendar snapshot', () async {
    final _MemoryReadCache readCache = _MemoryReadCache();
    final ReadCacheTodayCalendarSnapshotCache cache =
        ReadCacheTodayCalendarSnapshotCache(readCache);
    final CalendarRecurrenceRule recurrence = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    );
    final TodayCalendarSnapshot snapshot = _snapshot(<OneTimeCalendarEvent>[
      calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'All-day holiday',
        description: '',
        isAllDay: true,
      ),
      calendarEventFixture(
        title: 'Changed recurring dinner',
        recurrenceRule: recurrence,
        recurrenceLocalStartDate: '2026-08-07',
        revisionNumber: 3,
        occurrenceVersion: 4,
        isException: true,
      ),
    ]);

    expect(await cache.write(snapshot), isTrue);

    final CachedTodayCalendarSnapshot? restored = await cache.read(
      TodayCalendarRequest(
        householdId: calendarHouseholdId(),
        participantMemberId: null,
      ),
    );

    expect(restored, isNotNull);
    expect(restored!.snapshot.householdId, snapshot.householdId);
    expect(restored.snapshot.householdTimeZone, snapshot.householdTimeZone);
    expect(restored.snapshot.localDate, snapshot.localDate);
    expect(restored.snapshot.generatedAt, snapshot.generatedAt);
    expect(restored.snapshot.truncated, isFalse);
    expect(
      restored.snapshot.events.map((projection) => projection.event.title),
      <String>['All-day holiday', 'Changed recurring dinner'],
    );
    final OneTimeCalendarEvent recurring = restored.snapshot.events.last.event;
    expect(recurring.description, 'Bring dessert');
    expect(recurring.recurrenceRule, recurrence);
    expect(recurring.revisionNumber, 3);
    expect(recurring.occurrenceVersion, 4);
    expect(recurring.isException, isTrue);
    expect(restored.metadata.validatedAt, snapshot.generatedAt.dateTime);

    final Map<String, Object?> payload = Map<String, Object?>.from(
      readCache.records[ReadCacheSlot.todayCalendar]!.payload! as Map,
    );
    expect(payload.keys, <String>[
      'payloadVersion',
      'householdId',
      'householdTimezone',
      'householdLocalDate',
      'generatedAt',
      'participantMemberId',
      'truncated',
      'projections',
    ]);
  });

  test(
    'requires an exact participant filter without deleting valid data',
    () async {
      final _MemoryReadCache readCache = _MemoryReadCache();
      final ReadCacheTodayCalendarSnapshotCache cache =
          ReadCacheTodayCalendarSnapshotCache(readCache);
      await cache.write(
        _snapshot(<OneTimeCalendarEvent>[calendarEventFixture()]),
      );

      final CachedTodayCalendarSnapshot? mismatch = await cache.read(
        TodayCalendarRequest(
          householdId: calendarHouseholdId(),
          participantMemberId: calendarMemberOneId(),
        ),
      );

      expect(mismatch, isNull);
      expect(readCache.records, contains(ReadCacheSlot.todayCalendar));
      expect(readCache.deleteCount, 0);
    },
  );

  test('deletes a snapshot with an unknown payload field', () async {
    final _MemoryReadCache readCache = _MemoryReadCache();
    final ReadCacheTodayCalendarSnapshotCache cache =
        ReadCacheTodayCalendarSnapshotCache(readCache);
    await cache.write(
      _snapshot(<OneTimeCalendarEvent>[calendarEventFixture()]),
    );
    final ReadCacheRecord record =
        readCache.records[ReadCacheSlot.todayCalendar]!;
    final Map<String, Object?> corrupt = Map<String, Object?>.from(
      record.payload! as Map,
    )..['unexpected'] = true;
    readCache.records[ReadCacheSlot.todayCalendar] = ReadCacheRecord(
      householdId: record.householdId,
      payload: corrupt,
      metadata: record.metadata,
    );

    expect(
      await cache.read(
        TodayCalendarRequest(
          householdId: calendarHouseholdId(),
          participantMemberId: null,
        ),
      ),
      isNull,
    );
    expect(readCache.records, isNot(contains(ReadCacheSlot.todayCalendar)));
    expect(readCache.deleteCount, 1);
  });

  test('deletes duplicate or out-of-order cached projections', () async {
    for (final bool duplicate in <bool>[false, true]) {
      final _MemoryReadCache readCache = _MemoryReadCache();
      final ReadCacheTodayCalendarSnapshotCache cache =
          ReadCacheTodayCalendarSnapshotCache(readCache);
      await cache.write(
        _snapshot(<OneTimeCalendarEvent>[
          calendarEventFixture(
            seriesId: calendarSeriesTwoUuid,
            occurrenceId: calendarOccurrenceTwoUuid,
            title: 'All-day first',
            isAllDay: true,
          ),
          calendarEventFixture(title: 'Timed second'),
        ]),
      );
      final ReadCacheRecord record =
          readCache.records[ReadCacheSlot.todayCalendar]!;
      final Map<String, Object?> corrupt = Map<String, Object?>.from(
        record.payload! as Map,
      );
      final List<Object?> projections = List<Object?>.from(
        corrupt['projections']! as List,
      );
      corrupt['projections'] = duplicate
          ? <Object?>[projections.first, projections.first]
          : projections.reversed.toList(growable: false);
      readCache.records[ReadCacheSlot.todayCalendar] = ReadCacheRecord(
        householdId: record.householdId,
        payload: corrupt,
        metadata: record.metadata,
      );

      expect(
        await cache.read(
          TodayCalendarRequest(
            householdId: calendarHouseholdId(),
            participantMemberId: null,
          ),
        ),
        isNull,
      );
      expect(readCache.records, isNot(contains(ReadCacheSlot.todayCalendar)));
    }
  });

  test('deletes a projection that claims another household', () async {
    final _MemoryReadCache readCache = _MemoryReadCache();
    final ReadCacheTodayCalendarSnapshotCache cache =
        ReadCacheTodayCalendarSnapshotCache(readCache);
    await cache.write(
      _snapshot(<OneTimeCalendarEvent>[calendarEventFixture()]),
    );
    final ReadCacheRecord record =
        readCache.records[ReadCacheSlot.todayCalendar]!;
    final Map<String, Object?> corrupt = Map<String, Object?>.from(
      record.payload! as Map,
    );
    final List<Object?> projections = List<Object?>.from(
      corrupt['projections']! as List,
    );
    final Map<String, Object?> projection = Map<String, Object?>.from(
      projections.single! as Map,
    );
    final Map<String, Object?> event = Map<String, Object?>.from(
      projection['event']! as Map,
    )..['householdId'] = '99999999-9999-4999-8999-999999999999';
    projection['event'] = event;
    corrupt['projections'] = <Object?>[projection];
    readCache.records[ReadCacheSlot.todayCalendar] = ReadCacheRecord(
      householdId: record.householdId,
      payload: corrupt,
      metadata: record.metadata,
    );

    expect(
      await cache.read(
        TodayCalendarRequest(
          householdId: calendarHouseholdId(),
          participantMemberId: null,
        ),
      ),
      isNull,
    );
    expect(readCache.records, isNot(contains(ReadCacheSlot.todayCalendar)));
  });

  test('round-trips an empty Today Calendar snapshot', () async {
    final _MemoryReadCache readCache = _MemoryReadCache();
    final ReadCacheTodayCalendarSnapshotCache cache =
        ReadCacheTodayCalendarSnapshotCache(readCache);
    await cache.write(_snapshot(const <OneTimeCalendarEvent>[]));

    final CachedTodayCalendarSnapshot? restored = await cache.read(
      TodayCalendarRequest(
        householdId: calendarHouseholdId(),
        participantMemberId: null,
      ),
    );

    expect(restored?.snapshot.events, isEmpty);
  });

  test(
    'deletes a snapshot whose validation timestamp is not authoritative',
    () async {
      final _MemoryReadCache readCache = _MemoryReadCache();
      final ReadCacheTodayCalendarSnapshotCache cache =
          ReadCacheTodayCalendarSnapshotCache(readCache);
      await cache.write(
        _snapshot(<OneTimeCalendarEvent>[calendarEventFixture()]),
      );
      final ReadCacheRecord record =
          readCache.records[ReadCacheSlot.todayCalendar]!;
      readCache.records[ReadCacheSlot.todayCalendar] = ReadCacheRecord(
        householdId: record.householdId,
        payload: record.payload,
        metadata: ReadCacheMetadata(
          validatedAt: record.metadata.validatedAt.add(
            const Duration(seconds: 1),
          ),
          expiresAt: record.metadata.expiresAt,
        ),
      );

      expect(
        await cache.read(
          TodayCalendarRequest(
            householdId: calendarHouseholdId(),
            participantMemberId: null,
          ),
        ),
        isNull,
      );
      expect(readCache.records, isNot(contains(ReadCacheSlot.todayCalendar)));
    },
  );
}

TodayCalendarSnapshot _snapshot(List<OneTimeCalendarEvent> events) {
  final CalendarEventPage page = calendarEventPageFixture(
    events: events,
    rangeEndDateExclusive: '2026-08-08',
    limit: 100,
  );
  return TodayCalendarSnapshot.tryCreate(
    householdId: page.householdId,
    householdTimeZone: page.householdTimeZone,
    localDate: page.householdLocalDate,
    generatedAt: page.generatedAt,
    participantMemberId: null,
    events: page.items,
    truncated: false,
  )!;
}

final class _MemoryReadCache implements ReadCache {
  final Map<ReadCacheSlot, ReadCacheRecord> records =
      <ReadCacheSlot, ReadCacheRecord>{};
  var deleteCount = 0;

  @override
  Future<ReadCacheRecord?> read(
    ReadCacheSlot slot, {
    String? expectedHouseholdId,
  }) async {
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
    final DateTime effectiveValidatedAt =
        validatedAt ?? DateTime.parse('2026-08-07T00:00:00Z');
    records[slot] = ReadCacheRecord(
      householdId: householdId,
      payload: payload,
      metadata: ReadCacheMetadata(
        validatedAt: effectiveValidatedAt,
        expiresAt: effectiveValidatedAt.add(const Duration(hours: 2)),
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
    records.clear();
    return true;
  }
}
