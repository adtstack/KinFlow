import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/invite_sharing_controller.dart';
import 'package:kinflow_app/features/household/application/invite_sharing_state.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

import '../../support/fakes/fake_invite_dependencies.dart';
import '../../support/fakes/fake_invite_sharing_dependencies.dart';

void main() {
  test('maps native chooser handoff without claiming delivery', () async {
    final FakeHouseholdInviteShareGateway gateway =
        FakeHouseholdInviteShareGateway();
    final InviteSharingController controller = InviteSharingController(
      gateway,
      FakeHouseholdInviteClipboard(),
    );
    addTearDown(controller.dispose);
    final List<InviteSharingState> states = <InviteSharingState>[];
    final StreamSubscription<InviteSharingState> subscription = controller
        .states
        .listen(states.add);
    addTearDown(subscription.cancel);

    await controller.share(
      _inviteLink(),
      chooserTitle: 'Share KinFlow invitation',
    );

    expect(gateway.links, hasLength(1));
    expect(gateway.chooserTitles, <String>['Share KinFlow invitation']);
    expect(states, hasLength(2));
    expect(
      states.first,
      isA<InviteSharingInProgress>().having(
        (InviteSharingInProgress value) => value.action,
        'action',
        InviteSharingAction.shareLink,
      ),
    );
    expect(
      states.last,
      isA<InviteSharingCompleted>().having(
        (InviteSharingCompleted value) => value.outcome,
        'outcome',
        InviteSharingOutcome.shareSheetOpened,
      ),
    );
  });

  test(
    'single-flight blocks copy and duplicate share while chooser opens',
    () async {
      final Completer<HouseholdInviteShareResult> pending =
          Completer<HouseholdInviteShareResult>();
      final FakeHouseholdInviteShareGateway gateway =
          FakeHouseholdInviteShareGateway(
            callback: (HouseholdInviteLink link, String chooserTitle) =>
                pending.future,
          );
      final FakeHouseholdInviteClipboard clipboard =
          FakeHouseholdInviteClipboard();
      final InviteSharingController controller = InviteSharingController(
        gateway,
        clipboard,
      );
      addTearDown(controller.dispose);
      final HouseholdInviteLink link = _inviteLink();

      final Future<void> first = controller.share(
        link,
        chooserTitle: 'Share invitation',
      );
      final Future<void> duplicate = controller.share(
        link,
        chooserTitle: 'Share invitation',
      );
      final Future<void> blockedCopy = controller.copyLink(link);

      expect(gateway.links, hasLength(1));
      expect(clipboard.linkWrites, isEmpty);
      pending.complete(HouseholdInviteShareResult.unavailable);
      await Future.wait(<Future<void>>[first, duplicate, blockedCopy]);
      expect(
        controller.state,
        isA<InviteSharingCompleted>().having(
          (InviteSharingCompleted value) => value.outcome,
          'outcome',
          InviteSharingOutcome.shareUnavailable,
        ),
      );
    },
  );

  test(
    'provider exceptions become credential-free stable failure states',
    () async {
      final FakeHouseholdInviteShareGateway gateway =
          FakeHouseholdInviteShareGateway(
            callback: (HouseholdInviteLink link, String chooserTitle) async =>
                throw StateError('raw ${link.value} private provider failure'),
          );
      final InviteSharingController controller = InviteSharingController(
        gateway,
        FakeHouseholdInviteClipboard(),
      );
      addTearDown(controller.dispose);

      await controller.share(_inviteLink(), chooserTitle: 'Share invitation');

      expect(
        controller.state,
        isA<InviteSharingCompleted>().having(
          (InviteSharingCompleted value) => value.outcome,
          'outcome',
          InviteSharingOutcome.shareFailed,
        ),
      );
      expect(controller.state.toString(), isNot(contains(inviteTokenValue)));
    },
  );

  test(
    'link and short-code copy failures remain independently retryable',
    () async {
      final FakeHouseholdInviteClipboard clipboard =
          FakeHouseholdInviteClipboard(
            linkResults: <HouseholdInviteCopyResult>[
              HouseholdInviteCopyResult.failed,
              HouseholdInviteCopyResult.copied,
            ],
            shortCodeResults: <HouseholdInviteCopyResult>[
              HouseholdInviteCopyResult.failed,
              HouseholdInviteCopyResult.copied,
            ],
          );
      final InviteSharingController controller = InviteSharingController(
        FakeHouseholdInviteShareGateway(),
        clipboard,
      );
      addTearDown(controller.dispose);
      final InviteShortCode shortCode = InviteShortCode.tryParse(
        inviteShortCodeValue,
      )!;

      await controller.copyLink(_inviteLink());
      expect(
        (controller.state as InviteSharingCompleted).outcome,
        InviteSharingOutcome.linkCopyFailed,
      );
      await controller.copyLink(_inviteLink());
      expect(
        (controller.state as InviteSharingCompleted).outcome,
        InviteSharingOutcome.linkCopied,
      );
      await controller.copyShortCode(shortCode);
      expect(
        (controller.state as InviteSharingCompleted).outcome,
        InviteSharingOutcome.shortCodeCopyFailed,
      );
      await controller.copyShortCode(shortCode);
      expect(
        (controller.state as InviteSharingCompleted).outcome,
        InviteSharingOutcome.shortCodeCopied,
      );
    },
  );
}

HouseholdInviteLink _inviteLink() {
  return HouseholdInviteLink.tryCreate(
    host: 'auth.example.invalid',
    token: InviteToken.tryParse(inviteTokenValue)!,
  )!;
}
