import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';

sealed class RecurringChoreCreationState {
  const RecurringChoreCreationState();
}

final class RecurringChoreCreationIdle extends RecurringChoreCreationState {
  const RecurringChoreCreationIdle();
}

final class RecurringChoreCreationSubmitting
    extends RecurringChoreCreationState {
  const RecurringChoreCreationSubmitting();
}

final class RecurringChoreCreationSucceeded
    extends RecurringChoreCreationState {
  const RecurringChoreCreationSucceeded(this.snapshot);

  final RecurringChoreSnapshot snapshot;
}

final class RecurringChoreCreationFailed extends RecurringChoreCreationState {
  const RecurringChoreCreationFailed(this.failure);

  final ChoreFailure failure;
}
