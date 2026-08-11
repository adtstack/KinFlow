enum CalendarDataFailureKind {
  unauthenticated,
  invalidInput,
  notFoundOrForbidden,
  idempotencyConflict,
  staleVersion,
  nonexistentLocalTime,
  transitionNotAllowed,
  featurePolicyUnavailable,
  featureLimitReached,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class CalendarEventDataRecord {
  CalendarEventDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.description,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timezone,
    required this.overlapPolicy,
    required this.startsAt,
    required this.endsAt,
    required this.dstResolution,
    required this.utcOffsetSeconds,
    required List<String> participantMemberIds,
    required List<String> participantDisplayNames,
    required this.version,
    required this.occurrenceVersion,
    Map<String, Object?>? recurrenceRule,
    this.recurrenceLocalStartDate,
    this.revisionNumber = 1,
    this.isException = false,
  }) : participantMemberIds = List<String>.unmodifiable(participantMemberIds),
       participantDisplayNames = List<String>.unmodifiable(
         participantDisplayNames,
       ),
       recurrenceRule = recurrenceRule == null
           ? null
           : Map<String, Object?>.unmodifiable(recurrenceRule);

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String title;
  final String? description;
  final bool isAllDay;
  final String localStartDate;
  final String? localStartTime;
  final int? durationMinutes;
  final String? allDayEndDateExclusive;
  final String? timezone;
  final String? overlapPolicy;
  final String? startsAt;
  final String? endsAt;
  final String? dstResolution;
  final int? utcOffsetSeconds;
  final List<String> participantMemberIds;
  final List<String> participantDisplayNames;
  final int version;
  final int occurrenceVersion;
  final Map<String, Object?>? recurrenceRule;
  final String? recurrenceLocalStartDate;
  final int revisionNumber;
  final bool isException;
}

final class CalendarEventListDataRecord {
  CalendarEventListDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required List<CalendarEventDataRecord> events,
  }) : events = List<CalendarEventDataRecord>.unmodifiable(events);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final List<CalendarEventDataRecord> events;
}

final class CalendarEventProjectionDataRecord {
  const CalendarEventProjectionDataRecord({
    required this.event,
    required this.viewLocalDate,
    required this.viewLocalTime,
  });

  final CalendarEventDataRecord event;
  final String viewLocalDate;
  final String? viewLocalTime;
}

final class CalendarEventPageDataRecord {
  CalendarEventPageDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.viewMode,
    required this.rangeStartDate,
    required this.rangeEndDateExclusive,
    required this.pageLimit,
    required this.hasMore,
    required this.pageCursor,
    required List<CalendarEventProjectionDataRecord> items,
  }) : items = List<CalendarEventProjectionDataRecord>.unmodifiable(items);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String generatedAt;
  final String viewMode;
  final String rangeStartDate;
  final String rangeEndDateExclusive;
  final int pageLimit;
  final bool hasMore;
  final String? pageCursor;
  final List<CalendarEventProjectionDataRecord> items;
}

final class CalendarMonthDayDataRecord {
  const CalendarMonthDayDataRecord({
    required this.date,
    required this.eventCount,
    required this.allDayCount,
    required this.timedCount,
  });

  final String date;
  final int eventCount;
  final int allDayCount;
  final int timedCount;
}

final class CalendarMonthSummaryDataRecord {
  CalendarMonthSummaryDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.monthStartDate,
    required this.monthEndDateExclusive,
    required List<CalendarMonthDayDataRecord> days,
  }) : days = List<CalendarMonthDayDataRecord>.unmodifiable(days);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String generatedAt;
  final String monthStartDate;
  final String monthEndDateExclusive;
  final List<CalendarMonthDayDataRecord> days;
}

final class CalendarOccurrenceLocatorDataRecord {
  const CalendarOccurrenceLocatorDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.seriesId,
    required this.occurrenceId,
    required this.viewLocalDate,
    required this.seriesVersion,
    required this.occurrenceVersion,
  });

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String generatedAt;
  final String seriesId;
  final String occurrenceId;
  final String viewLocalDate;
  final int seriesVersion;
  final int occurrenceVersion;
}

final class CalendarOverlapConflictDataRecord {
  CalendarOverlapConflictDataRecord({
    required this.candidateLocalStartDate,
    required this.seriesId,
    required this.occurrenceId,
    required this.title,
    required this.isAllDay,
    required this.viewLocalStartDate,
    required this.viewLocalStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required List<String> participantMemberIds,
    required List<String> participantDisplayNames,
  }) : participantMemberIds = List<String>.unmodifiable(participantMemberIds),
       participantDisplayNames = List<String>.unmodifiable(
         participantDisplayNames,
       );

  final String candidateLocalStartDate;
  final String seriesId;
  final String occurrenceId;
  final String title;
  final bool isAllDay;
  final String viewLocalStartDate;
  final String? viewLocalStartTime;
  final int? durationMinutes;
  final String? allDayEndDateExclusive;
  final List<String> participantMemberIds;
  final List<String> participantDisplayNames;
}

final class CalendarOverlapPreviewDataRecord {
  CalendarOverlapPreviewDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.generatedAt,
    required this.checkedFromLocalDate,
    required this.checkedThroughLocalDate,
    required this.candidateOccurrenceCount,
    required this.totalConflictCount,
    required this.truncated,
    required List<CalendarOverlapConflictDataRecord> conflicts,
  }) : conflicts = List<CalendarOverlapConflictDataRecord>.unmodifiable(
         conflicts,
       );

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String generatedAt;
  final String checkedFromLocalDate;
  final String checkedThroughLocalDate;
  final int candidateOccurrenceCount;
  final int totalConflictCount;
  final bool truncated;
  final List<CalendarOverlapConflictDataRecord> conflicts;
}

final class CalendarEventDeletionDataRecord {
  const CalendarEventDeletionDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.version,
    required this.occurrenceVersion,
    required this.deleted,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final int version;
  final int occurrenceVersion;
  final bool deleted;
  final bool changed;
}

final class RecurringCalendarEventDataRecord {
  RecurringCalendarEventDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.firstOccurrenceId,
    required Map<String, Object?> recurrenceRule,
    required this.materializedThrough,
    required this.materializedCount,
    required this.version,
    required this.created,
  }) : recurrenceRule = Map<String, Object?>.unmodifiable(recurrenceRule);

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String seriesId;
  final String firstOccurrenceId;
  final Map<String, Object?> recurrenceRule;
  final String materializedThrough;
  final int materializedCount;
  final int version;
  final bool created;
}

final class CalendarRecurringSeriesDetailDataRecord {
  CalendarRecurringSeriesDetailDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.title,
    required this.description,
    required this.isAllDay,
    required this.localStartDate,
    required this.localStartTime,
    required this.durationMinutes,
    required this.allDayEndDateExclusive,
    required this.timezone,
    required this.overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
    required List<String> participantDisplayNames,
    required this.version,
  }) : recurrenceRule = Map<String, Object?>.unmodifiable(recurrenceRule),
       participantMemberIds = List<String>.unmodifiable(participantMemberIds),
       participantDisplayNames = List<String>.unmodifiable(
         participantDisplayNames,
       );

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String seriesId;
  final String revisionId;
  final int revisionNumber;
  final String title;
  final String? description;
  final bool isAllDay;
  final String localStartDate;
  final String? localStartTime;
  final int? durationMinutes;
  final String? allDayEndDateExclusive;
  final String? timezone;
  final String? overlapPolicy;
  final Map<String, Object?> recurrenceRule;
  final List<String> participantMemberIds;
  final List<String> participantDisplayNames;
  final int version;
}

final class CalendarRecurringSeriesUpdateDataRecord {
  const CalendarRecurringSeriesUpdateDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.revisionId,
    required this.revisionNumber,
    required this.effectiveLocalDate,
    required this.materializedThrough,
    required this.version,
    required this.rebuiltCount,
    required this.cancelledCount,
    required this.preservedExceptionCount,
    required this.changed,
  });

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String seriesId;
  final String revisionId;
  final int revisionNumber;
  final String effectiveLocalDate;
  final String materializedThrough;
  final int version;
  final int rebuiltCount;
  final int cancelledCount;
  final int preservedExceptionCount;
  final bool changed;
}

final class CalendarRecurringSeriesCancellationDataRecord {
  const CalendarRecurringSeriesCancellationDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedPastCount,
    required this.changed,
  });

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedPastCount;
  final bool changed;
}

final class CalendarRecurringSeriesFromOccurrenceCancellationDataRecord {
  const CalendarRecurringSeriesFromOccurrenceCancellationDataRecord({
    required this.householdId,
    required this.householdTimezone,
    required this.householdLocalDate,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.cancelledCount,
    required this.preservedPastCount,
    required this.terminalRevisionId,
    required this.terminalRevisionNumber,
    required this.changed,
  });

  final String householdId;
  final String householdTimezone;
  final String householdLocalDate;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int cancelledCount;
  final int preservedPastCount;
  final String? terminalRevisionId;
  final int? terminalRevisionNumber;
  final bool changed;
}

final class CalendarRecurringSeriesCancellationResumeDataRecord {
  const CalendarRecurringSeriesCancellationResumeDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.effectiveLocalDate,
    required this.version,
    required this.restoredCount,
    required this.preservedPastCount,
    required this.revisionId,
    required this.revisionNumber,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String effectiveLocalDate;
  final int version;
  final int restoredCount;
  final int preservedPastCount;
  final String revisionId;
  final int revisionNumber;
  final bool changed;
}

final class CalendarOccurrenceCommandDataRecord {
  const CalendarOccurrenceCommandDataRecord({
    required this.householdId,
    required this.seriesId,
    required this.occurrenceId,
    required this.revisionId,
    required this.occurrenceVersion,
    required this.exceptionVersion,
    required this.cancelled,
    required this.changed,
  });

  final String householdId;
  final String seriesId;
  final String occurrenceId;
  final String? revisionId;
  final int occurrenceVersion;
  final int exceptionVersion;
  final bool cancelled;
  final bool changed;
}

abstract interface class CalendarDataSource {
  Future<CalendarDataResult<CalendarEventPageDataRecord>> loadEventPage({
    required String householdId,
    required String viewMode,
    required String? rangeStartDate,
    required String? rangeEndDateExclusive,
    required int limit,
    required String? afterCursor,
  });

  Future<CalendarDataResult<CalendarMonthSummaryDataRecord>> loadMonthSummary({
    required String householdId,
    required String monthStartDate,
  });

  Future<CalendarDataResult<CalendarOccurrenceLocatorDataRecord>>
  loadOccurrenceLocator({
    required String householdId,
    required String occurrenceId,
  });

  Future<CalendarDataResult<CalendarOverlapPreviewDataRecord>> previewOverlaps({
    required String householdId,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?>? recurrenceRule,
    required String windowStartDate,
    required List<String> participantMemberIds,
    required String? excludedSeriesId,
    required String? excludedOccurrenceId,
    required int limit,
  });

  Future<CalendarDataResult<CalendarEventListDataRecord>> loadOneTimeEvents({
    required String householdId,
    required int limit,
  });

  Future<CalendarDataResult<CalendarEventDataRecord>> createOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<RecurringCalendarEventDataRecord>>
  createRecurringEvent({
    required String idempotencyKey,
    required String householdId,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<CalendarRecurringSeriesDetailDataRecord>>
  loadRecurringSeries({required String householdId, required String seriesId});

  Future<CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>>
  updateRecurringSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>>
  updateRecurringSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required Map<String, Object?> recurrenceRule,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>>
  cancelRecurringSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  });

  Future<
    CalendarDataResult<
      CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
    >
  >
  cancelRecurringSeriesFromOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String effectiveOccurrenceId,
    required int expectedVersion,
  });

  Future<
    CalendarDataResult<CalendarRecurringSeriesCancellationResumeDataRecord>
  >
  resumeRecurringSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  });

  Future<CalendarDataResult<CalendarEventDataRecord>> updateOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<CalendarEventDeletionDataRecord>>
  deleteOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  });

  Future<CalendarDataResult<CalendarOccurrenceCommandDataRecord>>
  updateRecurringOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedOccurrenceVersion,
    required String title,
    required String? description,
    required bool isAllDay,
    required String localStartDate,
    required String? localStartTime,
    required int? durationMinutes,
    required String? allDayEndDateExclusive,
    required String? timezone,
    required String? overlapPolicy,
    required List<String> participantMemberIds,
  });

  Future<CalendarDataResult<CalendarOccurrenceCommandDataRecord>>
  cancelRecurringOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedOccurrenceVersion,
  });
}

sealed class CalendarDataResult<T> {
  const CalendarDataResult();
}

final class CalendarDataSucceeded<T> extends CalendarDataResult<T> {
  const CalendarDataSucceeded(this.value);

  final T value;
}

final class CalendarDataFailed<T> extends CalendarDataResult<T> {
  const CalendarDataFailed(this.kind);

  final CalendarDataFailureKind kind;
}
