import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_controller.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_state.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/data/services/timezone_calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'cancellation returns to initial state without command or repository I/O',
    () async {
      final _FakeImportFileGateway gateway = _FakeImportFileGateway(
        <CalendarImportFilePickResult>[const CalendarImportFilePickCancelled()],
      );
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      final CalendarImportController controller = _controller(
        gateway: gateway,
        repository: repository,
        ids: ids,
      );
      addTearDown(controller.dispose);

      await _pick(controller);

      expect(controller.state, isA<CalendarImportInitial>());
      expect(gateway.callCount, 1);
      expect(ids.callCount, 0);
      expect(repository.createRequests, isEmpty);
    },
  );

  test(
    'policy change while picker is open discards the returned source',
    () async {
      final Completer<CalendarImportFilePickResult> selected =
          Completer<CalendarImportFilePickResult>();
      final _DeferredImportFileGateway gateway = _DeferredImportFileGateway(
        selected.future,
      );
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      var blocked = false;
      final CalendarImportController controller = _controller(
        gateway: gateway,
        repository: repository,
        ids: ids,
        mutationsBlocked: () => blocked,
      );
      addTearDown(controller.dispose);

      final Future<void> pick = _pick(controller);
      expect(controller.state, isA<CalendarImportPicking>());
      blocked = true;
      selected.complete(
        const CalendarImportFileSelected(
          CalendarImportFile(displayName: 'family.ics', content: _oneEventFile),
        ),
      );
      await pick;

      expect(controller.state, isA<CalendarImportInitial>());
      expect(gateway.callCount, 1);
      expect(ids.callCount, 0);
      expect(repository.createRequests, isEmpty);
    },
  );

  test(
    'preselects supported events and only the current participant',
    () async {
      final CalendarImportController controller = _controller(
        gateway: _selectedGateway(_twoEventFile),
        repository: FakeCalendarRepository(),
        ids: FakeCalendarCommandIdGenerator(),
      );
      addTearDown(controller.dispose);

      await _pick(controller);

      final CalendarImportSelection selection =
          (controller.state as CalendarImportReady).selection;
      expect(selection.document.candidates, hasLength(2));
      expect(selection.selectedSourceIndexes, <int>{0, 1});
      expect(selection.participantMemberIds, <Object>{calendarMemberOneId()});

      controller.toggleCandidate(1);
      controller.toggleParticipant(calendarMemberTwoId());
      final CalendarImportSelection edited =
          (controller.state as CalendarImportReady).selection;
      expect(edited.selectedSourceIndexes, <int>{0});
      expect(edited.participantMemberIds, <Object>{
        calendarMemberOneId(),
        calendarMemberTwoId(),
      });
    },
  );

  test(
    'creates selected one-time and recurring events in preview order',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      final CalendarImportController controller = _controller(
        gateway: _selectedGateway(_twoEventFile),
        repository: repository,
        ids: ids,
      );
      addTearDown(controller.dispose);
      await _pick(controller);

      await controller.importSelected();

      expect(controller.state, isA<CalendarImportCompleted>());
      expect((controller.state as CalendarImportCompleted).importedCount, 2);
      expect(repository.createRequests, hasLength(1));
      expect(repository.createRequests.single.draft.title, 'One time');
      expect(repository.recurringCreateRequests, hasLength(1));
      expect(
        repository.recurringCreateRequests.single.draft.event.title,
        'Weekly',
      );
      expect(ids.callCount, 2);
      expect(
        repository.createRequests.single.idempotencyKey,
        isNot(repository.recurringCreateRequests.single.idempotencyKey),
      );
    },
  );

  test(
    'stops on first failure and retries with the same frozen command ID',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository(
        recurringCreateResults: <CreateRecurringCalendarEventResult>[
          const CreateRecurringCalendarEventFailed(
            CalendarFailure(CalendarFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      final CalendarImportController controller = _controller(
        gateway: _selectedGateway(_twoEventFile),
        repository: repository,
        ids: ids,
      );
      addTearDown(controller.dispose);
      await _pick(controller);

      await controller.importSelected();

      final CalendarImportSubmissionFailed failed =
          controller.state as CalendarImportSubmissionFailed;
      expect(failed.completedCount, 1);
      expect(failed.totalCount, 2);
      expect(repository.createRequests, hasLength(1));
      expect(repository.recurringCreateRequests, hasLength(1));
      final Object retryKey =
          repository.recurringCreateRequests.single.idempotencyKey;
      expect(ids.callCount, 2);

      await controller.retryImport();

      expect(controller.state, isA<CalendarImportCompleted>());
      expect(repository.createRequests, hasLength(1));
      expect(repository.recurringCreateRequests, hasLength(2));
      expect(repository.recurringCreateRequests.last.idempotencyKey, retryKey);
      expect(ids.callCount, 2);
    },
  );

  test('dispose during a write prevents remaining batch I/O', () async {
    final Completer<CreateOneTimeCalendarEventResult> firstWrite =
        Completer<CreateOneTimeCalendarEventResult>();
    final FakeCalendarRepository repository = FakeCalendarRepository(
      createLoader: (_) => firstWrite.future,
    );
    final FakeCalendarCommandIdGenerator ids = FakeCalendarCommandIdGenerator();
    final CalendarImportController controller = _controller(
      gateway: _selectedGateway(_twoEventFile),
      repository: repository,
      ids: ids,
    );
    await _pick(controller);

    final Future<void> import = controller.importSelected();
    expect(controller.state, isA<CalendarImportSubmitting>());
    expect(repository.createRequests, hasLength(1));
    await controller.dispose();
    firstWrite.complete(
      OneTimeCalendarEventCreated(
        calendarEventFromDraft(
          repository.createRequests.single.draft,
          seriesId: calendarSeriesTwoUuid,
          occurrenceId: calendarOccurrenceTwoUuid,
        ),
      ),
    );
    await import;

    expect(repository.recurringCreateRequests, isEmpty);
    expect(ids.callCount, 2);
  });

  test(
    'policy change pauses before the next write and retry resumes',
    () async {
      var blocked = false;
      final FakeCalendarRepository repository = FakeCalendarRepository(
        createLoader: (request) async {
          blocked = true;
          return OneTimeCalendarEventCreated(
            calendarEventFromDraft(
              request.draft,
              seriesId: calendarSeriesTwoUuid,
              occurrenceId: calendarOccurrenceTwoUuid,
            ),
          );
        },
      );
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      final CalendarImportController controller = _controller(
        gateway: _selectedGateway(_twoEventFile),
        repository: repository,
        ids: ids,
        mutationsBlocked: () => blocked,
      );
      addTearDown(controller.dispose);
      await _pick(controller);

      await controller.importSelected();

      final CalendarImportSubmissionFailed paused =
          controller.state as CalendarImportSubmissionFailed;
      expect(paused.completedCount, 1);
      expect(repository.createRequests, hasLength(1));
      expect(repository.recurringCreateRequests, isEmpty);
      expect(ids.callCount, 2);

      blocked = false;
      await controller.retryImport();

      expect(controller.state, isA<CalendarImportCompleted>());
      expect(repository.createRequests, hasLength(1));
      expect(repository.recurringCreateRequests, hasLength(1));
      expect(ids.callCount, 2);
    },
  );

  test(
    'empty selection and empty participants never allocate command IDs',
    () async {
      final FakeCalendarRepository repository = FakeCalendarRepository();
      final FakeCalendarCommandIdGenerator ids =
          FakeCalendarCommandIdGenerator();
      final CalendarImportController controller = _controller(
        gateway: _selectedGateway(_oneEventFile),
        repository: repository,
        ids: ids,
      );
      addTearDown(controller.dispose);
      await _pick(controller);
      controller.toggleCandidate(0);

      await controller.importSelected();

      expect(controller.state, isA<CalendarImportReady>());
      expect(ids.callCount, 0);
      expect(repository.createRequests, isEmpty);

      controller.toggleCandidate(0);
      controller.toggleParticipant(calendarMemberOneId());
      await controller.importSelected();
      expect(controller.state, isA<CalendarImportReady>());
      expect(ids.callCount, 0);
    },
  );

  test('maps picker and parse failures to explicit safe states', () async {
    final List<
      ({
        CalendarImportFilePickResult result,
        CalendarImportLoadFailureKind kind,
      })
    >
    fixtures =
        <
          ({
            CalendarImportFilePickResult result,
            CalendarImportLoadFailureKind kind,
          })
        >[
          (
            result: const CalendarImportFilePickerUnavailable(),
            kind: CalendarImportLoadFailureKind.pickerUnavailable,
          ),
          (
            result: const CalendarImportFilePickFailed(),
            kind: CalendarImportLoadFailureKind.pickerFailed,
          ),
          (
            result: const CalendarImportFileTooLarge(),
            kind: CalendarImportLoadFailureKind.tooLarge,
          ),
          (
            result: const CalendarImportFileSelected(
              CalendarImportFile(
                displayName: 'bad.ics',
                content: 'not a calendar',
              ),
            ),
            kind: CalendarImportLoadFailureKind.invalidFile,
          ),
        ];
    for (final fixture in fixtures) {
      final CalendarImportController controller = _controller(
        gateway: _FakeImportFileGateway(<CalendarImportFilePickResult>[
          fixture.result,
        ]),
        repository: FakeCalendarRepository(),
        ids: FakeCalendarCommandIdGenerator(),
      );

      await _pick(controller);

      expect((controller.state as CalendarImportLoadFailed).kind, fixture.kind);
      await controller.dispose();
    }
  });
}

CalendarImportController _controller({
  required CalendarImportFileGateway gateway,
  required FakeCalendarRepository repository,
  required FakeCalendarCommandIdGenerator ids,
  bool Function()? mutationsBlocked,
}) {
  final TimezoneCalendarTimeResolver resolver = TimezoneCalendarTimeResolver();
  return CalendarImportController(
    fileGateway: gateway,
    parser: IcalendarImportParser(resolver),
    repository: repository,
    idGenerator: ids,
    mutationsBlocked: mutationsBlocked ?? () => false,
  );
}

Future<void> _pick(CalendarImportController controller) {
  return controller.pickFile(
    householdId: calendarHouseholdId(),
    householdTimeZone: IanaTimeZoneId.tryParse('Asia/Seoul')!,
    currentMemberId: calendarMemberOneId(),
    availableParticipantIds: [calendarMemberOneId(), calendarMemberTwoId()],
  );
}

_FakeImportFileGateway _selectedGateway(String content) {
  return _FakeImportFileGateway(<CalendarImportFilePickResult>[
    CalendarImportFileSelected(
      CalendarImportFile(displayName: 'family.ics', content: content),
    ),
  ]);
}

final class _FakeImportFileGateway implements CalendarImportFileGateway {
  _FakeImportFileGateway(List<CalendarImportFilePickResult> results)
    : _results = List<CalendarImportFilePickResult>.of(results);

  final List<CalendarImportFilePickResult> _results;
  var callCount = 0;

  @override
  Future<CalendarImportFilePickResult> pick() async {
    callCount += 1;
    return _results.removeAt(0);
  }
}

final class _DeferredImportFileGateway implements CalendarImportFileGateway {
  _DeferredImportFileGateway(this.result);

  final Future<CalendarImportFilePickResult> result;
  var callCount = 0;

  @override
  Future<CalendarImportFilePickResult> pick() {
    callCount += 1;
    return result;
  }
}

const String _oneEventFile = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:one@example.test
DTSTART;VALUE=DATE:20260809
SUMMARY:One time
END:VEVENT
END:VCALENDAR
''';

const String _twoEventFile = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:one@example.test
DTSTART;VALUE=DATE:20260809
SUMMARY:One time
END:VEVENT
BEGIN:VEVENT
UID:weekly@example.test
DTSTART:20260810T010000Z
DURATION:PT30M
RRULE:FREQ=WEEKLY;COUNT=4
SUMMARY:Weekly
END:VEVENT
END:VCALENDAR
''';
