import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_controller.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_state.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_occurrence_locator.dart';
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
    'returns the repository overlap preview without mutating page state',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      final CalendarOverlapPreviewRequest request = _previewRequest();

      final PreviewCalendarOverlapsResult result = await controller
          .previewOverlaps(request);

      expect(result, isA<CalendarOverlapsPreviewed>());
      expect(repository.overlapPreviewRequests, <CalendarOverlapPreviewRequest>[
        request,
      ]);
      expect(controller.state, isA<CalendarEventsInitial>());
    },
  );

  test('loads the authoritative household calendar', () async {
    final OneTimeCalendarEvent event = calendarEventFixture();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[event],
      ),
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load(calendarHouseholdId());

    expect(
      repository.pageRequests.map((request) => request.householdId),
      <Object>[calendarHouseholdId()],
    );
    final CalendarEventsReady state = controller.state as CalendarEventsReady;
    expect(state.page.items.single.event.title, 'Family dinner');
  });

  test('reuses an idempotency key when the same create is retried', () async {
    final OneTimeCalendarEvent created = calendarEventFixture(
      seriesId: calendarSeriesTwoUuid,
      occurrenceId: calendarOccurrenceTwoUuid,
      title: 'Dentist',
    );
    final FakeCalendarRepository repository = FakeCalendarRepository(
      createResults: <CreateOneTimeCalendarEventResult>[
        const CreateOneTimeCalendarEventFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
        OneTimeCalendarEventCreated(created),
      ],
    );
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());
    final draft = calendarEventDraftFixture(title: 'Dentist');

    await controller.create(draft);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.temporarilyUnavailable,
    );
    await controller.create(draft);

    expect(generator.callCount, 1);
    expect(repository.createRequests, hasLength(2));
    expect(
      repository.createRequests.first.idempotencyKey,
      repository.createRequests.last.idempotencyKey,
    );
    expect(
      (controller.state as CalendarEventsReady).page.items.single.event.title,
      'Dentist',
    );
  });

  test('updates by version and removes a deleted stable series', () async {
    final OneTimeCalendarEvent original = calendarEventFixture();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());

    await controller.update(
      current: original,
      draft: calendarEventDraftFixture(title: 'Dinner with grandparents'),
    );
    final OneTimeCalendarEvent updated =
        (controller.state as CalendarEventsReady).page.items.single.event;

    expect(updated.seriesId, original.seriesId);
    expect(updated.version, 2);
    expect(repository.updateRequests.single.expectedVersion, 1);

    await controller.delete(updated);

    expect(repository.deleteRequests.single.expectedVersion, 2);
    expect((controller.state as CalendarEventsReady).page.items, isEmpty);
  });

  test(
    'creates a recurring series then authoritatively refreshes the view',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final event = calendarEventDraftFixture(title: 'Weekly planning');
      final RecurringCalendarEventDraft draft =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: CalendarRecurrenceRule.anchored(
              frequency: CalendarRecurrenceFrequency.weekly,
              startLocalDate: event.localStartDate,
            ),
          )!;

      await controller.createRecurring(draft);

      expect(repository.recurringCreateRequests, hasLength(1));
      expect(repository.pageRequests, hasLength(2));
      final OneTimeCalendarEvent created =
          (controller.state as CalendarEventsReady).page.items.single.event;
      expect(created.title, 'Weekly planning');
      expect(created.isRecurring, isTrue);
      expect(
        created.recurrenceRule?.frequency,
        CalendarRecurrenceFrequency.weekly,
      );
    },
  );

  test('reuses an idempotency key when recurring create is retried', () async {
    final FakeCalendarRepository repository = FakeCalendarRepository(
      recurringCreateResults: <CreateRecurringCalendarEventResult>[
        const CreateRecurringCalendarEventFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());
    final event = calendarEventDraftFixture(title: 'Weekly retry');
    final RecurringCalendarEventDraft draft =
        RecurringCalendarEventDraft.tryCreate(
          event: event,
          recurrenceRule: CalendarRecurrenceRule.anchored(
            frequency: CalendarRecurrenceFrequency.weekly,
            startLocalDate: event.localStartDate,
          ),
        )!;

    await controller.createRecurring(draft);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.temporarilyUnavailable,
    );
    await controller.createRecurring(draft);

    expect(generator.callCount, 1);
    expect(repository.recurringCreateRequests, hasLength(2));
    expect(
      repository.recurringCreateRequests.first.idempotencyKey,
      repository.recurringCreateRequests.last.idempotencyKey,
    );
    expect(
      (controller.state as CalendarEventsReady).page.items.single.event.title,
      'Weekly retry',
    );
  });

  test(
    'rotates the recurring command key when interval or end changes',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        recurringCreateResults: <CreateRecurringCalendarEventResult>[
          const CreateRecurringCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final event = calendarEventDraftFixture(title: 'Advanced weekly retry');
      final RecurringCalendarEventDraft first =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: CalendarRecurrenceRule.tryAnchored(
              frequency: CalendarRecurrenceFrequency.weekly,
              startLocalDate: event.localStartDate,
              interval: 2,
              end: const CalendarRecurrenceCountEnd(8),
            )!,
          )!;
      final RecurringCalendarEventDraft changed =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: CalendarRecurrenceRule.tryAnchored(
              frequency: CalendarRecurrenceFrequency.weekly,
              startLocalDate: event.localStartDate,
              interval: 3,
              end: const CalendarRecurrenceCountEnd(12),
            )!,
          )!;

      await controller.createRecurring(first);
      await controller.createRecurring(changed);

      expect(generator.callCount, 2);
      expect(repository.recurringCreateRequests, hasLength(2));
      expect(
        repository.recurringCreateRequests.first.idempotencyKey,
        isNot(repository.recurringCreateRequests.last.idempotencyKey),
      );
      expect(
        repository.recurringCreateRequests.last.draft.recurrenceRule.interval,
        3,
      );
      expect(
        repository.recurringCreateRequests.last.draft.recurrenceRule.end,
        const CalendarRecurrenceCountEnd(12),
      );
    },
  );

  test(
    'rotates the recurring command key when weekly weekdays change',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        recurringCreateResults: <CreateRecurringCalendarEventResult>[
          const CreateRecurringCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final event = calendarEventDraftFixture(title: 'Multi-day weekly retry');
      final CalendarRecurrenceRule firstRule = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.weekly,
        startLocalDate: event.localStartDate,
      );
      final CalendarRecurrenceRule changedRule = firstRule
          .tryWithWeeklyWeekdays(
            weekdays: const <CalendarWeekday>[
              CalendarWeekday.monday,
              CalendarWeekday.friday,
            ],
            sourceLocalDate: event.localStartDate,
            interval: 1,
            end: const CalendarRecurrenceNeverEnds(),
            minimumLocalDate: event.localStartDate,
          )!;
      final RecurringCalendarEventDraft first =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: firstRule,
          )!;
      final RecurringCalendarEventDraft changed =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: changedRule,
          )!;

      await controller.createRecurring(first);
      await controller.createRecurring(changed);

      expect(generator.callCount, 2);
      expect(repository.recurringCreateRequests, hasLength(2));
      expect(
        repository.recurringCreateRequests.first.idempotencyKey,
        isNot(repository.recurringCreateRequests.last.idempotencyKey),
      );
      expect(
        repository.recurringCreateRequests.last.draft.recurrenceRule.weekdays,
        const <CalendarWeekday>[CalendarWeekday.monday, CalendarWeekday.friday],
      );
    },
  );

  test(
    'rotates the recurring command key when monthly start anchor changes',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        recurringCreateResults: <CreateRecurringCalendarEventResult>[
          const CreateRecurringCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final firstEvent = calendarEventDraftFixture(
        title: 'Monthly anchor retry',
      );
      final changedEvent = calendarEventDraftFixture(
        title: 'Monthly anchor retry',
        localStartDate: '2026-08-15',
      );
      final RecurringCalendarEventDraft first =
          RecurringCalendarEventDraft.tryCreate(
            event: firstEvent,
            recurrenceRule: CalendarRecurrenceRule.anchored(
              frequency: CalendarRecurrenceFrequency.monthly,
              startLocalDate: firstEvent.localStartDate,
            ),
          )!;
      final RecurringCalendarEventDraft changed =
          RecurringCalendarEventDraft.tryCreate(
            event: changedEvent,
            recurrenceRule: CalendarRecurrenceRule.anchored(
              frequency: CalendarRecurrenceFrequency.monthly,
              startLocalDate: changedEvent.localStartDate,
            ),
          )!;

      await controller.createRecurring(first);
      await controller.createRecurring(changed);

      expect(generator.callCount, 2);
      expect(repository.recurringCreateRequests, hasLength(2));
      expect(
        repository.recurringCreateRequests.first.idempotencyKey,
        isNot(repository.recurringCreateRequests.last.idempotencyKey),
      );
      expect(
        repository.recurringCreateRequests.last.draft.recurrenceRule.monthDay,
        15,
      );
      expect(
        repository
            .recurringCreateRequests
            .last
            .draft
            .event
            .localStartDate
            .value,
        '2026-08-15',
      );
    },
  );

  test(
    'updates and cancels one recurring occurrence by occurrence version',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        version: 9,
        occurrenceVersion: 3,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.updateOccurrence(
        current: original,
        draft: calendarEventDraftFixture(
          title: 'Moved family dinner',
          localStartDate: '2026-08-08',
        ),
      );

      final OneTimeCalendarEvent updated =
          (controller.state as CalendarEventsReady).page.items.single.event;
      expect(
        repository.occurrenceUpdateRequests.single.expectedOccurrenceVersion,
        3,
      );
      expect(updated.version, 9);
      expect(updated.occurrenceVersion, 4);
      expect(updated.localStartDate.value, '2026-08-08');
      expect(updated.recurrenceLocalStartDate.value, '2026-08-07');
      expect(updated.isException, isTrue);

      await controller.cancelOccurrence(updated);

      expect(
        repository.occurrenceCancelRequests.single.expectedOccurrenceVersion,
        4,
      );
      expect((controller.state as CalendarEventsReady).page.items, isEmpty);
    },
  );

  test('reuses one command key when an occurrence update is retried', () async {
    final OneTimeCalendarEvent original = _recurringEvent();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
      occurrenceUpdateResults: <UpdateRecurringCalendarOccurrenceResult>[
        const UpdateRecurringCalendarOccurrenceFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());
    final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
      title: 'Retried occurrence',
    );

    await controller.updateOccurrence(current: original, draft: draft);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.temporarilyUnavailable,
    );
    await controller.updateOccurrence(current: original, draft: draft);

    expect(generator.callCount, 1);
    expect(repository.occurrenceUpdateRequests, hasLength(2));
    expect(
      repository.occurrenceUpdateRequests.first.idempotencyKey,
      repository.occurrenceUpdateRequests.last.idempotencyKey,
    );
    expect(
      (controller.state as CalendarEventsReady).page.items.single.event.title,
      'Retried occurrence',
    );
  });

  test(
    'loads the active revision before updating an entire recurring series',
    () async {
      final OneTimeCalendarEvent visibleException = _recurringEvent(
        version: 4,
        occurrenceVersion: 2,
        title: 'Moved occurrence',
        isException: true,
      );
      final RecurringCalendarSeriesDetail active = _seriesDetail(
        version: 4,
        title: 'Canonical series',
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[visibleException],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(active),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      final RecurringCalendarSeriesDetail? loaded = await controller
          .loadSeriesForEdit(visibleException);

      expect(loaded?.draft.event.title, 'Canonical series');
      expect(repository.recurringSeriesLoadRequests, hasLength(1));
      final RecurringCalendarEventDraft updated =
          RecurringCalendarEventDraft.tryCreate(
            event: calendarEventDraftFixture(title: 'Updated entire series'),
            recurrenceRule: active.draft.recurrenceRule,
          )!;

      await controller.updateSeries(current: loaded!, draft: updated);

      expect(repository.recurringSeriesUpdateRequests, hasLength(1));
      expect(
        repository.recurringSeriesUpdateRequests.single.expectedVersion,
        4,
      );
      expect(
        repository.recurringSeriesUpdateRequests.single.draft.event.title,
        'Updated entire series',
      );
      expect(repository.pageRequests, hasLength(2));
      expect(generator.callCount, 1);
    },
  );

  test(
    'reuses one command key when a whole-series update is retried',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent();
      final RecurringCalendarSeriesDetail detail = _seriesDetail();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesUpdateResults: <UpdateRecurringCalendarSeriesResult>[
          const UpdateRecurringCalendarSeriesFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final RecurringCalendarEventDraft updated =
          RecurringCalendarEventDraft.tryCreate(
            event: calendarEventDraftFixture(title: 'Retried entire series'),
            recurrenceRule: detail.draft.recurrenceRule,
          )!;

      await controller.updateSeries(current: detail, draft: updated);
      expect(
        (controller.state as CalendarEventsReady).actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      await controller.updateSeries(current: detail, draft: updated);

      expect(generator.callCount, 1);
      expect(repository.recurringSeriesUpdateRequests, hasLength(2));
      expect(
        repository.recurringSeriesUpdateRequests.first.idempotencyKey,
        repository.recurringSeriesUpdateRequests.last.idempotencyKey,
      );
    },
  );

  test(
    'updates from the selected occurrence with one retry-stable command key',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        recurrenceLocalStartDate: '2026-08-12',
        revisionNumber: 2,
      );
      final RecurringCalendarSeriesDetail detail = _seriesDetail();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesFromOccurrenceUpdateResults:
            <UpdateRecurringCalendarSeriesResult>[
              const UpdateRecurringCalendarSeriesFailed(
                CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final CalendarLocalDate boundary = original.recurrenceLocalStartDate;
      final OneTimeCalendarEventDraft event = calendarEventDraftFixture(
        title: 'Updated from selected occurrence',
        localStartDate: boundary.value,
      );
      final RecurringCalendarEventDraft draft =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: CalendarRecurrenceRule.anchored(
              frequency: CalendarRecurrenceFrequency.daily,
              startLocalDate: boundary,
            ),
          )!;

      await controller.updateSeriesFromOccurrence(
        current: original,
        series: detail,
        draft: draft,
      );
      expect(
        (controller.state as CalendarEventsReady).actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      await controller.updateSeriesFromOccurrence(
        current: original,
        series: detail,
        draft: draft,
      );

      expect(generator.callCount, 1);
      expect(
        repository.recurringSeriesFromOccurrenceUpdateRequests,
        hasLength(2),
      );
      final requests = repository.recurringSeriesFromOccurrenceUpdateRequests;
      expect(requests.first.idempotencyKey, requests.last.idempotencyKey);
      expect(requests.last.effectiveOccurrenceId, original.occurrenceId);
      expect(requests.last.effectiveLocalDate, boundary);
      expect(requests.last.draft.event.localStartDate, boundary);
      expect(repository.pageRequests, hasLength(2));
    },
  );

  test(
    'rejects a past selected series boundary before issuing a command',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        recurrenceLocalStartDate: '2026-08-06',
        revisionNumber: 2,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final RecurringCalendarSeriesDetail detail = _seriesDetail();

      await controller.updateSeriesFromOccurrence(
        current: original,
        series: detail,
        draft: detail.draft,
      );

      expect(repository.recurringSeriesFromOccurrenceUpdateRequests, isEmpty);
      expect(generator.callCount, 0);
      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.actionFailure, isNull);
      expect(
        state.conflictResolution,
        CalendarConflictResolution.latestReloaded,
      );
    },
  );

  test(
    'cancels from the selected occurrence with one retry-stable command key',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        version: 4,
        recurrenceLocalStartDate: '2026-08-12',
        revisionNumber: 2,
      );
      final RecurringCalendarSeriesDetail detail = _seriesDetail(version: 4);
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesFromOccurrenceCancelResults:
            <CancelRecurringCalendarSeriesFromOccurrenceResult>[
              const CancelRecurringCalendarSeriesFromOccurrenceFailed(
                CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: detail,
      );
      expect(
        (controller.state as CalendarEventsReady).actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: detail,
      );

      expect(generator.callCount, 1);
      expect(
        repository.recurringSeriesFromOccurrenceCancelRequests,
        hasLength(2),
      );
      final requests = repository.recurringSeriesFromOccurrenceCancelRequests;
      expect(requests.first.idempotencyKey, requests.last.idempotencyKey);
      expect(requests.last.effectiveOccurrenceId, original.occurrenceId);
      expect(
        requests.last.effectiveLocalDate,
        original.recurrenceLocalStartDate,
      );
      expect(requests.last.expectedVersion, 4);
      expect(repository.pageRequests, hasLength(2));
      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.page.items, isEmpty);
      expect(state.undoableSeriesCancellation, isNotNull);
      expect(
        state.undoableSeriesCancellation!.cancellationIdempotencyKey,
        requests.last.idempotencyKey,
      );
      expect(state.undoableSeriesCancellation!.cancellationVersion, 5);
    },
  );

  test(
    'retries selected cancellation Undo with one key and restores the page',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        version: 4,
        recurrenceLocalStartDate: '2026-08-12',
        revisionNumber: 2,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesCancellationResumeResults:
            <ResumeRecurringCalendarSeriesCancellationResult>[
              const ResumeRecurringCalendarSeriesCancellationFailed(
                CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: _seriesDetail(version: 4),
      );
      final UndoableRecurringCalendarSeriesCancellation receipt =
          (controller.state as CalendarEventsReady).undoableSeriesCancellation!;

      await controller.resumeSeriesCancellation(
        householdId: receipt.householdId,
        seriesId: receipt.seriesId,
      );
      final CalendarEventsReady failed =
          controller.state as CalendarEventsReady;
      expect(
        failed.actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      expect(
        failed.undoableSeriesCancellation?.cancellationIdempotencyKey,
        receipt.cancellationIdempotencyKey,
      );

      await controller.resumeSeriesCancellation(
        householdId: receipt.householdId,
        seriesId: receipt.seriesId,
      );

      final CalendarEventsReady restored =
          controller.state as CalendarEventsReady;
      expect(restored.actionFailure, isNull);
      expect(restored.undoableSeriesCancellation, isNull);
      expect(restored.page.eventByOccurrence(original.occurrenceId), isNotNull);
      expect(generator.callCount, 2);
      expect(
        repository.recurringSeriesCancellationResumeRequests,
        hasLength(2),
      );
      final requests = repository.recurringSeriesCancellationResumeRequests;
      expect(requests.first.idempotencyKey, requests.last.idempotencyKey);
      expect(
        requests.last.cancellationIdempotencyKey,
        receipt.cancellationIdempotencyKey,
      );
      expect(requests.last.expectedVersion, receipt.cancellationVersion);
    },
  );

  test(
    'terminal selected cancellation Undo clears its receipt and reloads',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        version: 4,
        recurrenceLocalStartDate: '2026-08-12',
        revisionNumber: 2,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesCancellationResumeResults:
            <ResumeRecurringCalendarSeriesCancellationResult>[
              const ResumeRecurringCalendarSeriesCancellationFailed(
                CalendarFailure(CalendarFailureKind.staleVersion),
              ),
            ],
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: _seriesDetail(version: 4),
      );

      await controller.resumeSeriesCancellation(
        householdId: original.householdId,
        seriesId: original.seriesId,
      );

      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.undoableSeriesCancellation, isNull);
      expect(state.actionFailure?.kind, CalendarFailureKind.staleVersion);
      expect(repository.pageRequests, hasLength(3));
    },
  );

  test(
    'keeps selected cancellation Undo key when success reload fails',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        version: 4,
        recurrenceLocalStartDate: '2026-08-12',
        revisionNumber: 2,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(
            calendarEventPageFixture(events: <OneTimeCalendarEvent>[original]),
          ),
          CalendarEventPageLoaded(calendarEventPageFixture()),
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
          CalendarEventPageLoaded(
            calendarEventPageFixture(events: <OneTimeCalendarEvent>[original]),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: _seriesDetail(version: 4),
      );
      final UndoableRecurringCalendarSeriesCancellation receipt =
          (controller.state as CalendarEventsReady).undoableSeriesCancellation!;

      await controller.resumeSeriesCancellation(
        householdId: receipt.householdId,
        seriesId: receipt.seriesId,
      );

      final CalendarEventsReady reloadFailed =
          controller.state as CalendarEventsReady;
      expect(
        reloadFailed.actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      expect(reloadFailed.undoableSeriesCancellation, same(receipt));

      await controller.resumeSeriesCancellation(
        householdId: receipt.householdId,
        seriesId: receipt.seriesId,
      );

      final CalendarEventsReady restored =
          controller.state as CalendarEventsReady;
      expect(restored.actionFailure, isNull);
      expect(restored.undoableSeriesCancellation, isNull);
      expect(restored.page.eventByOccurrence(original.occurrenceId), isNotNull);
      expect(
        repository.recurringSeriesCancellationResumeRequests,
        hasLength(2),
      );
      final requests = repository.recurringSeriesCancellationResumeRequests;
      expect(requests.first.idempotencyKey, requests.last.idempotencyKey);
      expect(generator.callCount, 2);
    },
  );

  test(
    'rejects a past selected cancellation before IDs or repository I/O',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(
        recurrenceLocalStartDate: '2026-08-06',
        revisionNumber: 2,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.cancelSeriesFromOccurrence(
        current: original,
        series: _seriesDetail(),
      );

      expect(repository.recurringSeriesFromOccurrenceCancelRequests, isEmpty);
      expect(generator.callCount, 0);
      expect(
        (controller.state as CalendarEventsReady).conflictResolution,
        CalendarConflictResolution.latestReloaded,
      );
    },
  );

  test(
    'reloads the latest calendar when an active series detail is stale',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent(version: 3);
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(_seriesDetail(version: 2)),
        ],
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      final RecurringCalendarSeriesDetail? loaded = await controller
          .loadSeriesForEdit(original);

      expect(loaded, isNull);
      expect(repository.recurringSeriesLoadRequests, hasLength(1));
      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.actionFailure, isNull);
      expect(
        state.conflictResolution,
        CalendarConflictResolution.latestReloaded,
      );
    },
  );

  test('rejects a whole-series DST gap before issuing a command', () async {
    final OneTimeCalendarEvent original = _recurringEvent();
    final RecurringCalendarSeriesDetail detail = _seriesDetail();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
    );
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());
    final OneTimeCalendarEventDraft event = calendarEventDraftFixture(
      localStartDate: '2026-03-08',
      localStartTime: '02:30',
      timeZone: 'America/Los_Angeles',
    );
    final RecurringCalendarEventDraft draft =
        RecurringCalendarEventDraft.tryCreate(
          event: event,
          recurrenceRule: CalendarRecurrenceRule.anchored(
            frequency: CalendarRecurrenceFrequency.daily,
            startLocalDate: event.localStartDate,
          ),
        )!;

    await controller.updateSeries(current: detail, draft: draft);

    expect(repository.recurringSeriesUpdateRequests, isEmpty);
    expect(generator.callCount, 0);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.nonexistentLocalTime,
    );
  });

  test(
    'rejects a whole-series until date before household today pre-command',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final OneTimeCalendarEventDraft event = calendarEventDraftFixture(
        localStartDate: '2026-08-01',
      );
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.tryAnchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: event.localStartDate,
        interval: 1,
        end: CalendarRecurrenceUntilEnd(
          CalendarLocalDate.tryParse('2026-08-05')!,
        ),
      )!;
      final RecurringCalendarSeriesDetail current =
          RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: 2,
            event: event,
            recurrenceRule: rule,
            participantDisplayNames: const <String>['Alex'],
            version: 1,
          )!;
      final RecurringCalendarEventDraft draft =
          RecurringCalendarEventDraft.tryCreate(
            event: event,
            recurrenceRule: rule,
          )!;

      await controller.updateSeries(current: current, draft: draft);

      expect(repository.recurringSeriesUpdateRequests, isEmpty);
      expect(generator.callCount, 0);
      expect(
        (controller.state as CalendarEventsReady).actionFailure?.kind,
        CalendarFailureKind.invalidInput,
      );
    },
  );

  test(
    'reuses one command key when whole-series cancellation is retried',
    () async {
      final OneTimeCalendarEvent original = _recurringEvent();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[original],
        ),
        recurringSeriesCancelResults: <CancelRecurringCalendarSeriesResult>[
          const CancelRecurringCalendarSeriesFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator generator =
          FakeCalendarCommandIdGenerator();
      final CalendarEventsController controller = CalendarEventsController(
        repository: repository,
        idGenerator: generator,
        timeResolver: TimezoneCalendarTimeResolver(),
      );
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.cancelSeries(original);
      expect(
        (controller.state as CalendarEventsReady).actionFailure?.kind,
        CalendarFailureKind.temporarilyUnavailable,
      );
      await controller.cancelSeries(original);

      expect(generator.callCount, 1);
      expect(repository.recurringSeriesCancelRequests, hasLength(2));
      expect(
        repository.recurringSeriesCancelRequests.first.idempotencyKey,
        repository.recurringSeriesCancelRequests.last.idempotencyKey,
      );
    },
  );

  test('ends an entire recurring series by version and refreshes', () async {
    final OneTimeCalendarEvent original = _recurringEvent(version: 3);
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());

    await controller.cancelSeries(original);

    expect(repository.recurringSeriesCancelRequests, hasLength(1));
    expect(repository.recurringSeriesCancelRequests.single.expectedVersion, 3);
    expect(repository.pageRequests, hasLength(2));
    expect((controller.state as CalendarEventsReady).page.items, isEmpty);
  });

  test('rejects an occurrence edit DST gap before issuing a command', () async {
    final OneTimeCalendarEvent original = _recurringEvent();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
    );
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());

    await controller.updateOccurrence(
      current: original,
      draft: calendarEventDraftFixture(
        localStartDate: '2026-03-08',
        localStartTime: '02:30',
        timeZone: 'America/Los_Angeles',
      ),
    );

    expect(repository.occurrenceUpdateRequests, isEmpty);
    expect(generator.callCount, 0);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.nonexistentLocalTime,
    );
  });

  test('refreshes the month summary after an occurrence edit', () async {
    final OneTimeCalendarEvent original = _recurringEvent();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[original],
      ),
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());
    await controller.showMonth(
      CalendarLocalDate.tryParse('2026-08-01')!,
      selectedDate: CalendarLocalDate.tryParse('2026-08-07'),
    );

    await controller.updateOccurrence(
      current: original,
      draft: calendarEventDraftFixture(title: 'Month refresh'),
    );

    expect(repository.monthRequests, hasLength(2));
    expect(
      (controller.state as CalendarEventsReady).page.items.single.event.title,
      'Month refresh',
    );
  });

  test('rejects a DST gap before generating or sending a command', () async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    final FakeCalendarCommandIdGenerator generator =
        FakeCalendarCommandIdGenerator();
    final CalendarEventsController controller = CalendarEventsController(
      repository: repository,
      idGenerator: generator,
      timeResolver: TimezoneCalendarTimeResolver(),
    );
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());

    await controller.create(
      calendarEventDraftFixture(
        localStartDate: '2026-03-08',
        localStartTime: '02:30',
        timeZone: 'America/Los_Angeles',
      ),
    );

    expect(repository.createRequests, isEmpty);
    expect(generator.callCount, 0);
    expect(
      (controller.state as CalendarEventsReady).actionFailure?.kind,
      CalendarFailureKind.nonexistentLocalTime,
    );
  });

  test('keeps visible content when refresh fails', () async {
    final OneTimeCalendarEvent event = calendarEventFixture();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[event],
      ),
      pageResults: <LoadCalendarEventPageResult>[
        CalendarEventPageLoaded(
          calendarEventPageFixture(events: <OneTimeCalendarEvent>[event]),
        ),
        const LoadCalendarEventPageFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load(calendarHouseholdId());

    await controller.refresh();

    final CalendarEventsReady state = controller.state as CalendarEventsReady;
    expect(state.page.items.single.event, same(event));
    expect(
      state.refreshFailure?.kind,
      CalendarFailureKind.temporarilyUnavailable,
    );
  });

  test(
    'discards retained Calendar content when household access is lost',
    () async {
      final OneTimeCalendarEvent event = calendarEventFixture();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[event],
        ),
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(
            calendarEventPageFixture(events: <OneTimeCalendarEvent>[event]),
          ),
          const LoadCalendarEventPageFailed(
            CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
          ),
        ],
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.refresh();

      final CalendarEventsLoadFailed state =
          controller.state as CalendarEventsLoadFailed;
      expect(state.failure.kind, CalendarFailureKind.notFoundOrForbidden);
    },
  );

  test(
    'switches day and month views with one retained month summary',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(events: [calendarEventFixture()]),
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());
      final CalendarLocalDate augustSeventh = CalendarLocalDate.tryParse(
        '2026-08-07',
      )!;

      await controller.showDay(augustSeventh);
      expect(
        (controller.state as CalendarEventsReady).viewMode,
        CalendarViewMode.day,
      );

      await controller.showMonth(
        augustSeventh.firstDayOfMonth,
        selectedDate: augustSeventh,
      );
      CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.viewMode, CalendarViewMode.month);
      expect(state.monthSummary?.days, hasLength(31));
      expect(repository.monthRequests, hasLength(1));

      await controller.selectMonthDate(augustSeventh.addDays(1));
      state = controller.state as CalendarEventsReady;
      expect(state.focusedDate.value, '2026-08-08');
      expect(state.page.items, isEmpty);
      expect(repository.monthRequests, hasLength(1));
    },
  );

  test('merges the next keyset page and rejects a duplicate replay', () async {
    final OneTimeCalendarEvent firstEvent = calendarEventFixture(
      title: 'Holiday',
      isAllDay: true,
    );
    final OneTimeCalendarEvent secondEvent = calendarEventFixture(
      seriesId: calendarSeriesTwoUuid,
      occurrenceId: calendarOccurrenceTwoUuid,
      title: 'Dinner',
    );
    final CalendarEventPage first = calendarEventPageFixture(
      events: [firstEvent],
      limit: 1,
      hasMore: true,
      nextCursor: 'aa',
    );
    final CalendarEventPage second = calendarEventPageFixture(
      events: [secondEvent],
      limit: 1,
      requestCursor: 'aa',
    );
    final FakeCalendarRepository repository = FakeCalendarRepository(
      pageResults: [
        CalendarEventPageLoaded(first),
        CalendarEventPageLoaded(second),
      ],
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load(calendarHouseholdId());
    await controller.loadMore();

    final CalendarEventsReady state = controller.state as CalendarEventsReady;
    expect(state.page.items.map((item) => item.event.title), [
      'Holiday',
      'Dinner',
    ]);
    expect(state.page.hasMore, isFalse);
    expect(repository.pageRequests.last.cursor?.value, 'aa');
  });

  test(
    'reloads an authoritative newer page after a server version conflict',
    () async {
      final OneTimeCalendarEvent original = calendarEventFixture(version: 1);
      final OneTimeCalendarEvent latest = calendarEventFixture(
        version: 2,
        occurrenceVersion: 2,
        title: 'Latest family dinner',
      );
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(calendarEventPageFixture(events: [original])),
          CalendarEventPageLoaded(calendarEventPageFixture(events: [latest])),
        ],
        locatorResults: <LoadCalendarOccurrenceLocatorResult>[
          CalendarOccurrenceLocatorLoaded(_locator(latest)),
        ],
        updateResults: <UpdateOneTimeCalendarEventResult>[
          const UpdateOneTimeCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.staleVersion),
          ),
        ],
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.update(
        current: original,
        draft: calendarEventDraftFixture(title: 'My stale edit'),
      );

      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.page.items.single.event.title, 'Latest family dinner');
      expect(
        state.conflictResolution,
        CalendarConflictResolution.latestReloaded,
      );
      expect(state.actionFailure, isNull);
      expect(repository.locatorRequests, <Object>[original.occurrenceId]);
    },
  );

  test(
    'marks a mutation target unavailable after authoritative recovery',
    () async {
      final OneTimeCalendarEvent original = calendarEventFixture();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        pageResults: <LoadCalendarEventPageResult>[
          CalendarEventPageLoaded(calendarEventPageFixture(events: [original])),
          CalendarEventPageLoaded(calendarEventPageFixture()),
        ],
        locatorResults: <LoadCalendarOccurrenceLocatorResult>[
          const LoadCalendarOccurrenceLocatorFailed(
            CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
          ),
        ],
        deleteResults: <DeleteOneTimeCalendarEventResult>[
          const DeleteOneTimeCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
          ),
        ],
      );
      final CalendarEventsController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load(calendarHouseholdId());

      await controller.delete(original);

      final CalendarEventsReady state = controller.state as CalendarEventsReady;
      expect(state.page.items, isEmpty);
      expect(
        state.conflictResolution,
        CalendarConflictResolution.targetUnavailable,
      );
      expect(state.actionFailure, isNull);
    },
  );

  test('opens a valid occurrence deep link in its authoritative day', () async {
    final OneTimeCalendarEvent event = calendarEventFixture();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(events: [event]),
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.openOccurrence(calendarHouseholdId(), event.occurrenceId);

    final CalendarEventsReady state = controller.state as CalendarEventsReady;
    expect(state.viewMode, CalendarViewMode.day);
    expect(state.focusedDate, event.localStartDate);
    expect(state.highlightedOccurrenceId, event.occurrenceId);
    expect(state.page.eventByOccurrence(event.occurrenceId), isNotNull);
  });

  test('fails closed when a deep-link occurrence was deleted', () async {
    final CalendarEventOccurrenceId occurrenceId =
        CalendarEventOccurrenceId.tryParse(calendarOccurrenceOneUuid)!;
    final FakeCalendarRepository repository = FakeCalendarRepository(
      locatorResults: <LoadCalendarOccurrenceLocatorResult>[
        const LoadCalendarOccurrenceLocatorFailed(
          CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
        ),
      ],
    );
    final CalendarEventsController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.openOccurrence(calendarHouseholdId(), occurrenceId);

    expect(controller.state, isA<CalendarEventsTargetUnavailable>());
  });
}

CalendarEventsController _controller(FakeCalendarRepository repository) {
  return CalendarEventsController(
    repository: repository,
    idGenerator: FakeCalendarCommandIdGenerator(),
    timeResolver: TimezoneCalendarTimeResolver(),
  );
}

OneTimeCalendarEvent _recurringEvent({
  int version = 1,
  int occurrenceVersion = 1,
  String title = 'Family dinner',
  bool isException = false,
  String recurrenceLocalStartDate = '2026-08-07',
  int revisionNumber = 1,
}) {
  final CalendarLocalDate start = CalendarLocalDate.tryParse('2026-08-07')!;
  return calendarEventFixture(
    version: version,
    occurrenceVersion: occurrenceVersion,
    title: title,
    recurrenceRule: CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: start,
    ),
    localStartDate: recurrenceLocalStartDate,
    recurrenceLocalStartDate: recurrenceLocalStartDate,
    revisionNumber: revisionNumber,
    isException: isException,
  );
}

RecurringCalendarSeriesDetail _seriesDetail({
  int version = 1,
  String title = 'Canonical series',
}) {
  final event = calendarEventDraftFixture(title: title);
  return RecurringCalendarSeriesDetail.tryCreate(
    householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
    householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
    revisionId: CalendarEventRevisionId.tryParse(calendarRevisionOneUuid)!,
    revisionNumber: 2,
    event: event,
    recurrenceRule: CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: event.localStartDate,
    ),
    participantDisplayNames: const <String>['Alex'],
    version: version,
  )!;
}

CalendarOccurrenceLocator _locator(OneTimeCalendarEvent event) {
  return CalendarOccurrenceLocator.tryCreate(
    householdId: event.householdId,
    householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
    householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    generatedAt: UtcInstant.tryParse('2026-08-07T00:00:00Z')!,
    seriesId: event.seriesId,
    occurrenceId: event.occurrenceId,
    viewLocalDate: event.localStartDate,
    seriesVersion: event.version,
    occurrenceVersion: event.occurrenceVersion,
  )!;
}

CalendarOverlapPreviewRequest _previewRequest() {
  final CalendarLocalDate date = CalendarLocalDate.tryParse('2026-08-08')!;
  return CalendarOverlapPreviewRequest.tryCreate(
    householdId: calendarHouseholdId(),
    isAllDay: false,
    localStartDate: date,
    localStartTime: CalendarLocalTime.tryParse('09:00'),
    durationMinutes: 60,
    allDayEndDateExclusive: null,
    timeZone: IanaTimeZoneId.tryParse('Asia/Seoul'),
    overlapPolicy: CalendarDstOverlapPolicy.earlier,
    recurrenceRule: null,
    windowStartDate: date,
    participantMemberIds: <HouseholdMemberId>[
      HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
    ],
    excludedSeriesId: null,
    excludedOccurrenceId: null,
  )!;
}
