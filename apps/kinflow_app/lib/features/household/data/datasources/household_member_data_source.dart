import 'package:kinflow_app/features/household/data/dto/household_member_dto.dart';

enum HouseholdMemberDataFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  notFound,
  roleNotAllowed,
  ownerTransferRequired,
  recentAuthenticationRequired,
  versionConflict,
  idempotencyConflict,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

abstract interface class HouseholdMemberDataSource {
  Future<HouseholdMemberDataResult<List<HouseholdMemberRosterRowDto>>>
  loadRoster({required String householdId});

  Future<HouseholdMemberDataResult<HouseholdMemberRoleMutationDto>> changeRole({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String memberId,
    required String role,
    required int expectedVersion,
  });

  Future<HouseholdMemberDataResult<HouseholdMemberRemovalDto>> removeMember({
    required String idempotencyKey,
    required String householdId,
    required String memberId,
    required int expectedVersion,
  });

  Future<HouseholdMemberDataResult<LeaveHouseholdDto>> leaveHousehold({
    required String idempotencyKey,
    required String householdId,
    required int expectedVersion,
  });

  Future<HouseholdMemberDataResult<HouseholdOwnerTransferDto>> transferOwner({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String newOwnerMemberId,
    required int expectedVersion,
  });
}

sealed class HouseholdMemberDataResult<T> {
  const HouseholdMemberDataResult();
}

final class HouseholdMemberDataSucceeded<T>
    extends HouseholdMemberDataResult<T> {
  const HouseholdMemberDataSucceeded(this.value);

  final T value;
}

final class HouseholdMemberDataFailed<T> extends HouseholdMemberDataResult<T> {
  const HouseholdMemberDataFailed(this.kind);

  final HouseholdMemberDataFailureKind kind;
}
