import 'package:kinflow_app/features/calendar/domain/entities/calendar_import.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum CalendarImportLoadFailureKind {
  pickerUnavailable,
  pickerFailed,
  invalidFile,
  unsupportedVersion,
  tooLarge,
  tooManyEvents,
}

final class CalendarImportSelection {
  CalendarImportSelection({
    required this.householdId,
    required this.householdTimeZone,
    required this.displayName,
    required this.document,
    required Iterable<int> selectedSourceIndexes,
    required Iterable<HouseholdMemberId> availableParticipantIds,
    required Iterable<HouseholdMemberId> participantMemberIds,
  }) : selectedSourceIndexes = Set<int>.unmodifiable(selectedSourceIndexes),
       availableParticipantIds = Set<HouseholdMemberId>.unmodifiable(
         availableParticipantIds,
       ),
       participantMemberIds = Set<HouseholdMemberId>.unmodifiable(
         participantMemberIds,
       );

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final String displayName;
  final CalendarImportDocument document;
  final Set<int> selectedSourceIndexes;
  final Set<HouseholdMemberId> availableParticipantIds;
  final Set<HouseholdMemberId> participantMemberIds;

  bool get canImport =>
      selectedSourceIndexes.isNotEmpty && participantMemberIds.isNotEmpty;

  CalendarImportSelection copyWith({
    Iterable<int>? selectedSourceIndexes,
    Iterable<HouseholdMemberId>? participantMemberIds,
  }) {
    return CalendarImportSelection(
      householdId: householdId,
      householdTimeZone: householdTimeZone,
      displayName: displayName,
      document: document,
      selectedSourceIndexes:
          selectedSourceIndexes ?? this.selectedSourceIndexes,
      availableParticipantIds: availableParticipantIds,
      participantMemberIds: participantMemberIds ?? this.participantMemberIds,
    );
  }
}

sealed class CalendarImportState {
  const CalendarImportState();
}

final class CalendarImportInitial extends CalendarImportState {
  const CalendarImportInitial();
}

final class CalendarImportPicking extends CalendarImportState {
  const CalendarImportPicking();
}

final class CalendarImportLoadFailed extends CalendarImportState {
  const CalendarImportLoadFailed(this.kind);

  final CalendarImportLoadFailureKind kind;
}

final class CalendarImportReady extends CalendarImportState {
  const CalendarImportReady(this.selection);

  final CalendarImportSelection selection;
}

final class CalendarImportSubmitting extends CalendarImportState {
  const CalendarImportSubmitting({
    required this.selection,
    required this.completedCount,
    required this.totalCount,
  });

  final CalendarImportSelection selection;
  final int completedCount;
  final int totalCount;
}

final class CalendarImportSubmissionFailed extends CalendarImportState {
  const CalendarImportSubmissionFailed({
    required this.selection,
    required this.completedCount,
    required this.totalCount,
    required this.failure,
  });

  final CalendarImportSelection selection;
  final int completedCount;
  final int totalCount;
  final CalendarFailure failure;
}

final class CalendarImportCompleted extends CalendarImportState {
  const CalendarImportCompleted(this.importedCount);

  final int importedCount;
}
