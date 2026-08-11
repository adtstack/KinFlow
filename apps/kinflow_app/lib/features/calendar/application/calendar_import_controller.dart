import 'dart:async';

import 'package:kinflow_app/features/calendar/application/calendar_import_state.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_import.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class CalendarImportController {
  factory CalendarImportController({
    required CalendarImportFileGateway fileGateway,
    required IcalendarImportParser parser,
    required CalendarRepository repository,
    required CalendarCommandIdGenerator idGenerator,
    required bool Function() mutationsBlocked,
  }) => CalendarImportController._(
    fileGateway: fileGateway,
    parser: parser,
    repository: repository,
    idGenerator: idGenerator,
    mutationsBlocked: mutationsBlocked,
  );

  CalendarImportController._({
    required this._fileGateway,
    required this._parser,
    required this._repository,
    required this._idGenerator,
    required this._mutationsBlocked,
  });

  final CalendarImportFileGateway _fileGateway;
  final IcalendarImportParser _parser;
  final CalendarRepository _repository;
  final CalendarCommandIdGenerator _idGenerator;
  final bool Function() _mutationsBlocked;
  final StreamController<CalendarImportState> _states =
      StreamController<CalendarImportState>.broadcast(sync: true);

  CalendarImportState _state = const CalendarImportInitial();
  List<_CalendarImportCommand>? _commands;
  var _nextCommandIndex = 0;
  var _busy = false;
  var _disposed = false;

  CalendarImportState get state => _state;
  Stream<CalendarImportState> get states => _states.stream;

  Future<void> pickFile({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required HouseholdMemberId currentMemberId,
    required Iterable<HouseholdMemberId> availableParticipantIds,
  }) async {
    if (_busy || _disposed || _mutationsBlocked()) return;
    final Set<HouseholdMemberId> available = availableParticipantIds.toSet();
    if (available.isEmpty || !available.contains(currentMemberId)) {
      _emit(
        const CalendarImportLoadFailed(
          CalendarImportLoadFailureKind.invalidFile,
        ),
      );
      return;
    }
    final CalendarImportState previous = _state;
    _busy = true;
    _emit(const CalendarImportPicking());
    final CalendarImportFilePickResult result = await _fileGateway.pick();
    _busy = false;
    if (_disposed) return;
    if (_mutationsBlocked()) {
      _emit(
        previous is CalendarImportReady ||
                previous is CalendarImportSubmissionFailed
            ? previous
            : const CalendarImportInitial(),
      );
      return;
    }
    switch (result) {
      case CalendarImportFilePickCancelled():
        _emit(
          previous is CalendarImportReady ||
                  previous is CalendarImportSubmissionFailed
              ? previous
              : const CalendarImportInitial(),
        );
      case CalendarImportFilePickerUnavailable():
        _emit(
          const CalendarImportLoadFailed(
            CalendarImportLoadFailureKind.pickerUnavailable,
          ),
        );
      case CalendarImportFileTooLarge():
        _emit(
          const CalendarImportLoadFailed(
            CalendarImportLoadFailureKind.tooLarge,
          ),
        );
      case CalendarImportFilePickFailed():
        _emit(
          const CalendarImportLoadFailed(
            CalendarImportLoadFailureKind.pickerFailed,
          ),
        );
      case CalendarImportFileSelected(:final file):
        if (!_validDisplayName(file.displayName)) {
          _emit(
            const CalendarImportLoadFailed(
              CalendarImportLoadFailureKind.invalidFile,
            ),
          );
          return;
        }
        final CalendarImportParseResult parseResult = _parser.parse(
          content: file.content,
          householdTimeZone: householdTimeZone,
        );
        switch (parseResult) {
          case CalendarImportParseFailed(:final kind):
            _emit(CalendarImportLoadFailed(_mapParseFailure(kind)));
          case CalendarImportParsed(:final document):
            _commands = null;
            _nextCommandIndex = 0;
            _emit(
              CalendarImportReady(
                CalendarImportSelection(
                  householdId: householdId,
                  householdTimeZone: householdTimeZone,
                  displayName: file.displayName,
                  document: document,
                  selectedSourceIndexes: document.candidates.map(
                    (CalendarImportCandidate candidate) =>
                        candidate.sourceIndex,
                  ),
                  availableParticipantIds: available,
                  participantMemberIds: <HouseholdMemberId>{currentMemberId},
                ),
              ),
            );
        }
    }
  }

  void toggleCandidate(int sourceIndex) {
    if (_busy || _state is! CalendarImportReady) return;
    final CalendarImportSelection selection =
        (_state as CalendarImportReady).selection;
    if (!selection.document.candidates.any(
      (CalendarImportCandidate candidate) =>
          candidate.sourceIndex == sourceIndex,
    )) {
      return;
    }
    final Set<int> selected = selection.selectedSourceIndexes.toSet();
    selected.contains(sourceIndex)
        ? selected.remove(sourceIndex)
        : selected.add(sourceIndex);
    _emit(
      CalendarImportReady(selection.copyWith(selectedSourceIndexes: selected)),
    );
  }

  void toggleParticipant(HouseholdMemberId participantId) {
    if (_busy || _state is! CalendarImportReady) return;
    final CalendarImportSelection selection =
        (_state as CalendarImportReady).selection;
    if (!selection.availableParticipantIds.contains(participantId)) return;
    final Set<HouseholdMemberId> selected = selection.participantMemberIds
        .toSet();
    selected.contains(participantId)
        ? selected.remove(participantId)
        : selected.add(participantId);
    _emit(
      CalendarImportReady(selection.copyWith(participantMemberIds: selected)),
    );
  }

  Future<void> importSelected() async {
    if (_busy ||
        _disposed ||
        _mutationsBlocked() ||
        _state is! CalendarImportReady) {
      return;
    }
    final CalendarImportSelection selection =
        (_state as CalendarImportReady).selection;
    if (!selection.canImport) return;
    final List<_CalendarImportCommand>? commands = _buildCommands(selection);
    if (commands == null || commands.isEmpty) {
      _emit(
        const CalendarImportLoadFailed(
          CalendarImportLoadFailureKind.invalidFile,
        ),
      );
      return;
    }
    _commands = commands;
    _nextCommandIndex = 0;
    await _runCommands(selection);
  }

  Future<void> retryImport() async {
    if (_busy ||
        _disposed ||
        _mutationsBlocked() ||
        _state is! CalendarImportSubmissionFailed ||
        _commands == null) {
      return;
    }
    final CalendarImportSelection selection =
        (_state as CalendarImportSubmissionFailed).selection;
    await _runCommands(selection);
  }

  void reset() {
    if (_busy || _disposed) return;
    _commands = null;
    _nextCommandIndex = 0;
    _emit(const CalendarImportInitial());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }

  List<_CalendarImportCommand>? _buildCommands(
    CalendarImportSelection selection,
  ) {
    final List<CalendarImportCandidate> selected = selection.document.candidates
        .where(
          (CalendarImportCandidate candidate) =>
              selection.selectedSourceIndexes.contains(candidate.sourceIndex),
        )
        .toList(growable: false);
    final List<_CalendarImportCommand> commands = <_CalendarImportCommand>[];
    final List<Object> drafts = <Object>[];
    for (final CalendarImportCandidate candidate in selected) {
      if (candidate.recurrenceRule == null) {
        final OneTimeCalendarEventDraft? draft = candidate.createEventDraft(
          householdId: selection.householdId,
          participantMemberIds: selection.participantMemberIds,
        );
        if (draft == null) return null;
        drafts.add(draft);
      } else {
        final RecurringCalendarEventDraft? draft = candidate
            .createRecurringDraft(
              householdId: selection.householdId,
              participantMemberIds: selection.participantMemberIds,
            );
        if (draft == null) return null;
        drafts.add(draft);
      }
    }
    for (final Object draft in drafts) {
      final CalendarEventCommandId commandId = _idGenerator.generate();
      commands.add(switch (draft) {
        OneTimeCalendarEventDraft() => _CalendarImportOneTimeCommand(
          draft.createRequest(commandId),
        ),
        RecurringCalendarEventDraft() => _CalendarImportRecurringCommand(
          draft.createRequest(commandId),
        ),
        _ => throw StateError('Unexpected Calendar import draft.'),
      });
    }
    return commands;
  }

  Future<void> _runCommands(CalendarImportSelection selection) async {
    final List<_CalendarImportCommand> commands = _commands!;
    _busy = true;
    while (_nextCommandIndex < commands.length) {
      if (_mutationsBlocked()) {
        _busy = false;
        _emit(
          CalendarImportSubmissionFailed(
            selection: selection,
            completedCount: _nextCommandIndex,
            totalCount: commands.length,
            failure: const CalendarFailure(
              CalendarFailureKind.temporarilyUnavailable,
            ),
          ),
        );
        return;
      }
      _emit(
        CalendarImportSubmitting(
          selection: selection,
          completedCount: _nextCommandIndex,
          totalCount: commands.length,
        ),
      );
      final CalendarFailure? failure = await commands[_nextCommandIndex].run(
        _repository,
      );
      if (_disposed) {
        _busy = false;
        return;
      }
      if (failure != null) {
        _busy = false;
        _emit(
          CalendarImportSubmissionFailed(
            selection: selection,
            completedCount: _nextCommandIndex,
            totalCount: commands.length,
            failure: failure,
          ),
        );
        return;
      }
      _nextCommandIndex += 1;
    }
    _busy = false;
    final int importedCount = commands.length;
    _commands = null;
    _nextCommandIndex = 0;
    _emit(CalendarImportCompleted(importedCount));
  }

  void _emit(CalendarImportState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }
}

bool _validDisplayName(String value) {
  return value.trim() == value &&
      value.isNotEmpty &&
      value.length <= 120 &&
      value.toLowerCase().endsWith('.ics') &&
      !value.codeUnits.any((int unit) => unit < 32 || unit == 127);
}

CalendarImportLoadFailureKind _mapParseFailure(
  CalendarImportParseFailureKind kind,
) {
  return switch (kind) {
    CalendarImportParseFailureKind.tooLarge =>
      CalendarImportLoadFailureKind.tooLarge,
    CalendarImportParseFailureKind.tooManyEvents =>
      CalendarImportLoadFailureKind.tooManyEvents,
    CalendarImportParseFailureKind.invalidStructure =>
      CalendarImportLoadFailureKind.invalidFile,
    CalendarImportParseFailureKind.unsupportedVersion =>
      CalendarImportLoadFailureKind.unsupportedVersion,
  };
}

sealed class _CalendarImportCommand {
  const _CalendarImportCommand();

  Future<CalendarFailure?> run(CalendarRepository repository);
}

final class _CalendarImportOneTimeCommand extends _CalendarImportCommand {
  const _CalendarImportOneTimeCommand(this.request);

  final CreateOneTimeCalendarEventRequest request;

  @override
  Future<CalendarFailure?> run(CalendarRepository repository) async {
    return switch (await repository.createOneTimeEvent(request)) {
      OneTimeCalendarEventCreated() => null,
      CreateOneTimeCalendarEventFailed(:final failure) => failure,
    };
  }
}

final class _CalendarImportRecurringCommand extends _CalendarImportCommand {
  const _CalendarImportRecurringCommand(this.request);

  final CreateRecurringCalendarEventRequest request;

  @override
  Future<CalendarFailure?> run(CalendarRepository repository) async {
    return switch (await repository.createRecurringEvent(request)) {
      RecurringCalendarEventCreated() => null,
      CreateRecurringCalendarEventFailed(:final failure) => failure,
    };
  }
}
