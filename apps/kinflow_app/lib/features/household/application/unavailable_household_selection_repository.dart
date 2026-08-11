import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class UnavailableHouseholdSelectionRepository
    implements HouseholdSelectionRepository {
  const UnavailableHouseholdSelectionRepository();

  @override
  Future<LoadHouseholdSelectionsResult> load() async {
    return const LoadHouseholdSelectionsFailed(
      HouseholdSelectionFailure(
        HouseholdSelectionFailureKind.temporarilyUnavailable,
      ),
    );
  }

  @override
  Future<SwitchActiveHouseholdResult> switchActiveHousehold({
    required HouseholdId targetHouseholdId,
    required int expectedSelectionVersion,
  }) async {
    return const SwitchActiveHouseholdFailed(
      HouseholdSelectionFailure(
        HouseholdSelectionFailureKind.temporarilyUnavailable,
      ),
    );
  }
}
