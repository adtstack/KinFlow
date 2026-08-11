import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

enum HouseholdInviteRole { admin, member }

enum HouseholdInviteStatus { active, accepted, revoked, expired }

final class HouseholdInvite {
  const HouseholdInvite({
    required this.id,
    required this.householdId,
    required this.role,
    required this.expiresAt,
    required this.status,
    this.rawToken,
    this.rawShortCode,
    this.shortCodeExpiresAt,
  });

  final InviteId id;
  final HouseholdId householdId;
  final HouseholdInviteRole role;
  final DateTime expiresAt;
  final HouseholdInviteStatus status;
  final InviteToken? rawToken;
  final InviteShortCode? rawShortCode;
  final DateTime? shortCodeExpiresAt;

  @override
  String toString() {
    return 'HouseholdInvite(id: ${id.value}, householdId: ${householdId.value}, '
        'role: ${role.name}, status: ${status.name}, rawToken: redacted, '
        'rawShortCode: redacted)';
  }
}

final class HouseholdInvitePreview {
  const HouseholdInvitePreview({
    required this.householdDisplayName,
    required this.inviterDisplayName,
    required this.role,
    required this.expiresAt,
  });

  final String householdDisplayName;
  final String inviterDisplayName;
  final HouseholdInviteRole role;
  final DateTime expiresAt;
}

final class AcceptedHouseholdInvite {
  const AcceptedHouseholdInvite({
    required this.household,
    required this.displayName,
    required this.role,
    required this.activeHouseholdSet,
  });

  final ActiveHousehold household;
  final String displayName;
  final HouseholdInviteRole role;
  final bool activeHouseholdSet;
}
