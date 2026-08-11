import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

sealed class GuidedChoreSetupState {
  const GuidedChoreSetupState();
}

final class GuidedChoreSetupInitial extends GuidedChoreSetupState {
  const GuidedChoreSetupInitial();
}

final class GuidedChoreSetupLoading extends GuidedChoreSetupState {
  const GuidedChoreSetupLoading();
}

final class GuidedChoreSetupReady extends GuidedChoreSetupState {
  const GuidedChoreSetupReady({
    required this.startLocalDate,
    required this.householdTimezone,
  });

  final ChoreLocalDate startLocalDate;
  final String householdTimezone;
}

final class GuidedChoreSetupLoadFailed extends GuidedChoreSetupState {
  const GuidedChoreSetupLoadFailed(this.failure);

  final ChoreFailure failure;
}

final class GuidedChoreSetupSubmitting extends GuidedChoreSetupState {
  const GuidedChoreSetupSubmitting({
    required this.startLocalDate,
    required this.householdTimezone,
    required this.completedCount,
    required this.frozenInputs,
    required this.resumed,
  });

  final ChoreLocalDate startLocalDate;
  final String householdTimezone;
  final int completedCount;
  final List<GuidedChoreSetupInput> frozenInputs;
  final bool resumed;
}

final class GuidedChoreSetupSubmissionFailed extends GuidedChoreSetupState {
  const GuidedChoreSetupSubmissionFailed({
    required this.startLocalDate,
    required this.householdTimezone,
    required this.completedCount,
    required this.failure,
    required this.draftFrozen,
    required this.frozenInputs,
    required this.resumed,
  });

  final ChoreLocalDate startLocalDate;
  final String householdTimezone;
  final int completedCount;
  final ChoreFailure failure;
  final bool draftFrozen;
  final List<GuidedChoreSetupInput> frozenInputs;
  final bool resumed;
}

final class GuidedChoreSetupSucceeded extends GuidedChoreSetupState {
  const GuidedChoreSetupSucceeded({required this.createdCount});

  final int createdCount;
}
