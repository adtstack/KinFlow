import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_occurrence_locator.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

const String calendarHouseholdUuid = '22222222-2222-4222-8222-222222222222';
const String calendarMemberOneUuid = '33333333-3333-4333-8333-333333333333';
const String calendarMemberTwoUuid = '33333333-3333-4333-8333-333333333334';
const String calendarSeriesOneUuid = '44444444-4444-4444-8444-444444444441';
const String calendarSeriesTwoUuid = '44444444-4444-4444-8444-444444444442';
const String calendarOccurrenceOneUuid = '55555555-5555-4555-8555-555555555551';
const String calendarOccurrenceTwoUuid = '55555555-5555-4555-8555-555555555552';
const String calendarRevisionOneUuid = '77777777-7777-4777-8777-777777777771';
const String calendarRevisionTerminalUuid =
    '77777777-7777-4777-8777-777777777772';
const String calendarRevisionResumedUuid =
    '77777777-7777-4777-8777-777777777773';

final class FakeCalendarRepository implements CalendarRepository {
  FakeCalendarRepository({
    OneTimeCalendarEventList? eventList,
    List<LoadOneTimeCalendarEventsResult> loadResults =
        const <LoadOneTimeCalendarEventsResult>[],
    List<LoadCalendarEventPageResult> pageResults =
        const <LoadCalendarEventPageResult>[],
    this.pageLoader,
    List<LoadCalendarMonthSummaryResult> monthResults =
        const <LoadCalendarMonthSummaryResult>[],
    List<LoadCalendarOccurrenceLocatorResult> locatorResults =
        const <LoadCalendarOccurrenceLocatorResult>[],
    List<PreviewCalendarOverlapsResult> overlapPreviewResults =
        const <PreviewCalendarOverlapsResult>[],
    this.overlapPreviewLoader,
    List<CreateOneTimeCalendarEventResult> createResults =
        const <CreateOneTimeCalendarEventResult>[],
    this.createLoader,
    List<CreateRecurringCalendarEventResult> recurringCreateResults =
        const <CreateRecurringCalendarEventResult>[],
    this.recurringCreateLoader,
    List<LoadRecurringCalendarSeriesResult> recurringSeriesLoadResults =
        const <LoadRecurringCalendarSeriesResult>[],
    List<UpdateRecurringCalendarSeriesResult> recurringSeriesUpdateResults =
        const <UpdateRecurringCalendarSeriesResult>[],
    List<UpdateRecurringCalendarSeriesResult>
        recurringSeriesFromOccurrenceUpdateResults =
        const <UpdateRecurringCalendarSeriesResult>[],
    List<CancelRecurringCalendarSeriesResult> recurringSeriesCancelResults =
        const <CancelRecurringCalendarSeriesResult>[],
    List<CancelRecurringCalendarSeriesFromOccurrenceResult>
        recurringSeriesFromOccurrenceCancelResults =
        const <CancelRecurringCalendarSeriesFromOccurrenceResult>[],
    List<ResumeRecurringCalendarSeriesCancellationResult>
        recurringSeriesCancellationResumeResults =
        const <ResumeRecurringCalendarSeriesCancellationResult>[],
    List<UpdateOneTimeCalendarEventResult> updateResults =
        const <UpdateOneTimeCalendarEventResult>[],
    List<DeleteOneTimeCalendarEventResult> deleteResults =
        const <DeleteOneTimeCalendarEventResult>[],
    List<UpdateRecurringCalendarOccurrenceResult> occurrenceUpdateResults =
        const <UpdateRecurringCalendarOccurrenceResult>[],
    List<CancelRecurringCalendarOccurrenceResult> occurrenceCancelResults =
        const <CancelRecurringCalendarOccurrenceResult>[],
  }) : defaultList = eventList ?? calendarEventListFixture(),
       _loadResults = List<LoadOneTimeCalendarEventsResult>.of(loadResults),
       _pageResults = List<LoadCalendarEventPageResult>.of(pageResults),
       _monthResults = List<LoadCalendarMonthSummaryResult>.of(monthResults),
       _locatorResults = List<LoadCalendarOccurrenceLocatorResult>.of(
         locatorResults,
       ),
       _overlapPreviewResults = List<PreviewCalendarOverlapsResult>.of(
         overlapPreviewResults,
       ),
       _createResults = List<CreateOneTimeCalendarEventResult>.of(
         createResults,
       ),
       _recurringCreateResults = List<CreateRecurringCalendarEventResult>.of(
         recurringCreateResults,
       ),
       _recurringSeriesLoadResults = List<LoadRecurringCalendarSeriesResult>.of(
         recurringSeriesLoadResults,
       ),
       _recurringSeriesUpdateResults =
           List<UpdateRecurringCalendarSeriesResult>.of(
             recurringSeriesUpdateResults,
           ),
       _recurringSeriesFromOccurrenceUpdateResults =
           List<UpdateRecurringCalendarSeriesResult>.of(
             recurringSeriesFromOccurrenceUpdateResults,
           ),
       _recurringSeriesCancelResults =
           List<CancelRecurringCalendarSeriesResult>.of(
             recurringSeriesCancelResults,
           ),
       _recurringSeriesFromOccurrenceCancelResults =
           List<CancelRecurringCalendarSeriesFromOccurrenceResult>.of(
             recurringSeriesFromOccurrenceCancelResults,
           ),
       _recurringSeriesCancellationResumeResults =
           List<ResumeRecurringCalendarSeriesCancellationResult>.of(
             recurringSeriesCancellationResumeResults,
           ),
       _updateResults = List<UpdateOneTimeCalendarEventResult>.of(
         updateResults,
       ),
       _deleteResults = List<DeleteOneTimeCalendarEventResult>.of(
         deleteResults,
       ),
       _occurrenceUpdateResults =
           List<UpdateRecurringCalendarOccurrenceResult>.of(
             occurrenceUpdateResults,
           ),
       _occurrenceCancelResults =
           List<CancelRecurringCalendarOccurrenceResult>.of(
             occurrenceCancelResults,
           );

  OneTimeCalendarEventList defaultList;
  final List<LoadOneTimeCalendarEventsResult> _loadResults;
  final List<LoadCalendarEventPageResult> _pageResults;
  final Future<LoadCalendarEventPageResult> Function(
    CalendarEventPageRequest request,
  )?
  pageLoader;
  final List<LoadCalendarMonthSummaryResult> _monthResults;
  final List<LoadCalendarOccurrenceLocatorResult> _locatorResults;
  final List<PreviewCalendarOverlapsResult> _overlapPreviewResults;
  final Future<PreviewCalendarOverlapsResult> Function(
    CalendarOverlapPreviewRequest request,
  )?
  overlapPreviewLoader;
  final List<CreateOneTimeCalendarEventResult> _createResults;
  final Future<CreateOneTimeCalendarEventResult> Function(
    CreateOneTimeCalendarEventRequest request,
  )?
  createLoader;
  final List<CreateRecurringCalendarEventResult> _recurringCreateResults;
  final Future<CreateRecurringCalendarEventResult> Function(
    CreateRecurringCalendarEventRequest request,
  )?
  recurringCreateLoader;
  final List<LoadRecurringCalendarSeriesResult> _recurringSeriesLoadResults;
  final List<UpdateRecurringCalendarSeriesResult> _recurringSeriesUpdateResults;
  final List<UpdateRecurringCalendarSeriesResult>
  _recurringSeriesFromOccurrenceUpdateResults;
  final List<CancelRecurringCalendarSeriesResult> _recurringSeriesCancelResults;
  final List<CancelRecurringCalendarSeriesFromOccurrenceResult>
  _recurringSeriesFromOccurrenceCancelResults;
  final List<ResumeRecurringCalendarSeriesCancellationResult>
  _recurringSeriesCancellationResumeResults;
  final List<UpdateOneTimeCalendarEventResult> _updateResults;
  final List<DeleteOneTimeCalendarEventResult> _deleteResults;
  final List<UpdateRecurringCalendarOccurrenceResult> _occurrenceUpdateResults;
  final List<CancelRecurringCalendarOccurrenceResult> _occurrenceCancelResults;
  final List<HouseholdId> loadedHouseholds = <HouseholdId>[];
  final List<CalendarEventPageRequest> pageRequests =
      <CalendarEventPageRequest>[];
  final List<CalendarMonthSummaryRequest> monthRequests =
      <CalendarMonthSummaryRequest>[];
  final List<CalendarEventOccurrenceId> locatorRequests =
      <CalendarEventOccurrenceId>[];
  final List<CalendarOverlapPreviewRequest> overlapPreviewRequests =
      <CalendarOverlapPreviewRequest>[];
  final List<CreateOneTimeCalendarEventRequest> createRequests =
      <CreateOneTimeCalendarEventRequest>[];
  final List<CreateRecurringCalendarEventRequest> recurringCreateRequests =
      <CreateRecurringCalendarEventRequest>[];
  final List<({HouseholdId householdId, CalendarEventSeriesId seriesId})>
  recurringSeriesLoadRequests =
      <({HouseholdId householdId, CalendarEventSeriesId seriesId})>[];
  final List<UpdateRecurringCalendarSeriesRequest>
  recurringSeriesUpdateRequests = <UpdateRecurringCalendarSeriesRequest>[];
  final List<UpdateRecurringCalendarSeriesFromOccurrenceRequest>
  recurringSeriesFromOccurrenceUpdateRequests =
      <UpdateRecurringCalendarSeriesFromOccurrenceRequest>[];
  final List<CancelRecurringCalendarSeriesRequest>
  recurringSeriesCancelRequests = <CancelRecurringCalendarSeriesRequest>[];
  final List<CancelRecurringCalendarSeriesFromOccurrenceRequest>
  recurringSeriesFromOccurrenceCancelRequests =
      <CancelRecurringCalendarSeriesFromOccurrenceRequest>[];
  final List<ResumeRecurringCalendarSeriesCancellationRequest>
  recurringSeriesCancellationResumeRequests =
      <ResumeRecurringCalendarSeriesCancellationRequest>[];
  final Map<CalendarEventCommandId, List<OneTimeCalendarEvent>>
  _cancelledSeriesEvents =
      <CalendarEventCommandId, List<OneTimeCalendarEvent>>{};
  final Set<CalendarEventCommandId> _appliedSeriesCancellationResumeCommands =
      <CalendarEventCommandId>{};
  final List<UpdateOneTimeCalendarEventRequest> updateRequests =
      <UpdateOneTimeCalendarEventRequest>[];
  final List<DeleteOneTimeCalendarEventRequest> deleteRequests =
      <DeleteOneTimeCalendarEventRequest>[];
  final List<UpdateRecurringCalendarOccurrenceRequest>
  occurrenceUpdateRequests = <UpdateRecurringCalendarOccurrenceRequest>[];
  final List<CancelRecurringCalendarOccurrenceRequest>
  occurrenceCancelRequests = <CancelRecurringCalendarOccurrenceRequest>[];

  @override
  Future<LoadOneTimeCalendarEventsResult> loadOneTimeEvents(
    HouseholdId householdId,
  ) async {
    loadedHouseholds.add(householdId);
    return _loadResults.isEmpty
        ? OneTimeCalendarEventsLoaded(defaultList)
        : _loadResults.removeAt(0);
  }

  @override
  Future<LoadCalendarEventPageResult> loadEventPage(
    CalendarEventPageRequest request,
  ) async {
    pageRequests.add(request);
    if (pageLoader != null) {
      return pageLoader!(request);
    }
    if (_pageResults.isNotEmpty) {
      return _pageResults.removeAt(0);
    }
    final CalendarAllDayRange range =
        request.range ??
        CalendarAllDayRange.tryCreate(
          startDate: defaultList.householdLocalDate,
          endDateExclusive: defaultList.householdLocalDate.addDays(90),
        )!;
    final CalendarEventPageRequest resolvedRequest = request.resolveRange(
      range,
    )!;
    final List<CalendarEventProjection> projections =
        defaultList.events
            .map((OneTimeCalendarEvent event) {
              final CalendarLocalDate visibleDate =
                  event.isAllDay &&
                      event.localStartDate.compareTo(range.startDate) < 0
                  ? range.startDate
                  : event.localStartDate;
              return CalendarEventProjection.tryCreate(
                event: event,
                viewLocalDate: visibleDate,
                viewLocalTime: event.isAllDay ? null : event.localStartTime,
                queryRange: range,
              );
            })
            .whereType<CalendarEventProjection>()
            .toList()
          ..sort(compareCalendarEventProjections);
    final int offset = request.cursor == null
        ? 0
        : int.tryParse(request.cursor!.value, radix: 16) ?? projections.length;
    final int end = (offset + request.limit).clamp(0, projections.length);
    final List<CalendarEventProjection> items = offset >= projections.length
        ? <CalendarEventProjection>[]
        : projections.sublist(offset, end);
    final bool hasMore = end < projections.length;
    final CalendarPageCursor? nextCursor = hasMore
        ? CalendarPageCursor.tryParse(
            end.toRadixString(16).padLeft(2, '0').padRight(2, '0'),
          )
        : null;
    return CalendarEventPageLoaded(
      CalendarEventPage.tryCreate(
        request: resolvedRequest,
        householdTimeZone: defaultList.householdTimeZone,
        householdLocalDate: defaultList.householdLocalDate,
        generatedAt: UtcInstant.tryParse('2026-08-07T00:00:00Z')!,
        items: items,
        hasMore: hasMore,
        nextCursor: nextCursor,
      )!,
    );
  }

  @override
  Future<LoadCalendarMonthSummaryResult> loadMonthSummary(
    CalendarMonthSummaryRequest request,
  ) async {
    monthRequests.add(request);
    if (_monthResults.isNotEmpty) {
      return _monthResults.removeAt(0);
    }
    return CalendarMonthSummaryLoaded(
      calendarMonthSummaryFixture(
        monthStartDate: request.monthStartDate.value,
        events: defaultList.events,
        localDate: defaultList.householdLocalDate.value,
        timeZone: defaultList.householdTimeZone.value,
      ),
    );
  }

  @override
  Future<LoadCalendarOccurrenceLocatorResult> loadOccurrenceLocator({
    required HouseholdId householdId,
    required CalendarEventOccurrenceId occurrenceId,
  }) async {
    locatorRequests.add(occurrenceId);
    if (_locatorResults.isNotEmpty) {
      return _locatorResults.removeAt(0);
    }
    final List<OneTimeCalendarEvent> matches = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.occurrenceId == occurrenceId &&
              event.householdId == householdId,
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      return const LoadCalendarOccurrenceLocatorFailed(
        CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
      );
    }
    final OneTimeCalendarEvent event = matches.single;
    return CalendarOccurrenceLocatorLoaded(
      CalendarOccurrenceLocator.tryCreate(
        householdId: householdId,
        householdTimeZone: defaultList.householdTimeZone,
        householdLocalDate: defaultList.householdLocalDate,
        generatedAt: UtcInstant.tryParse('2026-08-07T00:00:00Z')!,
        seriesId: event.seriesId,
        occurrenceId: event.occurrenceId,
        viewLocalDate: event.localStartDate,
        seriesVersion: event.version,
        occurrenceVersion: event.occurrenceVersion,
      )!,
    );
  }

  @override
  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) async {
    overlapPreviewRequests.add(request);
    if (overlapPreviewLoader != null) {
      return overlapPreviewLoader!(request);
    }
    return _overlapPreviewResults.isEmpty
        ? CalendarOverlapsPreviewed(
            calendarOverlapPreviewFixture(request: request),
          )
        : _overlapPreviewResults.removeAt(0);
  }

  @override
  Future<CreateOneTimeCalendarEventResult> createOneTimeEvent(
    CreateOneTimeCalendarEventRequest request,
  ) async {
    createRequests.add(request);
    final CreateOneTimeCalendarEventResult result = createLoader != null
        ? await createLoader!(request)
        : _createResults.isEmpty
        ? OneTimeCalendarEventCreated(
            calendarEventFromDraft(
              request.draft,
              seriesId: calendarSeriesTwoUuid,
              occurrenceId: calendarOccurrenceTwoUuid,
            ),
          )
        : _createResults.removeAt(0);
    if (result case OneTimeCalendarEventCreated(:final event)) {
      defaultList = defaultList.apply(event);
    }
    return result;
  }

  @override
  Future<CreateRecurringCalendarEventResult> createRecurringEvent(
    CreateRecurringCalendarEventRequest request,
  ) async {
    recurringCreateRequests.add(request);
    final CreateRecurringCalendarEventResult result =
        recurringCreateLoader != null
        ? await recurringCreateLoader!(request)
        : _recurringCreateResults.isEmpty
        ? RecurringCalendarEventCreated(
            RecurringCalendarEventSnapshot.tryCreate(
              householdId: request.draft.householdId,
              seriesId: CalendarEventSeriesId.tryParse(calendarSeriesTwoUuid)!,
              firstOccurrenceId: CalendarEventOccurrenceId.tryParse(
                calendarOccurrenceTwoUuid,
              )!,
              recurrenceRule: request.draft.recurrenceRule,
              materializedThrough: request.draft.event.localStartDate.addDays(
                365,
              ),
              materializedCount: 52,
              version: 1,
              created: true,
            )!,
          )
        : _recurringCreateResults.removeAt(0);
    if (result case RecurringCalendarEventCreated()) {
      defaultList = defaultList.apply(
        calendarEventFromDraft(
          request.draft.event,
          seriesId: calendarSeriesTwoUuid,
          occurrenceId: calendarOccurrenceTwoUuid,
          recurrenceRule: request.draft.recurrenceRule,
        ),
      );
    }
    return result;
  }

  @override
  Future<LoadRecurringCalendarSeriesResult> loadRecurringSeries({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  }) async {
    recurringSeriesLoadRequests.add((
      householdId: householdId,
      seriesId: seriesId,
    ));
    if (_recurringSeriesLoadResults.isNotEmpty) {
      return _recurringSeriesLoadResults.removeAt(0);
    }
    final List<OneTimeCalendarEvent> matchingEvents = defaultList.events
        .where(
          (OneTimeCalendarEvent item) =>
              item.seriesId == seriesId && item.isRecurring,
        )
        .toList(growable: false);
    final OneTimeCalendarEvent? event = matchingEvents.isEmpty
        ? null
        : matchingEvents.first;
    if (event == null || householdId != defaultList.householdId) {
      return const LoadRecurringCalendarSeriesFailed(
        CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
      );
    }
    final OneTimeCalendarEventDraft? eventDraft =
        OneTimeCalendarEventDraft.tryCreate(
          householdId: event.householdId,
          title: event.title,
          description: event.description ?? '',
          isAllDay: event.isAllDay,
          localStartDate: event.recurrenceLocalStartDate,
          localStartTime: event.localStartTime,
          durationMinutes: event.durationMinutes,
          allDayEndDateExclusive: event.allDayEndDateExclusive,
          timeZone: event.timeZone,
          overlapPolicy: event.overlapPolicy,
          participantMemberIds: event.participants.map(
            (CalendarEventParticipant participant) => participant.memberId,
          ),
        );
    final RecurringCalendarSeriesDetail? detail = eventDraft == null
        ? null
        : RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: defaultList.householdTimeZone,
            householdLocalDate: defaultList.householdLocalDate,
            seriesId: seriesId,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: event.revisionNumber,
            event: eventDraft,
            recurrenceRule: event.recurrenceRule!,
            participantDisplayNames: event.participants
                .map(
                  (CalendarEventParticipant participant) =>
                      participant.displayName,
                )
                .toList(growable: false),
            version: event.version,
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
    recurringSeriesUpdateRequests.add(request);
    final UpdateRecurringCalendarSeriesResult result =
        _recurringSeriesUpdateResults.isEmpty
        ? RecurringCalendarSeriesUpdated(
            RecurringCalendarSeriesUpdateSnapshot.tryCreate(
              householdId: request.draft.householdId,
              householdTimeZone: defaultList.householdTimeZone,
              householdLocalDate: defaultList.householdLocalDate,
              seriesId: request.seriesId,
              revisionId: CalendarEventRevisionId.tryParse(
                calendarRevisionOneUuid,
              )!,
              revisionNumber: 2,
              effectiveLocalDate: defaultList.householdLocalDate,
              materializedThrough: defaultList.householdLocalDate.addDays(365),
              version: request.expectedVersion + 1,
              rebuiltCount: 1,
              cancelledCount: 0,
              preservedExceptionCount: 0,
              changed: true,
            )!,
          )
        : _recurringSeriesUpdateResults.removeAt(0);
    if (result case RecurringCalendarSeriesUpdated(:final snapshot)) {
      final List<OneTimeCalendarEvent> matchingEvents = defaultList.events
          .where(
            (OneTimeCalendarEvent event) => event.seriesId == request.seriesId,
          )
          .toList(growable: false);
      final OneTimeCalendarEvent? current = matchingEvents.isEmpty
          ? null
          : matchingEvents.first;
      if (current != null) {
        defaultList = defaultList.applyOccurrence(
          calendarEventFromDraft(
            request.draft.event,
            seriesId: request.seriesId.value,
            occurrenceId: current.occurrenceId.value,
            version: snapshot.version,
            occurrenceVersion: current.occurrenceVersion + 1,
            recurrenceRule: request.draft.recurrenceRule,
            recurrenceLocalStartDate: current.recurrenceLocalStartDate,
            revisionNumber: snapshot.revisionNumber,
            isException: current.isException,
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<UpdateRecurringCalendarSeriesResult>
  updateRecurringSeriesFromOccurrence(
    UpdateRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    recurringSeriesFromOccurrenceUpdateRequests.add(request);
    final UpdateRecurringCalendarSeriesResult result =
        _recurringSeriesFromOccurrenceUpdateResults.isEmpty
        ? RecurringCalendarSeriesUpdated(
            RecurringCalendarSeriesUpdateSnapshot.tryCreate(
              householdId: request.householdId,
              householdTimeZone: defaultList.householdTimeZone,
              householdLocalDate: defaultList.householdLocalDate,
              seriesId: request.seriesId,
              revisionId: CalendarEventRevisionId.tryParse(
                calendarRevisionOneUuid,
              )!,
              revisionNumber: 2,
              effectiveLocalDate: request.effectiveLocalDate,
              materializedThrough: request.effectiveLocalDate.addDays(365),
              version: request.expectedVersion + 1,
              rebuiltCount: 1,
              cancelledCount: 0,
              preservedExceptionCount: 0,
              changed: true,
            )!,
          )
        : _recurringSeriesFromOccurrenceUpdateResults.removeAt(0);
    if (result case RecurringCalendarSeriesUpdated(:final snapshot)) {
      final List<OneTimeCalendarEvent> matching = defaultList.events
          .where(
            (OneTimeCalendarEvent event) =>
                event.occurrenceId == request.effectiveOccurrenceId,
          )
          .toList(growable: false);
      final OneTimeCalendarEvent? current = matching.isEmpty
          ? null
          : matching.first;
      if (current != null) {
        defaultList = defaultList.applyOccurrence(
          calendarEventFromDraft(
            request.draft.event,
            seriesId: request.seriesId.value,
            occurrenceId: current.occurrenceId.value,
            version: snapshot.version,
            occurrenceVersion: current.occurrenceVersion + 1,
            recurrenceRule: request.draft.recurrenceRule,
            recurrenceLocalStartDate: current.recurrenceLocalStartDate,
            revisionNumber: snapshot.revisionNumber,
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<CancelRecurringCalendarSeriesResult> cancelRecurringSeries(
    CancelRecurringCalendarSeriesRequest request,
  ) async {
    recurringSeriesCancelRequests.add(request);
    final int futureCount = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.seriesId == request.seriesId &&
              event.recurrenceLocalStartDate.compareTo(
                    defaultList.householdLocalDate,
                  ) >=
                  0,
        )
        .length;
    final int preservedPastCount = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.seriesId == request.seriesId &&
              event.recurrenceLocalStartDate.compareTo(
                    defaultList.householdLocalDate,
                  ) <
                  0,
        )
        .length;
    final CancelRecurringCalendarSeriesResult result =
        _recurringSeriesCancelResults.isEmpty
        ? RecurringCalendarSeriesCancelled(
            RecurringCalendarSeriesCancellationSnapshot.tryCreate(
              householdId: request.householdId,
              householdTimeZone: defaultList.householdTimeZone,
              householdLocalDate: defaultList.householdLocalDate,
              seriesId: request.seriesId,
              effectiveLocalDate: defaultList.householdLocalDate,
              version: request.expectedVersion + 1,
              cancelledCount: futureCount,
              preservedPastCount: preservedPastCount,
              changed: true,
            )!,
          )
        : _recurringSeriesCancelResults.removeAt(0);
    if (result case RecurringCalendarSeriesCancelled()) {
      defaultList = OneTimeCalendarEventList.tryCreate(
        householdId: defaultList.householdId,
        householdTimeZone: defaultList.householdTimeZone,
        householdLocalDate: defaultList.householdLocalDate,
        events: defaultList.events
            .where(
              (OneTimeCalendarEvent event) =>
                  event.seriesId != request.seriesId ||
                  event.recurrenceLocalStartDate.compareTo(
                        defaultList.householdLocalDate,
                      ) <
                      0,
            )
            .toList(growable: false),
      )!;
    }
    return result;
  }

  @override
  Future<CancelRecurringCalendarSeriesFromOccurrenceResult>
  cancelRecurringSeriesFromOccurrence(
    CancelRecurringCalendarSeriesFromOccurrenceRequest request,
  ) async {
    recurringSeriesFromOccurrenceCancelRequests.add(request);
    final List<OneTimeCalendarEvent> cancelledEvents = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.seriesId == request.seriesId &&
              event.recurrenceLocalStartDate.compareTo(
                    request.effectiveLocalDate,
                  ) >=
                  0,
        )
        .toList(growable: false);
    final int cancelledCount = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.seriesId == request.seriesId &&
              event.recurrenceLocalStartDate.compareTo(
                    request.effectiveLocalDate,
                  ) >=
                  0,
        )
        .length;
    final int preservedPastCount = defaultList.events
        .where(
          (OneTimeCalendarEvent event) =>
              event.seriesId == request.seriesId &&
              event.recurrenceLocalStartDate.compareTo(
                    request.effectiveLocalDate,
                  ) <
                  0,
        )
        .length;
    final bool retainsPrefix = defaultList.events.any(
      (OneTimeCalendarEvent event) =>
          event.seriesId == request.seriesId &&
          !event.isException &&
          event.recurrenceLocalStartDate.compareTo(
                defaultList.householdLocalDate,
              ) >=
              0 &&
          event.recurrenceLocalStartDate.compareTo(request.effectiveLocalDate) <
              0,
    );
    final CancelRecurringCalendarSeriesFromOccurrenceResult result =
        _recurringSeriesFromOccurrenceCancelResults.isEmpty
        ? RecurringCalendarSeriesCancelledFromOccurrence(
            RecurringCalendarSeriesFromOccurrenceCancellationSnapshot.tryCreate(
              householdId: request.householdId,
              householdTimeZone: defaultList.householdTimeZone,
              householdLocalDate: defaultList.householdLocalDate,
              seriesId: request.seriesId,
              effectiveLocalDate: request.effectiveLocalDate,
              version: request.expectedVersion + 1,
              cancelledCount: cancelledCount,
              preservedPastCount: preservedPastCount,
              terminalRevisionId: retainsPrefix
                  ? CalendarEventRevisionId.tryParse(
                      calendarRevisionTerminalUuid,
                    )
                  : null,
              terminalRevisionNumber: retainsPrefix ? 3 : null,
              changed: true,
            )!,
          )
        : _recurringSeriesFromOccurrenceCancelResults.removeAt(0);
    if (result case RecurringCalendarSeriesCancelledFromOccurrence()) {
      _cancelledSeriesEvents[request.idempotencyKey] = cancelledEvents;
      defaultList = OneTimeCalendarEventList.tryCreate(
        householdId: defaultList.householdId,
        householdTimeZone: defaultList.householdTimeZone,
        householdLocalDate: defaultList.householdLocalDate,
        events: defaultList.events
            .where(
              (OneTimeCalendarEvent event) =>
                  event.seriesId != request.seriesId ||
                  event.recurrenceLocalStartDate.compareTo(
                        request.effectiveLocalDate,
                      ) <
                      0,
            )
            .toList(growable: false),
      )!;
    }
    return result;
  }

  @override
  Future<ResumeRecurringCalendarSeriesCancellationResult>
  resumeRecurringSeriesCancellation(
    ResumeRecurringCalendarSeriesCancellationRequest request,
  ) async {
    recurringSeriesCancellationResumeRequests.add(request);
    final bool isReplay = _appliedSeriesCancellationResumeCommands.contains(
      request.idempotencyKey,
    );
    final List<OneTimeCalendarEvent> cancelledEvents =
        _cancelledSeriesEvents[request.cancellationIdempotencyKey] ??
        const <OneTimeCalendarEvent>[];
    final ResumeRecurringCalendarSeriesCancellationResult result =
        _recurringSeriesCancellationResumeResults.isEmpty
        ? RecurringCalendarSeriesCancellationResumed(
            RecurringCalendarSeriesCancellationResumeSnapshot.tryCreate(
              householdId: request.householdId,
              seriesId: request.seriesId,
              effectiveLocalDate: cancelledEvents.isEmpty
                  ? defaultList.householdLocalDate
                  : cancelledEvents.first.recurrenceLocalStartDate,
              version: request.expectedVersion + 1,
              restoredCount: cancelledEvents.isEmpty
                  ? 1
                  : cancelledEvents.length,
              preservedPastCount: defaultList.events
                  .where(
                    (OneTimeCalendarEvent event) =>
                        event.seriesId == request.seriesId,
                  )
                  .length,
              revisionId: CalendarEventRevisionId.tryParse(
                calendarRevisionResumedUuid,
              )!,
              revisionNumber: 4,
              changed: !isReplay,
            )!,
          )
        : _recurringSeriesCancellationResumeResults.removeAt(0);
    if (result case RecurringCalendarSeriesCancellationResumed()
        when _appliedSeriesCancellationResumeCommands.add(
          request.idempotencyKey,
        )) {
      defaultList = OneTimeCalendarEventList.tryCreate(
        householdId: defaultList.householdId,
        householdTimeZone: defaultList.householdTimeZone,
        householdLocalDate: defaultList.householdLocalDate,
        events: <OneTimeCalendarEvent>[
          ...defaultList.events,
          ...cancelledEvents,
        ],
      )!;
    }
    return result;
  }

  @override
  Future<UpdateOneTimeCalendarEventResult> updateOneTimeEvent(
    UpdateOneTimeCalendarEventRequest request,
  ) async {
    updateRequests.add(request);
    final UpdateOneTimeCalendarEventResult result = _updateResults.isEmpty
        ? OneTimeCalendarEventUpdated(
            calendarEventFromDraft(
              request.draft,
              seriesId: request.seriesId.value,
              occurrenceId: request.occurrenceId.value,
              version: request.expectedVersion + 1,
              occurrenceVersion: request.expectedVersion + 1,
            ),
          )
        : _updateResults.removeAt(0);
    if (result case OneTimeCalendarEventUpdated(:final event)) {
      defaultList = defaultList.apply(event);
    }
    return result;
  }

  @override
  Future<DeleteOneTimeCalendarEventResult> deleteOneTimeEvent(
    DeleteOneTimeCalendarEventRequest request,
  ) async {
    deleteRequests.add(request);
    final DeleteOneTimeCalendarEventResult result = _deleteResults.isEmpty
        ? OneTimeCalendarEventDeleted(
            seriesId: request.seriesId,
            version: request.expectedVersion + 1,
          )
        : _deleteResults.removeAt(0);
    if (result case OneTimeCalendarEventDeleted(:final seriesId)) {
      defaultList = defaultList.remove(seriesId);
    }
    return result;
  }

  @override
  Future<UpdateRecurringCalendarOccurrenceResult> updateRecurringOccurrence(
    UpdateRecurringCalendarOccurrenceRequest request,
  ) async {
    occurrenceUpdateRequests.add(request);
    final OneTimeCalendarEvent current = defaultList.events.firstWhere(
      (OneTimeCalendarEvent event) =>
          event.occurrenceId == request.occurrenceId,
    );
    final UpdateRecurringCalendarOccurrenceResult result =
        _occurrenceUpdateResults.isEmpty
        ? RecurringCalendarOccurrenceUpdated(
            RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
              householdId: request.draft.householdId,
              seriesId: request.seriesId,
              occurrenceId: request.occurrenceId,
              revisionId: CalendarEventRevisionId.tryParse(
                calendarRevisionOneUuid,
              ),
              occurrenceVersion: request.expectedOccurrenceVersion + 1,
              exceptionVersion: current.isException ? 2 : 1,
              cancelled: false,
              changed: true,
            )!,
          )
        : _occurrenceUpdateResults.removeAt(0);
    if (result case RecurringCalendarOccurrenceUpdated(:final snapshot)) {
      defaultList = defaultList.applyOccurrence(
        calendarEventFromDraft(
          request.draft,
          seriesId: request.seriesId.value,
          occurrenceId: request.occurrenceId.value,
          version: current.version,
          occurrenceVersion: snapshot.occurrenceVersion,
          recurrenceRule: current.recurrenceRule,
          recurrenceLocalStartDate: current.recurrenceLocalStartDate,
          revisionNumber: current.revisionNumber + 1,
          isException: true,
        ),
      );
    }
    return result;
  }

  @override
  Future<CancelRecurringCalendarOccurrenceResult> cancelRecurringOccurrence(
    CancelRecurringCalendarOccurrenceRequest request,
  ) async {
    occurrenceCancelRequests.add(request);
    final CancelRecurringCalendarOccurrenceResult result =
        _occurrenceCancelResults.isEmpty
        ? RecurringCalendarOccurrenceCancelled(
            RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
              householdId: request.householdId,
              seriesId: request.seriesId,
              occurrenceId: request.occurrenceId,
              revisionId: null,
              occurrenceVersion: request.expectedOccurrenceVersion + 1,
              exceptionVersion: 1,
              cancelled: true,
              changed: true,
            )!,
          )
        : _occurrenceCancelResults.removeAt(0);
    if (result case RecurringCalendarOccurrenceCancelled()) {
      defaultList = defaultList.removeOccurrence(request.occurrenceId);
    }
    return result;
  }
}

final class FakeCalendarCommandIdGenerator
    implements CalendarCommandIdGenerator {
  var callCount = 0;

  @override
  CalendarEventCommandId generate() {
    callCount += 1;
    return CalendarEventCommandId.tryParse(
      '66666666-6666-4666-8666-${callCount.toString().padLeft(12, '0')}',
    )!;
  }
}

HouseholdId calendarHouseholdId() =>
    HouseholdId.tryParse(calendarHouseholdUuid)!;

HouseholdMemberId calendarMemberOneId() =>
    HouseholdMemberId.tryParse(calendarMemberOneUuid)!;

HouseholdMemberId calendarMemberTwoId() =>
    HouseholdMemberId.tryParse(calendarMemberTwoUuid)!;

OneTimeCalendarEventDraft calendarEventDraftFixture({
  String title = 'Family dinner',
  String description = '',
  bool isAllDay = false,
  String localStartDate = '2026-08-07',
  String localStartTime = '19:00',
  int durationMinutes = 60,
  String allDayEndDateExclusive = '2026-08-08',
  String timeZone = 'Asia/Seoul',
  CalendarDstOverlapPolicy overlapPolicy = CalendarDstOverlapPolicy.earlier,
  List<HouseholdMemberId>? participantMemberIds,
}) {
  return OneTimeCalendarEventDraft.tryCreate(
    householdId: calendarHouseholdId(),
    title: title,
    description: description,
    isAllDay: isAllDay,
    localStartDate: CalendarLocalDate.tryParse(localStartDate)!,
    localStartTime: isAllDay
        ? null
        : CalendarLocalTime.tryParse(localStartTime),
    durationMinutes: isAllDay ? null : durationMinutes,
    allDayEndDateExclusive: isAllDay
        ? CalendarLocalDate.tryParse(allDayEndDateExclusive)
        : null,
    timeZone: isAllDay ? null : IanaTimeZoneId.tryParse(timeZone),
    overlapPolicy: isAllDay ? null : overlapPolicy,
    participantMemberIds:
        participantMemberIds ?? <HouseholdMemberId>[calendarMemberOneId()],
  )!;
}

OneTimeCalendarEvent calendarEventFixture({
  String seriesId = calendarSeriesOneUuid,
  String occurrenceId = calendarOccurrenceOneUuid,
  String title = 'Family dinner',
  String description = 'Bring dessert',
  bool isAllDay = false,
  String localStartDate = '2026-08-07',
  String localStartTime = '19:00',
  int durationMinutes = 60,
  String allDayEndDateExclusive = '2026-08-08',
  String timeZone = 'Asia/Seoul',
  CalendarDstOverlapPolicy overlapPolicy = CalendarDstOverlapPolicy.earlier,
  String startsAt = '2026-08-07T10:00:00Z',
  CalendarTimeResolutionKind resolution = CalendarTimeResolutionKind.normal,
  int utcOffsetSeconds = 32400,
  int version = 1,
  int occurrenceVersion = 1,
  List<CalendarEventParticipant>? participants,
  CalendarRecurrenceRule? recurrenceRule,
  String? recurrenceLocalStartDate,
  int revisionNumber = 1,
  bool isException = false,
}) {
  final UtcInstant? start = isAllDay ? null : UtcInstant.tryParse(startsAt);
  return OneTimeCalendarEvent.tryCreate(
    householdId: calendarHouseholdId(),
    seriesId: CalendarEventSeriesId.tryParse(seriesId)!,
    occurrenceId: CalendarEventOccurrenceId.tryParse(occurrenceId)!,
    title: title,
    description: description.isEmpty ? null : description,
    isAllDay: isAllDay,
    localStartDate: CalendarLocalDate.tryParse(localStartDate)!,
    localStartTime: isAllDay
        ? null
        : CalendarLocalTime.tryParse(localStartTime),
    durationMinutes: isAllDay ? null : durationMinutes,
    allDayEndDateExclusive: isAllDay
        ? CalendarLocalDate.tryParse(allDayEndDateExclusive)
        : null,
    timeZone: isAllDay ? null : IanaTimeZoneId.tryParse(timeZone),
    overlapPolicy: isAllDay ? null : overlapPolicy,
    startsAt: start,
    endsAt: isAllDay
        ? null
        : UtcInstant.tryFromDateTime(
            start!.dateTime.add(Duration(minutes: durationMinutes)),
          ),
    dstResolution: isAllDay ? null : resolution,
    utcOffsetSeconds: isAllDay ? null : utcOffsetSeconds,
    participants:
        participants ??
        <CalendarEventParticipant>[
          CalendarEventParticipant.tryCreate(
            memberId: calendarMemberOneId(),
            displayName: 'Alex',
          )!,
        ],
    version: version,
    occurrenceVersion: occurrenceVersion,
    recurrenceRule: recurrenceRule,
    recurrenceLocalStartDate: recurrenceLocalStartDate == null
        ? null
        : CalendarLocalDate.tryParse(recurrenceLocalStartDate),
    revisionNumber: revisionNumber,
    isException: isException,
  )!;
}

OneTimeCalendarEvent calendarEventFromDraft(
  OneTimeCalendarEventDraft draft, {
  required String seriesId,
  required String occurrenceId,
  int version = 1,
  int occurrenceVersion = 1,
  CalendarRecurrenceRule? recurrenceRule,
  CalendarLocalDate? recurrenceLocalStartDate,
  int revisionNumber = 1,
  bool isException = false,
}) {
  final CalendarTimeResolution? resolution = draft.isAllDay
      ? null
      : TimezoneCalendarTimeResolver().resolve(draft.timedIntent!);
  final ResolvedCalendarTime? resolved = resolution is ResolvedCalendarTime
      ? resolution
      : null;
  return OneTimeCalendarEvent.tryCreate(
    householdId: draft.householdId,
    seriesId: CalendarEventSeriesId.tryParse(seriesId)!,
    occurrenceId: CalendarEventOccurrenceId.tryParse(occurrenceId)!,
    title: draft.title,
    description: draft.description,
    isAllDay: draft.isAllDay,
    localStartDate: draft.localStartDate,
    localStartTime: draft.localStartTime,
    durationMinutes: draft.durationMinutes,
    allDayEndDateExclusive: draft.allDayEndDateExclusive,
    timeZone: draft.timeZone,
    overlapPolicy: draft.overlapPolicy,
    startsAt: resolved?.instant,
    endsAt: resolved == null
        ? null
        : UtcInstant.tryFromDateTime(
            resolved.instant.dateTime.add(
              Duration(minutes: draft.durationMinutes!),
            ),
          ),
    dstResolution: resolved?.kind,
    utcOffsetSeconds: resolved?.utcOffset.inSeconds,
    participants: draft.participantMemberIds
        .map(
          (HouseholdMemberId id) => CalendarEventParticipant.tryCreate(
            memberId: id,
            displayName: id == calendarMemberOneId() ? 'Alex' : 'Jamie',
          )!,
        )
        .toList(growable: false),
    version: version,
    occurrenceVersion: occurrenceVersion,
    recurrenceRule: recurrenceRule,
    recurrenceLocalStartDate: recurrenceRule == null
        ? null
        : recurrenceLocalStartDate ?? draft.localStartDate,
    revisionNumber: revisionNumber,
    isException: isException,
  )!;
}

OneTimeCalendarEventList calendarEventListFixture({
  List<OneTimeCalendarEvent> events = const <OneTimeCalendarEvent>[],
  String localDate = '2026-08-07',
  String timeZone = 'Asia/Seoul',
}) {
  final List<OneTimeCalendarEvent> sorted = List<OneTimeCalendarEvent>.of(
    events,
  )..sort(compareOneTimeCalendarEvents);
  return OneTimeCalendarEventList.tryCreate(
    householdId: calendarHouseholdId(),
    householdTimeZone: IanaTimeZoneId.tryParse(timeZone)!,
    householdLocalDate: CalendarLocalDate.tryParse(localDate)!,
    events: sorted,
  )!;
}

CalendarEventPage calendarEventPageFixture({
  List<OneTimeCalendarEvent> events = const <OneTimeCalendarEvent>[],
  CalendarViewMode view = CalendarViewMode.agenda,
  String rangeStartDate = '2026-08-07',
  String? rangeEndDateExclusive,
  String localDate = '2026-08-07',
  String timeZone = 'Asia/Seoul',
  int limit = 30,
  String? requestCursor,
  bool hasMore = false,
  String? nextCursor,
}) {
  final CalendarLocalDate start = CalendarLocalDate.tryParse(rangeStartDate)!;
  final CalendarAllDayRange range = CalendarAllDayRange.tryCreate(
    startDate: start,
    endDateExclusive: CalendarLocalDate.tryParse(
      rangeEndDateExclusive ??
          start.addDays(view == CalendarViewMode.day ? 1 : 90).value,
    )!,
  )!;
  final CalendarEventPageRequest request = CalendarEventPageRequest.tryCreate(
    householdId: calendarHouseholdId(),
    view: view,
    range: range,
    limit: limit,
    cursor: requestCursor == null
        ? null
        : CalendarPageCursor.tryParse(requestCursor),
  )!;
  final List<CalendarEventProjection> projections =
      events
          .map(
            (OneTimeCalendarEvent event) => CalendarEventProjection.tryCreate(
              event: event,
              viewLocalDate:
                  event.isAllDay && event.localStartDate.compareTo(start) < 0
                  ? start
                  : event.localStartDate,
              viewLocalTime: event.isAllDay ? null : event.localStartTime,
              queryRange: range,
            ),
          )
          .whereType<CalendarEventProjection>()
          .toList()
        ..sort(compareCalendarEventProjections);
  return CalendarEventPage.tryCreate(
    request: request,
    householdTimeZone: IanaTimeZoneId.tryParse(timeZone)!,
    householdLocalDate: CalendarLocalDate.tryParse(localDate)!,
    generatedAt: UtcInstant.tryParse('2026-08-07T00:00:00Z')!,
    items: projections,
    hasMore: hasMore,
    nextCursor: nextCursor == null
        ? null
        : CalendarPageCursor.tryParse(nextCursor),
  )!;
}

CalendarOverlapPreview calendarOverlapPreviewFixture({
  required CalendarOverlapPreviewRequest request,
  List<CalendarOverlapConflict> conflicts = const <CalendarOverlapConflict>[],
  int? totalConflictCount,
  bool? truncated,
}) {
  final int total = totalConflictCount ?? conflicts.length;
  return CalendarOverlapPreview.tryCreate(
    householdId: request.householdId,
    householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
    householdLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
    generatedAt: UtcInstant.tryParse('2026-08-08T00:00:00Z')!,
    checkedFromLocalDate: request.windowStartDate,
    checkedThroughLocalDate: request.recurrenceRule == null
        ? request.windowStartDate
        : request.windowStartDate.addDays(365),
    candidateOccurrenceCount: request.recurrenceRule == null ? 1 : 52,
    totalConflictCount: total,
    truncated: truncated ?? total > conflicts.length,
    conflicts: conflicts,
  )!;
}

CalendarMonthSummary calendarMonthSummaryFixture({
  String monthStartDate = '2026-08-01',
  List<OneTimeCalendarEvent> events = const <OneTimeCalendarEvent>[],
  String localDate = '2026-08-07',
  String timeZone = 'Asia/Seoul',
}) {
  final CalendarLocalDate start = CalendarLocalDate.tryParse(monthStartDate)!;
  final CalendarMonthSummaryRequest request =
      CalendarMonthSummaryRequest.tryCreate(
        householdId: calendarHouseholdId(),
        monthStartDate: start,
      )!;
  final List<CalendarMonthDaySummary> days = <CalendarMonthDaySummary>[];
  for (var index = 0; index < start.daysInMonth; index += 1) {
    final CalendarLocalDate date = start.addDays(index);
    var allDayCount = 0;
    var timedCount = 0;
    for (final OneTimeCalendarEvent event in events) {
      if (event.isAllDay && event.allDayRange!.contains(date)) {
        allDayCount += 1;
      } else if (!event.isAllDay && event.localStartDate == date) {
        timedCount += 1;
      }
    }
    days.add(
      CalendarMonthDaySummary.tryCreate(
        date: date,
        eventCount: allDayCount + timedCount,
        allDayCount: allDayCount,
        timedCount: timedCount,
      )!,
    );
  }
  return CalendarMonthSummary.tryCreate(
    request: request,
    householdTimeZone: IanaTimeZoneId.tryParse(timeZone)!,
    householdLocalDate: CalendarLocalDate.tryParse(localDate)!,
    generatedAt: UtcInstant.tryParse('2026-08-07T00:00:00Z')!,
    monthEndDateExclusive: start.addMonthsClamped(1),
    days: days,
  )!;
}
