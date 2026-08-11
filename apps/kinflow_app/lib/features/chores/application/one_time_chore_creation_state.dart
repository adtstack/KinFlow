import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';

sealed class OneTimeChoreCreationState {
  const OneTimeChoreCreationState();
}

final class OneTimeChoreCreationIdle extends OneTimeChoreCreationState {
  const OneTimeChoreCreationIdle();
}

final class OneTimeChoreCreationSubmitting extends OneTimeChoreCreationState {
  const OneTimeChoreCreationSubmitting();
}

final class OneTimeChoreCreationSucceeded extends OneTimeChoreCreationState {
  const OneTimeChoreCreationSucceeded(this.occurrence);

  final ChoreOccurrence occurrence;
}

final class OneTimeChoreCreationFailed extends OneTimeChoreCreationState {
  const OneTimeChoreCreationFailed(this.failure);

  final ChoreFailure failure;
}
