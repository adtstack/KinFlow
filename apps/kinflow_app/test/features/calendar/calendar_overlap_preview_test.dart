import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'timed preview request normalizes participants without event content',
    () {
      final CalendarOverlapPreviewRequest? request =
          CalendarOverlapPreviewRequest.tryCreate(
            householdId: calendarHouseholdId(),
            isAllDay: false,
            localStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
            localStartTime: CalendarLocalTime.tryParse('09:30'),
            durationMinutes: 60,
            allDayEndDateExclusive: null,
            timeZone: IanaTimeZoneId.tryParse('Asia/Seoul'),
            overlapPolicy: CalendarDstOverlapPolicy.earlier,
            recurrenceRule: null,
            windowStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
            participantMemberIds: <HouseholdMemberId>[
              HouseholdMemberId.tryParse(calendarMemberTwoUuid)!,
              HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
            ],
            excludedSeriesId: CalendarEventSeriesId.tryParse(
              calendarSeriesOneUuid,
            ),
            excludedOccurrenceId: null,
          );

      expect(request, isNotNull);
      expect(
        request!.participantMemberIds.map((HouseholdMemberId id) => id.value),
        <String>[calendarMemberOneUuid, calendarMemberTwoUuid],
      );
      expect(request.fingerprint, isNot(contains('title')));
      expect(request.fingerprint, isNot(contains('description')));
      expect(request.fingerprint, contains(calendarSeriesOneUuid));
    },
  );

  test(
    'recurring preview permits an effective window before a future anchor',
    () {
      final CalendarLocalDate anchor = CalendarLocalDate.tryParse(
        '2026-09-01',
      )!;
      final CalendarOverlapPreviewRequest? request =
          CalendarOverlapPreviewRequest.tryCreate(
            householdId: calendarHouseholdId(),
            isAllDay: true,
            localStartDate: anchor,
            localStartTime: null,
            durationMinutes: null,
            allDayEndDateExclusive: anchor.addDays(1),
            timeZone: null,
            overlapPolicy: null,
            recurrenceRule: CalendarRecurrenceRule.anchored(
              frequency: CalendarRecurrenceFrequency.weekly,
              startLocalDate: anchor,
            ),
            windowStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
            participantMemberIds: <HouseholdMemberId>[
              HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
            ],
            excludedSeriesId: CalendarEventSeriesId.tryParse(
              calendarSeriesOneUuid,
            ),
            excludedOccurrenceId: null,
          );

      expect(request, isNotNull);
      expect(request!.windowStartDate.value, '2026-08-08');
      expect(request.recurrenceRule, isNotNull);
    },
  );

  test('request rejects invalid schedule and ambiguous self-exclusion', () {
    final HouseholdMemberId member = HouseholdMemberId.tryParse(
      calendarMemberOneUuid,
    )!;
    expect(
      CalendarOverlapPreviewRequest.tryCreate(
        householdId: calendarHouseholdId(),
        isAllDay: false,
        localStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
        localStartTime: null,
        durationMinutes: 60,
        allDayEndDateExclusive: null,
        timeZone: IanaTimeZoneId.tryParse('Asia/Seoul'),
        overlapPolicy: CalendarDstOverlapPolicy.earlier,
        recurrenceRule: null,
        windowStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
        participantMemberIds: <HouseholdMemberId>[member],
        excludedSeriesId: null,
        excludedOccurrenceId: null,
      ),
      isNull,
    );
    expect(
      CalendarOverlapPreviewRequest.tryCreate(
        householdId: calendarHouseholdId(),
        isAllDay: true,
        localStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
        localStartTime: null,
        durationMinutes: null,
        allDayEndDateExclusive: CalendarLocalDate.tryParse('2026-08-09'),
        timeZone: null,
        overlapPolicy: null,
        recurrenceRule: null,
        windowStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
        participantMemberIds: <HouseholdMemberId>[member],
        excludedSeriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid),
        excludedOccurrenceId: CalendarEventOccurrenceId.tryParse(
          calendarOccurrenceOneUuid,
        ),
      ),
      isNull,
    );
  });

  test('preview accepts ordered exact conflicts and bounded truncation', () {
    final CalendarOverlapConflict first = _conflict(
      occurrenceId: calendarOccurrenceOneUuid,
      startTime: '09:00',
    );
    final CalendarOverlapConflict second = _conflict(
      occurrenceId: calendarOccurrenceTwoUuid,
      startTime: '10:00',
    );
    final CalendarOverlapPreview? preview = CalendarOverlapPreview.tryCreate(
      householdId: calendarHouseholdId(),
      householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
      householdLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
      generatedAt: UtcInstant.tryParse('2026-08-08T00:00:00Z')!,
      checkedFromLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
      checkedThroughLocalDate: CalendarLocalDate.tryParse('2027-08-08')!,
      candidateOccurrenceCount: 52,
      totalConflictCount: 3,
      truncated: true,
      conflicts: <CalendarOverlapConflict>[first, second],
    );

    expect(preview, isNotNull);
    expect(preview!.hasConflicts, isTrue);
    expect(preview.truncated, isTrue);
  });

  test('preview rejects duplicate pairs and non-deterministic ordering', () {
    final CalendarOverlapConflict later = _conflict(
      occurrenceId: calendarOccurrenceTwoUuid,
      startTime: '10:00',
    );
    final CalendarOverlapConflict earlier = _conflict(
      occurrenceId: calendarOccurrenceOneUuid,
      startTime: '09:00',
    );
    CalendarOverlapPreview? create(List<CalendarOverlapConflict> conflicts) {
      return CalendarOverlapPreview.tryCreate(
        householdId: calendarHouseholdId(),
        householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
        householdLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
        generatedAt: UtcInstant.tryParse('2026-08-08T00:00:00Z')!,
        checkedFromLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
        checkedThroughLocalDate: CalendarLocalDate.tryParse('2026-08-08')!,
        candidateOccurrenceCount: 1,
        totalConflictCount: conflicts.length,
        truncated: false,
        conflicts: conflicts,
      );
    }

    expect(create(<CalendarOverlapConflict>[later, earlier]), isNull);
    expect(create(<CalendarOverlapConflict>[earlier, earlier]), isNull);
  });
}

CalendarOverlapConflict _conflict({
  required String occurrenceId,
  required String startTime,
}) {
  return CalendarOverlapConflict.tryCreate(
    candidateLocalStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
    seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
    occurrenceId: CalendarEventOccurrenceId.tryParse(occurrenceId)!,
    title: 'Existing event',
    isAllDay: false,
    viewLocalStartDate: CalendarLocalDate.tryParse('2026-08-08')!,
    viewLocalStartTime: CalendarLocalTime.tryParse(startTime),
    durationMinutes: 60,
    allDayEndDateExclusive: null,
    participants: <CalendarOverlapParticipant>[
      CalendarOverlapParticipant.tryCreate(
        memberId: HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
        displayName: 'Alex',
      )!,
    ],
  )!;
}
