import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test('builds an occurrence update from canonical draft identity', () {
    final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
      title: '  ignored by fixture normalization  ',
    );
    final UpdateRecurringCalendarOccurrenceRequest request = draft
        .updateOccurrenceRequest(
          idempotencyKey: CalendarEventCommandId.tryParse(
            '66666666-6666-4666-8666-666666666666',
          )!,
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          occurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
          expectedOccurrenceVersion: 7,
        );

    expect(request.draft.title, 'ignored by fixture normalization');
    expect(request.expectedOccurrenceVersion, 7);
    expect(request.occurrenceId.value, calendarOccurrenceOneUuid);
  });

  test('requires an immutable revision for a non-cancelled exception', () {
    final CalendarEventSeriesId seriesId = CalendarEventSeriesId.tryParse(
      calendarSeriesOneUuid,
    )!;
    final CalendarEventOccurrenceId occurrenceId =
        CalendarEventOccurrenceId.tryParse(calendarOccurrenceOneUuid)!;

    expect(
      RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        revisionId: null,
        occurrenceVersion: 2,
        exceptionVersion: 1,
        cancelled: false,
        changed: true,
      ),
      isNull,
    );
    expect(
      RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
        householdId: calendarHouseholdId(),
        seriesId: seriesId,
        occurrenceId: occurrenceId,
        revisionId: CalendarEventRevisionId.tryParse(calendarRevisionOneUuid),
        occurrenceVersion: 2,
        exceptionVersion: 1,
        cancelled: false,
        changed: true,
      ),
      isNotNull,
    );
  });

  test(
    'allows cancellation-only exception snapshots but rejects bad versions',
    () {
      final CalendarEventSeriesId seriesId = CalendarEventSeriesId.tryParse(
        calendarSeriesOneUuid,
      )!;
      final CalendarEventOccurrenceId occurrenceId =
          CalendarEventOccurrenceId.tryParse(calendarOccurrenceOneUuid)!;

      final RecurringCalendarOccurrenceCommandSnapshot? cancelled =
          RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: seriesId,
            occurrenceId: occurrenceId,
            revisionId: null,
            occurrenceVersion: 2,
            exceptionVersion: 1,
            cancelled: true,
            changed: false,
          );
      final RecurringCalendarOccurrenceCommandSnapshot? invalid =
          RecurringCalendarOccurrenceCommandSnapshot.tryCreate(
            householdId: calendarHouseholdId(),
            seriesId: seriesId,
            occurrenceId: occurrenceId,
            revisionId: null,
            occurrenceVersion: 0,
            exceptionVersion: 1,
            cancelled: true,
            changed: true,
          );

      expect(cancelled?.revisionId, isNull);
      expect(cancelled?.cancelled, isTrue);
      expect(invalid, isNull);
    },
  );
}
