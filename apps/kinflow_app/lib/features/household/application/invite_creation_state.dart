import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';

sealed class InviteCreationState {
  const InviteCreationState();
}

final class InviteCreationIdle extends InviteCreationState {
  const InviteCreationIdle();
}

final class InviteCreationSubmitting extends InviteCreationState {
  const InviteCreationSubmitting();
}

final class InviteCreationSucceeded extends InviteCreationState {
  const InviteCreationSucceeded(this.invite);

  final HouseholdInvite invite;
}

final class InviteCreationRevoking extends InviteCreationState {
  const InviteCreationRevoking(this.invite);

  final HouseholdInvite invite;
}

final class InviteCreationFailed extends InviteCreationState {
  const InviteCreationFailed(this.failure, {this.invite});

  final InviteFailure failure;
  final HouseholdInvite? invite;
}
