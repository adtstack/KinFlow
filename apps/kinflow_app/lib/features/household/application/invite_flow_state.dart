import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';

sealed class InviteFlowState {
  const InviteFlowState();
}

final class InviteFlowIdle extends InviteFlowState {
  const InviteFlowIdle();
}

final class InviteFlowMissing extends InviteFlowState {
  const InviteFlowMissing();
}

final class InviteFlowLoading extends InviteFlowState {
  const InviteFlowLoading();
}

final class InviteFlowPreviewReady extends InviteFlowState {
  const InviteFlowPreviewReady(this.preview);

  final HouseholdInvitePreview preview;
}

final class InviteFlowAccepting extends InviteFlowState {
  const InviteFlowAccepting(this.preview);

  final HouseholdInvitePreview preview;
}

final class InviteFlowAccepted extends InviteFlowState {
  const InviteFlowAccepted(this.acceptance);

  final AcceptedHouseholdInvite acceptance;
}

final class InviteFlowFailed extends InviteFlowState {
  const InviteFlowFailed(this.failure, {this.preview});

  final InviteFailure failure;
  final HouseholdInvitePreview? preview;
}
