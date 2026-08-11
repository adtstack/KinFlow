import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class HouseholdSelection {
  const HouseholdSelection({
    required this.householdId,
    required this.memberId,
    required this.householdName,
    required this.memberRole,
    required this.membershipVersion,
    required this.isActive,
  });

  final HouseholdId householdId;
  final HouseholdMemberId memberId;
  final String householdName;
  final HouseholdMemberRole memberRole;
  final int membershipVersion;
  final bool isActive;

  HouseholdSelection withActive(bool value) {
    return HouseholdSelection(
      householdId: householdId,
      memberId: memberId,
      householdName: householdName,
      memberRole: memberRole,
      membershipVersion: membershipVersion,
      isActive: value,
    );
  }
}

final class HouseholdSelectionSnapshot {
  HouseholdSelectionSnapshot({
    required List<HouseholdSelection> households,
    required this.selectionVersion,
  }) : households = List<HouseholdSelection>.unmodifiable(households);

  final List<HouseholdSelection> households;
  final int selectionVersion;

  HouseholdSelection? get activeHousehold {
    for (final HouseholdSelection household in households) {
      if (household.isActive) {
        return household;
      }
    }
    return null;
  }

  HouseholdSelectionSnapshot activate(
    HouseholdId householdId, {
    required int version,
  }) {
    return HouseholdSelectionSnapshot(
      households: households
          .map(
            (HouseholdSelection household) =>
                household.withActive(household.householdId == householdId),
          )
          .toList(growable: false),
      selectionVersion: version,
    );
  }
}

final class HouseholdSelectionCommit {
  const HouseholdSelectionCommit({
    required this.activeHousehold,
    required this.selectionVersion,
    required this.changed,
  });

  final ActiveHousehold activeHousehold;
  final int selectionVersion;
  final bool changed;
}
