import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChangeHouseholdMemberRoleCommand {
  const ChangeHouseholdMemberRoleCommand({
    required this.idempotencyKey,
    required this.householdId,
    required this.memberId,
    required this.role,
    required this.expectedVersion,
    required this.recentAuthenticationProof,
  });

  final HouseholdCommandId idempotencyKey;
  final HouseholdId householdId;
  final HouseholdMemberId memberId;
  final HouseholdMemberRole role;
  final int expectedVersion;
  final RecentAuthenticationProof recentAuthenticationProof;
}

final class RemoveHouseholdMemberCommand {
  const RemoveHouseholdMemberCommand({
    required this.idempotencyKey,
    required this.householdId,
    required this.memberId,
    required this.expectedVersion,
  });

  final HouseholdCommandId idempotencyKey;
  final HouseholdId householdId;
  final HouseholdMemberId memberId;
  final int expectedVersion;
}

final class LeaveHouseholdCommand {
  const LeaveHouseholdCommand({
    required this.idempotencyKey,
    required this.householdId,
    required this.memberId,
    required this.expectedVersion,
  });

  final HouseholdCommandId idempotencyKey;
  final HouseholdId householdId;
  final HouseholdMemberId memberId;
  final int expectedVersion;
}

final class TransferHouseholdOwnerCommand {
  const TransferHouseholdOwnerCommand({
    required this.idempotencyKey,
    required this.householdId,
    required this.newOwnerMemberId,
    required this.expectedVersion,
    required this.recentAuthenticationProof,
  });

  final HouseholdCommandId idempotencyKey;
  final HouseholdId householdId;
  final HouseholdMemberId newOwnerMemberId;
  final int expectedVersion;
  final RecentAuthenticationProof recentAuthenticationProof;
}
