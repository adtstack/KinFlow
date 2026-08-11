import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

enum HouseholdInviteCopyResult { copied, failed }

abstract interface class HouseholdInviteClipboard {
  Future<HouseholdInviteCopyResult> copyLink(HouseholdInviteLink link);

  Future<HouseholdInviteCopyResult> copyShortCode(InviteShortCode shortCode);
}
