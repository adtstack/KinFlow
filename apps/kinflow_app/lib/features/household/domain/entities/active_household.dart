import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ActiveHousehold {
  const ActiveHousehold({required this.householdId, required this.memberId});

  final HouseholdId householdId;
  final HouseholdMemberId memberId;

  @override
  bool operator ==(Object other) {
    return other is ActiveHousehold &&
        other.householdId == householdId &&
        other.memberId == memberId;
  }

  @override
  int get hashCode => Object.hash(householdId, memberId);
}
