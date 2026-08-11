import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';

abstract interface class WebShareClient {
  bool get isSupported;

  Future<void> share({required String title, required String url});
}

final class WebHouseholdInviteShareGateway
    implements HouseholdInviteShareGateway {
  const WebHouseholdInviteShareGateway(this._client);

  final WebShareClient _client;

  @override
  Future<HouseholdInviteShareResult> share(
    HouseholdInviteLink link, {
    required String chooserTitle,
  }) async {
    if (chooserTitle.trim().isEmpty || chooserTitle.length > 120) {
      return HouseholdInviteShareResult.failed;
    }
    if (!_client.isSupported) {
      return HouseholdInviteShareResult.unavailable;
    }
    try {
      await _client.share(title: chooserTitle, url: link.value);
      return HouseholdInviteShareResult.opened;
    } on Object {
      // Browser exception names and messages may contain implementation detail.
      return HouseholdInviteShareResult.failed;
    }
  }
}
