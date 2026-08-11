import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class UnavailableInviteRepository implements InviteRepository {
  const UnavailableInviteRepository();

  static const InviteFailure _failure = InviteFailure(
    InviteFailureKind.temporarilyUnavailable,
  );

  @override
  Future<CreateHouseholdInviteResult> createInvite(
    CreateHouseholdInviteRequest request,
  ) async => const CreateHouseholdInviteFailed(_failure);

  @override
  Future<PreviewHouseholdInviteResult> previewInvite(InviteToken token) async =>
      const PreviewHouseholdInviteFailed(_failure);

  @override
  Future<PreviewHouseholdInviteResult> previewInviteByShortCode(
    InviteShortCode shortCode,
  ) async => const PreviewHouseholdInviteFailed(_failure);

  @override
  Future<AcceptHouseholdInviteResult> acceptInvite(
    AcceptHouseholdInviteRequest request,
  ) async => const AcceptHouseholdInviteFailed(_failure);

  @override
  Future<AcceptHouseholdInviteResult> acceptInviteByShortCode(
    AcceptHouseholdInviteByShortCodeRequest request,
  ) async => const AcceptHouseholdInviteFailed(_failure);

  @override
  Future<RevokeHouseholdInviteResult> revokeInvite(
    RevokeHouseholdInviteRequest request,
  ) async => const RevokeHouseholdInviteFailed(_failure);
}
