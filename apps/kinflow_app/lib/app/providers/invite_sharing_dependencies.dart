import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/application/unavailable_household_invite_sharing.dart';
import 'package:kinflow_app/infrastructure/clipboard/flutter_household_invite_clipboard.dart';
import 'package:kinflow_app/infrastructure/share/platform_household_invite_share_gateway.dart';

final class InviteSharingDependencies {
  const InviteSharingDependencies({
    required this.shareGateway,
    required this.clipboard,
  });

  final HouseholdInviteShareGateway shareGateway;
  final HouseholdInviteClipboard clipboard;
}

InviteSharingDependencies createInviteSharingDependencies() {
  return InviteSharingDependencies(
    shareGateway: createPlatformHouseholdInviteShareGateway(),
    clipboard: const FlutterHouseholdInviteClipboard(),
  );
}

InviteSharingDependencies createUnavailableInviteSharingDependencies() {
  return const InviteSharingDependencies(
    shareGateway: UnavailableHouseholdInviteShareGateway(),
    clipboard: UnavailableHouseholdInviteClipboard(),
  );
}
