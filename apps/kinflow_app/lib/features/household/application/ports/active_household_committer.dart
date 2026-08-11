import 'package:kinflow_app/features/household/domain/entities/active_household.dart';

abstract interface class ActiveHouseholdCommitter {
  Future<bool> commitActiveHousehold(ActiveHousehold household);
}
