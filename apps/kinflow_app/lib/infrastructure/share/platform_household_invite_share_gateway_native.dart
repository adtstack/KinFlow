import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/infrastructure/share/method_channel_household_invite_share_gateway.dart';

HouseholdInviteShareGateway createPlatformHouseholdInviteShareGateway() {
  return const MethodChannelHouseholdInviteShareGateway();
}
