import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';

sealed class HouseholdMembersState {
  const HouseholdMembersState();
}

final class HouseholdMembersInitial extends HouseholdMembersState {
  const HouseholdMembersInitial();
}

final class HouseholdMembersLoading extends HouseholdMembersState {
  const HouseholdMembersLoading();
}

final class HouseholdMembersReady extends HouseholdMembersState {
  const HouseholdMembersReady(
    this.roster, {
    this.isSubmitting = false,
    this.failure,
  });

  final HouseholdMemberRoster roster;
  final bool isSubmitting;
  final HouseholdMemberFailure? failure;
}

final class HouseholdMembersLoadFailed extends HouseholdMembersState {
  const HouseholdMembersLoadFailed(this.failure);

  final HouseholdMemberFailure failure;
}

final class HouseholdMembersLeft extends HouseholdMembersState {
  const HouseholdMembersLeft();
}
