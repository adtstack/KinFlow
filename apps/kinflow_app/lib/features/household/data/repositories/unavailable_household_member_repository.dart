import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableHouseholdMemberRepository
    implements HouseholdMemberRepository {
  const UnavailableHouseholdMemberRepository();

  static const HouseholdMemberFailure _failure = HouseholdMemberFailure(
    HouseholdMemberFailureKind.temporarilyUnavailable,
  );

  @override
  Future<LoadHouseholdMemberRosterResult> loadRoster(
    HouseholdId householdId,
  ) async {
    return const LoadHouseholdMemberRosterFailed(_failure);
  }

  @override
  Future<HouseholdMemberCommandResult> changeRole(
    ChangeHouseholdMemberRoleCommand command,
  ) async {
    return const HouseholdMemberCommandFailed(_failure);
  }

  @override
  Future<HouseholdMemberCommandResult> removeMember(
    RemoveHouseholdMemberCommand command,
  ) async {
    return const HouseholdMemberCommandFailed(_failure);
  }

  @override
  Future<HouseholdMemberCommandResult> leaveHousehold(
    LeaveHouseholdCommand command,
  ) async {
    return const HouseholdMemberCommandFailed(_failure);
  }

  @override
  Future<HouseholdMemberCommandResult> transferOwner(
    TransferHouseholdOwnerCommand command,
  ) async {
    return const HouseholdMemberCommandFailed(_failure);
  }
}
