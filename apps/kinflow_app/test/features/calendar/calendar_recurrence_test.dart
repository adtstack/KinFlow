import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test('anchored weekly and monthly rules preserve local source intent', () {
    final CalendarLocalDate date = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarRecurrenceRule weekly = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.weekly,
      startLocalDate: date,
    );
    final CalendarRecurrenceRule monthly = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.monthly,
      startLocalDate: date,
    );

    expect(weekly.weekdays, <CalendarWeekday>[CalendarWeekday.friday]);
    expect(weekly.startsOn(date), isTrue);
    expect(monthly.monthDay, 7);
    expect(monthly.startsOn(date), isTrue);
    expect(weekly.end, const CalendarRecurrenceNeverEnds());
  });

  test('advanced anchored rules enforce interval and end boundaries', () {
    final CalendarLocalDate date = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarRecurrenceRule? rule = CalendarRecurrenceRule.tryAnchored(
      frequency: CalendarRecurrenceFrequency.weekly,
      startLocalDate: date,
      interval: 3,
      end: const CalendarRecurrenceCountEnd(12),
    );

    expect(rule, isNotNull);
    expect(rule!.interval, 3);
    expect(rule.weekdays, <CalendarWeekday>[CalendarWeekday.friday]);
    expect(rule.end, const CalendarRecurrenceCountEnd(12));
    expect(rule.toJson(), <String, Object?>{
      'frequency': 'weekly',
      'interval': 3,
      'weekdays': <String>['FR'],
      'end': <String, Object?>{'type': 'count', 'count': 12},
    });
    expect(
      CalendarRecurrenceRule.tryAnchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: date,
        interval: 0,
        end: const CalendarRecurrenceNeverEnds(),
      ),
      isNull,
    );
    expect(
      CalendarRecurrenceRule.tryAnchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: date,
        interval: 31,
        end: const CalendarRecurrenceCountEnd(1001),
      ),
      isNull,
    );
    expect(
      CalendarRecurrenceRule.tryAnchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: date,
        interval: 1,
        end: CalendarRecurrenceUntilEnd(
          CalendarLocalDate.tryParse('2026-08-06')!,
        ),
      ),
      isNull,
    );
  });

  test('advanced copies preserve recurrence anchors exactly', () {
    final CalendarRecurrenceRule weekly = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <Object?>['MO', 'FR'],
        'end': <String, Object?>{'type': 'count', 'count': 8},
      },
    )!;
    final CalendarRecurrenceUntilEnd updatedEnd = CalendarRecurrenceUntilEnd(
      CalendarLocalDate.tryParse('2026-09-01')!,
    );
    final CalendarRecurrenceRule? updated = weekly.tryWithIntervalAndEnd(
      interval: 4,
      end: updatedEnd,
      minimumLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    );

    expect(updated, isNotNull);
    expect(updated!.frequency, CalendarRecurrenceFrequency.weekly);
    expect(updated.interval, 4);
    expect(updated.weekdays, <CalendarWeekday>[
      CalendarWeekday.monday,
      CalendarWeekday.friday,
    ]);
    expect(updated.end, updatedEnd);
    expect(
      weekly.tryWithIntervalAndEnd(
        interval: 1,
        end: CalendarRecurrenceUntilEnd(
          CalendarLocalDate.tryParse('2026-08-06')!,
        ),
        minimumLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
      ),
      isNull,
    );

    final CalendarRecurrenceRule monthly = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'monthly',
        'interval': 1,
        'monthDay': 31,
        'end': <String, Object?>{'type': 'never'},
      },
    )!;
    expect(
      monthly
          .tryWithIntervalAndEnd(
            interval: 2,
            end: const CalendarRecurrenceCountEnd(5),
            minimumLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
          )!
          .monthDay,
      31,
    );
  });

  test('monthly copy reanchors to the edited local start date', () {
    final CalendarLocalDate originalDate = CalendarLocalDate.tryParse(
      '2026-08-07',
    )!;
    final CalendarLocalDate editedDate = CalendarLocalDate.tryParse(
      '2026-08-15',
    )!;
    final CalendarRecurrenceRule monthly = CalendarRecurrenceRule.tryAnchored(
      frequency: CalendarRecurrenceFrequency.monthly,
      startLocalDate: originalDate,
      interval: 2,
      end: const CalendarRecurrenceCountEnd(8),
    )!;
    final CalendarRecurrenceRule? updated = monthly.tryWithMonthlyStartDate(
      sourceLocalDate: editedDate,
      interval: monthly.interval,
      end: monthly.end,
      minimumLocalDate: editedDate,
    );

    expect(updated, isNotNull);
    expect(updated!.frequency, CalendarRecurrenceFrequency.monthly);
    expect(updated.interval, 2);
    expect(updated.monthDay, 15);
    expect(updated.weekdays, isEmpty);
    expect(updated.end, const CalendarRecurrenceCountEnd(8));
    expect(updated.startsOn(editedDate), isTrue);
    expect(updated.startsOn(originalDate), isFalse);

    final CalendarRecurrenceRule daily = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: originalDate,
    );
    expect(
      daily.tryWithMonthlyStartDate(
        sourceLocalDate: editedDate,
        interval: 1,
        end: const CalendarRecurrenceNeverEnds(),
        minimumLocalDate: editedDate,
      ),
      isNull,
    );
    expect(
      monthly.tryWithMonthlyStartDate(
        sourceLocalDate: editedDate,
        interval: 1,
        end: CalendarRecurrenceUntilEnd(originalDate),
        minimumLocalDate: editedDate,
      ),
      isNull,
    );
  });

  test('weekly weekday copy validates anchors and canonicalizes ISO order', () {
    final CalendarLocalDate friday = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarRecurrenceRule weekly = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.weekly,
      startLocalDate: friday,
    );
    final CalendarRecurrenceRule? selected = weekly.tryWithWeeklyWeekdays(
      weekdays: const <CalendarWeekday>[
        CalendarWeekday.sunday,
        CalendarWeekday.friday,
        CalendarWeekday.monday,
      ],
      sourceLocalDate: friday,
      interval: 2,
      end: const CalendarRecurrenceCountEnd(20),
      minimumLocalDate: friday,
    );

    expect(selected, isNotNull);
    expect(selected!.weekdays, const <CalendarWeekday>[
      CalendarWeekday.monday,
      CalendarWeekday.friday,
      CalendarWeekday.sunday,
    ]);
    expect(selected.toJson(), <String, Object?>{
      'frequency': 'weekly',
      'interval': 2,
      'weekdays': <String>['MO', 'FR', 'SU'],
      'end': <String, Object?>{'type': 'count', 'count': 20},
    });
    expect(
      weekly
          .tryWithWeeklyWeekdays(
            weekdays: CalendarWeekday.values,
            sourceLocalDate: friday,
            interval: 1,
            end: const CalendarRecurrenceNeverEnds(),
            minimumLocalDate: friday,
          )
          ?.weekdays,
      CalendarWeekday.values,
    );
    for (final List<CalendarWeekday> invalid in <List<CalendarWeekday>>[
      const <CalendarWeekday>[],
      const <CalendarWeekday>[CalendarWeekday.monday],
      const <CalendarWeekday>[CalendarWeekday.friday, CalendarWeekday.friday],
    ]) {
      expect(
        weekly.tryWithWeeklyWeekdays(
          weekdays: invalid,
          sourceLocalDate: friday,
          interval: 1,
          end: const CalendarRecurrenceNeverEnds(),
          minimumLocalDate: friday,
        ),
        isNull,
      );
    }
    final CalendarRecurrenceRule daily = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: friday,
    );
    expect(
      daily.tryWithWeeklyWeekdays(
        weekdays: const <CalendarWeekday>[CalendarWeekday.friday],
        sourceLocalDate: friday,
        interval: 1,
        end: const CalendarRecurrenceNeverEnds(),
        minimumLocalDate: friday,
      ),
      isNull,
    );
  });

  test('strict parser round trips the supported recurrence subset', () {
    final CalendarRecurrenceRule? rule = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <Object?>['MO', 'WE'],
        'end': <String, Object?>{'type': 'count', 'count': 8},
      },
    );

    expect(rule, isNotNull);
    expect(rule!.frequency, CalendarRecurrenceFrequency.weekly);
    expect(rule.interval, 2);
    expect(rule.weekdays, <CalendarWeekday>[
      CalendarWeekday.monday,
      CalendarWeekday.wednesday,
    ]);
    expect(CalendarRecurrenceRule.tryParse(rule.toJson()), rule);
  });

  test('strict parser rejects unknown, duplicate, and locale fields', () {
    expect(
      CalendarRecurrenceRule.tryParse(<String, Object?>{
        'frequency': 'daily',
        'interval': 1,
        'end': <String, Object?>{'type': 'never'},
        'locale': 'ko-KR',
      }),
      isNull,
    );
    expect(
      CalendarRecurrenceRule.tryParse(<String, Object?>{
        'frequency': 'weekly',
        'interval': 1,
        'weekdays': <Object?>['MO', 'MO'],
        'end': <String, Object?>{'type': 'never'},
      }),
      isNull,
    );
    expect(
      CalendarRecurrenceRule.tryParse(<String, Object?>{
        'frequency': 'weekly',
        'interval': 1,
        'weekdays': <Object?>['월'],
        'end': <String, Object?>{'type': 'never'},
      }),
      isNull,
    );
  });

  test('recurrence end parser validates count and local dates', () {
    expect(
      CalendarRecurrenceEnd.tryParse(<String, Object?>{
        'type': 'count',
        'count': 1000,
      }),
      const CalendarRecurrenceCountEnd(1000),
    );
    expect(
      CalendarRecurrenceEnd.tryParse(<String, Object?>{
        'type': 'count',
        'count': 1001,
      }),
      isNull,
    );
    expect(
      CalendarRecurrenceEnd.tryParse(<String, Object?>{
        'type': 'until',
        'localDate': '2026-02-30',
      }),
      isNull,
    );
  });

  test('recurring draft binds a validated event and anchored rule', () {
    final event = calendarEventDraftFixture(localStartDate: '2026-08-07');
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.weekly,
      startLocalDate: event.localStartDate,
    );
    final RecurringCalendarEventDraft? draft =
        RecurringCalendarEventDraft.tryCreate(
          event: event,
          recurrenceRule: rule,
        );

    expect(draft, isNotNull);
    expect(draft!.fingerprint, contains('recurrenceRule'));
    expect(
      draft
          .createRequest(
            CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-000000000001',
            )!,
          )
          .draft,
      same(draft),
    );
  });

  test('recurring draft rejects an anchor outside the rule', () {
    final event = calendarEventDraftFixture(localStartDate: '2026-08-07');
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 1,
        'weekdays': <Object?>['MO'],
        'end': <String, Object?>{'type': 'never'},
      },
    )!;

    expect(
      RecurringCalendarEventDraft.tryCreate(event: event, recurrenceRule: rule),
      isNull,
    );
  });

  test('occurrence validates recurrence metadata independently of display', () {
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    );
    final event = calendarEventFixture(
      recurrenceRule: rule,
      recurrenceLocalStartDate: '2026-08-07',
      revisionNumber: 2,
    );

    expect(event.isRecurring, isTrue);
    expect(event.recurrenceRule, rule);
    expect(event.revisionNumber, 2);
    expect(event.isException, isFalse);
  });

  test('recurring snapshot enforces bounded materialization metadata', () {
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
    );
    expect(
      RecurringCalendarEventSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
        firstOccurrenceId: CalendarEventOccurrenceId.tryParse(
          calendarOccurrenceOneUuid,
        )!,
        recurrenceRule: rule,
        materializedThrough: CalendarLocalDate.tryParse('2027-08-07')!,
        materializedCount: 367,
        version: 1,
        created: true,
      ),
      isNull,
    );
  });

  test('active series detail binds the editable revision and version', () {
    final event = calendarEventDraftFixture(localStartDate: '2026-08-07');
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.weekly,
      startLocalDate: event.localStartDate,
    );
    final RecurringCalendarSeriesDetail? detail =
        RecurringCalendarSeriesDetail.tryCreate(
          householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
          householdLocalDate: CalendarLocalDate.tryParse('2026-08-07')!,
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          revisionId: CalendarEventRevisionId.tryParse(
            calendarRevisionOneUuid,
          )!,
          revisionNumber: 3,
          event: event,
          recurrenceRule: rule,
          participantDisplayNames: const <String>['Alex'],
          version: 4,
        );

    expect(detail, isNotNull);
    expect(detail!.draft.recurrenceRule, rule);
    expect(detail.participantDisplayNames, const <String>['Alex']);
    final UpdateRecurringCalendarSeriesRequest request = detail.updateRequest(
      idempotencyKey: CalendarEventCommandId.tryParse(
        '66666666-6666-4666-8666-000000000002',
      )!,
      updatedDraft: detail.draft,
    );
    expect(request.expectedVersion, 4);
    expect(request.seriesId, detail.seriesId);
  });

  test('selected-occurrence series draft owns its future boundary and key', () {
    final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarLocalDate boundary = today.addDays(5);
    final event = calendarEventDraftFixture(localStartDate: boundary.value);
    final RecurringCalendarEventDraft recurring =
        RecurringCalendarEventDraft.tryCreate(
          event: event,
          recurrenceRule: CalendarRecurrenceRule.anchored(
            frequency: CalendarRecurrenceFrequency.daily,
            startLocalDate: boundary,
          ),
        )!;
    final RecurringCalendarSeriesFromOccurrenceUpdateDraft? update =
        RecurringCalendarSeriesFromOccurrenceUpdateDraft.tryCreate(
          householdId: calendarHouseholdId(),
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          effectiveOccurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
          effectiveLocalDate: boundary,
          householdLocalDate: today,
          expectedVersion: 4,
          draft: recurring,
        );

    expect(update, isNotNull);
    expect(update!.fingerprint, contains(calendarOccurrenceOneUuid));
    expect(update.fingerprint, contains(boundary.value));
    final request = update.withId(
      CalendarEventCommandId.tryParse('66666666-6666-4666-8666-000000000003')!,
    );
    expect(request.effectiveOccurrenceId.value, calendarOccurrenceOneUuid);
    expect(request.expectedVersion, 4);
    expect(
      RecurringCalendarSeriesFromOccurrenceUpdateDraft.tryCreate(
        householdId: calendarHouseholdId(),
        seriesId: request.seriesId,
        effectiveOccurrenceId: request.effectiveOccurrenceId,
        effectiveLocalDate: boundary,
        householdLocalDate: today,
        expectedVersion: 4,
        draft: RecurringCalendarEventDraft.tryCreate(
          event: calendarEventDraftFixture(localStartDate: today.value),
          recurrenceRule: CalendarRecurrenceRule.anchored(
            frequency: CalendarRecurrenceFrequency.daily,
            startLocalDate: today,
          ),
        )!,
      ),
      isNull,
    );
  });

  test(
    'selected-occurrence cancellation binds target slot and terminal pair',
    () {
      final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
      final CalendarLocalDate boundary = today.addDays(5);
      final RecurringCalendarSeriesFromOccurrenceCancellationDraft? draft =
          RecurringCalendarSeriesFromOccurrenceCancellationDraft.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            effectiveOccurrenceId: CalendarEventOccurrenceId.tryParse(
              calendarOccurrenceOneUuid,
            )!,
            effectiveLocalDate: boundary,
            householdLocalDate: today,
            expectedVersion: 4,
          );

      expect(draft, isNotNull);
      expect(draft!.fingerprint, contains(calendarOccurrenceOneUuid));
      expect(draft.fingerprint, contains(boundary.value));
      final CancelRecurringCalendarSeriesFromOccurrenceRequest request = draft
          .withId(
            CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-000000000004',
            )!,
          );
      expect(request.effectiveOccurrenceId.value, calendarOccurrenceOneUuid);
      expect(request.effectiveLocalDate, boundary);
      expect(request.expectedVersion, 4);
      expect(
        RecurringCalendarSeriesFromOccurrenceCancellationDraft.tryCreate(
          householdId: calendarHouseholdId(),
          seriesId: request.seriesId,
          effectiveOccurrenceId: request.effectiveOccurrenceId,
          effectiveLocalDate: today.addDays(-1),
          householdLocalDate: today,
          expectedVersion: 4,
        ),
        isNull,
      );

      final RecurringCalendarSeriesFromOccurrenceCancellationSnapshot?
      snapshot =
          RecurringCalendarSeriesFromOccurrenceCancellationSnapshot.tryCreate(
            householdId: calendarHouseholdId(),
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: today,
            seriesId: request.seriesId,
            effectiveLocalDate: boundary,
            version: 5,
            cancelledCount: 20,
            preservedPastCount: 7,
            terminalRevisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionTerminalUuid,
            ),
            terminalRevisionNumber: 5,
            changed: true,
          );
      expect(snapshot?.retainsScheduledPrefix, isTrue);
      expect(
        RecurringCalendarSeriesFromOccurrenceCancellationSnapshot.tryCreate(
          householdId: calendarHouseholdId(),
          householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
          householdLocalDate: today,
          seriesId: request.seriesId,
          effectiveLocalDate: boundary,
          version: 5,
          cancelledCount: 20,
          preservedPastCount: 7,
          terminalRevisionId: null,
          terminalRevisionNumber: 5,
          changed: true,
        ),
        isNull,
      );
    },
  );

  test(
    'selected cancellation resume binds the original command and version',
    () {
      final ResumeRecurringCalendarSeriesCancellationDraft? draft =
          ResumeRecurringCalendarSeriesCancellationDraft.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            cancellationIdempotencyKey: CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-000000000004',
            )!,
            expectedVersion: 5,
          );

      expect(draft, isNotNull);
      expect(draft!.fingerprint, contains('resumeRecurringCalendar'));
      expect(draft.fingerprint, contains('000000000004'));
      final ResumeRecurringCalendarSeriesCancellationRequest request = draft
          .withId(
            CalendarEventCommandId.tryParse(
              '66666666-6666-4666-8666-000000000005',
            )!,
          );
      expect(request.expectedVersion, 5);
      expect(
        request.cancellationIdempotencyKey.value,
        '66666666-6666-4666-8666-000000000004',
      );
      expect(
        ResumeRecurringCalendarSeriesCancellationDraft.tryCreate(
          householdId: request.householdId,
          seriesId: request.seriesId,
          cancellationIdempotencyKey: request.cancellationIdempotencyKey,
          expectedVersion: 0,
        ),
        isNull,
      );
      expect(
        RecurringCalendarSeriesCancellationResumeSnapshot.tryCreate(
          householdId: request.householdId,
          seriesId: request.seriesId,
          effectiveLocalDate: CalendarLocalDate.tryParse('2026-08-12')!,
          version: 6,
          restoredCount: 20,
          preservedPastCount: 7,
          revisionId: CalendarEventRevisionId.tryParse(
            calendarRevisionResumedUuid,
          )!,
          revisionNumber: 6,
          changed: true,
        ),
        isNotNull,
      );
    },
  );

  test('series command snapshots accept a server-owned future boundary', () {
    final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
    expect(
      RecurringCalendarSeriesUpdateSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
        householdLocalDate: today,
        seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
        revisionId: CalendarEventRevisionId.tryParse(calendarRevisionOneUuid)!,
        revisionNumber: 2,
        effectiveLocalDate: today.addDays(1),
        materializedThrough: today.addDays(365),
        version: 2,
        rebuiltCount: 10,
        cancelledCount: 2,
        preservedExceptionCount: 1,
        changed: true,
      ),
      isNotNull,
    );
    expect(
      RecurringCalendarSeriesUpdateSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
        householdLocalDate: today,
        seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
        revisionId: CalendarEventRevisionId.tryParse(calendarRevisionOneUuid)!,
        revisionNumber: 2,
        effectiveLocalDate: today.addDays(-1),
        materializedThrough: today.addDays(365),
        version: 2,
        rebuiltCount: 10,
        cancelledCount: 2,
        preservedExceptionCount: 1,
        changed: true,
      ),
      isNull,
    );
    expect(
      RecurringCalendarSeriesCancellationSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
        householdLocalDate: today,
        seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
        effectiveLocalDate: today,
        version: 3,
        cancelledCount: 8,
        preservedPastCount: 4,
        changed: true,
      ),
      isNotNull,
    );
  });
}
