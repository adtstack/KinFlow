import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class CreateHouseholdInviteRequest {
  const CreateHouseholdInviteRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.role,
    required this.expiresInHours,
    this.targetEmail,
  });

  final InviteCommandId idempotencyKey;
  final HouseholdId householdId;
  final HouseholdInviteRole role;
  final int expiresInHours;
  final String? targetEmail;
}

final class AcceptHouseholdInviteRequest {
  const AcceptHouseholdInviteRequest({
    required this.idempotencyKey,
    required this.token,
    required this.setActiveHousehold,
  });

  final InviteCommandId idempotencyKey;
  final InviteToken token;
  final bool setActiveHousehold;
}

final class RevokeHouseholdInviteRequest {
  const RevokeHouseholdInviteRequest({
    required this.idempotencyKey,
    required this.householdId,
    required this.inviteId,
  });

  final InviteCommandId idempotencyKey;
  final HouseholdId householdId;
  final InviteId inviteId;
}
