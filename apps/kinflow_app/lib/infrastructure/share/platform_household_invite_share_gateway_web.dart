import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/infrastructure/share/browser_web_share_client.dart';
import 'package:kinflow_app/infrastructure/share/web_household_invite_share_gateway.dart';

HouseholdInviteShareGateway createPlatformHouseholdInviteShareGateway() {
  return WebHouseholdInviteShareGateway(const BrowserWebShareClient());
}
