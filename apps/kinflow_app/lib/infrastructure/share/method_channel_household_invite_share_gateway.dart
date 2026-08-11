import 'package:flutter/services.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';

final class MethodChannelHouseholdInviteShareGateway
    implements HouseholdInviteShareGateway {
  const MethodChannelHouseholdInviteShareGateway({
    this.channel = const MethodChannel(channelName),
  });

  static const String channelName = 'me.newlines.kinflow/invite_sharing';
  static const String openMethod = 'openInviteShareSheet';

  final MethodChannel channel;

  @override
  Future<HouseholdInviteShareResult> share(
    HouseholdInviteLink link, {
    required String chooserTitle,
  }) async {
    if (chooserTitle.trim().isEmpty || chooserTitle.length > 120) {
      return HouseholdInviteShareResult.failed;
    }
    try {
      final bool? opened = await channel.invokeMethod<bool>(
        openMethod,
        <String, String>{'url': link.value, 'chooserTitle': chooserTitle},
      );
      return opened == true
          ? HouseholdInviteShareResult.opened
          : HouseholdInviteShareResult.unavailable;
    } on MissingPluginException {
      return HouseholdInviteShareResult.unavailable;
    } on PlatformException {
      return HouseholdInviteShareResult.failed;
    } on Object {
      return HouseholdInviteShareResult.failed;
    }
  }
}
