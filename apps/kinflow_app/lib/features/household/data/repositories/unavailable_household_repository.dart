import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';

final class UnavailableHouseholdRepository implements HouseholdRepository {
  const UnavailableHouseholdRepository();

  static const HouseholdFailure _failure = HouseholdFailure(
    HouseholdFailureKind.temporarilyUnavailable,
  );

  @override
  Future<CreateFirstHouseholdResult> createFirstHousehold(
    CreateFirstHouseholdRequest request,
  ) async {
    return const CreateFirstHouseholdFailed(_failure);
  }

  @override
  Future<LoadActiveHouseholdResult> loadActiveHousehold() async {
    return const LoadActiveHouseholdFailed(_failure);
  }
}
