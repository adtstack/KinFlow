import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';

abstract interface class ActiveHouseholdTransitionLocalState {
  Future<bool> replaceAfterSwitch(ActiveHousehold household);

  Future<bool> clearAfterDeparture();
}

final class CompositeActiveHouseholdTransitionLocalState
    implements ActiveHouseholdTransitionLocalState {
  factory CompositeActiveHouseholdTransitionLocalState({
    required ActiveHouseholdSnapshotWriter snapshotWriter,
    required Iterable<SensitiveLocalStatePurgeParticipant> participants,
  }) {
    return CompositeActiveHouseholdTransitionLocalState._(
      snapshotWriter,
      List<SensitiveLocalStatePurgeParticipant>.unmodifiable(participants),
    );
  }

  CompositeActiveHouseholdTransitionLocalState._(
    this._snapshotWriter,
    this._participants,
  );

  final ActiveHouseholdSnapshotWriter _snapshotWriter;
  final List<SensitiveLocalStatePurgeParticipant> _participants;

  @override
  Future<bool> replaceAfterSwitch(ActiveHousehold household) async {
    if (!await _purgeParticipants()) {
      return false;
    }
    try {
      return await _snapshotWriter.replace(household);
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> clearAfterDeparture() async {
    if (!await _purgeParticipants()) {
      return false;
    }
    try {
      return await _snapshotWriter.clear();
    } on Object {
      return false;
    }
  }

  Future<bool> _purgeParticipants() async {
    for (final SensitiveLocalStatePurgeParticipant participant
        in _participants) {
      try {
        await participant.purgeSensitiveLocalState();
      } on Object {
        return false;
      }
    }
    return true;
  }
}

final class UnavailableActiveHouseholdTransitionLocalState
    implements ActiveHouseholdTransitionLocalState {
  const UnavailableActiveHouseholdTransitionLocalState();

  @override
  Future<bool> replaceAfterSwitch(ActiveHousehold household) async => true;

  @override
  Future<bool> clearAfterDeparture() async => true;
}
