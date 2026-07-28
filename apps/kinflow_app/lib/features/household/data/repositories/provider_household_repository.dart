import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/first_household_request.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderHouseholdRepository implements HouseholdRepository {
  const ProviderHouseholdRepository(this._dataSource);

  final HouseholdDataSource _dataSource;

  @override
  Future<LoadActiveHouseholdResult> loadActiveHousehold() async {
    final LoadActiveHouseholdDataResult result = await _dataSource
        .loadActiveHousehold();
    return switch (result) {
      ActiveHouseholdDataFound(:final record) => _mapLoaded(record),
      ActiveHouseholdDataAbsent() => const NoActiveHousehold(),
      LoadActiveHouseholdDataFailed(:final kind) => LoadActiveHouseholdFailed(
        _mapFailure(kind),
      ),
    };
  }

  @override
  Future<CreateFirstHouseholdResult> createFirstHousehold(
    CreateFirstHouseholdRequest request,
  ) async {
    final CreateFirstHouseholdDataResult result = await _dataSource
        .createFirstHousehold(
          idempotencyKey: request.idempotencyKey.value,
          householdName: request.householdName,
          ownerDisplayName: request.ownerDisplayName,
          locale: request.locale,
          timezone: request.timezone,
        );
    return switch (result) {
      FirstHouseholdDataCreated(:final record) => _mapCreated(record),
      CreateFirstHouseholdDataFailed(:final kind) => CreateFirstHouseholdFailed(
        _mapFailure(kind),
      ),
    };
  }

  LoadActiveHouseholdResult _mapLoaded(ActiveHouseholdRecord record) {
    final ActiveHousehold? household = _mapRecord(record);
    return household == null
        ? const LoadActiveHouseholdFailed(
            HouseholdFailure(HouseholdFailureKind.invalidPayload),
          )
        : ActiveHouseholdLoaded(household);
  }

  CreateFirstHouseholdResult _mapCreated(ActiveHouseholdRecord record) {
    final ActiveHousehold? household = _mapRecord(record);
    return household == null
        ? const CreateFirstHouseholdFailed(
            HouseholdFailure(HouseholdFailureKind.invalidPayload),
          )
        : FirstHouseholdCreated(household);
  }

  ActiveHousehold? _mapRecord(ActiveHouseholdRecord record) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
      record.memberId,
    );
    if (householdId == null || memberId == null) {
      return null;
    }
    return ActiveHousehold(householdId: householdId, memberId: memberId);
  }

  HouseholdFailure _mapFailure(HouseholdDataFailureKind kind) {
    return HouseholdFailure(switch (kind) {
      HouseholdDataFailureKind.unauthenticated =>
        HouseholdFailureKind.unauthenticated,
      HouseholdDataFailureKind.invalidInput =>
        HouseholdFailureKind.invalidInput,
      HouseholdDataFailureKind.activeHouseholdExists =>
        HouseholdFailureKind.activeHouseholdExists,
      HouseholdDataFailureKind.idempotencyConflict =>
        HouseholdFailureKind.idempotencyConflict,
      HouseholdDataFailureKind.profileUnavailable =>
        HouseholdFailureKind.profileUnavailable,
      HouseholdDataFailureKind.temporarilyUnavailable =>
        HouseholdFailureKind.temporarilyUnavailable,
      HouseholdDataFailureKind.invalidPayload =>
        HouseholdFailureKind.invalidPayload,
      HouseholdDataFailureKind.unknown => HouseholdFailureKind.internal,
    });
  }
}
