import 'package:kinflow_app/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_occurrence_locator.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderCalendarRepository implements CalendarRepository {
  const ProviderCalendarRepository(this._dataSource);

  final CalendarDataSource _dataSource;

  @override
  Future<LoadCalendarEventPageResult> loadEventPage(
    CalendarEventPageRequest request,
  ) async {
    final CalendarAllDayRange? range = request.range;
    final CalendarDataResult<CalendarEventPageDataRecord> result =
        await _dataSource.loadEventPage(
          householdId: request.householdId.value,
          viewMode: request.view.wireValue,
          rangeStartDate: range?.startDate.value,
          rangeEndDateExclusive: range?.endDateExclusive.value,
          limit: request.limit,
          afterCursor: request.cursor?.value,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarEventPageDataRecord>(:final value) =>
        _mapEventPage(value, request),
      CalendarDataFailed<CalendarEventPageDataRecord>(:final kind) =>
        LoadCalendarEventPageFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadCalendarMonthSummaryResult> loadMonthSummary(
    CalendarMonthSummaryRequest request,
  ) async {
    final CalendarDataResult<CalendarMonthSummaryDataRecord> result =
        await _dataSource.loadMonthSummary(
          householdId: request.householdId.value,
          monthStartDate: request.monthStartDate.value,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarMonthSummaryDataRecord>(:final value) =>
        _mapMonthSummary(value, request),
      CalendarDataFailed<CalendarMonthSummaryDataRecord>(:final kind) =>
        LoadCalendarMonthSummaryFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<LoadCalendarOccurrenceLocatorResult> loadOccurrenceLocator({
    required HouseholdId householdId,
    required CalendarEventOccurrenceId occurrenceId,
  }) async {
    final CalendarDataResult<CalendarOccurrenceLocatorDataRecord> result =
        await _dataSource.loadOccurrenceLocator(
          householdId: householdId.value,
          occurrenceId: occurrenceId.value,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarOccurrenceLocatorDataRecord>(
        :final value,
      ) =>
        _mapOccurrenceLocator(value, householdId, occurrenceId),
      CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(:final kind) =>
        LoadCalendarOccurrenceLocatorFailed(_mapFailure(kind)),
    };
  }

  LoadCalendarOccurrenceLocatorResult _mapOccurrenceLocator(
    CalendarOccurrenceLocatorDataRecord record,
    HouseholdId expectedHouseholdId,
    CalendarEventOccurrenceId expectedOccurrenceId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final UtcInstant? generatedAt = UtcInstant.tryParse(record.generatedAt);
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(record.occurrenceId);
    final CalendarLocalDate? viewLocalDate = CalendarLocalDate.tryParse(
      record.viewLocalDate,
    );
    if (householdId != expectedHouseholdId ||
        occurrenceId != expectedOccurrenceId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        generatedAt == null ||
        seriesId == null ||
        viewLocalDate == null) {
      return const LoadCalendarOccurrenceLocatorFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final CalendarOccurrenceLocator? locator =
        CalendarOccurrenceLocator.tryCreate(
          householdId: householdId!,
          householdTimeZone: householdTimeZone,
          householdLocalDate: householdLocalDate,
          generatedAt: generatedAt,
          seriesId: seriesId,
          occurrenceId: occurrenceId!,
          viewLocalDate: viewLocalDate,
          seriesVersion: record.seriesVersion,
          occurrenceVersion: record.occurrenceVersion,
        );
    return locator == null
        ? const LoadCalendarOccurrenceLocatorFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : CalendarOccurrenceLocatorLoaded(locator);
  }

  @override
  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) async {
    final CalendarDataResult<CalendarOverlapPreviewDataRecord> result =
        await _dataSource.previewOverlaps(
          householdId: request.householdId.value,
          isAllDay: request.isAllDay,
          localStartDate: request.localStartDate.value,
          localStartTime: request.localStartTime?.value,
          durationMinutes: request.durationMinutes,
          allDayEndDateExclusive: request.allDayEndDateExclusive?.value,
          timezone: request.timeZone?.value,
          overlapPolicy: request.overlapPolicy?.wireValue,
          recurrenceRule: request.recurrenceRule?.toJson(),
          windowStartDate: request.windowStartDate.value,
          participantMemberIds: request.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
          excludedSeriesId: request.excludedSeriesId?.value,
          excludedOccurrenceId: request.excludedOccurrenceId?.value,
          limit: calendarOverlapPreviewLimit,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarOverlapPreviewDataRecord>(:final value) =>
        _mapOverlapPreview(value, request),
      CalendarDataFailed<CalendarOverlapPreviewDataRecord>(:final kind) =>
        PreviewCalendarOverlapsFailed(_mapFailure(kind)),
    };
  }

  PreviewCalendarOverlapsResult _mapOverlapPreview(
    CalendarOverlapPreviewDataRecord record,
    CalendarOverlapPreviewRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final UtcInstant? generatedAt = UtcInstant.tryParse(record.generatedAt);
    final CalendarLocalDate? checkedFrom = CalendarLocalDate.tryParse(
      record.checkedFromLocalDate,
    );
    final CalendarLocalDate? checkedThrough = CalendarLocalDate.tryParse(
      record.checkedThroughLocalDate,
    );
    final CalendarLocalDate expectedThrough = request.recurrenceRule == null
        ? request.windowStartDate
        : request.windowStartDate.addDays(365);
    if (householdId != request.householdId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        generatedAt == null ||
        checkedFrom != request.windowStartDate ||
        checkedThrough != expectedThrough ||
        request.recurrenceRule == null &&
            record.candidateOccurrenceCount != 1) {
      return const PreviewCalendarOverlapsFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final List<CalendarOverlapConflict> conflicts = <CalendarOverlapConflict>[];
    for (final CalendarOverlapConflictDataRecord item in record.conflicts) {
      final CalendarLocalDate? candidateDate = CalendarLocalDate.tryParse(
        item.candidateLocalStartDate,
      );
      final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
        item.seriesId,
      );
      final CalendarEventOccurrenceId? occurrenceId =
          CalendarEventOccurrenceId.tryParse(item.occurrenceId);
      final CalendarLocalDate? viewDate = CalendarLocalDate.tryParse(
        item.viewLocalStartDate,
      );
      final CalendarLocalTime? viewTime = item.viewLocalStartTime == null
          ? null
          : CalendarLocalTime.tryParse(item.viewLocalStartTime!);
      final CalendarLocalDate? allDayEnd = item.allDayEndDateExclusive == null
          ? null
          : CalendarLocalDate.tryParse(item.allDayEndDateExclusive!);
      if (candidateDate == null ||
          seriesId == null ||
          occurrenceId == null ||
          viewDate == null ||
          item.viewLocalStartTime != null && viewTime == null ||
          item.allDayEndDateExclusive != null && allDayEnd == null ||
          item.participantMemberIds.length !=
              item.participantDisplayNames.length) {
        return const PreviewCalendarOverlapsFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      final List<CalendarOverlapParticipant> participants =
          <CalendarOverlapParticipant>[];
      for (
        var index = 0;
        index < item.participantMemberIds.length;
        index += 1
      ) {
        final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
          item.participantMemberIds[index],
        );
        final CalendarOverlapParticipant? participant = memberId == null
            ? null
            : CalendarOverlapParticipant.tryCreate(
                memberId: memberId,
                displayName: item.participantDisplayNames[index],
              );
        if (participant == null) {
          return const PreviewCalendarOverlapsFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          );
        }
        participants.add(participant);
      }
      final CalendarOverlapConflict? conflict =
          CalendarOverlapConflict.tryCreate(
            candidateLocalStartDate: candidateDate,
            seriesId: seriesId,
            occurrenceId: occurrenceId,
            title: item.title,
            isAllDay: item.isAllDay,
            viewLocalStartDate: viewDate,
            viewLocalStartTime: viewTime,
            durationMinutes: item.durationMinutes,
            allDayEndDateExclusive: allDayEnd,
            participants: participants,
          );
      if (conflict == null) {
        return const PreviewCalendarOverlapsFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      conflicts.add(conflict);
    }
    final CalendarOverlapPreview? preview = CalendarOverlapPreview.tryCreate(
      householdId: householdId!,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      checkedFromLocalDate: checkedFrom!,
      checkedThroughLocalDate: checkedThrough!,
      candidateOccurrenceCount: record.candidateOccurrenceCount,
      totalConflictCount: record.totalConflictCount,
      truncated: record.truncated,
      conflicts: conflicts,
    );
    return preview == null
        ? const PreviewCalendarOverlapsFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : CalendarOverlapsPreviewed(preview);
  }

  @override
  Future<LoadOneTimeCalendarEventsResult> loadOneTimeEvents(
    HouseholdId householdId,
  ) async {
    final CalendarDataResult<CalendarEventListDataRecord> result =
        await _dataSource.loadOneTimeEvents(
          householdId: householdId.value,
          limit: 100,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarEventListDataRecord>(:final value) =>
        _mapList(value, householdId),
      CalendarDataFailed<CalendarEventListDataRecord>(:final kind) =>
        LoadOneTimeCalendarEventsFailed(_mapFailure(kind)),
    };
  }

  LoadCalendarEventPageResult _mapEventPage(
    CalendarEventPageDataRecord record,
    CalendarEventPageRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final UtcInstant? generatedAt = UtcInstant.tryParse(record.generatedAt);
    final CalendarViewMode? view = CalendarViewMode.tryParse(record.viewMode);
    final CalendarLocalDate? rangeStart = CalendarLocalDate.tryParse(
      record.rangeStartDate,
    );
    final CalendarLocalDate? rangeEnd = CalendarLocalDate.tryParse(
      record.rangeEndDateExclusive,
    );
    final CalendarAllDayRange? range = rangeStart == null || rangeEnd == null
        ? null
        : CalendarAllDayRange.tryCreate(
            startDate: rangeStart,
            endDateExclusive: rangeEnd,
          );
    final CalendarPageCursor? nextCursor = record.pageCursor == null
        ? null
        : CalendarPageCursor.tryParse(record.pageCursor!);
    final CalendarEventPageRequest? resolvedRequest = range == null
        ? null
        : request.resolveRange(range);
    if (householdId != request.householdId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        generatedAt == null ||
        view != request.view ||
        view == CalendarViewMode.month ||
        range == null ||
        resolvedRequest == null ||
        record.pageLimit != request.limit ||
        (request.range == null &&
            (request.view != CalendarViewMode.agenda ||
                range.startDate != householdLocalDate ||
                range.dayCount != 90)) ||
        (record.pageCursor != null && nextCursor == null)) {
      return const LoadCalendarEventPageFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final List<CalendarEventProjection> items = <CalendarEventProjection>[];
    for (final CalendarEventProjectionDataRecord item in record.items) {
      final OneTimeCalendarEvent? event = _mapEvent(
        item.event,
        request.householdId,
      );
      final CalendarLocalDate? viewLocalDate = CalendarLocalDate.tryParse(
        item.viewLocalDate,
      );
      final CalendarLocalTime? viewLocalTime = item.viewLocalTime == null
          ? null
          : CalendarLocalTime.tryParse(item.viewLocalTime!);
      if (event == null ||
          viewLocalDate == null ||
          (item.viewLocalTime != null && viewLocalTime == null)) {
        return const LoadCalendarEventPageFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      final CalendarEventProjection? projection =
          CalendarEventProjection.tryCreate(
            event: event,
            viewLocalDate: viewLocalDate,
            viewLocalTime: viewLocalTime,
            queryRange: range,
          );
      if (projection == null) {
        return const LoadCalendarEventPageFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      items.add(projection);
    }
    final CalendarEventPage? page = CalendarEventPage.tryCreate(
      request: resolvedRequest,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      items: items,
      hasMore: record.hasMore,
      nextCursor: nextCursor,
    );
    return page == null
        ? const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : CalendarEventPageLoaded(page);
  }

  LoadCalendarMonthSummaryResult _mapMonthSummary(
    CalendarMonthSummaryDataRecord record,
    CalendarMonthSummaryRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final UtcInstant? generatedAt = UtcInstant.tryParse(record.generatedAt);
    final CalendarLocalDate? monthStart = CalendarLocalDate.tryParse(
      record.monthStartDate,
    );
    final CalendarLocalDate? monthEnd = CalendarLocalDate.tryParse(
      record.monthEndDateExclusive,
    );
    if (householdId != request.householdId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        generatedAt == null ||
        monthStart != request.monthStartDate ||
        monthEnd == null) {
      return const LoadCalendarMonthSummaryFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final List<CalendarMonthDaySummary> days = <CalendarMonthDaySummary>[];
    for (final CalendarMonthDayDataRecord item in record.days) {
      final CalendarLocalDate? date = CalendarLocalDate.tryParse(item.date);
      final CalendarMonthDaySummary? day = date == null
          ? null
          : CalendarMonthDaySummary.tryCreate(
              date: date,
              eventCount: item.eventCount,
              allDayCount: item.allDayCount,
              timedCount: item.timedCount,
            );
      if (day == null) {
        return const LoadCalendarMonthSummaryFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      days.add(day);
    }
    final CalendarMonthSummary? summary = CalendarMonthSummary.tryCreate(
      request: request,
      householdTimeZone: householdTimeZone,
      householdLocalDate: householdLocalDate,
      generatedAt: generatedAt,
      monthEndDateExclusive: monthEnd,
      days: days,
    );
    return summary == null
        ? const LoadCalendarMonthSummaryFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : CalendarMonthSummaryLoaded(summary);
  }

  @override
  Future<CreateOneTimeCalendarEventResult> createOneTimeEvent(
    CreateOneTimeCalendarEventRequest request,
  ) async {
    final OneTimeCalendarEventDraft draft = request.draft;
    final CalendarDataResult<CalendarEventDataRecord> result = await _dataSource
        .createOneTimeEvent(
          idempotencyKey: request.idempotencyKey.value,
          householdId: draft.householdId.value,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarEventDataRecord>(:final value) =>
        _mapCreatedEvent(value, draft.householdId),
      CalendarDataFailed<CalendarEventDataRecord>(:final kind) =>
        CreateOneTimeCalendarEventFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CreateRecurringCalendarEventResult> createRecurringEvent(
    CreateRecurringCalendarEventRequest request,
  ) async {
    final RecurringCalendarEventDraft recurringDraft = request.draft;
    final OneTimeCalendarEventDraft draft = recurringDraft.event;
    final CalendarDataResult<RecurringCalendarEventDataRecord> result =
        await _dataSource.createRecurringEvent(
          idempotencyKey: request.idempotencyKey.value,
          householdId: draft.householdId.value,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          recurrenceRule: recurringDraft.recurrenceRule.toJson(),
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<RecurringCalendarEventDataRecord>(:final value) =>
        _mapRecurringSnapshot(value, request),
      CalendarDataFailed<RecurringCalendarEventDataRecord>(:final kind) =>
        CreateRecurringCalendarEventFailed(_mapFailure(kind)),
    };
  }

  CreateRecurringCalendarEventResult _mapRecurringSnapshot(
    RecurringCalendarEventDataRecord record,
    CreateRecurringCalendarEventRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventOccurrenceId? firstOccurrenceId =
        CalendarEventOccurrenceId.tryParse(record.firstOccurrenceId);
    final CalendarRecurrenceRule? recurrenceRule =
        CalendarRecurrenceRule.tryParse(record.recurrenceRule);
    final CalendarLocalDate? materializedThrough = CalendarLocalDate.tryParse(
      record.materializedThrough,
    );
    if (householdId != request.draft.householdId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        seriesId == null ||
        firstOccurrenceId == null ||
        recurrenceRule != request.draft.recurrenceRule ||
        materializedThrough == null ||
        materializedThrough.compareTo(request.draft.event.localStartDate) < 0) {
      return const CreateRecurringCalendarEventFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final RecurringCalendarEventSnapshot? snapshot =
        RecurringCalendarEventSnapshot.tryCreate(
          householdId: householdId!,
          seriesId: seriesId,
          firstOccurrenceId: firstOccurrenceId,
          recurrenceRule: recurrenceRule!,
          materializedThrough: materializedThrough,
          materializedCount: record.materializedCount,
          version: record.version,
          created: record.created,
        );
    return snapshot == null
        ? const CreateRecurringCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarEventCreated(snapshot);
  }

  @override
  Future<LoadRecurringCalendarSeriesResult> loadRecurringSeries({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  }) async {
    final CalendarDataResult<CalendarRecurringSeriesDetailDataRecord> result =
        await _dataSource.loadRecurringSeries(
          householdId: householdId.value,
          seriesId: seriesId.value,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarRecurringSeriesDetailDataRecord>(
        :final value,
      ) =>
        _mapRecurringSeriesDetail(value, householdId, seriesId),
      CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
        :final kind,
      ) =>
        LoadRecurringCalendarSeriesFailed(_mapFailure(kind)),
    };
  }

  LoadRecurringCalendarSeriesResult _mapRecurringSeriesDetail(
    CalendarRecurringSeriesDetailDataRecord record,
    HouseholdId expectedHouseholdId,
    CalendarEventSeriesId expectedSeriesId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventRevisionId? revisionId =
        CalendarEventRevisionId.tryParse(record.revisionId);
    final CalendarLocalDate? localStartDate = CalendarLocalDate.tryParse(
      record.localStartDate,
    );
    final CalendarLocalTime? localStartTime = record.localStartTime == null
        ? null
        : CalendarLocalTime.tryParse(record.localStartTime!);
    final CalendarLocalDate? allDayEndDate =
        record.allDayEndDateExclusive == null
        ? null
        : CalendarLocalDate.tryParse(record.allDayEndDateExclusive!);
    final IanaTimeZoneId? timeZone = record.timezone == null
        ? null
        : IanaTimeZoneId.tryParse(record.timezone!);
    final CalendarDstOverlapPolicy? overlapPolicy = record.overlapPolicy == null
        ? null
        : CalendarDstOverlapPolicy.tryParse(record.overlapPolicy!);
    final CalendarRecurrenceRule? recurrenceRule =
        CalendarRecurrenceRule.tryParse(record.recurrenceRule);
    final List<HouseholdMemberId> participantIds = <HouseholdMemberId>[];
    for (final String rawId in record.participantMemberIds) {
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(rawId);
      if (memberId == null) {
        return const LoadRecurringCalendarSeriesFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      participantIds.add(memberId);
    }
    if (householdId != expectedHouseholdId ||
        seriesId != expectedSeriesId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        revisionId == null ||
        localStartDate == null ||
        (record.localStartTime != null && localStartTime == null) ||
        (record.allDayEndDateExclusive != null && allDayEndDate == null) ||
        (record.timezone != null && timeZone == null) ||
        (record.overlapPolicy != null && overlapPolicy == null) ||
        recurrenceRule == null) {
      return const LoadRecurringCalendarSeriesFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final OneTimeCalendarEventDraft? event =
        OneTimeCalendarEventDraft.tryCreate(
          householdId: householdId!,
          title: record.title,
          description: record.description ?? '',
          isAllDay: record.isAllDay,
          localStartDate: localStartDate,
          localStartTime: localStartTime,
          durationMinutes: record.durationMinutes,
          allDayEndDateExclusive: allDayEndDate,
          timeZone: timeZone,
          overlapPolicy: overlapPolicy,
          participantMemberIds: participantIds,
        );
    final RecurringCalendarSeriesDetail? detail = event == null
        ? null
        : RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: householdTimeZone,
            householdLocalDate: householdLocalDate,
            seriesId: seriesId!,
            revisionId: revisionId,
            revisionNumber: record.revisionNumber,
            event: event,
            recurrenceRule: recurrenceRule,
            participantDisplayNames: record.participantDisplayNames,
            version: record.version,
          );
    return detail == null
        ? const LoadRecurringCalendarSeriesFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarSeriesLoaded(detail);
  }

  @override
  Future<UpdateRecurringCalendarSeriesResult> updateRecurringSeries(
    UpdateRecurringCalendarSeriesRequest request,
  ) async {
    final RecurringCalendarEventDraft recurringDraft = request.draft;
    final OneTimeCalendarEventDraft draft = recurringDraft.event;
    final CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord> result =
        await _dataSource.updateRecurringSeries(
          idempotencyKey: request.idempotencyKey.value,
          householdId: draft.householdId.value,
          seriesId: request.seriesId.value,
          expectedVersion: request.expectedVersion,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          recurrenceRule: recurringDraft.recurrenceRule.toJson(),
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarRecurringSeriesUpdateDataRecord>(
        :final value,
      ) =>
        _mapRecurringSeriesUpdate(value, request),
      CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        :final kind,
      ) =>
        UpdateRecurringCalendarSeriesFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<UpdateRecurringCalendarSeriesResult>
  updateRecurringSeriesFromOccurrence(
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    final RecurringCalendarEventDraft recurringDraft = request.draft;
    final OneTimeCalendarEventDraft draft = recurringDraft.event;
    final CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord> result =
        await _dataSource.updateRecurringSeriesFromOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          effectiveOccurrenceId: request.effectiveOccurrenceId.value,
          expectedVersion: request.expectedVersion,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          recurrenceRule: recurringDraft.recurrenceRule.toJson(),
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarRecurringSeriesUpdateDataRecord>(
        :final value,
      ) =>
        _mapRecurringSeriesUpdateEnvelope(
          value,
          expectedHouseholdId: request.householdId,
          expectedSeriesId: request.seriesId,
          expectedVersion: request.expectedVersion,
        ),
      CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
        :final kind,
      ) =>
        UpdateRecurringCalendarSeriesFailed(_mapFailure(kind)),
    };
  }

  UpdateRecurringCalendarSeriesResult _mapRecurringSeriesUpdate(
    CalendarRecurringSeriesUpdateDataRecord record,
    UpdateRecurringCalendarSeriesRequest request,
  ) {
    return _mapRecurringSeriesUpdateEnvelope(
      record,
      expectedHouseholdId: request.draft.householdId,
      expectedSeriesId: request.seriesId,
      expectedVersion: request.expectedVersion,
    );
  }

  UpdateRecurringCalendarSeriesResult _mapRecurringSeriesUpdateEnvelope(
    CalendarRecurringSeriesUpdateDataRecord record, {
    required HouseholdId expectedHouseholdId,
    required CalendarEventSeriesId expectedSeriesId,
    required int expectedVersion,
  }) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventRevisionId? revisionId =
        CalendarEventRevisionId.tryParse(record.revisionId);
    final CalendarLocalDate? effectiveLocalDate = CalendarLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    final CalendarLocalDate? materializedThrough = CalendarLocalDate.tryParse(
      record.materializedThrough,
    );
    if (householdId != expectedHouseholdId ||
        seriesId != expectedSeriesId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        revisionId == null ||
        effectiveLocalDate == null ||
        materializedThrough == null ||
        record.version <= expectedVersion) {
      return const UpdateRecurringCalendarSeriesFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final RecurringCalendarSeriesUpdateSnapshot? snapshot =
        RecurringCalendarSeriesUpdateSnapshot.tryCreate(
          householdId: householdId!,
          householdTimeZone: householdTimeZone,
          householdLocalDate: householdLocalDate,
          seriesId: seriesId!,
          revisionId: revisionId,
          revisionNumber: record.revisionNumber,
          effectiveLocalDate: effectiveLocalDate,
          materializedThrough: materializedThrough,
          version: record.version,
          rebuiltCount: record.rebuiltCount,
          cancelledCount: record.cancelledCount,
          preservedExceptionCount: record.preservedExceptionCount,
          changed: record.changed,
        );
    return snapshot == null
        ? const UpdateRecurringCalendarSeriesFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarSeriesUpdated(snapshot);
  }

  @override
  Future<CancelRecurringCalendarSeriesResult> cancelRecurringSeries(
    CancelRecurringCalendarSeriesRequest request,
  ) async {
    final CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>
    result = await _dataSource.cancelRecurringSeries(
      idempotencyKey: request.idempotencyKey.value,
      householdId: request.householdId.value,
      seriesId: request.seriesId.value,
      expectedVersion: request.expectedVersion,
    );
    return switch (result) {
      CalendarDataSucceeded<CalendarRecurringSeriesCancellationDataRecord>(
        :final value,
      ) =>
        _mapRecurringSeriesCancellation(value, request),
      CalendarDataFailed<CalendarRecurringSeriesCancellationDataRecord>(
        :final kind,
      ) =>
        CancelRecurringCalendarSeriesFailed(_mapFailure(kind)),
    };
  }

  CancelRecurringCalendarSeriesResult _mapRecurringSeriesCancellation(
    CalendarRecurringSeriesCancellationDataRecord record,
    CancelRecurringCalendarSeriesRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarLocalDate? effectiveLocalDate = CalendarLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        effectiveLocalDate == null ||
        record.version <= request.expectedVersion) {
      return const CancelRecurringCalendarSeriesFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final RecurringCalendarSeriesCancellationSnapshot? snapshot =
        RecurringCalendarSeriesCancellationSnapshot.tryCreate(
          householdId: householdId!,
          householdTimeZone: householdTimeZone,
          householdLocalDate: householdLocalDate,
          seriesId: seriesId!,
          effectiveLocalDate: effectiveLocalDate,
          version: record.version,
          cancelledCount: record.cancelledCount,
          preservedPastCount: record.preservedPastCount,
          changed: record.changed,
        );
    return snapshot == null
        ? const CancelRecurringCalendarSeriesFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarSeriesCancelled(snapshot);
  }

  @override
  Future<CancelRecurringCalendarSeriesFromOccurrenceResult>
  cancelRecurringSeriesFromOccurrence(
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    final CalendarDataResult<
      CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
    >
    result = await _dataSource.cancelRecurringSeriesFromOccurrence(
      idempotencyKey: request.idempotencyKey.value,
      householdId: request.householdId.value,
      seriesId: request.seriesId.value,
      effectiveOccurrenceId: request.effectiveOccurrenceId.value,
      expectedVersion: request.expectedVersion,
    );
    return switch (result) {
      CalendarDataSucceeded<
        CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
      >(
        :final value,
      ) =>
        _mapRecurringSeriesCancellationFromOccurrence(value, request),
      CalendarDataFailed<
        CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
      >(
        :final kind,
      ) =>
        CancelRecurringCalendarSeriesFromOccurrenceFailed(_mapFailure(kind)),
    };
  }

  CancelRecurringCalendarSeriesFromOccurrenceResult
  _mapRecurringSeriesCancellationFromOccurrence(
    CalendarRecurringSeriesFromOccurrenceCancellationDataRecord record,
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? householdLocalDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarLocalDate? effectiveLocalDate = CalendarLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    final CalendarEventRevisionId? terminalRevisionId =
        record.terminalRevisionId == null
        ? null
        : CalendarEventRevisionId.tryParse(record.terminalRevisionId!);
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        householdTimeZone == null ||
        householdLocalDate == null ||
        effectiveLocalDate != request.effectiveLocalDate ||
        record.version != request.expectedVersion + 1) {
      return const CancelRecurringCalendarSeriesFromOccurrenceFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final RecurringCalendarSeriesFromOccurrenceCancellationSnapshot? snapshot =
        RecurringCalendarSeriesFromOccurrenceCancellationSnapshot.tryCreate(
          householdId: householdId!,
          householdTimeZone: householdTimeZone,
          householdLocalDate: householdLocalDate,
          seriesId: seriesId!,
          effectiveLocalDate: effectiveLocalDate!,
          version: record.version,
          cancelledCount: record.cancelledCount,
          preservedPastCount: record.preservedPastCount,
          terminalRevisionId: terminalRevisionId,
          terminalRevisionNumber: record.terminalRevisionNumber,
          changed: record.changed,
        );
    return snapshot == null
        ? const CancelRecurringCalendarSeriesFromOccurrenceFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarSeriesCancelledFromOccurrence(snapshot);
  }

  @override
  Future<ResumeRecurringCalendarSeriesCancellationResult>
  resumeRecurringSeriesCancellation(
    ResumeRecurringCalendarSeriesCancellationRequest request,
  ) async {
    final CalendarDataResult<
      CalendarRecurringSeriesCancellationResumeDataRecord
    >
    result = await _dataSource.resumeRecurringSeriesCancellation(
      idempotencyKey: request.idempotencyKey.value,
      householdId: request.householdId.value,
      seriesId: request.seriesId.value,
      cancellationIdempotencyKey: request.cancellationIdempotencyKey.value,
      expectedVersion: request.expectedVersion,
    );
    return switch (result) {
      CalendarDataSucceeded<
        CalendarRecurringSeriesCancellationResumeDataRecord
      >(
        :final value,
      ) =>
        _mapRecurringSeriesCancellationResume(value, request),
      CalendarDataFailed<CalendarRecurringSeriesCancellationResumeDataRecord>(
        :final kind,
      ) =>
        ResumeRecurringCalendarSeriesCancellationFailed(_mapFailure(kind)),
    };
  }

  ResumeRecurringCalendarSeriesCancellationResult
  _mapRecurringSeriesCancellationResume(
    CalendarRecurringSeriesCancellationResumeDataRecord record,
    ResumeRecurringCalendarSeriesCancellationRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarLocalDate? effectiveLocalDate = CalendarLocalDate.tryParse(
      record.effectiveLocalDate,
    );
    final CalendarEventRevisionId? revisionId =
        CalendarEventRevisionId.tryParse(record.revisionId);
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        effectiveLocalDate == null ||
        revisionId == null ||
        record.version != request.expectedVersion + 1) {
      return const ResumeRecurringCalendarSeriesCancellationFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final RecurringCalendarSeriesCancellationResumeSnapshot? snapshot =
        RecurringCalendarSeriesCancellationResumeSnapshot.tryCreate(
          householdId: householdId!,
          seriesId: seriesId!,
          effectiveLocalDate: effectiveLocalDate,
          version: record.version,
          restoredCount: record.restoredCount,
          preservedPastCount: record.preservedPastCount,
          revisionId: revisionId,
          revisionNumber: record.revisionNumber,
          changed: record.changed,
        );
    return snapshot == null
        ? const ResumeRecurringCalendarSeriesCancellationFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : RecurringCalendarSeriesCancellationResumed(snapshot);
  }

  @override
  Future<UpdateOneTimeCalendarEventResult> updateOneTimeEvent(
    UpdateOneTimeCalendarEventRequest request,
  ) async {
    final OneTimeCalendarEventDraft draft = request.draft;
    final CalendarDataResult<CalendarEventDataRecord> result = await _dataSource
        .updateOneTimeEvent(
          idempotencyKey: request.idempotencyKey.value,
          householdId: draft.householdId.value,
          seriesId: request.seriesId.value,
          expectedVersion: request.expectedVersion,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarEventDataRecord>(:final value) =>
        _mapUpdatedEvent(value, request),
      CalendarDataFailed<CalendarEventDataRecord>(:final kind) =>
        UpdateOneTimeCalendarEventFailed(_mapFailure(kind)),
    };
  }

  CreateOneTimeCalendarEventResult _mapCreatedEvent(
    CalendarEventDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final OneTimeCalendarEvent? event = _mapEvent(record, expectedHouseholdId);
    return event == null
        ? const CreateOneTimeCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : OneTimeCalendarEventCreated(event);
  }

  UpdateOneTimeCalendarEventResult _mapUpdatedEvent(
    CalendarEventDataRecord record,
    UpdateOneTimeCalendarEventRequest request,
  ) {
    final OneTimeCalendarEvent? event = _mapEvent(
      record,
      request.draft.householdId,
    );
    return event == null ||
            event.seriesId != request.seriesId ||
            event.occurrenceId != request.occurrenceId
        ? const UpdateOneTimeCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : OneTimeCalendarEventUpdated(event);
  }

  @override
  Future<DeleteOneTimeCalendarEventResult> deleteOneTimeEvent(
    DeleteOneTimeCalendarEventRequest request,
  ) async {
    final CalendarDataResult<CalendarEventDeletionDataRecord> result =
        await _dataSource.deleteOneTimeEvent(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          expectedVersion: request.expectedVersion,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarEventDeletionDataRecord>(:final value) =>
        _mapDeletion(value, request),
      CalendarDataFailed<CalendarEventDeletionDataRecord>(:final kind) =>
        DeleteOneTimeCalendarEventFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<UpdateRecurringCalendarOccurrenceResult> updateRecurringOccurrence(
    UpdateRecurringCalendarOccurrenceRequest request,
  ) async {
    final OneTimeCalendarEventDraft draft = request.draft;
    final CalendarDataResult<CalendarOccurrenceCommandDataRecord> result =
        await _dataSource.updateRecurringOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: draft.householdId.value,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
          title: draft.title,
          description: draft.description,
          isAllDay: draft.isAllDay,
          localStartDate: draft.localStartDate.value,
          localStartTime: draft.localStartTime?.value,
          durationMinutes: draft.durationMinutes,
          allDayEndDateExclusive: draft.allDayEndDateExclusive?.value,
          timezone: draft.timeZone?.value,
          overlapPolicy: draft.overlapPolicy?.wireValue,
          participantMemberIds: draft.participantMemberIds
              .map((HouseholdMemberId id) => id.value)
              .toList(growable: false),
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarOccurrenceCommandDataRecord>(
        :final value,
      ) =>
        switch (_mapOccurrenceCommand(
          value,
          expectedHouseholdId: draft.householdId,
          expectedSeriesId: request.seriesId,
          expectedOccurrenceId: request.occurrenceId,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
          expectedCancelled: false,
        )) {
          final RecurringCalendarOccurrenceCommandSnapshot snapshot =>
            RecurringCalendarOccurrenceUpdated(snapshot),
          null => const UpdateRecurringCalendarOccurrenceFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          ),
        },
      CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(:final kind) =>
        UpdateRecurringCalendarOccurrenceFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<CancelRecurringCalendarOccurrenceResult> cancelRecurringOccurrence(
    CancelRecurringCalendarOccurrenceRequest request,
  ) async {
    final CalendarDataResult<CalendarOccurrenceCommandDataRecord> result =
        await _dataSource.cancelRecurringOccurrence(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
        );
    return switch (result) {
      CalendarDataSucceeded<CalendarOccurrenceCommandDataRecord>(
        :final value,
      ) =>
        switch (_mapOccurrenceCommand(
          value,
          expectedHouseholdId: request.householdId,
          expectedSeriesId: request.seriesId,
          expectedOccurrenceId: request.occurrenceId,
          expectedOccurrenceVersion: request.expectedOccurrenceVersion,
          expectedCancelled: true,
        )) {
          final RecurringCalendarOccurrenceCommandSnapshot snapshot =>
            RecurringCalendarOccurrenceCancelled(snapshot),
          null => const CancelRecurringCalendarOccurrenceFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          ),
        },
      CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(:final kind) =>
        CancelRecurringCalendarOccurrenceFailed(_mapFailure(kind)),
    };
  }

  RecurringCalendarOccurrenceCommandSnapshot? _mapOccurrenceCommand(
    CalendarOccurrenceCommandDataRecord record, {
    required HouseholdId expectedHouseholdId,
    required CalendarEventSeriesId expectedSeriesId,
    required CalendarEventOccurrenceId expectedOccurrenceId,
    required int expectedOccurrenceVersion,
    required bool expectedCancelled,
  }) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(record.occurrenceId);
    final CalendarEventRevisionId? revisionId = record.revisionId == null
        ? null
        : CalendarEventRevisionId.tryParse(record.revisionId!);
    if (householdId != expectedHouseholdId ||
        seriesId != expectedSeriesId ||
        occurrenceId != expectedOccurrenceId ||
        record.revisionId != null && revisionId == null ||
        record.occurrenceVersion <= expectedOccurrenceVersion ||
        record.cancelled != expectedCancelled) {
      return null;
    }
    return RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
      householdId: householdId!,
      seriesId: seriesId!,
      occurrenceId: occurrenceId!,
      revisionId: revisionId,
      occurrenceVersion: record.occurrenceVersion,
      exceptionVersion: record.exceptionVersion,
      cancelled: record.cancelled,
      changed: record.changed,
    );
  }

  LoadOneTimeCalendarEventsResult _mapList(
    CalendarEventListDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final IanaTimeZoneId? householdTimeZone = IanaTimeZoneId.tryParse(
      record.householdTimezone,
    );
    final CalendarLocalDate? localDate = CalendarLocalDate.tryParse(
      record.householdLocalDate,
    );
    if (householdId != expectedHouseholdId ||
        householdTimeZone == null ||
        localDate == null ||
        record.events.length > 100) {
      return const LoadOneTimeCalendarEventsFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    final List<OneTimeCalendarEvent> events = <OneTimeCalendarEvent>[];
    final Set<CalendarEventSeriesId> seriesIds = <CalendarEventSeriesId>{};
    for (final CalendarEventDataRecord item in record.events) {
      final OneTimeCalendarEvent? event = _mapEvent(item, expectedHouseholdId);
      if (event == null || !seriesIds.add(event.seriesId)) {
        return const LoadOneTimeCalendarEventsFailed(
          CalendarFailure(CalendarFailureKind.invalidPayload),
        );
      }
      events.add(event);
    }
    final OneTimeCalendarEventList? eventList =
        OneTimeCalendarEventList.tryCreate(
          householdId: householdId!,
          householdTimeZone: householdTimeZone,
          householdLocalDate: localDate,
          events: events,
        );
    return eventList == null
        ? const LoadOneTimeCalendarEventsFailed(
            CalendarFailure(CalendarFailureKind.invalidPayload),
          )
        : OneTimeCalendarEventsLoaded(eventList);
  }

  OneTimeCalendarEvent? _mapEvent(
    CalendarEventDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(record.occurrenceId);
    final CalendarLocalDate? localStartDate = CalendarLocalDate.tryParse(
      record.localStartDate,
    );
    final CalendarLocalTime? localStartTime = record.localStartTime == null
        ? null
        : CalendarLocalTime.tryParse(record.localStartTime!);
    final CalendarLocalDate? allDayEndDate =
        record.allDayEndDateExclusive == null
        ? null
        : CalendarLocalDate.tryParse(record.allDayEndDateExclusive!);
    final IanaTimeZoneId? timeZone = record.timezone == null
        ? null
        : IanaTimeZoneId.tryParse(record.timezone!);
    final CalendarDstOverlapPolicy? overlapPolicy = record.overlapPolicy == null
        ? null
        : CalendarDstOverlapPolicy.tryParse(record.overlapPolicy!);
    final UtcInstant? startsAt = record.startsAt == null
        ? null
        : UtcInstant.tryParse(record.startsAt!);
    final UtcInstant? endsAt = record.endsAt == null
        ? null
        : UtcInstant.tryParse(record.endsAt!);
    final CalendarTimeResolutionKind? resolution = record.dstResolution == null
        ? null
        : CalendarTimeResolutionKind.tryParse(record.dstResolution!);
    final CalendarRecurrenceRule? recurrenceRule = record.recurrenceRule == null
        ? null
        : CalendarRecurrenceRule.tryParse(record.recurrenceRule);
    final CalendarLocalDate? recurrenceLocalStartDate =
        record.recurrenceLocalStartDate == null
        ? null
        : CalendarLocalDate.tryParse(record.recurrenceLocalStartDate!);
    if (householdId != expectedHouseholdId ||
        seriesId == null ||
        occurrenceId == null ||
        localStartDate == null ||
        (record.localStartTime != null && localStartTime == null) ||
        (record.allDayEndDateExclusive != null && allDayEndDate == null) ||
        (record.timezone != null && timeZone == null) ||
        (record.overlapPolicy != null && overlapPolicy == null) ||
        (record.startsAt != null && startsAt == null) ||
        (record.endsAt != null && endsAt == null) ||
        (record.dstResolution != null && resolution == null) ||
        (record.recurrenceRule != null && recurrenceRule == null) ||
        (record.recurrenceLocalStartDate != null &&
            recurrenceLocalStartDate == null) ||
        recurrenceRule != null && recurrenceLocalStartDate == null ||
        record.participantMemberIds.length !=
            record.participantDisplayNames.length) {
      return null;
    }
    final List<CalendarEventParticipant> participants =
        <CalendarEventParticipant>[];
    for (
      var index = 0;
      index < record.participantMemberIds.length;
      index += 1
    ) {
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
        record.participantMemberIds[index],
      );
      if (memberId == null) {
        return null;
      }
      final CalendarEventParticipant? participant =
          CalendarEventParticipant.tryCreate(
            memberId: memberId,
            displayName: record.participantDisplayNames[index],
          );
      if (participant == null) {
        return null;
      }
      participants.add(participant);
    }
    return OneTimeCalendarEvent.tryCreate(
      householdId: householdId!,
      seriesId: seriesId,
      occurrenceId: occurrenceId,
      title: record.title,
      description: record.description,
      isAllDay: record.isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: record.durationMinutes,
      allDayEndDateExclusive: allDayEndDate,
      timeZone: timeZone,
      overlapPolicy: overlapPolicy,
      startsAt: startsAt,
      endsAt: endsAt,
      dstResolution: resolution,
      utcOffsetSeconds: record.utcOffsetSeconds,
      participants: participants,
      version: record.version,
      occurrenceVersion: record.occurrenceVersion,
      recurrenceRule: recurrenceRule,
      recurrenceLocalStartDate: recurrenceLocalStartDate,
      revisionNumber: record.revisionNumber,
      isException: record.isException,
    );
  }

  DeleteOneTimeCalendarEventResult _mapDeletion(
    CalendarEventDeletionDataRecord record,
    DeleteOneTimeCalendarEventRequest request,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final CalendarEventSeriesId? seriesId = CalendarEventSeriesId.tryParse(
      record.seriesId,
    );
    final CalendarEventOccurrenceId? occurrenceId =
        CalendarEventOccurrenceId.tryParse(record.occurrenceId);
    if (householdId != request.householdId ||
        seriesId != request.seriesId ||
        occurrenceId != request.occurrenceId ||
        !record.deleted ||
        record.version <= request.expectedVersion ||
        record.occurrenceVersion < 1) {
      return const DeleteOneTimeCalendarEventFailed(
        CalendarFailure(CalendarFailureKind.invalidPayload),
      );
    }
    return OneTimeCalendarEventDeleted(
      seriesId: seriesId!,
      version: record.version,
    );
  }

  CalendarFailure _mapFailure(CalendarDataFailureKind kind) {
    return CalendarFailure(switch (kind) {
      CalendarDataFailureKind.unauthenticated =>
        CalendarFailureKind.unauthenticated,
      CalendarDataFailureKind.invalidInput => CalendarFailureKind.invalidInput,
      CalendarDataFailureKind.notFoundOrForbidden =>
        CalendarFailureKind.notFoundOrForbidden,
      CalendarDataFailureKind.idempotencyConflict =>
        CalendarFailureKind.idempotencyConflict,
      CalendarDataFailureKind.staleVersion => CalendarFailureKind.staleVersion,
      CalendarDataFailureKind.nonexistentLocalTime =>
        CalendarFailureKind.nonexistentLocalTime,
      CalendarDataFailureKind.transitionNotAllowed =>
        CalendarFailureKind.transitionNotAllowed,
      CalendarDataFailureKind.featurePolicyUnavailable =>
        CalendarFailureKind.featurePolicyUnavailable,
      CalendarDataFailureKind.featureLimitReached =>
        CalendarFailureKind.featureLimitReached,
      CalendarDataFailureKind.temporarilyUnavailable =>
        CalendarFailureKind.temporarilyUnavailable,
      CalendarDataFailureKind.invalidPayload ||
      CalendarDataFailureKind.unknown => CalendarFailureKind.invalidPayload,
    });
  }
}
