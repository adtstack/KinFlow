import 'dart:async';

import 'package:kinflow_app/features/household/application/invite_sharing_state.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class InviteSharingController {
  InviteSharingController(this._shareGateway, this._clipboard);

  final HouseholdInviteShareGateway _shareGateway;
  final HouseholdInviteClipboard _clipboard;
  final StreamController<InviteSharingState> _states =
      StreamController<InviteSharingState>.broadcast(sync: true);

  InviteSharingState _state = const InviteSharingIdle();
  Future<void> _pending = Future<void>.value();
  bool _busy = false;
  bool _disposed = false;

  InviteSharingState get state => _state;

  Stream<InviteSharingState> get states => _states.stream;

  Future<void> share(HouseholdInviteLink link, {required String chooserTitle}) {
    return _start(
      action: InviteSharingAction.shareLink,
      failure: InviteSharingOutcome.shareFailed,
      operation: () async {
        final HouseholdInviteShareResult result = await _shareGateway.share(
          link,
          chooserTitle: chooserTitle,
        );
        return switch (result) {
          HouseholdInviteShareResult.opened =>
            InviteSharingOutcome.shareSheetOpened,
          HouseholdInviteShareResult.unavailable =>
            InviteSharingOutcome.shareUnavailable,
          HouseholdInviteShareResult.failed => InviteSharingOutcome.shareFailed,
        };
      },
    );
  }

  Future<void> copyLink(HouseholdInviteLink link) {
    return _start(
      action: InviteSharingAction.copyLink,
      failure: InviteSharingOutcome.linkCopyFailed,
      operation: () async {
        final HouseholdInviteCopyResult result = await _clipboard.copyLink(
          link,
        );
        return result == HouseholdInviteCopyResult.copied
            ? InviteSharingOutcome.linkCopied
            : InviteSharingOutcome.linkCopyFailed;
      },
    );
  }

  Future<void> copyShortCode(InviteShortCode shortCode) {
    return _start(
      action: InviteSharingAction.copyShortCode,
      failure: InviteSharingOutcome.shortCodeCopyFailed,
      operation: () async {
        final HouseholdInviteCopyResult result = await _clipboard.copyShortCode(
          shortCode,
        );
        return result == HouseholdInviteCopyResult.copied
            ? InviteSharingOutcome.shortCodeCopied
            : InviteSharingOutcome.shortCodeCopyFailed;
      },
    );
  }

  Future<void> _start({
    required InviteSharingAction action,
    required InviteSharingOutcome failure,
    required Future<InviteSharingOutcome> Function() operation,
  }) {
    if (_busy || _disposed) return _pending;
    _busy = true;
    _pending = _run(
      action: action,
      failure: failure,
      operation: operation,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _run({
    required InviteSharingAction action,
    required InviteSharingOutcome failure,
    required Future<InviteSharingOutcome> Function() operation,
  }) async {
    _emit(InviteSharingInProgress(action));
    InviteSharingOutcome outcome = failure;
    try {
      outcome = await operation();
    } on Object {
      // Provider details are intentionally reduced to the stable failure.
    }
    _emit(InviteSharingCompleted(outcome));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(InviteSharingState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }
}
