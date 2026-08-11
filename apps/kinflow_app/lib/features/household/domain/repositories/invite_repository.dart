import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

abstract interface class InviteRepository {
  Future<CreateHouseholdInviteResult> createInvite(
    CreateHouseholdInviteRequest request,
  );

  Future<PreviewHouseholdInviteResult> previewInvite(InviteToken token);

  Future<PreviewHouseholdInviteResult> previewInviteByShortCode(
    InviteShortCode shortCode,
  );

  Future<AcceptHouseholdInviteResult> acceptInvite(
    AcceptHouseholdInviteRequest request,
  );

  Future<AcceptHouseholdInviteResult> acceptInviteByShortCode(
    AcceptHouseholdInviteByShortCodeRequest request,
  );

  Future<RevokeHouseholdInviteResult> revokeInvite(
    RevokeHouseholdInviteRequest request,
  );
}

sealed class CreateHouseholdInviteResult {
  const CreateHouseholdInviteResult();
}

final class HouseholdInviteCreated extends CreateHouseholdInviteResult {
  const HouseholdInviteCreated(this.invite);

  final HouseholdInvite invite;
}

final class CreateHouseholdInviteFailed extends CreateHouseholdInviteResult {
  const CreateHouseholdInviteFailed(this.failure);

  final InviteFailure failure;
}

sealed class PreviewHouseholdInviteResult {
  const PreviewHouseholdInviteResult();
}

final class HouseholdInvitePreviewed extends PreviewHouseholdInviteResult {
  const HouseholdInvitePreviewed(this.preview);

  final HouseholdInvitePreview preview;
}

final class PreviewHouseholdInviteFailed extends PreviewHouseholdInviteResult {
  const PreviewHouseholdInviteFailed(this.failure);

  final InviteFailure failure;
}

sealed class AcceptHouseholdInviteResult {
  const AcceptHouseholdInviteResult();
}

final class HouseholdInviteAccepted extends AcceptHouseholdInviteResult {
  const HouseholdInviteAccepted(this.acceptance);

  final AcceptedHouseholdInvite acceptance;
}

final class AcceptHouseholdInviteFailed extends AcceptHouseholdInviteResult {
  const AcceptHouseholdInviteFailed(this.failure);

  final InviteFailure failure;
}

sealed class RevokeHouseholdInviteResult {
  const RevokeHouseholdInviteResult();
}

final class HouseholdInviteRevoked extends RevokeHouseholdInviteResult {
  const HouseholdInviteRevoked(this.inviteId);

  final InviteId inviteId;
}

final class RevokeHouseholdInviteFailed extends RevokeHouseholdInviteResult {
  const RevokeHouseholdInviteFailed(this.failure);

  final InviteFailure failure;
}
