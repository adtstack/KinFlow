import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class HouseholdSelectionRepository {
  Future<LoadHouseholdSelectionsResult> load();

  Future<SwitchActiveHouseholdResult> switchActiveHousehold({
    required HouseholdId targetHouseholdId,
    required int expectedSelectionVersion,
  });
}

sealed class LoadHouseholdSelectionsResult {
  const LoadHouseholdSelectionsResult();
}

final class HouseholdSelectionsLoaded extends LoadHouseholdSelectionsResult {
  const HouseholdSelectionsLoaded(this.snapshot);

  final HouseholdSelectionSnapshot snapshot;
}

final class LoadHouseholdSelectionsFailed
    extends LoadHouseholdSelectionsResult {
  const LoadHouseholdSelectionsFailed(this.failure);

  final HouseholdSelectionFailure failure;
}

sealed class SwitchActiveHouseholdResult {
  const SwitchActiveHouseholdResult();
}

final class ActiveHouseholdSwitched extends SwitchActiveHouseholdResult {
  const ActiveHouseholdSwitched(this.commit);

  final HouseholdSelectionCommit commit;
}

final class SwitchActiveHouseholdFailed extends SwitchActiveHouseholdResult {
  const SwitchActiveHouseholdFailed(this.failure);

  final HouseholdSelectionFailure failure;
}
