import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class GuidedChoreSetupResumeStore {
  Future<GuidedChoreSetupResumePlan?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedAssigneeMemberId,
  });

  Future<bool> write(GuidedChoreSetupResumePlan plan);

  Future<bool> clear();
}

final class UnavailableGuidedChoreSetupResumeStore
    implements GuidedChoreSetupResumeStore {
  const UnavailableGuidedChoreSetupResumeStore();

  @override
  Future<GuidedChoreSetupResumePlan?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedAssigneeMemberId,
  }) async => null;

  @override
  Future<bool> write(GuidedChoreSetupResumePlan plan) async => false;

  @override
  Future<bool> clear() async => false;
}
