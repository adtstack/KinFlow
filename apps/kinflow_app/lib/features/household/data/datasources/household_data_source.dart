enum HouseholdDataFailureKind {
  unauthenticated,
  invalidInput,
  activeHouseholdExists,
  idempotencyConflict,
  profileUnavailable,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class ActiveHouseholdRecord {
  const ActiveHouseholdRecord({
    required this.householdId,
    required this.memberId,
  });

  final String householdId;
  final String memberId;
}

abstract interface class HouseholdDataSource {
  Future<LoadActiveHouseholdDataResult> loadActiveHousehold();

  Future<CreateFirstHouseholdDataResult> createFirstHousehold({
    required String idempotencyKey,
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  });
}

sealed class LoadActiveHouseholdDataResult {
  const LoadActiveHouseholdDataResult();
}

final class ActiveHouseholdDataFound extends LoadActiveHouseholdDataResult {
  const ActiveHouseholdDataFound(this.record);

  final ActiveHouseholdRecord record;
}

final class ActiveHouseholdDataAbsent extends LoadActiveHouseholdDataResult {
  const ActiveHouseholdDataAbsent();
}

final class LoadActiveHouseholdDataFailed
    extends LoadActiveHouseholdDataResult {
  const LoadActiveHouseholdDataFailed(this.kind);

  final HouseholdDataFailureKind kind;
}

sealed class CreateFirstHouseholdDataResult {
  const CreateFirstHouseholdDataResult();
}

final class FirstHouseholdDataCreated extends CreateFirstHouseholdDataResult {
  const FirstHouseholdDataCreated(this.record);

  final ActiveHouseholdRecord record;
}

final class CreateFirstHouseholdDataFailed
    extends CreateFirstHouseholdDataResult {
  const CreateFirstHouseholdDataFailed(this.kind);

  final HouseholdDataFailureKind kind;
}
