import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

abstract interface class HouseholdRepository {
  Future<LoadActiveHouseholdResult> loadActiveHousehold();

  Future<CreateFirstHouseholdResult> createFirstHousehold(
    CreateFirstHouseholdRequest request,
  );
}

sealed class LoadActiveHouseholdResult {
  const LoadActiveHouseholdResult();
}

final class ActiveHouseholdLoaded extends LoadActiveHouseholdResult {
  const ActiveHouseholdLoaded(this.household, {this.cacheMetadata});

  final ActiveHousehold household;
  final ReadCacheMetadata? cacheMetadata;
}

final class NoActiveHousehold extends LoadActiveHouseholdResult {
  const NoActiveHousehold();
}

final class LoadActiveHouseholdFailed extends LoadActiveHouseholdResult {
  const LoadActiveHouseholdFailed(this.failure);

  final HouseholdFailure failure;
}

sealed class CreateFirstHouseholdResult {
  const CreateFirstHouseholdResult();
}

final class FirstHouseholdCreated extends CreateFirstHouseholdResult {
  const FirstHouseholdCreated(this.household);

  final ActiveHousehold household;
}

final class CreateFirstHouseholdFailed extends CreateFirstHouseholdResult {
  const CreateFirstHouseholdFailed(this.failure);

  final HouseholdFailure failure;
}
