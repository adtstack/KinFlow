import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:kinflow_app/features/calendar/data/repositories/provider_calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'overlap preview sends content-free inputs and maps strict rows',
    () async {
      final CalendarOverlapPreviewRequest request = _overlapRequest();
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        overlapPreviewResult:
            CalendarDataSucceeded<CalendarOverlapPreviewDataRecord>(
              CalendarOverlapPreviewDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-08',
                generatedAt: '2026-08-08T00:00:00.000Z',
                checkedFromLocalDate: '2026-08-08',
                checkedThroughLocalDate: '2026-08-08',
                candidateOccurrenceCount: 1,
                totalConflictCount: 1,
                truncated: false,
                conflicts: <CalendarOverlapConflictDataRecord>[
                  CalendarOverlapConflictDataRecord(
                    candidateLocalStartDate: '2026-08-08',
                    seriesId: calendarSeriesTwoUuid,
                    occurrenceId: calendarOccurrenceTwoUuid,
                    title: 'Existing event',
                    isAllDay: false,
                    viewLocalStartDate: '2026-08-08',
                    viewLocalStartTime: '09:30',
                    durationMinutes: 60,
                    allDayEndDateExclusive: null,
                    participantMemberIds: <String>[calendarMemberOneUuid],
                    participantDisplayNames: <String>['Alex'],
                  ),
                ],
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );

      final PreviewCalendarOverlapsResult result = await repository
          .previewOverlaps(request);

      expect(result, isA<CalendarOverlapsPreviewed>());
      expect(
        (result as CalendarOverlapsPreviewed).preview.conflicts.single.title,
        'Existing event',
      );
      expect(dataSource.overlapRecurrenceRule, isNull);
      expect(dataSource.overlapWindowStartDate, '2026-08-08');
      expect(dataSource.overlapParticipantIds, <String>[calendarMemberOneUuid]);
      expect(dataSource.overlapExcludedSeriesId, calendarSeriesOneUuid);
      expect(dataSource.overlapExcludedOccurrenceId, isNull);
      expect(dataSource.overlapLimit, calendarOverlapPreviewLimit);
    },
  );

  test('overlap preview rejects malformed participant pairs', () async {
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      _FakeCalendarDataSource(
        overlapPreviewResult:
            CalendarDataSucceeded<CalendarOverlapPreviewDataRecord>(
              CalendarOverlapPreviewDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-08',
                generatedAt: '2026-08-08T00:00:00.000Z',
                checkedFromLocalDate: '2026-08-08',
                checkedThroughLocalDate: '2026-08-08',
                candidateOccurrenceCount: 1,
                totalConflictCount: 1,
                truncated: false,
                conflicts: <CalendarOverlapConflictDataRecord>[
                  CalendarOverlapConflictDataRecord(
                    candidateLocalStartDate: '2026-08-08',
                    seriesId: calendarSeriesTwoUuid,
                    occurrenceId: calendarOccurrenceTwoUuid,
                    title: 'Existing event',
                    isAllDay: false,
                    viewLocalStartDate: '2026-08-08',
                    viewLocalStartTime: '09:30',
                    durationMinutes: 60,
                    allDayEndDateExclusive: null,
                    participantMemberIds: <String>[calendarMemberOneUuid],
                    participantDisplayNames: const <String>[],
                  ),
                ],
              ),
            ),
      ),
    );

    final PreviewCalendarOverlapsResult result = await repository
        .previewOverlaps(_overlapRequest());

    expect(result, isA<PreviewCalendarOverlapsFailed>());
    expect(
      (result as PreviewCalendarOverlapsFailed).failure.kind,
      CalendarFailureKind.invalidPayload,
    );
  });

  test('overlap preview maps provider failure without content', () async {
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      _FakeCalendarDataSource(
        overlapPreviewResult:
            const CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
              CalendarDataFailureKind.notFoundOrForbidden,
            ),
      ),
    );

    final PreviewCalendarOverlapsResult result = await repository
        .previewOverlaps(_overlapRequest());

    expect(result, isA<PreviewCalendarOverlapsFailed>());
    expect(
      (result as PreviewCalendarOverlapsFailed).failure.kind,
      CalendarFailureKind.notFoundOrForbidden,
    );
  });

  test('maps a strict provider record into the timed domain event', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      loadResult: CalendarDataSucceeded<CalendarEventListDataRecord>(
        CalendarEventListDataRecord(
          householdId: calendarHouseholdUuid,
          householdTimezone: 'Asia/Seoul',
          householdLocalDate: '2026-08-07',
          events: <CalendarEventDataRecord>[_timedRecord()],
        ),
      ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );

    final LoadOneTimeCalendarEventsResult result = await repository
        .loadOneTimeEvents(calendarHouseholdId());

    final OneTimeCalendarEvent event =
        (result as OneTimeCalendarEventsLoaded).eventList.events.single;
    expect(dataSource.loadedLimit, 100);
    expect(event.localStartTime?.value, '19:00');
    expect(event.startsAt?.value, '2026-08-07T10:00:00.000Z');
    expect(event.participants.single.displayName, 'Alex');
  });

  test('passes canonical draft fields and maps create success', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      createResult: CalendarDataSucceeded<CalendarEventDataRecord>(
        _timedRecord(seriesId: calendarSeriesTwoUuid),
      ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );
    final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
      participantMemberIds: [calendarMemberTwoId(), calendarMemberOneId()],
    );
    final CalendarEventCommandId id = CalendarEventCommandId.tryParse(
      '66666666-6666-4666-8666-666666666666',
    )!;

    final CreateOneTimeCalendarEventResult result = await repository
        .createOneTimeEvent(draft.createRequest(id));

    expect(result, isA<OneTimeCalendarEventCreated>());
    expect(dataSource.createdParticipantIds, <String>[
      calendarMemberOneUuid,
      calendarMemberTwoUuid,
    ]);
    expect(dataSource.createdOverlapPolicy, 'earlier');
    expect(dataSource.createdTimeZone, 'Asia/Seoul');
  });

  test('rejects mismatched arrays and maps stable provider failures', () async {
    final CalendarEventDataRecord malformed = _timedRecord(
      participantNames: const <String>[],
    );
    final ProviderCalendarRepository malformedRepository =
        ProviderCalendarRepository(
          _FakeCalendarDataSource(
            loadResult: CalendarDataSucceeded<CalendarEventListDataRecord>(
              CalendarEventListDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                events: <CalendarEventDataRecord>[malformed],
              ),
            ),
          ),
        );
    final ProviderCalendarRepository failureRepository =
        ProviderCalendarRepository(
          _FakeCalendarDataSource(
            loadResult: const CalendarDataFailed<CalendarEventListDataRecord>(
              CalendarDataFailureKind.notFoundOrForbidden,
            ),
          ),
        );

    final LoadOneTimeCalendarEventsResult malformedResult =
        await malformedRepository.loadOneTimeEvents(calendarHouseholdId());
    final LoadOneTimeCalendarEventsResult failureResult =
        await failureRepository.loadOneTimeEvents(calendarHouseholdId());

    expect(
      (malformedResult as LoadOneTimeCalendarEventsFailed).failure.kind,
      CalendarFailureKind.invalidPayload,
    );
    expect(
      (failureResult as LoadOneTimeCalendarEventsFailed).failure.kind,
      CalendarFailureKind.notFoundOrForbidden,
    );
  });

  test('maps feature capacity failures without provider details', () async {
    const Map<CalendarDataFailureKind, CalendarFailureKind> cases =
        <CalendarDataFailureKind, CalendarFailureKind>{
          CalendarDataFailureKind.featurePolicyUnavailable:
              CalendarFailureKind.featurePolicyUnavailable,
          CalendarDataFailureKind.featureLimitReached:
              CalendarFailureKind.featureLimitReached,
        };

    for (final MapEntry<CalendarDataFailureKind, CalendarFailureKind> entry
        in cases.entries) {
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        _FakeCalendarDataSource(
          loadResult: CalendarDataFailed<CalendarEventListDataRecord>(
            entry.key,
          ),
        ),
      );
      final LoadOneTimeCalendarEventsResult result = await repository
          .loadOneTimeEvents(calendarHouseholdId());
      expect(
        (result as LoadOneTimeCalendarEventsFailed).failure.kind,
        entry.value,
      );
    }
  });

  test(
    'accepts an idempotent deletion snapshot with advanced version',
    () async {
      final CalendarEventSeriesId seriesId = CalendarEventSeriesId.tryParse(
        calendarSeriesOneUuid,
      )!;
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        deleteResult: CalendarDataSucceeded<CalendarEventDeletionDataRecord>(
          CalendarEventDeletionDataRecord(
            householdId: calendarHouseholdUuid,
            seriesId: calendarSeriesOneUuid,
            occurrenceId: calendarOccurrenceOneUuid,
            version: 2,
            occurrenceVersion: 2,
            deleted: true,
            changed: false,
          ),
        ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );

      final DeleteOneTimeCalendarEventResult result = await repository
          .deleteOneTimeEvent(
            DeleteOneTimeCalendarEventRequest(
              idempotencyKey: CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-666666666666',
              )!,
              householdId: calendarHouseholdId(),
              seriesId: seriesId,
              occurrenceId: CalendarEventOccurrenceId.tryParse(
                calendarOccurrenceOneUuid,
              )!,
              expectedVersion: 1,
            ),
          );

      expect(result, isA<OneTimeCalendarEventDeleted>());
    },
  );

  test('maps an authoritative agenda projection page', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      pageResult: CalendarDataSucceeded<CalendarEventPageDataRecord>(
        CalendarEventPageDataRecord(
          householdId: calendarHouseholdUuid,
          householdTimezone: 'Asia/Seoul',
          householdLocalDate: '2026-08-07',
          generatedAt: '2026-08-07T00:00:00Z',
          viewMode: 'agenda',
          rangeStartDate: '2026-08-07',
          rangeEndDateExclusive: '2026-11-05',
          pageLimit: 30,
          hasMore: false,
          pageCursor: null,
          items: [
            CalendarEventProjectionDataRecord(
              event: _timedRecord(),
              viewLocalDate: '2026-08-07',
              viewLocalTime: '19:00',
            ),
          ],
        ),
      ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );
    final CalendarEventPageRequest request = CalendarEventPageRequest.tryCreate(
      householdId: calendarHouseholdId(),
      view: CalendarViewMode.agenda,
      range: CalendarAllDayRange.tryCreate(
        startDate: CalendarLocalDate.tryParse('2026-08-07')!,
        endDateExclusive: CalendarLocalDate.tryParse('2026-11-05')!,
      ),
    )!;

    final LoadCalendarEventPageResult result = await repository.loadEventPage(
      request,
    );

    final CalendarEventPage page = (result as CalendarEventPageLoaded).page;
    expect(page.items.single.viewLocalTime?.value, '19:00');
    expect(page.items.single.event.title, 'Family dinner');
  });

  test('maps one contiguous month summary row per local date', () async {
    final List<CalendarMonthDayDataRecord> days = List.generate(31, (
      int index,
    ) {
      final CalendarLocalDate date = CalendarLocalDate.tryParse(
        '2026-08-01',
      )!.addDays(index);
      return CalendarMonthDayDataRecord(
        date: date.value,
        eventCount: index == 6 ? 2 : 0,
        allDayCount: index == 6 ? 1 : 0,
        timedCount: index == 6 ? 1 : 0,
      );
    });
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      monthResult: CalendarDataSucceeded<CalendarMonthSummaryDataRecord>(
        CalendarMonthSummaryDataRecord(
          householdId: calendarHouseholdUuid,
          householdTimezone: 'Asia/Seoul',
          householdLocalDate: '2026-08-07',
          generatedAt: '2026-08-07T00:00:00Z',
          monthStartDate: '2026-08-01',
          monthEndDateExclusive: '2026-09-01',
          days: days,
        ),
      ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );
    final CalendarMonthSummaryRequest request =
        CalendarMonthSummaryRequest.tryCreate(
          householdId: calendarHouseholdId(),
          monthStartDate: CalendarLocalDate.tryParse('2026-08-01')!,
        )!;

    final LoadCalendarMonthSummaryResult result = await repository
        .loadMonthSummary(request);

    final CalendarMonthSummary summary =
        (result as CalendarMonthSummaryLoaded).summary;
    expect(summary.days, hasLength(31));
    expect(
      summary.dayFor(CalendarLocalDate.tryParse('2026-08-07')!)?.eventCount,
      2,
    );
  });

  test('maps a strict content-free occurrence locator', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      locatorResult:
          const CalendarDataSucceeded<CalendarOccurrenceLocatorDataRecord>(
            CalendarOccurrenceLocatorDataRecord(
              householdId: calendarHouseholdUuid,
              householdTimezone: 'Asia/Seoul',
              householdLocalDate: '2026-08-08',
              generatedAt: '2026-08-07T15:00:00Z',
              seriesId: calendarSeriesOneUuid,
              occurrenceId: calendarOccurrenceOneUuid,
              viewLocalDate: '2026-08-09',
              seriesVersion: 4,
              occurrenceVersion: 2,
            ),
          ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );

    final LoadCalendarOccurrenceLocatorResult result = await repository
        .loadOccurrenceLocator(
          householdId: calendarHouseholdId(),
          occurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
        );

    final locator = (result as CalendarOccurrenceLocatorLoaded).locator;
    expect(locator.viewLocalDate.value, '2026-08-09');
    expect(locator.seriesVersion, 4);
    expect(locator.occurrenceVersion, 2);
  });

  test(
    'maps recurring creation metadata and occurrence source intent',
    () async {
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.weekly,
        startLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
      );
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        recurringCreateResult:
            CalendarDataSucceeded<RecurringCalendarEventDataRecord>(
              RecurringCalendarEventDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                seriesId: calendarSeriesTwoUuid,
                firstOccurrenceId: calendarOccurrenceTwoUuid,
                recurrenceRule: rule.toJson(),
                materializedThrough: '2027-08-07',
                materializedCount: 52,
                version: 1,
                created: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );
      final RecurringCalendarEventDraft draft =
          RecurringCalendarEventDraft.tryCreate(
            event: calendarEventDraftFixture(),
            recurrenceRule: rule,
          )!;

      final CreateRecurringCalendarEventResult result = await repository
          .createRecurringEvent(
            draft.createRequest(
              CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-666666666666',
              )!,
            ),
          );

      final RecurringCalendarEventSnapshot snapshot =
          (result as RecurringCalendarEventCreated).snapshot;
      expect(snapshot.recurrenceRule, rule);
      expect(snapshot.materializedCount, 52);
      expect(snapshot.created, isTrue);
      expect(
        dataSource.recurringIdempotencyKey,
        '66666666-6666-4666-8666-666666666666',
      );
      expect(dataSource.recurringRule, rule.toJson());
      expect(dataSource.recurringParticipantIds, <String>[
        calendarMemberOneUuid,
      ]);
      expect(dataSource.recurringTimeZone, 'Asia/Seoul');
      expect(dataSource.recurringOverlapPolicy, 'earlier');
    },
  );

  test(
    'loads the active series revision and maps a whole-series update',
    () async {
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.weekly,
        startLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
      );
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        recurringSeriesLoadResult:
            CalendarDataSucceeded<CalendarRecurringSeriesDetailDataRecord>(
              CalendarRecurringSeriesDetailDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                seriesId: calendarSeriesOneUuid,
                revisionId: calendarRevisionOneUuid,
                revisionNumber: 2,
                title: 'Family call',
                description: null,
                isAllDay: false,
                localStartDate: '2026-08-07',
                localStartTime: '19:00',
                durationMinutes: 60,
                allDayEndDateExclusive: null,
                timezone: 'Asia/Seoul',
                overlapPolicy: 'earlier',
                recurrenceRule: rule.toJson(),
                participantMemberIds: const <String>[calendarMemberOneUuid],
                participantDisplayNames: const <String>['Alex'],
                version: 2,
              ),
            ),
        recurringSeriesUpdateResult:
            const CalendarDataSucceeded<
              CalendarRecurringSeriesUpdateDataRecord
            >(
              CalendarRecurringSeriesUpdateDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                seriesId: calendarSeriesOneUuid,
                revisionId: calendarRevisionOneUuid,
                revisionNumber: 3,
                effectiveLocalDate: '2026-08-07',
                materializedThrough: '2027-08-07',
                version: 3,
                rebuiltCount: 53,
                cancelledCount: 313,
                preservedExceptionCount: 1,
                changed: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );

      final LoadRecurringCalendarSeriesResult loaded = await repository
          .loadRecurringSeries(
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          );
      final RecurringCalendarSeriesDetail detail =
          (loaded as RecurringCalendarSeriesLoaded).detail;
      final UpdateRecurringCalendarSeriesResult updated = await repository
          .updateRecurringSeries(
            detail.updateRequest(
              idempotencyKey: CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-666666666666',
              )!,
              updatedDraft: detail.draft,
            ),
          );

      expect(detail.draft.event.title, 'Family call');
      expect(detail.draft.recurrenceRule, rule);
      expect(
        (updated as RecurringCalendarSeriesUpdated)
            .snapshot
            .preservedExceptionCount,
        1,
      );
      expect(dataSource.recurringSeriesExpectedVersion, 2);
      expect(dataSource.recurringSeriesRule, rule.toJson());
    },
  );

  test(
    'maps selected-occurrence series update and forwards target identity',
    () async {
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        recurringSeriesUpdateResult:
            const CalendarDataSucceeded<
              CalendarRecurringSeriesUpdateDataRecord
            >(
              CalendarRecurringSeriesUpdateDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                seriesId: calendarSeriesOneUuid,
                revisionId: calendarRevisionOneUuid,
                revisionNumber: 3,
                effectiveLocalDate: '2026-08-12',
                materializedThrough: '2027-08-12',
                version: 3,
                rebuiltCount: 53,
                cancelledCount: 306,
                preservedExceptionCount: 1,
                changed: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );
      final CalendarLocalDate boundary = CalendarLocalDate.tryParse(
        '2026-08-12',
      )!;
      final event = calendarEventDraftFixture(
        title: 'Selected-boundary series',
        localStartDate: boundary.value,
      );
      final recurring = RecurringCalendarEventDraft.tryCreate(
        event: event,
        recurrenceRule: CalendarRecurrenceRule.anchored(
          frequency: CalendarRecurrenceFrequency.daily,
          startLocalDate: boundary,
        ),
      )!;
      final update = RecurringCalendarSeriesFromOccurrenceUpdateDraft.tryCreate(
        householdId: calendarHouseholdId(),
        seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
        effectiveOccurrenceId: CalendarEventOccurrenceId.tryParse(
          calendarOccurrenceOneUuid,
        )!,
        effectiveLocalDate: boundary,
        householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
        expectedVersion: 2,
        draft: recurring,
      )!;

      final UpdateRecurringCalendarSeriesResult result = await repository
          .updateRecurringSeriesFromOccurrence(
            update.withId(
              CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-000000000004',
              )!,
            ),
          );

      final snapshot = (result as RecurringCalendarSeriesUpdated).snapshot;
      expect(snapshot.householdLocalDate.value, '2026-08-07');
      expect(snapshot.effectiveLocalDate, boundary);
      expect(snapshot.preservedExceptionCount, 1);
      expect(
        dataSource.recurringSeriesEffectiveOccurrenceId,
        calendarOccurrenceOneUuid,
      );
      expect(dataSource.recurringSeriesExpectedVersion, 2);
    },
  );

  test('maps whole-series cancellation with preserved past metadata', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      recurringSeriesCancelResult:
          const CalendarDataSucceeded<
            CalendarRecurringSeriesCancellationDataRecord
          >(
            CalendarRecurringSeriesCancellationDataRecord(
              householdId: calendarHouseholdUuid,
              householdTimezone: 'Asia/Seoul',
              householdLocalDate: '2026-08-07',
              seriesId: calendarSeriesOneUuid,
              effectiveLocalDate: '2026-08-07',
              version: 3,
              cancelledCount: 52,
              preservedPastCount: 8,
              changed: true,
            ),
          ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );

    final CancelRecurringCalendarSeriesResult result = await repository
        .cancelRecurringSeries(
          CancelRecurringCalendarSeriesRequest(
            idempotencyKey: CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-666666666666',
            )!,
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            expectedVersion: 2,
          ),
        );

    expect(
      (result as RecurringCalendarSeriesCancelled).snapshot.preservedPastCount,
      8,
    );
    expect(dataSource.recurringSeriesExpectedVersion, 2);
  });

  test(
    'maps selected-occurrence cancellation and its optional terminal revision',
    () async {
      final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
      final CalendarLocalDate boundary = today.addDays(5);
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        recurringSeriesFromOccurrenceCancelResult:
            const CalendarDataSucceeded<
              CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
            >(
              CalendarRecurringSeriesFromOccurrenceCancellationDataRecord(
                householdId: calendarHouseholdUuid,
                householdTimezone: 'Asia/Seoul',
                householdLocalDate: '2026-08-07',
                seriesId: calendarSeriesOneUuid,
                effectiveLocalDate: '2026-08-12',
                version: 3,
                cancelledCount: 40,
                preservedPastCount: 8,
                terminalRevisionId: calendarRevisionTerminalUuid,
                terminalRevisionNumber: 4,
                changed: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );
      final RecurringCalendarSeriesFromOccurrenceCancellationDraft draft =
          RecurringCalendarSeriesFromOccurrenceCancellationDraft.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            effectiveOccurrenceId: CalendarEventOccurrenceId.tryParse(
              calendarOccurrenceOneUuid,
            )!,
            effectiveLocalDate: boundary,
            householdLocalDate: today,
            expectedVersion: 2,
          )!;

      final CancelRecurringCalendarSeriesFromOccurrenceResult result =
          await repository.cancelRecurringSeriesFromOccurrence(
            draft.withId(
              CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-000000000005',
              )!,
            ),
          );

      final snapshot =
          (result as RecurringCalendarSeriesCancelledFromOccurrence).snapshot;
      expect(snapshot.effectiveLocalDate, boundary);
      expect(snapshot.terminalRevisionId?.value, calendarRevisionTerminalUuid);
      expect(snapshot.terminalRevisionNumber, 4);
      expect(snapshot.retainsScheduledPrefix, isTrue);
      expect(
        dataSource.recurringSeriesEffectiveOccurrenceId,
        calendarOccurrenceOneUuid,
      );
    },
  );

  test('rejects malformed selected cancellation terminal pairs', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      recurringSeriesFromOccurrenceCancelResult:
          const CalendarDataSucceeded<
            CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
          >(
            CalendarRecurringSeriesFromOccurrenceCancellationDataRecord(
              householdId: calendarHouseholdUuid,
              householdTimezone: 'Asia/Seoul',
              householdLocalDate: '2026-08-07',
              seriesId: calendarSeriesOneUuid,
              effectiveLocalDate: '2026-08-12',
              version: 3,
              cancelledCount: 40,
              preservedPastCount: 8,
              terminalRevisionId: 'not-a-uuid',
              terminalRevisionNumber: 4,
              changed: true,
            ),
          ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );
    final CancelRecurringCalendarSeriesFromOccurrenceRequest request =
        RecurringCalendarSeriesFromOccurrenceCancellationDraft.tryCreate(
          householdId: calendarHouseholdId(),
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          effectiveOccurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
          effectiveLocalDate: CalendarLocalDate.tryParse('2026-08-12')!,
          householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
          expectedVersion: 2,
        )!.withId(
          CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-000000000006',
          )!,
        );

    final CancelRecurringCalendarSeriesFromOccurrenceResult result =
        await repository.cancelRecurringSeriesFromOccurrence(request);

    expect(result, isA<CancelRecurringCalendarSeriesFromOccurrenceFailed>());
    expect(
      (result as CancelRecurringCalendarSeriesFromOccurrenceFailed)
          .failure
          .kind,
      CalendarFailureKind.invalidPayload,
    );
  });

  test(
    'maps selected cancellation resume and forwards its original key',
    () async {
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        recurringSeriesCancellationResumeResult:
            const CalendarDataSucceeded<
              CalendarRecurringSeriesCancellationResumeDataRecord
            >(
              CalendarRecurringSeriesCancellationResumeDataRecord(
                householdId: calendarHouseholdUuid,
                seriesId: calendarSeriesOneUuid,
                effectiveLocalDate: '2026-08-12',
                version: 3,
                restoredCount: 40,
                preservedPastCount: 8,
                revisionId: calendarRevisionResumedUuid,
                revisionNumber: 5,
                changed: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );
      final CalendarEventCommandId cancellationId =
          CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-000000000007',
          )!;
      final ResumeRecurringCalendarSeriesCancellationRequest request =
          ResumeRecurringCalendarSeriesCancellationDraft.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            cancellationIdempotencyKey: cancellationId,
            expectedVersion: 2,
          )!.withId(
            CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-000000000008',
            )!,
          );

      final ResumeRecurringCalendarSeriesCancellationResult result =
          await repository.resumeRecurringSeriesCancellation(request);

      final snapshot =
          (result as RecurringCalendarSeriesCancellationResumed).snapshot;
      expect(snapshot.effectiveLocalDate.value, '2026-08-12');
      expect(snapshot.restoredCount, 40);
      expect(snapshot.revisionId.value, calendarRevisionResumedUuid);
      expect(
        dataSource.recurringSeriesCancellationIdempotencyKey,
        cancellationId.value,
      );
      expect(dataSource.recurringSeriesExpectedVersion, 2);
    },
  );

  test('rejects malformed selected cancellation resume snapshots', () async {
    final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
      recurringSeriesCancellationResumeResult:
          const CalendarDataSucceeded<
            CalendarRecurringSeriesCancellationResumeDataRecord
          >(
            CalendarRecurringSeriesCancellationResumeDataRecord(
              householdId: calendarHouseholdUuid,
              seriesId: calendarSeriesOneUuid,
              effectiveLocalDate: '2026-08-12',
              version: 3,
              restoredCount: 0,
              preservedPastCount: 8,
              revisionId: calendarRevisionResumedUuid,
              revisionNumber: 5,
              changed: true,
            ),
          ),
    );
    final ProviderCalendarRepository repository = ProviderCalendarRepository(
      dataSource,
    );
    final ResumeRecurringCalendarSeriesCancellationRequest request =
        ResumeRecurringCalendarSeriesCancellationDraft.tryCreate(
          householdId: calendarHouseholdId(),
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          cancellationIdempotencyKey: CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-000000000009',
          )!,
          expectedVersion: 2,
        )!.withId(
          CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-000000000010',
          )!,
        );

    final ResumeRecurringCalendarSeriesCancellationResult result =
        await repository.resumeRecurringSeriesCancellation(request);

    expect(result, isA<ResumeRecurringCalendarSeriesCancellationFailed>());
    expect(
      (result as ResumeRecurringCalendarSeriesCancellationFailed).failure.kind,
      CalendarFailureKind.invalidPayload,
    );
  });

  test(
    'maps a versioned single-occurrence update and canonical draft fields',
    () async {
      final _FakeCalendarDataSource dataSource = _FakeCalendarDataSource(
        occurrenceUpdateResult:
            const CalendarDataSucceeded<CalendarOccurrenceCommandDataRecord>(
              CalendarOccurrenceCommandDataRecord(
                householdId: calendarHouseholdUuid,
                seriesId: calendarSeriesOneUuid,
                occurrenceId: calendarOccurrenceOneUuid,
                revisionId: calendarRevisionOneUuid,
                occurrenceVersion: 4,
                exceptionVersion: 1,
                cancelled: false,
                changed: true,
              ),
            ),
      );
      final ProviderCalendarRepository repository = ProviderCalendarRepository(
        dataSource,
      );
      final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
        title: 'Moved occurrence',
        participantMemberIds: <HouseholdMemberId>[
          calendarMemberTwoId(),
          calendarMemberOneId(),
        ],
      );

      final UpdateRecurringCalendarOccurrenceResult result = await repository
          .updateRecurringOccurrence(
            draft.updateOccurrenceRequest(
              idempotencyKey: CalendarEventCommandId.tryParse(
                '66666666-6666-4666-8666-666666666666',
              )!,
              seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
              occurrenceId: CalendarEventOccurrenceId.tryParse(
                calendarOccurrenceOneUuid,
              )!,
              expectedOccurrenceVersion: 3,
            ),
          );

      final RecurringCalendarOccurrenceCommandSnapshot snapshot =
          (result as RecurringCalendarOccurrenceUpdated).snapshot;
      expect(snapshot.revisionId?.value, calendarRevisionOneUuid);
      expect(snapshot.occurrenceVersion, 4);
      expect(snapshot.cancelled, isFalse);
      expect(dataSource.occurrenceUpdateId, calendarOccurrenceOneUuid);
      expect(dataSource.occurrenceUpdateExpectedVersion, 3);
      expect(dataSource.occurrenceUpdateParticipantIds, <String>[
        calendarMemberOneUuid,
        calendarMemberTwoUuid,
      ]);
    },
  );

  test('maps occurrence cancellation and transition failure safely', () async {
    final CancelRecurringCalendarOccurrenceRequest request =
        CancelRecurringCalendarOccurrenceRequest(
          idempotencyKey: CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-666666666666',
          )!,
          householdId: calendarHouseholdId(),
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          occurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
          expectedOccurrenceVersion: 2,
        );
    final _FakeCalendarDataSource successDataSource = _FakeCalendarDataSource(
      occurrenceCancelResult:
          const CalendarDataSucceeded<CalendarOccurrenceCommandDataRecord>(
            CalendarOccurrenceCommandDataRecord(
              householdId: calendarHouseholdUuid,
              seriesId: calendarSeriesOneUuid,
              occurrenceId: calendarOccurrenceOneUuid,
              revisionId: null,
              occurrenceVersion: 3,
              exceptionVersion: 1,
              cancelled: true,
              changed: false,
            ),
          ),
    );
    final ProviderCalendarRepository successRepository =
        ProviderCalendarRepository(successDataSource);
    final ProviderCalendarRepository failureRepository =
        ProviderCalendarRepository(
          _FakeCalendarDataSource(
            occurrenceCancelResult:
                const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
                  CalendarDataFailureKind.transitionNotAllowed,
                ),
          ),
        );

    final CancelRecurringCalendarOccurrenceResult success =
        await successRepository.cancelRecurringOccurrence(request);
    final CancelRecurringCalendarOccurrenceResult failure =
        await failureRepository.cancelRecurringOccurrence(request);

    expect(success, isA<RecurringCalendarOccurrenceCancelled>());
    expect(successDataSource.occurrenceCancelId, calendarOccurrenceOneUuid);
    expect(successDataSource.occurrenceCancelExpectedVersion, 2);
    expect(
      (failure as CancelRecurringCalendarOccurrenceFailed).failure.kind,
      CalendarFailureKind.transitionNotAllowed,
    );
  });
}

CalendarEventDataRecord _timedRecord({
  String seriesId = calendarSeriesOneUuid,
  List<String> participantNames = const <String>['Alex'],
}) {
  return CalendarEventDataRecord(
    householdId: calendarHouseholdUuid,
    seriesId: seriesId,
    occurrenceId: seriesId == calendarSeriesOneUuid
        ? calendarOccurrenceOneUuid
        : calendarOccurrenceTwoUuid,
    title: 'Family dinner',
    description: null,
    isAllDay: false,
    localStartDate: '2026-08-07',
    localStartTime: '19:00',
    durationMinutes: 60,
    allDayEndDateExclusive: null,
    timezone: 'Asia/Seoul',
    overlapPolicy: 'earlier',
    startsAt: '2026-08-07T10:00:00.000Z',
    endsAt: '2026-08-07T11:00:00.000Z',
    dstResolution: 'normal',
    utcOffsetSeconds: 32400,
    participantMemberIds: <String>[calendarMemberOneUuid],
    participantDisplayNames: participantNames,
    version: 1,
    occurrenceVersion: 1,
  );
}

CalendarOverlapPreviewRequest _overlapRequest() {
  return CalendarOverlapPreviewRequest.tryCreate(
    householdId: calendarHouseholdId(),
    isAllDay: false,
    localStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
    localStartTime: CalendarLocalTime.tryParse('09:00'),
    durationMinutes: 60,
    allDayEndDateExclusive: null,
    timeZone: IanaTimeZoneId.tryParse('Asia/Seoul'),
    overlapPolicy: CalendarDstOverlapPolicy.earlier,
    recurrenceRule: null,
    windowStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
    participantMemberIds: <HouseholdMemberId>[
      HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
    ],
    excludedSeriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid),
    excludedOccurrenceId: null,
  )!;
}

final class _FakeCalendarDataSource implements CalendarDataSource {
  _FakeCalendarDataSource({
    CalendarDataResult<CalendarEventPageDataRecord>? pageResult,
    CalendarDataResult<CalendarMonthSummaryDataRecord>? monthResult,
    CalendarDataResult<CalendarOccurrenceLocatorDataRecord>? locatorResult,
    CalendarDataResult<CalendarOverlapPreviewDataRecord>? overlapPreviewResult,
    CalendarDataResult<CalendarEventListDataRecord>? loadResult,
    CalendarDataResult<CalendarEventDataRecord>? createResult,
    CalendarDataResult<RecurringCalendarEventDataRecord>? recurringCreateResult,
    CalendarDataResult<CalendarRecurringSeriesDetailDataRecord>?
    recurringSeriesLoadResult,
    CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>?
    recurringSeriesUpdateResult,
    CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>?
    recurringSeriesCancelResult,
    CalendarDataResult<
      CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
    >?
    recurringSeriesFromOccurrenceCancelResult,
    CalendarDataResult<CalendarRecurringSeriesCancellationResumeDataRecord>?
    recurringSeriesCancellationResumeResult,
    CalendarDataResult<CalendarEventDataRecord>? updateResult,
    CalendarDataResult<CalendarEventDeletionDataRecord>? deleteResult,
    CalendarDataResult<CalendarOccurrenceCommandDataRecord>?
    occurrenceUpdateResult,
    CalendarDataResult<CalendarOccurrenceCommandDataRecord>?
    occurrenceCancelResult,
  }) : pageResult =
           pageResult ??
           const CalendarDataFailed<CalendarEventPageDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       monthResult =
           monthResult ??
           const CalendarDataFailed<CalendarMonthSummaryDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       locatorResult =
           locatorResult ??
           const CalendarDataFailed<CalendarOccurrenceLocatorDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       overlapPreviewResult =
           overlapPreviewResult ??
           const CalendarDataFailed<CalendarOverlapPreviewDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       loadResult =
           loadResult ??
           CalendarDataSucceeded<CalendarEventListDataRecord>(
             CalendarEventListDataRecord(
               householdId: calendarHouseholdUuid,
               householdTimezone: 'Asia/Seoul',
               householdLocalDate: '2026-08-07',
               events: const <CalendarEventDataRecord>[],
             ),
           ),
       createResult =
           createResult ??
           const CalendarDataFailed<CalendarEventDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       recurringCreateResult =
           recurringCreateResult ??
           const CalendarDataFailed<RecurringCalendarEventDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       recurringSeriesLoadResult =
           recurringSeriesLoadResult ??
           const CalendarDataFailed<CalendarRecurringSeriesDetailDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       recurringSeriesUpdateResult =
           recurringSeriesUpdateResult ??
           const CalendarDataFailed<CalendarRecurringSeriesUpdateDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       recurringSeriesCancelResult =
           recurringSeriesCancelResult ??
           const CalendarDataFailed<
             CalendarRecurringSeriesCancellationDataRecord
           >(CalendarDataFailureKind.unknown),
       recurringSeriesFromOccurrenceCancelResult =
           recurringSeriesFromOccurrenceCancelResult ??
           const CalendarDataFailed<
             CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
           >(CalendarDataFailureKind.unknown),
       recurringSeriesCancellationResumeResult =
           recurringSeriesCancellationResumeResult ??
           const CalendarDataFailed<
             CalendarRecurringSeriesCancellationResumeDataRecord
           >(CalendarDataFailureKind.unknown),
       updateResult =
           updateResult ??
           const CalendarDataFailed<CalendarEventDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       deleteResult =
           deleteResult ??
           const CalendarDataFailed<CalendarEventDeletionDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       occurrenceUpdateResult =
           occurrenceUpdateResult ??
           const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
             CalendarDataFailureKind.unknown,
           ),
       occurrenceCancelResult =
           occurrenceCancelResult ??
           const CalendarDataFailed<CalendarOccurrenceCommandDataRecord>(
             CalendarDataFailureKind.unknown,
           );

  final CalendarDataResult<CalendarEventPageDataRecord> pageResult;
  final CalendarDataResult<CalendarMonthSummaryDataRecord> monthResult;
  final CalendarDataResult<CalendarOccurrenceLocatorDataRecord> locatorResult;
  final CalendarDataResult<CalendarOverlapPreviewDataRecord>
  overlapPreviewResult;
  final CalendarDataResult<CalendarEventListDataRecord> loadResult;
  final CalendarDataResult<CalendarEventDataRecord> createResult;
  final CalendarDataResult<RecurringCalendarEventDataRecord>
  recurringCreateResult;
  final CalendarDataResult<CalendarRecurringSeriesDetailDataRecord>
  recurringSeriesLoadResult;
  final CalendarDataResult<CalendarRecurringSeriesUpdateDataRecord>
  recurringSeriesUpdateResult;
  final CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>
  recurringSeriesCancelResult;
  final CalendarDataResult<
    CalendarRecurringSeriesFromOccurrenceCancellationDataRecord
  >
  recurringSeriesFromOccurrenceCancelResult;
  final CalendarDataResult<CalendarRecurringSeriesCancellationResumeDataRecord>
  recurringSeriesCancellationResumeResult;
  final CalendarDataResult<CalendarEventDataRecord> updateResult;
  final CalendarDataResult<CalendarEventDeletionDataRecord> deleteResult;
  final CalendarDataResult<CalendarOccurrenceCommandDataRecord>
  occurrenceUpdateResult;
  final CalendarDataResult<CalendarOccurrenceCommandDataRecord>
  occurrenceCancelResult;
  int? loadedLimit;
  List<String>? createdParticipantIds;
  String? createdOverlapPolicy;
  String? createdTimeZone;
  String? recurringIdempotencyKey;
  Map<String, Object?>? recurringRule;
  List<String>? recurringParticipantIds;
  String? recurringTimeZone;
  String? recurringOverlapPolicy;
  String? recurringSeriesId;
  String? recurringSeriesEffectiveOccurrenceId;
  int? recurringSeriesExpectedVersion;
  String? recurringSeriesCancellationIdempotencyKey;
  Map<String, Object?>? recurringSeriesRule;
  String? occurrenceUpdateId;
  int? occurrenceUpdateExpectedVersion;
  List<String>? occurrenceUpdateParticipantIds;
  String? occurrenceCancelId;
  int? occurrenceCancelExpectedVersion;
  Map<String, Object?>? overlapRecurrenceRule;
  String? overlapWindowStartDate;
  List<String>? overlapParticipantIds;
  String? overlapExcludedSeriesId;
  String? overlapExcludedOccurrenceId;
  int? overlapLimit;

  @override
  Future<CalendarDataResult<CalendarEventPageDataRecord>> loadEventPage({
    required String householdId,
    required String viewMode,
    required String? rangeStartDate,
    required String? rangeEndDateExclusive,
    required int limit,
    required String? afterCursor,
  }) async => pageResult;

  @override
  Future<CalendarDataResult<CalendarMonthSummaryDataRecord>> loadMonthSummary({
    required String householdId,
    required String monthStartDate,
  }) async => monthResult;

  @override
  Future<CalendarDataResult<CalendarOccurrenceLocatorDataRecord>>
  loadOccurrenceLocator({
    required String householdId,
    required String occurrenceId,
  }) async => locatorResult;

  @override
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
  }) async {
    overlapRecurrenceRule = recurrenceRule;
    overlapWindowStartDate = windowStartDate;
    overlapParticipantIds = participantMemberIds;
    overlapExcludedSeriesId = excludedSeriesId;
    overlapExcludedOccurrenceId = excludedOccurrenceId;
    overlapLimit = limit;
    return overlapPreviewResult;
  }

  @override
  Future<CalendarDataResult<CalendarEventListDataRecord>> loadOneTimeEvents({
    required String householdId,
    required int limit,
  }) async {
    loadedLimit = limit;
    return loadResult;
  }

  @override
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
  }) async {
    createdParticipantIds = participantMemberIds;
    createdOverlapPolicy = overlapPolicy;
    createdTimeZone = timezone;
    return createResult;
  }

  @override
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
  }) async {
    recurringIdempotencyKey = idempotencyKey;
    recurringRule = recurrenceRule;
    recurringParticipantIds = participantMemberIds;
    recurringTimeZone = timezone;
    recurringOverlapPolicy = overlapPolicy;
    return recurringCreateResult;
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesDetailDataRecord>>
  loadRecurringSeries({
    required String householdId,
    required String seriesId,
  }) async {
    recurringSeriesId = seriesId;
    return recurringSeriesLoadResult;
  }

  @override
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
  }) async {
    recurringSeriesId = seriesId;
    recurringSeriesExpectedVersion = expectedVersion;
    recurringSeriesRule = recurrenceRule;
    return recurringSeriesUpdateResult;
  }

  @override
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
  }) async {
    recurringSeriesId = seriesId;
    recurringSeriesEffectiveOccurrenceId = effectiveOccurrenceId;
    recurringSeriesExpectedVersion = expectedVersion;
    recurringSeriesRule = recurrenceRule;
    return recurringSeriesUpdateResult;
  }

  @override
  Future<CalendarDataResult<CalendarRecurringSeriesCancellationDataRecord>>
  cancelRecurringSeries({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async {
    recurringSeriesId = seriesId;
    recurringSeriesExpectedVersion = expectedVersion;
    return recurringSeriesCancelResult;
  }

  @override
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
  }) async {
    recurringSeriesId = seriesId;
    recurringSeriesEffectiveOccurrenceId = effectiveOccurrenceId;
    recurringSeriesExpectedVersion = expectedVersion;
    return recurringSeriesFromOccurrenceCancelResult;
  }

  @override
  Future<
    CalendarDataResult<CalendarRecurringSeriesCancellationResumeDataRecord>
  >
  resumeRecurringSeriesCancellation({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String cancellationIdempotencyKey,
    required int expectedVersion,
  }) async {
    recurringSeriesId = seriesId;
    recurringSeriesCancellationIdempotencyKey = cancellationIdempotencyKey;
    recurringSeriesExpectedVersion = expectedVersion;
    return recurringSeriesCancellationResumeResult;
  }

  @override
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
  }) async => updateResult;

  @override
  Future<CalendarDataResult<CalendarEventDeletionDataRecord>>
  deleteOneTimeEvent({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required int expectedVersion,
  }) async => deleteResult;

  @override
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
  }) async {
    occurrenceUpdateId = occurrenceId;
    occurrenceUpdateExpectedVersion = expectedOccurrenceVersion;
    occurrenceUpdateParticipantIds = participantMemberIds;
    return occurrenceUpdateResult;
  }

  @override
  Future<CalendarDataResult<CalendarOccurrenceCommandDataRecord>>
  cancelRecurringOccurrence({
    required String idempotencyKey,
    required String householdId,
    required String seriesId,
    required String occurrenceId,
    required int expectedOccurrenceVersion,
  }) async {
    occurrenceCancelId = occurrenceId;
    occurrenceCancelExpectedVersion = expectedOccurrenceVersion;
    return occurrenceCancelResult;
  }
}
