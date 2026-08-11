import 'package:kinflow_app/features/household/domain/entities/active_household.dart';

abstract interface class ActiveHouseholdDepartureCommitter {
  Future<bool> commitHouseholdDeparture(ActiveHousehold? nextHousehold);
}
