import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class ChoreSyncRepository {
  Stream<ChoreSyncSignal> watch(HouseholdId householdId);
}
