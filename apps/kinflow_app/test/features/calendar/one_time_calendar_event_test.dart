import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  group('OneTimeCalendarEventDraft', () {
    test('keeps timed intent and canonical participant order', () {
      final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
        title: '  Family dinner  ',
        participantMemberIds: <HouseholdMemberId>[
          calendarMemberTwoId(),
          calendarMemberOneId(),
        ],
      );

      expect(draft.title, 'Family dinner');
      expect(draft.timedIntent?.gapPolicy, CalendarDstGapPolicy.reject);
      expect(draft.participantMemberIds, <Object>[
        calendarMemberOneId(),
        calendarMemberTwoId(),
      ]);
      expect(draft.fingerprint, contains('"overlapPolicy":"earlier"'));
    });

    test('stores all-day dates without timezone or instant intent', () {
      final OneTimeCalendarEventDraft draft = calendarEventDraftFixture(
        isAllDay: true,
        localStartDate: '2026-08-07',
        allDayEndDateExclusive: '2026-08-10',
      );

      expect(draft.timedIntent, isNull);
      expect(draft.timeZone, isNull);
      expect(draft.localStartTime, isNull);
      expect(draft.allDayEndDateExclusive?.value, '2026-08-10');
    });

    test('rejects empty participants and invalid exclusive end', () {
      expect(
        OneTimeCalendarEventDraft.tryCreate(
          householdId: calendarHouseholdId(),
          title: 'Trip',
          description: '',
          isAllDay: true,
          localStartDate: CalendarLocalDate.tryParse('2026-08-07')!,
          localStartTime: null,
          durationMinutes: null,
          allDayEndDateExclusive: CalendarLocalDate.tryParse('2026-08-07'),
          timeZone: null,
          overlapPolicy: null,
          participantMemberIds: const <HouseholdMemberId>[],
        ),
        isNull,
      );
    });
  });

  group('OneTimeCalendarEvent', () {
    test('enforces mutually exclusive timed and all-day persistence', () {
      final OneTimeCalendarEvent timed = calendarEventFixture();
      final OneTimeCalendarEvent allDay = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        isAllDay: true,
        localStartDate: '2026-08-08',
        allDayEndDateExclusive: '2026-08-10',
      );

      expect(timed.startsAt?.value, '2026-08-07T10:00:00.000Z');
      expect(timed.endsAt?.value, '2026-08-07T11:00:00.000Z');
      expect(allDay.startsAt, isNull);
      expect(allDay.timeZone, isNull);
      expect(allDay.allDayRange?.dayCount, 2);
    });

    test('sorts all-day before timed and replaces by stable series id', () {
      final OneTimeCalendarEvent timed = calendarEventFixture();
      final OneTimeCalendarEvent allDay = calendarEventFixture(
        seriesId: calendarSeriesTwoUuid,
        occurrenceId: calendarOccurrenceTwoUuid,
        title: 'School holiday',
        isAllDay: true,
      );
      final OneTimeCalendarEventList list = calendarEventListFixture(
        events: <OneTimeCalendarEvent>[timed, allDay],
      );
      final OneTimeCalendarEvent updated = calendarEventFixture(
        title: 'Dinner updated',
        version: 2,
        occurrenceVersion: 2,
      );

      expect(list.events.first, same(allDay));
      final OneTimeCalendarEventList applied = list.apply(updated);
      expect(applied.events, hasLength(2));
      expect(applied.events.last.title, 'Dinner updated');
      expect(applied.events.last.version, 2);
    });

    test('rejects duplicate participants', () {
      final CalendarEventParticipant participant =
          CalendarEventParticipant.tryCreate(
            memberId: calendarMemberOneId(),
            displayName: 'Alex',
          )!;
      final OneTimeCalendarEvent base = calendarEventFixture();

      expect(
        OneTimeCalendarEvent.tryCreate(
          householdId: base.householdId,
          seriesId: base.seriesId,
          occurrenceId: base.occurrenceId,
          title: base.title,
          description: base.description,
          isAllDay: false,
          localStartDate: base.localStartDate,
          localStartTime: base.localStartTime,
          durationMinutes: base.durationMinutes,
          allDayEndDateExclusive: null,
          timeZone: base.timeZone,
          overlapPolicy: base.overlapPolicy,
          startsAt: base.startsAt,
          endsAt: base.endsAt,
          dstResolution: CalendarTimeResolutionKind.normal,
          utcOffsetSeconds: base.utcOffsetSeconds,
          participants: <CalendarEventParticipant>[participant, participant],
          version: 1,
          occurrenceVersion: 1,
        ),
        isNull,
      );
    });

    test(
      'rejects DST overlap metadata that contradicts the selected policy',
      () {
        final OneTimeCalendarEvent base = calendarEventFixture();

        expect(
          OneTimeCalendarEvent.tryCreate(
            householdId: base.householdId,
            seriesId: base.seriesId,
            occurrenceId: base.occurrenceId,
            title: base.title,
            description: base.description,
            isAllDay: false,
            localStartDate: base.localStartDate,
            localStartTime: base.localStartTime,
            durationMinutes: base.durationMinutes,
            allDayEndDateExclusive: null,
            timeZone: base.timeZone,
            overlapPolicy: CalendarDstOverlapPolicy.earlier,
            startsAt: base.startsAt,
            endsAt: base.endsAt,
            dstResolution: CalendarTimeResolutionKind.overlapLater,
            utcOffsetSeconds: base.utcOffsetSeconds,
            participants: base.participants,
            version: base.version,
            occurrenceVersion: base.occurrenceVersion,
          ),
          isNull,
        );
      },
    );
  });
}
