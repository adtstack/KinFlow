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
      'KinFlow currently supports adult accounts with Google sign-in.';

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
      'Confirm your name, language, and IANA timezone. You will become the household Owner.';

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
  String get householdTimezoneHint => 'Use an IANA name such as Asia/Seoul.';

  @override
  String get householdTimezoneValidation => 'Enter an IANA timezone.';

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
      'Create a single-use link that expires in 7 days. You can optionally restrict it to one email address.';

  @override
  String get inviteEmailLabel => 'Recipient email (optional)';

  @override
  String get inviteEmailHint => 'The signed-in account must match this email.';

  @override
  String get inviteCreateAction => 'Create invite link';

  @override
  String get inviteCreatingAction => 'Creating invite';

  @override
  String get inviteLinkHeading => 'Your invite link is ready';

  @override
  String get inviteLinkBody =>
      'Share this link only with the intended adult. KinFlow will not show the token again after this screen closes.';

  @override
  String get inviteCopyAction => 'Copy link';

  @override
  String get inviteCopiedBody => 'Invite link copied.';

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
  String get inviteInvalidError => 'This invitation link is invalid.';

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
  String get todayTitle => 'Today';

  @override
  String get todayEmptyTitle => 'Nothing is scheduled for today';

  @override
  String get todayEmptyBody =>
      'Your shared household is ready. Chores will appear here when they are added.';

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
      '[!! ĶîñFłôŵ currently supports adult accounts with Ĝôôĝłē sign-in only across every supported family flow and adaptive layout. !!]';

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
      '[!! Çôñƒîŕm ŷôûŕ display name, preferred language, åñđ complete ÎÅÑÅ timezone. You will securely become the Owner of this shared household across every adaptive layout. !!]';

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
      '[!! Ûšē å complete ÎÅÑÅ timezone name such as Asia/Seoul for every shared schedule. !!]';

  @override
  String get householdTimezoneValidation =>
      '[!! Ēñţēŕ å valid complete ÎÅÑÅ timezone name. !!]';

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
      '[!! Çŕēåţē å šîñĝłē-ûšē secure invitation link that expires in seven full days. You may optionally restrict it to exactly one adult email address. !!]';

  @override
  String get inviteEmailLabel =>
      '[!! Ŕēçîpîēñţ åđûłţ ēmåîł address — optional !!]';

  @override
  String get inviteEmailHint =>
      '[!! Ţĥē signed-in adult account must exactly match this protected email address before joining. !!]';

  @override
  String get inviteCreateAction => '[!! Çŕēåţē ţĥē secure îñvîţē łîñķ !!]';

  @override
  String get inviteCreatingAction =>
      '[!! Çŕēåţîñĝ ţĥē secure household invitation now !!]';

  @override
  String get inviteLinkHeading =>
      '[!! Ŷôûŕ šēçûŕē one-time invitation link îš ready !!]';

  @override
  String get inviteLinkBody =>
      '[!! Šĥåŕē ţĥîš sensitive link only with the intended adult. ĶîñFłôŵ will never show the raw token again after this complete screen closes. !!]';

  @override
  String get inviteCopyAction => '[!! Çôpŷ ţĥē complete invitation link !!]';

  @override
  String get inviteCopiedBody =>
      '[!! Secure invitation link copied successfully. !!]';

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
      '[!! Ţĥîš secure invitation link is invalid and cannot be used. !!]';

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
  String get todayTitle => '[!! Ţôđåŷ schedule !!]';

  @override
  String get todayEmptyTitle =>
      '[!! Ñôţĥîñĝ îš currently scheduled for today in this shared household !!]';

  @override
  String get todayEmptyBody =>
      '[!! Ŷôûŕ shared household is completely ready. New chores and family responsibilities will appear safely in this Today view whenever they are added. !!]';

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
}
