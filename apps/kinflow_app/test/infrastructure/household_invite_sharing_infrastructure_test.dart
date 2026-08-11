import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';
import 'package:kinflow_app/infrastructure/clipboard/flutter_household_invite_clipboard.dart';
import 'package:kinflow_app/infrastructure/share/method_channel_household_invite_share_gateway.dart';

import '../support/fakes/fake_invite_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel(
    MethodChannelHouseholdInviteShareGateway.channelName,
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'native adapter sends only exact URL and localized chooser title',
    () async {
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return true;
          });
      const MethodChannelHouseholdInviteShareGateway gateway =
          MethodChannelHouseholdInviteShareGateway();

      final HouseholdInviteShareResult result = await gateway.share(
        _inviteLink(),
        chooserTitle: 'Share KinFlow invitation',
      );

      expect(result, HouseholdInviteShareResult.opened);
      expect(calls, hasLength(1));
      expect(
        calls.single.method,
        MethodChannelHouseholdInviteShareGateway.openMethod,
      );
      expect(calls.single.arguments, <String, String>{
        'url': _inviteLink().value,
        'chooserTitle': 'Share KinFlow invitation',
      });
    },
  );

  test('native false, missing plugin and provider errors map stably', () async {
    const MethodChannelHouseholdInviteShareGateway gateway =
        MethodChannelHouseholdInviteShareGateway();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => false);
    expect(
      await gateway.share(_inviteLink(), chooserTitle: 'Share invitation'),
      HouseholdInviteShareResult.unavailable,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(
      await gateway.share(_inviteLink(), chooserTitle: 'Share invitation'),
      HouseholdInviteShareResult.unavailable,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          throw PlatformException(
            code: 'private_code',
            message: 'raw $inviteTokenValue provider detail',
          );
        });
    expect(
      await gateway.share(_inviteLink(), chooserTitle: 'Share invitation'),
      HouseholdInviteShareResult.failed,
    );
  });

  test(
    'invalid chooser title is rejected before platform invocation',
    () async {
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            callCount += 1;
            return true;
          });
      const MethodChannelHouseholdInviteShareGateway gateway =
          MethodChannelHouseholdInviteShareGateway();

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
      expect(callCount, 0);
    },
  );

  test('clipboard writes exact validated values and never reads', () async {
    final List<String> writes = <String>[];
    final FlutterHouseholdInviteClipboard clipboard =
        FlutterHouseholdInviteClipboard(
          writer: (String text) async => writes.add(text),
        );

    expect(
      await clipboard.copyLink(_inviteLink()),
      HouseholdInviteCopyResult.copied,
    );
    expect(
      await clipboard.copyShortCode(
        InviteShortCode.tryParse(inviteShortCodeValue)!,
      ),
      HouseholdInviteCopyResult.copied,
    );
    expect(writes, <String>[_inviteLink().value, inviteShortCodeValue]);
  });

  test('clipboard provider exceptions map to stable failed result', () async {
    final FlutterHouseholdInviteClipboard clipboard =
        FlutterHouseholdInviteClipboard(
          writer: (String text) async {
            throw StateError('raw $text provider detail');
          },
        );

    expect(
      await clipboard.copyLink(_inviteLink()),
      HouseholdInviteCopyResult.failed,
    );
  });
}

HouseholdInviteLink _inviteLink() {
  return HouseholdInviteLink.tryCreate(
    host: 'auth.example.invalid',
    token: InviteToken.tryParse(inviteTokenValue)!,
  )!;
}
