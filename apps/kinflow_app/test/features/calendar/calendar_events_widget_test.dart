import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/app.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

import '../../support/fakes/fake_auth_dependencies.dart';
import '../../support/fakes/fake_calendar_dependencies.dart';
import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_runtime_policy_dependencies.dart';

void main() {
  testWidgets('Calendar creates, edits, and deletes an all-day event', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository calendarRepository = FakeCalendarRepository();
    final FakeHouseholdMemberRepository memberRepository =
        FakeHouseholdMemberRepository();
    await _pumpCalendarApp(
      tester,
      calendarRepository: calendarRepository,
      memberRepository: memberRepository,
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar.empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar.editor')), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'School holiday',
    );
    await tester.tap(find.byKey(const Key('calendar.editor.allDay')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.list')), findsOneWidget);
    expect(find.text('School holiday'), findsOneWidget);
    expect(find.textContaining('All day'), findsOneWidget);
    expect(calendarRepository.createRequests, hasLength(1));
    expect(calendarRepository.createRequests.single.draft.isAllDay, isTrue);
    expect(
      calendarRepository
          .createRequests
          .single
          .draft
          .allDayEndDateExclusive
          ?.value,
      '2026-08-08',
    );
    expect(memberRepository.loadedHouseholds, hasLength(1));

    await tester.tap(
      find.byKey(const Key('calendar.edit.$calendarSeriesTwoUuid')),
    );
    await tester.pumpAndSettle();
    expect(
      calendarRepository.overlapPreviewRequests.last.excludedSeriesId?.value,
      calendarSeriesTwoUuid,
    );
    expect(
      calendarRepository.overlapPreviewRequests.last.excludedOccurrenceId,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'School holiday updated',
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(find.text('School holiday updated'), findsOneWidget);
    expect(calendarRepository.updateRequests, hasLength(1));
    expect(calendarRepository.updateRequests.single.expectedVersion, 1);
    expect(
      calendarRepository.updateRequests.single.occurrenceId.value,
      calendarOccurrenceTwoUuid,
    );

    await tester.tap(
      find.byKey(const Key('calendar.delete.$calendarSeriesTwoUuid')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete this event?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar.delete.confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.empty')), findsOneWidget);
    expect(calendarRepository.deleteRequests, hasLength(1));
    expect(calendarRepository.deleteRequests.single.expectedVersion, 2);
  });

  testWidgets('Calendar renders timed schedule, zone, and participants', (
    WidgetTester tester,
  ) async {
    final OneTimeCalendarEvent event = calendarEventFixture();
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[event],
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family dinner'), findsOneWidget);
    expect(find.text('Time zone: Asia/Seoul'), findsOneWidget);
    expect(find.text('With Alex'), findsOneWidget);
    expect(find.textContaining('60 minutes'), findsOneWidget);
  });

  testWidgets('same-member overlap hint is automatic and never blocks save', (
    WidgetTester tester,
  ) async {
    final CalendarOverlapPreviewRequest request = _editorPreviewRequest();
    final CalendarOverlapConflict conflict = CalendarOverlapConflict.tryCreate(
      candidateLocalStartDate: CalendarLocalDate.tryParse('2026-08-07')!,
      seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
      occurrenceId: CalendarEventOccurrenceId.tryParse(
        calendarOccurrenceOneUuid,
      )!,
      title: 'School pickup',
      isAllDay: false,
      viewLocalStartDate: CalendarLocalDate.tryParse('2026-08-07')!,
      viewLocalStartTime: CalendarLocalTime.tryParse('09:30'),
      durationMinutes: 60,
      allDayEndDateExclusive: null,
      participants: <CalendarOverlapParticipant>[
        CalendarOverlapParticipant.tryCreate(
          memberId: HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
          displayName: 'Alex',
        )!,
      ],
    )!;
    final FakeCalendarRepository repository = FakeCalendarRepository(
      overlapPreviewResults: <PreviewCalendarOverlapsResult>[
        CalendarOverlapsPreviewed(
          calendarOverlapPreviewFixture(
            request: request,
            conflicts: <CalendarOverlapConflict>[conflict],
          ),
        ),
      ],
    );
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar.editor.overlapSummary')),
      findsOneWidget,
    );
    expect(find.text('School pickup'), findsOneWidget);
    expect(find.textContaining('Alex'), findsWidgets);
    final FilledButton save = tester.widget<FilledButton>(
      find.byKey(const Key('calendar.editor.save')),
    );
    expect(save.onPressed, isNotNull);

    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Conflicting but allowed',
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, hasLength(1));
    expect(repository.overlapPreviewRequests, hasLength(1));
  });

  testWidgets('overlap preview failure remains safe and nonblocking', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository(
      overlapPreviewResults: <PreviewCalendarOverlapsResult>[
        const PreviewCalendarOverlapsFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar.editor.overlapUnavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('still save'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Save without preview',
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, hasLength(1));
  });

  testWidgets('late overlap responses cannot replace a newer editor result', (
    WidgetTester tester,
  ) async {
    final List<Completer<PreviewCalendarOverlapsResult>> completers =
        <Completer<PreviewCalendarOverlapsResult>>[];
    final FakeCalendarRepository repository = FakeCalendarRepository(
      overlapPreviewLoader: (CalendarOverlapPreviewRequest request) {
        final Completer<PreviewCalendarOverlapsResult> completer =
            Completer<PreviewCalendarOverlapsResult>();
        completers.add(completer);
        return completer.future;
      },
    );
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(completers, hasLength(1));

    await tester.tap(find.byKey(const Key('calendar.editor.allDay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(completers, hasLength(2));

    completers[1].complete(
      CalendarOverlapsPreviewed(
        calendarOverlapPreviewFixture(
          request: repository.overlapPreviewRequests[1],
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('calendar.editor.overlapNone')),
      findsOneWidget,
    );

    final CalendarOverlapConflict staleConflict =
        CalendarOverlapConflict.tryCreate(
          candidateLocalStartDate: CalendarLocalDate.tryParse('2026-08-07')!,
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          occurrenceId: CalendarEventOccurrenceId.tryParse(
            calendarOccurrenceOneUuid,
          )!,
          title: 'Stale result',
          isAllDay: false,
          viewLocalStartDate: CalendarLocalDate.tryParse('2026-08-07')!,
          viewLocalStartTime: CalendarLocalTime.tryParse('09:30'),
          durationMinutes: 60,
          allDayEndDateExclusive: null,
          participants: <CalendarOverlapParticipant>[
            CalendarOverlapParticipant.tryCreate(
              memberId: HouseholdMemberId.tryParse(calendarMemberOneUuid)!,
              displayName: 'Alex',
            )!,
          ],
        )!;
    completers[0].complete(
      CalendarOverlapsPreviewed(
        calendarOverlapPreviewFixture(
          request: repository.overlapPreviewRequests[0],
          conflicts: <CalendarOverlapConflict>[staleConflict],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Stale result'), findsNothing);
    expect(
      find.byKey(const Key('calendar.editor.overlapNone')),
      findsOneWidget,
    );
  });

  testWidgets('Calendar creates, edits, and cancels one weekly occurrence', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Weekly planning',
    );
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    await tester.tap(recurrence);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    final Finder monday = find.byKey(
      const Key('calendar.editor.recurrenceOptions.weekday.MO'),
    );
    final Finder wednesday = find.byKey(
      const Key('calendar.editor.recurrenceOptions.weekday.WE'),
    );
    final Finder friday = find.byKey(
      const Key('calendar.editor.recurrenceOptions.weekday.FR'),
    );
    await tester.ensureVisible(monday);
    expect(tester.widget<FilterChip>(friday).selected, isTrue);
    expect(tester.widget<FilterChip>(friday).onSelected, isNull);
    expect(tester.getSize(monday).height, greaterThanOrEqualTo(48));
    await tester.tap(monday);
    await tester.pumpAndSettle();
    await tester.tap(wednesday);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.recurrenceOptions.interval')),
      '2',
    );
    final Finder recurrenceEnd = find.byKey(
      const Key('calendar.editor.recurrenceOptions.end'),
    );
    await tester.ensureVisible(recurrenceEnd);
    await tester.tap(recurrenceEnd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.recurrenceOptions.count')),
      '8',
    );
    await tester.pumpAndSettle();
    final CalendarRecurrenceRule previewRule =
        repository.overlapPreviewRequests.last.recurrenceRule!;
    expect(previewRule.interval, 2);
    expect(previewRule.weekdays, const <CalendarWeekday>[
      CalendarWeekday.monday,
      CalendarWeekday.wednesday,
      CalendarWeekday.friday,
    ]);
    expect(previewRule.end, const CalendarRecurrenceCountEnd(8));
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, isEmpty);
    expect(repository.recurringCreateRequests, hasLength(1));
    expect(
      repository.recurringCreateRequests.single.draft.recurrenceRule.frequency,
      CalendarRecurrenceFrequency.weekly,
    );
    expect(
      repository.recurringCreateRequests.single.draft.recurrenceRule.interval,
      2,
    );
    expect(
      repository.recurringCreateRequests.single.draft.recurrenceRule.weekdays,
      const <CalendarWeekday>[
        CalendarWeekday.monday,
        CalendarWeekday.wednesday,
        CalendarWeekday.friday,
      ],
    );
    expect(
      repository.recurringCreateRequests.single.draft.recurrenceRule.end,
      const CalendarRecurrenceCountEnd(8),
    );
    expect(find.text('Weekly planning'), findsOneWidget);
    expect(
      find.text('Repeats Every 2 weeks on Monday, Wednesday, Friday'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('calendar.event.recurrence.$calendarOccurrenceTwoUuid'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar.edit.$calendarSeriesTwoUuid')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar.delete.$calendarSeriesTwoUuid')),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key('calendar.occurrence.edit.$calendarOccurrenceTwoUuid'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const Key('calendar.occurrence.edit.$calendarOccurrenceTwoUuid'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      repository.overlapPreviewRequests.last.excludedOccurrenceId?.value,
      calendarOccurrenceTwoUuid,
    );
    expect(repository.overlapPreviewRequests.last.excludedSeriesId, isNull);
    expect(find.text('Edit this occurrence'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Weekly planning moved',
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.updateRequests, isEmpty);
    expect(repository.occurrenceUpdateRequests, hasLength(1));
    expect(
      repository.occurrenceUpdateRequests.single.expectedOccurrenceVersion,
      1,
    );
    expect(find.text('Weekly planning moved'), findsOneWidget);
    expect(find.text('Modified occurrence'), findsOneWidget);
    expect(
      find.byKey(
        const Key('calendar.event.exception.$calendarOccurrenceTwoUuid'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const Key('calendar.occurrence.cancel.$calendarOccurrenceTwoUuid'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancel this occurrence?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('calendar.occurrence.cancel.confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.occurrenceCancelRequests, hasLength(1));
    expect(
      repository.occurrenceCancelRequests.single.expectedOccurrenceVersion,
      2,
    );
    expect(find.byKey(const Key('calendar.empty')), findsOneWidget);
  });

  testWidgets('recurring creation clamps an until date to the new start', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Weekly until date',
    );
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    await tester.tap(recurrence);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    final Finder recurrenceEnd = find.byKey(
      const Key('calendar.editor.recurrenceOptions.end'),
    );
    await tester.ensureVisible(recurrenceEnd);
    await tester.tap(recurrenceEnd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('On a date').last);
    await tester.pumpAndSettle();

    final Finder startDate = find.byKey(const Key('calendar.editor.startDate'));
    await tester.ensureVisible(startDate);
    await tester.tap(startDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Saturday, August 15, 2026'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    final CalendarRecurrenceRule rule =
        repository.recurringCreateRequests.single.draft.recurrenceRule;
    expect(rule.weekdays, const <CalendarWeekday>[
      CalendarWeekday.friday,
      CalendarWeekday.saturday,
    ]);
    expect(
      rule.end,
      CalendarRecurrenceUntilEnd(CalendarLocalDate.tryParse('2026-08-15')!),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly creation derives its locked day from the start date', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Monthly family check-in',
    );
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.monthly);
    await tester.pumpAndSettle();

    final Finder monthDay = find.byKey(
      const Key('calendar.editor.recurrenceOptions.monthDay'),
    );
    final Finder monthDayDropdown = find.descendant(
      of: monthDay,
      matching: find.byType(DropdownButtonFormField<int>),
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(monthDayDropdown).onChanged,
      isNull,
    );
    expect(find.text('Day 7'), findsOneWidget);
    expect(find.text("The event's start date sets this day."), findsOneWidget);
    expect(
      find.text(
        'Months without this date are skipped, not moved to the last day.',
      ),
      findsOneWidget,
    );
    expect(find.text('On day 7 of the month.'), findsOneWidget);

    final Finder startDate = find.byKey(const Key('calendar.editor.startDate'));
    await tester.ensureVisible(startDate);
    await tester.tap(startDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Day 15'), findsOneWidget);
    expect(find.text('On day 15 of the month.'), findsOneWidget);
    final CalendarOverlapPreviewRequest preview =
        repository.overlapPreviewRequests.last;
    expect(preview.localStartDate.value, '2026-08-15');
    expect(preview.recurrenceRule?.monthDay, 15);
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    expect(repository.recurringCreateRequests, hasLength(1));
    final RecurringCalendarEventDraft draft =
        repository.recurringCreateRequests.single.draft;
    expect(draft.event.localStartDate.value, '2026-08-15');
    expect(draft.recurrenceRule.toJson(), <String, Object?>{
      'frequency': 'monthly',
      'interval': 1,
      'monthDay': 15,
      'end': <String, Object?>{'type': 'never'},
    });
    expect(find.text('Repeats Monthly on day 15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid advanced recurrence never reaches preview or save', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar.editor.title')),
      'Invalid recurrence',
    );
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    await tester.tap(recurrence);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();

    final Finder interval = find.byKey(
      const Key('calendar.editor.recurrenceOptions.interval'),
    );
    final int previewCountBeforeInvalidInterval =
        repository.overlapPreviewRequests.length;
    await tester.enterText(interval, '0');
    await tester.pumpAndSettle();
    expect(
      repository.overlapPreviewRequests.length,
      previewCountBeforeInvalidInterval,
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pump();
    expect(find.text('Enter a number from 1 to 30.'), findsOneWidget);
    expect(repository.recurringCreateRequests, isEmpty);

    await tester.enterText(interval, '1');
    final Finder recurrenceEnd = find.byKey(
      const Key('calendar.editor.recurrenceOptions.end'),
    );
    await tester.ensureVisible(recurrenceEnd);
    await tester.tap(recurrenceEnd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a number of occurrences').last);
    await tester.pumpAndSettle();
    final int previewCountBeforeInvalidCount =
        repository.overlapPreviewRequests.length;
    await tester.enterText(
      find.byKey(const Key('calendar.editor.recurrenceOptions.count')),
      '1001',
    );
    await tester.pumpAndSettle();
    expect(
      repository.overlapPreviewRequests.length,
      previewCountBeforeInvalidCount,
    );
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pump();
    expect(find.text('Enter a number from 1 to 1,000.'), findsOneWidget);
    expect(repository.recurringCreateRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly selection survives an in-editor frequency round trip', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository();
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.create')));
    await tester.pumpAndSettle();
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.weekly);
    await tester.pumpAndSettle();
    final Finder monday = find.byKey(
      const Key('calendar.editor.recurrenceOptions.weekday.MO'),
    );
    await tester.ensureVisible(monday);
    await tester.tap(monday);
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.monthly);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar.editor.recurrenceOptions.weekdays')),
      findsNothing,
    );
    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.weekly);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(monday).selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(
              const Key('calendar.editor.recurrenceOptions.weekday.FR'),
            ),
          )
          .selected,
      isTrue,
    );
    expect(
      repository.overlapPreviewRequests.last.recurrenceRule?.weekdays,
      const <CalendarWeekday>[CalendarWeekday.monday, CalendarWeekday.friday],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('whole-series frequency change reanchors without losing bounds', (
    WidgetTester tester,
  ) async {
    final CalendarLocalDate anchor = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarRecurrenceRule sourceRule = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <Object?>['MO', 'FR'],
        'end': <String, Object?>{'type': 'count', 'count': 10},
      },
    )!;
    final OneTimeCalendarEvent visible = calendarEventFixture(
      title: 'Multi-day source',
      version: 4,
      recurrenceRule: sourceRule,
      recurrenceLocalStartDate: anchor.value,
      revisionNumber: 2,
    );
    final RecurringCalendarSeriesDetail active =
        RecurringCalendarSeriesDetail.tryCreate(
          householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
          householdLocalDate: anchor,
          seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
          revisionId: CalendarEventRevisionId.tryParse(
            calendarRevisionOneUuid,
          )!,
          revisionNumber: 2,
          event: calendarEventDraftFixture(
            title: 'Multi-day source',
            localStartDate: anchor.value,
          ),
          recurrenceRule: sourceRule,
          participantDisplayNames: const <String>['Alex'],
          version: 4,
        )!;
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(
        events: <OneTimeCalendarEvent>[visible],
      ),
      recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
        RecurringCalendarSeriesLoaded(active),
      ],
    );
    await _pumpCalendarApp(tester, calendarRepository: repository);

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calendar.series.menu.$calendarOccurrenceOneUuid')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit entire series'));
    await tester.pumpAndSettle();

    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    await tester.tap(recurrence);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
    await tester.tap(find.byKey(const Key('calendar.editor.save')));
    await tester.pumpAndSettle();

    final CalendarRecurrenceRule updated =
        repository.recurringSeriesUpdateRequests.single.draft.recurrenceRule;
    expect(updated.frequency, CalendarRecurrenceFrequency.monthly);
    expect(updated.interval, 2);
    expect(updated.monthDay, 7);
    expect(updated.weekdays, isEmpty);
    expect(updated.end, const CalendarRecurrenceCountEnd(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'whole-series monthly start change reanchors preview and update',
    (WidgetTester tester) async {
      final CalendarLocalDate anchor = CalendarLocalDate.tryParse(
        '2026-08-07',
      )!;
      final CalendarRecurrenceRule sourceRule = CalendarRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'monthly',
          'interval': 2,
          'monthDay': 7,
          'end': <String, Object?>{'type': 'count', 'count': 10},
        },
      )!;
      final OneTimeCalendarEvent visible = calendarEventFixture(
        title: 'Monthly source',
        version: 4,
        recurrenceRule: sourceRule,
        recurrenceLocalStartDate: anchor.value,
        revisionNumber: 2,
      );
      final RecurringCalendarSeriesDetail active =
          RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: anchor,
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: 2,
            event: calendarEventDraftFixture(
              title: 'Monthly source',
              localStartDate: anchor.value,
            ),
            recurrenceRule: sourceRule,
            participantDisplayNames: const <String>['Alex'],
            version: 4,
          )!;
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[visible],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(active),
        ],
      );
      await _pumpCalendarApp(tester, calendarRepository: repository);

      await tester.tap(
        find.byKey(const Key('layout.primaryNavigation.calendar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('calendar.series.menu.$calendarOccurrenceOneUuid'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit entire series'));
      await tester.pumpAndSettle();
      expect(find.text('Day 7'), findsOneWidget);

      final Finder startDate = find.byKey(
        const Key('calendar.editor.startDate'),
      );
      await tester.ensureVisible(startDate);
      await tester.tap(startDate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Day 15'), findsOneWidget);
      final CalendarRecurrenceRule changedDatePreview =
          repository.overlapPreviewRequests.last.recurrenceRule!;
      expect(changedDatePreview.monthDay, 15);
      expect(changedDatePreview.interval, 2);
      expect(changedDatePreview.end, const CalendarRecurrenceCountEnd(10));

      final Finder recurrence = find.byKey(
        const Key('calendar.editor.recurrence'),
      );
      await tester.ensureVisible(recurrence);
      tester
          .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
            recurrence,
          )
          .onChanged!(CalendarRecurrenceFrequency.daily);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('calendar.editor.recurrenceOptions.monthDay')),
        findsNothing,
      );
      tester
          .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
            recurrence,
          )
          .onChanged!(CalendarRecurrenceFrequency.monthly);
      await tester.pumpAndSettle();
      expect(find.text('Day 15'), findsOneWidget);
      expect(
        repository.overlapPreviewRequests.last.recurrenceRule?.monthDay,
        15,
      );

      await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
      await tester.tap(find.byKey(const Key('calendar.editor.save')));
      await tester.pumpAndSettle();

      expect(repository.recurringSeriesUpdateRequests, hasLength(1));
      final RecurringCalendarEventDraft draft =
          repository.recurringSeriesUpdateRequests.single.draft;
      expect(draft.event.localStartDate.value, '2026-08-15');
      expect(draft.recurrenceRule.monthDay, 15);
      expect(draft.recurrenceRule.interval, 2);
      expect(draft.recurrenceRule.end, const CalendarRecurrenceCountEnd(10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'whole-series menu edits the active source and clearly ends future scope',
    (WidgetTester tester) async {
      final CalendarLocalDate anchor = CalendarLocalDate.tryParse(
        '2026-08-07',
      )!;
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.tryParse(
        <String, Object?>{
          'frequency': 'weekly',
          'interval': 2,
          'weekdays': <Object?>['MO', 'FR'],
          'end': <String, Object?>{'type': 'count', 'count': 10},
        },
      )!;
      final OneTimeCalendarEvent visibleException = calendarEventFixture(
        title: 'Moved single occurrence',
        version: 4,
        occurrenceVersion: 2,
        recurrenceRule: rule,
        recurrenceLocalStartDate: anchor.value,
        revisionNumber: 2,
        isException: true,
      );
      final activeEvent = calendarEventDraftFixture(
        title: 'Canonical series',
        localStartDate: anchor.value,
      );
      final RecurringCalendarSeriesDetail active =
          RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: anchor,
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: 2,
            event: activeEvent,
            recurrenceRule: rule,
            participantDisplayNames: const <String>['Alex'],
            version: 4,
          )!;
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[visibleException],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(active),
        ],
      );
      await _pumpCalendarApp(tester, calendarRepository: repository);

      await tester.tap(
        find.byKey(const Key('layout.primaryNavigation.calendar')),
      );
      await tester.pumpAndSettle();
      final Finder seriesMenu = find.byKey(
        const Key('calendar.series.menu.$calendarOccurrenceOneUuid'),
      );
      await tester.ensureVisible(seriesMenu);
      await tester.tap(seriesMenu);
      await tester.pumpAndSettle();

      expect(find.text('Edit entire series'), findsOneWidget);
      expect(find.text('End entire series'), findsOneWidget);
      expect(find.text('Edit this and later'), findsNothing);
      expect(find.text('End this and later'), findsNothing);
      await tester.tap(find.text('Edit entire series'));
      await tester.pumpAndSettle();

      expect(find.text('Edit entire series'), findsOneWidget);
      expect(
        repository.overlapPreviewRequests.last.excludedSeriesId?.value,
        calendarSeriesOneUuid,
      );
      expect(repository.overlapPreviewRequests.last.windowStartDate, anchor);
      final TextFormField titleField = tester.widget<TextFormField>(
        find.byKey(const Key('calendar.editor.title')),
      );
      expect(titleField.controller?.text, 'Canonical series');
      final TextFormField intervalField = tester.widget<TextFormField>(
        find.byKey(const Key('calendar.editor.recurrenceOptions.interval')),
      );
      final TextFormField countField = tester.widget<TextFormField>(
        find.byKey(const Key('calendar.editor.recurrenceOptions.count')),
      );
      expect(intervalField.controller?.text, '2');
      expect(countField.controller?.text, '10');
      final Finder monday = find.byKey(
        const Key('calendar.editor.recurrenceOptions.weekday.MO'),
      );
      final Finder wednesday = find.byKey(
        const Key('calendar.editor.recurrenceOptions.weekday.WE'),
      );
      final Finder friday = find.byKey(
        const Key('calendar.editor.recurrenceOptions.weekday.FR'),
      );
      expect(tester.widget<FilterChip>(monday).selected, isTrue);
      expect(tester.widget<FilterChip>(friday).selected, isTrue);
      expect(tester.widget<FilterChip>(friday).onSelected, isNull);
      await tester.ensureVisible(monday);
      await tester.tap(monday);
      await tester.pumpAndSettle();
      await tester.tap(wednesday);
      await tester.pumpAndSettle();
      expect(repository.recurringSeriesLoadRequests, hasLength(1));
      await tester.enterText(
        find.byKey(const Key('calendar.editor.title')),
        'Canonical series updated',
      );
      await tester.enterText(
        find.byKey(const Key('calendar.editor.recurrenceOptions.interval')),
        '3',
      );
      await tester.enterText(
        find.byKey(const Key('calendar.editor.recurrenceOptions.count')),
        '12',
      );
      await tester.pumpAndSettle();
      final CalendarRecurrenceRule previewRule =
          repository.overlapPreviewRequests.last.recurrenceRule!;
      expect(previewRule.interval, 3);
      expect(previewRule.weekdays, const <CalendarWeekday>[
        CalendarWeekday.wednesday,
        CalendarWeekday.friday,
      ]);
      expect(previewRule.end, const CalendarRecurrenceCountEnd(12));
      await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
      await tester.tap(find.byKey(const Key('calendar.editor.save')));
      await tester.pumpAndSettle();

      expect(repository.recurringSeriesUpdateRequests, hasLength(1));
      expect(
        repository.recurringSeriesUpdateRequests.single.expectedVersion,
        4,
      );
      expect(
        repository
            .recurringSeriesUpdateRequests
            .single
            .draft
            .recurrenceRule
            .weekdays,
        const <CalendarWeekday>[
          CalendarWeekday.wednesday,
          CalendarWeekday.friday,
        ],
      );
      expect(
        repository
            .recurringSeriesUpdateRequests
            .single
            .draft
            .recurrenceRule
            .interval,
        3,
      );
      expect(
        repository
            .recurringSeriesUpdateRequests
            .single
            .draft
            .recurrenceRule
            .end,
        const CalendarRecurrenceCountEnd(12),
      );
      expect(
        repository.recurringSeriesUpdateRequests.single.draft.event.title,
        'Canonical series updated',
      );

      await tester.ensureVisible(seriesMenu);
      await tester.tap(seriesMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End entire series'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Today and future occurrences'),
        findsOneWidget,
      );
      expect(find.textContaining('Past occurrences'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar.series.cancel.confirm')));
      await tester.pumpAndSettle();

      expect(repository.recurringSeriesCancelRequests, hasLength(1));
      expect(
        repository.recurringSeriesCancelRequests.single.expectedVersion,
        5,
      );
      expect(find.byKey(const Key('calendar.empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected-occurrence menu anchors editor and forwards exact target',
    (WidgetTester tester) async {
      final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
      final CalendarLocalDate boundary = CalendarLocalDate.tryParse(
        '2026-08-12',
      )!;
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: today,
      );
      final OneTimeCalendarEvent visible = calendarEventFixture(
        title: 'Future occurrence',
        localStartDate: boundary.value,
        startsAt: '2026-08-12T10:00:00Z',
        version: 4,
        recurrenceRule: rule,
        recurrenceLocalStartDate: boundary.value,
        revisionNumber: 2,
      );
      final RecurringCalendarSeriesDetail active =
          RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: today,
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: 2,
            event: calendarEventDraftFixture(
              title: 'Canonical future series',
              localStartDate: today.value,
            ),
            recurrenceRule: rule,
            participantDisplayNames: const <String>['Alex'],
            version: 4,
          )!;
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          localDate: today.value,
          events: <OneTimeCalendarEvent>[visible],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(active),
        ],
      );
      await _pumpCalendarApp(
        tester,
        calendarRepository: repository,
        locale: const Locale('en', 'XA'),
        size: const Size(320, 568),
        textScaleFactor: 2,
      );

      await tester.tap(
        find.byKey(const Key('layout.primaryNavigation.calendar')),
      );
      await tester.pumpAndSettle();
      final Finder seriesMenu = find.byKey(
        const Key('calendar.series.menu.$calendarOccurrenceOneUuid'),
      );
      final Finder calendarScrollable = find.descendant(
        of: find.byKey(const Key('calendar.list')),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollableState = tester.state<ScrollableState>(
        calendarScrollable,
      );
      expect(scrollableState.position.maxScrollExtent, greaterThan(0));
      final double targetOffset =
          (scrollableState.position.pixels +
                  tester.getTopLeft(seriesMenu).dy -
                  240)
              .clamp(
                scrollableState.position.minScrollExtent,
                scrollableState.position.maxScrollExtent,
              );
      scrollableState.position.jumpTo(targetOffset);
      await tester.pumpAndSettle();
      expect(tester.getCenter(seriesMenu).dy, inInclusiveRange(0, 568));
      await tester.tap(seriesMenu);
      await tester.pumpAndSettle();

      final Finder selectedAction = find.byKey(
        const Key(
          'calendar.series.editFromOccurrence.$calendarOccurrenceOneUuid',
        ),
      );
      expect(selectedAction, findsOneWidget);
      await tester.tap(selectedAction);
      await tester.pumpAndSettle();

      expect(
        find.text(
          '[!! Edit this selected occurrence and every later recurring '
          'household calendar occurrence safely !!]',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '[!! The selected recurring household occurrence and every later '
          'series occurrence will use the complete new settings. Every '
          'earlier occurrence and each existing one-occurrence adjustment '
          'remains safely unchanged for the household. !!]',
        ),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(repository.overlapPreviewRequests.last.windowStartDate, boundary);
      final TextFormField titleField = tester.widget<TextFormField>(
        find.byKey(const Key('calendar.editor.title')),
      );
      expect(titleField.controller?.text, 'Canonical future series');
      await tester.enterText(
        find.byKey(const Key('calendar.editor.title')),
        'Updated selected series',
      );
      await tester.ensureVisible(find.byKey(const Key('calendar.editor.save')));
      await tester.tap(find.byKey(const Key('calendar.editor.save')));
      await tester.pumpAndSettle();

      expect(repository.recurringSeriesUpdateRequests, isEmpty);
      expect(
        repository.recurringSeriesFromOccurrenceUpdateRequests,
        hasLength(1),
      );
      final request =
          repository.recurringSeriesFromOccurrenceUpdateRequests.single;
      expect(request.effectiveOccurrenceId, visible.occurrenceId);
      expect(request.effectiveLocalDate, boundary);
      expect(request.draft.event.localStartDate, boundary);
      expect(request.draft.event.title, 'Updated selected series');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected-occurrence cancellation discloses exception scope at 200 percent',
    (WidgetTester tester) async {
      final CalendarLocalDate today = CalendarLocalDate.tryParse('2026-08-07')!;
      final CalendarLocalDate boundary = CalendarLocalDate.tryParse(
        '2026-08-12',
      )!;
      final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
        frequency: CalendarRecurrenceFrequency.daily,
        startLocalDate: today,
      );
      final OneTimeCalendarEvent visible = calendarEventFixture(
        title: 'Future occurrence',
        localStartDate: boundary.value,
        startsAt: '2026-08-12T10:00:00Z',
        version: 4,
        recurrenceRule: rule,
        recurrenceLocalStartDate: boundary.value,
        revisionNumber: 2,
      );
      final RecurringCalendarSeriesDetail active =
          RecurringCalendarSeriesDetail.tryCreate(
            householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
            householdLocalDate: today,
            seriesId: CalendarEventSeriesId.tryParse(calendarSeriesOneUuid)!,
            revisionId: CalendarEventRevisionId.tryParse(
              calendarRevisionOneUuid,
            )!,
            revisionNumber: 2,
            event: calendarEventDraftFixture(
              title: 'Canonical future series',
              localStartDate: today.value,
            ),
            recurrenceRule: rule,
            participantDisplayNames: const <String>['Alex'],
            version: 4,
          )!;
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          localDate: today.value,
          events: <OneTimeCalendarEvent>[visible],
        ),
        recurringSeriesLoadResults: <LoadRecurringCalendarSeriesResult>[
          RecurringCalendarSeriesLoaded(active),
        ],
      );
      await _pumpCalendarApp(
        tester,
        calendarRepository: repository,
        locale: const Locale('en', 'XA'),
        size: const Size(320, 568),
        textScaleFactor: 2,
      );

      await tester.tap(
        find.byKey(const Key('layout.primaryNavigation.calendar')),
      );
      await tester.pumpAndSettle();
      final Finder seriesMenu = find.byKey(
        const Key('calendar.series.menu.$calendarOccurrenceOneUuid'),
      );
      final Finder calendarScrollable = find.descendant(
        of: find.byKey(const Key('calendar.list')),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollableState = tester.state<ScrollableState>(
        calendarScrollable,
      );
      final double targetOffset =
          (scrollableState.position.pixels +
                  tester.getTopLeft(seriesMenu).dy -
                  240)
              .clamp(
                scrollableState.position.minScrollExtent,
                scrollableState.position.maxScrollExtent,
              );
      scrollableState.position.jumpTo(targetOffset);
      await tester.pumpAndSettle();
      await tester.tap(seriesMenu);
      await tester.pumpAndSettle();

      final Finder selectedCancel = find.byKey(
        const Key(
          'calendar.series.cancelFromOccurrence.$calendarOccurrenceOneUuid',
        ),
      );
      expect(selectedCancel, findsOneWidget);
      await tester.ensureVisible(selectedCancel);
      await tester.tap(selectedCancel);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calendar.series.cancelFromOccurrence.dialog')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Existing one-occurrence adjustments'),
        findsOneWidget,
      );
      final Finder confirm = find.byKey(
        const Key('calendar.series.cancelFromOccurrence.confirm'),
      );
      await tester.ensureVisible(confirm);
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(
        repository.recurringSeriesFromOccurrenceCancelRequests,
        hasLength(1),
      );
      final request =
          repository.recurringSeriesFromOccurrenceCancelRequests.single;
      expect(request.effectiveOccurrenceId, visible.occurrenceId);
      expect(request.effectiveLocalDate, boundary);
      expect(request.expectedVersion, 4);
      expect(find.byKey(const Key('calendar.empty')), findsOneWidget);
      final Finder undo = find.byKey(
        const Key('calendar.series.cancelFromOccurrence.undo'),
      );
      expect(undo, findsOneWidget);
      expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();

      expect(
        repository.recurringSeriesCancellationResumeRequests,
        hasLength(1),
      );
      expect(
        repository
            .recurringSeriesCancellationResumeRequests
            .single
            .cancellationIdempotencyKey,
        request.idempotencyKey,
      );
      expect(find.text('Future occurrence'), findsOneWidget);
      expect(
        find.byKey(
          const Key('calendar.series.cancelFromOccurrence.undo.succeeded'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recurring cards and actions use unique occurrence identities', (
    WidgetTester tester,
  ) async {
    final CalendarLocalDate anchor = CalendarLocalDate.tryParse('2026-08-07')!;
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.anchored(
      frequency: CalendarRecurrenceFrequency.daily,
      startLocalDate: anchor,
    );
    final OneTimeCalendarEvent first = calendarEventFixture(
      recurrenceRule: rule,
      recurrenceLocalStartDate: '2026-08-07',
    );
    final OneTimeCalendarEvent second = calendarEventFixture(
      occurrenceId: calendarOccurrenceTwoUuid,
      localStartDate: '2026-08-08',
      startsAt: '2026-08-08T10:00:00Z',
      recurrenceRule: rule,
      recurrenceLocalStartDate: '2026-08-08',
    );
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[first, second],
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar.event.$calendarOccurrenceOneUuid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar.event.$calendarOccurrenceTwoUuid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar.event.$calendarSeriesOneUuid')),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key('calendar.occurrence.edit.$calendarOccurrenceOneUuid'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('calendar.occurrence.edit.$calendarOccurrenceTwoUuid'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar.series.menu.$calendarOccurrenceOneUuid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar.series.menu.$calendarOccurrenceTwoUuid')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-weekday card fits compact 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    final CalendarRecurrenceRule rule = CalendarRecurrenceRule.tryParse(
      <String, Object?>{
        'frequency': 'weekly',
        'interval': 2,
        'weekdays': <Object?>['MO', 'WE', 'FR'],
        'end': <String, Object?>{'type': 'never'},
      },
    )!;
    final OneTimeCalendarEvent event = calendarEventFixture(
      recurrenceRule: rule,
      recurrenceLocalStartDate: '2026-08-07',
    );
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[event],
        ),
      ),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    final Finder recurrenceChip = find.byKey(
      const Key('calendar.event.recurrence.$calendarOccurrenceOneUuid'),
    );
    await tester.ensureVisible(recurrenceChip);

    expect(recurrenceChip, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar editor stays scrollable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(),
      locale: const Locale('en', 'XA'),
      size: const Size(320, 568),
      textScaleFactor: 2,
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    final Finder create = find.byKey(const Key('calendar.create'));
    expect(find.byKey(const Key('calendar.empty')), findsOneWidget);
    expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.editor')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    final Finder recurrence = find.byKey(
      const Key('calendar.editor.recurrence'),
    );
    await tester.ensureVisible(recurrence);
    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.weekly);
    await tester.pumpAndSettle();
    final Finder recurrenceSummary = find.byKey(
      const Key('calendar.editor.recurrenceOptions.summary'),
    );
    final Finder sunday = find.byKey(
      const Key('calendar.editor.recurrenceOptions.weekday.SU'),
    );
    await tester.ensureVisible(sunday);
    expect(tester.getSize(sunday).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(recurrenceSummary);
    expect(recurrenceSummary, findsOneWidget);
    tester
        .widget<DropdownButtonFormField<CalendarRecurrenceFrequency?>>(
          recurrence,
        )
        .onChanged!(CalendarRecurrenceFrequency.monthly);
    await tester.pumpAndSettle();
    final Finder monthDay = find.byKey(
      const Key('calendar.editor.recurrenceOptions.monthDay'),
    );
    await tester.ensureVisible(monthDay);
    expect(tester.getSize(monthDay).height, greaterThanOrEqualTo(48));
    expect(
      find.text(
        '[!! Months without this complete date are skipped safely and never '
        'moved to the final day. !!]',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar switches day and expanded month selections', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository(
      eventList: calendarEventListFixture(events: [calendarEventFixture()]),
    );
    await _pumpCalendarApp(
      tester,
      calendarRepository: repository,
      size: const Size(1200, 900),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(repository.pageRequests.last.view.name, 'day');
    expect(find.text('Family dinner'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.month.grid')), findsOneWidget);
    expect(repository.monthRequests, hasLength(1));
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('calendar.selectedDate.heading')),
      )).data,
      contains('Aug 7'),
    );

    await tester.tap(find.byKey(const Key('calendar.month.day.2026-08-08')));
    await tester.pumpAndSettle();

    expect(repository.pageRequests.last.range?.startDate.value, '2026-08-08');
    expect(repository.monthRequests, hasLength(1));
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('calendar.selectedDate.heading')),
      )).data,
      contains('Aug 8'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact month dates keep 48dp targets and perform semantics taps',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(events: [calendarEventFixture()]),
      );
      try {
        await _pumpCalendarApp(
          tester,
          calendarRepository: repository,
          size: const Size(320, 568),
        );

        await tester.tap(
          find.byKey(const Key('layout.primaryNavigation.calendar')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('calendar.view.selector.agenda')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Month').last);
        await tester.pumpAndSettle();

        final Finder day = find.byKey(
          const Key('calendar.month.day.2026-08-02'),
        );
        expect(tester.getSize(day), const Size(48, 48));

        final semanticDay = find.semantics.byLabel(RegExp(r'Aug 2, 0 events$'));
        expect(semanticDay, findsOne);
        expect(
          semanticDay.evaluate().single,
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        tester.semantics.tap(semanticDay);
        await tester.pumpAndSettle();

        expect(
          repository.pageRequests.last.range?.startDate.value,
          '2026-08-02',
        );
        expect(
          (tester.widget<Text>(
            find.byKey(const Key('calendar.selectedDate.heading')),
          )).data,
          contains('Aug 2'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'busy month dates expose disabled semantics without tap actions',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final Completer<LoadCalendarEventPageResult> refreshResponse =
          Completer<LoadCalendarEventPageResult>();
      CalendarEventPageRequest? refreshRequest;
      var pageCallCount = 0;
      var blockNextPage = false;
      final OneTimeCalendarEvent event = calendarEventFixture();
      final FakeCalendarRepository repository = FakeCalendarRepository(
        eventList: calendarEventListFixture(
          events: <OneTimeCalendarEvent>[event],
        ),
        pageLoader: (CalendarEventPageRequest request) {
          pageCallCount += 1;
          if (blockNextPage) {
            blockNextPage = false;
            refreshRequest = request;
            return refreshResponse.future;
          }
          return Future<LoadCalendarEventPageResult>.value(
            CalendarEventPageLoaded(
              _calendarPageForRequest(request, <OneTimeCalendarEvent>[event]),
            ),
          );
        },
      );
      try {
        final ProviderContainer container = await _pumpCalendarApp(
          tester,
          calendarRepository: repository,
          size: const Size(320, 568),
        );

        await tester.tap(
          find.byKey(const Key('layout.primaryNavigation.calendar')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('calendar.view.selector.agenda')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Month').last);
        await tester.pumpAndSettle();
        final int settledPageCallCount = pageCallCount;

        blockNextPage = true;
        final Future<void> refresh = container
            .read(calendarEventsProvider.notifier)
            .refresh();
        await tester.pump();
        expect(pageCallCount, settledPageCallCount + 1);

        final semanticDay = find.semantics.byLabel(RegExp(r'Aug 2, 0 events$'));
        expect(semanticDay, findsOne);
        expect(
          semanticDay.evaluate().single,
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        expect(() => tester.semantics.tap(semanticDay), throwsStateError);

        refreshResponse.complete(
          CalendarEventPageLoaded(
            _calendarPageForRequest(refreshRequest!, <OneTimeCalendarEvent>[
              event,
            ]),
          ),
        );
        await refresh;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Korean month grid follows the locale weekday order', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(
        eventList: calendarEventListFixture(events: [calendarEventFixture()]),
      ),
      locale: const Locale('ko'),
      size: const Size(1200, 900),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('일').last).dx,
      lessThan(tester.getCenter(find.text('토')).dx),
    );
    expect(find.bySemanticsLabel(RegExp('일정 1개')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleted Calendar deep link fails closed without event content', (
    WidgetTester tester,
  ) async {
    final CalendarEventOccurrenceId occurrenceId =
        CalendarEventOccurrenceId.tryParse(calendarOccurrenceOneUuid)!;
    final FakeCalendarRepository calendarRepository = FakeCalendarRepository(
      locatorResults: <LoadCalendarOccurrenceLocatorResult>[
        const LoadCalendarOccurrenceLocatorFailed(
          CalendarFailure(CalendarFailureKind.notFoundOrForbidden),
        ),
      ],
    );
    final ProviderContainer container = await _pumpCalendarApp(
      tester,
      calendarRepository: calendarRepository,
    );

    container
        .read(appRouterProvider)
        .go('/calendar/event/${occurrenceId.value}');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar.targetUnavailable')), findsOneWidget);
    expect(find.text('Event unavailable'), findsOneWidget);
    expect(find.text('Family dinner'), findsNothing);

    await tester.tap(find.byKey(const Key('calendar.targetUnavailable.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar.screen')), findsOneWidget);
  });

  testWidgets('disconnect keeps Calendar content and reconnects accessibly', (
    WidgetTester tester,
  ) async {
    final OneTimeCalendarEvent event = calendarEventFixture();
    final FakeCalendarRepository calendarRepository = FakeCalendarRepository(
      eventList: calendarEventListFixture(events: [event]),
    );
    final _WidgetCalendarSyncRepository syncRepository =
        _WidgetCalendarSyncRepository();
    addTearDown(syncRepository.dispose);
    await _pumpCalendarApp(
      tester,
      calendarRepository: calendarRepository,
      syncRepository: syncRepository,
      locale: const Locale('en', 'XA'),
      size: const Size(800, 700),
      textScaleFactor: 2,
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    syncRepository.latest.add(const CalendarSyncDisconnected());
    await tester.pump();

    expect(find.text('Family dinner'), findsOneWidget);
    expect(find.byKey(const Key('calendar.sync.disconnected')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('calendar.list')),
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();
    final Finder reconnect = find.byKey(const Key('calendar.sync.reconnect'));
    await tester.ensureVisible(reconnect);
    await tester.pumpAndSettle();
    await tester.tap(reconnect);
    await tester.pump();
    expect(syncRepository.watchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Calendar imports selected one-time and recurring ICS events through review',
    (WidgetTester tester) async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final _WidgetCalendarImportFileGateway gateway =
          _WidgetCalendarImportFileGateway(<CalendarImportFilePickResult>[
            const CalendarImportFileSelected(
              CalendarImportFile(
                displayName: 'family.ics',
                content: _widgetImportFile,
              ),
            ),
          ]);
      await _pumpCalendarApp(
        tester,
        calendarRepository: repository,
        importGateway: gateway,
        locale: const Locale('en', 'XA'),
        size: const Size(320, 568),
        textScaleFactor: 2,
      );

      await tester.tap(
        find.byKey(const Key('layout.primaryNavigation.calendar')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('calendar.list')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar.import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendarImport.screen')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('calendarImport.pick')));
      await tester.tap(find.byKey(const Key('calendarImport.pick')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendarImport.preview')), findsOneWidget);
      expect(find.text('Family holiday'), findsOneWidget);
      expect(find.text('Weekly planning'), findsOneWidget);
      expect(
        find.byKey(const Key('calendarImport.floatingDisclosure')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('calendarImport.participant.$calendarMemberOneUuid')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const Key('calendarImport.preview')),
        const Offset(0, -10000),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('calendarImport.preview')),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendarImport.submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar.screen')), findsOneWidget);
      expect(repository.createRequests, hasLength(1));
      expect(repository.recurringCreateRequests, hasLength(1));
      expect(gateway.callCount, 1);
      expect(find.textContaining('2'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial ICS import retries the same command then refreshes', (
    WidgetTester tester,
  ) async {
    final FakeCalendarRepository repository = FakeCalendarRepository(
      createResults: <CreateOneTimeCalendarEventResult>[
        const CreateOneTimeCalendarEventFailed(
          CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    await _pumpCalendarApp(
      tester,
      calendarRepository: repository,
      importGateway:
          _WidgetCalendarImportFileGateway(<CalendarImportFilePickResult>[
            const CalendarImportFileSelected(
              CalendarImportFile(
                displayName: 'one.ics',
                content: _widgetOneEventImportFile,
              ),
            ),
          ]),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendarImport.pick')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('calendarImport.preview')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendarImport.submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendarImport.submissionFailed')),
      findsOneWidget,
    );
    final Object commandId = repository.createRequests.single.idempotencyKey;

    await tester.drag(
      find.byKey(const Key('calendarImport.preview')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendarImport.retry')));
    await tester.pumpAndSettle();

    expect(repository.createRequests, hasLength(2));
    expect(repository.createRequests.last.idempotencyKey, commandId);
    expect(find.byKey(const Key('calendar.screen')), findsOneWidget);
  });

  testWidgets('Calendar runtime policy blocks file picker I/O', (
    WidgetTester tester,
  ) async {
    final _WidgetCalendarImportFileGateway gateway =
        _WidgetCalendarImportFileGateway(<CalendarImportFilePickResult>[
          const CalendarImportFilePickCancelled(),
        ]);
    await _pumpCalendarApp(
      tester,
      calendarRepository: FakeCalendarRepository(),
      importGateway: gateway,
      runtimePolicyRepository: const _CalendarWidgetRuntimePolicyRepository(
        <AppRuntimeFeature>{AppRuntimeFeature.calendar},
      ),
    );

    await tester.tap(
      find.byKey(const Key('layout.primaryNavigation.calendar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar.import')));
    await tester.pumpAndSettle();

    final FilledButton pick = tester.widget<FilledButton>(
      find.byKey(const Key('calendarImport.pick')),
    );
    expect(pick.onPressed, isNull);
    expect(gateway.callCount, 0);
  });
}

CalendarOverlapPreviewRequest _editorPreviewRequest() {
  final CalendarLocalDate date = CalendarLocalDate.tryParse('2026-08-07')!;
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

CalendarEventPage _calendarPageForRequest(
  CalendarEventPageRequest request,
  List<OneTimeCalendarEvent> events,
) {
  final CalendarAllDayRange? range = request.range;
  return calendarEventPageFixture(
    events: events,
    view: request.view,
    rangeStartDate: range?.startDate.value ?? '2026-08-07',
    rangeEndDateExclusive: range?.endDateExclusive.value,
    limit: request.limit,
    requestCursor: request.cursor?.value,
  );
}

Future<ProviderContainer> _pumpCalendarApp(
  WidgetTester tester, {
  required FakeCalendarRepository calendarRepository,
  HouseholdMemberRepository? memberRepository,
  CalendarSyncRepository? syncRepository,
  CalendarImportFileGateway? importGateway,
  AppRuntimePolicyRepository runtimePolicyRepository =
      const FakeAllowedAppRuntimePolicyRepository(),
  Locale? locale,
  Size? size,
  double textScaleFactor = 1,
}) async {
  if (size != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final FakeAuthSessionRepository authRepository = FakeAuthSessionRepository(
    restoreResult: AuthSessionAvailable(authSessionFixture()),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
      appRuntimePolicyRepositoryProvider.overrideWithValue(
        runtimePolicyRepository,
      ),
      appInitializerProvider.overrideWithValue(_successfulInitialization),
      authSessionRepositoryProvider.overrideWithValue(authRepository),
      authSignInLauncherProvider.overrideWithValue(createAuthSignInLauncher()),
      sensitiveLocalStatePurgerProvider.overrideWithValue(
        createSensitiveLocalStatePurger(),
      ),
      activeHouseholdSnapshotWriterProvider.overrideWithValue(
        createActiveHouseholdSnapshotWriter(),
      ),
      householdRepositoryProvider.overrideWithValue(
        FakeHouseholdRepository(
          defaultLoadResult: ActiveHouseholdLoaded(activeHouseholdFixture()),
        ),
      ),
      householdMemberRepositoryProvider.overrideWithValue(
        memberRepository ?? FakeHouseholdMemberRepository(),
      ),
      householdCommandIdGeneratorProvider.overrideWithValue(
        FakeHouseholdCommandIdGenerator(),
      ),
      recentAuthenticationServiceProvider.overrideWithValue(
        FakeRecentAuthenticationService(),
      ),
      choreRepositoryProvider.overrideWithValue(FakeChoreRepository()),
      choreCommandIdGeneratorProvider.overrideWithValue(
        FakeChoreCommandIdGenerator(),
      ),
      calendarRepositoryProvider.overrideWithValue(calendarRepository),
      calendarCommandIdGeneratorProvider.overrideWithValue(
        FakeCalendarCommandIdGenerator(),
      ),
      calendarTimeResolverProvider.overrideWithValue(
        TimezoneCalendarTimeResolver(),
      ),
      if (importGateway != null)
        calendarImportFileGatewayProvider.overrideWithValue(importGateway),
      if (syncRepository != null)
        calendarSyncRepositoryProvider.overrideWithValue(syncRepository),
      if (locale != null) appLocaleProvider.overrideWithValue(locale),
    ],
  );
  addTearDown(authRepository.close);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KinFlowApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _successfulInitialization() async {}

final class _WidgetCalendarSyncRepository implements CalendarSyncRepository {
  final List<StreamController<CalendarSyncSignal>> _controllers =
      <StreamController<CalendarSyncSignal>>[];

  int get watchCount => _controllers.length;

  StreamController<CalendarSyncSignal> get latest => _controllers.last;

  @override
  Stream<CalendarSyncSignal> watch(HouseholdId householdId) {
    final StreamController<CalendarSyncSignal> controller =
        StreamController<CalendarSyncSignal>.broadcast(sync: true);
    _controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final StreamController<CalendarSyncSignal> controller
        in _controllers) {
      await controller.close();
    }
  }
}

final class _WidgetCalendarImportFileGateway
    implements CalendarImportFileGateway {
  _WidgetCalendarImportFileGateway(List<CalendarImportFilePickResult> results)
    : _results = List<CalendarImportFilePickResult>.of(results);

  final List<CalendarImportFilePickResult> _results;
  var callCount = 0;

  @override
  Future<CalendarImportFilePickResult> pick() async {
    callCount += 1;
    return _results.removeAt(0);
  }
}

final class _CalendarWidgetRuntimePolicyRepository
    implements AppRuntimePolicyRepository {
  const _CalendarWidgetRuntimePolicyRepository(this.disabledFeatures);

  final Set<AppRuntimeFeature> disabledFeatures;

  @override
  Future<AppRuntimePolicyResult> load() async {
    return AppRuntimePolicySucceeded(
      runtimePolicySnapshotFixture(disabledFeatures: disabledFeatures),
    );
  }
}

const String _widgetOneEventImportFile = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:holiday@example.test
DTSTART;VALUE=DATE:20260809
SUMMARY:Family holiday
END:VEVENT
END:VCALENDAR
''';

const String _widgetImportFile = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:holiday@example.test
DTSTART;VALUE=DATE:20260809
SUMMARY:Family holiday
END:VEVENT
BEGIN:VEVENT
UID:planning@example.test
DTSTART:20260810T100000
DURATION:PT45M
RRULE:FREQ=WEEKLY;COUNT=4
SUMMARY:Weekly planning
END:VEVENT
END:VCALENDAR
''';
