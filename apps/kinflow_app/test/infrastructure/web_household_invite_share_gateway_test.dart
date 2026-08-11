import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';
import 'package:kinflow_app/infrastructure/share/web_household_invite_share_gateway.dart';

import '../support/fakes/fake_invite_dependencies.dart';

void main() {
  test(
    'hands only the validated URL and localized title to Web Share',
    () async {
      final _RecordingWebShareClient client = _RecordingWebShareClient();
      final WebHouseholdInviteShareGateway gateway =
          WebHouseholdInviteShareGateway(client);

      final HouseholdInviteShareResult result = await gateway.share(
        _inviteLink(),
        chooserTitle: 'Share KinFlow invitation',
      );

      expect(result, HouseholdInviteShareResult.opened);
      expect(client.titles, <String>['Share KinFlow invitation']);
      expect(client.urls, <String>[_inviteLink().value]);
    },
  );

  test(
    'unsupported Web Share returns the explicit-copy fallback state',
    () async {
      final _RecordingWebShareClient client = _RecordingWebShareClient(
        isSupported: false,
      );
      final WebHouseholdInviteShareGateway gateway =
          WebHouseholdInviteShareGateway(client);

      expect(
        await gateway.share(_inviteLink(), chooserTitle: 'Share invitation'),
        HouseholdInviteShareResult.unavailable,
      );
      expect(client.urls, isEmpty);
    },
  );

  test('invalid titles fail before any browser invocation', () async {
    final _RecordingWebShareClient client = _RecordingWebShareClient();
    final WebHouseholdInviteShareGateway gateway =
        WebHouseholdInviteShareGateway(client);

    expect(
      await gateway.share(_inviteLink(), chooserTitle: '   '),
      HouseholdInviteShareResult.failed,
    );
    expect(
      await gateway.share(
        _inviteLink(),
        chooserTitle: List<String>.filled(121, 'a').join(),
      ),
      HouseholdInviteShareResult.failed,
    );
    expect(client.urls, isEmpty);
  });

  test('browser rejection becomes a credential-free stable failure', () async {
    final _RecordingWebShareClient client = _RecordingWebShareClient(
      failure: Exception('raw $inviteTokenValue browser failure'),
    );
    final WebHouseholdInviteShareGateway gateway =
        WebHouseholdInviteShareGateway(client);

    final HouseholdInviteShareResult result = await gateway.share(
      _inviteLink(),
      chooserTitle: 'Share invitation',
    );

    expect(result, HouseholdInviteShareResult.failed);
    expect(result.toString(), isNot(contains(inviteTokenValue)));
  });
}

HouseholdInviteLink _inviteLink() {
  return HouseholdInviteLink.tryCreate(
    host: 'auth.example.invalid',
    token: InviteToken.tryParse(inviteTokenValue)!,
  )!;
}

final class _RecordingWebShareClient implements WebShareClient {
  _RecordingWebShareClient({this.isSupported = true, this.failure});

  @override
  final bool isSupported;
  final Exception? failure;
  final List<String> titles = <String>[];
  final List<String> urls = <String>[];

  @override
  Future<void> share({required String title, required String url}) async {
    titles.add(title);
    urls.add(url);
    final Exception? currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
  }
}
