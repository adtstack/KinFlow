import 'package:kinflow_app/features/household/domain/entities/active_household.dart';

abstract interface class ActiveHouseholdSnapshotWriter {
  Future<bool> replace(ActiveHousehold household);

  Future<bool> clear();
}

final class UnavailableActiveHouseholdSnapshotWriter
    implements ActiveHouseholdSnapshotWriter {
  const UnavailableActiveHouseholdSnapshotWriter();

  @override
  Future<bool> replace(ActiveHousehold household) async => true;

  @override
  Future<bool> clear() async => true;
}
