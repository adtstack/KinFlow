import 'package:flutter/services.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

typedef HouseholdInviteClipboardWriter = Future<void> Function(String text);

final class FlutterHouseholdInviteClipboard
    implements HouseholdInviteClipboard {
  const FlutterHouseholdInviteClipboard({
    this.writer = writeHouseholdInviteClipboardText,
  });

  final HouseholdInviteClipboardWriter writer;

  @override
  Future<HouseholdInviteCopyResult> copyLink(HouseholdInviteLink link) {
    return _write(link.value);
  }

  @override
  Future<HouseholdInviteCopyResult> copyShortCode(InviteShortCode shortCode) {
    return _write(shortCode.formatted);
  }

  Future<HouseholdInviteCopyResult> _write(String text) async {
    try {
      await writer(text);
      return HouseholdInviteCopyResult.copied;
    } on Object {
      return HouseholdInviteCopyResult.failed;
    }
  }
}

Future<void> writeHouseholdInviteClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
