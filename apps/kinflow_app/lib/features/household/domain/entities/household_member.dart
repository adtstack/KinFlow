import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

enum HouseholdMemberRole { owner, admin, member }

final class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.version,
    required this.isCurrentUser,
  });

  final HouseholdMemberId id;
  final String displayName;
  final HouseholdMemberRole role;
  final int version;
  final bool isCurrentUser;
}

final class HouseholdMemberRoster {
  HouseholdMemberRoster({
    required this.householdId,
    required this.householdName,
    required this.householdVersion,
    required List<HouseholdMember> members,
  }) : members = List<HouseholdMember>.unmodifiable(members);

  final HouseholdId householdId;
  final String householdName;
  final int householdVersion;
  final List<HouseholdMember> members;

  HouseholdMember get currentMember =>
      members.singleWhere((HouseholdMember member) => member.isCurrentUser);
}
