import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class HouseholdMemberRepository {
  Future<LoadHouseholdMemberRosterResult> loadRoster(HouseholdId householdId);

  Future<HouseholdMemberCommandResult> changeRole(
    ChangeHouseholdMemberRoleCommand command,
  );

  Future<HouseholdMemberCommandResult> removeMember(
    RemoveHouseholdMemberCommand command,
  );

  Future<HouseholdMemberCommandResult> leaveHousehold(
    LeaveHouseholdCommand command,
  );

  Future<HouseholdMemberCommandResult> transferOwner(
    TransferHouseholdOwnerCommand command,
  );
}

sealed class LoadHouseholdMemberRosterResult {
  const LoadHouseholdMemberRosterResult();
}

final class HouseholdMemberRosterLoaded
    extends LoadHouseholdMemberRosterResult {
  const HouseholdMemberRosterLoaded(this.roster);

  final HouseholdMemberRoster roster;
}

final class LoadHouseholdMemberRosterFailed
    extends LoadHouseholdMemberRosterResult {
  const LoadHouseholdMemberRosterFailed(this.failure);

  final HouseholdMemberFailure failure;
}

sealed class HouseholdMemberCommandResult {
  const HouseholdMemberCommandResult();
}

final class HouseholdMemberCommandCompleted
    extends HouseholdMemberCommandResult {
  const HouseholdMemberCommandCompleted();
}

final class HouseholdLeaveCompleted extends HouseholdMemberCommandResult {
  const HouseholdLeaveCompleted(this.activeHousehold);

  final ActiveHousehold? activeHousehold;
}

final class HouseholdMemberCommandFailed extends HouseholdMemberCommandResult {
  const HouseholdMemberCommandFailed(this.failure);

  final HouseholdMemberFailure failure;
}
