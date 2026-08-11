import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

final class ReadCacheTodayCalendarSnapshotCache
    implements TodayCalendarSnapshotCache {
  const ReadCacheTodayCalendarSnapshotCache(this._cache);

  static const int payloadVersion = 1;
  static const Set<String> _snapshotKeys = <String>{
    'payloadVersion',
    'householdId',
    'householdTimezone',
    'householdLocalDate',
    'generatedAt',
    'participantMemberId',
    'truncated',
    'projections',
  };
  static const Set<String> _projectionKeys = <String>{
    'viewLocalDate',
    'viewLocalTime',
    'event',
  };
  static const Set<String> _eventKeys = <String>{
    'householdId',
    'seriesId',
    'occurrenceId',
    'title',
    'description',
    'isAllDay',
    'localStartDate',
    'localStartTime',
    'durationMinutes',
    'allDayEndDateExclusive',
    'timezone',
    'overlapPolicy',
    'startsAt',
    'endsAt',
    'dstResolution',
    'utcOffsetSeconds',
    'participants',
    'version',
    'occurrenceVersion',
    'recurrenceRule',
    'recurrenceLocalStartDate',
    'revisionNumber',
    'isException',
  };
  static const Set<String> _participantKeys = <String>{
    'memberId',
    'displayName',
  };

  final ReadCache _cache;

  @override
  Future<CachedTodayCalendarSnapshot?> read(
    TodayCalendarRequest request,
  ) async {
    final ReadCacheRecord? cached = await _cache.read(
      ReadCacheSlot.todayCalendar,
      expectedHouseholdId: request.householdId.value,
    );
    if (cached == null) {
      return null;
    }
    final TodayCalendarSnapshot? snapshot = _snapshotFromPayload(
      cached.payload,
    );
    if (snapshot == null ||
        snapshot.householdId != request.householdId ||
        cached.householdId != snapshot.householdId.value ||
        cached.metadata.validatedAt != snapshot.generatedAt.dateTime) {
      await _cache.delete(ReadCacheSlot.todayCalendar);
      return null;
    }
    if (snapshot.participantMemberId != request.participantMemberId) {
      return null;
    }
    return CachedTodayCalendarSnapshot(
      snapshot: snapshot,
      metadata: cached.metadata,
    );
  }

  @override
  Future<bool> write(TodayCalendarSnapshot snapshot) {
    return _cache.write(
      ReadCacheSlot.todayCalendar,
      householdId: snapshot.householdId.value,
      payload: _snapshotPayload(snapshot),
      validatedAt: snapshot.generatedAt.dateTime,
    );
  }

  @override
  Future<bool> delete() => _cache.delete(ReadCacheSlot.todayCalendar);

  @override
  Future<bool> clearAll() => _cache.clear();

  Map<String, Object?> _snapshotPayload(TodayCalendarSnapshot snapshot) {
    return <String, Object?>{
      'payloadVersion': payloadVersion,
      'householdId': snapshot.householdId.value,
      'householdTimezone': snapshot.householdTimeZone.value,
      'householdLocalDate': snapshot.localDate.value,
      'generatedAt': snapshot.generatedAt.value,
      'participantMemberId': snapshot.participantMemberId?.value,
      'truncated': snapshot.truncated,
      'projections': snapshot.events
          .map(_projectionPayload)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _projectionPayload(CalendarEventProjection projection) {
    return <String, Object?>{
      'viewLocalDate': projection.viewLocalDate.value,
      'viewLocalTime': projection.viewLocalTime?.value,
      'event': _eventPayload(projection.event),
    };
  }

  Map<String, Object?> _eventPayload(OneTimeCalendarEvent event) {
    return <String, Object?>{
      'householdId': event.householdId.value,
      'seriesId': event.seriesId.value,
      'occurrenceId': event.occurrenceId.value,
      'title': event.title,
      'description': event.description,
      'isAllDay': event.isAllDay,
      'localStartDate': event.localStartDate.value,
      'localStartTime': event.localStartTime?.value,
      'durationMinutes': event.durationMinutes,
      'allDayEndDateExclusive': event.allDayEndDateExclusive?.value,
      'timezone': event.timeZone?.value,
      'overlapPolicy': event.overlapPolicy?.wireValue,
      'startsAt': event.startsAt?.value,
      'endsAt': event.endsAt?.value,
      'dstResolution': event.dstResolution?.wireValue,
      'utcOffsetSeconds': event.utcOffsetSeconds,
      'participants': event.participants
          .map(
            (CalendarEventParticipant participant) => <String, Object?>{
              'memberId': participant.memberId.value,
              'displayName': participant.displayName,
            },
          )
          .toList(growable: false),
      'version': event.version,
      'occurrenceVersion': event.occurrenceVersion,
      'recurrenceRule': event.recurrenceRule?.toJson(),
      'recurrenceLocalStartDate': event.recurrenceLocalStartDate.value,
      'revisionNumber': event.revisionNumber,
      'isException': event.isException,
    };
  }

  TodayCalendarSnapshot? _snapshotFromPayload(Object? raw) {
    final Map<String, Object?>? value = _exactMap(raw, _snapshotKeys);
    if (value == null ||
        value['payloadVersion'] != payloadVersion ||
        value['householdId'] is! String ||
        value['householdTimezone'] is! String ||
        value['householdLocalDate'] is! String ||
        value['generatedAt'] is! String ||
        !_isNullableString(value['participantMemberId']) ||
        value['truncated'] is! bool ||
        value['projections'] is! List) {
      return null;
    }
    final HouseholdId? householdId = HouseholdId.tryParse(
      value['householdId']! as String,
    );
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      value['householdTimezone']! as String,
    );
    final CalendarLocalDate? localDate = CalendarLocalDate.tryParse(
      value['householdLocalDate']! as String,
    );
    final UtcInstant? generatedAt = UtcInstant.tryParse(
      value['generatedAt']! as String,
    );
    final Object? rawParticipantMemberId = value['participantMemberId'];
    final HouseholdMemberId? participantMemberId =
        rawParticipantMemberId == null
        ? null
        : HouseholdMemberId.tryParse(rawParticipantMemberId as String);
    if (householdId == null ||
        householdTimeZone == null ||
        localDate == null ||
        generatedAt == null ||
        rawParticipantMemberId != null && participantMemberId == null) {
      return null;
    }
    final CalendarAllDayRange queryRange = CalendarAllDayRange.tryCreate(
      startDate: localDate,
      endDateExclusive: localDate.addDays(1),
    )!;
    final List<CalendarEventProjection> projections =
        <CalendarEventProjection>[];
    final List<dynamic> rawProjections = value['projections']! as List<dynamic>;
    if (rawProjections.length > 500) {
      return null;
    }
    for (final Object? rawProjection in rawProjections) {
      final CalendarEventProjection? projection = _projectionFromPayload(
        rawProjection,
        expectedHouseholdId: householdId,
        queryRange: queryRange,
      );
      if (projection == null) {
        return null;
      }
      projections.add(projection);
    }
    return TodayCalendarSnapshot.tryCreate(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      localDate: localDate,
      generatedAt: generatedAt,
      participantMemberId: participantMemberId,
      events: projections,
      truncated: value['truncated']! as bool,
    );
  }

  CalendarEventProjection? _projectionFromPayload(
    Object? raw, {
    required HouseholdId expectedHouseholdId,
    required CalendarAllDayRange queryRange,
  }) {
    final Map<String, Object?>? value = _exactMap(raw, _projectionKeys);
    if (value == null ||
        value['viewLocalDate'] is! String ||
        !_isNullableString(value['viewLocalTime'])) {
      return null;
    }
    final CalendarLocalDate? viewLocalDate = CalendarLocalDate.tryParse(
      value['viewLocalDate']! as String,
    );
    final Object? rawViewLocalTime = value['viewLocalTime'];
    final CalendarLocalTime? viewLocalTime = rawViewLocalTime == null
        ? null
        : CalendarLocalTime.tryParse(rawViewLocalTime as String);
    final OneTimeCalendarEvent? event = _eventFromPayload(
      value['event'],
      expectedHouseholdId: expectedHouseholdId,
    );
    if (viewLocalDate == null ||
        rawViewLocalTime != null && viewLocalTime == null ||
        event == null) {
      return null;
    }
    return CalendarEventProjection.tryCreate(
      event: event,
      viewLocalDate: viewLocalDate,
      viewLocalTime: viewLocalTime,
      queryRange: queryRange,
    );
  }

  OneTimeCalendarEvent? _eventFromPayload(
    Object? raw, {
    required HouseholdId expectedHouseholdId,
  }) {
    final Map<String, Object?>? value = _exactMap(raw, _eventKeys);
    if (value == null ||
        value['householdId'] is! String ||
        value['seriesId'] is! String ||
        value['occurrenceId'] is! String ||
        value['title'] is! String ||
        !_isNullableString(value['description']) ||
        value['isAllDay'] is! bool ||
        value['localStartDate'] is! String ||
        !_isNullableString(value['localStartTime']) ||
        !_isNullableInt(value['durationMinutes']) ||
        !_isNullableString(value['allDayEndDateExclusive']) ||
        !_isNullableString(value['timezone']) ||
        !_isNullableString(value['overlapPolicy']) ||
        !_isNullableString(value['startsAt']) ||
        !_isNullableString(value['endsAt']) ||
        !_isNullableString(value['dstResolution']) ||
        !_isNullableInt(value['utcOffsetSeconds']) ||
        value['participants'] is! List ||
        value['version'] is! int ||
        value['occurrenceVersion'] is! int ||
        value['recurrenceLocalStartDate'] is! String ||
        value['revisionNumber'] is! int ||
        value['isException'] is! bool) {
      return null;
    }
    final HouseholdId? householdId = HouseholdId.tryParse(
      value['householdId']! as String,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      value['seriesId']! as String,
    );
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(value['occurrenceId']! as String);
    final CalendarLocalDate? localStartDate = CalendarLocalDate.tryParse(
      value['localStartDate']! as String,
    );
    final CalendarLocalTime? localStartTime = _parseOptional(
      value['localStartTime'],
      CalendarLocalTime.tryParse,
    );
    final CalendarLocalDate? allDayEndDateExclusive = _parseOptional(
      value['allDayEndDateExclusive'],
      CalendarLocalDate.tryParse,
    );
    final IanaTimeZoneId? timeZone = _parseOptional(
      value['timezone'],
      IanaTimeZoneId.tryParse,
    );
    final CalendarDstOverlapPolicy? overlapPolicy = _parseOptional(
      value['overlapPolicy'],
      CalendarDstOverlapPolicy.tryParse,
    );
    final UtcInstant? startsAt = _parseOptional(
      value['startsAt'],
      UtcInstant.tryParse,
    );
    final UtcInstant? endsAt = _parseOptional(
      value['endsAt'],
      UtcInstant.tryParse,
    );
    final CalendarTimeResolutionKind? dstResolution = _parseOptional(
      value['dstResolution'],
      CalendarTimeResolutionKind.tryParse,
    );
    final CalendarLocalDate? recurrenceLocalStartDate =
        CalendarLocalDate.tryParse(
          value['recurrenceLocalStartDate']! as String,
        );
    final Object? rawRecurrenceRule = value['recurrenceRule'];
    final CalendarRecurrenceRule? recurrenceRule = rawRecurrenceRule == null
        ? null
        : CalendarRecurrenceRule.tryParse(rawRecurrenceRule);
    if (householdId != expectedHouseholdId ||
        seriesId == null ||
        occurrenceId == null ||
        localStartDate == null ||
        value['localStartTime'] != null && localStartTime == null ||
        value['allDayEndDateExclusive'] != null &&
            allDayEndDateExclusive == null ||
        value['timezone'] != null && timeZone == null ||
        value['overlapPolicy'] != null && overlapPolicy == null ||
        value['startsAt'] != null && startsAt == null ||
        value['endsAt'] != null && endsAt == null ||
        value['dstResolution'] != null && dstResolution == null ||
        recurrenceLocalStartDate == null ||
        rawRecurrenceRule != null && recurrenceRule == null) {
      return null;
    }
    final List<CalendarEventParticipant>? participants =
        _participantsFromPayload(value['participants']);
    if (participants == null) {
      return null;
    }
    return OneTimeCalendarEvent.tryCreate(
      householdId: householdId!,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      title: value['title']! as String,
      description: value['description'] as String?,
      isAllDay: value['isAllDay']! as bool,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: value['durationMinutes'] as int?,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      startsAt: startsAt,
      endsAt: endsAt,
      dstResolution: dstResolution,
      utcOffsetSeconds: value['utcOffsetSeconds'] as int?,
      participants: participants,
      version: value['version']! as int,
      occurrenceVersion: value['occurrenceVersion']! as int,
      recurrenceRule: recurrenceRule,
      recurrenceLocalStartDate: recurrenceLocalStartDate,
      revisionNumber: value['revisionNumber']! as int,
      isException: value['isException']! as bool,
    );
  }

  List<CalendarEventParticipant>? _participantsFromPayload(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.length > 50) {
      return null;
    }
    final List<CalendarEventParticipant> participants =
        <CalendarEventParticipant>[];
    for (final Object? rawParticipant in raw) {
      final Map<String, Object?>? value = _exactMap(
        rawParticipant,
        _participantKeys,
      );
      if (value == null ||
          value['memberId'] is! String ||
          value['displayName'] is! String) {
        return null;
      }
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
        value['memberId']! as String,
      );
      final CalendarEventParticipant? participant = memberId == null
          ? null
          : CalendarEventParticipant.tryCreate(
              memberId: memberId,
              displayName: value['displayName']! as String,
            );
      if (participant == null) {
        return null;
      }
      participants.add(participant);
    }
    return participants;
  }

  Map<String, Object?>? _exactMap(Object? raw, Set<String> keys) {
    if (raw is! Map || raw.keys.any((Object? key) => key is! String)) {
      return null;
    }
    final Map<String, Object?> value = Map<String, Object?>.from(raw);
    return value.length == keys.length && value.keys.toSet().containsAll(keys)
        ? value
        : null;
  }

  bool _isNullableString(Object? value) => value == null || value is String;

  bool _isNullableInt(Object? value) => value == null || value is int;

  T? _parseOptional<T>(Object? raw, T? Function(String value) parse) {
    return raw == null ? null : parse(raw as String);
  }
}
