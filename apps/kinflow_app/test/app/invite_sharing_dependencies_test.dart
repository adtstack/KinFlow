import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/providers/invite_sharing_dependencies.dart';
import 'package:kinflow_app/features/household/application/unavailable_household_invite_sharing.dart';
import 'package:kinflow_app/infrastructure/clipboard/flutter_household_invite_clipboard.dart';
import 'package:kinflow_app/infrastructure/share/method_channel_household_invite_share_gateway.dart';

void main() {
  test(
    'configured composition installs native share and write-only clipboard',
    () {
      final InviteSharingDependencies dependencies =
          createInviteSharingDependencies();

      expect(
        dependencies.shareGateway,
        isA<MethodChannelHouseholdInviteShareGateway>(),
      );
      expect(dependencies.clipboard, isA<FlutterHouseholdInviteClipboard>());
    },
  );

  test('unavailable composition fails closed', () {
    final InviteSharingDependencies dependencies =
        createUnavailableInviteSharingDependencies();

    expect(
      dependencies.shareGateway,
      isA<UnavailableHouseholdInviteShareGateway>(),
    );
    expect(dependencies.clipboard, isA<UnavailableHouseholdInviteClipboard>());
  });
}
