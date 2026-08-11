import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';

sealed class HouseholdSelectionState {
  const HouseholdSelectionState();
}

final class HouseholdSelectionInitial extends HouseholdSelectionState {
  const HouseholdSelectionInitial();
}

final class HouseholdSelectionLoading extends HouseholdSelectionState {
  const HouseholdSelectionLoading();
}

final class HouseholdSelectionLoadFailed extends HouseholdSelectionState {
  const HouseholdSelectionLoadFailed(this.failure);

  final HouseholdSelectionFailure failure;
}

final class HouseholdSelectionReady extends HouseholdSelectionState {
  const HouseholdSelectionReady(
    this.snapshot, {
    this.isSwitching = false,
    this.failure,
    this.successfulSwitchCount = 0,
  });

  final HouseholdSelectionSnapshot snapshot;
  final bool isSwitching;
  final HouseholdSelectionFailure? failure;
  final int successfulSwitchCount;
}
