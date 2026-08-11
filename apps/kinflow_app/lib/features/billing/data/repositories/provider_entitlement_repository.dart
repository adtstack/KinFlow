import 'package:kinflow_app/features/billing/data/datasources/entitlement_data_source.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/entitlement_failure.dart';
import 'package:kinflow_app/features/billing/domain/repositories/entitlement_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final RegExp _utcOffsetPattern = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$');

final class ProviderEntitlementRepository implements EntitlementRepository {
  const ProviderEntitlementRepository(this._dataSource);

  final EntitlementDataSource _dataSource;

  @override
  Future<EntitlementResult<HouseholdEntitlement>> load(
    HouseholdId householdId,
  ) async {
    final EntitlementDataResult<HouseholdEntitlementDataRecord> result =
        await _dataSource.load(householdId: householdId.value);
    return switch (result) {
      EntitlementDataSucceeded<HouseholdEntitlementDataRecord>(:final value) =>
        _map(value, householdId),
      EntitlementDataFailed<HouseholdEntitlementDataRecord>(:final kind) =>
        EntitlementFailed<HouseholdEntitlement>(_mapFailure(kind)),
    };
  }

  EntitlementResult<HouseholdEntitlement> _map(
    HouseholdEntitlementDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final EntitlementPlan? plan = EntitlementPlan.tryParse(record.planCode);
    final HouseholdEntitlementStatus? status =
        HouseholdEntitlementStatus.tryParse(record.status);
    final EntitlementSource? source = EntitlementSource.tryParse(record.source);
    final DateTime? currentPeriodEnd = record.currentPeriodEnd == null
        ? null
        : _utcInstant(record.currentPeriodEnd!);
    final DateTime? verifiedAt = _utcInstant(record.verifiedAt);
    if (householdId != expectedHouseholdId ||
        plan == null ||
        status == null ||
        source == null ||
        record.currentPeriodEnd != null && currentPeriodEnd == null ||
        verifiedAt == null) {
      return const EntitlementFailed<HouseholdEntitlement>(
        EntitlementFailure(EntitlementFailureKind.invalidPayload),
      );
    }
    final HouseholdEntitlement? entitlement = HouseholdEntitlement.tryCreate(
      householdId: householdId!,
      entitlementKey: record.entitlementKey,
      plan: plan,
      status: status,
      source: source,
      currentPeriodEnd: currentPeriodEnd,
      willRenew: record.willRenew,
      featureLimits: record.featureLimits,
      limitsFinalized: record.limitsFinalized,
      verifiedAt: verifiedAt,
      version: record.version,
      isBillingOwner: record.isBillingOwner,
    );
    return entitlement == null
        ? const EntitlementFailed<HouseholdEntitlement>(
            EntitlementFailure(EntitlementFailureKind.invalidPayload),
          )
        : EntitlementSucceeded<HouseholdEntitlement>(entitlement);
  }
}

DateTime? _utcInstant(String value) {
  if (!_utcOffsetPattern.hasMatch(value)) return null;
  return DateTime.tryParse(value)?.toUtc();
}

EntitlementFailure _mapFailure(EntitlementDataFailureKind kind) {
  return EntitlementFailure(switch (kind) {
    EntitlementDataFailureKind.unauthenticated =>
      EntitlementFailureKind.unauthenticated,
    EntitlementDataFailureKind.invalidInput =>
      EntitlementFailureKind.invalidInput,
    EntitlementDataFailureKind.notFoundOrForbidden =>
      EntitlementFailureKind.notFoundOrForbidden,
    EntitlementDataFailureKind.temporarilyUnavailable =>
      EntitlementFailureKind.temporarilyUnavailable,
    EntitlementDataFailureKind.invalidPayload =>
      EntitlementFailureKind.invalidPayload,
    EntitlementDataFailureKind.unknown => EntitlementFailureKind.unknown,
  });
}
