import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class UnavailableHouseholdInviteShareGateway
    implements HouseholdInviteShareGateway {
  const UnavailableHouseholdInviteShareGateway();

  @override
  Future<HouseholdInviteShareResult> share(
    HouseholdInviteLink link, {
    required String chooserTitle,
  }) async => HouseholdInviteShareResult.unavailable;
}

final class UnavailableHouseholdInviteClipboard
    implements HouseholdInviteClipboard {
  const UnavailableHouseholdInviteClipboard();

  @override
  Future<HouseholdInviteCopyResult> copyLink(HouseholdInviteLink link) async {
    return HouseholdInviteCopyResult.failed;
  }

  @override
  Future<HouseholdInviteCopyResult> copyShortCode(
    InviteShortCode shortCode,
  ) async {
    return HouseholdInviteCopyResult.failed;
  }
}
