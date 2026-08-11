import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';
import 'package:kinflow_app/infrastructure/cache/today_cache_invalidating_calendar_repository.dart';

import '../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'every successful Calendar mutation invalidates the Today slot',
    () async {
      final _RecordingTodayCalendarSnapshotCache cache =
          _RecordingTodayCalendarSnapshotCache();
      final OneTimeCalendarEventDraft draft = calendarEventDraftFixture();
      final CalendarRecurrenceRule recurrence = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: draft.localStartDate,
      );
      final RecurringCalendarEventDraft recurringDraft =
          RecurringCalendarEventDraft.tryCreate(
            event: draft,
            recurrenceRule: recurrence,
          )!;
      final CalendarEventSeriesId seriesId = CalendarEventSeriesId.tryParse(
        calendarSeriesOneUuid,
      )!;
      final CalendarEventOccurrenceId occurrenceId =
          CalendarEventOccurrenceId.tryParse(calendarOccurrenceOneUuid)!;
      final CalendarEventCommandId commandId = CalendarEventCommandId.tryParse(
        '66666666-6666-4666-8666-666666666666',
      )!;

      CalendarRepository repository() =>
          TodayCacheInvalidatingCalendarRepository(
            FakeCalendarRepository(
              eventList: calendarEventListFixture(
                events: <OneTimeCalendarEvent>[
                  calendarEventFixture(
                    recurrenceRule: recurrence,
                    recurrenceLocalStartDate: '2026-08-07',
                  ),
                ],
              ),
            ),
            cache,
          );

      await repository().createOneTimeEvent(draft.createRequest(commandId));
      await repository().createRecurringEvent(
        recurringDraft.createRequest(commandId),
      );
      await repository().updateRecurringSeries(
        UpdateRecurringCalendarSeriesRequest(
          idempotencyKey: commandId,
          seriesId: seriesId,
          expectedVersion: 1,
          draft: recurringDraft,
        ),
      );
      await repository().updateRecurringSeriesFromOccurrence(
        UpdateRecurringCalendarSeriesFromOccurrenceRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          effectiveOccurrenceId: occurrenceId,
          effectiveLocalDate: draft.localStartDate,
          expectedVersion: 1,
          draft: recurringDraft,
        ),
      );
      await repository().cancelRecurringSeriesFromOccurrence(
        CancelRecurringCalendarSeriesFromOccurrenceRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          effectiveOccurrenceId: occurrenceId,
          effectiveLocalDate: draft.localStartDate,
          expectedVersion: 1,
        ),
      );
      await repository().resumeRecurringSeriesCancellation(
        ResumeRecurringCalendarSeriesCancellationRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          cancellationIdempotencyKey: CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-666666666667',
          )!,
          expectedVersion: 2,
        ),
      );
      await repository().cancelRecurringSeries(
        CancelRecurringCalendarSeriesRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          expectedVersion: 1,
        ),
      );
      await repository().updateOneTimeEvent(
        draft.updateRequest(
          idempotencyKey: commandId,
          seriesId: seriesId,
          occurrenceId: occurrenceId,
          expectedVersion: 1,
        ),
      );
      await repository().deleteOneTimeEvent(
        DeleteOneTimeCalendarEventRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          occurrenceId: occurrenceId,
          expectedVersion: 1,
        ),
      );
      await repository().updateRecurringOccurrence(
        draft.updateOccurrenceRequest(
          idempotencyKey: commandId,
          seriesId: seriesId,
          occurrenceId: occurrenceId,
          expectedOccurrenceVersion: 1,
        ),
      );
      await repository().cancelRecurringOccurrence(
        CancelRecurringCalendarOccurrenceRequest(
          idempotencyKey: commandId,
          householdId: calendarHouseholdId(),
          seriesId: seriesId,
          occurrenceId: occurrenceId,
          expectedOccurrenceVersion: 1,
        ),
      );

      expect(cache.deleteCount, 11);
      expect(cache.clearCount, 0);
    },
  );

  test('transient mutation failure preserves a valid Today slot', () async {
    final _RecordingTodayCalendarSnapshotCache cache =
        _RecordingTodayCalendarSnapshotCache();
    final CalendarRepository repository =
        TodayCacheInvalidatingCalendarRepository(
          FakeCalendarRepository(
            createResults: const <CreateOneTimeCalendarEventResult>[
              CreateOneTimeCalendarEventFailed(
                CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
              ),
            ],
          ),
          cache,
        );

    await repository.createOneTimeEvent(
      calendarEventDraftFixture().createRequest(
        CalendarEventCommandId.tryParse(
          '66666666-6666-4666-8666-666666666666',
        )!,
      ),
    );

    expect(cache.deleteCount, 0);
    expect(cache.clearCount, 0);
  });

  test(
    'authorization mutation failure clears all retained read data',
    () async {
      final _RecordingTodayCalendarSnapshotCache cache =
          _RecordingTodayCalendarSnapshotCache();
      final CalendarRepository repository =
          TodayCacheInvalidatingCalendarRepository(
            FakeCalendarRepository(
              createResults: const <CreateOneTimeCalendarEventResult>[
                CreateOneTimeCalendarEventFailed(
                  CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
                ),
              ],
            ),
            cache,
          );

      await repository.createOneTimeEvent(
        calendarEventDraftFixture().createRequest(
          CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-666666666666',
          )!,
        ),
      );

      expect(cache.deleteCount, 0);
      expect(cache.clearCount, 1);
    },
  );
}

final class _RecordingTodayCalendarSnapshotCache
    implements TodayCalendarSnapshotCache {
  var deleteCount = 0;
  var clearCount = 0;

  @override
  Future<CachedTodayCalendarSnapshot?> read(
    TodayCalendarRequest request,
  ) async => null;

  @override
  Future<bool> write(TodayCalendarSnapshot snapshot) async => true;

  @override
  Future<bool> delete() async {
    deleteCount += 1;
    return true;
  }

  @override
  Future<bool> clearAll() async {
    clearCount += 1;
    return true;
  }
}
