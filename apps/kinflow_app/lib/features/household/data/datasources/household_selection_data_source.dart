enum HouseholdSelectionDataFailureKind {
  unauthenticated,
  invalidInput,
  targetUnavailable,
  versionConflict,
  featureDisabled,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class HouseholdSelectionDataRecord {
  const HouseholdSelectionDataRecord({
    required this.householdId,
    required this.memberId,
    required this.householdName,
    required this.memberRole,
    required this.membershipVersion,
    required this.isActive,
    required this.selectionVersion,
  });

  final String householdId;
  final String memberId;
  final String householdName;
  final String memberRole;
  final int membershipVersion;
  final bool isActive;
  final int selectionVersion;
}

final class ActiveHouseholdSwitchDataRecord {
  const ActiveHouseholdSwitchDataRecord({
    required this.householdId,
    required this.memberId,
    required this.selectionVersion,
    required this.changed,
  });

  final String householdId;
  final String memberId;
  final int selectionVersion;
  final bool changed;
}

abstract interface class HouseholdSelectionDataSource {
  Future<HouseholdSelectionDataResult<List<HouseholdSelectionDataRecord>>>
  load();

  Future<HouseholdSelectionDataResult<ActiveHouseholdSwitchDataRecord>>
  switchActiveHousehold({
    required String targetHouseholdId,
    required int expectedSelectionVersion,
  });
}

sealed class HouseholdSelectionDataResult<T> {
  const HouseholdSelectionDataResult();
}

final class HouseholdSelectionDataSucceeded<T>
    extends HouseholdSelectionDataResult<T> {
  const HouseholdSelectionDataSucceeded(this.value);

  final T value;
}

final class HouseholdSelectionDataFailed<T>
    extends HouseholdSelectionDataResult<T> {
  const HouseholdSelectionDataFailed(this.kind);

  final HouseholdSelectionDataFailureKind kind;
}
