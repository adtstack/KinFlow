// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KinFlow';

  @override
  String get developmentBanner => 'DEV';

  @override
  String get startupLoadingLabel => 'Starting KinFlow';

  @override
  String get startupErrorTitle => 'KinFlow couldn\'t start';

  @override
  String get startupErrorBody =>
      'Please try again. If the problem continues, restart the app.';

  @override
  String get authLoadingLabel => 'Checking your session';

  @override
  String get authSignInTitle => 'Sign in to KinFlow';

  @override
  String get authSignInBody =>
      'Use a one-time code sent to your email, or continue with an adult Google account.';

  @override
  String get authGoogleSignInAction => 'Continue with Google';

  @override
  String get authGoogleSignInHint => 'Signs in with an adult Google account';

  @override
  String get authSigningInLabel => 'Connecting to Google';

  @override
  String get authProviderUnavailableBody =>
      'Google sign-in is temporarily unavailable. Please try again later.';

  @override
  String get authIdentityConflictTitle =>
      'This account cannot be connected automatically';

  @override
  String get authIdentityConflictBody =>
      'KinFlow did not merge accounts. Choose another Google account, or open support if you believe this account should already work.';

  @override
  String get authIdentityChooseAnotherAction => 'Choose another Google account';

  @override
  String get authIdentityChooseAnotherHint =>
      'Opens Google account selection again without merging accounts';

  @override
  String get authIdentitySupportAction => 'Open support';

  @override
  String get authIdentitySupportOpening => 'Opening support';

  @override
  String get authIdentitySupportOpened => 'Support opened outside KinFlow.';

  @override
  String get authIdentitySupportUnavailable =>
      'Support could not be opened. Try again later.';

  @override
  String get authEmailSectionLabel => 'Continue with email';

  @override
  String get authEmailLabel => 'Email address';

  @override
  String get authEmailHint =>
      'We\'ll send a 6-digit code. If needed, this creates a new adult KinFlow account.';

  @override
  String get authEmailSendCodeAction => 'Send sign-in code';

  @override
  String get authEmailSendingCodeAction => 'Sending code';

  @override
  String authEmailCodeSentBody(String maskedEmail) {
    return 'If $maskedEmail can be used, we sent a 6-digit code. Check your inbox and spam folder.';
  }

  @override
  String get authEmailCodeLifetimeBody =>
      'The newest code expires in 10 minutes. You can request another after 60 seconds.';

  @override
  String get authEmailCodeLabel => '6-digit code';

  @override
  String get authEmailCodeHint => 'Enter all 6 digits from the newest email.';

  @override
  String get authEmailVerifyAction => 'Verify and continue';

  @override
  String get authEmailVerifyingAction => 'Verifying code';

  @override
  String get authEmailResendAction => 'Send a new code';

  @override
  String get authEmailResendingAction => 'Sending a new code';

  @override
  String get authEmailChangeAction => 'Use a different email';

  @override
  String get authEmailSigningInLabel => 'Code verified. Finishing sign-in.';

  @override
  String get authEmailInvalidEmailError => 'Enter a valid email address.';

  @override
  String get authEmailInvalidCodeError =>
      'Enter the newest valid 6-digit code.';

  @override
  String get authEmailExpiredError =>
      'This code expired. Send a new code to continue.';

  @override
  String get authEmailAlreadyUsedError => 'This code has already been used.';

  @override
  String get authEmailRateLimitedError =>
      'Please wait before requesting or checking another code.';

  @override
  String get authEmailTemporarilyUnavailableError =>
      'Email sign-in is temporarily unavailable. Try again later.';

  @override
  String get authSessionExpiredBody =>
      'Your session expired or was revoked. Sign in again.';

  @override
  String get authLocalStateLockedBody =>
      'KinFlow locked access because local data could not be cleared safely. Restart the app before trying again.';

  @override
  String get authLogoutAction => 'Sign out';

  @override
  String get householdLookupErrorTitle => 'We couldn\'t load your household';

  @override
  String get householdLookupErrorBody =>
      'Check your connection and try again. Your household data has not been changed.';

  @override
  String get householdOnboardingTitle => 'Set up your household';

  @override
  String get householdOnboardingHeading => 'Create a shared home';

  @override
  String get householdOnboardingBody =>
      'Add your name and a name for your household. You will become the household Owner.';

  @override
  String get householdAdditionalSettingsTitle => 'Additional settings';

  @override
  String get householdAdditionalSettingsBody =>
      'Review or change language and timezone before creating.';

  @override
  String get ownerDisplayNameLabel => 'Your display name';

  @override
  String get householdNameLabel => 'Household name';

  @override
  String get householdNameValidation =>
      'Enter 1–80 characters without control characters.';

  @override
  String get householdLocaleLabel => 'Language';

  @override
  String get householdTimezoneLabel => 'Timezone';

  @override
  String get householdTimezoneHint =>
      'Choose an IANA region or city such as Asia/Seoul.';

  @override
  String get householdTimezonePickerTitle => 'Choose the household timezone';

  @override
  String get householdTimezoneValidation => 'Choose an IANA timezone.';

  @override
  String get householdCreateAction => 'Create household';

  @override
  String get householdCreatingAction => 'Creating household';

  @override
  String get householdInvalidInputError =>
      'Check the highlighted details and try again.';

  @override
  String get householdAlreadyExistsError =>
      'This account already has an active household. Reload your household to continue.';

  @override
  String get householdRequestConflictError =>
      'These details changed during a retry. Review them and submit again.';

  @override
  String get householdCreateError =>
      'We couldn\'t create the household. Your request is safe to retry.';

  @override
  String get todayInviteAction => 'Invite an adult';

  @override
  String get inviteCreateTitle => 'Invite to your household';

  @override
  String get inviteCreateHeading => 'Bring another adult into KinFlow';

  @override
  String get inviteCreateBody =>
      'Create a single-use link and a 24-hour companion code. You can optionally restrict the invitation to one email address.';

  @override
  String get inviteEmailLabel => 'Recipient email (optional)';

  @override
  String get inviteEmailHint => 'The signed-in account must match this email.';

  @override
  String get inviteCreateAction => 'Create invitation';

  @override
  String get inviteCreatingAction => 'Creating invite';

  @override
  String get inviteLinkHeading => 'Your invitation is ready';

  @override
  String get inviteLinkBody =>
      'Share this link only with the intended adult. KinFlow will not show the token again after this screen closes.';

  @override
  String get inviteCodeHeading => '24-hour invite code';

  @override
  String get inviteCodeBody =>
      'Share this code only with the intended adult. It expires sooner than the link and will not be shown again.';

  @override
  String get inviteCodeCopyAction => 'Copy code';

  @override
  String get inviteCodeCopiedBody => 'Invite code copied.';

  @override
  String get inviteCopyAction => 'Copy link';

  @override
  String get inviteCopiedBody => 'Invite link copied.';

  @override
  String get inviteShareAction => 'Share link';

  @override
  String get inviteShareChooserTitle => 'Share KinFlow invitation';

  @override
  String get inviteShareOpeningBody => 'Opening the share sheet…';

  @override
  String get inviteShareOpenedBody =>
      'Share sheet opened. Confirm the recipient before sending; KinFlow cannot confirm delivery.';

  @override
  String get inviteShareUnavailableBody =>
      'The share sheet is unavailable. Use Copy link below and send it only to the intended adult.';

  @override
  String get inviteShareFailedBody =>
      'Sharing stopped safely. Use Copy link below or try Share link again.';

  @override
  String get inviteCopyingBody =>
      'Writing the invitation to the system clipboard…';

  @override
  String get inviteCopyFailedBody =>
      'Could not copy the invitation. Select the value above manually or try again.';

  @override
  String get inviteClipboardNotice =>
      'Copying places this single-use invitation on the system clipboard. Send it only to the intended adult, then clear clipboard history if your device or keyboard keeps it.';

  @override
  String get inviteTokenUnavailableBody =>
      'This retry is safe, but the one-time link can no longer be shown. Revoke it and create a new invite.';

  @override
  String get inviteRevokeAction => 'Revoke invite';

  @override
  String get inviteRevokingAction => 'Revoking invite';

  @override
  String get inviteNewAction => 'Create another invite';

  @override
  String get inviteOpenTitle => 'Household invitation';

  @override
  String get inviteLoadingLabel => 'Checking this invitation';

  @override
  String get inviteMissingTitle => 'Invitation unavailable';

  @override
  String get inviteMissingBody =>
      'Open the original invitation link again or ask the sender for a new one.';

  @override
  String get inviteCodeEntryTitle => 'Enter an invite code';

  @override
  String get inviteCodeEntryBody =>
      'Enter the 8-character code from the household owner. Checking and accepting an invitation requires an internet connection.';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get inviteCodeHint => 'ABCD-EFGH';

  @override
  String get inviteCodeValidation => 'Enter a valid 8-character invite code.';

  @override
  String get inviteCodeSubmitAction => 'Check invitation';

  @override
  String get inviteEnterCodeAction => 'Enter an invite code';

  @override
  String get inviteAnotherCodeAction => 'Try another code';

  @override
  String invitePreviewSentence(String inviterName, String householdName) {
    return '$inviterName invited you to join $householdName.';
  }

  @override
  String get inviteRoleMember => 'Household member';

  @override
  String get inviteRoleAdmin => 'Household admin';

  @override
  String inviteExpiryLabel(String expiresAt) {
    return 'Expires $expiresAt';
  }

  @override
  String get inviteSignInBody =>
      'Sign in with the adult account that should join this household. This invitation will remain in memory during sign-in.';

  @override
  String get inviteSignInAction => 'Sign in to accept';

  @override
  String get inviteSwitchTitle => 'Switch active household?';

  @override
  String get inviteSwitchBody =>
      'You already have an active household. Joining will keep both memberships and switch KinFlow to this household.';

  @override
  String get inviteSwitchConfirmation =>
      'I want to join and switch to this household.';

  @override
  String get inviteAcceptAction => 'Accept invitation';

  @override
  String get inviteAcceptingAction => 'Joining household';

  @override
  String get inviteAcceptedBody => 'You joined the household. Opening Today…';

  @override
  String get inviteInvalidError =>
      'This invitation is invalid or no longer available.';

  @override
  String get inviteExpiredError =>
      'This invitation has expired. Ask the sender for a new one.';

  @override
  String get inviteRevokedError =>
      'This invitation was revoked. Ask the sender for a new one.';

  @override
  String get inviteAlreadyUsedError =>
      'This single-use invitation has already been accepted.';

  @override
  String get inviteEmailMismatchError =>
      'Sign in with the email address this invitation was created for.';

  @override
  String get inviteRateLimitedError =>
      'Too many invitation attempts. Wait a few minutes and try again.';

  @override
  String get invitePermissionError =>
      'Only the household Owner or an Admin can manage invitations.';

  @override
  String get inviteGenericError =>
      'We couldn\'t complete the invitation request. It is safe to try again.';

  @override
  String get todayMembersAction => 'Manage household members';

  @override
  String get membersTitle => 'Household members';

  @override
  String get membersLoadingLabel => 'Loading household members';

  @override
  String membersHeading(String householdName) {
    return 'Members of $householdName';
  }

  @override
  String get membersBody =>
      'Review and manage active adult members and roles. Every change is completed online.';

  @override
  String get membersYouLabel => 'You';

  @override
  String get membersRoleOwner => 'Owner';

  @override
  String get membersRoleAdmin => 'Admin';

  @override
  String get membersRoleMember => 'Member';

  @override
  String membersMenuTooltip(String memberName) {
    return 'Actions for $memberName';
  }

  @override
  String get memberPromoteAdminAction => 'Change to Admin';

  @override
  String get memberDemoteMemberAction => 'Change to Member';

  @override
  String get memberTransferOwnerAction => 'Transfer Owner';

  @override
  String get memberRemoveAction => 'Remove from household';

  @override
  String get householdLeaveAction => 'Leave this household';

  @override
  String get memberRoleChangeTitle => 'Change this role?';

  @override
  String memberRoleChangeBody(String memberName, String role) {
    return 'Change $memberName to $role. Google will ask you to verify your identity before continuing.';
  }

  @override
  String get memberRemoveTitle => 'Remove this member?';

  @override
  String memberRemoveBody(String memberName) {
    return '$memberName will immediately lose access to this household. Their unused invitations will also be revoked.';
  }

  @override
  String get ownerTransferTitle => 'Transfer ownership?';

  @override
  String ownerTransferBody(String memberName) {
    return '$memberName will become the new Owner and you will become an Admin. Google will ask you to verify your identity before continuing.';
  }

  @override
  String get householdLeaveTitle => 'Leave this household?';

  @override
  String get householdLeaveBody =>
      'Your membership and access to this household will end immediately. Shared records will remain with the household.';

  @override
  String get ownerMustTransferBody =>
      'The Owner must transfer ownership to another adult before leaving the household.';

  @override
  String get memberActionInProgress => 'Completing this change securely';

  @override
  String get memberCancelAction => 'Cancel';

  @override
  String get memberConfirmAction => 'Continue';

  @override
  String get membersLoadError =>
      'We couldn\'t load household members. Check your connection and try again.';

  @override
  String get membersPermissionError =>
      'You don\'t have permission to perform this member action.';

  @override
  String get membersVersionConflictError =>
      'Member information changed elsewhere. Reload it and try again.';

  @override
  String get membersOwnerTransferRequiredError =>
      'The last Owner cannot be removed or leave. Transfer ownership first.';

  @override
  String get membersRecentAuthError =>
      'This change needs a recent Google identity check. Try again.';

  @override
  String get membersRecentAuthCancelled =>
      'You cancelled the Google identity check. Household information was not changed.';

  @override
  String get membersAccountChangedError =>
      'A different Google account was selected, so the change was stopped. Check the current account.';

  @override
  String get membersGenericError =>
      'We couldn\'t complete the member change. It is safe to retry the same request.';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayEmptyTitle => 'Nothing is scheduled for today';

  @override
  String get todayEmptyBody =>
      'Your shared household is ready. Chores and events will appear here when they are added.';

  @override
  String get todayLoadingLabel => 'Loading today\'s chores';

  @override
  String get todayCreateChoreAction => 'Add the first chore';

  @override
  String get todayCreateAnotherChoreAction => 'Add another chore';

  @override
  String todayChoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores today',
      one: '1 chore today',
    );
    return '$_temp0';
  }

  @override
  String todayChoreMetadata(String assigneeName, String dueLabel) {
    return '$assigneeName · $dueLabel';
  }

  @override
  String get todayCalendarSectionTitle => 'Today\'s events';

  @override
  String get todayOverdueSectionTitle => 'Overdue chores';

  @override
  String get todayNowAndNextSectionTitle => 'Now and next';

  @override
  String get todayChoresSectionTitle => 'Today\'s chores';

  @override
  String get todayRemainingEventsSectionTitle => 'The rest of today\'s events';

  @override
  String get todayCompletedSectionTitle => 'Completed today';

  @override
  String get todayCompletedExpandAction => 'Show completed chores';

  @override
  String get todayCompletedCollapseAction => 'Hide completed chores';

  @override
  String get todayCalendarLoadingLabel => 'Loading today\'s events';

  @override
  String get todayCalendarRefreshingLabel => 'Refreshing today\'s events';

  @override
  String get todayCalendarEmptyLabel => 'No household events today.';

  @override
  String todayCalendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get todayCalendarHappeningNowLabel => 'Happening now';

  @override
  String todayCalendarStaleMessage(String syncLabel) {
    return 'Showing events loaded at $syncLabel. Events could not be refreshed.';
  }

  @override
  String todayCalendarOfflineMessage(String syncLabel) {
    return 'Showing a saved calendar snapshot from $syncLabel.';
  }

  @override
  String get todayCalendarOfflineReadOnlyHint =>
      'Saved events are read-only. Reconnect and refresh before changing the Today view or household calendar.';

  @override
  String get todayCalendarTruncatedMessage =>
      'Today has more than 500 events. Open Calendar to see the complete day.';

  @override
  String todayCalendarEventSemantics(
    String title,
    String schedule,
    String participants,
  ) {
    return '$title. $schedule. $participants';
  }

  @override
  String get todayOpenCalendarAction => 'Open household Calendar';

  @override
  String get todayChoresUnavailableTitle =>
      'Chores are temporarily unavailable';

  @override
  String get todayPartialFailureHint =>
      'The other Today section remains available.';

  @override
  String get choreListViewFilterLabel => 'Chore date and status filter';

  @override
  String get choreListAssigneeFilterLabel => 'Chore assignee filter';

  @override
  String get choreListTodayFilter => 'Today';

  @override
  String get choreListUpcomingFilter => 'Upcoming';

  @override
  String get choreListOverdueFilter => 'Overdue';

  @override
  String get choreListCompletedFilter => 'Completed';

  @override
  String get choreListEveryoneFilter => 'Everyone';

  @override
  String get choreListMeFilter => 'Me';

  @override
  String choreListBoundaryDate(String dateLabel) {
    return 'Household date: $dateLabel';
  }

  @override
  String choreListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores',
      one: '1 chore',
    );
    return '$_temp0';
  }

  @override
  String choreListMetadata(
    String assigneeName,
    String dateLabel,
    String dueLabel,
  ) {
    return '$assigneeName · $dateLabel · $dueLabel';
  }

  @override
  String get choreListRefreshing => 'Refreshing chores';

  @override
  String choreListLastSynced(String syncLabel) {
    return 'Last updated $syncLabel';
  }

  @override
  String choreListStaleMessage(String syncLabel) {
    return 'Showing the last available chores from $syncLabel. We couldn\'t refresh them.';
  }

  @override
  String get choreListStaleUnknown =>
      'Showing the last available chores. We couldn\'t refresh them.';

  @override
  String choreListOfflineMessage(String syncLabel) {
    return 'Showing a saved snapshot from $syncLabel.';
  }

  @override
  String get choreListOfflineReadOnlyHint =>
      'Eligible scheduled chore completion can be saved on this device. Reconnect for every other change.';

  @override
  String get choreListUpcomingEmptyTitle => 'No upcoming chores';

  @override
  String get choreListUpcomingEmptyBody =>
      'Future scheduled chores will appear here.';

  @override
  String get choreListOverdueEmptyTitle => 'Nothing is overdue';

  @override
  String get choreListOverdueEmptyBody =>
      'Every earlier scheduled chore has been handled.';

  @override
  String get choreListCompletedEmptyTitle => 'No completed chores yet';

  @override
  String get choreListCompletedEmptyBody =>
      'Completed household chores will remain available here.';

  @override
  String get choreListLoadingMore => 'Loading more chores';

  @override
  String get choreListLoadMoreAction => 'Load more chores';

  @override
  String get choreListLoadMoreFailed =>
      'We couldn\'t load more chores. The chores already shown are still available.';

  @override
  String get choreScheduledStatus => 'Scheduled';

  @override
  String get choreCompletedStatus => 'Completed';

  @override
  String get choreMarkCompleteAction => 'Mark complete';

  @override
  String get choreReopenAction => 'Reopen chore';

  @override
  String get choreCompletionInProgress => 'Updating chore status';

  @override
  String get choreCompletionQueuedStatus => 'Waiting to sync';

  @override
  String get choreCompletionQueuedMessage =>
      'Completion saved on this device. It will be checked and synced when you reconnect.';

  @override
  String get choreCompletionSyncingMessage =>
      'Checking permission and syncing the saved completion…';

  @override
  String get choreCompletionPausedMessage =>
      'The completion is saved, but syncing is paused by the current app policy.';

  @override
  String get choreCompletionReconciledMessage =>
      'Completion synced with the latest household data.';

  @override
  String get choreCompletionNeedsAttentionMessage =>
      'Automatic sync stopped safely. Discard this saved completion, refresh, and complete it again while online.';

  @override
  String get choreCompletionDiscardedMessage =>
      'The saved completion could not be applied because the chore or your access changed. The latest household data is shown.';

  @override
  String get choreCompletionExpiredMessage =>
      'The saved completion expired before it could sync. Refresh and complete it again while online.';

  @override
  String get choreCompletionQueueUnavailableMessage =>
      'This completion could not be saved safely on this device. Reconnect and try again.';

  @override
  String get choreCompletionQueueOccupiedMessage =>
      'One completion is already saved on this device. Discard it before saving another.';

  @override
  String get choreCompletionDiscardAction => 'Discard saved completion';

  @override
  String get choreOccurrenceMenuTooltip => 'More chore actions';

  @override
  String get choreSkipOccurrenceAction => 'Skip this occurrence';

  @override
  String get choreSkipOccurrenceDialogTitle => 'Skip this occurrence?';

  @override
  String get choreSkipOccurrenceDialogBody =>
      'This date will be skipped. The repeating schedule and every other occurrence will stay unchanged.';

  @override
  String get choreSkipOccurrenceConfirmAction => 'Skip occurrence';

  @override
  String get choreSkipOccurrenceSucceeded => 'This occurrence was skipped.';

  @override
  String get choreRestoreSkippedAction => 'Undo';

  @override
  String get choreRestoreSkippedSucceeded =>
      'This occurrence is back on Today.';

  @override
  String get choreRestoreSkippedFailed =>
      'This occurrence could not be restored.';

  @override
  String get choreRescheduleOccurrenceAction => 'Reschedule this occurrence';

  @override
  String get choreRescheduleDialogTitle => 'Reschedule this occurrence';

  @override
  String get choreRescheduleDialogBody =>
      'Only this date changes. The repeating schedule and every other occurrence will stay unchanged.';

  @override
  String get choreRescheduleConfirmAction => 'Save new schedule';

  @override
  String get choreRescheduleSucceeded => 'This occurrence was rescheduled.';

  @override
  String get choreReassignOccurrenceAction =>
      'Change assignee for this occurrence';

  @override
  String get choreReassignDialogTitle => 'Change this occurrence\'s assignee';

  @override
  String get choreReassignDialogBody =>
      'Only this occurrence changes. The repeating schedule and every other occurrence will keep their assignee.';

  @override
  String get choreReassignConfirmAction => 'Save assignee';

  @override
  String get choreReassignSucceeded => 'This occurrence was reassigned.';

  @override
  String get choreReassignRosterFailed =>
      'Household members could not be loaded. Try again.';

  @override
  String get choreEditOneTimeAction => 'Edit this one-time chore';

  @override
  String get choreDeleteOneTimeAction => 'Delete this one-time chore';

  @override
  String get choreEditOneTimeDialogTitle => 'Edit this one-time chore';

  @override
  String get choreEditOneTimeDialogBody =>
      'Update its details, assignee, date, or time. Completed chores must be reopened before they can be edited.';

  @override
  String get choreEditOneTimeConfirmAction => 'Save chore changes';

  @override
  String get choreEditOneTimeSucceeded => 'The one-time chore was updated.';

  @override
  String get choreDeleteOneTimeDialogTitle => 'Delete this one-time chore?';

  @override
  String get choreDeleteOneTimeDialogBody =>
      'It will be removed from chore lists. Its protected history will be kept.';

  @override
  String get choreDeleteOneTimeConfirmAction => 'Delete chore';

  @override
  String get choreDeleteOneTimeSucceeded => 'The one-time chore was deleted.';

  @override
  String get choreEditSeriesAction => 'Edit repeating series';

  @override
  String get choreCancelSeriesAction => 'Cancel repeating series';

  @override
  String get choreEditSeriesDialogTitle => 'Edit the repeating series';

  @override
  String get choreEditSeriesDialogBody =>
      'Changes apply from today in the household time zone. Past occurrences and completed chores stay unchanged.';

  @override
  String get choreEditSeriesConfirmAction => 'Save series changes';

  @override
  String get choreEditSeriesSucceeded =>
      'The repeating series was updated from today.';

  @override
  String get choreEditSeriesFromOccurrenceAction => 'Edit from this occurrence';

  @override
  String get choreEditSeriesFromOccurrenceDialogTitle =>
      'Edit this and later occurrences';

  @override
  String get choreEditSeriesFromOccurrenceDialogBody =>
      'The selected occurrence and later incomplete chores will use the new series settings. Earlier and completed chores stay unchanged. Later incomplete one-occurrence adjustments may reset to the new defaults.';

  @override
  String get choreEditSeriesFromOccurrenceConfirmAction =>
      'Save from this occurrence';

  @override
  String get choreEditSeriesFromOccurrenceSucceeded =>
      'The repeating series was updated from the selected occurrence.';

  @override
  String get choreCancelSeriesFromOccurrenceAction =>
      'Cancel from this occurrence';

  @override
  String get choreCancelSeriesFromOccurrenceDialogTitle =>
      'Cancel this and later occurrences?';

  @override
  String get choreCancelSeriesFromOccurrenceDialogBody =>
      'The selected occurrence and later incomplete chores will be removed. Earlier occurrences and completed chores stay unchanged.';

  @override
  String get choreCancelSeriesFromOccurrenceConfirmAction =>
      'Cancel from this occurrence';

  @override
  String get choreCancelSeriesFromOccurrenceSucceeded =>
      'The repeating series was cancelled from the selected occurrence.';

  @override
  String get choreCancelSeriesFromOccurrenceUndoAction => 'Undo';

  @override
  String get choreCancelSeriesFromOccurrenceUndoSucceeded =>
      'The repeating series was restored.';

  @override
  String get choreCancelSeriesFromOccurrenceUndoFailed =>
      'Could not restore the repeating series. Try again.';

  @override
  String get choreCancelSeriesDialogTitle => 'Cancel this repeating series?';

  @override
  String get choreCancelSeriesDialogBody =>
      'Incomplete occurrences from today onward will be removed. Past occurrences and completed chores stay unchanged.';

  @override
  String get choreCancelSeriesConfirmAction => 'Cancel series';

  @override
  String get choreCancelSeriesSucceeded =>
      'The repeating series was cancelled from today.';

  @override
  String get choreDetailsAction => 'View chore details and activity';

  @override
  String get choreDetailsTitle => 'Chore details';

  @override
  String get choreDetailsCloseTooltip => 'Close chore details';

  @override
  String get choreDetailsCurrentHeading => 'Current details';

  @override
  String get choreTargetLoading => 'Loading the latest chore details';

  @override
  String get choreTargetUnavailableTitle => 'This chore is unavailable';

  @override
  String get choreTargetUnavailableBody =>
      'It may have changed, been removed, or no longer be available in this household.';

  @override
  String get choreTargetLoadFailedTitle => 'Chore details could not be loaded';

  @override
  String get choreTargetLoadFailedBody =>
      'Check your connection and try again. No cached chore details are shown here.';

  @override
  String get choreTargetNotificationsAction => 'Open notifications';

  @override
  String get choreTargetChoresAction => 'Open chores';

  @override
  String get choreHistoryHeading => 'Activity';

  @override
  String get choreHistoryLoading => 'Loading chore activity';

  @override
  String get choreHistoryEmptyTitle => 'No activity yet';

  @override
  String get choreHistoryEmptyBody =>
      'Changes to this occurrence will appear here.';

  @override
  String get choreHistoryLoadFailed =>
      'Chore activity could not be loaded. Try again.';

  @override
  String get choreHistoryLoadMoreAction => 'Load earlier activity';

  @override
  String get choreHistoryLoadingMore => 'Loading earlier activity';

  @override
  String get choreHistoryLoadMoreFailed =>
      'Earlier activity could not be loaded.';

  @override
  String choreHistoryActorActingAs(String actorName, String actingName) {
    return '$actorName for $actingName';
  }

  @override
  String choreHistoryCompleted(String actorName) {
    return '$actorName completed this chore.';
  }

  @override
  String choreHistoryReopened(String actorName) {
    return '$actorName reopened this chore.';
  }

  @override
  String choreHistorySkipped(String actorName) {
    return '$actorName skipped this occurrence.';
  }

  @override
  String choreHistoryRestored(String actorName) {
    return '$actorName restored this occurrence.';
  }

  @override
  String choreHistoryRescheduled(
    String actorName,
    String previousSchedule,
    String newSchedule,
  ) {
    return '$actorName changed the schedule from $previousSchedule to $newSchedule.';
  }

  @override
  String choreHistoryReassigned(
    String actorName,
    String previousAssignee,
    String newAssignee,
  ) {
    return '$actorName changed the assignee from $previousAssignee to $newAssignee.';
  }

  @override
  String choreHistoryTimestamp(String date, String time) {
    return '$date · $time';
  }

  @override
  String choreScheduleLabel(String date, String time) {
    return '$date · $time';
  }

  @override
  String get choreCreateTitle => 'Add a chore';

  @override
  String get choreCreateHeading => 'Schedule a household task';

  @override
  String get choreCreateBody =>
      'Choose an active adult, the first due date, and whether this task repeats.';

  @override
  String get choreTemplatesHeading => 'Quick starts';

  @override
  String get choreTemplatesBody =>
      'Choose a suggestion to fill its title and repeat. You can edit every detail.';

  @override
  String get choreTemplateSearchLabel => 'Search quick starts';

  @override
  String get choreTemplateSearchClearAction => 'Clear template search';

  @override
  String get choreTemplateCategoryAll => 'All';

  @override
  String get choreTemplateCategoryKitchen => 'Kitchen';

  @override
  String get choreTemplateCategoryCleaning => 'Cleaning';

  @override
  String get choreTemplateCategoryLaundry => 'Laundry';

  @override
  String get choreTemplateCategoryHomeCare => 'Home care';

  @override
  String get choreTemplateCategoryPetCare => 'Pet care';

  @override
  String get choreTemplateNoResults =>
      'No quick starts match this search and category.';

  @override
  String get choreTemplateDishes => 'Dishes';

  @override
  String get choreTemplateKitchenReset => 'Kitchen reset';

  @override
  String get choreTemplateLaundry => 'Laundry';

  @override
  String get choreTemplateVacuuming => 'Vacuuming';

  @override
  String get choreTemplateBathroomCleaning => 'Bathroom cleaning';

  @override
  String get choreTemplateTrashAndRecycling => 'Trash and recycling';

  @override
  String get choreTemplateWipeCounters => 'Wipe counters';

  @override
  String get choreTemplateFridgeCleanout => 'Clean out the fridge';

  @override
  String get choreTemplateMopFloors => 'Mop floors';

  @override
  String get choreTemplateDusting => 'Dust';

  @override
  String get choreTemplateChangeBedLinen => 'Change bed linen';

  @override
  String get choreTemplateFoldClothes => 'Fold clothes';

  @override
  String get choreTemplateMakeBeds => 'Make beds';

  @override
  String get choreTemplateWaterPlants => 'Water plants';

  @override
  String get choreTemplateFeedPets => 'Feed pets';

  @override
  String get choreTemplateCleanPetArea => 'Clean pet area';

  @override
  String get guidedChoreSetupTitle => 'Set up your first chores';

  @override
  String get guidedChoreSetupHeading => 'Choose three chores to start together';

  @override
  String get guidedChoreSetupBody =>
      'A small shared list makes Today useful right away. Pick exactly three chores, then review them before adding.';

  @override
  String get guidedChoreSetupLoading => 'Preparing household chore suggestions';

  @override
  String get guidedChoreSetupResumeNotice =>
      'Your saved setup was restored. Safely continuing from the last confirmed chore.';

  @override
  String guidedChoreSetupSelectionProgress(int selected, int required) {
    return '$selected of $required selected';
  }

  @override
  String guidedChoreSetupAddingProgress(int completed, int total) {
    return '$completed of $total chores added';
  }

  @override
  String guidedChoreSetupDefaultsBody(String startDate, String timezone) {
    return 'Assigned to you, available any time, and repeating from $startDate in $timezone. You can edit them later.';
  }

  @override
  String get guidedChoreSetupChooseBody =>
      'Pick exactly three suggestions. Selected titles and repeat schedules remain editable.';

  @override
  String get guidedChoreSetupReviewHeading => 'Review your three chores';

  @override
  String get guidedChoreSetupAddAction => 'Add 3 chores';

  @override
  String get guidedChoreSetupRetryAction => 'Continue adding chores';

  @override
  String get guidedChoreSetupSkipAction => 'Skip for now';

  @override
  String get guidedChoreSetupExitTitle => 'Leave quick setup?';

  @override
  String get guidedChoreSetupExitBody =>
      'You can add chores later from Today. Leave quick setup now?';

  @override
  String guidedChoreSetupPartialExitBody(int completed) {
    return 'Added so far: $completed. Those chores will stay in the household, and you can add the rest later. Continue to Today?';
  }

  @override
  String get guidedChoreSetupStayAction => 'Keep setting up';

  @override
  String get guidedChoreSetupContinueTodayAction => 'Continue to Today';

  @override
  String get choreTitleLabel => 'Chore';

  @override
  String get choreTitleValidation => 'Enter a chore name.';

  @override
  String get choreDescriptionLabel => 'Notes (optional)';

  @override
  String get choreAssigneeLabel => 'Assigned to';

  @override
  String choreAssigneeYou(String memberName) {
    return '$memberName (you)';
  }

  @override
  String get choreRecurrenceLabel => 'Repeats';

  @override
  String get choreRecurrenceOnce => 'Does not repeat';

  @override
  String get choreRecurrenceDaily => 'Every day';

  @override
  String get choreRecurrenceWeekly => 'Every week';

  @override
  String get choreRecurrenceMonthly => 'Every month';

  @override
  String choreRecurrenceSummary(String pattern, String startDate) {
    return '$pattern, starting $startDate. Future dates are created in the household time zone.';
  }

  @override
  String get choreRecurrenceWeekdaysLabel => 'Repeat on';

  @override
  String get choreRecurrenceWeekdayCreationAnchorHelper =>
      'The chore\'s first weekday stays selected.';

  @override
  String get choreRecurrenceWeekdayMinimumHelper =>
      'Keep at least one repeat day selected.';

  @override
  String get choreRecurrenceWeekdayMonday => 'Monday';

  @override
  String get choreRecurrenceWeekdayTuesday => 'Tuesday';

  @override
  String get choreRecurrenceWeekdayWednesday => 'Wednesday';

  @override
  String get choreRecurrenceWeekdayThursday => 'Thursday';

  @override
  String get choreRecurrenceWeekdayFriday => 'Friday';

  @override
  String get choreRecurrenceWeekdaySaturday => 'Saturday';

  @override
  String get choreRecurrenceWeekdaySunday => 'Sunday';

  @override
  String choreRecurrenceWeekdaysSummary(String weekdays) {
    return 'On $weekdays.';
  }

  @override
  String get choreRecurrenceMonthDayLabel => 'Day of month';

  @override
  String choreRecurrenceMonthDayOption(int day) {
    return 'Day $day';
  }

  @override
  String get choreRecurrenceMonthDayCreationAnchorHelper =>
      'The first due date sets this day.';

  @override
  String get choreRecurrenceMonthDayMissingDateHelper =>
      'Months without this date are skipped, not moved to the last day.';

  @override
  String choreRecurrenceMonthDaySummary(int day) {
    return 'On day $day of the month.';
  }

  @override
  String get choreRecurrenceIntervalLabel => 'Repeat interval';

  @override
  String get choreRecurrenceIntervalHelper =>
      'Use a whole number from 1 to 30.';

  @override
  String get choreRecurrenceIntervalValidation =>
      'Enter a number from 1 to 30.';

  @override
  String get choreRecurrenceEndLabel => 'Ends';

  @override
  String get choreRecurrenceEndNever => 'Never';

  @override
  String get choreRecurrenceEndAfterCount => 'After a number of occurrences';

  @override
  String get choreRecurrenceEndOnDate => 'On a date';

  @override
  String get choreRecurrenceCountLabel => 'Number of occurrences';

  @override
  String get choreRecurrenceCountHelper =>
      'Use a whole number from 1 to 1,000.';

  @override
  String get choreRecurrenceCountValidation =>
      'Enter a number from 1 to 1,000.';

  @override
  String get choreRecurrenceUntilDateLabel => 'End date';

  @override
  String get choreRecurrenceInvalidSummary => 'Review the repeat settings.';

  @override
  String choreRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String get choreRecurrenceEndNeverSummary =>
      'This series does not have an end date.';

  @override
  String choreRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ends after $count occurrences.',
      one: 'Ends after 1 occurrence.',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEndUntilSummary(String date) {
    return 'Ends on $date.';
  }

  @override
  String get choreDueDateLabel => 'Due date';

  @override
  String get choreDueTimeLabel => 'Due time';

  @override
  String get choreAllDayLabel => 'Any time';

  @override
  String get choreClearTimeAction => 'Remove due time';

  @override
  String get choreCreateAction => 'Add chore';

  @override
  String get choreCreatingAction => 'Adding chore';

  @override
  String get choreCreatedBody => 'Chore added to the household.';

  @override
  String get choreCreateInvalidError =>
      'Check the chore details and try again.';

  @override
  String get choreRecurrenceInvalidError =>
      'That repeat schedule isn\'t supported. Review it and try again.';

  @override
  String get chorePermissionError =>
      'This household or assignee is no longer available. Reload and try again.';

  @override
  String get choreCreateConflictError =>
      'The chore details changed during a retry. Review them and submit again.';

  @override
  String get choreActionConflictError =>
      'This chore action changed during a retry. Reload and try again.';

  @override
  String get choreVersionConflictError =>
      'This chore changed elsewhere. The latest household status is shown.';

  @override
  String get choreTransitionConflictError =>
      'That action no longer matches this chore\'s current status. The latest status is shown.';

  @override
  String get choreGenericError =>
      'We couldn\'t load or save chores. It is safe to try again.';

  @override
  String get choreOfflineReadOnlyError =>
      'This saved snapshot is read-only. Reconnect and refresh before making changes.';

  @override
  String get retryAction => 'Try again';

  @override
  String get retryActionHint => 'Runs this check again';

  @override
  String get foundationReadyTitle => 'KinFlow is ready';

  @override
  String get foundationReadyBody =>
      'The app foundation and code boundaries are running. Product features can now be added safely.';

  @override
  String foundationLayoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adaptive layouts are ready.',
      one: '1 adaptive layout is ready.',
    );
    return '$_temp0';
  }

  @override
  String get foundationLoadingLabel => 'Checking the app foundation';

  @override
  String get foundationErrorTitle => 'The app foundation is unavailable';

  @override
  String get foundationErrorBody => 'Please try the check again.';

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get pageNotFoundBody => 'This page is unavailable.';

  @override
  String get goHomeAction => 'Go home';

  @override
  String get primaryNavigationLabel => 'Primary navigation';

  @override
  String get homeNavigationLabel => 'Home';

  @override
  String get todayNavigationLabel => 'Today';

  @override
  String get choresNavigationLabel => 'Chores';

  @override
  String get calendarNavigationLabel => 'Calendar';

  @override
  String get familyNavigationLabel => 'Family';

  @override
  String get settingsNavigationLabel => 'Settings';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarTodayAction => 'Back to Today';

  @override
  String get calendarLoadingLabel => 'Loading household events';

  @override
  String get calendarEmptyTitle => 'No events yet';

  @override
  String get calendarEmptyBody =>
      'Add a timed event or an all-day plan for your household.';

  @override
  String get calendarCreateAction => 'Add event';

  @override
  String get calendarImportAction => 'Import .ics';

  @override
  String get calendarImportTitle => 'Import calendar file';

  @override
  String get calendarImportIntro =>
      'Choose one UTF-8 .ics file, review the supported events, and copy only the events you select into this household.';

  @override
  String get calendarImportCopyDisclosure =>
      'This is a one-time copy, not a sync. Importing the same file again can create duplicate events, and later external changes are not applied.';

  @override
  String get calendarImportChooseFileAction => 'Choose .ics file';

  @override
  String get calendarImportChooseAnotherAction => 'Choose another file';

  @override
  String get calendarImportBackAction => 'Close import';

  @override
  String get calendarImportPickingLabel => 'Opening the secure document picker';

  @override
  String get calendarImportRosterLoading => 'Loading active household members';

  @override
  String calendarImportSupportedCount(int count) {
    return 'Supported events: $count';
  }

  @override
  String calendarImportSkippedCount(int count) {
    return 'Skipped events: $count';
  }

  @override
  String calendarImportSkippedDetails(
    int invalid,
    int unsupported,
    int duplicate,
  ) {
    return 'Invalid $invalid · unsupported $unsupported · duplicate in file $duplicate';
  }

  @override
  String get calendarImportIgnoredFieldsDisclosure =>
      'Locations, links, organizers, attendees, attachments, and alarms are not copied or opened.';

  @override
  String calendarImportFloatingDisclosure(String timeZone) {
    return 'Events without a time zone use the household time zone $timeZone.';
  }

  @override
  String get calendarImportOverlapDisclosure =>
      'A repeated clock time uses its earlier valid occurrence.';

  @override
  String get calendarImportEventsHeading => 'Events to copy';

  @override
  String calendarImportSelectedCount(int selected, int total) {
    return 'Selected $selected of $total';
  }

  @override
  String get calendarImportNoSupportedEvents =>
      'This file contains no events that KinFlow can copy. Unsupported or invalid events stay unchanged in the source file.';

  @override
  String get calendarImportParticipantsHeading =>
      'Participants for copied events';

  @override
  String get calendarImportParticipantsHelper =>
      'The same active household members will be added to every selected event.';

  @override
  String calendarImportAllDayRange(String startDate, String endDate) {
    return 'All day · $startDate–$endDate';
  }

  @override
  String calendarImportTimedSummary(
    String date,
    String time,
    String duration,
    String timeZone,
  ) {
    return '$date · $time · $duration · $timeZone';
  }

  @override
  String calendarImportSubmitAction(int count) {
    return 'Copy $count selected events';
  }

  @override
  String calendarImportProgress(int completed, int total) {
    return 'Copied $completed of $total events';
  }

  @override
  String calendarImportPartialFailure(int completed, int total) {
    return 'Copied $completed of $total. The next event was not copied.';
  }

  @override
  String get calendarImportRetryAction => 'Retry the remaining events';

  @override
  String calendarImportSuccess(int count) {
    return 'Copied $count events into the household calendar.';
  }

  @override
  String get calendarImportPickerUnavailableError =>
      'The document picker is unavailable in this app build.';

  @override
  String get calendarImportPickerFailedError =>
      'The selected file could not be read safely. Choose it again or use another .ics file.';

  @override
  String get calendarImportInvalidFileError =>
      'This is not a valid supported iCalendar file. The source file was not changed.';

  @override
  String get calendarImportUnsupportedVersionError =>
      'This file does not contain exactly one iCalendar version 2.0 calendar.';

  @override
  String get calendarImportTooLargeError =>
      'Choose an .ics file no larger than 256 KiB.';

  @override
  String get calendarImportTooManyEventsError =>
      'Choose an .ics file with no more than 50 events.';

  @override
  String get calendarEditAction => 'Edit event';

  @override
  String get calendarDeleteAction => 'Delete event';

  @override
  String get calendarOccurrenceEditAction => 'Edit this occurrence';

  @override
  String get calendarOccurrenceCancelAction => 'Cancel this occurrence';

  @override
  String get calendarOccurrenceModifiedLabel => 'Modified occurrence';

  @override
  String get calendarSeriesMenuTooltip => 'Recurring series actions';

  @override
  String get calendarSeriesEditAction => 'Edit entire series';

  @override
  String get calendarSeriesEditFromOccurrenceAction => 'Edit this and later';

  @override
  String get calendarSeriesCancelFromOccurrenceAction => 'End this and later';

  @override
  String get calendarSeriesCancelAction => 'End entire series';

  @override
  String calendarHouseholdTimeZone(String timeZone) {
    return 'Household time zone: $timeZone';
  }

  @override
  String calendarTimedSchedule(String date, String time, String duration) {
    return '$date · $time · $duration';
  }

  @override
  String calendarAllDaySingle(String date) {
    return 'All day · $date';
  }

  @override
  String calendarAllDayRange(String startDate, String endDate) {
    return 'All day · $startDate – $endDate';
  }

  @override
  String calendarParticipantSummary(String names) {
    return 'With $names';
  }

  @override
  String get calendarEditorCreateTitle => 'Add an event';

  @override
  String get calendarEditorEditTitle => 'Edit event';

  @override
  String get calendarOccurrenceEditorEditTitle => 'Edit this occurrence';

  @override
  String get calendarSeriesEditorEditTitle => 'Edit entire series';

  @override
  String get calendarSeriesEditFromOccurrenceEditorTitle =>
      'Edit this and later occurrences';

  @override
  String get calendarSeriesEditFromOccurrenceEditorBody =>
      'The selected occurrence and later series occurrences will use the new settings. Earlier occurrences and existing one-occurrence changes stay unchanged.';

  @override
  String get calendarTitleLabel => 'Event title';

  @override
  String get calendarTitleValidation => 'Enter an event title.';

  @override
  String get calendarDescriptionLabel => 'Notes (optional)';

  @override
  String get calendarAllDayLabel => 'All-day event';

  @override
  String get calendarStartDateLabel => 'Starts';

  @override
  String get calendarEndDateLabel => 'Ends';

  @override
  String get calendarStartTimeLabel => 'Start time';

  @override
  String get calendarDurationLabel => 'Duration';

  @override
  String calendarDurationMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String calendarTimeZoneLabel(String timeZone) {
    return 'Time zone: $timeZone';
  }

  @override
  String get calendarOverlapLabel => 'Repeated clock time';

  @override
  String get calendarOverlapEarlier => 'Use the earlier occurrence';

  @override
  String get calendarOverlapLater => 'Use the later occurrence';

  @override
  String get calendarParticipantsLabel => 'Participants';

  @override
  String get calendarParticipantValidation =>
      'Choose at least one active household member.';

  @override
  String get calendarCancelAction => 'Cancel';

  @override
  String get calendarSaveAction => 'Save event';

  @override
  String get calendarDeleteTitle => 'Delete this event?';

  @override
  String calendarDeleteBody(String title) {
    return '“$title” will be removed from the household calendar.';
  }

  @override
  String get calendarDeleteConfirmAction => 'Delete';

  @override
  String get calendarOccurrenceCancelTitle => 'Cancel this occurrence?';

  @override
  String calendarOccurrenceCancelBody(String title) {
    return '“$title” will be cancelled only for this occurrence. The rest of the series will stay unchanged.';
  }

  @override
  String get calendarOccurrenceCancelConfirmAction => 'Cancel occurrence';

  @override
  String get calendarSeriesCancelTitle => 'End this recurring series?';

  @override
  String calendarSeriesCancelBody(String title) {
    return 'Today and future occurrences of “$title” will be cancelled. Past occurrences will stay in calendar history.';
  }

  @override
  String get calendarSeriesCancelConfirmAction => 'End series';

  @override
  String get calendarSeriesCancelFromOccurrenceTitle =>
      'End this and later occurrences?';

  @override
  String calendarSeriesCancelFromOccurrenceBody(String title) {
    return 'The selected recurrence of “$title” and every later recurrence will be cancelled. Earlier recurrences stay unchanged, even if one was moved to a later display date. Existing one-occurrence changes at or after this recurrence will also be cancelled.';
  }

  @override
  String get calendarSeriesCancelFromOccurrenceConfirmAction =>
      'End this and later';

  @override
  String get calendarSeriesCancelFromOccurrenceSucceeded =>
      'This and later occurrences were ended.';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoAction => 'Undo';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoSucceeded =>
      'The recurring calendar series was restored.';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoFailed =>
      'Could not restore the recurring calendar series. Try again.';

  @override
  String get calendarRosterError =>
      'Household participants could not be loaded. Try again.';

  @override
  String get calendarInvalidError => 'Check the event details and try again.';

  @override
  String get calendarPermissionError =>
      'This household, event, or participant is no longer available. Reload and try again.';

  @override
  String get calendarRetryConflictError =>
      'The event action changed during a retry. Reload and try again.';

  @override
  String get calendarVersionConflictError =>
      'This event changed elsewhere. Reload the latest calendar before trying again.';

  @override
  String get calendarNonexistentTimeError =>
      'That local time does not exist because the clock changes then. Choose another time.';

  @override
  String get calendarOccurrenceTransitionError =>
      'This occurrence can no longer be changed. Reload the latest calendar and try again.';

  @override
  String get calendarAgendaView => 'Agenda';

  @override
  String get calendarDayView => 'Day';

  @override
  String get calendarMonthView => 'Month';

  @override
  String get calendarPreviousRangeAction => 'Previous period';

  @override
  String get calendarNextRangeAction => 'Next period';

  @override
  String get calendarGoToTodayAction => 'Go to today';

  @override
  String calendarDateRange(String startDate, String endDate) {
    return '$startDate – $endDate';
  }

  @override
  String calendarSelectedDateHeading(String date) {
    return 'Events on $date';
  }

  @override
  String get calendarNoEventsInView => 'No events in this period.';

  @override
  String get calendarLoadMoreAction => 'Load more events';

  @override
  String get calendarLoadMoreError =>
      'More events could not be loaded. Try again.';

  @override
  String get calendarAllDayChip => 'All day';

  @override
  String get calendarRecurrenceLabel => 'Repeats';

  @override
  String get calendarRecurrenceOnce => 'Does not repeat';

  @override
  String get calendarRecurrenceDaily => 'Daily';

  @override
  String get calendarRecurrenceWeekly => 'Weekly';

  @override
  String get calendarRecurrenceMonthly => 'Monthly';

  @override
  String get calendarRecurrenceWeekdaysLabel => 'Repeat on';

  @override
  String get calendarRecurrenceWeekdayAnchorHelper =>
      'The event\'s start weekday stays selected.';

  @override
  String get calendarRecurrenceWeekdayMonday => 'Monday';

  @override
  String get calendarRecurrenceWeekdayTuesday => 'Tuesday';

  @override
  String get calendarRecurrenceWeekdayWednesday => 'Wednesday';

  @override
  String get calendarRecurrenceWeekdayThursday => 'Thursday';

  @override
  String get calendarRecurrenceWeekdayFriday => 'Friday';

  @override
  String get calendarRecurrenceWeekdaySaturday => 'Saturday';

  @override
  String get calendarRecurrenceWeekdaySunday => 'Sunday';

  @override
  String calendarRecurrenceWeekdaysSummary(String weekdays) {
    return 'On $weekdays.';
  }

  @override
  String calendarRecurrenceWeeklySummary(String pattern, String weekdays) {
    return 'Repeats $pattern on $weekdays';
  }

  @override
  String get calendarRecurrenceMonthDayLabel => 'Day of month';

  @override
  String calendarRecurrenceMonthDayOption(int day) {
    return 'Day $day';
  }

  @override
  String get calendarRecurrenceMonthDayAnchorHelper =>
      'The event\'s start date sets this day.';

  @override
  String get calendarRecurrenceMonthDayMissingDateHelper =>
      'Months without this date are skipped, not moved to the last day.';

  @override
  String calendarRecurrenceMonthDaySummary(int day) {
    return 'On day $day of the month.';
  }

  @override
  String calendarRecurrenceMonthlySummary(String pattern, int day) {
    return 'Repeats $pattern on day $day';
  }

  @override
  String get calendarRecurrenceIntervalLabel => 'Repeat interval';

  @override
  String get calendarRecurrenceIntervalHelper =>
      'Use a whole number from 1 to 30.';

  @override
  String get calendarRecurrenceIntervalValidation =>
      'Enter a number from 1 to 30.';

  @override
  String get calendarRecurrenceEndLabel => 'Ends';

  @override
  String get calendarRecurrenceEndNever => 'Never';

  @override
  String get calendarRecurrenceEndAfterCount => 'After a number of occurrences';

  @override
  String get calendarRecurrenceEndOnDate => 'On a date';

  @override
  String get calendarRecurrenceCountLabel => 'Number of occurrences';

  @override
  String get calendarRecurrenceCountHelper =>
      'Use a whole number from 1 to 1,000.';

  @override
  String get calendarRecurrenceCountValidation =>
      'Enter a number from 1 to 1,000.';

  @override
  String get calendarRecurrenceUntilDateLabel => 'Last occurrence date';

  @override
  String calendarRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Every $interval months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEditorSummary(String pattern, String startDate) {
    return '$pattern, starting $startDate.';
  }

  @override
  String get calendarRecurrenceInvalidSummary =>
      'Complete the supported recurrence values.';

  @override
  String get calendarRecurrenceEndNeverSummary =>
      'This series does not have an end date.';

  @override
  String calendarRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ends after $count occurrences.',
      one: 'Ends after 1 occurrence.',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEndUntilSummary(String date) {
    return 'Ends on $date.';
  }

  @override
  String calendarRecurrenceSummary(String pattern) {
    return 'Repeats $pattern';
  }

  @override
  String calendarMonthDateSemantics(String date, int count) {
    return '$date, $count events';
  }

  @override
  String get calendarGenericError =>
      'We couldn\'t load or save calendar events. It is safe to try again.';

  @override
  String get calendarTargetUnavailableTitle => 'Event unavailable';

  @override
  String get calendarTargetUnavailableMessage =>
      'This event was removed, cancelled, or is no longer available to this household.';

  @override
  String get calendarBackToCalendarAction => 'Open calendar';

  @override
  String get calendarLiveDisconnectedMessage =>
      'Live updates are paused. The last loaded calendar may be out of date.';

  @override
  String get calendarReconnectAction => 'Reconnect';

  @override
  String get choreLiveDisconnectedMessage =>
      'Live chore updates are paused. The last loaded chores may be out of date.';

  @override
  String get choreReconnectAction => 'Reconnect chore updates';

  @override
  String get notificationLiveDisconnectedMessage =>
      'Live notification updates are paused. The last loaded inbox and unread count may be out of date.';

  @override
  String get notificationReconnectAction => 'Reconnect notification updates';

  @override
  String get calendarConflictLatestReloadedMessage =>
      'This event changed elsewhere. The latest calendar is loaded; review it before trying again.';

  @override
  String get calendarConflictTargetUnavailableMessage =>
      'This event changed or was removed elsewhere. The latest calendar is loaded.';

  @override
  String get calendarScheduleOverlapHeading => 'Schedule overlap hint';

  @override
  String get calendarScheduleOverlapChecking =>
      'Checking this schedule against household events…';

  @override
  String get calendarScheduleOverlapNone =>
      'No same-member overlaps were found in the checked range.';

  @override
  String get calendarScheduleOverlapUnavailable =>
      'We couldn\'t check overlaps. You can still save, but review the household calendar first.';

  @override
  String get calendarScheduleOverlapSaveAllowed =>
      'This is a hint only. Saving remains available.';

  @override
  String calendarScheduleOverlapSummary(
    int total,
    int candidateCount,
    String fromDate,
    String throughDate,
  ) {
    return '$total overlaps across $candidateCount candidate occurrences checked from $fromDate through $throughDate.';
  }

  @override
  String calendarScheduleOverlapTruncated(int limit) {
    return 'Showing the first $limit overlaps.';
  }

  @override
  String calendarScheduleOverlapCandidateDate(String date) {
    return 'Candidate occurrence: $date';
  }

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationOpenAction => 'Open notifications';

  @override
  String get notificationLoadingLabel => 'Loading notifications';

  @override
  String get notificationInboxHeading => 'Inbox';

  @override
  String notificationUnreadBadge(int count) {
    return '$count unread';
  }

  @override
  String notificationBadgeSemantics(int count) {
    return '$count unread notifications';
  }

  @override
  String get notificationMarkAllReadAction => 'Mark all read';

  @override
  String get notificationEmptyTitle => 'You\'re all caught up';

  @override
  String get notificationEmptyBody =>
      'New chore and calendar reminders will appear here even when push delivery is unavailable.';

  @override
  String get notificationChoreDueLabel => 'Chore due update';

  @override
  String get notificationChoreAssignmentLabel => 'Chore assignment update';

  @override
  String get notificationCalendarEventLabel => 'Calendar event reminder';

  @override
  String get notificationItemBody =>
      'Open Today to securely load the latest authorized household details.';

  @override
  String notificationCreatedSchedule(String date, String time) {
    return 'Received $date · $time';
  }

  @override
  String get notificationSnoozeAction => 'Remind me again';

  @override
  String get notificationSnoozeSheetTitle => 'When should we remind you again?';

  @override
  String get notificationSnoozeSheetBody =>
      'The reminder will return to this inbox at the selected time and send another mobile push when enabled.';

  @override
  String notificationSnoozeMinutesAction(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'In $_temp0';
  }

  @override
  String notificationSnoozeSucceeded(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'We\'ll remind you again in $_temp0.';
  }

  @override
  String notificationSnoozeCount(int count) {
    return 'Snoozed $count of 3 times';
  }

  @override
  String get notificationOpenTodayAction => 'Open Today';

  @override
  String get notificationLoadMoreAction => 'Load more notifications';

  @override
  String get notificationLoadMoreError =>
      'More notifications could not be loaded. Try again.';

  @override
  String get notificationSettingsHeading => 'Notification settings';

  @override
  String get notificationSettingsBody =>
      'Choose each category and set quiet hours in your current IANA timezone. Quiet hours delay future push and email delivery, not this inbox.';

  @override
  String get notificationInAppLabel => 'In-app inbox';

  @override
  String get notificationInAppBody => 'Keep durable items in this inbox.';

  @override
  String get notificationNativePushLabel => 'Mobile push';

  @override
  String get notificationNativePushBody =>
      'Saved now; delivery starts after a device is registered.';

  @override
  String get notificationEmailLabel => 'Account email';

  @override
  String get notificationEmailBody =>
      'Send a generic reminder to your verified account email. No family details are included; this inbox remains available if delivery fails.';

  @override
  String get notificationQuietHoursLabel => 'Quiet hours';

  @override
  String notificationQuietHoursOff(String timezone) {
    return 'Off · $timezone';
  }

  @override
  String notificationQuietHoursSummary(
    String start,
    String end,
    String timezone,
  ) {
    return '$start–$end · $timezone';
  }

  @override
  String get notificationReminderLeadLabel => 'Remind me';

  @override
  String get notificationReminderLeadBody =>
      'Changes apply only to Calendar reminders that have not been delivered yet.';

  @override
  String get notificationReminderLeadAtStart => 'At event time';

  @override
  String notificationReminderLeadMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String get notificationAdditionalRemindersLabel => 'Additional reminders';

  @override
  String get notificationAdditionalRemindersBody =>
      'Choose up to 2 more times. Each reminder is delivered separately.';

  @override
  String get notificationEditAction => 'Edit';

  @override
  String notificationEditorTitle(String category) {
    return 'Edit $category';
  }

  @override
  String get notificationQuietEnabledLabel => 'Use quiet hours';

  @override
  String get notificationQuietStartLabel => 'Quiet starts';

  @override
  String get notificationQuietEndLabel => 'Quiet ends';

  @override
  String get notificationTimezoneLabel => 'IANA timezone';

  @override
  String get notificationTimezoneHint =>
      'Choose by IANA region or city, such as Asia/Seoul';

  @override
  String get notificationTimezonePickerTitle =>
      'Choose the notification timezone';

  @override
  String get notificationTimezoneValidation =>
      'Choose a valid IANA timezone and different quiet start and end times.';

  @override
  String get notificationSaveAction => 'Save settings';

  @override
  String get notificationCancelAction => 'Cancel';

  @override
  String get notificationInvalidInputError =>
      'Check the notification settings and try again.';

  @override
  String get notificationPermissionError =>
      'This notification inbox or household is no longer available. Reload your session.';

  @override
  String get notificationVersionConflictError =>
      'These settings changed elsewhere. Reload the latest settings and try again.';

  @override
  String get notificationSnoozeUnavailableError =>
      'This Calendar reminder can no longer be snoozed. Refresh the notification inbox.';

  @override
  String get notificationGenericError =>
      'We couldn\'t load or save notifications. It is safe to try again.';

  @override
  String get notificationPushPermissionHeading => 'Device notifications';

  @override
  String get notificationPushPrePromptBody =>
      'KinFlow sends generic reminders only. Names, chore details, and calendar details stay out of push messages, and this in-app inbox remains available.';

  @override
  String get notificationPushEnableAction => 'Enable device notifications';

  @override
  String get notificationPushDeniedBody =>
      'Device notifications are off. You can allow them in Android settings; this in-app inbox still works.';

  @override
  String get notificationPushOpenSettingsAction => 'Open Android settings';

  @override
  String get notificationPushAuthorizedBody =>
      'Device notifications are enabled for this household.';

  @override
  String get notificationPushUnavailableBody =>
      'Device notifications are unavailable in this build. This in-app inbox still works.';

  @override
  String get notificationPushSetupError =>
      'Device notification setup could not finish. Your in-app inbox is unaffected.';

  @override
  String get notificationPushPresentationTitle => 'KinFlow reminder';

  @override
  String get notificationPushPresentationBody =>
      'Open KinFlow to view the latest household update.';

  @override
  String get notificationPushChannelName => 'Household reminders';

  @override
  String get notificationPushChannelDescription =>
      'Generic household reminders without private details';

  @override
  String get featurePolicyUnavailableError =>
      'Feature limits are not available yet. Try again after the household plan refreshes.';

  @override
  String get featureLimitReachedError =>
      'This household has reached the current plan limit. Review the plan to continue.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsOpenAction => 'Open settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsHouseholdSwitchTitle => 'Switch household';

  @override
  String get settingsHouseholdSwitchSummary =>
      'View your households and choose which one is active.';

  @override
  String get householdSwitchTitle => 'Switch household';

  @override
  String get householdSwitchIntro =>
      'Only your own current memberships are shown. Switching reloads Today with the selected household.';

  @override
  String get householdSwitchLoading => 'Loading your households';

  @override
  String get householdSwitchEmpty =>
      'No available households were found for this account.';

  @override
  String get householdSwitchCurrentLabel => 'Current household';

  @override
  String get householdSwitchRoleOwner => 'Owner';

  @override
  String get householdSwitchRoleAdmin => 'Admin';

  @override
  String get householdSwitchRoleMember => 'Member';

  @override
  String get householdSwitchConfirmTitle => 'Switch active household?';

  @override
  String householdSwitchConfirmBody(String name) {
    return 'KinFlow will clear household-bound local data and reload Today for “$name”.';
  }

  @override
  String get householdSwitchConfirmAction => 'Switch household';

  @override
  String get householdSwitchInProgress => 'Switching household securely…';

  @override
  String get householdSwitchLoadError =>
      'Your household list could not be loaded. Try again.';

  @override
  String get householdSwitchTargetUnavailableError =>
      'That household is no longer available to this account. Refresh the list.';

  @override
  String get householdSwitchConflictError =>
      'Your active household changed elsewhere. Refresh the list before switching.';

  @override
  String get householdSwitchFeatureDisabledError =>
      'Household changes are temporarily paused. You can still view the current list.';

  @override
  String get householdSwitchLocalStateError =>
      'The server changed households, but this device could not safely clear local household data. Sign in again to recover.';

  @override
  String get householdSwitchGenericError =>
      'The household could not be switched safely. Refresh the list and try again.';

  @override
  String get settingsDeleteAccountTitle => 'Delete account';

  @override
  String get settingsDeleteAccountSummary =>
      'Review eligibility, request deletion, or cancel a pending request.';

  @override
  String get accountDeletionTitle => 'Delete account';

  @override
  String get accountDeletionLoadingLabel => 'Checking account deletion status';

  @override
  String get accountDeletionIntroHeading => 'What account deletion does';

  @override
  String get accountDeletionIntroBody =>
      'After the cancellation window, your profile, sign-in identity, personal notification settings, and device notification credentials are removed.';

  @override
  String get accountDeletionPreservedBody =>
      'Shared household, chore, and calendar history stays available to the remaining household members under a deleted-member label.';

  @override
  String get accountDeletionStatusHeading => 'Latest request';

  @override
  String get accountDeletionStatusQueued => 'Scheduled — you can still cancel';

  @override
  String get accountDeletionStatusVerifying =>
      'Verifying — you can still cancel';

  @override
  String get accountDeletionStatusProcessing =>
      'Deletion is being processed and can no longer be cancelled';

  @override
  String get accountDeletionStatusCompleted => 'Account deletion completed';

  @override
  String get accountDeletionStatusFailed =>
      'Account deletion needs another attempt';

  @override
  String get accountDeletionStatusCancelled => 'Account deletion cancelled';

  @override
  String accountDeletionScheduledFor(String date) {
    return 'Deletion begins after $date';
  }

  @override
  String accountDeletionCancellationWindow(int hours) {
    return 'A new request can be cancelled for about $hours hours.';
  }

  @override
  String get accountDeletionRequestAction => 'Request account deletion';

  @override
  String get accountDeletionCancelAction => 'Cancel deletion request';

  @override
  String get accountDeletionOwnerBlockTitle =>
      'Transfer household ownership first';

  @override
  String accountDeletionOwnerBlockBody(int count) {
    return 'You still own $count active household(s). Transfer each one to another adult before deleting your account.';
  }

  @override
  String get accountDeletionManageHouseholdsAction =>
      'Manage household members';

  @override
  String get accountDeletionSubscriptionTitle => 'Active subscription detected';

  @override
  String get accountDeletionSubscriptionBody =>
      'Deleting KinFlow does not cancel your App Store or Google Play subscription. Cancel it separately in the store if you no longer want it.';

  @override
  String get accountDeletionSubscriptionAcknowledge =>
      'I understand that account deletion does not cancel my store subscription.';

  @override
  String get accountDeletionPausedTitle =>
      'Deletion requests are temporarily paused';

  @override
  String get accountDeletionPausedBody =>
      'Your account remains active. Refresh later to check whether new requests are available.';

  @override
  String get accountDeletionConfirmTitle => 'Schedule account deletion?';

  @override
  String get accountDeletionConfirmBody =>
      'You will be signed out on this device immediately. Sign in again before the deadline if you need to cancel the request.';

  @override
  String get accountDeletionConfirmAction => 'Schedule deletion';

  @override
  String get accountDeletionConfirmCancelAction => 'Keep account';

  @override
  String get accountDeletionCancelConfirmTitle => 'Cancel account deletion?';

  @override
  String get accountDeletionCancelConfirmBody =>
      'Your account will remain active and this deletion request will not run.';

  @override
  String get accountDeletionCancelConfirmAction => 'Cancel deletion';

  @override
  String get accountDeletionPermissionError =>
      'This account deletion request is no longer available. Refresh your session.';

  @override
  String get accountDeletionRecentAuthError =>
      'Confirm your Google sign-in again before requesting account deletion.';

  @override
  String get accountDeletionRecentAuthCancelled =>
      'Account confirmation was cancelled. No deletion request was sent.';

  @override
  String get accountDeletionAccountChangedError =>
      'The confirmed Google account did not match this KinFlow account. No deletion request was sent.';

  @override
  String get accountDeletionOwnerTransferError =>
      'Transfer every household you own before requesting deletion.';

  @override
  String get accountDeletionSubscriptionError =>
      'Acknowledge the active store subscription notice before continuing.';

  @override
  String get accountDeletionPendingError =>
      'An account deletion request is already pending. Refresh to view it.';

  @override
  String get accountDeletionConflictError =>
      'This request changed elsewhere. Refresh its latest status before trying again.';

  @override
  String get accountDeletionPausedError =>
      'Account deletion requests are temporarily paused. Your account remains active.';

  @override
  String get accountDeletionGenericError =>
      'We couldn\'t load or update account deletion status. It is safe to try again.';

  @override
  String get settingsDataExportTitle => 'Download my data';

  @override
  String get settingsDataExportSummary =>
      'Create private JSON and readable text copies of your personal KinFlow data.';

  @override
  String get dataExportTitle => 'Download my data';

  @override
  String get dataExportLoadingLabel => 'Checking personal data export status';

  @override
  String get dataExportIntroHeading => 'Your personal KinFlow data';

  @override
  String get dataExportIntroBody =>
      'The export includes your profile, active memberships, items you authored, your participation and completion records, notification settings, and a provider-ID-free billing summary.';

  @override
  String get dataExportScopeBody =>
      'It does not include other household members\' profiles or a full shared-household archive. Household Owners will get that separate workflow later.';

  @override
  String dataExportRetentionBody(int hours, int minutes) {
    return 'Finished files expire after about $hours hours. Every download link works once and expires after $minutes minutes.';
  }

  @override
  String get dataExportStatusHeading => 'Latest export';

  @override
  String get dataExportStatusQueued => 'Export queued';

  @override
  String get dataExportStatusVerifying => 'Export is being verified';

  @override
  String get dataExportStatusProcessing => 'Creating private files';

  @override
  String get dataExportStatusCompleted => 'Personal export is ready';

  @override
  String get dataExportStatusFailed => 'This export could not be completed';

  @override
  String get dataExportStatusCancelled => 'Export request cancelled';

  @override
  String get dataExportRequestAction => 'Create personal export';

  @override
  String get dataExportCancelAction => 'Cancel export request';

  @override
  String get dataExportDownloadHeading => 'Private downloads';

  @override
  String get dataExportDownloadBody =>
      'Confirm your account again to create a new one-time link. The file opens in your browser or download app.';

  @override
  String get dataExportJsonAction => 'Download JSON';

  @override
  String get dataExportTextAction => 'Download readable text';

  @override
  String dataExportExpiresAt(String date) {
    return 'Files expire $date';
  }

  @override
  String dataExportFileSizes(String jsonSize, String textSize) {
    return 'JSON $jsonSize · Text $textSize';
  }

  @override
  String dataExportBytes(String count) {
    return '$count B';
  }

  @override
  String dataExportKilobytes(String count) {
    return '$count KB';
  }

  @override
  String dataExportMegabytes(String count) {
    return '$count MB';
  }

  @override
  String dataExportOpenedMessage(String format) {
    return 'The $format one-time download was opened. Request another link if you need the file again.';
  }

  @override
  String get dataExportJsonFormat => 'JSON';

  @override
  String get dataExportTextFormat => 'text';

  @override
  String get dataExportRevokeAction => 'Delete export files now';

  @override
  String get dataExportRevokedBody =>
      'These export files were revoked and are queued for permanent removal.';

  @override
  String get dataExportPurgedBody =>
      'These export files were permanently removed.';

  @override
  String get dataExportExpiredBody =>
      'These export files expired. Create a new export if you still need a copy.';

  @override
  String get dataExportRequestsPausedTitle =>
      'New exports are temporarily paused';

  @override
  String get dataExportRequestsPausedBody =>
      'Your data is unchanged. Refresh later to check whether a new export is available.';

  @override
  String get dataExportConflictingRequestBody =>
      'Another privacy request is in progress. Finish or cancel it before creating an export.';

  @override
  String get dataExportDownloadsPausedBody =>
      'Downloads are temporarily paused. Your completed file stays private until it expires or you delete it.';

  @override
  String get dataExportConfirmTitle => 'Create a personal export?';

  @override
  String get dataExportConfirmBody =>
      'You will confirm your Google account, then KinFlow will create private JSON and readable text files.';

  @override
  String get dataExportConfirmAction => 'Create export';

  @override
  String get dataExportDismissAction => 'Not now';

  @override
  String get dataExportCancelConfirmTitle => 'Cancel this export?';

  @override
  String get dataExportCancelConfirmBody =>
      'The queued job will stop and no download files will be created.';

  @override
  String get dataExportCancelConfirmAction => 'Cancel export';

  @override
  String get dataExportRevokeConfirmTitle => 'Delete these export files now?';

  @override
  String get dataExportRevokeConfirmBody =>
      'Every outstanding download link will stop working and the private files will be queued for permanent removal.';

  @override
  String get dataExportRevokeConfirmAction => 'Delete files';

  @override
  String get dataExportPermissionError =>
      'This export is no longer available to this account. Refresh your session.';

  @override
  String get dataExportRecentAuthError =>
      'Confirm your Google sign-in again before creating or downloading an export.';

  @override
  String get dataExportRecentAuthCancelled =>
      'Account confirmation was cancelled. No export action was sent.';

  @override
  String get dataExportAccountChangedError =>
      'The confirmed Google account did not match this KinFlow account. No export action was sent.';

  @override
  String get dataExportPendingError =>
      'Another privacy request is already pending. Refresh its latest status before trying again.';

  @override
  String get dataExportConflictError =>
      'This export changed elsewhere. Refresh the latest status before trying again.';

  @override
  String get dataExportPausedError =>
      'New personal exports are temporarily paused. Your data is unchanged.';

  @override
  String get dataExportDownloadsPausedError =>
      'Personal export downloads are temporarily paused. Try again later.';

  @override
  String get dataExportUnavailableError =>
      'This private export expired, was revoked, or is no longer available. Create a new export if needed.';

  @override
  String get dataExportTooLargeError =>
      'This account has more export data than one file can safely contain. Contact support for help.';

  @override
  String get dataExportLaunchError =>
      'The download app could not open. Request a new one-time link and try again.';

  @override
  String get dataExportGenericError =>
      'We couldn\'t load or update your personal export. It is safe to try again.';

  @override
  String get settingsHouseholdPrivacyTitle => 'Household data and deletion';

  @override
  String get settingsHouseholdPrivacySummary =>
      'Owners can export shared data or schedule household deletion';

  @override
  String get householdPrivacyTitle => 'Household data and deletion';

  @override
  String get householdPrivacyLoadingLabel =>
      'Checking Owner access and household privacy status…';

  @override
  String get householdPrivacyIntroHeading => 'Owner-only controls';

  @override
  String get householdPrivacyIntroBody =>
      'These controls affect shared household data and every current member. KinFlow checks current Owner access on the server for every action.';

  @override
  String householdPrivacyMemberCount(int count) {
    return 'Current members: $count';
  }

  @override
  String householdPrivacyExportRetention(int hours, int minutes) {
    return 'Export files expire after about $hours hours. Each one-time link lasts $minutes minutes.';
  }

  @override
  String householdPrivacyDeletionWindow(int hours) {
    return 'A deletion request can be cancelled for about $hours hours before background removal begins.';
  }

  @override
  String get householdPrivacyExportHeading => 'Export shared household data';

  @override
  String get householdPrivacyExportBody =>
      'Create private JSON and readable text files containing household metadata, members, chores, calendar data, and a provider-free billing summary.';

  @override
  String get householdPrivacyExportAction => 'Create household export';

  @override
  String get householdPrivacyDeleteHeading => 'Delete this household';

  @override
  String get householdPrivacyDeleteBody =>
      'Deletion permanently removes member access, redacts shared content, revokes invites, and unlinks billing access. Member accounts and Store subscriptions are not deleted or cancelled.';

  @override
  String get householdPrivacyDeleteAction => 'Schedule household deletion';

  @override
  String get householdPrivacySubscriptionWarning =>
      'This household has an active subscription assignment. Deleting the household does not cancel the Store subscription.';

  @override
  String get householdPrivacyStatusHeading =>
      'Latest household privacy request';

  @override
  String get householdPrivacyExportKind => 'Household export';

  @override
  String get householdPrivacyDeletionKind => 'Household deletion';

  @override
  String get householdPrivacyStatusQueued =>
      'Queued during the cancellation window';

  @override
  String get householdPrivacyStatusVerifying =>
      'Verifying current Owner and request conditions';

  @override
  String get householdPrivacyStatusProcessing =>
      'Background processing is in progress';

  @override
  String get householdPrivacyStatusCompleted => 'Request completed';

  @override
  String get householdPrivacyStatusFailed =>
      'The request could not be completed';

  @override
  String get householdPrivacyStatusCancelled => 'Request cancelled';

  @override
  String get householdPrivacyCancelAction => 'Cancel request';

  @override
  String get householdPrivacyDownloadHeading => 'Private household downloads';

  @override
  String get householdPrivacyDownloadBody =>
      'Each link works once. KinFlow does not keep the link in app state or storage.';

  @override
  String get householdPrivacyRevokeAction =>
      'Delete household export files now';

  @override
  String get householdPrivacyRetentionBlocked =>
      'Deletion is paused by a retention hold. Access is not removed while the hold is active.';

  @override
  String householdPrivacyRetentionReview(String date) {
    return 'Retention review: $date';
  }

  @override
  String householdPrivacyOpenedMessage(String format) {
    return 'The $format one-time household download opened.';
  }

  @override
  String get householdPrivacyExportConfirmTitle => 'Create a household export?';

  @override
  String get householdPrivacyExportConfirmBody =>
      'Confirm your Google account, then KinFlow will create private JSON and readable text files for this household.';

  @override
  String get householdPrivacyCancelConfirmTitle => 'Cancel this request?';

  @override
  String get householdPrivacyCancelConfirmBody =>
      'The queued request will stop. A request already being processed cannot be cancelled.';

  @override
  String get householdPrivacyRevokeConfirmTitle =>
      'Delete these household export files now?';

  @override
  String get householdPrivacyRevokeConfirmBody =>
      'Outstanding links will stop working and both private files will be queued for permanent removal.';

  @override
  String get householdPrivacyDeleteConfirmTitle =>
      'Permanently delete this household?';

  @override
  String get householdPrivacyDeleteConfirmBody =>
      'Type the exact household name and confirm every impact. You will then confirm your Google account.';

  @override
  String get householdPrivacyNameLabel => 'Household name';

  @override
  String householdPrivacyNameHint(String name) {
    return 'Type $name';
  }

  @override
  String get householdPrivacyMemberAccessAck =>
      'I understand every current member will lose access to this household.';

  @override
  String get householdPrivacyRedactionAck =>
      'I understand shared chores, calendar content, names, and endpoint material will be irreversibly redacted or removed.';

  @override
  String get householdPrivacySubscriptionAck =>
      'I understand this does not cancel the Store subscription, which must be managed separately.';

  @override
  String get householdPrivacyDeleteConfirmAction =>
      'Confirm and schedule deletion';

  @override
  String get householdPrivacyPermissionError =>
      'Only the current household Owner can use these controls. Refresh if ownership changed.';

  @override
  String get householdPrivacyRecentAuthError =>
      'Confirm the same Google account again before this sensitive household action.';

  @override
  String get householdPrivacyRecentAuthCancelled =>
      'Account confirmation was cancelled. No household action was sent.';

  @override
  String get householdPrivacyAccountChangedError =>
      'The confirmed Google account did not match this KinFlow account. No household action was sent.';

  @override
  String get householdPrivacyPausedError =>
      'This household privacy action is temporarily paused. Shared data is unchanged.';

  @override
  String get householdPrivacyPendingError =>
      'Another household privacy request is already in progress. Refresh its status first.';

  @override
  String get householdPrivacyConflictError =>
      'This household or request changed elsewhere. Refresh before trying again.';

  @override
  String get householdPrivacyConfirmationError =>
      'The typed household name no longer matches. Refresh and enter the current exact name.';

  @override
  String get householdPrivacySubscriptionAckError =>
      'Acknowledge that household deletion does not cancel the active Store subscription.';

  @override
  String get householdPrivacyArtifactError =>
      'This household export expired, was revoked, or is unavailable. Create a new export if needed.';

  @override
  String get householdPrivacyDeletedError =>
      'This household has already been deleted. Refresh to select or create another household.';

  @override
  String get householdPrivacyLaunchError =>
      'The download app could not open. Request a fresh one-time link and try again.';

  @override
  String get householdPrivacyGenericError =>
      'We couldn\'t load or update household privacy controls. It is safe to try again.';

  @override
  String get settingsProfilePreferencesTitle => 'Profile and regional settings';

  @override
  String get settingsProfilePreferencesSummary =>
      'Update your name, avatar, language, and timezones';

  @override
  String get profilePreferencesTitle => 'Profile and regional settings';

  @override
  String get profilePreferencesLoadingLabel =>
      'Loading your profile and household timezone…';

  @override
  String get profilePreferencesIntroHeading => 'Your minimal KinFlow profile';

  @override
  String get profilePreferencesIntroBody =>
      'Use a display name and optional built-in avatar. KinFlow does not require a legal name, birthday, or extra personal details.';

  @override
  String get profilePreferencesProfileHeading => 'Profile';

  @override
  String get profilePreferencesDisplayNameLabel => 'Display name';

  @override
  String get profilePreferencesDisplayNameValidation =>
      'Enter 1–80 visible characters.';

  @override
  String get profilePreferencesAvatarHeading => 'Built-in avatar';

  @override
  String get profilePreferencesAvatarNone => 'None';

  @override
  String get profilePreferencesAvatarSun => 'Sun';

  @override
  String get profilePreferencesAvatarHeart => 'Heart';

  @override
  String get profilePreferencesAvatarLeaf => 'Leaf';

  @override
  String get profilePreferencesAvatarStar => 'Star';

  @override
  String get profilePreferencesRegionalHeading =>
      'Language and personal timezone';

  @override
  String get timezonePreviewHeading => 'Current date and time preview';

  @override
  String get timezonePreviewBody =>
      'This preview uses your unsaved language and timezone choices. Refresh it to use a new current instant and offset snapshot.';

  @override
  String get timezonePreviewPersonalLabel => 'Personal preview';

  @override
  String get timezonePreviewHouseholdLabel => 'Household preview';

  @override
  String get timezonePreviewRefreshAction => 'Refresh date and time preview';

  @override
  String get timezonePreviewLoadingLabel =>
      'Preparing the current date and time preview…';

  @override
  String get timezonePreviewLoadFailure =>
      'The preview could not be refreshed. Your language and timezone choices have not changed.';

  @override
  String timezonePreviewMissingTimezone(String timezone) {
    return '$timezone is not in the bundled timezone list, so no device-time fallback is shown.';
  }

  @override
  String timezonePreviewSemantics(
    String label,
    String timezone,
    String date,
    String time,
    String metadata,
  ) {
    return '$label. $timezone. $date. $time. $metadata.';
  }

  @override
  String timezonePreviewUnavailableSemantics(String label, String timezone) {
    return '$label. Preview unavailable for $timezone.';
  }

  @override
  String get profilePreferencesLanguageLabel => 'App language';

  @override
  String get profilePreferencesLanguageEnglish => 'English';

  @override
  String get profilePreferencesLanguageKorean => '한국어';

  @override
  String get profilePreferencesPersonalTimezoneLabel => 'Personal timezone';

  @override
  String get profilePreferencesPersonalTimezoneHelper =>
      'Choose an IANA region or city. This becomes your personal default.';

  @override
  String get profilePreferencesPersonalTimezonePickerTitle =>
      'Choose your personal timezone';

  @override
  String get profilePreferencesTimezoneValidation =>
      'Choose a valid IANA timezone such as Asia/Seoul or UTC.';

  @override
  String get profilePreferencesHouseholdHeading => 'Household default timezone';

  @override
  String get profilePreferencesHouseholdTimezoneLabel => 'Household timezone';

  @override
  String get profilePreferencesHouseholdTimezoneHelper =>
      'Owner and Admin can choose the default used by household dates and newly created items.';

  @override
  String get profilePreferencesHouseholdTimezonePickerTitle =>
      'Choose the household timezone';

  @override
  String profilePreferencesHouseholdTimezoneReadOnly(String timezone) {
    return '$timezone · Only Owner or Admin can change this default.';
  }

  @override
  String get profilePreferencesImpactHeading =>
      'What a household timezone change means';

  @override
  String get profilePreferencesImpactBody =>
      'It changes the household-local Today boundary, defaults for new items, and notification preferences that still inherit the household default.';

  @override
  String get profilePreferencesImpactPreservedBody =>
      'Existing repeating chores and calendar series keep their saved timezone and occurrence instants.';

  @override
  String get profilePreferencesSaveAction =>
      'Save profile and regional settings';

  @override
  String get profilePreferencesSavedMessage =>
      'Profile and regional settings saved.';

  @override
  String get profilePreferencesConfirmTimezoneTitle =>
      'Change the household timezone?';

  @override
  String get profilePreferencesConfirmTimezoneBody =>
      'Today boundaries and new defaults will change immediately. Existing repeating items keep their saved timezone and instants.';

  @override
  String get profilePreferencesConfirmTimezoneAction =>
      'Change timezone and save';

  @override
  String get profilePreferencesCancelAction => 'Cancel';

  @override
  String get timezonePickerCloseAction => 'Close timezone picker';

  @override
  String get timezonePickerCurrentLabel => 'Current selection';

  @override
  String get timezonePickerSearchLabel => 'Search by region or city';

  @override
  String get timezonePickerSearchHelper => 'Try Seoul, New York, or Europe.';

  @override
  String get timezonePickerClearSearchAction => 'Clear timezone search';

  @override
  String get timezonePickerLoadingLabel => 'Loading the bundled timezone list…';

  @override
  String get timezonePickerLoadFailure =>
      'The timezone list could not be loaded. Your current selection has not changed.';

  @override
  String get timezonePickerEmptyLabel => 'No timezone matches this search.';

  @override
  String get timezonePickerDaylightSavingLabel => 'daylight saving now';

  @override
  String get timezonePickerStandardTimeLabel => 'standard time now';

  @override
  String timezonePickerMetadata(String offset, String clockKind) {
    return 'UTC$offset · $clockKind';
  }

  @override
  String get profilePreferencesErrorUnauthenticated =>
      'Sign in again before loading or changing this profile.';

  @override
  String get profilePreferencesErrorInvalidInput =>
      'Check the display name, avatar, language, and IANA timezone values.';

  @override
  String get profilePreferencesErrorUnavailable =>
      'This profile or active household is no longer available. Refresh your session.';

  @override
  String get profilePreferencesErrorForbidden =>
      'Only the current Owner or Admin can change the household timezone. Your personal changes were not saved.';

  @override
  String get profilePreferencesErrorProfileConflict =>
      'Your profile changed elsewhere. Reload the latest version before saving again.';

  @override
  String get profilePreferencesErrorHouseholdConflict =>
      'The household timezone changed elsewhere. Reload the latest version before saving again.';

  @override
  String get profilePreferencesErrorTemporarilyUnavailable =>
      'Profile settings are temporarily unavailable. Your previous values remain unchanged.';

  @override
  String get profilePreferencesErrorInvalidPayload =>
      'KinFlow received an unexpected settings response and did not apply it.';

  @override
  String get profilePreferencesErrorInternal =>
      'We couldn\'t load or save these settings. It is safe to try again.';

  @override
  String get settingsSubscriptionTitle => 'Subscription and Plus';

  @override
  String get settingsSubscriptionSummary =>
      'Check this household\'s plan, purchase or restore Plus, and manage billing';

  @override
  String get subscriptionTitle => 'Subscription and Plus';

  @override
  String get subscriptionLoading =>
      'Loading the server-confirmed subscription status…';

  @override
  String get subscriptionHouseholdFallback => 'Active household';

  @override
  String get subscriptionStatusHeading => 'Current household subscription';

  @override
  String get subscriptionHouseholdLabel => 'Household';

  @override
  String get subscriptionPlanLabel => 'Plan';

  @override
  String get subscriptionLifecycleLabel => 'Status';

  @override
  String get subscriptionSourceLabel => 'Billing source';

  @override
  String get subscriptionBillingOwnerLabel => 'Billing owner';

  @override
  String get subscriptionBillingOwnerNone => 'No billing owner';

  @override
  String get subscriptionPeriodLabel => 'Billing period';

  @override
  String get subscriptionVerifiedLabel => 'Server verified';

  @override
  String get subscriptionPlanFree => 'Free';

  @override
  String get subscriptionPlanPlus => 'Plus';

  @override
  String get subscriptionStatusNone => 'No active Plus subscription';

  @override
  String get subscriptionStatusTrialing => 'Trial active';

  @override
  String get subscriptionStatusActive => 'Active';

  @override
  String get subscriptionStatusGrace => 'Payment retry grace period';

  @override
  String get subscriptionStatusBillingIssue => 'Billing needs attention';

  @override
  String get subscriptionStatusExpired => 'Expired';

  @override
  String get subscriptionStatusRevoked => 'Revoked or refunded';

  @override
  String get subscriptionSourceNone => 'None';

  @override
  String get subscriptionSourcePlayStore => 'Google Play';

  @override
  String get subscriptionSourceAppStore => 'Apple App Store';

  @override
  String get subscriptionSourceWeb => 'Web billing';

  @override
  String get subscriptionSourceSupport => 'KinFlow support';

  @override
  String get subscriptionBillingOwnerYou => 'You manage this subscription';

  @override
  String get subscriptionBillingOwnerOther =>
      'Another household member manages it';

  @override
  String subscriptionRenewsOn(String date) {
    return 'Renews on $date';
  }

  @override
  String subscriptionAccessThrough(String date) {
    return 'Current access through $date';
  }

  @override
  String get subscriptionNoPeriodEnd => 'No period end reported';

  @override
  String subscriptionVerifiedAt(String date) {
    return 'Checked $date';
  }

  @override
  String get subscriptionLifecycleTrialing =>
      'Your Plus trial is active. The Store may renew it unless you cancel there.';

  @override
  String get subscriptionLifecycleGrace =>
      'Plus remains available while the Store retries payment. Review the payment method in the Store.';

  @override
  String get subscriptionLifecycleBillingIssue =>
      'The Store reported a billing problem. Existing data remains safe; review billing in the Store.';

  @override
  String get subscriptionLifecycleExpired =>
      'Plus access ended. Existing household data is preserved, but new Free-plan limits apply.';

  @override
  String get subscriptionLifecycleRevoked =>
      'Plus access was revoked or refunded. Existing household data is preserved, but new Free-plan limits apply.';

  @override
  String get subscriptionBenefitsHeading => 'Plus benefits';

  @override
  String get subscriptionBenefitMembers => 'More room for household members';

  @override
  String get subscriptionBenefitRecurring =>
      'More active recurring chore and calendar series';

  @override
  String get subscriptionBenefitData =>
      'Existing household data stays preserved if Plus ends';

  @override
  String get subscriptionLimitsPending =>
      'Final prices and limits come from the Store and server. No unconfirmed numeric limit is shown here.';

  @override
  String get subscriptionOffersHeading => 'Choose a Store option';

  @override
  String subscriptionPackagePrice(String price, String period) {
    return '$price · $period';
  }

  @override
  String subscriptionPeriodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count days',
      one: 'every day',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count weeks',
      one: 'every week',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count months',
      one: 'every month',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'every $count years',
      one: 'every year',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPurchaseAction => 'Continue to Store purchase';

  @override
  String get subscriptionRestoreAction => 'Restore Store purchases';

  @override
  String get subscriptionManageAction => 'Manage subscription in Store';

  @override
  String get subscriptionRefreshAction => 'Refresh server status';

  @override
  String get subscriptionReturnAction => 'Back to subscription options';

  @override
  String get subscriptionSupportAction => 'Contact support';

  @override
  String get subscriptionTermsAction => 'Terms';

  @override
  String get subscriptionPrivacyAction => 'Privacy';

  @override
  String get subscriptionAdminRequired =>
      'Only an active household Owner or Admin can purchase or restore Plus. You can still view the current status.';

  @override
  String get subscriptionProfileUnavailable =>
      'KinFlow could not verify your active household role. Refresh profile settings before purchasing or restoring.';

  @override
  String get subscriptionStoreUnavailable =>
      'Store options are unavailable right now. The server-confirmed household status is still shown above.';

  @override
  String get subscriptionPurchaseConfirmTitle =>
      'Confirm this household purchase';

  @override
  String subscriptionPurchaseConfirmBody(
    String household,
    String price,
    String period,
  ) {
    return 'Buy Plus for $household at the Store price $price, billed $period?';
  }

  @override
  String get subscriptionPurchaseConfirmRenewal =>
      'The Store may renew and charge this subscription until the billing owner cancels it there.';

  @override
  String get subscriptionPurchaseConfirmServer =>
      'Store success is not final access. KinFlow waits for server confirmation before enabling Plus.';

  @override
  String get subscriptionPurchaseConfirmAction => 'Confirm and open Store';

  @override
  String get subscriptionRestoreConfirmTitle =>
      'Restore purchases for this household?';

  @override
  String subscriptionRestoreConfirmBody(String household) {
    return 'KinFlow will check Store purchases for $household. It will never transfer a subscription from another household automatically.';
  }

  @override
  String get subscriptionRestoreConfirmConflict =>
      'If a purchase is assigned elsewhere, KinFlow stops and offers a support request without exposing billing identifiers.';

  @override
  String get subscriptionRestoreConfirmAction => 'Confirm restore';

  @override
  String get subscriptionCancelAction => 'Cancel';

  @override
  String get subscriptionPreparingPurchase =>
      'Checking that this subscription can be safely assigned before opening the Store…';

  @override
  String get subscriptionPreparingRestore =>
      'Checking that restored purchases can be safely assigned to this household…';

  @override
  String get subscriptionPurchasing => 'Waiting for the Store purchase result…';

  @override
  String get subscriptionRestoring => 'Checking purchases with the Store…';

  @override
  String get subscriptionStorePending =>
      'The Store is still processing this request. Purchase and restore controls stay paused to prevent duplicates.';

  @override
  String get subscriptionServerPending =>
      'The Store responded, but KinFlow has not received authoritative server confirmation yet. Refresh status; do not purchase again.';

  @override
  String get subscriptionRestoreEmptyTitle => 'No restorable purchase found';

  @override
  String get subscriptionRestoreEmptyBody =>
      'The Store did not return a Plus purchase for this account. No household subscription changed.';

  @override
  String get subscriptionConflictTitle =>
      'Subscription assignment needs review';

  @override
  String get subscriptionConflictBody =>
      'KinFlow stopped before contacting the Store because this purchase or household is already linked elsewhere. No billing identifier is displayed.';

  @override
  String get subscriptionRestoreConflictBody =>
      'The Store found a purchase, but KinFlow could not safely assign it to this household. No access or ownership changed.';

  @override
  String get subscriptionRemediationAction => 'Request assignment review';

  @override
  String get subscriptionRemediationSubmitted =>
      'An assignment review request is open. Support can investigate without billing identifiers appearing here.';

  @override
  String get subscriptionRemediationFailed =>
      'The review request could not be sent. No Store action occurred; contact support if this continues.';

  @override
  String get subscriptionNoticePurchaseCancelled =>
      'The Store purchase was cancelled. Nothing was charged by KinFlow and the household plan did not change.';

  @override
  String get subscriptionNoticeAlreadyActive =>
      'Server-confirmed Plus is already active for this household.';

  @override
  String get subscriptionNoticePurchaseConfirmed =>
      'The server confirmed the purchase and updated this household\'s Plus status.';

  @override
  String get subscriptionNoticeRestoreConfirmed =>
      'The server confirmed the restored purchase for this household.';

  @override
  String get subscriptionNoticeServerRefreshed =>
      'The latest server-confirmed subscription status is shown.';

  @override
  String get subscriptionExternalUnavailable =>
      'That trusted external page could not be opened. Try again or use the Store app directly.';

  @override
  String get subscriptionFailureUnsupported =>
      'Store billing is not available on this device. You can still view the server-confirmed status.';

  @override
  String get subscriptionFailureUnauthenticated =>
      'Sign in again before loading or changing subscription status.';

  @override
  String get subscriptionFailureIdentity =>
      'KinFlow could not safely bind or clear the Store account. Sign out and back in before trying again.';

  @override
  String get subscriptionFailureInvalidInput =>
      'The active household or Store option changed. Refresh before continuing.';

  @override
  String get subscriptionFailureCatalog =>
      'Store options could not be loaded. The server-confirmed status remains available.';

  @override
  String get subscriptionFailureStore =>
      'The Store could not complete this request. Check the Store app and refresh server status before retrying.';

  @override
  String get subscriptionFailureNetwork =>
      'The network is unavailable. No new subscription status was assumed; refresh when connected.';

  @override
  String get subscriptionFailureAuthorization =>
      'The server refused this subscription action for the current account or household.';

  @override
  String get subscriptionFailureServer =>
      'The server could not confirm this request. Do not purchase again; refresh status first.';

  @override
  String get subscriptionFailureInvalidState =>
      'KinFlow received an unexpected subscription state and did not enable Plus.';

  @override
  String get subscriptionFailureUnknown =>
      'The subscription request could not be completed safely. Refresh status before trying another action.';

  @override
  String get settingsHelpSection => 'Help and legal';

  @override
  String get settingsLegalSupportTitle => 'Legal, privacy, and support';

  @override
  String get settingsLegalSupportSummary =>
      'Review published documents, manage privacy requests, or contact support.';

  @override
  String get legalSupportTitle => 'Legal, privacy, and support';

  @override
  String get legalSupportIntro =>
      'Use this hub to review KinFlow\'s published documents, reach support, and find your privacy controls.';

  @override
  String get legalSupportDocumentVersionTitle => 'Published document versions';

  @override
  String get legalSupportDocumentVersionBody =>
      'The publication date and version shown on each linked document are authoritative. The app\'s technical contract version is not a legal policy version.';

  @override
  String get legalSupportTermsTitle => 'Terms of service';

  @override
  String get legalSupportTermsBody =>
      'Review the current terms for using KinFlow, including account, household, and service responsibilities.';

  @override
  String get legalSupportTermsVersionNote =>
      'Opens the fixed terms page in your browser. Check that page for its publication date and version.';

  @override
  String get legalSupportTermsOpenAction => 'Open terms of service';

  @override
  String get legalSupportPrivacyTitle => 'Privacy policy';

  @override
  String get legalSupportPrivacyBody =>
      'Review how KinFlow handles account, household, device, notification, and subscription-related data.';

  @override
  String get legalSupportPrivacyVersionNote =>
      'Opens the fixed privacy page in your browser. Check that page for its publication date and version.';

  @override
  String get legalSupportPrivacyOpenAction => 'Open privacy policy';

  @override
  String get legalSupportPrivacyControlsTitle => 'Your privacy controls';

  @override
  String get legalSupportPrivacyControlsBody =>
      'Create private copies of your data or review the separate account deletion process without leaving KinFlow.';

  @override
  String get legalSupportSupportTitle => 'Support';

  @override
  String get legalSupportSupportBody =>
      'Open KinFlow\'s configured support page for product, account, household, or subscription help.';

  @override
  String get legalSupportSupportPrivacyNote =>
      'KinFlow does not automatically attach your account, household, billing, or diagnostic identifiers to this link.';

  @override
  String get legalSupportSupportOpenAction => 'Open support';

  @override
  String get legalSupportConsentTitle => 'Consent on this screen';

  @override
  String get legalSupportConsentBody =>
      'Opening or reading these resources does not grant or withdraw consent. If a specific policy version ever requires a decision, KinFlow will ask separately and record only that explicit choice.';

  @override
  String get legalSupportTermsResourceName => 'terms of service';

  @override
  String get legalSupportPrivacyResourceName => 'privacy policy';

  @override
  String get legalSupportSupportResourceName => 'support';

  @override
  String legalSupportOpening(String resource) {
    return 'Opening $resource in your browser…';
  }

  @override
  String legalSupportOpened(String resource) {
    return 'Opened $resource in your browser.';
  }

  @override
  String get legalSupportExternalUnavailable =>
      'That trusted page could not be opened. Check your connection or browser and try again.';

  @override
  String get settingsAnalyticsPrivacyTitle => 'Analytics and data collection';

  @override
  String get settingsAnalyticsPrivacySummary =>
      'Review optional usage analytics, collection limits, and SDK purposes.';

  @override
  String get analyticsPrivacyTitle => 'Analytics and data collection';

  @override
  String get analyticsPrivacyLoading =>
      'Loading the privacy-safe analytics preference…';

  @override
  String get analyticsPrivacyLoadFailed =>
      'The analytics preference could not be loaded safely. Optional usage analytics remains off. Try again.';

  @override
  String get analyticsPrivacyIntroTitle => 'A minimal, optional usage signal';

  @override
  String get analyticsPrivacyIntroBody =>
      'This device setting controls optional, content-free usage events. It is separate from operational error reporting and is off by default.';

  @override
  String get analyticsPrivacyPreferenceTitle =>
      'Allow optional usage analytics';

  @override
  String get analyticsPrivacyPreferenceBody =>
      'This choice applies only to analytics-usage-v1 on this device and environment. A provider, purpose, field, or policy expansion requires a new choice.';

  @override
  String get analyticsPrivacyStatusOff =>
      'Off. Optional usage events are not sent.';

  @override
  String get analyticsPrivacyStatusAvailable =>
      'Allowed. Only the approved content-free event envelope may reach the configured sink.';

  @override
  String get analyticsPrivacyStatusNoSink =>
      'Choice saved, but no external behavioral analytics sink is installed, so nothing is sent.';

  @override
  String get analyticsPrivacySaving =>
      'Saving the device analytics preference…';

  @override
  String get analyticsPrivacySaveFailed =>
      'The preference could not be saved. The previous choice remains in effect and no raw error was retained.';

  @override
  String get analyticsPrivacySaved =>
      'The device analytics preference was saved.';

  @override
  String get analyticsPrivacyAllowlistTitle => 'Exact event boundary';

  @override
  String get analyticsPrivacyAllowlistBody =>
      'KinFlow accepts only six typed product events and a five-field public build envelope. Free-form event names and attributes are rejected by the application boundary.';

  @override
  String get analyticsPrivacyChildPolicyTitle => 'Managed Child protection';

  @override
  String get analyticsPrivacyChildPolicyBody =>
      'Managed Child mode is not part of the adult-only Store MVP. If added later, optional analytics is blocked before preference storage or any sink is accessed.';

  @override
  String get analyticsPrivacyInventoryTitle =>
      'Current data-handling SDK inventory';

  @override
  String get analyticsPrivacyInventoryBehavioral =>
      'Behavioral analytics and advertising: no external SDK installed.';

  @override
  String get analyticsPrivacyInventoryOperational =>
      'Sentry: privacy-filtered crashes and operational errors only; it is not the optional usage analytics sink.';

  @override
  String get analyticsPrivacyInventoryNotifications =>
      'Firebase Messaging and local notifications: notification transport and display only.';

  @override
  String get analyticsPrivacyInventoryBilling =>
      'RevenueCat: Store purchase and entitlement processing only.';

  @override
  String get analyticsPrivacyInventoryIdentity =>
      'Google Sign-In and Supabase: authentication and app data services, not behavioral analytics.';

  @override
  String get analyticsPrivacyNeverCollectedTitle =>
      'Never included in optional analytics';

  @override
  String get analyticsPrivacyNeverCollectedBody =>
      'No account, household, member or child identifiers; email, names or family content; tokens, receipts, URLs or raw errors; location, contacts, advertising IDs or device fingerprints.';

  @override
  String get settingsDiagnosticsTitle => 'Diagnostic information';

  @override
  String get settingsDiagnosticsSummary =>
      'Review and copy a PII-free app, build, platform, and incident report.';

  @override
  String get diagnosticsTitle => 'Diagnostic information';

  @override
  String get diagnosticsIntroHeading => 'A local support reference';

  @override
  String get diagnosticsIntroBody =>
      'KinFlow creates this report on your device and does not upload its contents. A random incident ID may be recorded in PII-filtered app diagnostics so support can correlate an issue. Copy the report only when you choose to share it.';

  @override
  String get diagnosticsIncludedTitle => 'Included information';

  @override
  String get diagnosticsIncludedBody =>
      'App ID, app version, build number, dev or prod environment, API contract date, broad platform category, random incident ID, and UTC creation time.';

  @override
  String get diagnosticsExcludedTitle => 'Never included';

  @override
  String get diagnosticsExcludedBody =>
      'No account, household, profile, email, chores, calendar, notifications, billing content, credentials, network data, device model, serial number, advertising ID, locale, or timezone.';

  @override
  String get diagnosticsLoading =>
      'Creating a local PII-free diagnostic report…';

  @override
  String get diagnosticsUnavailable =>
      'Diagnostic information is temporarily unavailable. No partial report was copied or uploaded.';

  @override
  String get diagnosticsInvalidMetadata =>
      'The installed app metadata does not match this configured build, so KinFlow refused to create a partial or misleading report.';

  @override
  String get diagnosticsInternal =>
      'The diagnostic report could not be created safely. No partial report was copied or uploaded.';

  @override
  String get diagnosticsReportTitle => 'Report preview';

  @override
  String get diagnosticsApplicationIdLabel => 'Application ID';

  @override
  String get diagnosticsAppVersionLabel => 'App version';

  @override
  String get diagnosticsBuildNumberLabel => 'Build number';

  @override
  String get diagnosticsEnvironmentLabel => 'Environment';

  @override
  String get diagnosticsContractVersionLabel => 'API contract date';

  @override
  String get diagnosticsDevicePlatformLabel => 'Broad platform category';

  @override
  String get diagnosticsIncidentIdLabel => 'Incident ID';

  @override
  String get diagnosticsGeneratedAtLabel => 'Created at (UTC)';

  @override
  String get diagnosticsClipboardNotice =>
      'Copying writes this JSON report to the system clipboard without reading its existing contents. Paste it only into a trusted support request, then clear it if your device or keyboard keeps clipboard history.';

  @override
  String get diagnosticsCopyAction => 'Copy diagnostic information';

  @override
  String get diagnosticsNewIncidentAction => 'Create a new incident ID';

  @override
  String get diagnosticsRefreshing =>
      'Creating a new local report while keeping the current report available…';

  @override
  String get diagnosticsCopying =>
      'Writing the PII-free JSON report to the system clipboard…';

  @override
  String get diagnosticsCopied =>
      'Diagnostic information was copied. The report contents were not uploaded automatically.';

  @override
  String get diagnosticsCopyFailed =>
      'The system clipboard could not be written. The report remains visible and its contents were not uploaded.';

  @override
  String get diagnosticsRefreshFailed =>
      'A new incident ID could not be created. The previous report remains unchanged.';

  @override
  String get householdActivationTitle => 'Get the household started together';

  @override
  String get householdActivationBody =>
      'Finish these four milestones to establish a shared household routine.';

  @override
  String get householdActivationCompleteBody =>
      'Your household completed all four getting-started milestones.';

  @override
  String get householdActivationLoadingLabel =>
      'Refreshing household getting-started progress';

  @override
  String householdActivationSummary(int completed, int total) {
    return '$completed of $total milestones complete';
  }

  @override
  String get householdActivationAdultTitle => 'Invite a second adult';

  @override
  String householdActivationAdultProgress(int current, int goal) {
    return '$current of $goal adults have joined this household.';
  }

  @override
  String get householdActivationInviteAction => 'Invite an adult';

  @override
  String get householdActivationChoreTitle => 'Create three chores';

  @override
  String householdActivationChoreProgress(int current, int goal) {
    return '$current of $goal chores have been created.';
  }

  @override
  String get householdActivationCreateAction => 'Add a chore';

  @override
  String get householdActivationCompletionTitle => 'Complete one chore each';

  @override
  String householdActivationCompletionProgress(int current, int goal) {
    return '$current of $goal adults have completed at least one chore.';
  }

  @override
  String get householdActivationReturnTitle => 'Come back on another day';

  @override
  String get householdActivationReturnPending =>
      'Open Today again after the household\'s first local date has passed.';

  @override
  String get householdActivationReturnComplete =>
      'Today was opened after the household\'s first local date.';

  @override
  String get householdActivationStepComplete => 'Complete';

  @override
  String get householdActivationUnavailableBody =>
      'Getting-started progress is unavailable. Today\'s chores and events still work, and you can retry this card.';

  @override
  String get householdActivationReadOnlyBody =>
      'Invite and chore actions are unavailable while Today is showing saved data.';

  @override
  String get weeklyReportTitle => 'Household weekly recap';

  @override
  String get weeklyReportOpenAction => 'Open household weekly recap';

  @override
  String get weeklyReportLoading => 'Loading household weekly recap…';

  @override
  String get weeklyReportRefreshing => 'Refreshing household weekly recap…';

  @override
  String get weeklyReportUnavailableTitle => 'Weekly recap unavailable';

  @override
  String get weeklyReportUnavailableBody =>
      'Today\'s chores still work. Try this recap again when you\'re ready.';

  @override
  String weeklyReportWeekRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get weeklyReportLatestWeek => 'Latest closed week';

  @override
  String weeklyReportSummary(int completed, int due) {
    return '$completed of $due due chores completed';
  }

  @override
  String weeklyReportCardSummary(int completed, int due) {
    return '$completed of $due due chores completed by the end of the week';
  }

  @override
  String get weeklyReportEmpty => 'No chores were due or skipped this week.';

  @override
  String weeklyReportByWeekEndRate(int percent) {
    return '$percent% completed by the end of the week';
  }

  @override
  String weeklyReportCompletedByWeekEnd(int count) {
    return '$count completed by the end of the week';
  }

  @override
  String weeklyReportCompletedLater(int count) {
    return '$count completed later';
  }

  @override
  String weeklyReportStillOpen(int count) {
    return '$count still open';
  }

  @override
  String weeklyReportSkipped(int count) {
    return '$count skipped';
  }

  @override
  String weeklyReportYourContribution(int count) {
    return 'You completed $count';
  }

  @override
  String get weeklyReportBreakdownTitle => 'Contributions';

  @override
  String weeklyReportMemberContribution(String name, int count) {
    return '$name: $count completed';
  }

  @override
  String weeklyReportMemberByWeekEnd(int count) {
    return '$count by the end of the week';
  }

  @override
  String weeklyReportOtherContribution(int count) {
    return 'Other or former members: $count completed';
  }

  @override
  String get weeklyReportTruncatedNotice =>
      'Showing up to 20 current household members. Remaining contributions are combined above.';

  @override
  String get weeklyReportOlderWeek => 'Older week';

  @override
  String get weeklyReportNewerWeek => 'Newer week';

  @override
  String get runtimePolicyUnavailableTitle =>
      'Service status couldn\'t be verified';

  @override
  String get runtimePolicyUnavailableBody =>
      'Saved information remains available. Online changes may be unavailable until this check succeeds.';

  @override
  String get runtimePolicyReadOnlyTitle => 'KinFlow is temporarily read-only';

  @override
  String get runtimePolicyReadOnlyBody =>
      'You can still view information and use export, deletion, legal, support, and diagnostics. Other changes are paused.';

  @override
  String get runtimePolicyUpdateTitle =>
      'Update required before making changes';

  @override
  String runtimePolicyUpdateBody(String version) {
    return 'Update KinFlow to version $version or later. Reading, export, deletion, legal, support, and diagnostics remain available.';
  }

  @override
  String get runtimePolicyUpdateAction => 'Open Play Store';

  @override
  String get runtimePolicyUpdateUnavailable =>
      'The Play Store couldn\'t be opened. Try again or update KinFlow directly in the Store app.';

  @override
  String get runtimePolicyFeatureDisabledTitle =>
      'Some changes are temporarily paused';

  @override
  String runtimePolicyFeatureDisabledBody(String features) {
    return 'Paused: $features. Other features, reading, export, deletion, legal, support, and diagnostics remain available.';
  }

  @override
  String get runtimePolicyFeatureHousehold => 'Household';

  @override
  String get runtimePolicyFeatureChores => 'Chores';

  @override
  String get runtimePolicyFeatureCalendar => 'Calendar';

  @override
  String get runtimePolicyFeatureNotifications => 'Notifications';

  @override
  String get runtimePolicyFeatureProfile => 'Profile';

  @override
  String get runtimePolicyFeatureBilling => 'Billing';

  @override
  String get choreTrashTitle => 'Recently deleted chores';

  @override
  String get choreTrashOpenAction => 'Open recently deleted chores';

  @override
  String get choreTrashTodayAction => 'Back to Today';

  @override
  String get choreTrashLoading => 'Loading recently deleted chores…';

  @override
  String get choreTrashEmptyTitle => 'No recently deleted chores';

  @override
  String get choreTrashEmptyBody =>
      'Deleted one-time chores will appear here so an adult can restore them.';

  @override
  String get choreTrashRefreshFailed =>
      'Recently deleted chores could not be refreshed. The current list is still shown.';

  @override
  String choreTrashDeletedAt(String date, String time) {
    return 'Deleted $date at $time';
  }

  @override
  String choreTrashDueDate(String date) {
    return 'Due $date';
  }

  @override
  String choreTrashDueDateTime(String date, String time) {
    return 'Due $date at $time';
  }

  @override
  String choreTrashAssignee(String name) {
    return 'Assigned to $name';
  }

  @override
  String get choreTrashRestoreAction => 'Restore chore';

  @override
  String get choreTrashRestoringAction => 'Restoring…';

  @override
  String get choreTrashRestoreSucceeded => 'The one-time chore was restored.';

  @override
  String get choreTrashLoadMoreAction => 'Load more deleted chores';

  @override
  String get choreTrashLoadMoreFailed =>
      'More deleted chores could not be loaded.';

  @override
  String get choreDeleteUndoAction => 'Undo';

  @override
  String get choreRestoreOneTimeSucceeded => 'The deleted chore was restored.';

  @override
  String get choreRestoreOneTimeFailed =>
      'The deleted chore could not be restored. Try again from Recently deleted chores.';

  @override
  String get settingsDeviceCapabilitiesTitle => 'Device capability status';

  @override
  String get settingsDeviceCapabilitiesSummary =>
      'Review support, setup needs, and safe fallbacks for this device.';

  @override
  String get platformCapabilitiesTitle => 'Device capability status';

  @override
  String get platformCapabilitiesIntroTitle =>
      'How KinFlow works on this device';

  @override
  String get platformCapabilitiesIntroBody =>
      'This local snapshot shows the Android integrations selected by this app build and the current notification permission state. It does not test provider or server connectivity.';

  @override
  String get platformCapabilitiesPrivacyNote =>
      'No account, household, device, payment, configuration, or provider error details are included or uploaded from this screen.';

  @override
  String get platformCapabilitiesSelfCheckTitle =>
      'Capability self-check and recovery plan';

  @override
  String get platformCapabilitiesSelfCheckBody =>
      'Review what is ready first, then follow the ordered recovery steps for anything that needs attention or a fallback.';

  @override
  String platformCapabilitiesReadyCount(int count) {
    return '$count ready';
  }

  @override
  String platformCapabilitiesAttentionCount(int count) {
    return '$count need attention';
  }

  @override
  String platformCapabilitiesAlternativeCount(int count) {
    return '$count use a fallback or limitation';
  }

  @override
  String get platformCapabilitiesRecoveryHeading =>
      'Recommended recovery order';

  @override
  String get platformCapabilitiesRecoveryEmpty =>
      'All primary capabilities are ready. Safe fallbacks still remain available when needed.';

  @override
  String platformCapabilitiesRecoveryStep(int number) {
    return 'Step $number';
  }

  @override
  String get platformCapabilitiesSelfCheckAction =>
      'Recheck notification setup';

  @override
  String get platformCapabilitiesSelfCheckRefreshing =>
      'Checking notification setup…';

  @override
  String get platformCapabilitiesSelfCheckScope =>
      'This action does not request permission or open system settings. The existing notification coordinator may safely clean up or restore the device binding when the current permission changed.';

  @override
  String get platformCapabilitiesSelfCheckSucceeded =>
      'Notification permission and device binding status were checked again.';

  @override
  String get platformCapabilitiesSelfCheckFailed =>
      'Notification setup could not be checked right now. The inbox and the listed safe fallbacks remain available.';

  @override
  String get platformCapabilitiesProviderLabel => 'Selected integration';

  @override
  String get platformCapabilitiesFallbackLabel => 'Safe fallback';

  @override
  String get platformCapabilitiesNotificationTitle => 'Notification delivery';

  @override
  String get platformCapabilitiesBillingTitle => 'Google Play billing';

  @override
  String get platformCapabilitiesSecureStorageTitle =>
      'Encrypted local storage';

  @override
  String get platformCapabilitiesExternalLinksTitle =>
      'External links and downloads';

  @override
  String get platformCapabilitiesBackgroundTitle => 'Background delivery';

  @override
  String get platformCapabilitiesStateAvailable => 'Supported';

  @override
  String get platformCapabilitiesStateActionRequired => 'Action needed';

  @override
  String get platformCapabilitiesStateLimited => 'Limited by design';

  @override
  String get platformCapabilitiesStateFallbackOnly => 'Using fallback';

  @override
  String get platformCapabilitiesStateTemporaryIssue => 'Temporary issue';

  @override
  String get platformCapabilitiesProviderFirebaseMessaging =>
      'Firebase Messaging for Android';

  @override
  String get platformCapabilitiesProviderRevenueCatPlay =>
      'RevenueCat with Google Play';

  @override
  String get platformCapabilitiesProviderAndroidKeystore =>
      'Android Keystore-backed storage';

  @override
  String get platformCapabilitiesProviderAndroidUriLauncher =>
      'Android system link handler';

  @override
  String get platformCapabilitiesProviderBrowserUriLauncher =>
      'Browser trusted link handler';

  @override
  String get platformCapabilitiesProviderFirebaseBackground =>
      'Firebase Android background handler';

  @override
  String get platformCapabilitiesProviderUnavailable =>
      'Not configured in this app build';

  @override
  String get platformCapabilitiesFallbackInbox =>
      'Durable in-app notification inbox';

  @override
  String get platformCapabilitiesFallbackInboxAndEmail =>
      'Durable in-app inbox and configured generic email';

  @override
  String get platformCapabilitiesFallbackEntitlement =>
      'Server-confirmed entitlement and read-only subscription status';

  @override
  String get platformCapabilitiesFallbackReauthentication =>
      'Re-authentication without persistent offline data';

  @override
  String get platformCapabilitiesFallbackGuidance =>
      'On-screen guidance and local diagnostics';

  @override
  String get platformCapabilitiesFallbackServerNotifications =>
      'Server notification processing and the in-app inbox';

  @override
  String get platformCapabilitiesNotificationAvailable =>
      'Android push is supported. Important events also remain available in Notifications.';

  @override
  String get platformCapabilitiesNotificationNotDetermined =>
      'A notification choice has not been made yet. Choose it in Notifications; the inbox still works.';

  @override
  String get platformCapabilitiesNotificationDenied =>
      'System notifications are turned off for KinFlow. You can review the choice in Notifications; the inbox still works.';

  @override
  String get platformCapabilitiesNotificationRuntimeUnavailable =>
      'Android notification delivery is unavailable on this runtime. Important events remain in the inbox.';

  @override
  String get platformCapabilitiesNotificationTemporary =>
      'The notification adapter reported a temporary local problem. Existing inbox content remains available.';

  @override
  String get platformCapabilitiesNotificationNotConfigured =>
      'Push delivery is not configured in this app build. Important events remain in the inbox.';

  @override
  String get platformCapabilitiesBillingAvailable =>
      'Google Play purchasing is supported. Household access still follows the server-confirmed entitlement.';

  @override
  String get platformCapabilitiesBillingNotConfigured =>
      'Store purchasing is unavailable in this app build. Existing server-confirmed access and subscription details remain readable.';

  @override
  String get platformCapabilitiesSecureStorageAvailable =>
      'Sensitive session and supported offline snapshots use Android encrypted storage.';

  @override
  String get platformCapabilitiesSecureStorageNotConfigured =>
      'Persistent encrypted offline data is unavailable. KinFlow falls back to re-authentication and fresh online reads.';

  @override
  String get platformCapabilitiesExternalLinksAvailable =>
      'Trusted support, policy, Store, and export links can use the Android system handler.';

  @override
  String get platformCapabilitiesExternalLinksNotConfigured =>
      'External link handling is unavailable in this app build. On-screen guidance and diagnostics remain available.';

  @override
  String get platformCapabilitiesBackgroundLimited =>
      'Android can receive background push entry events, while the server pipeline remains the delivery source of truth.';

  @override
  String get platformCapabilitiesBackgroundNotConfigured =>
      'Client background delivery is not configured. Server processing and the in-app inbox remain the fallback.';

  @override
  String get platformCapabilitiesSafeUnknownState =>
      'This capability state is unavailable. Use the named fallback and local diagnostics.';

  @override
  String get platformCapabilitiesOpenNotificationsAction =>
      'Open Notifications';

  @override
  String get platformCapabilitiesOpenSubscriptionAction =>
      'Open subscription settings';

  @override
  String get platformCapabilitiesOpenDiagnosticsAction => 'Open diagnostics';
}

/// The translations for English (`en_XA`).
class AppLocalizationsEnXa extends AppLocalizationsEn {
  AppLocalizationsEnXa() : super('en_XA');

  @override
  String get appTitle => '[!! ĶîñFłôŵ adaptive preview !!]';

  @override
  String get developmentBanner => '[!! ĐĒVĒŁÔPMĒÑŢ !!]';

  @override
  String get startupLoadingLabel => '[!! Šţåŕţîñĝ ĶîñFłôŵ — please wait !!]';

  @override
  String get startupErrorTitle => '[!! ĶîñFłôŵ çôûłđ ñôţ šţåŕţ correctly !!]';

  @override
  String get startupErrorBody =>
      '[!! Płēåšē ţŕŷ åĝåîñ. Îƒ ţĥē pŕôɓłēm çôñţîñûēš, fully restart the application. !!]';

  @override
  String get authLoadingLabel =>
      '[!! Çĥēçķîñĝ ŷôûŕ secure authentication session !!]';

  @override
  String get authSignInTitle =>
      '[!! Šîĝñ îñ ţô ĶîñFłôŵ with your adult account !!]';

  @override
  String get authSignInBody =>
      '[!! Ûšē å complete one-time code delivered securely to your email, or continue with an adult Ĝôôĝłē account across every adaptive layout. !!]';

  @override
  String get authGoogleSignInAction => '[!! Çôñţîñûē ŵîţĥ Ĝôôĝłē account !!]';

  @override
  String get authGoogleSignInHint =>
      '[!! Šîĝñš îñ ŵîţĥ åñ åđûłţ Ĝôôĝłē account from every supported adaptive layout !!]';

  @override
  String get authSigningInLabel => '[!! Çôññēçţîñĝ securely ţô Ĝôôĝłē !!]';

  @override
  String get authProviderUnavailableBody =>
      '[!! Ĝôôĝłē sign-in is temporarily unavailable across every supported adaptive layout. Please try again after some time. !!]';

  @override
  String get authIdentityConflictTitle =>
      '[!! Ţĥîš Ĝôôĝłē account cannot be connected automatically or silently merged across any adaptive layout !!]';

  @override
  String get authIdentityConflictBody =>
      '[!! ĶîñFłôŵ did not merge any accounts. Choose a different Ĝôôĝłē account, or open the trusted support page if you believe this account should already work securely. !!]';

  @override
  String get authIdentityChooseAnotherAction =>
      '[!! Çĥôôšē åñôţĥēŕ Ĝôôĝłē account securely !!]';

  @override
  String get authIdentityChooseAnotherHint =>
      '[!! Opens the complete Ĝôôĝłē account selection again without silently linking or merging identities !!]';

  @override
  String get authIdentitySupportAction =>
      '[!! Ôpēñ ţĥē ţŕûšţēđ support page !!]';

  @override
  String get authIdentitySupportOpening =>
      '[!! Ôpēñîñĝ ţĥē ţŕûšţēđ support page securely !!]';

  @override
  String get authIdentitySupportOpened =>
      '[!! The trusted support page opened safely outside ĶîñFłôŵ. !!]';

  @override
  String get authIdentitySupportUnavailable =>
      '[!! The trusted support page could not be opened safely. Please try again after some time. !!]';

  @override
  String get authEmailSectionLabel =>
      '[!! Çôñţîñûē securely ŵîţĥ ēmåîł across every adaptive layout !!]';

  @override
  String get authEmailLabel => '[!! Çômpłēţē åđûłţ ēmåîł åđđŕēšš !!]';

  @override
  String get authEmailHint =>
      '[!! Ŵē ŵîłł send a complete six-digit one-time code. If needed, this securely creates a new adult ĶîñFłôŵ account. !!]';

  @override
  String get authEmailSendCodeAction =>
      '[!! Šēñđ ţĥē secure sign-in code now !!]';

  @override
  String get authEmailSendingCodeAction =>
      '[!! Šēñđîñĝ ţĥē secure code now !!]';

  @override
  String authEmailCodeSentBody(String maskedEmail) {
    return '[!! If $maskedEmail can be used securely, we sent a complete six-digit code. Carefully check the inbox and spam folder. !!]';
  }

  @override
  String get authEmailCodeLifetimeBody =>
      '[!! Ţĥē newest complete code expires in ten minutes. You may request another secure code after sixty seconds. !!]';

  @override
  String get authEmailCodeLabel => '[!! Complete six-digit one-time code !!]';

  @override
  String get authEmailCodeHint =>
      '[!! Ēñţēŕ åłł six digits from the newest secure email message. !!]';

  @override
  String get authEmailVerifyAction =>
      '[!! Vēŕîƒŷ ţĥē code and continue securely !!]';

  @override
  String get authEmailVerifyingAction =>
      '[!! Vēŕîƒŷîñĝ ţĥē complete code securely !!]';

  @override
  String get authEmailResendAction =>
      '[!! Šēñđ å completely new secure code !!]';

  @override
  String get authEmailResendingAction =>
      '[!! Šēñđîñĝ å completely new secure code now !!]';

  @override
  String get authEmailChangeAction =>
      '[!! Ûšē å different complete email address !!]';

  @override
  String get authEmailSigningInLabel =>
      '[!! Çôđē verified securely. Finishing the complete sign-in and household handoff now. !!]';

  @override
  String get authEmailInvalidEmailError =>
      '[!! Ēñţēŕ å valid complete adult email address. !!]';

  @override
  String get authEmailInvalidCodeError =>
      '[!! Ēñţēŕ ţĥē newest valid complete six-digit code. !!]';

  @override
  String get authEmailExpiredError =>
      '[!! Ţĥîš secure code expired. Send a completely new code to continue. !!]';

  @override
  String get authEmailAlreadyUsedError =>
      '[!! Ţĥîš one-time code has already been used securely. !!]';

  @override
  String get authEmailRateLimitedError =>
      '[!! Płēåšē wait before requesting or checking another complete secure code. !!]';

  @override
  String get authEmailTemporarilyUnavailableError =>
      '[!! Ēmåîł sign-in is temporarily unavailable across this adaptive layout. Please try again later. !!]';

  @override
  String get authSessionExpiredBody =>
      '[!! Your secure session expired or was revoked. Please sign in again. !!]';

  @override
  String get authLocalStateLockedBody =>
      '[!! ĶîñFłôŵ locked access because local data could not be cleared safely. Fully restart the app and complete the secure recovery flow before trying again across every adaptive layout. !!]';

  @override
  String get authLogoutAction => '[!! Šîĝñ ôûţ securely !!]';

  @override
  String get householdLookupErrorTitle =>
      '[!! Ŵē çôûłđ ñôţ safely łôåđ ŷôûŕ complete shared household information !!]';

  @override
  String get householdLookupErrorBody =>
      '[!! Çĥēçķ ŷôûŕ network connection and try the secure household lookup again. Your shared household data has not been changed anywhere. !!]';

  @override
  String get householdOnboardingTitle =>
      '[!! Šēţ ûp ŷôûŕ complete shared household securely !!]';

  @override
  String get householdOnboardingHeading =>
      '[!! Çŕēåţē å šĥåŕēđ family home together !!]';

  @override
  String get householdOnboardingBody =>
      '[!! Åđđ ŷôûŕ complete adult display name and a clear name for this shared household. You will securely become the Owner across every adaptive layout. !!]';

  @override
  String get householdAdditionalSettingsTitle => '[!! Åđđîţîôñåł šēţţîñĝš !!]';

  @override
  String get householdAdditionalSettingsBody =>
      '[!! Ŕēvîēŵ ôŕ çĥåñĝē ţĥē complete preferred language and ÎÅÑÅ timezone before creating this shared household. !!]';

  @override
  String get ownerDisplayNameLabel =>
      '[!! Ŷôûŕ åđûłţ display name for the household !!]';

  @override
  String get householdNameLabel => '[!! Šĥåŕēđ household display name !!]';

  @override
  String get householdNameValidation =>
      '[!! Ēñţēŕ between 1 and 80 readable characters without any hidden control characters. !!]';

  @override
  String get householdLocaleLabel => '[!! Pŕēƒēŕŕēđ application language !!]';

  @override
  String get householdTimezoneLabel => '[!! Šĥåŕēđ household timezone !!]';

  @override
  String get householdTimezoneHint =>
      '[!! Carefully choose a complete ÎÅÑÅ region or city such as Asia/Seoul for every shared household schedule. !!]';

  @override
  String get householdTimezonePickerTitle =>
      '[!! Carefully choose the complete shared household timezone now !!]';

  @override
  String get householdTimezoneValidation =>
      '[!! Carefully choose a valid complete ÎÅÑÅ timezone name. !!]';

  @override
  String get householdCreateAction =>
      '[!! Çŕēåţē ţĥîš shared household securely !!]';

  @override
  String get householdCreatingAction =>
      '[!! Çŕēåţîñĝ ţĥē shared household securely now !!]';

  @override
  String get householdInvalidInputError =>
      '[!! Çĥēçķ every highlighted household detail carefully and then try the secure request again. !!]';

  @override
  String get householdAlreadyExistsError =>
      '[!! Ţĥîš adult account already has an active household. Reload the complete household information securely to continue across every adaptive layout. !!]';

  @override
  String get householdRequestConflictError =>
      '[!! Ţĥēšē household details changed during a safe retry. Review every detail carefully and submit a fresh request again. !!]';

  @override
  String get householdCreateError =>
      '[!! Ŵē çôûłđ ñôţ safely create the shared household right now. Your complete request remains safe to retry without duplication. !!]';

  @override
  String get todayInviteAction =>
      '[!! Îñvîţē åñôţĥēŕ åđûłţ ţô ţĥîš šĥåŕēđ ĥôûšēĥôłđ !!]';

  @override
  String get inviteCreateTitle =>
      '[!! Îñvîţē šômēôñē ţô ŷôûŕ complete shared household securely !!]';

  @override
  String get inviteCreateHeading =>
      '[!! Bŕîñĝ åñôţĥēŕ åđûłţ îñţô ĶîñFłôŵ together !!]';

  @override
  String get inviteCreateBody =>
      '[!! Çŕēåţē å seven-day secure invitation link and a shorter twenty-four-hour companion code. You may restrict the complete invitation to exactly one adult email address. !!]';

  @override
  String get inviteEmailLabel =>
      '[!! Ŕēçîpîēñţ åđûłţ ēmåîł address — optional !!]';

  @override
  String get inviteEmailHint =>
      '[!! Ţĥē signed-in adult account must exactly match this protected email address before joining. !!]';

  @override
  String get inviteCreateAction =>
      '[!! Çŕēåţē ţĥē complete secure invitation !!]';

  @override
  String get inviteCreatingAction =>
      '[!! Çŕēåţîñĝ ţĥē secure household invitation now !!]';

  @override
  String get inviteLinkHeading =>
      '[!! Ŷôûŕ complete secure one-time invitation îš ready !!]';

  @override
  String get inviteLinkBody =>
      '[!! Šĥåŕē ţĥîš sensitive link only with the intended adult. ĶîñFłôŵ will never show the raw token again after this complete screen closes. !!]';

  @override
  String get inviteCodeHeading =>
      '[!! Ţŵēñţŷ-ƒôûŕ-hour secure invitation code !!]';

  @override
  String get inviteCodeBody =>
      '[!! Šĥåŕē this sensitive code only with the intended adult. It expires sooner than the link and is never shown again after this screen closes. !!]';

  @override
  String get inviteCodeCopyAction => '[!! Çôpŷ ţĥē secure invitation code !!]';

  @override
  String get inviteCodeCopiedBody =>
      '[!! Secure invitation code copied successfully. !!]';

  @override
  String get inviteCopyAction => '[!! Çôpŷ ţĥē complete invitation link !!]';

  @override
  String get inviteCopiedBody =>
      '[!! Secure invitation link copied successfully. !!]';

  @override
  String get inviteShareAction =>
      '[!! Šĥåŕē ţĥē complete secure invitation link !!]';

  @override
  String get inviteShareChooserTitle =>
      '[!! Šĥåŕē ţĥē ĶîñFłôŵ secure invitation carefully !!]';

  @override
  String get inviteShareOpeningBody =>
      '[!! Carefully opening the native sharing sheet without claiming delivery… !!]';

  @override
  String get inviteShareOpenedBody =>
      '[!! The complete sharing sheet opened. Carefully confirm the intended adult before sending because ĶîñFłôŵ cannot confirm delivery. !!]';

  @override
  String get inviteShareUnavailableBody =>
      '[!! The complete sharing sheet is unavailable. Use Copy link below and send it only to the intended adult securely. !!]';

  @override
  String get inviteShareFailedBody =>
      '[!! Sharing stopped completely and safely. Use Copy link below or carefully try the complete Share link again securely. !!]';

  @override
  String get inviteCopyingBody =>
      '[!! Explicitly writing the complete secure invitation to the system clipboard… !!]';

  @override
  String get inviteCopyFailedBody =>
      '[!! The secure invitation could not be copied. Select the complete value above manually or carefully try again. !!]';

  @override
  String get inviteClipboardNotice =>
      '[!! Explicit copying places this sensitive single-use invitation on the system clipboard. Send it only to the intended adult, then carefully clear clipboard history if the device or keyboard retains it across every secure adaptive device. !!]';

  @override
  String get inviteTokenUnavailableBody =>
      '[!! Ţĥîš retry remains safe, but the one-time link can no longer be shown. Revoke this invitation and create a fresh secure link. !!]';

  @override
  String get inviteRevokeAction => '[!! Ŕēvôķē ţĥîš invitation securely !!]';

  @override
  String get inviteRevokingAction =>
      '[!! Ŕēvôķîñĝ ţĥē invitation securely now !!]';

  @override
  String get inviteNewAction =>
      '[!! Çŕēåţē åñôţĥēŕ fresh secure invitation !!]';

  @override
  String get inviteOpenTitle => '[!! Šēçûŕē shared household invitation !!]';

  @override
  String get inviteLoadingLabel =>
      '[!! Çĥēçķîñĝ ţĥîš complete household invitation securely !!]';

  @override
  String get inviteMissingTitle =>
      '[!! Ţĥîš household invitation îš unavailable !!]';

  @override
  String get inviteMissingBody =>
      '[!! Ôpēñ ţĥē original secure invitation link again or ask the sender for a completely new one. !!]';

  @override
  String get inviteCodeEntryTitle => '[!! Ēñţēŕ å secure invitation code !!]';

  @override
  String get inviteCodeEntryBody =>
      '[!! Ēñţēŕ the eight-character code from the household owner. Checking and accepting the complete invitation requires an internet connection across every adaptive screen size. !!]';

  @override
  String get inviteCodeLabel => '[!! Secure invitation code !!]';

  @override
  String get inviteCodeHint => '[!! ABCD-EFGH !!]';

  @override
  String get inviteCodeValidation =>
      '[!! Ēñţēŕ å valid eight-character secure invitation code. !!]';

  @override
  String get inviteCodeSubmitAction =>
      '[!! Çĥēçķ ţĥē complete invitation securely !!]';

  @override
  String get inviteEnterCodeAction => '[!! Ēñţēŕ å secure invitation code !!]';

  @override
  String get inviteAnotherCodeAction => '[!! Ţŕŷ åñôţĥēŕ secure code !!]';

  @override
  String invitePreviewSentence(String inviterName, String householdName) {
    return '[!! $inviterName invited you to join the complete shared household named $householdName. !!]';
  }

  @override
  String get inviteRoleMember => '[!! Šĥåŕēđ household adult member role !!]';

  @override
  String get inviteRoleAdmin =>
      '[!! Šĥåŕēđ household adult administrator role !!]';

  @override
  String inviteExpiryLabel(String expiresAt) {
    return '[!! Ţĥîš secure invitation expires at $expiresAt !!]';
  }

  @override
  String get inviteSignInBody =>
      '[!! Šîĝñ îñ with the adult account that should join this household. This sensitive invitation remains only in protected ephemeral memory throughout sign-in. !!]';

  @override
  String get inviteSignInAction =>
      '[!! Šîĝñ îñ securely ţô accept this invitation !!]';

  @override
  String get inviteSwitchTitle =>
      '[!! Šŵîţçĥ ţĥē currently active household now? !!]';

  @override
  String get inviteSwitchBody =>
      '[!! Ŷôû already have an active household. Joining keeps both memberships and explicitly switches ĶîñFłôŵ to this newly accepted household across every adaptive layout. !!]';

  @override
  String get inviteSwitchConfirmation =>
      '[!! Î explicitly want to join and switch to this complete shared household now. !!]';

  @override
  String get inviteAcceptAction =>
      '[!! Åççēpţ ţĥîš secure household invitation !!]';

  @override
  String get inviteAcceptingAction =>
      '[!! Ĵôîñîñĝ ţĥē shared household securely now !!]';

  @override
  String get inviteAcceptedBody =>
      '[!! Ŷôû joined the shared household successfully. Opening the complete Today view now… !!]';

  @override
  String get inviteInvalidError =>
      '[!! Ţĥîš secure invitation is invalid or no longer available. !!]';

  @override
  String get inviteExpiredError =>
      '[!! Ţĥîš invitation expired. Ask the sender for a completely new secure link. !!]';

  @override
  String get inviteRevokedError =>
      '[!! Ţĥîš invitation was revoked. Ask the sender for a completely new secure link. !!]';

  @override
  String get inviteAlreadyUsedError =>
      '[!! Ţĥîš single-use invitation has already been accepted by an adult. !!]';

  @override
  String get inviteEmailMismatchError =>
      '[!! Šîĝñ îñ with the exact adult email address this protected invitation was created for. !!]';

  @override
  String get inviteRateLimitedError =>
      '[!! Ţôô many invitation attempts occurred. Wait several minutes and safely try again. !!]';

  @override
  String get invitePermissionError =>
      '[!! Ôñłŷ ţĥē household Owner or an adult Admin can securely manage invitations. !!]';

  @override
  String get inviteGenericError =>
      '[!! Ŵē çôûłđ ñôţ complete the secure invitation request. The same request remains safe to try again. !!]';

  @override
  String get todayMembersAction =>
      '[!! Måñåĝē åłł šĥåŕēđ ĥôûšēĥôłđ mēmbēŕš !!]';

  @override
  String get membersTitle => '[!! Šĥåŕēđ ĥôûšēĥôłđ mēmbēŕš åñđ ŕôłēš !!]';

  @override
  String get membersLoadingLabel =>
      '[!! Łôåđîñĝ åłł secure household members now !!]';

  @override
  String membersHeading(String householdName) {
    return '[!! Complete members of the shared household $householdName !!]';
  }

  @override
  String get membersBody =>
      '[!! Ŕēvîēŵ åñđ måñåĝē every active adult member and role. Every protected change is completed securely online. !!]';

  @override
  String get membersYouLabel => '[!! Ŷôûŕ account !!]';

  @override
  String get membersRoleOwner => '[!! Ĥôûšēĥôłđ Ôŵñēŕ !!]';

  @override
  String get membersRoleAdmin => '[!! Ĥôûšēĥôłđ Åđmîñ !!]';

  @override
  String get membersRoleMember => '[!! Ĥôûšēĥôłđ Mēmbēŕ !!]';

  @override
  String membersMenuTooltip(String memberName) {
    return '[!! Secure actions available for member $memberName !!]';
  }

  @override
  String get memberPromoteAdminAction =>
      '[!! Çĥåñĝē ţĥîš member securely ţô Åđmîñ !!]';

  @override
  String get memberDemoteMemberAction =>
      '[!! Çĥåñĝē ţĥîš administrator ţô Mēmbēŕ !!]';

  @override
  String get memberTransferOwnerAction =>
      '[!! Ţŕåñšƒēŕ household Ôŵñēŕ responsibility !!]';

  @override
  String get memberRemoveAction =>
      '[!! Ŕēmôvē this adult from the complete household !!]';

  @override
  String get householdLeaveAction =>
      '[!! Łēåvē ţĥîš complete shared household !!]';

  @override
  String get memberRoleChangeTitle =>
      '[!! Çĥåñĝē ţĥîš protected household role now? !!]';

  @override
  String memberRoleChangeBody(String memberName, String role) {
    return '[!! Change $memberName to $role. Ĝôôĝłē will ask you to verify your identity securely once more before the change continues. !!]';
  }

  @override
  String get memberRemoveTitle => '[!! Ŕēmôvē ţĥîš household member now? !!]';

  @override
  String memberRemoveBody(String memberName) {
    return '[!! $memberName will immediately lose access to this complete household, and every unused invitation they created will be revoked securely. !!]';
  }

  @override
  String get ownerTransferTitle =>
      '[!! Ţŕåñšƒēŕ complete household ownership now? !!]';

  @override
  String ownerTransferBody(String memberName) {
    return '[!! $memberName will become the new Ôŵñēŕ and you will become an Åđmîñ. Ĝôôĝłē will ask you to verify your identity securely. No household role changes until this secure confirmation succeeds completely. !!]';
  }

  @override
  String get householdLeaveTitle =>
      '[!! Łēåvē ţĥîš complete shared household now? !!]';

  @override
  String get householdLeaveBody =>
      '[!! Your membership and access end immediately. Every shared historical record remains safely with the household. You can only return after another active adult sends a completely new invitation. !!]';

  @override
  String get ownerMustTransferBody =>
      '[!! Ţĥē Ôŵñēŕ must securely transfer ownership to another adult before leaving this shared household. !!]';

  @override
  String get memberActionInProgress =>
      '[!! Çômpłēţîñĝ ţĥîš protected household change securely now !!]';

  @override
  String get memberCancelAction => '[!! Çåñçēł without changing anything !!]';

  @override
  String get memberConfirmAction => '[!! Çôñţîñûē securely !!]';

  @override
  String get membersLoadError =>
      '[!! We could not load every household member safely. Check the network connection and try again. !!]';

  @override
  String get membersPermissionError =>
      '[!! You do not have permission to perform this protected household member action. !!]';

  @override
  String get membersVersionConflictError =>
      '[!! Member information changed somewhere else. Reload the complete roster and try again. !!]';

  @override
  String get membersOwnerTransferRequiredError =>
      '[!! The final Ôŵñēŕ cannot be removed or leave. Transfer ownership to another adult first. !!]';

  @override
  String get membersRecentAuthError =>
      '[!! This protected change needs a recent Ĝôôĝłē identity check. Please try again securely. !!]';

  @override
  String get membersRecentAuthCancelled =>
      '[!! You cancelled the Ĝôôĝłē identity check. No household information was changed anywhere. Try again whenever you are ready. !!]';

  @override
  String get membersAccountChangedError =>
      '[!! A different Ĝôôĝłē account was selected, so the protected change stopped. Check the current account carefully. Return and select the original signed-in account. !!]';

  @override
  String get membersGenericError =>
      '[!! We could not complete this member change. The same protected request remains safe to retry. Nothing was partially applied. !!]';

  @override
  String get todayTitle => '[!! Ţôđåŷ schedule !!]';

  @override
  String get todayEmptyTitle =>
      '[!! Ñôţĥîñĝ îš currently scheduled for today in this shared household !!]';

  @override
  String get todayEmptyBody =>
      '[!! Ŷôûŕ shared household is completely ready. New chores and shared calendar events will appear safely in this complete Today view whenever they are added. !!]';

  @override
  String get todayLoadingLabel =>
      '[!! Łôåđîñĝ åłł ôƒ ţôđåŷ\'š household chores securely now !!]';

  @override
  String get todayCreateChoreAction =>
      '[!! Åđđ ţĥē very first shared household chore !!]';

  @override
  String get todayCreateAnotherChoreAction =>
      '[!! Åđđ åñôţĥēŕ shared household chore now !!]';

  @override
  String todayChoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! $count complete household chores belong to Today !!]',
      one: '[!! 1 complete household chore belongs to Today !!]',
    );
    return '$_temp0';
  }

  @override
  String todayChoreMetadata(String assigneeName, String dueLabel) {
    return '[!! Assigned securely to $assigneeName · due $dueLabel !!]';
  }

  @override
  String get todayCalendarSectionTitle =>
      '[!! Ţôđåŷ\'š complete shared household calendar events !!]';

  @override
  String get todayOverdueSectionTitle =>
      '[!! Every overdue shared household chore requiring attention !!]';

  @override
  String get todayNowAndNextSectionTitle =>
      '[!! Happening now and coming next in the complete household schedule !!]';

  @override
  String get todayChoresSectionTitle =>
      '[!! Ţôđåŷ\'š complete shared household chores !!]';

  @override
  String get todayRemainingEventsSectionTitle =>
      '[!! Every remaining shared household event scheduled throughout Today !!]';

  @override
  String get todayCompletedSectionTitle =>
      '[!! Shared household chores completed for Today !!]';

  @override
  String get todayCompletedExpandAction =>
      '[!! Show every completed household chore for Today !!]';

  @override
  String get todayCompletedCollapseAction =>
      '[!! Hide every completed household chore for Today !!]';

  @override
  String get todayCalendarLoadingLabel =>
      '[!! Łôåđîñĝ every shared household event for Today securely now !!]';

  @override
  String get todayCalendarRefreshingLabel =>
      '[!! Ŕēƒŕēšĥîñĝ every visible shared household event securely now !!]';

  @override
  String get todayCalendarEmptyLabel =>
      '[!! Ñô shared household calendar events are scheduled for Today. !!]';

  @override
  String todayCalendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! $count complete household events !!]',
      one: '[!! 1 complete household event !!]',
    );
    return '$_temp0';
  }

  @override
  String get todayCalendarHappeningNowLabel =>
      '[!! Ĥåppēñîñĝ right now in the household !!]';

  @override
  String todayCalendarStaleMessage(String syncLabel) {
    return '[!! Showing complete events loaded at $syncLabel. The shared calendar source could not refresh securely. !!]';
  }

  @override
  String todayCalendarOfflineMessage(String syncLabel) {
    return '[!! Showing a securely encrypted and strictly scoped saved household calendar snapshot from $syncLabel. !!]';
  }

  @override
  String get todayCalendarOfflineReadOnlyHint =>
      '[!! Saved household calendar events are strictly read-only. Reconnect and refresh securely before changing the complete Today view or household Calendar. !!]';

  @override
  String get todayCalendarTruncatedMessage =>
      '[!! Today contains more than 500 shared calendar events. Open the complete Calendar to see every event safely. !!]';

  @override
  String todayCalendarEventSemantics(
    String title,
    String schedule,
    String participants,
  ) {
    return '[!! Event $title. Schedule $schedule. Participants $participants. !!]';
  }

  @override
  String get todayOpenCalendarAction =>
      '[!! Ôpēñ the complete shared household Calendar !!]';

  @override
  String get todayChoresUnavailableTitle =>
      '[!! Household chores are temporarily unavailable right now !!]';

  @override
  String get todayPartialFailureHint =>
      '[!! The other complete Today section remains safely available. !!]';

  @override
  String get choreListViewFilterLabel =>
      '[!! Çĥôôšē ţĥē complete household chore date and status view !!]';

  @override
  String get choreListAssigneeFilterLabel =>
      '[!! Çĥôôšē whose complete household chores are visible !!]';

  @override
  String get choreListTodayFilter => '[!! Ţôđåŷ !!]';

  @override
  String get choreListUpcomingFilter => '[!! Ûpçômîñĝ !!]';

  @override
  String get choreListOverdueFilter => '[!! Ôvēŕđûē !!]';

  @override
  String get choreListCompletedFilter => '[!! Çômpłēţēđ !!]';

  @override
  String get choreListEveryoneFilter => '[!! Ēvēŕŷôñē !!]';

  @override
  String get choreListMeFilter => '[!! Mē ôñłŷ !!]';

  @override
  String choreListBoundaryDate(String dateLabel) {
    return '[!! Authoritative shared household date boundary: $dateLabel !!]';
  }

  @override
  String choreListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! $count complete filtered household chores !!]',
      one: '[!! 1 complete filtered household chore !!]',
    );
    return '$_temp0';
  }

  @override
  String choreListMetadata(
    String assigneeName,
    String dateLabel,
    String dueLabel,
  ) {
    return '[!! Assigned securely to $assigneeName · household date $dateLabel · due $dueLabel !!]';
  }

  @override
  String get choreListRefreshing =>
      '[!! Ŕēƒŕēšĥîñĝ every visible household chore securely now !!]';

  @override
  String choreListLastSynced(String syncLabel) {
    return '[!! Last complete authoritative update: $syncLabel !!]';
  }

  @override
  String choreListStaleMessage(String syncLabel) {
    return '[!! Showing the last completely available chores from $syncLabel. A secure refresh could not finish. !!]';
  }

  @override
  String get choreListStaleUnknown =>
      '[!! Showing the last completely available household chores. A secure refresh could not finish. !!]';

  @override
  String choreListOfflineMessage(String syncLabel) {
    return '[!! Šĥôŵîñĝ å securely šåvēđ household šñåþšĥôţ from $syncLabel. !!]';
  }

  @override
  String get choreListOfflineReadOnlyHint =>
      '[!! One eligible scheduled household chore completion can be saved securely on this device. Reconnect before making every other household change safely. !!]';

  @override
  String get choreListUpcomingEmptyTitle =>
      '[!! Ñô upcoming household chores are currently scheduled !!]';

  @override
  String get choreListUpcomingEmptyBody =>
      '[!! Every future scheduled household responsibility will appear completely in this view. !!]';

  @override
  String get choreListOverdueEmptyTitle =>
      '[!! Ñô household chores are currently overdue !!]';

  @override
  String get choreListOverdueEmptyBody =>
      '[!! Every earlier scheduled household responsibility has already been handled completely. !!]';

  @override
  String get choreListCompletedEmptyTitle =>
      '[!! Ñô household chores have been completed yet !!]';

  @override
  String get choreListCompletedEmptyBody =>
      '[!! Completed household responsibilities will remain safely available in this complete history view. !!]';

  @override
  String get choreListLoadingMore =>
      '[!! Łôåđîñĝ another complete page of household chores now !!]';

  @override
  String get choreListLoadMoreAction => '[!! Łôåđ more household chores !!]';

  @override
  String get choreListLoadMoreFailed =>
      '[!! Another page could not be loaded. Every household chore already shown remains completely available. !!]';

  @override
  String get choreScheduledStatus => '[!! Šçĥēđûłēđ and ready to complete !!]';

  @override
  String get choreCompletedStatus =>
      '[!! Çômpłēţēđ successfully by the household !!]';

  @override
  String get choreMarkCompleteAction =>
      '[!! Måŕķ this household chore completely done !!]';

  @override
  String get choreReopenAction =>
      '[!! Ŕēôpēñ this completed household chore safely !!]';

  @override
  String get choreCompletionInProgress =>
      '[!! Ûpđåţîñĝ the complete household chore status securely now !!]';

  @override
  String get choreCompletionQueuedStatus =>
      '[!! Waiting safely for complete synchronization !!]';

  @override
  String get choreCompletionQueuedMessage =>
      '[!! This complete household chore completion is saved securely on this device. Permission will be checked and synchronization attempted after reconnecting safely. !!]';

  @override
  String get choreCompletionSyncingMessage =>
      '[!! Checking every current household permission and synchronizing the securely saved completion now… !!]';

  @override
  String get choreCompletionPausedMessage =>
      '[!! The complete household completion remains securely saved, but synchronization is paused safely by the current application policy. !!]';

  @override
  String get choreCompletionReconciledMessage =>
      '[!! The complete household chore completion synchronized successfully with every latest authoritative household detail. !!]';

  @override
  String get choreCompletionNeedsAttentionMessage =>
      '[!! Automatic synchronization stopped safely at its complete bound. Discard this saved completion, refresh every detail, and complete the chore again while securely online. !!]';

  @override
  String get choreCompletionDiscardedMessage =>
      '[!! The saved completion could not be applied because the complete chore or household access changed. Every latest authoritative household detail is shown safely. !!]';

  @override
  String get choreCompletionExpiredMessage =>
      '[!! The securely saved completion expired before complete synchronization. Refresh every detail and complete the chore again while safely online. !!]';

  @override
  String get choreCompletionQueueUnavailableMessage =>
      '[!! This complete household completion could not be stored securely on this device. Reconnect safely and try the completion again. !!]';

  @override
  String get choreCompletionQueueOccupiedMessage =>
      '[!! One complete household completion is already stored securely on this device. Discard it safely before saving another completion. !!]';

  @override
  String get choreCompletionDiscardAction =>
      '[!! Discard the securely saved completion now !!]';

  @override
  String get choreOccurrenceMenuTooltip =>
      '[!! Open every additional safe household chore action available here !!]';

  @override
  String get choreSkipOccurrenceAction =>
      '[!! Skip only this one repeating household chore occurrence safely !!]';

  @override
  String get choreSkipOccurrenceDialogTitle =>
      '[!! Skip only this single household occurrence now? !!]';

  @override
  String get choreSkipOccurrenceDialogBody =>
      '[!! Only this selected household date will be skipped. The complete repeating schedule and every other occurrence remain safely unchanged. !!]';

  @override
  String get choreSkipOccurrenceConfirmAction =>
      '[!! Confirm skipping this one household occurrence !!]';

  @override
  String get choreSkipOccurrenceSucceeded =>
      '[!! This single repeating household occurrence was skipped successfully. !!]';

  @override
  String get choreRestoreSkippedAction =>
      '[!! Undo the skipped household occurrence safely now !!]';

  @override
  String get choreRestoreSkippedSucceeded =>
      '[!! The skipped repeating household occurrence is safely back on Today. !!]';

  @override
  String get choreRestoreSkippedFailed =>
      '[!! The skipped household occurrence could not be restored safely. Try again. !!]';

  @override
  String get choreRescheduleOccurrenceAction =>
      '[!! Change the complete date or time of only this single household occurrence !!]';

  @override
  String get choreRescheduleDialogTitle =>
      '[!! Reschedule only this one repeating household occurrence safely !!]';

  @override
  String get choreRescheduleDialogBody =>
      '[!! Only this selected household date and time will change. The complete repeating schedule and every other occurrence remain safely unchanged. !!]';

  @override
  String get choreRescheduleConfirmAction =>
      '[!! Save this complete new occurrence schedule safely now !!]';

  @override
  String get choreRescheduleSucceeded =>
      '[!! This single household occurrence was rescheduled successfully. !!]';

  @override
  String get choreReassignOccurrenceAction =>
      '[!! Change the active adult assigned to only this single household occurrence !!]';

  @override
  String get choreReassignDialogTitle =>
      '[!! Change the assignee for only this one repeating household occurrence safely !!]';

  @override
  String get choreReassignDialogBody =>
      '[!! Only this selected household occurrence will change assignee. The complete repeating schedule and every other occurrence keep their existing assignee safely. !!]';

  @override
  String get choreReassignConfirmAction =>
      '[!! Save this complete new occurrence assignee safely now !!]';

  @override
  String get choreReassignSucceeded =>
      '[!! This single household occurrence was reassigned successfully. !!]';

  @override
  String get choreReassignRosterFailed =>
      '[!! The active household member roster could not be loaded safely. Please try again now. !!]';

  @override
  String get choreEditOneTimeAction =>
      '[!! Edit every detail of this single one-time household chore safely now !!]';

  @override
  String get choreDeleteOneTimeAction =>
      '[!! Delete this single one-time household chore from every active list safely !!]';

  @override
  String get choreEditOneTimeDialogTitle =>
      '[!! Edit every detail of this one-time household chore safely !!]';

  @override
  String get choreEditOneTimeDialogBody =>
      '[!! Update the complete details, assignee, household date, or local time. Every completed chore must be reopened before editing so protected history remains safe. !!]';

  @override
  String get choreEditOneTimeConfirmAction =>
      '[!! Save every one-time household chore change safely now !!]';

  @override
  String get choreEditOneTimeSucceeded =>
      '[!! The complete one-time household chore was updated successfully and safely. !!]';

  @override
  String get choreDeleteOneTimeDialogTitle =>
      '[!! Delete this complete one-time household chore safely now? !!]';

  @override
  String get choreDeleteOneTimeDialogBody =>
      '[!! This chore will disappear from every active household chore list while its complete protected history remains safely preserved. !!]';

  @override
  String get choreDeleteOneTimeConfirmAction =>
      '[!! Confirm deleting this one-time household chore safely !!]';

  @override
  String get choreDeleteOneTimeSucceeded =>
      '[!! The complete one-time household chore was deleted successfully and safely. !!]';

  @override
  String get choreEditSeriesAction =>
      '[!! Edit the complete repeating household chore series from today onward !!]';

  @override
  String get choreCancelSeriesAction =>
      '[!! Cancel the complete repeating household chore series safely !!]';

  @override
  String get choreEditSeriesDialogTitle =>
      '[!! Edit this complete repeating household chore series safely !!]';

  @override
  String get choreEditSeriesDialogBody =>
      '[!! Every change applies from today in the shared household time zone. Past occurrences and every completed chore remain safely unchanged. !!]';

  @override
  String get choreEditSeriesConfirmAction =>
      '[!! Save every complete series change safely now !!]';

  @override
  String get choreEditSeriesSucceeded =>
      '[!! The complete repeating household series was updated safely from today. !!]';

  @override
  String get choreEditSeriesFromOccurrenceAction =>
      '[!! Edit this selected future occurrence and every later incomplete household chore safely !!]';

  @override
  String get choreEditSeriesFromOccurrenceDialogTitle =>
      '[!! Edit this selected household occurrence and every later incomplete occurrence safely !!]';

  @override
  String get choreEditSeriesFromOccurrenceDialogBody =>
      '[!! The selected occurrence and every later incomplete chore will use the new complete series settings. Earlier and completed chores remain unchanged. Later incomplete one-occurrence adjustments may reset safely to the new defaults. Existing completed history stays safely available for every household member. !!]';

  @override
  String get choreEditSeriesFromOccurrenceConfirmAction =>
      '[!! Save every series change safely from this selected occurrence now !!]';

  @override
  String get choreEditSeriesFromOccurrenceSucceeded =>
      '[!! The complete repeating household series was updated safely from the selected occurrence. !!]';

  @override
  String get choreCancelSeriesFromOccurrenceAction =>
      '[!! Cancel every incomplete household chore safely from this selected future occurrence onward now !!]';

  @override
  String get choreCancelSeriesFromOccurrenceDialogTitle =>
      '[!! Cancel this selected household occurrence and every later incomplete occurrence safely now? !!]';

  @override
  String get choreCancelSeriesFromOccurrenceDialogBody =>
      '[!! The selected household occurrence and every later incomplete repeating chore will be removed safely from the shared schedule. Every earlier occurrence and every completed household chore will remain unchanged and safely available to all household members. !!]';

  @override
  String get choreCancelSeriesFromOccurrenceConfirmAction =>
      '[!! Confirm cancelling every incomplete series occurrence safely from this selected occurrence now !!]';

  @override
  String get choreCancelSeriesFromOccurrenceSucceeded =>
      '[!! The complete repeating household series was cancelled safely from the selected occurrence onward. !!]';

  @override
  String get choreCancelSeriesFromOccurrenceUndoAction =>
      '[!! Undo and restore the complete repeating household series cancellation safely now !!]';

  @override
  String get choreCancelSeriesFromOccurrenceUndoSucceeded =>
      '[!! The complete repeating household chore series was restored safely for every household member. !!]';

  @override
  String get choreCancelSeriesFromOccurrenceUndoFailed =>
      '[!! The complete repeating household chore series could not be restored safely yet. Please try the same protected recovery action again now. !!]';

  @override
  String get choreCancelSeriesDialogTitle =>
      '[!! Cancel this complete repeating household chore series now? !!]';

  @override
  String get choreCancelSeriesDialogBody =>
      '[!! Every incomplete occurrence from today onward will be removed throughout the shared household schedule. Past occurrences and every completed chore remain safely unchanged. !!]';

  @override
  String get choreCancelSeriesConfirmAction =>
      '[!! Confirm cancelling the complete repeating series !!]';

  @override
  String get choreCancelSeriesSucceeded =>
      '[!! The complete repeating household series was cancelled safely from today. !!]';

  @override
  String get choreDetailsAction =>
      '[!! Open every chore detail and its complete household activity history safely !!]';

  @override
  String get choreDetailsTitle =>
      '[!! Complete household chore details and history !!]';

  @override
  String get choreDetailsCloseTooltip =>
      '[!! Close these complete household chore details safely !!]';

  @override
  String get choreDetailsCurrentHeading =>
      '[!! Complete current household chore information !!]';

  @override
  String get choreTargetLoading =>
      '[!! Loading every latest authoritative household chore detail securely now !!]';

  @override
  String get choreTargetUnavailableTitle =>
      '[!! This selected household chore is completely unavailable here !!]';

  @override
  String get choreTargetUnavailableBody =>
      '[!! It may have changed, been removed, or no longer be available inside this active household securely. !!]';

  @override
  String get choreTargetLoadFailedTitle =>
      '[!! Complete authoritative chore details could not be loaded safely !!]';

  @override
  String get choreTargetLoadFailedBody =>
      '[!! Check the complete network connection and try again. No stale cached chore detail is shown on this secure screen. !!]';

  @override
  String get choreTargetNotificationsAction =>
      '[!! Open the complete household notification center safely now !!]';

  @override
  String get choreTargetChoresAction =>
      '[!! Open every available household chore safely now !!]';

  @override
  String get choreHistoryHeading =>
      '[!! Complete household activity history !!]';

  @override
  String get choreHistoryLoading =>
      '[!! Loading every household chore activity entry securely now !!]';

  @override
  String get choreHistoryEmptyTitle =>
      '[!! No household activity has been recorded here yet !!]';

  @override
  String get choreHistoryEmptyBody =>
      '[!! Every future change to this selected household occurrence will appear safely in this complete history. !!]';

  @override
  String get choreHistoryLoadFailed =>
      '[!! Complete household chore activity could not be loaded safely. Check the connection and try again now. !!]';

  @override
  String get choreHistoryLoadMoreAction =>
      '[!! Load every available earlier household activity entry now !!]';

  @override
  String get choreHistoryLoadingMore =>
      '[!! Loading every earlier household activity entry securely now !!]';

  @override
  String get choreHistoryLoadMoreFailed =>
      '[!! Earlier household activity could not be loaded safely. Please try again now. !!]';

  @override
  String choreHistoryActorActingAs(String actorName, String actingName) {
    return '[!! $actorName acting securely for household member $actingName !!]';
  }

  @override
  String choreHistoryCompleted(String actorName) {
    return '[!! $actorName completely finished this shared household chore successfully. !!]';
  }

  @override
  String choreHistoryReopened(String actorName) {
    return '[!! $actorName safely reopened this completed shared household chore. !!]';
  }

  @override
  String choreHistorySkipped(String actorName) {
    return '[!! $actorName safely skipped only this selected household occurrence. !!]';
  }

  @override
  String choreHistoryRestored(String actorName) {
    return '[!! $actorName safely restored only this selected household occurrence. !!]';
  }

  @override
  String choreHistoryRescheduled(
    String actorName,
    String previousSchedule,
    String newSchedule,
  ) {
    return '[!! $actorName safely changed this occurrence schedule from $previousSchedule to $newSchedule for the household. !!]';
  }

  @override
  String choreHistoryReassigned(
    String actorName,
    String previousAssignee,
    String newAssignee,
  ) {
    return '[!! $actorName safely changed this occurrence assignee from $previousAssignee to $newAssignee for the household. !!]';
  }

  @override
  String choreHistoryTimestamp(String date, String time) {
    return '[!! Recorded securely on $date at local time $time !!]';
  }

  @override
  String choreScheduleLabel(String date, String time) {
    return '[!! Household-local schedule date $date at the complete time $time !!]';
  }

  @override
  String get choreCreateTitle =>
      '[!! Åđđ å complete shared household chore !!]';

  @override
  String get choreCreateHeading =>
      '[!! Šçĥēđûłē å complete household responsibility repeatedly or once !!]';

  @override
  String get choreCreateBody =>
      '[!! Choose an active adult, the very first due date, and whether this household responsibility repeats securely. !!]';

  @override
  String get choreTemplatesHeading =>
      '[!! Choose complete household quick-start suggestions !!]';

  @override
  String get choreTemplatesBody =>
      '[!! Choose one complete household suggestion to fill its localized title and repeating schedule, then freely edit every single detail before adding it securely. !!]';

  @override
  String get choreTemplateSearchLabel =>
      '[!! Search every complete household quick-start suggestion by its full localized title !!]';

  @override
  String get choreTemplateSearchClearAction =>
      '[!! Clear the complete household template search query now !!]';

  @override
  String get choreTemplateCategoryAll => '[!! Every household category !!]';

  @override
  String get choreTemplateCategoryKitchen =>
      '[!! Complete kitchen responsibilities !!]';

  @override
  String get choreTemplateCategoryCleaning =>
      '[!! Complete cleaning responsibilities !!]';

  @override
  String get choreTemplateCategoryLaundry =>
      '[!! Complete laundry responsibilities !!]';

  @override
  String get choreTemplateCategoryHomeCare =>
      '[!! Complete shared home care responsibilities !!]';

  @override
  String get choreTemplateCategoryPetCare =>
      '[!! Complete household pet care responsibilities !!]';

  @override
  String get choreTemplateNoResults =>
      '[!! No complete household quick-start suggestion matches both this search and selected category. !!]';

  @override
  String get choreTemplateDishes =>
      '[!! Complete all shared household dishes !!]';

  @override
  String get choreTemplateKitchenReset =>
      '[!! Reset the complete shared household kitchen carefully !!]';

  @override
  String get choreTemplateLaundry =>
      '[!! Complete all shared household laundry safely !!]';

  @override
  String get choreTemplateVacuuming =>
      '[!! Vacuum every shared household room completely !!]';

  @override
  String get choreTemplateBathroomCleaning =>
      '[!! Clean every complete shared household bathroom carefully !!]';

  @override
  String get choreTemplateTrashAndRecycling =>
      '[!! Take out all shared household trash and recycling completely !!]';

  @override
  String get choreTemplateWipeCounters =>
      '[!! Wipe every shared household kitchen counter completely !!]';

  @override
  String get choreTemplateFridgeCleanout =>
      '[!! Carefully clean out the complete shared household refrigerator !!]';

  @override
  String get choreTemplateMopFloors =>
      '[!! Mop every shared household floor completely and carefully !!]';

  @override
  String get choreTemplateDusting =>
      '[!! Remove dust from every complete shared household surface !!]';

  @override
  String get choreTemplateChangeBedLinen =>
      '[!! Change all complete shared household bed linen carefully !!]';

  @override
  String get choreTemplateFoldClothes =>
      '[!! Fold every complete shared household clothing item carefully !!]';

  @override
  String get choreTemplateMakeBeds =>
      '[!! Make every complete shared household bed carefully today !!]';

  @override
  String get choreTemplateWaterPlants =>
      '[!! Water every complete shared household plant carefully !!]';

  @override
  String get choreTemplateFeedPets =>
      '[!! Feed every complete shared household pet carefully today !!]';

  @override
  String get choreTemplateCleanPetArea =>
      '[!! Clean every complete shared household pet area carefully !!]';

  @override
  String get guidedChoreSetupTitle =>
      '[!! Set up every important first shared household chore carefully !!]';

  @override
  String get guidedChoreSetupHeading =>
      '[!! Choose exactly three complete household chores to begin working together successfully !!]';

  @override
  String get guidedChoreSetupBody =>
      '[!! A carefully prepared shared list makes the complete Today experience useful immediately. Pick exactly three household chores, then review every editable detail before adding them securely. !!]';

  @override
  String get guidedChoreSetupLoading =>
      '[!! Preparing every safe shared household chore suggestion and authoritative local date now !!]';

  @override
  String get guidedChoreSetupResumeNotice =>
      '[!! Your securely saved complete setup was restored after the interruption. Safely continuing every remaining household chore from the last confirmed result now. !!]';

  @override
  String guidedChoreSetupSelectionProgress(int selected, int required) {
    return '[!! Selected $selected complete household suggestions out of exactly $required required suggestions !!]';
  }

  @override
  String guidedChoreSetupAddingProgress(int completed, int total) {
    return '[!! Successfully added $completed complete household chores out of the required total of $total chores !!]';
  }

  @override
  String guidedChoreSetupDefaultsBody(String startDate, String timezone) {
    return '[!! Every selected chore is assigned to your current adult account, available at any convenient time, and repeats from $startDate in the authoritative $timezone household time zone. Every detail can be edited safely later. !!]';
  }

  @override
  String get guidedChoreSetupChooseBody =>
      '[!! Pick exactly three complete household suggestions. Every selected title and repeating schedule remains freely editable before the secure addition begins. !!]';

  @override
  String get guidedChoreSetupReviewHeading =>
      '[!! Carefully review all three selected household chores before adding them !!]';

  @override
  String get guidedChoreSetupAddAction =>
      '[!! Add all 3 complete household chores securely now !!]';

  @override
  String get guidedChoreSetupRetryAction =>
      '[!! Continue safely adding only the remaining household chores !!]';

  @override
  String get guidedChoreSetupSkipAction =>
      '[!! Skip this complete quick setup carefully for now !!]';

  @override
  String get guidedChoreSetupExitTitle =>
      '[!! Leave the complete household quick setup now? !!]';

  @override
  String get guidedChoreSetupExitBody =>
      '[!! Household chores can be added safely later from the complete Today screen. Are you sure you want to leave this quick setup now? !!]';

  @override
  String guidedChoreSetupPartialExitBody(int completed) {
    return '[!! Complete household chores added so far: $completed. Every added chore will remain safely in the household, and the rest can be added later. Continue to the Today screen now? !!]';
  }

  @override
  String get guidedChoreSetupStayAction =>
      '[!! Keep completing this household setup safely !!]';

  @override
  String get guidedChoreSetupContinueTodayAction =>
      '[!! Continue safely to the complete Today screen !!]';

  @override
  String get choreTitleLabel => '[!! Ĥôûšēĥôłđ chore name !!]';

  @override
  String get choreTitleValidation =>
      '[!! Enter a complete household chore name before continuing. !!]';

  @override
  String get choreDescriptionLabel =>
      '[!! Additional household notes (optional) !!]';

  @override
  String get choreAssigneeLabel =>
      '[!! Active adult assigned to this chore !!]';

  @override
  String choreAssigneeYou(String memberName) {
    return '[!! $memberName (your current adult account) !!]';
  }

  @override
  String get choreRecurrenceLabel =>
      '[!! Complete household repeating schedule !!]';

  @override
  String get choreRecurrenceOnce =>
      '[!! Does not repeat after this one household task !!]';

  @override
  String get choreRecurrenceDaily =>
      '[!! Repeats every complete household day !!]';

  @override
  String get choreRecurrenceWeekly =>
      '[!! Repeats every complete household week !!]';

  @override
  String get choreRecurrenceMonthly =>
      '[!! Repeats every complete household month !!]';

  @override
  String choreRecurrenceSummary(String pattern, String startDate) {
    return '[!! $pattern, beginning on $startDate. Every future date is created securely in the shared household time zone. !!]';
  }

  @override
  String get choreRecurrenceWeekdaysLabel =>
      '[!! Complete household weekdays selected for repeating this chore !!]';

  @override
  String get choreRecurrenceWeekdayCreationAnchorHelper =>
      '[!! The complete weekday of this chore\'s first date always remains safely selected. !!]';

  @override
  String get choreRecurrenceWeekdayMinimumHelper =>
      '[!! Keep at least one complete household repeat weekday selected safely. !!]';

  @override
  String get choreRecurrenceWeekdayMonday => '[!! Complete Monday weekday !!]';

  @override
  String get choreRecurrenceWeekdayTuesday =>
      '[!! Complete Tuesday weekday !!]';

  @override
  String get choreRecurrenceWeekdayWednesday =>
      '[!! Complete Wednesday weekday !!]';

  @override
  String get choreRecurrenceWeekdayThursday =>
      '[!! Complete Thursday weekday !!]';

  @override
  String get choreRecurrenceWeekdayFriday => '[!! Complete Friday weekday !!]';

  @override
  String get choreRecurrenceWeekdaySaturday =>
      '[!! Complete Saturday weekday !!]';

  @override
  String get choreRecurrenceWeekdaySunday => '[!! Complete Sunday weekday !!]';

  @override
  String choreRecurrenceWeekdaysSummary(String weekdays) {
    return '[!! Repeats safely on these complete household weekdays: $weekdays. !!]';
  }

  @override
  String get choreRecurrenceMonthDayLabel =>
      '[!! Complete household day of every month !!]';

  @override
  String choreRecurrenceMonthDayOption(int day) {
    return '[!! Complete monthly day $day !!]';
  }

  @override
  String get choreRecurrenceMonthDayCreationAnchorHelper =>
      '[!! The complete first due date safely sets this monthly day. !!]';

  @override
  String get choreRecurrenceMonthDayMissingDateHelper =>
      '[!! Months without this complete date are skipped safely and never moved to the final day. !!]';

  @override
  String choreRecurrenceMonthDaySummary(int day) {
    return '[!! Repeats safely on complete day $day of every month. !!]';
  }

  @override
  String get choreRecurrenceIntervalLabel =>
      '[!! Complete repeating schedule interval between household chores !!]';

  @override
  String get choreRecurrenceIntervalHelper =>
      '[!! Carefully use one complete whole number from 1 through 30 only. !!]';

  @override
  String get choreRecurrenceIntervalValidation =>
      '[!! Enter one supported complete number from 1 through 30 safely. !!]';

  @override
  String get choreRecurrenceEndLabel =>
      '[!! Complete repeating series ending condition !!]';

  @override
  String get choreRecurrenceEndNever =>
      '[!! Never end this complete household series automatically !!]';

  @override
  String get choreRecurrenceEndAfterCount =>
      '[!! End safely after a complete number of household occurrences !!]';

  @override
  String get choreRecurrenceEndOnDate =>
      '[!! End safely on one complete household-local date !!]';

  @override
  String get choreRecurrenceCountLabel =>
      '[!! Complete number of household chore occurrences !!]';

  @override
  String get choreRecurrenceCountHelper =>
      '[!! Carefully use one complete whole number from 1 through 1,000 only. !!]';

  @override
  String get choreRecurrenceCountValidation =>
      '[!! Enter one supported complete number from 1 through 1,000 safely. !!]';

  @override
  String get choreRecurrenceUntilDateLabel =>
      '[!! Complete household-local series end date !!]';

  @override
  String get choreRecurrenceInvalidSummary =>
      '[!! Carefully review every complete repeating schedule setting. !!]';

  @override
  String choreRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '[!! Every $interval complete household days safely !!]',
      one: '[!! Every complete household day !!]',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '[!! Every $interval complete household weeks safely !!]',
      one: '[!! Every complete household week !!]',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '[!! Every $interval complete household months safely !!]',
      one: '[!! Every complete household month !!]',
    );
    return '$_temp0';
  }

  @override
  String get choreRecurrenceEndNeverSummary =>
      '[!! This complete repeating household series has no automatic end date. !!]';

  @override
  String choreRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! Ends safely after $count complete household occurrences. !!]',
      one: '[!! Ends safely after 1 complete household occurrence. !!]',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEndUntilSummary(String date) {
    return '[!! Ends safely on the complete household-local date $date. !!]';
  }

  @override
  String get choreDueDateLabel => '[!! Complete household due date !!]';

  @override
  String get choreDueTimeLabel => '[!! Optional precise due time !!]';

  @override
  String get choreAllDayLabel =>
      '[!! Complete at any convenient time today !!]';

  @override
  String get choreClearTimeAction =>
      '[!! Remove the optional precise due time !!]';

  @override
  String get choreCreateAction => '[!! Åđđ this complete household chore !!]';

  @override
  String get choreCreatingAction =>
      '[!! Åđđîñĝ this household chore securely now !!]';

  @override
  String get choreCreatedBody =>
      '[!! The complete chore was added to the shared household successfully. !!]';

  @override
  String get choreCreateInvalidError =>
      '[!! Check every chore detail carefully and safely try again. !!]';

  @override
  String get choreRecurrenceInvalidError =>
      '[!! This repeating schedule is not supported. Review every recurrence detail and safely try again. !!]';

  @override
  String get chorePermissionError =>
      '[!! This household or selected adult is no longer available. Reload everything and safely try again. !!]';

  @override
  String get choreCreateConflictError =>
      '[!! The chore details changed during a retry. Review every detail and submit a fresh request. !!]';

  @override
  String get choreActionConflictError =>
      '[!! This household chore action changed during a safe retry. Reload every detail and try the complete action again. !!]';

  @override
  String get choreVersionConflictError =>
      '[!! This household chore changed somewhere else. The latest authoritative household status is now shown safely. !!]';

  @override
  String get choreTransitionConflictError =>
      '[!! That action no longer matches this household chore\'s current status. The latest authoritative status is now shown. !!]';

  @override
  String get choreGenericError =>
      '[!! We could not load or save household chores. The same request remains safe to try again. !!]';

  @override
  String get choreOfflineReadOnlyError =>
      '[!! This securely šåvēđ household snapshot is strictly ŕēåđ-ôñłŷ. Reconnect and refresh before making any change safely. !!]';

  @override
  String get retryAction => '[!! Ţŕŷ ţĥîš åĝåîñ !!]';

  @override
  String get retryActionHint =>
      '[!! Ŕûñš ţĥîš complete foundation check åĝåîñ !!]';

  @override
  String get foundationReadyTitle => '[!! ĶîñFłôŵ îš completely ŕēåđŷ !!]';

  @override
  String get foundationReadyBody =>
      '[!! Ţĥē åpp ƒôûñđåţîôñ åñđ çôđē ɓôûñđåŕîēš åŕē ŕûññîñĝ. Product features can now be added safely and confidently across every adaptive layout. !!]';

  @override
  String foundationLayoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! $count expanded adaptive layouts are completely ready. !!]',
      one: '[!! 1 expanded adaptive layout is completely ready. !!]',
    );
    return '$_temp0';
  }

  @override
  String get foundationLoadingLabel =>
      '[!! Çĥēçķîñĝ ţĥē complete åpp ƒôûñđåţîôñ !!]';

  @override
  String get foundationErrorTitle =>
      '[!! Ţĥē åpp ƒôûñđåţîôñ îš currently ûñåvåîłåɓłē !!]';

  @override
  String get foundationErrorBody =>
      '[!! Płēåšē ŕûñ ţĥē complete ƒôûñđåţîôñ çĥēçķ åĝåîñ. !!]';

  @override
  String get pageNotFoundTitle =>
      '[!! Ţĥîš requested påĝē çôûłđ ñôţ ɓē ƒôûñđ !!]';

  @override
  String get pageNotFoundBody =>
      '[!! Ţĥîš requested påĝē îš currently ûñåvåîłåɓłē. !!]';

  @override
  String get goHomeAction => '[!! Ĝô ɓåçķ ţô Ĥômē !!]';

  @override
  String get primaryNavigationLabel => '[!! Pŕîmåŕŷ åppłîçåţîôñ ñåvîĝåţîôñ !!]';

  @override
  String get homeNavigationLabel => '[!! Ĥômē page !!]';

  @override
  String get todayNavigationLabel =>
      '[!! Ţôđåŷ household schedule destination !!]';

  @override
  String get choresNavigationLabel =>
      '[!! Çĥôŕēš shared household task destination !!]';

  @override
  String get calendarNavigationLabel =>
      '[!! Çåłēñđåŕ shared family event destination !!]';

  @override
  String get familyNavigationLabel =>
      '[!! Fåmîłŷ household people and invitations destination !!]';

  @override
  String get settingsNavigationLabel =>
      '[!! Šēţţîñĝš account privacy and application destination !!]';

  @override
  String get calendarTitle =>
      '[!! Complete shared household calendar and every event !!]';

  @override
  String get calendarTodayAction =>
      '[!! Return safely to the complete Today household schedule !!]';

  @override
  String get calendarLoadingLabel =>
      '[!! Loading every shared household calendar event securely now !!]';

  @override
  String get calendarEmptyTitle =>
      '[!! No shared household calendar events have been added yet !!]';

  @override
  String get calendarEmptyBody =>
      '[!! Add a precisely timed event or a complete all-day household plan safely. !!]';

  @override
  String get calendarCreateAction =>
      '[!! Add a complete household calendar event now !!]';

  @override
  String get calendarImportAction =>
      '[!! Import one complete external .ics calendar file safely !!]';

  @override
  String get calendarImportTitle =>
      '[!! Review and import one complete calendar file safely !!]';

  @override
  String get calendarImportIntro =>
      '[!! Carefully choose one complete UTF-8 .ics file, review every supported event, and copy only your selected events into this exact household calendar safely. !!]';

  @override
  String get calendarImportCopyDisclosure =>
      '[!! This is one complete one-time copy and never automatic synchronization. Importing the same file again can create duplicate household events, and every later external change remains separate. !!]';

  @override
  String get calendarImportChooseFileAction =>
      '[!! Choose one trusted .ics calendar file safely !!]';

  @override
  String get calendarImportChooseAnotherAction =>
      '[!! Replace this preview with another trusted file safely !!]';

  @override
  String get calendarImportBackAction =>
      '[!! Close the complete calendar import review safely !!]';

  @override
  String get calendarImportPickingLabel =>
      '[!! Opening the trusted Android document picker safely now !!]';

  @override
  String get calendarImportRosterLoading =>
      '[!! Loading every active household member safely now !!]';

  @override
  String calendarImportSupportedCount(int count) {
    return '[!! Complete supported household events: $count !!]';
  }

  @override
  String calendarImportSkippedCount(int count) {
    return '[!! Complete safely skipped source events: $count !!]';
  }

  @override
  String calendarImportSkippedDetails(
    int invalid,
    int unsupported,
    int duplicate,
  ) {
    return '[!! Invalid $invalid · unsupported $unsupported · duplicate safely detected inside this exact file $duplicate !!]';
  }

  @override
  String get calendarImportIgnoredFieldsDisclosure =>
      '[!! External locations, links, organizers, attendees, attachments, and alarms are never copied, opened, or executed here. !!]';

  @override
  String calendarImportFloatingDisclosure(String timeZone) {
    return '[!! Every event without a time zone safely uses the authoritative household time zone $timeZone. !!]';
  }

  @override
  String get calendarImportOverlapDisclosure =>
      '[!! Every repeated local clock time safely uses its earlier complete valid occurrence. !!]';

  @override
  String get calendarImportEventsHeading =>
      '[!! Choose every complete source event to copy safely !!]';

  @override
  String calendarImportSelectedCount(int selected, int total) {
    return '[!! Selected $selected complete events from $total supported events !!]';
  }

  @override
  String get calendarImportNoSupportedEvents =>
      '[!! This complete file contains no event KinFlow can copy safely into the household. Every unsupported or invalid source event remains completely unchanged. !!]';

  @override
  String get calendarImportParticipantsHeading =>
      '[!! Choose participants for every copied household event !!]';

  @override
  String get calendarImportParticipantsHelper =>
      '[!! The same selected active household members are safely added to every selected event in this complete batch. !!]';

  @override
  String calendarImportAllDayRange(String startDate, String endDate) {
    return '[!! Complete all-day event · $startDate through $endDate inclusive !!]';
  }

  @override
  String calendarImportTimedSummary(
    String date,
    String time,
    String duration,
    String timeZone,
  ) {
    return '[!! Complete date $date · precise time $time · $duration · trusted time zone $timeZone !!]';
  }

  @override
  String calendarImportSubmitAction(int count) {
    return '[!! Copy all $count selected events safely now !!]';
  }

  @override
  String calendarImportProgress(int completed, int total) {
    return '[!! Safely copied $completed from $total complete events !!]';
  }

  @override
  String calendarImportPartialFailure(int completed, int total) {
    return '[!! Safely copied $completed from $total complete events. The next event was not copied. !!]';
  }

  @override
  String get calendarImportRetryAction =>
      '[!! Retry every remaining event with the same safe requests !!]';

  @override
  String calendarImportSuccess(int count) {
    return '[!! Safely copied $count complete events into this household calendar. !!]';
  }

  @override
  String get calendarImportPickerUnavailableError =>
      '[!! The trusted Android document picker is unavailable in this complete application build. !!]';

  @override
  String get calendarImportPickerFailedError =>
      '[!! The selected file could not be read safely and completely. Carefully choose it again or use another complete .ics file. !!]';

  @override
  String get calendarImportInvalidFileError =>
      '[!! This is not one completely valid supported iCalendar file. The complete original source file remains unchanged. !!]';

  @override
  String get calendarImportUnsupportedVersionError =>
      '[!! This selected source file must contain exactly one complete supported iCalendar version 2.0 calendar. !!]';

  @override
  String get calendarImportTooLargeError =>
      '[!! Carefully choose one complete .ics file no larger than 256 KiB. !!]';

  @override
  String get calendarImportTooManyEventsError =>
      '[!! Carefully choose one complete .ics file containing no more than 50 events. !!]';

  @override
  String get calendarEditAction =>
      '[!! Edit this complete household calendar event safely !!]';

  @override
  String get calendarDeleteAction =>
      '[!! Delete this complete household calendar event safely !!]';

  @override
  String get calendarOccurrenceEditAction =>
      '[!! Edit only this selected recurring household occurrence safely now !!]';

  @override
  String get calendarOccurrenceCancelAction =>
      '[!! Cancel only this selected recurring household occurrence safely now !!]';

  @override
  String get calendarOccurrenceModifiedLabel =>
      '[!! This recurring household occurrence has a complete one-off modification !!]';

  @override
  String get calendarSeriesMenuTooltip =>
      '[!! Open every safe action for this complete recurring household series !!]';

  @override
  String get calendarSeriesEditAction =>
      '[!! Edit this entire recurring household series safely from today !!]';

  @override
  String get calendarSeriesEditFromOccurrenceAction =>
      '[!! Edit this selected recurring household occurrence and every later series occurrence safely now !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceAction =>
      '[!! End this selected recurring household occurrence and every later series occurrence safely now !!]';

  @override
  String get calendarSeriesCancelAction =>
      '[!! End this entire recurring household series safely from today !!]';

  @override
  String calendarHouseholdTimeZone(String timeZone) {
    return '[!! Authoritative shared household time zone: $timeZone !!]';
  }

  @override
  String calendarTimedSchedule(String date, String time, String duration) {
    return '[!! Household-local date $date · precise time $time · complete duration $duration !!]';
  }

  @override
  String calendarAllDaySingle(String date) {
    return '[!! Complete all-day household plan · $date !!]';
  }

  @override
  String calendarAllDayRange(String startDate, String endDate) {
    return '[!! Complete all-day household plan · $startDate through $endDate inclusive !!]';
  }

  @override
  String calendarParticipantSummary(String names) {
    return '[!! Shared safely with household members $names !!]';
  }

  @override
  String get calendarEditorCreateTitle =>
      '[!! Add a complete one-time household calendar event safely !!]';

  @override
  String get calendarEditorEditTitle =>
      '[!! Edit this complete one-time household calendar event safely !!]';

  @override
  String get calendarOccurrenceEditorEditTitle =>
      '[!! Edit only this complete recurring household occurrence safely !!]';

  @override
  String get calendarSeriesEditorEditTitle =>
      '[!! Edit this entire recurring household calendar series safely !!]';

  @override
  String get calendarSeriesEditFromOccurrenceEditorTitle =>
      '[!! Edit this selected occurrence and every later recurring household calendar occurrence safely !!]';

  @override
  String get calendarSeriesEditFromOccurrenceEditorBody =>
      '[!! The selected recurring household occurrence and every later series occurrence will use the complete new settings. Every earlier occurrence and each existing one-occurrence adjustment remains safely unchanged for the household. !!]';

  @override
  String get calendarTitleLabel => '[!! Complete household event title !!]';

  @override
  String get calendarTitleValidation =>
      '[!! Enter a complete household event title before continuing. !!]';

  @override
  String get calendarDescriptionLabel =>
      '[!! Additional household event notes (optional) !!]';

  @override
  String get calendarAllDayLabel =>
      '[!! This is a complete all-day household event !!]';

  @override
  String get calendarStartDateLabel =>
      '[!! Complete household event starting date !!]';

  @override
  String get calendarEndDateLabel =>
      '[!! Complete household event ending date !!]';

  @override
  String get calendarStartTimeLabel =>
      '[!! Precise household-local starting time !!]';

  @override
  String get calendarDurationLabel => '[!! Complete event duration !!]';

  @override
  String calendarDurationMinutes(int minutes) {
    return '[!! $minutes complete minutes of household time !!]';
  }

  @override
  String calendarTimeZoneLabel(String timeZone) {
    return '[!! Authoritative IANA time zone: $timeZone !!]';
  }

  @override
  String get calendarOverlapLabel =>
      '[!! Repeated local clock time during a daylight-saving overlap !!]';

  @override
  String get calendarOverlapEarlier =>
      '[!! Use the earlier real occurrence of this repeated clock time !!]';

  @override
  String get calendarOverlapLater =>
      '[!! Use the later real occurrence of this repeated clock time !!]';

  @override
  String get calendarParticipantsLabel =>
      '[!! Active household event participants !!]';

  @override
  String get calendarParticipantValidation =>
      '[!! Choose at least one active household member before saving safely. !!]';

  @override
  String get calendarCancelAction =>
      '[!! Cancel this calendar action safely !!]';

  @override
  String get calendarSaveAction =>
      '[!! Save this complete household calendar event securely !!]';

  @override
  String get calendarDeleteTitle =>
      '[!! Delete this complete household calendar event now? !!]';

  @override
  String calendarDeleteBody(String title) {
    return '[!! The event “$title” will be removed from the complete shared household calendar. !!]';
  }

  @override
  String get calendarDeleteConfirmAction =>
      '[!! Confirm deleting this complete event safely !!]';

  @override
  String get calendarOccurrenceCancelTitle =>
      '[!! Cancel only this selected recurring household occurrence now? !!]';

  @override
  String calendarOccurrenceCancelBody(String title) {
    return '[!! Only this occurrence of “$title” will be cancelled safely, while every other recurring household occurrence remains completely unchanged. !!]';
  }

  @override
  String get calendarOccurrenceCancelConfirmAction =>
      '[!! Confirm cancelling only this recurring occurrence safely !!]';

  @override
  String get calendarSeriesCancelTitle =>
      '[!! End this complete recurring household series from today now? !!]';

  @override
  String calendarSeriesCancelBody(String title) {
    return '[!! Today and every future occurrence of “$title” will be cancelled safely, while every past occurrence remains in complete calendar history. !!]';
  }

  @override
  String get calendarSeriesCancelConfirmAction =>
      '[!! Confirm ending this entire recurring series safely !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceTitle =>
      '[!! End this selected household occurrence and every later recurring occurrence safely now? !!]';

  @override
  String calendarSeriesCancelFromOccurrenceBody(String title) {
    return '[!! The selected recurrence of “$title” and every later recurrence will be cancelled safely and clearly. Every earlier recurrence remains completely unchanged, even when a one-occurrence adjustment moved it to a later display date. Existing one-occurrence adjustments at or after this selected recurrence will also be cancelled. !!]';
  }

  @override
  String get calendarSeriesCancelFromOccurrenceConfirmAction =>
      '[!! Confirm ending this selected occurrence and every later recurrence safely !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceSucceeded =>
      '[!! This selected occurrence and every later recurring household occurrence were ended safely now. !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoAction =>
      '[!! Undo this complete cancellation safely now !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoSucceeded =>
      '[!! The complete recurring household calendar series was restored safely and authoritatively. !!]';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoFailed =>
      '[!! The recurring household calendar series could not be restored safely. Please try this complete Undo action again now. !!]';

  @override
  String get calendarRosterError =>
      '[!! The active household participant roster could not be loaded safely. Please try again now. !!]';

  @override
  String get calendarInvalidError =>
      '[!! Check every household event detail carefully and safely try again. !!]';

  @override
  String get calendarPermissionError =>
      '[!! This household, calendar event, or participant is no longer available. Reload every detail and safely try again. !!]';

  @override
  String get calendarRetryConflictError =>
      '[!! This calendar event action changed during a safe retry. Reload every detail and try the complete action again. !!]';

  @override
  String get calendarVersionConflictError =>
      '[!! This household event changed somewhere else. Reload the latest authoritative calendar before safely trying again. !!]';

  @override
  String get calendarNonexistentTimeError =>
      '[!! That household-local clock time does not exist because the clock changes then. Choose another precise time safely. !!]';

  @override
  String get calendarOccurrenceTransitionError =>
      '[!! This recurring occurrence can no longer be changed safely. Reload the latest authoritative household calendar and try again. !!]';

  @override
  String get calendarAgendaView => '[!! Complete household agenda view !!]';

  @override
  String get calendarDayView => '[!! Complete household day view !!]';

  @override
  String get calendarMonthView => '[!! Complete household month view !!]';

  @override
  String get calendarPreviousRangeAction =>
      '[!! Move to the complete previous calendar period safely !!]';

  @override
  String get calendarNextRangeAction =>
      '[!! Move to the complete next calendar period safely !!]';

  @override
  String get calendarGoToTodayAction =>
      '[!! Move to the authoritative household-local current date !!]';

  @override
  String calendarDateRange(String startDate, String endDate) {
    return '[!! Complete period from $startDate through $endDate !!]';
  }

  @override
  String calendarSelectedDateHeading(String date) {
    return '[!! Complete household events scheduled on $date !!]';
  }

  @override
  String get calendarNoEventsInView =>
      '[!! No complete household events exist in this selected period. !!]';

  @override
  String get calendarLoadMoreAction =>
      '[!! Load the next complete page of household events !!]';

  @override
  String get calendarLoadMoreError =>
      '[!! More household events could not be loaded safely. Please try again now. !!]';

  @override
  String get calendarAllDayChip => '[!! Complete all-day event !!]';

  @override
  String get calendarRecurrenceLabel =>
      '[!! Complete repeating schedule pattern !!]';

  @override
  String get calendarRecurrenceOnce =>
      '[!! This household event does not repeat !!]';

  @override
  String get calendarRecurrenceDaily =>
      '[!! Repeat this complete household event every day !!]';

  @override
  String get calendarRecurrenceWeekly =>
      '[!! Repeat this complete household event every week !!]';

  @override
  String get calendarRecurrenceMonthly =>
      '[!! Repeat this complete household event every month !!]';

  @override
  String get calendarRecurrenceWeekdaysLabel =>
      '[!! Choose every complete household weekday for this repeating event !!]';

  @override
  String get calendarRecurrenceWeekdayAnchorHelper =>
      '[!! The complete household event\'s starting weekday always remains selected safely. !!]';

  @override
  String get calendarRecurrenceWeekdayMonday => '[Möndáÿ!!]';

  @override
  String get calendarRecurrenceWeekdayTuesday => '[Tüësdáÿ!!]';

  @override
  String get calendarRecurrenceWeekdayWednesday => '[Wëdnësdáÿ!!]';

  @override
  String get calendarRecurrenceWeekdayThursday => '[Thürsdáÿ!!]';

  @override
  String get calendarRecurrenceWeekdayFriday => '[Frïdáÿ!!]';

  @override
  String get calendarRecurrenceWeekdaySaturday => '[Sátürdáÿ!!]';

  @override
  String get calendarRecurrenceWeekdaySunday => '[Sündáÿ!!]';

  @override
  String calendarRecurrenceWeekdaysSummary(String weekdays) {
    return '[!! Repeat safely on these complete household weekdays: $weekdays. !!]';
  }

  @override
  String calendarRecurrenceWeeklySummary(String pattern, String weekdays) {
    return '[!! This complete household event repeats $pattern on these weekdays: $weekdays !!]';
  }

  @override
  String get calendarRecurrenceMonthDayLabel =>
      '[!! Complete monthly household event day !!]';

  @override
  String calendarRecurrenceMonthDayOption(int day) {
    return '[!! Complete monthly event day $day !!]';
  }

  @override
  String get calendarRecurrenceMonthDayAnchorHelper =>
      '[!! The complete household event\'s starting date always sets this monthly day safely. !!]';

  @override
  String get calendarRecurrenceMonthDayMissingDateHelper =>
      '[!! Months without this complete date are skipped safely and never moved to the final day. !!]';

  @override
  String calendarRecurrenceMonthDaySummary(int day) {
    return '[!! Repeat safely on complete day $day of each selected month. !!]';
  }

  @override
  String calendarRecurrenceMonthlySummary(String pattern, int day) {
    return '[!! This complete household event repeats $pattern on monthly day $day !!]';
  }

  @override
  String get calendarRecurrenceIntervalLabel =>
      '[!! Complete repeating event schedule interval !!]';

  @override
  String get calendarRecurrenceIntervalHelper =>
      '[!! Carefully use one complete whole number from 1 through 30 only. !!]';

  @override
  String get calendarRecurrenceIntervalValidation =>
      '[!! Enter one supported complete number from 1 through 30 safely. !!]';

  @override
  String get calendarRecurrenceEndLabel =>
      '[!! Complete repeating event series ending condition !!]';

  @override
  String get calendarRecurrenceEndNever =>
      '[!! Never end this complete household event series automatically !!]';

  @override
  String get calendarRecurrenceEndAfterCount =>
      '[!! End safely after a complete number of household event occurrences !!]';

  @override
  String get calendarRecurrenceEndOnDate =>
      '[!! End safely on one complete household-local event date !!]';

  @override
  String get calendarRecurrenceCountLabel =>
      '[!! Complete number of repeating household event occurrences !!]';

  @override
  String get calendarRecurrenceCountHelper =>
      '[!! Carefully use one complete whole number from 1 through 1,000 only. !!]';

  @override
  String get calendarRecurrenceCountValidation =>
      '[!! Enter one supported complete number from 1 through 1,000 safely. !!]';

  @override
  String get calendarRecurrenceUntilDateLabel =>
      '[!! Complete final household-local event occurrence date !!]';

  @override
  String calendarRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other:
          '[!! Repeat this complete household event every $interval days !!]',
      one: '[!! Repeat this complete household event every day !!]',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other:
          '[!! Repeat this complete household event every $interval weeks !!]',
      one: '[!! Repeat this complete household event every week !!]',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other:
          '[!! Repeat this complete household event every $interval months !!]',
      one: '[!! Repeat this complete household event every month !!]',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEditorSummary(String pattern, String startDate) {
    return '[!! $pattern, beginning safely on the complete household-local date $startDate. !!]';
  }

  @override
  String get calendarRecurrenceInvalidSummary =>
      '[!! Carefully complete every supported repeating household event value. !!]';

  @override
  String get calendarRecurrenceEndNeverSummary =>
      '[!! This complete repeating household event series has no automatic end date. !!]';

  @override
  String calendarRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '[!! Ends safely after $count complete household event occurrences. !!]',
      one: '[!! Ends safely after 1 complete household event occurrence. !!]',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEndUntilSummary(String date) {
    return '[!! Ends safely on the complete household-local event date $date. !!]';
  }

  @override
  String calendarRecurrenceSummary(String pattern) {
    return '[!! This complete household event repeats $pattern !!]';
  }

  @override
  String calendarMonthDateSemantics(String date, int count) {
    return '[!! $date, containing $count complete household events !!]';
  }

  @override
  String get calendarGenericError =>
      '[!! We could not load or save household calendar events. The same request remains safe to try again. !!]';

  @override
  String get calendarTargetUnavailableTitle =>
      '[!! Complete household event unavailable !!]';

  @override
  String get calendarTargetUnavailableMessage =>
      '[!! This complete household calendar event was removed, cancelled, or is no longer safely available to this household here. !!]';

  @override
  String get calendarBackToCalendarAction =>
      '[!! Open the complete household calendar !!]';

  @override
  String get calendarLiveDisconnectedMessage =>
      '[!! Live household updates are paused. The last complete calendar may now be out of date. !!]';

  @override
  String get calendarReconnectAction =>
      '[!! Reconnect live household calendar updates !!]';

  @override
  String get choreLiveDisconnectedMessage =>
      '[!! Live household chore updates are paused. The last complete chore lists may now be out of date. !!]';

  @override
  String get choreReconnectAction =>
      '[!! Reconnect every visible live household chore update source !!]';

  @override
  String get notificationLiveDisconnectedMessage =>
      '[!! Live personal notification updates are paused. The last complete household inbox and unread count may now be out of date. !!]';

  @override
  String get notificationReconnectAction =>
      '[!! Reconnect live notification updates and securely reload the complete inbox !!]';

  @override
  String get calendarConflictLatestReloadedMessage =>
      '[!! This complete household calendar event changed on another device. The newest complete calendar view is now safely loaded here; carefully review every detail before trying this action again. !!]';

  @override
  String get calendarConflictTargetUnavailableMessage =>
      '[!! This complete household calendar event changed or was removed on another device. The newest complete calendar view is now safely loaded here. !!]';

  @override
  String get calendarScheduleOverlapHeading =>
      '[!! Complete household schedule overlap guidance hint !!]';

  @override
  String get calendarScheduleOverlapChecking =>
      '[!! Carefully checking this complete proposed schedule against every bounded household event… !!]';

  @override
  String get calendarScheduleOverlapNone =>
      '[!! No same-member schedule overlaps were found anywhere inside the complete checked range. !!]';

  @override
  String get calendarScheduleOverlapUnavailable =>
      '[!! We could not safely check schedule overlaps. Saving remains available, but carefully review the complete household calendar first. !!]';

  @override
  String get calendarScheduleOverlapSaveAllowed =>
      '[!! This complete guidance is only a hint and never blocks saving the household event. !!]';

  @override
  String calendarScheduleOverlapSummary(
    int total,
    int candidateCount,
    String fromDate,
    String throughDate,
  ) {
    return '[!! Found $total complete overlaps across $candidateCount candidate occurrences checked safely and carefully from $fromDate through $throughDate. !!]';
  }

  @override
  String calendarScheduleOverlapTruncated(int limit) {
    return '[!! Showing only the first $limit complete schedule overlaps here. !!]';
  }

  @override
  String calendarScheduleOverlapCandidateDate(String date) {
    return '[!! Proposed candidate occurrence begins on $date !!]';
  }

  @override
  String get notificationTitle =>
      '[!! Complete household notifications and preferences !!]';

  @override
  String get notificationOpenAction =>
      '[!! Open the complete durable notification inbox !!]';

  @override
  String get notificationLoadingLabel =>
      '[!! Loading every durable household notification safely !!]';

  @override
  String get notificationInboxHeading =>
      '[!! Complete durable notification inbox !!]';

  @override
  String notificationUnreadBadge(int count) {
    return '[!! $count complete notifications remain unread !!]';
  }

  @override
  String notificationBadgeSemantics(int count) {
    return '[!! $count complete unread household notifications !!]';
  }

  @override
  String get notificationMarkAllReadAction =>
      '[!! Mark every active notification as read !!]';

  @override
  String get notificationEmptyTitle =>
      '[!! Every complete notification is handled here !!]';

  @override
  String get notificationEmptyBody =>
      '[!! Every new chore and calendar reminder will remain safely available here whenever push delivery is unavailable. !!]';

  @override
  String get notificationChoreDueLabel =>
      '[!! Complete household chore due update !!]';

  @override
  String get notificationChoreAssignmentLabel =>
      '[!! Complete household chore assignment update !!]';

  @override
  String get notificationCalendarEventLabel =>
      '[!! Complete household calendar event reminder !!]';

  @override
  String get notificationItemBody =>
      '[!! Open Today to securely load the newest authorized household details safely across every screen. !!]';

  @override
  String notificationCreatedSchedule(String date, String time) {
    return '[!! Securely received $date at $time !!]';
  }

  @override
  String get notificationSnoozeAction =>
      '[!! Remind me again with a complete delayed reminder !!]';

  @override
  String get notificationSnoozeSheetTitle =>
      '[!! Carefully choose when this complete reminder should return !!]';

  @override
  String get notificationSnoozeSheetBody =>
      '[!! The complete reminder will safely return to this durable inbox at the selected time and send another generic mobile push whenever delivery is enabled. !!]';

  @override
  String notificationSnoozeMinutesAction(int minutes) {
    return '[!! In exactly $minutes deliberately expanded reminder minutes before this notification safely returns again !!]';
  }

  @override
  String notificationSnoozeSucceeded(int minutes) {
    return '[!! This complete reminder will safely return again in exactly $minutes deliberately expanded minutes across every durable notification surface. !!]';
  }

  @override
  String notificationSnoozeCount(int count) {
    return '[!! This complete reminder has been snoozed $count of the maximum 3 times !!]';
  }

  @override
  String get notificationOpenTodayAction =>
      '[!! Open the complete Today view !!]';

  @override
  String get notificationLoadMoreAction =>
      '[!! Load more complete household notifications !!]';

  @override
  String get notificationLoadMoreError =>
      '[!! More complete notifications could not be safely loaded. Please try again. !!]';

  @override
  String get notificationSettingsHeading =>
      '[!! Complete notification category settings !!]';

  @override
  String get notificationSettingsBody =>
      '[!! Choose every complete channel and quiet interval in your current complete IANA timezone for every category. Quiet hours delay future push and account-email delivery but never this durable inbox. !!]';

  @override
  String get notificationInAppLabel =>
      '[!! Durable in-app notification inbox !!]';

  @override
  String get notificationInAppBody =>
      '[!! Keep complete durable items available inside this inbox. !!]';

  @override
  String get notificationNativePushLabel =>
      '[!! Native mobile push delivery preference !!]';

  @override
  String get notificationNativePushBody =>
      '[!! Save this preference now; delivery begins after a secure device registration is available. !!]';

  @override
  String get notificationEmailLabel =>
      '[!! Verified account email reminder delivery !!]';

  @override
  String get notificationEmailBody =>
      '[!! Send one deliberately generic reminder to the verified account email without any family details; this complete durable inbox safely remains available whenever delivery fails. !!]';

  @override
  String get notificationQuietHoursLabel =>
      '[!! Complete local quiet hours !!]';

  @override
  String notificationQuietHoursOff(String timezone) {
    return '[!! Quiet hours disabled in $timezone !!]';
  }

  @override
  String notificationQuietHoursSummary(
    String start,
    String end,
    String timezone,
  ) {
    return '[!! Quiet from $start until $end in $timezone !!]';
  }

  @override
  String get notificationReminderLeadLabel =>
      '[!! Complete personal Calendar reminder timing !!]';

  @override
  String get notificationReminderLeadBody =>
      '[!! Changes apply only to complete Calendar reminders that have not been delivered yet on any channel. !!]';

  @override
  String get notificationReminderLeadAtStart =>
      '[!! Exactly at the complete event time !!]';

  @override
  String notificationReminderLeadMinutesBefore(int minutes) {
    return '[!! $minutes complete expanded advance-warning minutes before the complete Calendar event begins, with extra layout pressure applied !!]';
  }

  @override
  String get notificationAdditionalRemindersLabel =>
      '[!! Additional complete Calendar reminder timings !!]';

  @override
  String get notificationAdditionalRemindersBody =>
      '[!! Carefully choose up to two more complete timings; every reminder travels through its own separately delivered path. !!]';

  @override
  String get notificationEditAction =>
      '[!! Edit complete category settings !!]';

  @override
  String notificationEditorTitle(String category) {
    return '[!! Edit complete $category settings !!]';
  }

  @override
  String get notificationQuietEnabledLabel =>
      '[!! Use complete local quiet hours !!]';

  @override
  String get notificationQuietStartLabel =>
      '[!! Complete quiet interval starts !!]';

  @override
  String get notificationQuietEndLabel =>
      '[!! Complete quiet interval ends !!]';

  @override
  String get notificationTimezoneLabel =>
      '[!! Complete recipient IANA timezone !!]';

  @override
  String get notificationTimezoneHint =>
      '[!! Carefully choose by complete IANA region or city, such as the full Asia/Seoul name. !!]';

  @override
  String get notificationTimezonePickerTitle =>
      '[!! Carefully choose the complete recipient notification timezone now !!]';

  @override
  String get notificationTimezoneValidation =>
      '[!! Choose a valid complete IANA timezone and different quiet start and end times safely. !!]';

  @override
  String get notificationSaveAction =>
      '[!! Save complete notification settings !!]';

  @override
  String get notificationCancelAction =>
      '[!! Cancel notification setting changes !!]';

  @override
  String get notificationInvalidInputError =>
      '[!! Carefully check every notification setting and try again safely. !!]';

  @override
  String get notificationPermissionError =>
      '[!! This complete notification inbox or household is no longer safely available. Reload your secure session. !!]';

  @override
  String get notificationVersionConflictError =>
      '[!! These complete settings changed on another device. Reload the newest settings and try again. !!]';

  @override
  String get notificationSnoozeUnavailableError =>
      '[!! This complete Calendar reminder can no longer be safely snoozed. Refresh the durable notification inbox. !!]';

  @override
  String get notificationGenericError =>
      '[!! We could not load or save complete notifications. The same request remains safe to try again. !!]';

  @override
  String get notificationPushPermissionHeading =>
      '[!! Complete Android device notification permission controls !!]';

  @override
  String get notificationPushPrePromptBody =>
      '[!! KinFlow sends only generic household reminders. Every name, chore detail, and calendar detail stays outside push messages, while this complete in-app inbox always remains safely available. !!]';

  @override
  String get notificationPushEnableAction =>
      '[!! Enable complete device notifications now !!]';

  @override
  String get notificationPushDeniedBody =>
      '[!! Device notifications are currently disabled. Allow them in Android settings while this complete in-app inbox continues working safely. !!]';

  @override
  String get notificationPushOpenSettingsAction =>
      '[!! Open complete Android notification settings !!]';

  @override
  String get notificationPushAuthorizedBody =>
      '[!! Complete device notifications are enabled and securely bound to this active household. !!]';

  @override
  String get notificationPushUnavailableBody =>
      '[!! Device notifications are unavailable in this complete build. This durable in-app inbox continues working safely. !!]';

  @override
  String get notificationPushSetupError =>
      '[!! Complete device notification setup could not finish safely. Your durable in-app inbox remains entirely unaffected. !!]';

  @override
  String get notificationPushPresentationTitle =>
      '[!! Complete KinFlow household reminder !!]';

  @override
  String get notificationPushPresentationBody =>
      '[!! Open KinFlow to securely view the newest authorized household update. !!]';

  @override
  String get notificationPushChannelName =>
      '[!! Complete household reminder channel !!]';

  @override
  String get notificationPushChannelDescription =>
      '[!! Generic complete household reminders without any private details !!]';

  @override
  String get featurePolicyUnavailableError =>
      '[!! Complete household feature limits are not safely available yet. Refresh the complete household plan before trying again. !!]';

  @override
  String get featureLimitReachedError =>
      '[!! This complete household has reached the current plan limit. Review every plan detail before continuing. !!]';

  @override
  String get settingsTitle => '[!! Complete settings and controls !!]';

  @override
  String get settingsOpenAction => '[!! Open complete application settings !!]';

  @override
  String get settingsAccountSection => '[!! Complete account controls !!]';

  @override
  String get settingsHouseholdSwitchTitle =>
      '[!! Switch the complete active household !!]';

  @override
  String get settingsHouseholdSwitchSummary =>
      '[!! Review every available household and carefully choose the active one. !!]';

  @override
  String get householdSwitchTitle =>
      '[!! Complete household switching controls !!]';

  @override
  String get householdSwitchIntro =>
      '[!! Only your own complete current memberships appear with every authorized choice clearly separated. Switching safely reloads the complete Today view for the selected household and preserves expanded layout pressure. !!]';

  @override
  String get householdSwitchLoading =>
      '[!! Carefully loading every available household !!]';

  @override
  String get householdSwitchEmpty =>
      '[!! No complete available households were found for this account. !!]';

  @override
  String get householdSwitchCurrentLabel =>
      '[!! Current complete household !!]';

  @override
  String get householdSwitchRoleOwner => '[!! Complete Owner !!]';

  @override
  String get householdSwitchRoleAdmin => '[!! Complete Admin !!]';

  @override
  String get householdSwitchRoleMember => '[!! Complete Member !!]';

  @override
  String get householdSwitchConfirmTitle =>
      '[!! Switch the complete active household? !!]';

  @override
  String householdSwitchConfirmBody(String name) {
    return '[!! KinFlow will securely clear every household-bound local item and reload Today for “$name”. !!]';
  }

  @override
  String get householdSwitchConfirmAction =>
      '[!! Switch complete household !!]';

  @override
  String get householdSwitchInProgress =>
      '[!! Securely switching the complete household… !!]';

  @override
  String get householdSwitchLoadError =>
      '[!! Your complete household list could not be loaded safely. Try again. !!]';

  @override
  String get householdSwitchTargetUnavailableError =>
      '[!! That complete household is no longer available to this account. Carefully refresh every authorized household item before choosing again. !!]';

  @override
  String get householdSwitchConflictError =>
      '[!! Your active household changed somewhere else. Refresh the complete authorized household list before carefully attempting another switch. !!]';

  @override
  String get householdSwitchFeatureDisabledError =>
      '[!! Complete household changes are temporarily paused by the current safety policy. The entire current household list remains clearly visible. !!]';

  @override
  String get householdSwitchLocalStateError =>
      '[!! The server changed complete households, but this device could not safely clear every household-bound local item. Sign in again to complete secure recovery before viewing any protected household content. !!]';

  @override
  String get householdSwitchGenericError =>
      '[!! The complete household could not be switched safely on this attempt. Refresh every authorized household item and carefully try again. !!]';

  @override
  String get settingsDeleteAccountTitle =>
      '[!! Permanently delete this complete account !!]';

  @override
  String get settingsDeleteAccountSummary =>
      '[!! Carefully review eligibility, request deletion, or cancel a complete pending request. !!]';

  @override
  String get accountDeletionTitle =>
      '[!! Complete account deletion lifecycle !!]';

  @override
  String get accountDeletionLoadingLabel =>
      '[!! Carefully checking complete account deletion status !!]';

  @override
  String get accountDeletionIntroHeading =>
      '[!! What complete account deletion does !!]';

  @override
  String get accountDeletionIntroBody =>
      '[!! After the full cancellation window, your profile, sign-in identity, personal notification settings, and device credentials are securely removed with complete privacy-safe lifecycle verification. !!]';

  @override
  String get accountDeletionPreservedBody =>
      '[!! Shared household, chore, and calendar history remains available to authorized household members under a complete deleted-member label with expanded retention guidance. !!]';

  @override
  String get accountDeletionStatusHeading =>
      '[!! Latest complete deletion request !!]';

  @override
  String get accountDeletionStatusQueued =>
      '[!! Completely scheduled — cancellation remains available !!]';

  @override
  String get accountDeletionStatusVerifying =>
      '[!! Carefully verifying — cancellation remains available !!]';

  @override
  String get accountDeletionStatusProcessing =>
      '[!! Complete deletion is processing and cancellation is no longer available !!]';

  @override
  String get accountDeletionStatusCompleted =>
      '[!! Complete account deletion finished !!]';

  @override
  String get accountDeletionStatusFailed =>
      '[!! Complete account deletion safely needs another attempt !!]';

  @override
  String get accountDeletionStatusCancelled =>
      '[!! Complete account deletion cancelled !!]';

  @override
  String accountDeletionScheduledFor(String date) {
    return '[!! Complete deletion begins after $date !!]';
  }

  @override
  String accountDeletionCancellationWindow(int hours) {
    return '[!! Every new request can be cancelled for approximately $hours complete hours. !!]';
  }

  @override
  String get accountDeletionRequestAction =>
      '[!! Request complete account deletion !!]';

  @override
  String get accountDeletionCancelAction =>
      '[!! Cancel complete deletion request !!]';

  @override
  String get accountDeletionOwnerBlockTitle =>
      '[!! Transfer every household ownership first !!]';

  @override
  String accountDeletionOwnerBlockBody(int count) {
    return '[!! You still own $count complete active household(s). Transfer each one to another adult before deletion through the fully expanded member-management journey. !!]';
  }

  @override
  String get accountDeletionManageHouseholdsAction =>
      '[!! Manage complete household members !!]';

  @override
  String get accountDeletionSubscriptionTitle =>
      '[!! Complete active subscription detected !!]';

  @override
  String get accountDeletionSubscriptionBody =>
      '[!! Deleting KinFlow never cancels your App Store or Google Play subscription. Cancel it separately in the store if needed, after reviewing every complete billing consequence. !!]';

  @override
  String get accountDeletionSubscriptionAcknowledge =>
      '[!! I completely understand that account deletion does not cancel my store subscription or its continuing renewal. !!]';

  @override
  String get accountDeletionPausedTitle =>
      '[!! Complete deletion requests are temporarily paused !!]';

  @override
  String get accountDeletionPausedBody =>
      '[!! Your complete account remains fully active and unchanged. Refresh again later to carefully check new deletion request availability. !!]';

  @override
  String get accountDeletionConfirmTitle =>
      '[!! Schedule complete account deletion? !!]';

  @override
  String get accountDeletionConfirmBody =>
      '[!! This complete device signs out immediately and clears every sensitive local state. Sign in again before the full deadline if cancellation is needed. !!]';

  @override
  String get accountDeletionConfirmAction =>
      '[!! Schedule complete deletion !!]';

  @override
  String get accountDeletionConfirmCancelAction =>
      '[!! Keep complete account !!]';

  @override
  String get accountDeletionCancelConfirmTitle =>
      '[!! Cancel complete account deletion? !!]';

  @override
  String get accountDeletionCancelConfirmBody =>
      '[!! Your complete account remains fully active and this scheduled deletion request will never run or remove the identity. !!]';

  @override
  String get accountDeletionCancelConfirmAction =>
      '[!! Cancel complete deletion !!]';

  @override
  String get accountDeletionPermissionError =>
      '[!! This complete account deletion request is no longer available. Refresh your secure session. !!]';

  @override
  String get accountDeletionRecentAuthError =>
      '[!! Confirm your complete Google sign-in identity again before requesting permanent account deletion. !!]';

  @override
  String get accountDeletionRecentAuthCancelled =>
      '[!! Complete account confirmation was safely cancelled. No permanent deletion request was ever sent. !!]';

  @override
  String get accountDeletionAccountChangedError =>
      '[!! The confirmed complete Google account did not match this active KinFlow account. No permanent deletion request was sent or retained. !!]';

  @override
  String get accountDeletionOwnerTransferError =>
      '[!! Transfer every complete household you own before requesting permanent account deletion. !!]';

  @override
  String get accountDeletionSubscriptionError =>
      '[!! Acknowledge the complete active store subscription and continuing-renewal notice before continuing. !!]';

  @override
  String get accountDeletionPendingError =>
      '[!! A complete account deletion request is already pending. Refresh to view its newest safe lifecycle status. !!]';

  @override
  String get accountDeletionConflictError =>
      '[!! This complete deletion request changed safely on another device. Refresh the newest status before trying again. !!]';

  @override
  String get accountDeletionPausedError =>
      '[!! Complete account deletion requests are temporarily paused while your account remains fully active and unchanged. !!]';

  @override
  String get accountDeletionGenericError =>
      '[!! We could not load or update complete account deletion status. It remains safe to try again. !!]';

  @override
  String get settingsDataExportTitle =>
      '[!! Download every piece of my complete personal data !!]';

  @override
  String get settingsDataExportSummary =>
      '[!! Create complete private JSON and highly readable text copies of your own personal KinFlow data. !!]';

  @override
  String get dataExportTitle => '[!! Download my complete personal data !!]';

  @override
  String get dataExportLoadingLabel =>
      '[!! Carefully checking complete personal data export status !!]';

  @override
  String get dataExportIntroHeading =>
      '[!! Your complete personal KinFlow data archive !!]';

  @override
  String get dataExportIntroBody =>
      '[!! This complete export includes your profile, active memberships, authored items, participation and completion records, notification settings, and a provider-identifier-free billing summary. All included sections stay clearly labeled for careful review. !!]';

  @override
  String get dataExportScopeBody =>
      '[!! It completely excludes other household member profiles and the full shared household archive, which remains a separate Owner workflow. No unrelated family identity is copied into this personal package. !!]';

  @override
  String dataExportRetentionBody(int hours, int minutes) {
    return '[!! Finished private files expire after approximately $hours hours. Every one-time download link expires after $minutes minutes and works only once. !!]';
  }

  @override
  String get dataExportStatusHeading =>
      '[!! Latest complete personal export !!]';

  @override
  String get dataExportStatusQueued => '[!! Complete export safely queued !!]';

  @override
  String get dataExportStatusVerifying =>
      '[!! Complete export carefully verifying !!]';

  @override
  String get dataExportStatusProcessing =>
      '[!! Creating complete private files now !!]';

  @override
  String get dataExportStatusCompleted =>
      '[!! Complete personal export is fully ready !!]';

  @override
  String get dataExportStatusFailed =>
      '[!! This complete personal export could not finish safely !!]';

  @override
  String get dataExportStatusCancelled =>
      '[!! Complete export request cancelled !!]';

  @override
  String get dataExportRequestAction =>
      '[!! Create complete personal export !!]';

  @override
  String get dataExportCancelAction => '[!! Cancel complete export request !!]';

  @override
  String get dataExportDownloadHeading =>
      '[!! Complete private one-time downloads !!]';

  @override
  String get dataExportDownloadBody =>
      '[!! Confirm the complete account again to create a fresh one-time link that opens in the browser or download application without storing the link inside KinFlow. !!]';

  @override
  String get dataExportJsonAction =>
      '[!! Download complete machine-readable JSON !!]';

  @override
  String get dataExportTextAction =>
      '[!! Download complete highly readable text !!]';

  @override
  String dataExportExpiresAt(String date) {
    return '[!! Complete private files expire $date !!]';
  }

  @override
  String dataExportFileSizes(String jsonSize, String textSize) {
    return '[!! Complete JSON $jsonSize · complete text $textSize !!]';
  }

  @override
  String dataExportBytes(String count) {
    return '[!! $count complete bytes !!]';
  }

  @override
  String dataExportKilobytes(String count) {
    return '[!! $count complete kilobytes !!]';
  }

  @override
  String dataExportMegabytes(String count) {
    return '[!! $count complete megabytes !!]';
  }

  @override
  String dataExportOpenedMessage(String format) {
    return '[!! The complete $format one-time download opened. Request another complete link if the file is needed again, and do not reuse the previous link. !!]';
  }

  @override
  String get dataExportJsonFormat => '[!! complete JSON !!]';

  @override
  String get dataExportTextFormat => '[!! complete text !!]';

  @override
  String get dataExportRevokeAction =>
      '[!! Permanently delete complete export files now !!]';

  @override
  String get dataExportRevokedBody =>
      '[!! These complete export files were revoked and queued for secure permanent removal without delay. !!]';

  @override
  String get dataExportPurgedBody =>
      '[!! These complete export files were securely and permanently removed. !!]';

  @override
  String get dataExportExpiredBody =>
      '[!! These complete export files expired safely. Create a fresh export if another copy is needed. !!]';

  @override
  String get dataExportRequestsPausedTitle =>
      '[!! Complete new exports are temporarily paused !!]';

  @override
  String get dataExportRequestsPausedBody =>
      '[!! Your complete data remains unchanged. Refresh later to carefully check export availability. No personal content was changed. !!]';

  @override
  String get dataExportConflictingRequestBody =>
      '[!! Another complete privacy request is processing. Finish or cancel it before creating this export. No second job will begin meanwhile. !!]';

  @override
  String get dataExportDownloadsPausedBody =>
      '[!! Complete downloads are temporarily paused while the private file remains protected until expiry or deletion. No new one-time link will be issued during this pause. !!]';

  @override
  String get dataExportConfirmTitle =>
      '[!! Create a complete personal export? !!]';

  @override
  String get dataExportConfirmBody =>
      '[!! Confirm the complete Google account before KinFlow creates private JSON and readable text files after the account confirmation succeeds. !!]';

  @override
  String get dataExportConfirmAction => '[!! Create complete export !!]';

  @override
  String get dataExportDismissAction => '[!! Not completely now !!]';

  @override
  String get dataExportCancelConfirmTitle =>
      '[!! Cancel this complete export? !!]';

  @override
  String get dataExportCancelConfirmBody =>
      '[!! The complete queued job will stop and no private download files will be created. !!]';

  @override
  String get dataExportCancelConfirmAction => '[!! Cancel complete export !!]';

  @override
  String get dataExportRevokeConfirmTitle =>
      '[!! Delete these complete export files now? !!]';

  @override
  String get dataExportRevokeConfirmBody =>
      '[!! Every outstanding link stops working and complete private files enter permanent removal immediately, and they cannot be downloaded again from any outstanding link. !!]';

  @override
  String get dataExportRevokeConfirmAction => '[!! Delete complete files !!]';

  @override
  String get dataExportPermissionError =>
      '[!! This complete export is no longer available to this account. Refresh the secure session. !!]';

  @override
  String get dataExportRecentAuthError =>
      '[!! Confirm the complete Google sign-in again before creating or downloading this export. No action is sent before confirmation. !!]';

  @override
  String get dataExportRecentAuthCancelled =>
      '[!! Complete account confirmation was cancelled and no export action was sent. !!]';

  @override
  String get dataExportAccountChangedError =>
      '[!! The confirmed complete Google account did not match this KinFlow account, so no export action was sent. The mismatch remains fail-closed. !!]';

  @override
  String get dataExportPendingError =>
      '[!! Another complete privacy request is pending. Refresh its newest status before continuing. No duplicate export job will be created. !!]';

  @override
  String get dataExportConflictError =>
      '[!! This complete export changed elsewhere. Refresh the newest status before trying again. No stale version will be changed. !!]';

  @override
  String get dataExportPausedError =>
      '[!! Complete new personal exports are temporarily paused while all data remains unchanged. !!]';

  @override
  String get dataExportDownloadsPausedError =>
      '[!! Complete personal export downloads are temporarily paused. Carefully try again later. !!]';

  @override
  String get dataExportUnavailableError =>
      '[!! This complete private export expired, was revoked, or became unavailable. Create a fresh complete export if needed. The previous one-time link cannot be reused. !!]';

  @override
  String get dataExportTooLargeError =>
      '[!! This complete account exceeds the safe single-file export boundary. Contact support for a carefully assisted export. !!]';

  @override
  String get dataExportLaunchError =>
      '[!! The complete download application could not open. Request a fresh one-time link and try again. !!]';

  @override
  String get dataExportGenericError =>
      '[!! We could not load or update the complete personal export. It remains safe to try again. !!]';

  @override
  String get settingsHouseholdPrivacyTitle =>
      '[!! Complete household data and permanent deletion controls !!]';

  @override
  String get settingsHouseholdPrivacySummary =>
      '[!! Current Owners can export all shared data or carefully schedule household deletion !!]';

  @override
  String get householdPrivacyTitle =>
      '[!! Complete household data and permanent deletion controls !!]';

  @override
  String get householdPrivacyLoadingLabel =>
      '[!! Carefully checking current Owner access and complete household privacy status… !!]';

  @override
  String get householdPrivacyIntroHeading =>
      '[!! Current Owner-only sensitive controls !!]';

  @override
  String get householdPrivacyIntroBody =>
      '[!! These complete controls affect all shared household data and every current member. KinFlow carefully and securely checks current Owner access on the server for every single action. !!]';

  @override
  String householdPrivacyMemberCount(int count) {
    return '[!! Complete current household members: $count people !!]';
  }

  @override
  String householdPrivacyExportRetention(int hours, int minutes) {
    return '[!! Complete private export files expire after approximately $hours hours. Every one-time link lasts only $minutes minutes. !!]';
  }

  @override
  String householdPrivacyDeletionWindow(int hours) {
    return '[!! A complete deletion request can be cancelled for approximately $hours hours before secure background removal begins. !!]';
  }

  @override
  String get householdPrivacyExportHeading =>
      '[!! Export all complete shared household data !!]';

  @override
  String get householdPrivacyExportBody =>
      '[!! Securely create private JSON and highly readable text files containing complete household metadata, current members, chores, calendar data, and a carefully provider-free billing summary. !!]';

  @override
  String get householdPrivacyExportAction =>
      '[!! Create complete household export files !!]';

  @override
  String get householdPrivacyDeleteHeading =>
      '[!! Permanently delete this complete household !!]';

  @override
  String get householdPrivacyDeleteBody =>
      '[!! Deletion permanently removes all member access, redacts complete shared content, revokes every invite, and unlinks billing access. Member accounts and Store subscriptions remain completely separate and are never automatically cancelled. !!]';

  @override
  String get householdPrivacyDeleteAction =>
      '[!! Carefully schedule permanent household deletion !!]';

  @override
  String get householdPrivacySubscriptionWarning =>
      '[!! This household has a complete active subscription assignment. Deleting the household never cancels the Store subscription automatically or separately. !!]';

  @override
  String get householdPrivacyStatusHeading =>
      '[!! Latest complete household privacy request status !!]';

  @override
  String get householdPrivacyExportKind =>
      '[!! Complete household export request !!]';

  @override
  String get householdPrivacyDeletionKind =>
      '[!! Complete household deletion request !!]';

  @override
  String get householdPrivacyStatusQueued =>
      '[!! Securely queued during the complete cancellation window !!]';

  @override
  String get householdPrivacyStatusVerifying =>
      '[!! Carefully verifying the current Owner and every request condition !!]';

  @override
  String get householdPrivacyStatusProcessing =>
      '[!! Secure background processing is currently in progress !!]';

  @override
  String get householdPrivacyStatusCompleted =>
      '[!! Complete request successfully completed !!]';

  @override
  String get householdPrivacyStatusFailed =>
      '[!! The complete request could not be safely completed !!]';

  @override
  String get householdPrivacyStatusCancelled =>
      '[!! Complete request safely cancelled !!]';

  @override
  String get householdPrivacyCancelAction =>
      '[!! Cancel complete queued request !!]';

  @override
  String get householdPrivacyDownloadHeading =>
      '[!! Complete private household file downloads !!]';

  @override
  String get householdPrivacyDownloadBody =>
      '[!! Every secure link works exactly once. KinFlow never keeps the raw link in application state or persistent storage. !!]';

  @override
  String get householdPrivacyRevokeAction =>
      '[!! Permanently delete complete household export files now !!]';

  @override
  String get householdPrivacyRetentionBlocked =>
      '[!! Complete deletion is securely paused by a retention hold. Member access is not removed while the hold remains active. !!]';

  @override
  String householdPrivacyRetentionReview(String date) {
    return '[!! Complete retention review timestamp: $date !!]';
  }

  @override
  String householdPrivacyOpenedMessage(String format) {
    return '[!! The complete $format one-time household download opened successfully. !!]';
  }

  @override
  String get householdPrivacyExportConfirmTitle =>
      '[!! Create a complete household export now? !!]';

  @override
  String get householdPrivacyExportConfirmBody =>
      '[!! Carefully confirm the same Google account before KinFlow securely creates complete private JSON and highly readable text files for this household. !!]';

  @override
  String get householdPrivacyCancelConfirmTitle =>
      '[!! Cancel this complete privacy request? !!]';

  @override
  String get householdPrivacyCancelConfirmBody =>
      '[!! The complete queued request stops safely. A request already processing can no longer be cancelled at all. !!]';

  @override
  String get householdPrivacyRevokeConfirmTitle =>
      '[!! Permanently delete these complete household export files now? !!]';

  @override
  String get householdPrivacyRevokeConfirmBody =>
      '[!! Every outstanding link immediately stops working and both complete private files enter secure permanent removal without recovery. !!]';

  @override
  String get householdPrivacyDeleteConfirmTitle =>
      '[!! Permanently delete this complete household and shared data? !!]';

  @override
  String get householdPrivacyDeleteConfirmBody =>
      '[!! Type the exact complete household name and confirm every irreversible impact. Then confirm the same Google account securely. !!]';

  @override
  String get householdPrivacyNameLabel =>
      '[!! Exact complete household name !!]';

  @override
  String householdPrivacyNameHint(String name) {
    return '[!! Carefully type the exact name $name !!]';
  }

  @override
  String get householdPrivacyMemberAccessAck =>
      '[!! I completely understand every current member permanently loses access to this household. !!]';

  @override
  String get householdPrivacyRedactionAck =>
      '[!! I completely understand shared chores, calendar content, names, and endpoint material are irreversibly redacted or removed without recovery or undo. !!]';

  @override
  String get householdPrivacySubscriptionAck =>
      '[!! I completely understand this never cancels the Store subscription, which must be managed separately inside the Store. !!]';

  @override
  String get householdPrivacyDeleteConfirmAction =>
      '[!! Confirm every impact and schedule permanent deletion !!]';

  @override
  String get householdPrivacyPermissionError =>
      '[!! Only the complete current household Owner can use these controls. Refresh securely if ownership changed. !!]';

  @override
  String get householdPrivacyRecentAuthError =>
      '[!! Securely confirm the complete same Google account again before this sensitive household action. !!]';

  @override
  String get householdPrivacyRecentAuthCancelled =>
      '[!! Complete account confirmation was cancelled. No household action was sent at all. !!]';

  @override
  String get householdPrivacyAccountChangedError =>
      '[!! The confirmed complete Google account did not match this KinFlow account. No sensitive household action was sent at all. !!]';

  @override
  String get householdPrivacyPausedError =>
      '[!! This complete household privacy action is temporarily paused while all shared data remains unchanged. !!]';

  @override
  String get householdPrivacyPendingError =>
      '[!! Another complete household privacy request is processing. Refresh its newest status before continuing. !!]';

  @override
  String get householdPrivacyConflictError =>
      '[!! This complete household or request changed elsewhere. Refresh the newest state before carefully trying again. !!]';

  @override
  String get householdPrivacyConfirmationError =>
      '[!! The typed complete household name no longer matches. Carefully refresh and enter the current exact name. !!]';

  @override
  String get householdPrivacySubscriptionAckError =>
      '[!! Acknowledge completely that household deletion never cancels the active Store subscription separately. !!]';

  @override
  String get householdPrivacyArtifactError =>
      '[!! This complete household export expired, was revoked, or became unavailable. Securely create a fresh export if needed. !!]';

  @override
  String get householdPrivacyDeletedError =>
      '[!! This complete household was already deleted. Carefully refresh to select or create another household safely. !!]';

  @override
  String get householdPrivacyLaunchError =>
      '[!! The complete download application could not open. Request a fresh one-time link and carefully try again. !!]';

  @override
  String get householdPrivacyGenericError =>
      '[!! We could not load or update complete household privacy controls. It remains safe to carefully try again. !!]';

  @override
  String get settingsProfilePreferencesTitle =>
      '[!! Complete personal profile and regional preference controls !!]';

  @override
  String get settingsProfilePreferencesSummary =>
      '[!! Carefully update your display name, built-in avatar, language, and complete timezones !!]';

  @override
  String get profilePreferencesTitle =>
      '[!! Complete profile and regional preference controls !!]';

  @override
  String get profilePreferencesLoadingLabel =>
      '[!! Carefully loading your complete profile and current household timezone… !!]';

  @override
  String get profilePreferencesIntroHeading =>
      '[!! Your carefully minimal KinFlow personal profile !!]';

  @override
  String get profilePreferencesIntroBody =>
      '[!! Use a complete display name and optional built-in avatar. KinFlow never requires a legal name, birthday, or unnecessary additional personal details for this profile. !!]';

  @override
  String get profilePreferencesProfileHeading =>
      '[!! Complete personal profile details !!]';

  @override
  String get profilePreferencesDisplayNameLabel =>
      '[!! Complete visible display name !!]';

  @override
  String get profilePreferencesDisplayNameValidation =>
      '[!! Enter between 1 and 80 complete visible characters without hidden controls. !!]';

  @override
  String get profilePreferencesAvatarHeading =>
      '[!! Carefully selected built-in avatar symbol !!]';

  @override
  String get profilePreferencesAvatarNone => '[!! No complete avatar !!]';

  @override
  String get profilePreferencesAvatarSun => '[!! Bright complete sun !!]';

  @override
  String get profilePreferencesAvatarHeart => '[!! Friendly complete heart !!]';

  @override
  String get profilePreferencesAvatarLeaf => '[!! Natural complete leaf !!]';

  @override
  String get profilePreferencesAvatarStar => '[!! Bright complete star !!]';

  @override
  String get profilePreferencesRegionalHeading =>
      '[!! Complete application language and personal timezone preferences !!]';

  @override
  String get timezonePreviewHeading =>
      '[!! Complete current regional date and time preview for every timezone choice !!]';

  @override
  String get timezonePreviewBody =>
      '[!! This complete preview carefully uses every unsaved language and timezone choice without changing stored preferences. Refresh it explicitly to compare a completely new current instant and offset snapshot. !!]';

  @override
  String get timezonePreviewPersonalLabel =>
      '[!! Complete personal date and time preview !!]';

  @override
  String get timezonePreviewHouseholdLabel =>
      '[!! Complete shared household date and time preview !!]';

  @override
  String get timezonePreviewRefreshAction =>
      '[!! Carefully refresh the complete regional date and time preview now !!]';

  @override
  String get timezonePreviewLoadingLabel =>
      '[!! Carefully preparing the complete current regional date and time preview now… !!]';

  @override
  String get timezonePreviewLoadFailure =>
      '[!! The complete regional preview could not be refreshed safely. Every unsaved language and timezone choice remains entirely unchanged. !!]';

  @override
  String timezonePreviewMissingTimezone(String timezone) {
    return '[!! The exact timezone $timezone is not present in the complete bundled timezone list, so no potentially incorrect device-time fallback is displayed. !!]';
  }

  @override
  String timezonePreviewSemantics(
    String label,
    String timezone,
    String date,
    String time,
    String metadata,
  ) {
    return '[!! Complete $label. Exact timezone $timezone. Localized date $date. Localized time $time. Current metadata $metadata. !!]';
  }

  @override
  String timezonePreviewUnavailableSemantics(String label, String timezone) {
    return '[!! Complete $label. The exact timezone $timezone has no safe bundled preview and is never silently replaced. !!]';
  }

  @override
  String get profilePreferencesLanguageLabel =>
      '[!! Complete application language !!]';

  @override
  String get profilePreferencesLanguageEnglish =>
      '[!! Complete English language !!]';

  @override
  String get profilePreferencesLanguageKorean =>
      '[!! Complete Korean language 한국어 !!]';

  @override
  String get profilePreferencesPersonalTimezoneLabel =>
      '[!! Complete personal IANA timezone !!]';

  @override
  String get profilePreferencesPersonalTimezoneHelper =>
      '[!! Carefully choose a complete IANA region or city. This becomes your visible personal default timezone everywhere. !!]';

  @override
  String get profilePreferencesPersonalTimezonePickerTitle =>
      '[!! Carefully choose your complete personal IANA timezone now !!]';

  @override
  String get profilePreferencesTimezoneValidation =>
      '[!! Carefully choose a complete valid IANA timezone such as Asia/Seoul or UTC. !!]';

  @override
  String get profilePreferencesHouseholdHeading =>
      '[!! Complete household default timezone controls !!]';

  @override
  String get profilePreferencesHouseholdTimezoneLabel =>
      '[!! Complete household IANA timezone !!]';

  @override
  String get profilePreferencesHouseholdTimezoneHelper =>
      '[!! Current Owners and Admins can carefully choose the complete default used by household dates and every newly created item. !!]';

  @override
  String get profilePreferencesHouseholdTimezonePickerTitle =>
      '[!! Carefully choose the complete household IANA timezone now !!]';

  @override
  String profilePreferencesHouseholdTimezoneReadOnly(String timezone) {
    return '[!! Complete timezone $timezone · Only the current Owner or Admin can carefully change this household default. !!]';
  }

  @override
  String get profilePreferencesImpactHeading =>
      '[!! Carefully understand every household timezone change impact !!]';

  @override
  String get profilePreferencesImpactBody =>
      '[!! It immediately and visibly changes the household-local Today boundary, defaults for every new item, and notification preferences that still inherit the complete household default across every household view. !!]';

  @override
  String get profilePreferencesImpactPreservedBody =>
      '[!! Every existing repeating chore and calendar series carefully keeps its previously saved timezone and canonical occurrence instants without reinterpretation. !!]';

  @override
  String get profilePreferencesSaveAction =>
      '[!! Carefully save complete profile and regional settings !!]';

  @override
  String get profilePreferencesSavedMessage =>
      '[!! Complete profile and regional settings were saved successfully. !!]';

  @override
  String get profilePreferencesConfirmTimezoneTitle =>
      '[!! Change the complete household timezone now? !!]';

  @override
  String get profilePreferencesConfirmTimezoneBody =>
      '[!! Today boundaries and every new default change immediately. Existing repeating items carefully keep their saved timezone and canonical instants without reinterpretation. !!]';

  @override
  String get profilePreferencesConfirmTimezoneAction =>
      '[!! Confirm timezone change and save everything !!]';

  @override
  String get profilePreferencesCancelAction =>
      '[!! Completely cancel this change !!]';

  @override
  String get timezonePickerCloseAction =>
      '[!! Completely close the timezone selection panel !!]';

  @override
  String get timezonePickerCurrentLabel =>
      '[!! Complete current timezone selection remains unchanged !!]';

  @override
  String get timezonePickerSearchLabel =>
      '[!! Carefully search every timezone by region or city name !!]';

  @override
  String get timezonePickerSearchHelper =>
      '[!! Try a complete place such as Seoul, New York, or the entire Europe region. !!]';

  @override
  String get timezonePickerClearSearchAction =>
      '[!! Completely clear the current timezone search text !!]';

  @override
  String get timezonePickerLoadingLabel =>
      '[!! Carefully loading the complete bundled IANA timezone database now… !!]';

  @override
  String get timezonePickerLoadFailure =>
      '[!! The complete timezone list could not be loaded. Your current safe selection remains entirely unchanged. !!]';

  @override
  String get timezonePickerEmptyLabel =>
      '[!! No complete bundled IANA timezone matches this careful search. !!]';

  @override
  String get timezonePickerDaylightSavingLabel =>
      '[!! currently observing complete daylight saving time !!]';

  @override
  String get timezonePickerStandardTimeLabel =>
      '[!! currently observing complete standard time !!]';

  @override
  String timezonePickerMetadata(String offset, String clockKind) {
    return '[!! Complete UTC$offset · $clockKind !!]';
  }

  @override
  String get profilePreferencesErrorUnauthenticated =>
      '[!! Sign in completely again before loading or changing this personal profile. !!]';

  @override
  String get profilePreferencesErrorInvalidInput =>
      '[!! Carefully check the complete display name, avatar, language, and every IANA timezone value. !!]';

  @override
  String get profilePreferencesErrorUnavailable =>
      '[!! This complete profile or active household is no longer available. Carefully refresh the authenticated session. !!]';

  @override
  String get profilePreferencesErrorForbidden =>
      '[!! Only the complete current Owner or Admin can change the household timezone. None of your personal changes were saved, so carefully reload every authoritative setting. !!]';

  @override
  String get profilePreferencesErrorProfileConflict =>
      '[!! Your complete profile changed somewhere else. Reload the newest authoritative version before saving again. !!]';

  @override
  String get profilePreferencesErrorHouseholdConflict =>
      '[!! The complete household timezone changed somewhere else. Reload the newest authoritative version before saving again. !!]';

  @override
  String get profilePreferencesErrorTemporarilyUnavailable =>
      '[!! Complete profile settings are temporarily unavailable. Every previous value remains safely and completely unchanged. !!]';

  @override
  String get profilePreferencesErrorInvalidPayload =>
      '[!! KinFlow received an unexpected complete settings response and safely refused to apply any value. !!]';

  @override
  String get profilePreferencesErrorInternal =>
      '[!! We could not load or save these complete settings. It remains safe to carefully try again. !!]';

  @override
  String get settingsSubscriptionTitle =>
      '[!! Complete household subscription and Plus controls !!]';

  @override
  String get settingsSubscriptionSummary =>
      '[!! Carefully inspect this household\'s authoritative plan, purchase or restore Plus, and safely manage complete billing !!]';

  @override
  String get subscriptionTitle =>
      '[!! Complete household subscription and Plus controls !!]';

  @override
  String get subscriptionLoading =>
      '[!! Carefully loading the complete server-confirmed household subscription status without assumptions… !!]';

  @override
  String get subscriptionHouseholdFallback =>
      '[!! Complete currently active household context !!]';

  @override
  String get subscriptionStatusHeading =>
      '[!! Complete current household subscription status !!]';

  @override
  String get subscriptionHouseholdLabel =>
      '[!! Current authoritative household !!]';

  @override
  String get subscriptionPlanLabel => '[!! Complete household plan !!]';

  @override
  String get subscriptionLifecycleLabel =>
      '[!! Complete subscription lifecycle status !!]';

  @override
  String get subscriptionSourceLabel => '[!! Authoritative billing source !!]';

  @override
  String get subscriptionBillingOwnerLabel =>
      '[!! Current subscription billing owner relationship !!]';

  @override
  String get subscriptionBillingOwnerNone =>
      '[!! No complete subscription billing owner exists for this Free household !!]';

  @override
  String get subscriptionPeriodLabel =>
      '[!! Complete Store billing period information !!]';

  @override
  String get subscriptionVerifiedLabel =>
      '[!! Authoritatively verified by the server !!]';

  @override
  String get subscriptionPlanFree => '[!! Complete Free household plan !!]';

  @override
  String get subscriptionPlanPlus => '[!! Complete Plus household plan !!]';

  @override
  String get subscriptionStatusNone =>
      '[!! No complete active Plus subscription exists !!]';

  @override
  String get subscriptionStatusTrialing =>
      '[!! Complete Plus trial currently active !!]';

  @override
  String get subscriptionStatusActive =>
      '[!! Complete subscription currently active !!]';

  @override
  String get subscriptionStatusGrace =>
      '[!! Complete payment retry grace period active !!]';

  @override
  String get subscriptionStatusBillingIssue =>
      '[!! Complete Store billing needs careful attention !!]';

  @override
  String get subscriptionStatusExpired =>
      '[!! Complete Plus access has expired !!]';

  @override
  String get subscriptionStatusRevoked =>
      '[!! Complete Plus access revoked or refunded !!]';

  @override
  String get subscriptionSourceNone =>
      '[!! No complete billing source exists !!]';

  @override
  String get subscriptionSourcePlayStore =>
      '[!! Complete Google Play billing source !!]';

  @override
  String get subscriptionSourceAppStore =>
      '[!! Complete Apple App Store billing source !!]';

  @override
  String get subscriptionSourceWeb =>
      '[!! Complete secure web billing source !!]';

  @override
  String get subscriptionSourceSupport =>
      '[!! Complete KinFlow support assignment source !!]';

  @override
  String get subscriptionBillingOwnerYou =>
      '[!! You currently and completely manage this subscription billing relationship !!]';

  @override
  String get subscriptionBillingOwnerOther =>
      '[!! Another current household member completely manages this subscription !!]';

  @override
  String subscriptionRenewsOn(String date) {
    return '[!! Complete Store subscription renews on $date unless cancelled there !!]';
  }

  @override
  String subscriptionAccessThrough(String date) {
    return '[!! Complete current Plus access remains available through $date without renewal !!]';
  }

  @override
  String get subscriptionNoPeriodEnd =>
      '[!! No complete billing period end was reported by the server !!]';

  @override
  String subscriptionVerifiedAt(String date) {
    return '[!! Complete server-authoritative status carefully checked on $date !!]';
  }

  @override
  String get subscriptionLifecycleTrialing =>
      '[!! Your complete Plus trial is currently active. The Store may automatically renew it unless the billing owner carefully cancels it there. !!]';

  @override
  String get subscriptionLifecycleGrace =>
      '[!! Complete Plus remains available while the Store carefully retries payment. Review the complete payment method inside the authoritative Store. !!]';

  @override
  String get subscriptionLifecycleBillingIssue =>
      '[!! The Store reported a complete billing problem. Every existing household record remains safely preserved while you review billing in the Store. !!]';

  @override
  String get subscriptionLifecycleExpired =>
      '[!! Complete Plus access ended. Every existing household record remains safely preserved, while server-confirmed Free-plan limits apply only to new expansion. !!]';

  @override
  String get subscriptionLifecycleRevoked =>
      '[!! Complete Plus access was revoked or refunded. Every existing household record remains safely preserved, while server-confirmed Free-plan limits apply only to new expansion. !!]';

  @override
  String get subscriptionBenefitsHeading =>
      '[!! Complete Plus household benefit categories !!]';

  @override
  String get subscriptionBenefitMembers =>
      '[!! More complete room for carefully managed household members !!]';

  @override
  String get subscriptionBenefitRecurring =>
      '[!! More complete active recurring chore and calendar series for this household !!]';

  @override
  String get subscriptionBenefitData =>
      '[!! Every existing household record stays completely preserved if Plus eventually ends !!]';

  @override
  String get subscriptionLimitsPending =>
      '[!! Complete final prices and numeric limits come only from the authoritative Store and server. No unconfirmed numeric limit is ever invented or displayed here. !!]';

  @override
  String get subscriptionOffersHeading =>
      '[!! Carefully choose a complete current Store option !!]';

  @override
  String subscriptionPackagePrice(String price, String period) {
    return '[!! Exact Store price $price · billed completely $period !!]';
  }

  @override
  String subscriptionPeriodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! completely every $count days !!]',
      one: '[!! completely every single day !!]',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! completely every $count weeks !!]',
      one: '[!! completely every single week !!]',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! completely every $count months !!]',
      one: '[!! completely every single month !!]',
    );
    return '$_temp0';
  }

  @override
  String subscriptionPeriodYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '[!! completely every $count years !!]',
      one: '[!! completely every single year !!]',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionPurchaseAction =>
      '[!! Carefully continue to the complete Store purchase flow !!]';

  @override
  String get subscriptionRestoreAction =>
      '[!! Carefully restore complete purchases from the Store !!]';

  @override
  String get subscriptionManageAction =>
      '[!! Safely manage the complete subscription inside the authoritative Store !!]';

  @override
  String get subscriptionRefreshAction =>
      '[!! Carefully refresh complete server-authoritative status !!]';

  @override
  String get subscriptionReturnAction =>
      '[!! Return carefully to complete household subscription options !!]';

  @override
  String get subscriptionSupportAction =>
      '[!! Securely contact complete KinFlow billing support !!]';

  @override
  String get subscriptionTermsAction =>
      '[!! Review complete public service terms !!]';

  @override
  String get subscriptionPrivacyAction =>
      '[!! Review complete public privacy information !!]';

  @override
  String get subscriptionAdminRequired =>
      '[!! Only a complete active household Owner or Admin can purchase or restore Plus. You can still carefully inspect the current server-confirmed status without changing anything. !!]';

  @override
  String get subscriptionProfileUnavailable =>
      '[!! KinFlow could not authoritatively verify your complete active household role. Refresh profile settings before carefully purchasing or restoring anything. !!]';

  @override
  String get subscriptionStoreUnavailable =>
      '[!! Complete Store options are temporarily unavailable. The server-confirmed household status remains safely visible above without assumptions or replacement. !!]';

  @override
  String get subscriptionPurchaseConfirmTitle =>
      '[!! Carefully confirm this complete household purchase !!]';

  @override
  String subscriptionPurchaseConfirmBody(
    String household,
    String price,
    String period,
  ) {
    return '[!! Buy complete Plus specifically for $household at the exact Store price $price, billed $period, after reviewing every consequence? !!]';
  }

  @override
  String get subscriptionPurchaseConfirmRenewal =>
      '[!! The authoritative Store may repeatedly renew and charge this complete subscription until its billing owner carefully cancels it there. !!]';

  @override
  String get subscriptionPurchaseConfirmServer =>
      '[!! Store success alone is never final access. KinFlow carefully waits for authoritative server confirmation before enabling any complete Plus benefit. !!]';

  @override
  String get subscriptionPurchaseConfirmAction =>
      '[!! Carefully confirm every detail and open the Store !!]';

  @override
  String get subscriptionRestoreConfirmTitle =>
      '[!! Carefully restore complete purchases for this household? !!]';

  @override
  String subscriptionRestoreConfirmBody(String household) {
    return '[!! KinFlow carefully checks complete Store purchases specifically for $household. It never automatically transfers a subscription away from another household under any circumstance. !!]';
  }

  @override
  String get subscriptionRestoreConfirmConflict =>
      '[!! If any purchase is assigned elsewhere, KinFlow safely stops and offers a complete support review without exposing customer, transaction, product, or billing identifiers. !!]';

  @override
  String get subscriptionRestoreConfirmAction =>
      '[!! Carefully confirm complete Store restoration !!]';

  @override
  String get subscriptionCancelAction =>
      '[!! Completely cancel and close this confirmation !!]';

  @override
  String get subscriptionPreparingPurchase =>
      '[!! Carefully checking that this complete subscription can be safely assigned before opening or contacting the Store at all… !!]';

  @override
  String get subscriptionPreparingRestore =>
      '[!! Carefully checking that complete restored purchases can be safely assigned specifically to this active household… !!]';

  @override
  String get subscriptionPurchasing =>
      '[!! Carefully waiting for the complete authoritative Store purchase result without assuming success… !!]';

  @override
  String get subscriptionRestoring =>
      '[!! Carefully checking complete purchases with the authoritative Store without changing household access yet… !!]';

  @override
  String get subscriptionStorePending =>
      '[!! The authoritative Store is still completely processing this request. Purchase and restore controls remain paused to prevent every possible duplicate action. !!]';

  @override
  String get subscriptionServerPending =>
      '[!! The Store responded, but KinFlow has not received complete authoritative server confirmation yet. Carefully refresh status and never purchase again during this state. !!]';

  @override
  String get subscriptionRestoreEmptyTitle =>
      '[!! No complete restorable Store purchase was found !!]';

  @override
  String get subscriptionRestoreEmptyBody =>
      '[!! The authoritative Store did not return a complete Plus purchase for this account. No household subscription, ownership, access, or data changed at all. !!]';

  @override
  String get subscriptionConflictTitle =>
      '[!! Complete subscription assignment needs careful review !!]';

  @override
  String get subscriptionConflictBody =>
      '[!! KinFlow safely stopped before contacting the Store because this complete purchase or household is already linked elsewhere. No customer, transaction, product, or billing identifier appears here. !!]';

  @override
  String get subscriptionRestoreConflictBody =>
      '[!! The Store found a complete purchase, but KinFlow could not safely assign it specifically to this household. No access, ownership, billing source, or data changed. !!]';

  @override
  String get subscriptionRemediationAction =>
      '[!! Securely request a complete subscription assignment review !!]';

  @override
  String get subscriptionRemediationSubmitted =>
      '[!! A complete assignment review request is currently open. Support can carefully investigate without any billing identifiers ever appearing in this interface. !!]';

  @override
  String get subscriptionRemediationFailed =>
      '[!! The complete review request could not be sent. No Store action occurred at all; securely contact support if this careful failure continues. !!]';

  @override
  String get subscriptionNoticePurchaseCancelled =>
      '[!! The complete Store purchase was cancelled. KinFlow charged nothing and the authoritative household plan did not change at all. !!]';

  @override
  String get subscriptionNoticeAlreadyActive =>
      '[!! Complete server-confirmed Plus is already active for this current household. !!]';

  @override
  String get subscriptionNoticePurchaseConfirmed =>
      '[!! The authoritative server confirmed the complete purchase and safely updated this household\'s Plus status. !!]';

  @override
  String get subscriptionNoticeRestoreConfirmed =>
      '[!! The authoritative server confirmed the complete restored purchase specifically for this household. !!]';

  @override
  String get subscriptionNoticeServerRefreshed =>
      '[!! The newest complete server-confirmed household subscription status is now shown safely. !!]';

  @override
  String get subscriptionExternalUnavailable =>
      '[!! That complete trusted external page could not be opened. Carefully try again or use the authoritative Store application directly. !!]';

  @override
  String get subscriptionFailureUnsupported =>
      '[!! Complete Store billing is unavailable on this device. You can still carefully inspect the server-confirmed household status without changing anything. !!]';

  @override
  String get subscriptionFailureUnauthenticated =>
      '[!! Sign in completely again before loading or changing any household subscription status. !!]';

  @override
  String get subscriptionFailureIdentity =>
      '[!! KinFlow could not safely bind or clear the complete Store account identity. Sign out and back in carefully before attempting anything again. !!]';

  @override
  String get subscriptionFailureInvalidInput =>
      '[!! The complete active household context or Store option changed. Carefully refresh every authoritative value before continuing. !!]';

  @override
  String get subscriptionFailureCatalog =>
      '[!! Complete Store options could not be loaded. The server-confirmed household status remains safely available without replacement or assumptions. !!]';

  @override
  String get subscriptionFailureStore =>
      '[!! The authoritative Store could not safely complete this request. Check the Store application and refresh complete server status before carefully retrying. !!]';

  @override
  String get subscriptionFailureNetwork =>
      '[!! The complete network is unavailable. No new subscription status was assumed or invented; carefully refresh after connectivity returns. !!]';

  @override
  String get subscriptionFailureAuthorization =>
      '[!! The authoritative server safely refused this complete subscription action for the current account or active household. !!]';

  @override
  String get subscriptionFailureServer =>
      '[!! The authoritative server could not confirm this complete request. Never purchase again during uncertainty; carefully refresh status first. !!]';

  @override
  String get subscriptionFailureInvalidState =>
      '[!! KinFlow received a complete unexpected subscription state and safely refused to enable any Plus access or benefit. !!]';

  @override
  String get subscriptionFailureUnknown =>
      '[!! The complete subscription request could not be finished safely. Carefully refresh authoritative status before attempting any other billing action. !!]';

  @override
  String get settingsHelpSection =>
      '[!! Complete help, guidance, and authoritative legal resources !!]';

  @override
  String get settingsLegalSupportTitle =>
      '[!! Complete legal documents, careful privacy controls, and trusted support resources !!]';

  @override
  String get settingsLegalSupportSummary =>
      '[!! Carefully review every published authoritative document, manage complete privacy requests, or securely contact the trusted support channel. !!]';

  @override
  String get legalSupportTitle =>
      '[!! Complete legal documents, careful privacy controls, and trusted support resources !!]';

  @override
  String get legalSupportIntro =>
      '[!! Use this complete hub to carefully review KinFlow\'s authoritative published documents, securely reach support, and find every available privacy control. !!]';

  @override
  String get legalSupportDocumentVersionTitle =>
      '[!! Authoritative versions of every published legal document !!]';

  @override
  String get legalSupportDocumentVersionBody =>
      '[!! The exact publication date and version displayed on each complete linked document are authoritative. The application\'s separate technical contract version must never be interpreted as a legal policy version. !!]';

  @override
  String get legalSupportTermsTitle =>
      '[!! Complete authoritative terms of service document !!]';

  @override
  String get legalSupportTermsBody =>
      '[!! Carefully review the current complete terms for using KinFlow, including every account, household, service, and user responsibility. !!]';

  @override
  String get legalSupportTermsVersionNote =>
      '[!! Opens only the fixed trusted terms page in your external browser. Carefully inspect that complete page for its authoritative publication date and exact version. !!]';

  @override
  String get legalSupportTermsOpenAction =>
      '[!! Securely open the complete terms of service document !!]';

  @override
  String get legalSupportPrivacyTitle =>
      '[!! Complete authoritative privacy policy document !!]';

  @override
  String get legalSupportPrivacyBody =>
      '[!! Carefully review how KinFlow handles every relevant account, household, device, notification, and subscription-related data category. !!]';

  @override
  String get legalSupportPrivacyVersionNote =>
      '[!! Opens only the fixed trusted privacy page in your external browser. Carefully inspect that complete page for its authoritative publication date and exact version. !!]';

  @override
  String get legalSupportPrivacyOpenAction =>
      '[!! Securely open the complete privacy policy document !!]';

  @override
  String get legalSupportPrivacyControlsTitle =>
      '[!! Every available personal privacy request control !!]';

  @override
  String get legalSupportPrivacyControlsBody =>
      '[!! Create complete private copies of your personal data or carefully review the separate account deletion process without leaving the trusted KinFlow application. !!]';

  @override
  String get legalSupportSupportTitle =>
      '[!! Complete trusted customer support resources and guidance !!]';

  @override
  String get legalSupportSupportBody =>
      '[!! Securely open KinFlow\'s specifically configured support page for complete product, account, household, or subscription assistance. !!]';

  @override
  String get legalSupportSupportPrivacyNote =>
      '[!! KinFlow never automatically attaches your account, household, billing, diagnostic, or other private identifiers to this trusted external link. !!]';

  @override
  String get legalSupportSupportOpenAction =>
      '[!! Securely open the complete trusted support page !!]';

  @override
  String get legalSupportConsentTitle =>
      '[!! Explicit consent behavior for this informational screen !!]';

  @override
  String get legalSupportConsentBody =>
      '[!! Opening or carefully reading these complete resources never grants or withdraws consent under any circumstance. If an exact policy version ever requires a separate decision, KinFlow will ask clearly and explicitly in a dedicated flow, then record only that deliberate informed choice. !!]';

  @override
  String get legalSupportTermsResourceName =>
      '[!! the complete terms of service document !!]';

  @override
  String get legalSupportPrivacyResourceName =>
      '[!! the complete privacy policy document !!]';

  @override
  String get legalSupportSupportResourceName =>
      '[!! the complete trusted support page !!]';

  @override
  String legalSupportOpening(String resource) {
    return '[!! Carefully opening $resource in your trusted external browser without attaching any private context… !!]';
  }

  @override
  String legalSupportOpened(String resource) {
    return '[!! Successfully opened $resource in your trusted external browser without changing application state. !!]';
  }

  @override
  String get legalSupportExternalUnavailable =>
      '[!! That complete trusted external page could not be opened. Carefully check your connection or browser availability before safely trying again. !!]';

  @override
  String get settingsAnalyticsPrivacyTitle =>
      '[!! Complete optional analytics and carefully minimized data collection controls !!]';

  @override
  String get settingsAnalyticsPrivacySummary =>
      '[!! Carefully review every optional usage signal, strict collection boundary, and complete SDK purpose before making a choice. !!]';

  @override
  String get analyticsPrivacyTitle =>
      '[!! Complete optional analytics and carefully minimized data collection controls !!]';

  @override
  String get analyticsPrivacyLoading =>
      '[!! Carefully loading the complete privacy-safe analytics preference stored only for this device environment… !!]';

  @override
  String get analyticsPrivacyLoadFailed =>
      '[!! The complete analytics preference could not be loaded safely at all. Optional usage analytics remains fully off, and you may carefully try again. !!]';

  @override
  String get analyticsPrivacyIntroTitle =>
      '[!! A strictly minimized and completely optional usage signal !!]';

  @override
  String get analyticsPrivacyIntroBody =>
      '[!! This careful device setting controls only optional content-free usage events. It remains completely separate from operational error reporting and starts fully off by default. !!]';

  @override
  String get analyticsPrivacyPreferenceTitle =>
      '[!! Explicitly allow carefully minimized optional usage analytics !!]';

  @override
  String get analyticsPrivacyPreferenceBody =>
      '[!! This deliberate choice applies only to the exact analytics-usage-v1 policy on this device and environment. Any provider, purpose, field, or policy expansion requires a completely new explicit choice. !!]';

  @override
  String get analyticsPrivacyStatusOff =>
      '[!! Completely off. No optional usage event is sent anywhere at all. !!]';

  @override
  String get analyticsPrivacyStatusAvailable =>
      '[!! Explicitly allowed. Only the exact approved content-free event envelope may carefully reach the configured sink. !!]';

  @override
  String get analyticsPrivacyStatusNoSink =>
      '[!! Your deliberate choice is saved, but no external behavioral analytics sink is installed, so absolutely nothing is sent anywhere. !!]';

  @override
  String get analyticsPrivacySaving =>
      '[!! Carefully saving the complete device analytics preference without any identity or content… !!]';

  @override
  String get analyticsPrivacySaveFailed =>
      '[!! The complete preference could not be saved safely. The previous exact choice remains effective, and no raw storage error was retained or exposed. !!]';

  @override
  String get analyticsPrivacySaved =>
      '[!! The complete device analytics preference was saved safely without identity or content. !!]';

  @override
  String get analyticsPrivacyAllowlistTitle =>
      '[!! Exact complete typed event and envelope boundary !!]';

  @override
  String get analyticsPrivacyAllowlistBody =>
      '[!! KinFlow accepts only six explicitly typed product events and an exact five-field public build envelope. Every free-form event name and arbitrary attribute is rejected at the application boundary across every complete adaptive application flow. !!]';

  @override
  String get analyticsPrivacyChildPolicyTitle =>
      '[!! Complete future Managed Child privacy protection !!]';

  @override
  String get analyticsPrivacyChildPolicyBody =>
      '[!! Managed Child mode is outside the adult-only Store MVP. If separately approved and added later, every optional analytics event is blocked before preference storage or any sink can ever be accessed. !!]';

  @override
  String get analyticsPrivacyInventoryTitle =>
      '[!! Complete current inventory of every data-handling service SDK !!]';

  @override
  String get analyticsPrivacyInventoryBehavioral =>
      '[!! Behavioral analytics and advertising: no external SDK is installed anywhere in the application. !!]';

  @override
  String get analyticsPrivacyInventoryOperational =>
      '[!! Sentry: strictly privacy-filtered crashes and operational errors only; it is never reused as the optional usage analytics sink anywhere in KinFlow. !!]';

  @override
  String get analyticsPrivacyInventoryNotifications =>
      '[!! Firebase Messaging and local notifications: complete notification transport and display responsibilities only. !!]';

  @override
  String get analyticsPrivacyInventoryBilling =>
      '[!! RevenueCat: carefully bounded Store purchase and household entitlement processing only. !!]';

  @override
  String get analyticsPrivacyInventoryIdentity =>
      '[!! Google Sign-In and Supabase: authentication and application data services only, never behavioral analytics under any circumstance. !!]';

  @override
  String get analyticsPrivacyNeverCollectedTitle =>
      '[!! Every private category never included in optional analytics !!]';

  @override
  String get analyticsPrivacyNeverCollectedBody =>
      '[!! No account, household, member, or child identifier; no email, name, or family content; no token, receipt, URL, or raw error; and no location, contact, advertising identifier, or device fingerprint is ever included through any adaptive interface or configured service. !!]';

  @override
  String get settingsDiagnosticsTitle =>
      '[!! Complete privacy-safe diagnostic information for trusted support !!]';

  @override
  String get settingsDiagnosticsSummary =>
      '[!! Carefully review and explicitly copy a complete PII-free application, build, broad platform, and random incident report. !!]';

  @override
  String get diagnosticsTitle =>
      '[!! Complete privacy-safe diagnostic information for trusted support !!]';

  @override
  String get diagnosticsIntroHeading =>
      '[!! A complete local support reference created only on this device !!]';

  @override
  String get diagnosticsIntroBody =>
      '[!! KinFlow carefully creates this complete report locally on your device and never uploads its contents automatically. A separate random incident identifier may be recorded in strictly PII-filtered application diagnostics so trusted support can correlate a specific issue without receiving the report body. Explicitly copy the complete report only when you deliberately choose to share it. !!]';

  @override
  String get diagnosticsIncludedTitle =>
      '[!! Exact complete allowlist of information included in this report !!]';

  @override
  String get diagnosticsIncludedBody =>
      '[!! Application identifier, application version, build number, development or production environment, API contract date, broad platform category, random incident identifier, and UTC creation time only. !!]';

  @override
  String get diagnosticsExcludedTitle =>
      '[!! Every private or identifying category that is never included !!]';

  @override
  String get diagnosticsExcludedBody =>
      '[!! No account, household, profile, email, chore, calendar, notification, billing content, credential, network detail, device model, serial number, advertising identifier, locale, or timezone is ever included under any circumstance in this carefully minimized local support report. !!]';

  @override
  String get diagnosticsLoading =>
      '[!! Carefully creating a complete local PII-free diagnostic report without uploading anything… !!]';

  @override
  String get diagnosticsUnavailable =>
      '[!! Complete diagnostic information is temporarily unavailable. No partial report was copied, sent, persisted, or uploaded anywhere. !!]';

  @override
  String get diagnosticsInvalidMetadata =>
      '[!! The installed application metadata does not exactly match this configured build, so KinFlow safely refused to create any partial or misleading diagnostic report of any kind. !!]';

  @override
  String get diagnosticsInternal =>
      '[!! The complete diagnostic report could not be created safely. No partial report was copied, sent, persisted, or uploaded anywhere. !!]';

  @override
  String get diagnosticsReportTitle =>
      '[!! Complete exact diagnostic report preview before explicit copying !!]';

  @override
  String get diagnosticsApplicationIdLabel =>
      '[!! Complete installed application identifier !!]';

  @override
  String get diagnosticsAppVersionLabel =>
      '[!! Complete installed application version !!]';

  @override
  String get diagnosticsBuildNumberLabel =>
      '[!! Complete installed build number !!]';

  @override
  String get diagnosticsEnvironmentLabel =>
      '[!! Complete development or production environment !!]';

  @override
  String get diagnosticsContractVersionLabel =>
      '[!! Complete API contract date !!]';

  @override
  String get diagnosticsDevicePlatformLabel =>
      '[!! Broad non-identifying platform category only !!]';

  @override
  String get diagnosticsIncidentIdLabel =>
      '[!! Random report-specific incident identifier !!]';

  @override
  String get diagnosticsGeneratedAtLabel =>
      '[!! Complete report creation time in UTC !!]';

  @override
  String get diagnosticsClipboardNotice =>
      '[!! Explicit copying writes only this complete JSON report to the system clipboard without reading any existing content. Paste it only into a trusted support request, then carefully clear every copied character afterward if your device or keyboard retains any clipboard history. !!]';

  @override
  String get diagnosticsCopyAction =>
      '[!! Explicitly copy the complete PII-free diagnostic information !!]';

  @override
  String get diagnosticsNewIncidentAction =>
      '[!! Carefully create a completely new random incident identifier !!]';

  @override
  String get diagnosticsRefreshing =>
      '[!! Carefully creating a new complete local report while preserving the currently visible report unchanged… !!]';

  @override
  String get diagnosticsCopying =>
      '[!! Explicitly writing the complete PII-free JSON report to the system clipboard without reading existing content… !!]';

  @override
  String get diagnosticsCopied =>
      '[!! Complete diagnostic information was copied successfully. The complete report contents were not sent or uploaded automatically anywhere. !!]';

  @override
  String get diagnosticsCopyFailed =>
      '[!! The system clipboard could not be written safely. The complete report remains visible and its complete contents were not sent or uploaded anywhere. !!]';

  @override
  String get diagnosticsRefreshFailed =>
      '[!! A new random incident identifier could not be created. The complete previous report remains visible and unchanged. !!]';

  @override
  String get householdActivationTitle =>
      '[!! Get the complete household started safely together !!]';

  @override
  String get householdActivationBody =>
      '[!! Finish every one of these four complete milestones to establish a dependable shared household routine together. !!]';

  @override
  String get householdActivationCompleteBody =>
      '[!! Your complete household safely finished all four detailed getting-started milestones together. !!]';

  @override
  String get householdActivationLoadingLabel =>
      '[!! Refreshing complete household getting-started progress safely !!]';

  @override
  String householdActivationSummary(int completed, int total) {
    return '[!! $completed of $total complete household milestones are finished safely !!]';
  }

  @override
  String get householdActivationAdultTitle =>
      '[!! Invite a complete second adult household participant !!]';

  @override
  String householdActivationAdultProgress(int current, int goal) {
    return '[!! $current of $goal complete adults have joined this household safely. !!]';
  }

  @override
  String get householdActivationInviteAction =>
      '[!! Invite another complete adult participant !!]';

  @override
  String get householdActivationChoreTitle =>
      '[!! Create three complete shared household chores !!]';

  @override
  String householdActivationChoreProgress(int current, int goal) {
    return '[!! $current of $goal complete household chores have been created safely. !!]';
  }

  @override
  String get householdActivationCreateAction =>
      '[!! Add another complete household chore !!]';

  @override
  String get householdActivationCompletionTitle =>
      '[!! Let each complete adult finish one household chore !!]';

  @override
  String householdActivationCompletionProgress(int current, int goal) {
    return '[!! $current of $goal complete adults have finished at least one household chore safely. !!]';
  }

  @override
  String get householdActivationReturnTitle =>
      '[!! Come back to complete Today on another household day !!]';

  @override
  String get householdActivationReturnPending =>
      '[!! Open the complete Today view again after the household\'s first local date has safely passed. !!]';

  @override
  String get householdActivationReturnComplete =>
      '[!! The complete Today view was opened after the household\'s first local date safely passed. !!]';

  @override
  String get householdActivationStepComplete =>
      '[!! Complete milestone finished !!]';

  @override
  String get householdActivationUnavailableBody =>
      '[!! Complete getting-started progress is temporarily unavailable. Every Today chore and event still works, and only this card needs a safe retry. !!]';

  @override
  String get householdActivationReadOnlyBody =>
      '[!! Invite and chore actions remain unavailable while Today displays complete saved data safely. !!]';

  @override
  String get weeklyReportTitle =>
      '[!! Complete household weekly recap and shared progress !!]';

  @override
  String get weeklyReportOpenAction =>
      '[!! Open the complete household weekly recap safely !!]';

  @override
  String get weeklyReportLoading =>
      '[!! Loading the complete household weekly recap securely now… !!]';

  @override
  String get weeklyReportRefreshing =>
      '[!! Refreshing the complete household weekly recap securely now… !!]';

  @override
  String get weeklyReportUnavailableTitle =>
      '[!! Complete weekly recap is temporarily unavailable !!]';

  @override
  String get weeklyReportUnavailableBody =>
      '[!! Every Today chore still works safely. Retry only this complete recap whenever you are ready. !!]';

  @override
  String weeklyReportWeekRange(String start, String end) {
    return '[!! Complete week from $start through $end !!]';
  }

  @override
  String get weeklyReportLatestWeek =>
      '[!! Latest completely closed household week !!]';

  @override
  String weeklyReportSummary(int completed, int due) {
    return '[!! $completed of $due complete due household chores were finished safely !!]';
  }

  @override
  String weeklyReportCardSummary(int completed, int due) {
    return '[!! $completed of $due complete due household chores were finished safely by the complete end of the week !!]';
  }

  @override
  String get weeklyReportEmpty =>
      '[!! No complete household chores were due or skipped throughout this week. !!]';

  @override
  String weeklyReportByWeekEndRate(int percent) {
    return '[!! $percent% completed safely by the complete end of the week !!]';
  }

  @override
  String weeklyReportCompletedByWeekEnd(int count) {
    return '[!! $count completed safely by the complete end of the week !!]';
  }

  @override
  String weeklyReportCompletedLater(int count) {
    return '[!! $count completed safely after the complete week ended !!]';
  }

  @override
  String weeklyReportStillOpen(int count) {
    return '[!! $count complete due chores still remain open safely !!]';
  }

  @override
  String weeklyReportSkipped(int count) {
    return '[!! $count complete household chores were skipped safely !!]';
  }

  @override
  String weeklyReportYourContribution(int count) {
    return '[!! You safely completed $count complete household chores !!]';
  }

  @override
  String get weeklyReportBreakdownTitle =>
      '[!! Complete active household member contributions !!]';

  @override
  String weeklyReportMemberContribution(String name, int count) {
    return '[!! $name safely completed $count complete chores !!]';
  }

  @override
  String weeklyReportMemberByWeekEnd(int count) {
    return '[!! $count safely finished by the complete end of the week !!]';
  }

  @override
  String weeklyReportOtherContribution(int count) {
    return '[!! Other or former household members safely completed $count complete chores !!]';
  }

  @override
  String get weeklyReportTruncatedNotice =>
      '[!! Up to 20 complete current household members are shown safely. Every remaining contribution is combined above. !!]';

  @override
  String get weeklyReportOlderWeek =>
      '[!! Open the complete older closed week !!]';

  @override
  String get weeklyReportNewerWeek =>
      '[!! Open the complete newer closed week !!]';

  @override
  String get runtimePolicyUnavailableTitle =>
      '[!! Complete service status could not be verified safely !!]';

  @override
  String get runtimePolicyUnavailableBody =>
      '[!! Every saved item remains available for complete reading. Online changes may remain unavailable until this complete verification succeeds safely. !!]';

  @override
  String get runtimePolicyReadOnlyTitle =>
      '[!! KinFlow is temporarily in complete read-only mode !!]';

  @override
  String get runtimePolicyReadOnlyBody =>
      '[!! You can still completely view information and use export, deletion, legal, support, and diagnostic access safely. Every other change is temporarily paused. !!]';

  @override
  String get runtimePolicyUpdateTitle =>
      '[!! A complete KinFlow update is required before making changes !!]';

  @override
  String runtimePolicyUpdateBody(String version) {
    return '[!! Carefully update KinFlow to complete version $version or later. Reading, export, deletion, legal, support, and diagnostics all remain completely available. !!]';
  }

  @override
  String get runtimePolicyUpdateAction =>
      '[!! Open the trusted Google Play Store listing safely !!]';

  @override
  String get runtimePolicyUpdateUnavailable =>
      '[!! The trusted Google Play Store listing could not be opened safely. Try again or update KinFlow directly in the complete Store application. !!]';

  @override
  String get runtimePolicyFeatureDisabledTitle =>
      '[!! Some complete capability changes are temporarily paused safely !!]';

  @override
  String runtimePolicyFeatureDisabledBody(String features) {
    return '[!! Complete paused capabilities: $features. Every other feature, reading, export, deletion, legal, support, and diagnostic action remains safely available. !!]';
  }

  @override
  String get runtimePolicyFeatureHousehold =>
      '[!! Complete household management !!]';

  @override
  String get runtimePolicyFeatureChores => '[!! Complete household chores !!]';

  @override
  String get runtimePolicyFeatureCalendar => '[!! Complete family calendar !!]';

  @override
  String get runtimePolicyFeatureNotifications =>
      '[!! Complete notification controls !!]';

  @override
  String get runtimePolicyFeatureProfile => '[!! Complete personal profile !!]';

  @override
  String get runtimePolicyFeatureBilling =>
      '[!! Complete subscription and billing !!]';

  @override
  String get choreTrashTitle =>
      '[!! Complete recently deleted household chores safely !!]';

  @override
  String get choreTrashOpenAction =>
      '[!! Open every recently deleted household chore safely !!]';

  @override
  String get choreTrashTodayAction =>
      '[!! Return completely to the Today view safely !!]';

  @override
  String get choreTrashLoading =>
      '[!! Loading every recently deleted household chore safely… !!]';

  @override
  String get choreTrashEmptyTitle =>
      '[!! No complete recently deleted household chores !!]';

  @override
  String get choreTrashEmptyBody =>
      '[!! Deleted one-time household chores will completely appear here so an adult can safely restore them. !!]';

  @override
  String get choreTrashRefreshFailed =>
      '[!! Recently deleted household chores could not be completely refreshed. The current complete list remains safely visible. !!]';

  @override
  String choreTrashDeletedAt(String date, String time) {
    return '[!! Completely deleted on $date at $time safely !!]';
  }

  @override
  String choreTrashDueDate(String date) {
    return '[!! Complete preserved due date $date !!]';
  }

  @override
  String choreTrashDueDateTime(String date, String time) {
    return '[!! Complete preserved due date $date at $time safely !!]';
  }

  @override
  String choreTrashAssignee(String name) {
    return '[!! Completely assigned to $name safely !!]';
  }

  @override
  String get choreTrashRestoreAction =>
      '[!! Restore this complete household chore safely !!]';

  @override
  String get choreTrashRestoringAction =>
      '[!! Completely restoring this household chore safely… !!]';

  @override
  String get choreTrashRestoreSucceeded =>
      '[!! The complete one-time household chore was safely restored. !!]';

  @override
  String get choreTrashLoadMoreAction =>
      '[!! Load more complete deleted household chores safely !!]';

  @override
  String get choreTrashLoadMoreFailed =>
      '[!! More complete deleted household chores could not be loaded safely. !!]';

  @override
  String get choreDeleteUndoAction => '[!! Completely undo deletion safely !!]';

  @override
  String get choreRestoreOneTimeSucceeded =>
      '[!! The complete deleted household chore was safely restored. !!]';

  @override
  String get choreRestoreOneTimeFailed =>
      '[!! The complete deleted household chore could not be restored safely. Try again from complete Recently deleted chores. !!]';

  @override
  String get settingsDeviceCapabilitiesTitle =>
      '[!! Complete device capability status and support overview !!]';

  @override
  String get settingsDeviceCapabilitiesSummary =>
      '[!! Review every supported integration, required setup choice, intentional limitation, and safe fallback for this complete device. !!]';

  @override
  String get platformCapabilitiesTitle =>
      '[!! Complete device capability status and fallback overview !!]';

  @override
  String get platformCapabilitiesIntroTitle =>
      '[!! How KinFlow works completely and safely on this device !!]';

  @override
  String get platformCapabilitiesIntroBody =>
      '[!! This complete local snapshot shows every Android integration selected by this application build and the current notification permission state. It intentionally does not test provider connectivity or remote server health. !!]';

  @override
  String get platformCapabilitiesPrivacyNote =>
      '[!! No account, shared household, device identity, payment detail, configuration value, or provider error detail is included or uploaded anywhere from this complete status screen. !!]';

  @override
  String get platformCapabilitiesSelfCheckTitle =>
      '[!! Complete capability self-check and ordered recovery plan !!]';

  @override
  String get platformCapabilitiesSelfCheckBody =>
      '[!! Review every completely ready capability first, then follow the safely ordered recovery steps for anything requiring attention, a fallback, or an intentional limitation. !!]';

  @override
  String platformCapabilitiesReadyCount(int count) {
    return '[!! $count complete capabilities ready safely !!]';
  }

  @override
  String platformCapabilitiesAttentionCount(int count) {
    return '[!! $count complete capabilities need careful attention !!]';
  }

  @override
  String platformCapabilitiesAlternativeCount(int count) {
    return '[!! $count complete capabilities use a safe fallback or intentional limitation !!]';
  }

  @override
  String get platformCapabilitiesRecoveryHeading =>
      '[!! Completely recommended and stable recovery order !!]';

  @override
  String get platformCapabilitiesRecoveryEmpty =>
      '[!! Every primary capability is completely ready. Safe fallback paths still remain fully available whenever needed. !!]';

  @override
  String platformCapabilitiesRecoveryStep(int number) {
    return '[!! Complete recovery step $number safely !!]';
  }

  @override
  String get platformCapabilitiesSelfCheckAction =>
      '[!! Recheck complete notification permission and device setup safely !!]';

  @override
  String get platformCapabilitiesSelfCheckRefreshing =>
      '[!! Completely checking notification permission and device setup safely… !!]';

  @override
  String get platformCapabilitiesSelfCheckScope =>
      '[!! This complete action never requests permission or opens system settings. The existing notification coordinator may safely clean up or restore the device binding only when the current permission changed, through its complete privacy-safe and already validated lifecycle without exposing any provider detail to this screen. !!]';

  @override
  String get platformCapabilitiesSelfCheckSucceeded =>
      '[!! Complete notification permission and safe device binding status were checked again successfully. !!]';

  @override
  String get platformCapabilitiesSelfCheckFailed =>
      '[!! Complete notification setup could not be checked safely right now. The durable inbox and every listed safe fallback remain fully available. !!]';

  @override
  String get platformCapabilitiesProviderLabel =>
      '[!! Selected complete platform integration !!]';

  @override
  String get platformCapabilitiesFallbackLabel =>
      '[!! Safe complete fallback and alternative path !!]';

  @override
  String get platformCapabilitiesNotificationTitle =>
      '[!! Complete notification delivery capability !!]';

  @override
  String get platformCapabilitiesBillingTitle =>
      '[!! Complete Google Play billing capability !!]';

  @override
  String get platformCapabilitiesSecureStorageTitle =>
      '[!! Complete encrypted local storage capability !!]';

  @override
  String get platformCapabilitiesExternalLinksTitle =>
      '[!! Complete external links and secure downloads capability !!]';

  @override
  String get platformCapabilitiesBackgroundTitle =>
      '[!! Complete background delivery capability !!]';

  @override
  String get platformCapabilitiesStateAvailable =>
      '[!! Completely supported here !!]';

  @override
  String get platformCapabilitiesStateActionRequired =>
      '[!! Complete user action is needed !!]';

  @override
  String get platformCapabilitiesStateLimited =>
      '[!! Intentionally limited by complete design !!]';

  @override
  String get platformCapabilitiesStateFallbackOnly =>
      '[!! Safely using the complete fallback path !!]';

  @override
  String get platformCapabilitiesStateTemporaryIssue =>
      '[!! Complete temporary local issue detected !!]';

  @override
  String get platformCapabilitiesProviderFirebaseMessaging =>
      '[!! Firebase Messaging integration for complete Android delivery !!]';

  @override
  String get platformCapabilitiesProviderRevenueCatPlay =>
      '[!! RevenueCat integration together with complete Google Play billing !!]';

  @override
  String get platformCapabilitiesProviderAndroidKeystore =>
      '[!! Complete Android Keystore-backed encrypted storage integration !!]';

  @override
  String get platformCapabilitiesProviderAndroidUriLauncher =>
      '[!! Complete Android system link and application handler integration !!]';

  @override
  String get platformCapabilitiesProviderBrowserUriLauncher =>
      '[!! Complete trusted browser link and external destination handler integration !!]';

  @override
  String get platformCapabilitiesProviderFirebaseBackground =>
      '[!! Firebase complete Android background message entry handler !!]';

  @override
  String get platformCapabilitiesProviderUnavailable =>
      '[!! Primary integration is not configured in this complete application build !!]';

  @override
  String get platformCapabilitiesFallbackInbox =>
      '[!! Durable complete in-application notification inbox fallback !!]';

  @override
  String get platformCapabilitiesFallbackInboxAndEmail =>
      '[!! Durable complete in-application inbox and configured privacy-safe generic email fallback !!]';

  @override
  String get platformCapabilitiesFallbackEntitlement =>
      '[!! Server-confirmed complete entitlement and readable subscription status fallback !!]';

  @override
  String get platformCapabilitiesFallbackReauthentication =>
      '[!! Safe re-authentication without any persistent offline household data fallback !!]';

  @override
  String get platformCapabilitiesFallbackGuidance =>
      '[!! Complete on-screen recovery guidance and privacy-safe local diagnostics fallback !!]';

  @override
  String get platformCapabilitiesFallbackServerNotifications =>
      '[!! Complete server notification processing together with the durable in-application inbox !!]';

  @override
  String get platformCapabilitiesNotificationAvailable =>
      '[!! Android push delivery is completely supported. Important household events also remain safely available inside Notifications. !!]';

  @override
  String get platformCapabilitiesNotificationNotDetermined =>
      '[!! A complete notification permission choice has not been made yet. Choose it inside Notifications while the durable application inbox continues to work safely. !!]';

  @override
  String get platformCapabilitiesNotificationDenied =>
      '[!! System notifications are currently turned off for KinFlow. Review the complete choice inside Notifications while the durable inbox continues working safely. !!]';

  @override
  String get platformCapabilitiesNotificationRuntimeUnavailable =>
      '[!! Android notification delivery is unavailable in this current runtime. Every important event remains safely accessible through the durable in-application inbox. !!]';

  @override
  String get platformCapabilitiesNotificationTemporary =>
      '[!! The notification integration reported a temporary local problem. Existing durable inbox content remains completely available and unchanged. !!]';

  @override
  String get platformCapabilitiesNotificationNotConfigured =>
      '[!! Push delivery is not configured in this complete application build. Important household events continue to remain safely available in the durable inbox. !!]';

  @override
  String get platformCapabilitiesBillingAvailable =>
      '[!! Google Play purchasing is completely supported. Shared household access still follows only the authoritative server-confirmed entitlement. !!]';

  @override
  String get platformCapabilitiesBillingNotConfigured =>
      '[!! Store purchasing is unavailable in this complete application build. Existing server-confirmed access and readable subscription details remain safely available. !!]';

  @override
  String get platformCapabilitiesSecureStorageAvailable =>
      '[!! Sensitive application sessions and supported offline snapshots completely use Android encrypted device storage. !!]';

  @override
  String get platformCapabilitiesSecureStorageNotConfigured =>
      '[!! Persistent encrypted offline household data is unavailable. KinFlow safely falls back to complete re-authentication and newly refreshed online reads. !!]';

  @override
  String get platformCapabilitiesExternalLinksAvailable =>
      '[!! Trusted support, policy, Store, and export links can completely use the Android system application handler. !!]';

  @override
  String get platformCapabilitiesExternalLinksNotConfigured =>
      '[!! External link handling is unavailable in this complete application build. On-screen recovery guidance and privacy-safe diagnostics remain available. !!]';

  @override
  String get platformCapabilitiesBackgroundLimited =>
      '[!! Android can receive complete background push entry events, while the authoritative server pipeline always remains the source of truth for delivery. !!]';

  @override
  String get platformCapabilitiesBackgroundNotConfigured =>
      '[!! Client background delivery is not configured completely. Authoritative server processing and the durable in-application inbox remain the safe fallback path. !!]';

  @override
  String get platformCapabilitiesSafeUnknownState =>
      '[!! This complete capability state is unavailable. Continue safely with the named fallback path and privacy-safe local diagnostics. !!]';

  @override
  String get platformCapabilitiesOpenNotificationsAction =>
      '[!! Open complete Notifications settings and inbox !!]';

  @override
  String get platformCapabilitiesOpenSubscriptionAction =>
      '[!! Open complete shared household subscription settings !!]';

  @override
  String get platformCapabilitiesOpenDiagnosticsAction =>
      '[!! Open complete privacy-safe local diagnostics !!]';
}
