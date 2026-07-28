import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';

sealed class FirstHouseholdOnboardingState {
  const FirstHouseholdOnboardingState();
}

final class FirstHouseholdOnboardingIdle extends FirstHouseholdOnboardingState {
  const FirstHouseholdOnboardingIdle();
}

final class FirstHouseholdOnboardingSubmitting
    extends FirstHouseholdOnboardingState {
  const FirstHouseholdOnboardingSubmitting();
}

final class FirstHouseholdOnboardingSucceeded
    extends FirstHouseholdOnboardingState {
  const FirstHouseholdOnboardingSucceeded(this.household);

  final ActiveHousehold household;
}

final class FirstHouseholdOnboardingFailed
    extends FirstHouseholdOnboardingState {
  const FirstHouseholdOnboardingFailed(this.failure);

  final HouseholdFailure failure;
}
