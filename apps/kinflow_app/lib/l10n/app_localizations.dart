import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'XA'),
    Locale('ko'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'KinFlow'**
  String get appTitle;

  /// Banner shown only in development builds
  ///
  /// In en, this message translates to:
  /// **'DEV'**
  String get developmentBanner;

  /// Accessible label and message while app dependencies initialize
  ///
  /// In en, this message translates to:
  /// **'Starting KinFlow'**
  String get startupLoadingLabel;

  /// Generic startup failure title
  ///
  /// In en, this message translates to:
  /// **'KinFlow couldn\'t start'**
  String get startupErrorTitle;

  /// Generic startup failure body without raw exception details
  ///
  /// In en, this message translates to:
  /// **'Please try again. If the problem continues, restart the app.'**
  String get startupErrorBody;

  /// Accessible message while the authentication session is restored
  ///
  /// In en, this message translates to:
  /// **'Checking your session'**
  String get authLoadingLabel;

  /// Adult account sign-in screen title
  ///
  /// In en, this message translates to:
  /// **'Sign in to KinFlow'**
  String get authSignInTitle;

  /// Explains the single adult sign-in provider
  ///
  /// In en, this message translates to:
  /// **'KinFlow currently supports adult accounts with Google sign-in.'**
  String get authSignInBody;

  /// Starts the Google sign-in request
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogleSignInAction;

  /// Accessible hint for the Google sign-in action
  ///
  /// In en, this message translates to:
  /// **'Signs in with an adult Google account'**
  String get authGoogleSignInHint;

  /// Status while a Google sign-in request is in progress
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google'**
  String get authSigningInLabel;

  /// Safe provider-unavailable message without upstream details
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is temporarily unavailable. Please try again later.'**
  String get authProviderUnavailableBody;

  /// Safe message after an expired or revoked session
  ///
  /// In en, this message translates to:
  /// **'Your session expired or was revoked. Sign in again.'**
  String get authSessionExpiredBody;

  /// Fail-closed message after local sensitive state purge fails
  ///
  /// In en, this message translates to:
  /// **'KinFlow locked access because local data could not be cleared safely. Restart the app before trying again.'**
  String get authLocalStateLockedBody;

  /// Signs out and clears local account-scoped state
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authLogoutAction;

  /// Safe recovery title when active household resolution fails
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your household'**
  String get householdLookupErrorTitle;

  /// Safe recovery guidance without exposing provider errors
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. Your household data has not been changed.'**
  String get householdLookupErrorBody;

  /// App bar title for first household onboarding
  ///
  /// In en, this message translates to:
  /// **'Set up your household'**
  String get householdOnboardingTitle;

  /// Heading for first household onboarding
  ///
  /// In en, this message translates to:
  /// **'Create a shared home'**
  String get householdOnboardingHeading;

  /// Explains the first household creation result
  ///
  /// In en, this message translates to:
  /// **'Confirm your name, language, and IANA timezone. You will become the household Owner.'**
  String get householdOnboardingBody;

  /// Label for the adult Owner display name
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get ownerDisplayNameLabel;

  /// Label for the new household name
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdNameLabel;

  /// Validation message shared by household and display names
  ///
  /// In en, this message translates to:
  /// **'Enter 1–80 characters without control characters.'**
  String get householdNameValidation;

  /// Label for the adult profile locale
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get householdLocaleLabel;

  /// Label for the household IANA timezone
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get householdTimezoneLabel;

  /// Guidance for the household timezone input
  ///
  /// In en, this message translates to:
  /// **'Use an IANA name such as Asia/Seoul.'**
  String get householdTimezoneHint;

  /// Validation message for an empty timezone
  ///
  /// In en, this message translates to:
  /// **'Enter an IANA timezone.'**
  String get householdTimezoneValidation;

  /// Submits first household onboarding
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get householdCreateAction;

  /// Status shown while first household creation is pending
  ///
  /// In en, this message translates to:
  /// **'Creating household'**
  String get householdCreatingAction;

  /// Safe message for server-rejected onboarding input
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted details and try again.'**
  String get householdInvalidInputError;

  /// Safe message when a second first-household request is rejected
  ///
  /// In en, this message translates to:
  /// **'This account already has an active household. Reload your household to continue.'**
  String get householdAlreadyExistsError;

  /// Safe message for an idempotency request conflict
  ///
  /// In en, this message translates to:
  /// **'These details changed during a retry. Review them and submit again.'**
  String get householdRequestConflictError;

  /// Generic first household creation failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create the household. Your request is safe to retry.'**
  String get householdCreateError;

  /// Opens the adult household invitation screen
  ///
  /// In en, this message translates to:
  /// **'Invite an adult'**
  String get todayInviteAction;

  /// Invitation creation screen title
  ///
  /// In en, this message translates to:
  /// **'Invite to your household'**
  String get inviteCreateTitle;

  /// Invitation creation heading
  ///
  /// In en, this message translates to:
  /// **'Bring another adult into KinFlow'**
  String get inviteCreateHeading;

  /// Explains invite lifetime and optional email restriction
  ///
  /// In en, this message translates to:
  /// **'Create a single-use link that expires in 7 days. You can optionally restrict it to one email address.'**
  String get inviteCreateBody;

  /// Optional target email input label
  ///
  /// In en, this message translates to:
  /// **'Recipient email (optional)'**
  String get inviteEmailLabel;

  /// Explains target-email enforcement
  ///
  /// In en, this message translates to:
  /// **'The signed-in account must match this email.'**
  String get inviteEmailHint;

  /// Creates a household invitation
  ///
  /// In en, this message translates to:
  /// **'Create invite link'**
  String get inviteCreateAction;

  /// Status while an invite is created
  ///
  /// In en, this message translates to:
  /// **'Creating invite'**
  String get inviteCreatingAction;

  /// Heading above the one-time invite link
  ///
  /// In en, this message translates to:
  /// **'Your invite link is ready'**
  String get inviteLinkHeading;

  /// Warns that the invite token is sensitive and shown once
  ///
  /// In en, this message translates to:
  /// **'Share this link only with the intended adult. KinFlow will not show the token again after this screen closes.'**
  String get inviteLinkBody;

  /// Copies the invite URL
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get inviteCopyAction;

  /// Confirmation after copying an invite link
  ///
  /// In en, this message translates to:
  /// **'Invite link copied.'**
  String get inviteCopiedBody;

  /// Explains why an idempotent retry may omit a raw token
  ///
  /// In en, this message translates to:
  /// **'This retry is safe, but the one-time link can no longer be shown. Revoke it and create a new invite.'**
  String get inviteTokenUnavailableBody;

  /// Revokes an active invite
  ///
  /// In en, this message translates to:
  /// **'Revoke invite'**
  String get inviteRevokeAction;

  /// Status while an invite is revoked
  ///
  /// In en, this message translates to:
  /// **'Revoking invite'**
  String get inviteRevokingAction;

  /// Starts a fresh invite after revocation
  ///
  /// In en, this message translates to:
  /// **'Create another invite'**
  String get inviteNewAction;

  /// Public invitation preview screen title
  ///
  /// In en, this message translates to:
  /// **'Household invitation'**
  String get inviteOpenTitle;

  /// Status while a public invite preview loads
  ///
  /// In en, this message translates to:
  /// **'Checking this invitation'**
  String get inviteLoadingLabel;

  /// Title when no safe pending invite token exists
  ///
  /// In en, this message translates to:
  /// **'Invitation unavailable'**
  String get inviteMissingTitle;

  /// Recovery guidance for a missing invite token
  ///
  /// In en, this message translates to:
  /// **'Open the original invitation link again or ask the sender for a new one.'**
  String get inviteMissingBody;

  /// Minimal public invite preview sentence
  ///
  /// In en, this message translates to:
  /// **'{inviterName} invited you to join {householdName}.'**
  String invitePreviewSentence(String inviterName, String householdName);

  /// Human-readable invited Member role
  ///
  /// In en, this message translates to:
  /// **'Household member'**
  String get inviteRoleMember;

  /// Human-readable invited Admin role
  ///
  /// In en, this message translates to:
  /// **'Household admin'**
  String get inviteRoleAdmin;

  /// Invite expiry display
  ///
  /// In en, this message translates to:
  /// **'Expires {expiresAt}'**
  String inviteExpiryLabel(String expiresAt);

  /// Explains invite continuation through authentication
  ///
  /// In en, this message translates to:
  /// **'Sign in with the adult account that should join this household. This invitation will remain in memory during sign-in.'**
  String get inviteSignInBody;

  /// Navigates to sign-in while retaining the invite intent
  ///
  /// In en, this message translates to:
  /// **'Sign in to accept'**
  String get inviteSignInAction;

  /// Heading for an existing active-household confirmation
  ///
  /// In en, this message translates to:
  /// **'Switch active household?'**
  String get inviteSwitchTitle;

  /// Explains explicit active-household switching
  ///
  /// In en, this message translates to:
  /// **'You already have an active household. Joining will keep both memberships and switch KinFlow to this household.'**
  String get inviteSwitchBody;

  /// Required confirmation before switching active household
  ///
  /// In en, this message translates to:
  /// **'I want to join and switch to this household.'**
  String get inviteSwitchConfirmation;

  /// Accepts the household invitation
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get inviteAcceptAction;

  /// Status while an invitation is accepted
  ///
  /// In en, this message translates to:
  /// **'Joining household'**
  String get inviteAcceptingAction;

  /// Success message after invitation acceptance
  ///
  /// In en, this message translates to:
  /// **'You joined the household. Opening Today…'**
  String get inviteAcceptedBody;

  /// Invalid invitation error
  ///
  /// In en, this message translates to:
  /// **'This invitation link is invalid.'**
  String get inviteInvalidError;

  /// Expired invitation error
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired. Ask the sender for a new one.'**
  String get inviteExpiredError;

  /// Revoked invitation error
  ///
  /// In en, this message translates to:
  /// **'This invitation was revoked. Ask the sender for a new one.'**
  String get inviteRevokedError;

  /// Used invitation error
  ///
  /// In en, this message translates to:
  /// **'This single-use invitation has already been accepted.'**
  String get inviteAlreadyUsedError;

  /// Target email mismatch error
  ///
  /// In en, this message translates to:
  /// **'Sign in with the email address this invitation was created for.'**
  String get inviteEmailMismatchError;

  /// Invite rate-limit error
  ///
  /// In en, this message translates to:
  /// **'Too many invitation attempts. Wait a few minutes and try again.'**
  String get inviteRateLimitedError;

  /// Invite permission error
  ///
  /// In en, this message translates to:
  /// **'Only the household Owner or an Admin can manage invitations.'**
  String get invitePermissionError;

  /// Generic safe invitation error
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete the invitation request. It is safe to try again.'**
  String get inviteGenericError;

  /// Opens household member management
  ///
  /// In en, this message translates to:
  /// **'Manage household members'**
  String get todayMembersAction;

  /// Household member screen title
  ///
  /// In en, this message translates to:
  /// **'Household members'**
  String get membersTitle;

  /// Accessible roster loading label
  ///
  /// In en, this message translates to:
  /// **'Loading household members'**
  String get membersLoadingLabel;

  /// Roster heading
  ///
  /// In en, this message translates to:
  /// **'Members of {householdName}'**
  String membersHeading(String householdName);

  /// Roster screen explanation
  ///
  /// In en, this message translates to:
  /// **'Review and manage active adult members and roles. Every change is completed online.'**
  String get membersBody;

  /// Badge for the current member
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get membersYouLabel;

  /// Owner role label
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get membersRoleOwner;

  /// Admin role label
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get membersRoleAdmin;

  /// Member role label
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get membersRoleMember;

  /// Accessible member action menu label
  ///
  /// In en, this message translates to:
  /// **'Actions for {memberName}'**
  String membersMenuTooltip(String memberName);

  /// Promote a Member to Admin
  ///
  /// In en, this message translates to:
  /// **'Change to Admin'**
  String get memberPromoteAdminAction;

  /// Demote an Admin to Member
  ///
  /// In en, this message translates to:
  /// **'Change to Member'**
  String get memberDemoteMemberAction;

  /// Transfer household ownership
  ///
  /// In en, this message translates to:
  /// **'Transfer Owner'**
  String get memberTransferOwnerAction;

  /// Remove a household member
  ///
  /// In en, this message translates to:
  /// **'Remove from household'**
  String get memberRemoveAction;

  /// Leave the current household
  ///
  /// In en, this message translates to:
  /// **'Leave this household'**
  String get householdLeaveAction;

  /// Role change confirmation title
  ///
  /// In en, this message translates to:
  /// **'Change this role?'**
  String get memberRoleChangeTitle;

  /// Role change confirmation body
  ///
  /// In en, this message translates to:
  /// **'Change {memberName} to {role}. Google will ask you to verify your identity before continuing.'**
  String memberRoleChangeBody(String memberName, String role);

  /// Member removal confirmation title
  ///
  /// In en, this message translates to:
  /// **'Remove this member?'**
  String get memberRemoveTitle;

  /// Member removal confirmation body
  ///
  /// In en, this message translates to:
  /// **'{memberName} will immediately lose access to this household. Their unused invitations will also be revoked.'**
  String memberRemoveBody(String memberName);

  /// Owner transfer confirmation title
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership?'**
  String get ownerTransferTitle;

  /// Owner transfer confirmation body
  ///
  /// In en, this message translates to:
  /// **'{memberName} will become the new Owner and you will become an Admin. Google will ask you to verify your identity before continuing.'**
  String ownerTransferBody(String memberName);

  /// Household leave confirmation title
  ///
  /// In en, this message translates to:
  /// **'Leave this household?'**
  String get householdLeaveTitle;

  /// Household leave confirmation body
  ///
  /// In en, this message translates to:
  /// **'Your membership and access to this household will end immediately. Shared records will remain with the household.'**
  String get householdLeaveBody;

  /// Explains why an Owner cannot leave
  ///
  /// In en, this message translates to:
  /// **'The Owner must transfer ownership to another adult before leaving the household.'**
  String get ownerMustTransferBody;

  /// Member mutation progress label
  ///
  /// In en, this message translates to:
  /// **'Completing this change securely'**
  String get memberActionInProgress;

  /// Cancel a member confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get memberCancelAction;

  /// Confirm a member mutation
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get memberConfirmAction;

  /// Roster load error
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load household members. Check your connection and try again.'**
  String get membersLoadError;

  /// Member action permission error
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to perform this member action.'**
  String get membersPermissionError;

  /// Stale member version error
  ///
  /// In en, this message translates to:
  /// **'Member information changed elsewhere. Reload it and try again.'**
  String get membersVersionConflictError;

  /// Last Owner invariant error
  ///
  /// In en, this message translates to:
  /// **'The last Owner cannot be removed or leave. Transfer ownership first.'**
  String get membersOwnerTransferRequiredError;

  /// Recent authentication required error
  ///
  /// In en, this message translates to:
  /// **'This change needs a recent Google identity check. Try again.'**
  String get membersRecentAuthError;

  /// Recent authentication cancellation
  ///
  /// In en, this message translates to:
  /// **'You cancelled the Google identity check. Household information was not changed.'**
  String get membersRecentAuthCancelled;

  /// Recent authentication account mismatch
  ///
  /// In en, this message translates to:
  /// **'A different Google account was selected, so the change was stopped. Check the current account.'**
  String get membersAccountChangedError;

  /// Generic household member error
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete the member change. It is safe to retry the same request.'**
  String get membersGenericError;

  /// Title for the Today destination
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Heading for the initial empty Today state
  ///
  /// In en, this message translates to:
  /// **'Nothing is scheduled for today'**
  String get todayEmptyTitle;

  /// Body for the initial empty Today state
  ///
  /// In en, this message translates to:
  /// **'Your shared household is ready. Chores will appear here when they are added.'**
  String get todayEmptyBody;

  /// Retries app dependency initialization
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// Accessible hint for retry buttons
  ///
  /// In en, this message translates to:
  /// **'Runs this check again'**
  String get retryActionHint;

  /// Temporary foundation shell success title
  ///
  /// In en, this message translates to:
  /// **'KinFlow is ready'**
  String get foundationReadyTitle;

  /// Temporary foundation shell success message
  ///
  /// In en, this message translates to:
  /// **'The app foundation and code boundaries are running. Product features can now be added safely.'**
  String get foundationReadyBody;

  /// Foundation message proving ICU plural generation
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 adaptive layout is ready.} other{{count} adaptive layouts are ready.}}'**
  String foundationLayoutCount(int count);

  /// Message while the architecture sample loads
  ///
  /// In en, this message translates to:
  /// **'Checking the app foundation'**
  String get foundationLoadingLabel;

  /// Generic architecture sample failure title
  ///
  /// In en, this message translates to:
  /// **'The app foundation is unavailable'**
  String get foundationErrorTitle;

  /// Generic architecture sample failure body without raw details
  ///
  /// In en, this message translates to:
  /// **'Please try the check again.'**
  String get foundationErrorBody;

  /// Safe title for unknown routes
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFoundTitle;

  /// Safe body for unknown routes
  ///
  /// In en, this message translates to:
  /// **'This page is unavailable.'**
  String get pageNotFoundBody;

  /// Navigates from an unknown route to the shell home
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHomeAction;

  /// Accessible label for the primary navigation region
  ///
  /// In en, this message translates to:
  /// **'Primary navigation'**
  String get primaryNavigationLabel;

  /// Navigation destination for the foundation home route
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavigationLabel;

  /// Navigation destination for the Today route
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayNavigationLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'XA':
            return AppLocalizationsEnXa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
