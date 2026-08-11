import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';

enum HouseholdInviteShareResult { opened, unavailable, failed }

abstract interface class HouseholdInviteShareGateway {
  Future<HouseholdInviteShareResult> share(
    HouseholdInviteLink link, {
    required String chooserTitle,
  });
}
