enum InviteSharingAction { shareLink, copyLink, copyShortCode }

enum InviteSharingOutcome {
  shareSheetOpened,
  shareUnavailable,
  shareFailed,
  linkCopied,
  linkCopyFailed,
  shortCodeCopied,
  shortCodeCopyFailed,
}

sealed class InviteSharingState {
  const InviteSharingState();
}

final class InviteSharingIdle extends InviteSharingState {
  const InviteSharingIdle();
}

final class InviteSharingInProgress extends InviteSharingState {
  const InviteSharingInProgress(this.action);

  final InviteSharingAction action;
}

final class InviteSharingCompleted extends InviteSharingState {
  const InviteSharingCompleted(this.outcome);

  final InviteSharingOutcome outcome;
}
