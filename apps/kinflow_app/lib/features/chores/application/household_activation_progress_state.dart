import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

sealed class HouseholdActivationProgressState {
  const HouseholdActivationProgressState();
}

final class HouseholdActivationProgressInitial
    extends HouseholdActivationProgressState {
  const HouseholdActivationProgressInitial();
}

final class HouseholdActivationProgressLoading
    extends HouseholdActivationProgressState {
  const HouseholdActivationProgressLoading(this.householdId);

  final HouseholdId householdId;
}

final class HouseholdActivationProgressReady
    extends HouseholdActivationProgressState {
  const HouseholdActivationProgressReady({
    required this.progress,
    this.refreshing = false,
  });

  final HouseholdActivationProgress progress;
  final bool refreshing;
}

final class HouseholdActivationProgressFailed
    extends HouseholdActivationProgressState {
  const HouseholdActivationProgressFailed({
    required this.householdId,
    required this.failure,
  });

  final HouseholdId householdId;
  final ChoreFailure failure;
}
