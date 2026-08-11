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

  /// Explains the adult Google and email OTP sign-in options
  ///
  /// In en, this message translates to:
  /// **'Use a one-time code sent to your email, or continue with an adult Google account.'**
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

  /// Safe title for a Google identity conflict
  ///
  /// In en, this message translates to:
  /// **'This account cannot be connected automatically'**
  String get authIdentityConflictTitle;

  /// Explains the no-auto-merge identity recovery policy
  ///
  /// In en, this message translates to:
  /// **'KinFlow did not merge accounts. Choose another Google account, or open support if you believe this account should already work.'**
  String get authIdentityConflictBody;

  /// Retries Google sign-in after clearing the local account selection
  ///
  /// In en, this message translates to:
  /// **'Choose another Google account'**
  String get authIdentityChooseAnotherAction;

  /// Accessible hint for identity conflict recovery
  ///
  /// In en, this message translates to:
  /// **'Opens Google account selection again without merging accounts'**
  String get authIdentityChooseAnotherHint;

  /// Opens the fixed configured public support resource
  ///
  /// In en, this message translates to:
  /// **'Open support'**
  String get authIdentitySupportAction;

  /// Status while the support resource opens
  ///
  /// In en, this message translates to:
  /// **'Opening support'**
  String get authIdentitySupportOpening;

  /// Stable success after opening identity recovery support
  ///
  /// In en, this message translates to:
  /// **'Support opened outside KinFlow.'**
  String get authIdentitySupportOpened;

  /// Stable failure when identity recovery support cannot open
  ///
  /// In en, this message translates to:
  /// **'Support could not be opened. Try again later.'**
  String get authIdentitySupportUnavailable;

  /// Divider label before the email OTP sign-in option
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authEmailSectionLabel;

  /// Email field label for passwordless authentication
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmailLabel;

  /// Explains email OTP delivery and adult account creation
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a 6-digit code. If needed, this creates a new adult KinFlow account.'**
  String get authEmailHint;

  /// Requests an email one-time password
  ///
  /// In en, this message translates to:
  /// **'Send sign-in code'**
  String get authEmailSendCodeAction;

  /// Email OTP request in-progress label
  ///
  /// In en, this message translates to:
  /// **'Sending code'**
  String get authEmailSendingCodeAction;

  /// Generic anti-enumeration message after requesting an email OTP
  ///
  /// In en, this message translates to:
  /// **'If {maskedEmail} can be used, we sent a 6-digit code. Check your inbox and spam folder.'**
  String authEmailCodeSentBody(String maskedEmail);

  /// Explains email OTP expiry and resend cooldown
  ///
  /// In en, this message translates to:
  /// **'The newest code expires in 10 minutes. You can request another after 60 seconds.'**
  String get authEmailCodeLifetimeBody;

  /// Email OTP input label
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authEmailCodeLabel;

  /// Email OTP input guidance
  ///
  /// In en, this message translates to:
  /// **'Enter all 6 digits from the newest email.'**
  String get authEmailCodeHint;

  /// Verifies an email OTP and signs in
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get authEmailVerifyAction;

  /// Email OTP verification in-progress label
  ///
  /// In en, this message translates to:
  /// **'Verifying code'**
  String get authEmailVerifyingAction;

  /// Requests a replacement email OTP
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get authEmailResendAction;

  /// Replacement email OTP request in-progress label
  ///
  /// In en, this message translates to:
  /// **'Sending a new code'**
  String get authEmailResendingAction;

  /// Returns from OTP entry to the email field
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get authEmailChangeAction;

  /// Status after OTP verification while auth routing completes
  ///
  /// In en, this message translates to:
  /// **'Code verified. Finishing sign-in.'**
  String get authEmailSigningInLabel;

  /// Email OTP validation failure
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalidEmailError;

  /// Malformed or incorrect email OTP failure
  ///
  /// In en, this message translates to:
  /// **'Enter the newest valid 6-digit code.'**
  String get authEmailInvalidCodeError;

  /// Locally expired email OTP failure
  ///
  /// In en, this message translates to:
  /// **'This code expired. Send a new code to continue.'**
  String get authEmailExpiredError;

  /// Locally reused email OTP failure
  ///
  /// In en, this message translates to:
  /// **'This code has already been used.'**
  String get authEmailAlreadyUsedError;

  /// Email OTP request or verification rate-limit failure
  ///
  /// In en, this message translates to:
  /// **'Please wait before requesting or checking another code.'**
  String get authEmailRateLimitedError;

  /// Safe email OTP provider or network failure
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is temporarily unavailable. Try again later.'**
  String get authEmailTemporarilyUnavailableError;

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
  /// **'Add your name and a name for your household. You will become the household Owner.'**
  String get householdOnboardingBody;

  /// Collapsed onboarding section for optional language and timezone review
  ///
  /// In en, this message translates to:
  /// **'Additional settings'**
  String get householdAdditionalSettingsTitle;

  /// Explains the settings available in the collapsed onboarding section
  ///
  /// In en, this message translates to:
  /// **'Review or change language and timezone before creating.'**
  String get householdAdditionalSettingsBody;

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

  /// Guidance for the household timezone selection
  ///
  /// In en, this message translates to:
  /// **'Choose an IANA region or city such as Asia/Seoul.'**
  String get householdTimezoneHint;

  /// First household timezone picker title
  ///
  /// In en, this message translates to:
  /// **'Choose the household timezone'**
  String get householdTimezonePickerTitle;

  /// Validation message for an empty timezone
  ///
  /// In en, this message translates to:
  /// **'Choose an IANA timezone.'**
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
  /// **'Create a single-use link and a 24-hour companion code. You can optionally restrict the invitation to one email address.'**
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
  /// **'Create invitation'**
  String get inviteCreateAction;

  /// Status while an invite is created
  ///
  /// In en, this message translates to:
  /// **'Creating invite'**
  String get inviteCreatingAction;

  /// Heading above the one-time invite link
  ///
  /// In en, this message translates to:
  /// **'Your invitation is ready'**
  String get inviteLinkHeading;

  /// Warns that the invite token is sensitive and shown once
  ///
  /// In en, this message translates to:
  /// **'Share this link only with the intended adult. KinFlow will not show the token again after this screen closes.'**
  String get inviteLinkBody;

  /// Heading above the one-time short invite code
  ///
  /// In en, this message translates to:
  /// **'24-hour invite code'**
  String get inviteCodeHeading;

  /// Explains short invite code sensitivity and lifetime
  ///
  /// In en, this message translates to:
  /// **'Share this code only with the intended adult. It expires sooner than the link and will not be shown again.'**
  String get inviteCodeBody;

  /// Copies the short invite code
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get inviteCodeCopyAction;

  /// Confirmation after copying a short invite code
  ///
  /// In en, this message translates to:
  /// **'Invite code copied.'**
  String get inviteCodeCopiedBody;

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

  /// Opens the native chooser for the one-time invite link
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get inviteShareAction;

  /// Android native chooser title for an invite link
  ///
  /// In en, this message translates to:
  /// **'Share KinFlow invitation'**
  String get inviteShareChooserTitle;

  /// Live status while handing an invite link to the native chooser
  ///
  /// In en, this message translates to:
  /// **'Opening the share sheet…'**
  String get inviteShareOpeningBody;

  /// Clarifies that opening the chooser does not prove invite delivery
  ///
  /// In en, this message translates to:
  /// **'Share sheet opened. Confirm the recipient before sending; KinFlow cannot confirm delivery.'**
  String get inviteShareOpenedBody;

  /// Manual clipboard recovery when native sharing is unavailable
  ///
  /// In en, this message translates to:
  /// **'The share sheet is unavailable. Use Copy link below and send it only to the intended adult.'**
  String get inviteShareUnavailableBody;

  /// Recoverable stable failure after native sharing fails
  ///
  /// In en, this message translates to:
  /// **'Sharing stopped safely. Use Copy link below or try Share link again.'**
  String get inviteShareFailedBody;

  /// Live status during an explicit invite clipboard write
  ///
  /// In en, this message translates to:
  /// **'Writing the invitation to the system clipboard…'**
  String get inviteCopyingBody;

  /// Recoverable stable invite clipboard failure
  ///
  /// In en, this message translates to:
  /// **'Could not copy the invitation. Select the value above manually or try again.'**
  String get inviteCopyFailedBody;

  /// Invite clipboard privacy and retention guidance
  ///
  /// In en, this message translates to:
  /// **'Copying places this single-use invitation on the system clipboard. Send it only to the intended adult, then clear clipboard history if your device or keyboard keeps it.'**
  String get inviteClipboardNotice;

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

  /// Heading for manual invite code entry
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get inviteCodeEntryTitle;

  /// Guidance for manual invite code entry
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-character code from the household owner. Checking and accepting an invitation requires an internet connection.'**
  String get inviteCodeEntryBody;

  /// Manual invite code field label
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// Formatted short invite code example
  ///
  /// In en, this message translates to:
  /// **'ABCD-EFGH'**
  String get inviteCodeHint;

  /// Validation error for malformed invite codes
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 8-character invite code.'**
  String get inviteCodeValidation;

  /// Loads a preview using a short invite code
  ///
  /// In en, this message translates to:
  /// **'Check invitation'**
  String get inviteCodeSubmitAction;

  /// Opens manual invite code entry from authentication or onboarding
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get inviteEnterCodeAction;

  /// Returns to manual entry after a terminal invite failure
  ///
  /// In en, this message translates to:
  /// **'Try another code'**
  String get inviteAnotherCodeAction;

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
  /// **'This invitation is invalid or no longer available.'**
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
  /// **'Your shared household is ready. Chores and events will appear here when they are added.'**
  String get todayEmptyBody;

  /// Status while the Today list loads
  ///
  /// In en, this message translates to:
  /// **'Loading today\'s chores'**
  String get todayLoadingLabel;

  /// Primary action in empty Today
  ///
  /// In en, this message translates to:
  /// **'Add the first chore'**
  String get todayCreateChoreAction;

  /// Adds a chore from a populated Today list
  ///
  /// In en, this message translates to:
  /// **'Add another chore'**
  String get todayCreateAnotherChoreAction;

  /// Number of chores in Today including completed items
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chore today} other{{count} chores today}}'**
  String todayChoreCount(int count);

  /// Assignee and due time shown on a Today item
  ///
  /// In en, this message translates to:
  /// **'{assigneeName} · {dueLabel}'**
  String todayChoreMetadata(String assigneeName, String dueLabel);

  /// Heading for the Calendar source in Today
  ///
  /// In en, this message translates to:
  /// **'Today\'s events'**
  String get todayCalendarSectionTitle;

  /// Heading for overdue chores in the detailed Today feed
  ///
  /// In en, this message translates to:
  /// **'Overdue chores'**
  String get todayOverdueSectionTitle;

  /// Heading for all-day, happening-now, and nearest next events in Today
  ///
  /// In en, this message translates to:
  /// **'Now and next'**
  String get todayNowAndNextSectionTitle;

  /// Heading for the Chore source in Today
  ///
  /// In en, this message translates to:
  /// **'Today\'s chores'**
  String get todayChoresSectionTitle;

  /// Heading for Calendar events not featured in Now and next
  ///
  /// In en, this message translates to:
  /// **'The rest of today\'s events'**
  String get todayRemainingEventsSectionTitle;

  /// Heading for due-today completed chores
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get todayCompletedSectionTitle;

  /// Action that expands due-today completed chores
  ///
  /// In en, this message translates to:
  /// **'Show completed chores'**
  String get todayCompletedExpandAction;

  /// Action that collapses due-today completed chores
  ///
  /// In en, this message translates to:
  /// **'Hide completed chores'**
  String get todayCompletedCollapseAction;

  /// Accessible status while the Today Calendar source loads
  ///
  /// In en, this message translates to:
  /// **'Loading today\'s events'**
  String get todayCalendarLoadingLabel;

  /// Accessible status while existing Today events refresh
  ///
  /// In en, this message translates to:
  /// **'Refreshing today\'s events'**
  String get todayCalendarRefreshingLabel;

  /// Empty Calendar source within a populated Today view
  ///
  /// In en, this message translates to:
  /// **'No household events today.'**
  String get todayCalendarEmptyLabel;

  /// Number of Calendar events in Today
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String todayCalendarEventCount(int count);

  /// Schedule label for an event active at the server-generated snapshot time
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get todayCalendarHappeningNowLabel;

  /// Stale Calendar source notice in Today
  ///
  /// In en, this message translates to:
  /// **'Showing events loaded at {syncLabel}. Events could not be refreshed.'**
  String todayCalendarStaleMessage(String syncLabel);

  /// Persistent cached Calendar source notice in Today
  ///
  /// In en, this message translates to:
  /// **'Showing a saved calendar snapshot from {syncLabel}.'**
  String todayCalendarOfflineMessage(String syncLabel);

  /// Explains disabled query changes on persistent cached Calendar content
  ///
  /// In en, this message translates to:
  /// **'Saved events are read-only. Reconnect and refresh before changing the Today view or household calendar.'**
  String get todayCalendarOfflineReadOnlyHint;

  /// Bounded Today Calendar source notice
  ///
  /// In en, this message translates to:
  /// **'Today has more than 500 events. Open Calendar to see the complete day.'**
  String get todayCalendarTruncatedMessage;

  /// Accessible summary for a Calendar event in Today
  ///
  /// In en, this message translates to:
  /// **'{title}. {schedule}. {participants}'**
  String todayCalendarEventSemantics(
    String title,
    String schedule,
    String participants,
  );

  /// Action from Today to the full Calendar
  ///
  /// In en, this message translates to:
  /// **'Open household Calendar'**
  String get todayOpenCalendarAction;

  /// Heading when Calendar remains available but the Chore source failed
  ///
  /// In en, this message translates to:
  /// **'Chores are temporarily unavailable'**
  String get todayChoresUnavailableTitle;

  /// Explains source-level failure isolation in Today
  ///
  /// In en, this message translates to:
  /// **'The other Today section remains available.'**
  String get todayPartialFailureHint;

  /// Accessible label for the chore list view filters
  ///
  /// In en, this message translates to:
  /// **'Chore date and status filter'**
  String get choreListViewFilterLabel;

  /// Accessible label for Everyone and Me filters
  ///
  /// In en, this message translates to:
  /// **'Chore assignee filter'**
  String get choreListAssigneeFilterLabel;

  /// Filter for chores due on the household local date
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get choreListTodayFilter;

  /// Filter for future scheduled chores
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get choreListUpcomingFilter;

  /// Filter for past scheduled chores
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get choreListOverdueFilter;

  /// Filter for completed chores across dates
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get choreListCompletedFilter;

  /// Filter showing every household assignee
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get choreListEveryoneFilter;

  /// Filter showing chores assigned to the current member
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get choreListMeFilter;

  /// Server-authoritative household local date used for list boundaries
  ///
  /// In en, this message translates to:
  /// **'Household date: {dateLabel}'**
  String choreListBoundaryDate(String dateLabel);

  /// Number of chores currently loaded for the selected filters
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chore} other{{count} chores}}'**
  String choreListCount(int count);

  /// Assignee and household-local due date and time shown on a chore
  ///
  /// In en, this message translates to:
  /// **'{assigneeName} · {dateLabel} · {dueLabel}'**
  String choreListMetadata(
    String assigneeName,
    String dateLabel,
    String dueLabel,
  );

  /// Accessible status during an authoritative list refresh
  ///
  /// In en, this message translates to:
  /// **'Refreshing chores'**
  String get choreListRefreshing;

  /// Last successful chore list response time
  ///
  /// In en, this message translates to:
  /// **'Last updated {syncLabel}'**
  String choreListLastSynced(String syncLabel);

  /// Safe stale-content message after a refresh failure
  ///
  /// In en, this message translates to:
  /// **'Showing the last available chores from {syncLabel}. We couldn\'t refresh them.'**
  String choreListStaleMessage(String syncLabel);

  /// Stale-content message when no sync time is available
  ///
  /// In en, this message translates to:
  /// **'Showing the last available chores. We couldn\'t refresh them.'**
  String get choreListStaleUnknown;

  /// Persistent offline chore-cache timestamp message
  ///
  /// In en, this message translates to:
  /// **'Showing a saved snapshot from {syncLabel}.'**
  String choreListOfflineMessage(String syncLabel);

  /// Explains the one bounded completion exception on persistent cached content
  ///
  /// In en, this message translates to:
  /// **'Eligible scheduled chore completion can be saved on this device. Reconnect for every other change.'**
  String get choreListOfflineReadOnlyHint;

  /// Heading for an empty upcoming list
  ///
  /// In en, this message translates to:
  /// **'No upcoming chores'**
  String get choreListUpcomingEmptyTitle;

  /// Body for an empty upcoming list
  ///
  /// In en, this message translates to:
  /// **'Future scheduled chores will appear here.'**
  String get choreListUpcomingEmptyBody;

  /// Heading for an empty overdue list
  ///
  /// In en, this message translates to:
  /// **'Nothing is overdue'**
  String get choreListOverdueEmptyTitle;

  /// Body for an empty overdue list
  ///
  /// In en, this message translates to:
  /// **'Every earlier scheduled chore has been handled.'**
  String get choreListOverdueEmptyBody;

  /// Heading for an empty completed list
  ///
  /// In en, this message translates to:
  /// **'No completed chores yet'**
  String get choreListCompletedEmptyTitle;

  /// Body for an empty completed list
  ///
  /// In en, this message translates to:
  /// **'Completed household chores will remain available here.'**
  String get choreListCompletedEmptyBody;

  /// Accessible status while a continuation page loads
  ///
  /// In en, this message translates to:
  /// **'Loading more chores'**
  String get choreListLoadingMore;

  /// Action that loads the next chore list page
  ///
  /// In en, this message translates to:
  /// **'Load more chores'**
  String get choreListLoadMoreAction;

  /// Safe continuation failure that preserves existing content
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load more chores. The chores already shown are still available.'**
  String get choreListLoadMoreFailed;

  /// Status label for an open chore occurrence
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get choreScheduledStatus;

  /// Status label for a completed chore occurrence
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get choreCompletedStatus;

  /// Quick action that completes a Today chore
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get choreMarkCompleteAction;

  /// Quick action that reopens a completed Today chore
  ///
  /// In en, this message translates to:
  /// **'Reopen chore'**
  String get choreReopenAction;

  /// Accessible label while a completion command is pending
  ///
  /// In en, this message translates to:
  /// **'Updating chore status'**
  String get choreCompletionInProgress;

  /// Status shown on a chore whose completion is durably queued
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get choreCompletionQueuedStatus;

  /// Stable status after an offline completion is durably queued
  ///
  /// In en, this message translates to:
  /// **'Completion saved on this device. It will be checked and synced when you reconnect.'**
  String get choreCompletionQueuedMessage;

  /// Live status while a queued completion is revalidated and replayed
  ///
  /// In en, this message translates to:
  /// **'Checking permission and syncing the saved completion…'**
  String get choreCompletionSyncingMessage;

  /// Status when runtime policy prevents automatic replay
  ///
  /// In en, this message translates to:
  /// **'The completion is saved, but syncing is paused by the current app policy.'**
  String get choreCompletionPausedMessage;

  /// Confirmation after queued completion reconciliation
  ///
  /// In en, this message translates to:
  /// **'Completion synced with the latest household data.'**
  String get choreCompletionReconciledMessage;

  /// Recovery after the bounded replay attempt limit or local storage failure
  ///
  /// In en, this message translates to:
  /// **'Automatic sync stopped safely. Discard this saved completion, refresh, and complete it again while online.'**
  String get choreCompletionNeedsAttentionMessage;

  /// Safe conflict or authorization recovery for a queued completion
  ///
  /// In en, this message translates to:
  /// **'The saved completion could not be applied because the chore or your access changed. The latest household data is shown.'**
  String get choreCompletionDiscardedMessage;

  /// Recovery when a queued completion reaches its bounded TTL
  ///
  /// In en, this message translates to:
  /// **'The saved completion expired before it could sync. Refresh and complete it again while online.'**
  String get choreCompletionExpiredMessage;

  /// Failure when secure completion persistence is unavailable
  ///
  /// In en, this message translates to:
  /// **'This completion could not be saved safely on this device. Reconnect and try again.'**
  String get choreCompletionQueueUnavailableMessage;

  /// Failure when the single completion outbox slot is occupied
  ///
  /// In en, this message translates to:
  /// **'One completion is already saved on this device. Discard it before saving another.'**
  String get choreCompletionQueueOccupiedMessage;

  /// Explicitly removes a queued completion without replaying it
  ///
  /// In en, this message translates to:
  /// **'Discard saved completion'**
  String get choreCompletionDiscardAction;

  /// Tooltip for additional Today occurrence actions
  ///
  /// In en, this message translates to:
  /// **'More chore actions'**
  String get choreOccurrenceMenuTooltip;

  /// Action that skips one repeating chore occurrence
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence'**
  String get choreSkipOccurrenceAction;

  /// Confirmation title before skipping one occurrence
  ///
  /// In en, this message translates to:
  /// **'Skip this occurrence?'**
  String get choreSkipOccurrenceDialogTitle;

  /// Explains the single-occurrence scope of skip
  ///
  /// In en, this message translates to:
  /// **'This date will be skipped. The repeating schedule and every other occurrence will stay unchanged.'**
  String get choreSkipOccurrenceDialogBody;

  /// Confirms skipping one repeating occurrence
  ///
  /// In en, this message translates to:
  /// **'Skip occurrence'**
  String get choreSkipOccurrenceConfirmAction;

  /// Confirmation after one occurrence is skipped
  ///
  /// In en, this message translates to:
  /// **'This occurrence was skipped.'**
  String get choreSkipOccurrenceSucceeded;

  /// SnackBar action that restores the most recently skipped occurrence
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get choreRestoreSkippedAction;

  /// Confirmation after a skipped occurrence is restored
  ///
  /// In en, this message translates to:
  /// **'This occurrence is back on Today.'**
  String get choreRestoreSkippedSucceeded;

  /// Message when restoring a skipped occurrence fails
  ///
  /// In en, this message translates to:
  /// **'This occurrence could not be restored.'**
  String get choreRestoreSkippedFailed;

  /// Action that changes only one repeating occurrence date or time
  ///
  /// In en, this message translates to:
  /// **'Reschedule this occurrence'**
  String get choreRescheduleOccurrenceAction;

  /// Title for the single-occurrence reschedule dialog
  ///
  /// In en, this message translates to:
  /// **'Reschedule this occurrence'**
  String get choreRescheduleDialogTitle;

  /// Explains the scope of a single-occurrence reschedule
  ///
  /// In en, this message translates to:
  /// **'Only this date changes. The repeating schedule and every other occurrence will stay unchanged.'**
  String get choreRescheduleDialogBody;

  /// Confirms a single-occurrence date or time change
  ///
  /// In en, this message translates to:
  /// **'Save new schedule'**
  String get choreRescheduleConfirmAction;

  /// Confirmation after one occurrence is rescheduled
  ///
  /// In en, this message translates to:
  /// **'This occurrence was rescheduled.'**
  String get choreRescheduleSucceeded;

  /// Action that changes only one repeating occurrence assignee
  ///
  /// In en, this message translates to:
  /// **'Change assignee for this occurrence'**
  String get choreReassignOccurrenceAction;

  /// Title for the single-occurrence reassignment dialog
  ///
  /// In en, this message translates to:
  /// **'Change this occurrence\'s assignee'**
  String get choreReassignDialogTitle;

  /// Explains the scope of a single-occurrence reassignment
  ///
  /// In en, this message translates to:
  /// **'Only this occurrence changes. The repeating schedule and every other occurrence will keep their assignee.'**
  String get choreReassignDialogBody;

  /// Confirms a single-occurrence assignee change
  ///
  /// In en, this message translates to:
  /// **'Save assignee'**
  String get choreReassignConfirmAction;

  /// Confirmation after one occurrence is reassigned
  ///
  /// In en, this message translates to:
  /// **'This occurrence was reassigned.'**
  String get choreReassignSucceeded;

  /// Message when the reassignment member roster cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Household members could not be loaded. Try again.'**
  String get choreReassignRosterFailed;

  /// Action that edits all fields of a scheduled one-time chore
  ///
  /// In en, this message translates to:
  /// **'Edit this one-time chore'**
  String get choreEditOneTimeAction;

  /// Action that soft-deletes a scheduled one-time chore
  ///
  /// In en, this message translates to:
  /// **'Delete this one-time chore'**
  String get choreDeleteOneTimeAction;

  /// Title for the one-time chore edit dialog
  ///
  /// In en, this message translates to:
  /// **'Edit this one-time chore'**
  String get choreEditOneTimeDialogTitle;

  /// Explains the scope and completed-state boundary of a one-time chore edit
  ///
  /// In en, this message translates to:
  /// **'Update its details, assignee, date, or time. Completed chores must be reopened before they can be edited.'**
  String get choreEditOneTimeDialogBody;

  /// Confirms a one-time chore edit
  ///
  /// In en, this message translates to:
  /// **'Save chore changes'**
  String get choreEditOneTimeConfirmAction;

  /// Confirmation after a one-time chore is updated
  ///
  /// In en, this message translates to:
  /// **'The one-time chore was updated.'**
  String get choreEditOneTimeSucceeded;

  /// Confirmation title before soft-deleting a one-time chore
  ///
  /// In en, this message translates to:
  /// **'Delete this one-time chore?'**
  String get choreDeleteOneTimeDialogTitle;

  /// Explains list removal and history preservation for one-time chore deletion
  ///
  /// In en, this message translates to:
  /// **'It will be removed from chore lists. Its protected history will be kept.'**
  String get choreDeleteOneTimeDialogBody;

  /// Confirms one-time chore deletion
  ///
  /// In en, this message translates to:
  /// **'Delete chore'**
  String get choreDeleteOneTimeConfirmAction;

  /// Confirmation after a one-time chore is soft-deleted
  ///
  /// In en, this message translates to:
  /// **'The one-time chore was deleted.'**
  String get choreDeleteOneTimeSucceeded;

  /// Action that changes a repeating chore series from household-local today onward
  ///
  /// In en, this message translates to:
  /// **'Edit repeating series'**
  String get choreEditSeriesAction;

  /// Action that cancels incomplete occurrences in a repeating chore series from today onward
  ///
  /// In en, this message translates to:
  /// **'Cancel repeating series'**
  String get choreCancelSeriesAction;

  /// Title for the repeating chore series edit dialog
  ///
  /// In en, this message translates to:
  /// **'Edit the repeating series'**
  String get choreEditSeriesDialogTitle;

  /// Explains the effective boundary of a whole-series edit
  ///
  /// In en, this message translates to:
  /// **'Changes apply from today in the household time zone. Past occurrences and completed chores stay unchanged.'**
  String get choreEditSeriesDialogBody;

  /// Confirms a repeating chore series edit
  ///
  /// In en, this message translates to:
  /// **'Save series changes'**
  String get choreEditSeriesConfirmAction;

  /// Confirmation after a repeating chore series is updated
  ///
  /// In en, this message translates to:
  /// **'The repeating series was updated from today.'**
  String get choreEditSeriesSucceeded;

  /// Edits a repeating chore beginning at the selected future occurrence
  ///
  /// In en, this message translates to:
  /// **'Edit from this occurrence'**
  String get choreEditSeriesFromOccurrenceAction;

  /// Title for a selected-occurrence repeating chore series edit
  ///
  /// In en, this message translates to:
  /// **'Edit this and later occurrences'**
  String get choreEditSeriesFromOccurrenceDialogTitle;

  /// Explains the server-owned selected recurrence boundary and exception reset
  ///
  /// In en, this message translates to:
  /// **'The selected occurrence and later incomplete chores will use the new series settings. Earlier and completed chores stay unchanged. Later incomplete one-occurrence adjustments may reset to the new defaults.'**
  String get choreEditSeriesFromOccurrenceDialogBody;

  /// Confirms a selected-occurrence repeating chore series edit
  ///
  /// In en, this message translates to:
  /// **'Save from this occurrence'**
  String get choreEditSeriesFromOccurrenceConfirmAction;

  /// Confirmation after a selected-occurrence series edit
  ///
  /// In en, this message translates to:
  /// **'The repeating series was updated from the selected occurrence.'**
  String get choreEditSeriesFromOccurrenceSucceeded;

  /// Cancels a repeating chore beginning at the selected future occurrence
  ///
  /// In en, this message translates to:
  /// **'Cancel from this occurrence'**
  String get choreCancelSeriesFromOccurrenceAction;

  /// Title for a selected-occurrence repeating chore cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancel this and later occurrences?'**
  String get choreCancelSeriesFromOccurrenceDialogTitle;

  /// Explains the server-owned selected recurrence cancellation boundary
  ///
  /// In en, this message translates to:
  /// **'The selected occurrence and later incomplete chores will be removed. Earlier occurrences and completed chores stay unchanged.'**
  String get choreCancelSeriesFromOccurrenceDialogBody;

  /// Confirms a selected-occurrence repeating chore cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancel from this occurrence'**
  String get choreCancelSeriesFromOccurrenceConfirmAction;

  /// Confirmation after a selected-occurrence series cancellation
  ///
  /// In en, this message translates to:
  /// **'The repeating series was cancelled from the selected occurrence.'**
  String get choreCancelSeriesFromOccurrenceSucceeded;

  /// Restores a repeating series immediately after selected-occurrence cancellation
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get choreCancelSeriesFromOccurrenceUndoAction;

  /// Confirmation after restoring a selected-occurrence series cancellation
  ///
  /// In en, this message translates to:
  /// **'The repeating series was restored.'**
  String get choreCancelSeriesFromOccurrenceUndoSucceeded;

  /// Retryable failure while restoring a selected-occurrence series cancellation
  ///
  /// In en, this message translates to:
  /// **'Could not restore the repeating series. Try again.'**
  String get choreCancelSeriesFromOccurrenceUndoFailed;

  /// Confirmation title before cancelling a repeating chore series
  ///
  /// In en, this message translates to:
  /// **'Cancel this repeating series?'**
  String get choreCancelSeriesDialogTitle;

  /// Explains the effective boundary of a repeating series cancellation
  ///
  /// In en, this message translates to:
  /// **'Incomplete occurrences from today onward will be removed. Past occurrences and completed chores stay unchanged.'**
  String get choreCancelSeriesDialogBody;

  /// Confirms cancellation of a repeating chore series
  ///
  /// In en, this message translates to:
  /// **'Cancel series'**
  String get choreCancelSeriesConfirmAction;

  /// Confirmation after a repeating chore series is cancelled
  ///
  /// In en, this message translates to:
  /// **'The repeating series was cancelled from today.'**
  String get choreCancelSeriesSucceeded;

  /// Accessible action for opening one chore occurrence's detail sheet
  ///
  /// In en, this message translates to:
  /// **'View chore details and activity'**
  String get choreDetailsAction;

  /// Title for the chore occurrence detail sheet
  ///
  /// In en, this message translates to:
  /// **'Chore details'**
  String get choreDetailsTitle;

  /// Tooltip for closing the chore occurrence detail sheet
  ///
  /// In en, this message translates to:
  /// **'Close chore details'**
  String get choreDetailsCloseTooltip;

  /// Heading for the current chore occurrence information
  ///
  /// In en, this message translates to:
  /// **'Current details'**
  String get choreDetailsCurrentHeading;

  /// Accessible status while an authoritative chore target loads
  ///
  /// In en, this message translates to:
  /// **'Loading the latest chore details'**
  String get choreTargetLoading;

  /// Indistinguishable heading for a missing or unauthorized chore target
  ///
  /// In en, this message translates to:
  /// **'This chore is unavailable'**
  String get choreTargetUnavailableTitle;

  /// Safe explanation for a missing or unauthorized chore target
  ///
  /// In en, this message translates to:
  /// **'It may have changed, been removed, or no longer be available in this household.'**
  String get choreTargetUnavailableBody;

  /// Heading for a transient authoritative chore target failure
  ///
  /// In en, this message translates to:
  /// **'Chore details could not be loaded'**
  String get choreTargetLoadFailedTitle;

  /// Safe explanation for a transient authoritative chore target failure
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. No cached chore details are shown here.'**
  String get choreTargetLoadFailedBody;

  /// Recovery action from a chore target to the notification center
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get choreTargetNotificationsAction;

  /// Recovery action from a chore target to the Chores hub
  ///
  /// In en, this message translates to:
  /// **'Open chores'**
  String get choreTargetChoresAction;

  /// Heading for the chore occurrence activity history
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get choreHistoryHeading;

  /// Accessible status while chore activity loads
  ///
  /// In en, this message translates to:
  /// **'Loading chore activity'**
  String get choreHistoryLoading;

  /// Heading when a chore occurrence has no recorded activity
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get choreHistoryEmptyTitle;

  /// Explanation when a chore occurrence has no recorded activity
  ///
  /// In en, this message translates to:
  /// **'Changes to this occurrence will appear here.'**
  String get choreHistoryEmptyBody;

  /// Safe message when initial chore activity loading fails
  ///
  /// In en, this message translates to:
  /// **'Chore activity could not be loaded. Try again.'**
  String get choreHistoryLoadFailed;

  /// Action that loads the next page of older chore activity
  ///
  /// In en, this message translates to:
  /// **'Load earlier activity'**
  String get choreHistoryLoadMoreAction;

  /// Accessible status while older chore activity loads
  ///
  /// In en, this message translates to:
  /// **'Loading earlier activity'**
  String get choreHistoryLoadingMore;

  /// Safe message when an older chore activity page fails
  ///
  /// In en, this message translates to:
  /// **'Earlier activity could not be loaded.'**
  String get choreHistoryLoadMoreFailed;

  /// Actor label when an authenticated member acted for another household member
  ///
  /// In en, this message translates to:
  /// **'{actorName} for {actingName}'**
  String choreHistoryActorActingAs(String actorName, String actingName);

  /// History entry for completing an occurrence
  ///
  /// In en, this message translates to:
  /// **'{actorName} completed this chore.'**
  String choreHistoryCompleted(String actorName);

  /// History entry for reopening a completed occurrence
  ///
  /// In en, this message translates to:
  /// **'{actorName} reopened this chore.'**
  String choreHistoryReopened(String actorName);

  /// History entry for skipping a repeating occurrence
  ///
  /// In en, this message translates to:
  /// **'{actorName} skipped this occurrence.'**
  String choreHistorySkipped(String actorName);

  /// History entry for restoring a skipped occurrence
  ///
  /// In en, this message translates to:
  /// **'{actorName} restored this occurrence.'**
  String choreHistoryRestored(String actorName);

  /// History entry for changing one occurrence's schedule
  ///
  /// In en, this message translates to:
  /// **'{actorName} changed the schedule from {previousSchedule} to {newSchedule}.'**
  String choreHistoryRescheduled(
    String actorName,
    String previousSchedule,
    String newSchedule,
  );

  /// History entry for changing one occurrence's assignee
  ///
  /// In en, this message translates to:
  /// **'{actorName} changed the assignee from {previousAssignee} to {newAssignee}.'**
  String choreHistoryReassigned(
    String actorName,
    String previousAssignee,
    String newAssignee,
  );

  /// Localized date and time for a chore activity entry
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String choreHistoryTimestamp(String date, String time);

  /// Localized household-local date and time for a chore schedule
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String choreScheduleLabel(String date, String time);

  /// Chore creation screen title
  ///
  /// In en, this message translates to:
  /// **'Add a chore'**
  String get choreCreateTitle;

  /// Chore creation heading
  ///
  /// In en, this message translates to:
  /// **'Schedule a household task'**
  String get choreCreateHeading;

  /// Explains one-time and repeating chore creation
  ///
  /// In en, this message translates to:
  /// **'Choose an active adult, the first due date, and whether this task repeats.'**
  String get choreCreateBody;

  /// Heading for app-bundled chore templates
  ///
  /// In en, this message translates to:
  /// **'Quick starts'**
  String get choreTemplatesHeading;

  /// Explains that chore template values remain editable
  ///
  /// In en, this message translates to:
  /// **'Choose a suggestion to fill its title and repeat. You can edit every detail.'**
  String get choreTemplatesBody;

  /// Label for filtering the app-bundled chore template library by localized title
  ///
  /// In en, this message translates to:
  /// **'Search quick starts'**
  String get choreTemplateSearchLabel;

  /// Clears the chore template title search query
  ///
  /// In en, this message translates to:
  /// **'Clear template search'**
  String get choreTemplateSearchClearAction;

  /// Shows every app-bundled chore template category
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get choreTemplateCategoryAll;

  /// Kitchen chore template category
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get choreTemplateCategoryKitchen;

  /// Cleaning chore template category
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get choreTemplateCategoryCleaning;

  /// Laundry chore template category
  ///
  /// In en, this message translates to:
  /// **'Laundry'**
  String get choreTemplateCategoryLaundry;

  /// General home care chore template category
  ///
  /// In en, this message translates to:
  /// **'Home care'**
  String get choreTemplateCategoryHomeCare;

  /// Pet care chore template category
  ///
  /// In en, this message translates to:
  /// **'Pet care'**
  String get choreTemplateCategoryPetCare;

  /// Empty state for a chore template search and category intersection
  ///
  /// In en, this message translates to:
  /// **'No quick starts match this search and category.'**
  String get choreTemplateNoResults;

  /// Generic dishes chore template title
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get choreTemplateDishes;

  /// Generic kitchen reset chore template title
  ///
  /// In en, this message translates to:
  /// **'Kitchen reset'**
  String get choreTemplateKitchenReset;

  /// Generic laundry chore template title
  ///
  /// In en, this message translates to:
  /// **'Laundry'**
  String get choreTemplateLaundry;

  /// Generic vacuuming chore template title
  ///
  /// In en, this message translates to:
  /// **'Vacuuming'**
  String get choreTemplateVacuuming;

  /// Generic bathroom cleaning chore template title
  ///
  /// In en, this message translates to:
  /// **'Bathroom cleaning'**
  String get choreTemplateBathroomCleaning;

  /// Generic trash and recycling chore template title
  ///
  /// In en, this message translates to:
  /// **'Trash and recycling'**
  String get choreTemplateTrashAndRecycling;

  /// Generic counter wiping chore template title
  ///
  /// In en, this message translates to:
  /// **'Wipe counters'**
  String get choreTemplateWipeCounters;

  /// Generic fridge cleanout chore template title
  ///
  /// In en, this message translates to:
  /// **'Clean out the fridge'**
  String get choreTemplateFridgeCleanout;

  /// Generic floor mopping chore template title
  ///
  /// In en, this message translates to:
  /// **'Mop floors'**
  String get choreTemplateMopFloors;

  /// Generic dusting chore template title
  ///
  /// In en, this message translates to:
  /// **'Dust'**
  String get choreTemplateDusting;

  /// Generic bed linen change chore template title
  ///
  /// In en, this message translates to:
  /// **'Change bed linen'**
  String get choreTemplateChangeBedLinen;

  /// Generic clothes folding chore template title
  ///
  /// In en, this message translates to:
  /// **'Fold clothes'**
  String get choreTemplateFoldClothes;

  /// Generic bed making chore template title
  ///
  /// In en, this message translates to:
  /// **'Make beds'**
  String get choreTemplateMakeBeds;

  /// Generic plant watering chore template title
  ///
  /// In en, this message translates to:
  /// **'Water plants'**
  String get choreTemplateWaterPlants;

  /// Generic pet feeding chore template title
  ///
  /// In en, this message translates to:
  /// **'Feed pets'**
  String get choreTemplateFeedPets;

  /// Generic pet area cleaning chore template title
  ///
  /// In en, this message translates to:
  /// **'Clean pet area'**
  String get choreTemplateCleanPetArea;

  /// First-household guided chore setup screen title
  ///
  /// In en, this message translates to:
  /// **'Set up your first chores'**
  String get guidedChoreSetupTitle;

  /// First-household guided chore setup heading
  ///
  /// In en, this message translates to:
  /// **'Choose three chores to start together'**
  String get guidedChoreSetupHeading;

  /// Explains the value and exact count of guided chore setup
  ///
  /// In en, this message translates to:
  /// **'A small shared list makes Today useful right away. Pick exactly three chores, then review them before adding.'**
  String get guidedChoreSetupBody;

  /// Status while authoritative household date is loaded
  ///
  /// In en, this message translates to:
  /// **'Preparing household chore suggestions'**
  String get guidedChoreSetupLoading;

  /// Explains that a submitted guided chore batch is resuming after an interruption
  ///
  /// In en, this message translates to:
  /// **'Your saved setup was restored. Safely continuing from the last confirmed chore.'**
  String get guidedChoreSetupResumeNotice;

  /// Live progress while selecting exactly three chore templates
  ///
  /// In en, this message translates to:
  /// **'{selected} of {required} selected'**
  String guidedChoreSetupSelectionProgress(int selected, int required);

  /// Live progress while the guided chores are created sequentially
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} chores added'**
  String guidedChoreSetupAddingProgress(int completed, int total);

  /// Explains assignee, all-day, start date, and household timezone defaults
  ///
  /// In en, this message translates to:
  /// **'Assigned to you, available any time, and repeating from {startDate} in {timezone}. You can edit them later.'**
  String guidedChoreSetupDefaultsBody(String startDate, String timezone);

  /// Instructions for selecting three editable chore templates
  ///
  /// In en, this message translates to:
  /// **'Pick exactly three suggestions. Selected titles and repeat schedules remain editable.'**
  String get guidedChoreSetupChooseBody;

  /// Heading above selected guided chore fields
  ///
  /// In en, this message translates to:
  /// **'Review your three chores'**
  String get guidedChoreSetupReviewHeading;

  /// Submits all three guided chore drafts
  ///
  /// In en, this message translates to:
  /// **'Add 3 chores'**
  String get guidedChoreSetupAddAction;

  /// Retries only remaining guided chore requests
  ///
  /// In en, this message translates to:
  /// **'Continue adding chores'**
  String get guidedChoreSetupRetryAction;

  /// Starts confirmation to leave guided setup
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get guidedChoreSetupSkipAction;

  /// Confirmation title before leaving guided setup
  ///
  /// In en, this message translates to:
  /// **'Leave quick setup?'**
  String get guidedChoreSetupExitTitle;

  /// Confirmation when no guided chore has been created
  ///
  /// In en, this message translates to:
  /// **'You can add chores later from Today. Leave quick setup now?'**
  String get guidedChoreSetupExitBody;

  /// Confirmation that partial guided setup results are preserved
  ///
  /// In en, this message translates to:
  /// **'Added so far: {completed}. Those chores will stay in the household, and you can add the rest later. Continue to Today?'**
  String guidedChoreSetupPartialExitBody(int completed);

  /// Dismisses the guided setup exit confirmation
  ///
  /// In en, this message translates to:
  /// **'Keep setting up'**
  String get guidedChoreSetupStayAction;

  /// Leaves guided setup and opens Today
  ///
  /// In en, this message translates to:
  /// **'Continue to Today'**
  String get guidedChoreSetupContinueTodayAction;

  /// Chore title input label
  ///
  /// In en, this message translates to:
  /// **'Chore'**
  String get choreTitleLabel;

  /// Required chore title validation
  ///
  /// In en, this message translates to:
  /// **'Enter a chore name.'**
  String get choreTitleValidation;

  /// Optional chore notes input label
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get choreDescriptionLabel;

  /// Chore assignee field label
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get choreAssigneeLabel;

  /// Current adult in the assignee menu
  ///
  /// In en, this message translates to:
  /// **'{memberName} (you)'**
  String choreAssigneeYou(String memberName);

  /// Chore recurrence selector label
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get choreRecurrenceLabel;

  /// One-time chore recurrence option
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get choreRecurrenceOnce;

  /// Daily chore recurrence label
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get choreRecurrenceDaily;

  /// Weekly chore recurrence label
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get choreRecurrenceWeekly;

  /// Monthly chore recurrence label
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get choreRecurrenceMonthly;

  /// Summary of a simple repeating chore before save
  ///
  /// In en, this message translates to:
  /// **'{pattern}, starting {startDate}. Future dates are created in the household time zone.'**
  String choreRecurrenceSummary(String pattern, String startDate);

  /// Weekly chore recurrence weekday selector heading
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get choreRecurrenceWeekdaysLabel;

  /// Explains the required recurring chore creation start-date weekday
  ///
  /// In en, this message translates to:
  /// **'The chore\'s first weekday stays selected.'**
  String get choreRecurrenceWeekdayCreationAnchorHelper;

  /// Explains the non-empty weekly chore series rule
  ///
  /// In en, this message translates to:
  /// **'Keep at least one repeat day selected.'**
  String get choreRecurrenceWeekdayMinimumHelper;

  /// Monday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get choreRecurrenceWeekdayMonday;

  /// Tuesday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get choreRecurrenceWeekdayTuesday;

  /// Wednesday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get choreRecurrenceWeekdayWednesday;

  /// Thursday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get choreRecurrenceWeekdayThursday;

  /// Friday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get choreRecurrenceWeekdayFriday;

  /// Saturday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get choreRecurrenceWeekdaySaturday;

  /// Sunday weekly chore recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get choreRecurrenceWeekdaySunday;

  /// Selected weekly chore recurrence weekday list
  ///
  /// In en, this message translates to:
  /// **'On {weekdays}.'**
  String choreRecurrenceWeekdaysSummary(String weekdays);

  /// Monthly chore day-of-month selector label
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get choreRecurrenceMonthDayLabel;

  /// Monthly chore day-of-month menu option
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String choreRecurrenceMonthDayOption(int day);

  /// Explains why monthly chore creation derives its day from the first due date
  ///
  /// In en, this message translates to:
  /// **'The first due date sets this day.'**
  String get choreRecurrenceMonthDayCreationAnchorHelper;

  /// Explains the monthly chore missing-date policy
  ///
  /// In en, this message translates to:
  /// **'Months without this date are skipped, not moved to the last day.'**
  String get choreRecurrenceMonthDayMissingDateHelper;

  /// Selected monthly chore day-of-month summary
  ///
  /// In en, this message translates to:
  /// **'On day {day} of the month.'**
  String choreRecurrenceMonthDaySummary(int day);

  /// Number of recurrence units between chore occurrences
  ///
  /// In en, this message translates to:
  /// **'Repeat interval'**
  String get choreRecurrenceIntervalLabel;

  /// Supported chore recurrence interval range
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to 30.'**
  String get choreRecurrenceIntervalHelper;

  /// Invalid chore recurrence interval message
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 30.'**
  String get choreRecurrenceIntervalValidation;

  /// Chore recurrence end mode selector
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get choreRecurrenceEndLabel;

  /// Recurrence has no explicit end
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get choreRecurrenceEndNever;

  /// Recurrence ends after a bounded occurrence count
  ///
  /// In en, this message translates to:
  /// **'After a number of occurrences'**
  String get choreRecurrenceEndAfterCount;

  /// Recurrence ends on a household-local date
  ///
  /// In en, this message translates to:
  /// **'On a date'**
  String get choreRecurrenceEndOnDate;

  /// Recurring chore occurrence count input
  ///
  /// In en, this message translates to:
  /// **'Number of occurrences'**
  String get choreRecurrenceCountLabel;

  /// Supported recurring chore count range
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to 1,000.'**
  String get choreRecurrenceCountHelper;

  /// Invalid recurring chore occurrence count
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 1,000.'**
  String get choreRecurrenceCountValidation;

  /// Household-local recurrence end date
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get choreRecurrenceUntilDateLabel;

  /// Summary shown while advanced recurrence input is invalid
  ///
  /// In en, this message translates to:
  /// **'Review the repeat settings.'**
  String get choreRecurrenceInvalidSummary;

  /// Daily recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every day} other{Every {interval} days}}'**
  String choreRecurrenceEveryDays(int interval);

  /// Weekly recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every week} other{Every {interval} weeks}}'**
  String choreRecurrenceEveryWeeks(int interval);

  /// Monthly recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every month} other{Every {interval} months}}'**
  String choreRecurrenceEveryMonths(int interval);

  /// Never-ending recurrence summary
  ///
  /// In en, this message translates to:
  /// **'This series does not have an end date.'**
  String get choreRecurrenceEndNeverSummary;

  /// Count-limited recurrence summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ends after 1 occurrence.} other{Ends after {count} occurrences.}}'**
  String choreRecurrenceEndCountSummary(int count);

  /// Date-limited recurrence summary
  ///
  /// In en, this message translates to:
  /// **'Ends on {date}.'**
  String choreRecurrenceEndUntilSummary(String date);

  /// One-time chore due date label
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get choreDueDateLabel;

  /// Optional one-time chore due time label
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get choreDueTimeLabel;

  /// Label when a chore has no due time
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get choreAllDayLabel;

  /// Clears an optional chore due time
  ///
  /// In en, this message translates to:
  /// **'Remove due time'**
  String get choreClearTimeAction;

  /// Submits a one-time chore
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get choreCreateAction;

  /// Status while a chore is created
  ///
  /// In en, this message translates to:
  /// **'Adding chore'**
  String get choreCreatingAction;

  /// Confirmation after chore creation
  ///
  /// In en, this message translates to:
  /// **'Chore added to the household.'**
  String get choreCreatedBody;

  /// Safe invalid chore input error
  ///
  /// In en, this message translates to:
  /// **'Check the chore details and try again.'**
  String get choreCreateInvalidError;

  /// Safe invalid recurrence rule error
  ///
  /// In en, this message translates to:
  /// **'That repeat schedule isn\'t supported. Review it and try again.'**
  String get choreRecurrenceInvalidError;

  /// Safe chore authorization or membership error
  ///
  /// In en, this message translates to:
  /// **'This household or assignee is no longer available. Reload and try again.'**
  String get chorePermissionError;

  /// Chore idempotency conflict error
  ///
  /// In en, this message translates to:
  /// **'The chore details changed during a retry. Review them and submit again.'**
  String get choreCreateConflictError;

  /// Chore action idempotency conflict error
  ///
  /// In en, this message translates to:
  /// **'This chore action changed during a retry. Reload and try again.'**
  String get choreActionConflictError;

  /// Stale chore occurrence version error
  ///
  /// In en, this message translates to:
  /// **'This chore changed elsewhere. The latest household status is shown.'**
  String get choreVersionConflictError;

  /// Invalid chore state transition error
  ///
  /// In en, this message translates to:
  /// **'That action no longer matches this chore\'s current status. The latest status is shown.'**
  String get choreTransitionConflictError;

  /// Generic safe chore failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or save chores. It is safe to try again.'**
  String get choreGenericError;

  /// Defense-in-depth error for attempted cached-state mutation
  ///
  /// In en, this message translates to:
  /// **'This saved snapshot is read-only. Reconnect and refresh before making changes.'**
  String get choreOfflineReadOnlyError;

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

  /// Navigation destination for the Chores route
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get choresNavigationLabel;

  /// Navigation destination for the Calendar route
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarNavigationLabel;

  /// Navigation destination for the Family route
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyNavigationLabel;

  /// Navigation destination for the Settings route
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsNavigationLabel;

  /// One-time household calendar screen title
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// Returns from Calendar to Today
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get calendarTodayAction;

  /// Calendar loading status
  ///
  /// In en, this message translates to:
  /// **'Loading household events'**
  String get calendarLoadingLabel;

  /// Empty one-time calendar heading
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get calendarEmptyTitle;

  /// Empty one-time calendar guidance
  ///
  /// In en, this message translates to:
  /// **'Add a timed event or an all-day plan for your household.'**
  String get calendarEmptyBody;

  /// Creates a one-time calendar event
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get calendarCreateAction;

  /// Opens the external calendar file import review
  ///
  /// In en, this message translates to:
  /// **'Import .ics'**
  String get calendarImportAction;

  /// External iCalendar file import screen title
  ///
  /// In en, this message translates to:
  /// **'Import calendar file'**
  String get calendarImportTitle;

  /// Bounded iCalendar import introduction
  ///
  /// In en, this message translates to:
  /// **'Choose one UTF-8 .ics file, review the supported events, and copy only the events you select into this household.'**
  String get calendarImportIntro;

  /// One-way copy and duplicate disclosure
  ///
  /// In en, this message translates to:
  /// **'This is a one-time copy, not a sync. Importing the same file again can create duplicate events, and later external changes are not applied.'**
  String get calendarImportCopyDisclosure;

  /// Opens the Android document picker for an iCalendar file
  ///
  /// In en, this message translates to:
  /// **'Choose .ics file'**
  String get calendarImportChooseFileAction;

  /// Replaces the current in-memory import preview
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get calendarImportChooseAnotherAction;

  /// Returns from calendar file import
  ///
  /// In en, this message translates to:
  /// **'Close import'**
  String get calendarImportBackAction;

  /// Calendar import file picker progress
  ///
  /// In en, this message translates to:
  /// **'Opening the secure document picker'**
  String get calendarImportPickingLabel;

  /// Participant roster loading before calendar import
  ///
  /// In en, this message translates to:
  /// **'Loading active household members'**
  String get calendarImportRosterLoading;

  /// Supported event count in an iCalendar file
  ///
  /// In en, this message translates to:
  /// **'Supported events: {count}'**
  String calendarImportSupportedCount(int count);

  /// Skipped event count in an iCalendar file
  ///
  /// In en, this message translates to:
  /// **'Skipped events: {count}'**
  String calendarImportSkippedCount(int count);

  /// Safe aggregate reasons for skipped iCalendar events
  ///
  /// In en, this message translates to:
  /// **'Invalid {invalid} · unsupported {unsupported} · duplicate in file {duplicate}'**
  String calendarImportSkippedDetails(
    int invalid,
    int unsupported,
    int duplicate,
  );

  /// Fields deliberately ignored by calendar import
  ///
  /// In en, this message translates to:
  /// **'Locations, links, organizers, attendees, attachments, and alarms are not copied or opened.'**
  String get calendarImportIgnoredFieldsDisclosure;

  /// Floating iCalendar time interpretation
  ///
  /// In en, this message translates to:
  /// **'Events without a time zone use the household time zone {timeZone}.'**
  String calendarImportFloatingDisclosure(String timeZone);

  /// DST overlap import policy
  ///
  /// In en, this message translates to:
  /// **'A repeated clock time uses its earlier valid occurrence.'**
  String get calendarImportOverlapDisclosure;

  /// Selectable imported event list heading
  ///
  /// In en, this message translates to:
  /// **'Events to copy'**
  String get calendarImportEventsHeading;

  /// Selected imported event count
  ///
  /// In en, this message translates to:
  /// **'Selected {selected} of {total}'**
  String calendarImportSelectedCount(int selected, int total);

  /// Valid file with no supported import candidates
  ///
  /// In en, this message translates to:
  /// **'This file contains no events that KinFlow can copy. Unsupported or invalid events stay unchanged in the source file.'**
  String get calendarImportNoSupportedEvents;

  /// Batch-wide calendar import participants heading
  ///
  /// In en, this message translates to:
  /// **'Participants for copied events'**
  String get calendarImportParticipantsHeading;

  /// Batch-wide participant selection explanation
  ///
  /// In en, this message translates to:
  /// **'The same active household members will be added to every selected event.'**
  String get calendarImportParticipantsHelper;

  /// Inclusive all-day import preview range
  ///
  /// In en, this message translates to:
  /// **'All day · {startDate}–{endDate}'**
  String calendarImportAllDayRange(String startDate, String endDate);

  /// Timed imported event preview
  ///
  /// In en, this message translates to:
  /// **'{date} · {time} · {duration} · {timeZone}'**
  String calendarImportTimedSummary(
    String date,
    String time,
    String duration,
    String timeZone,
  );

  /// Starts the selected calendar event import
  ///
  /// In en, this message translates to:
  /// **'Copy {count} selected events'**
  String calendarImportSubmitAction(int count);

  /// Sequential calendar import progress
  ///
  /// In en, this message translates to:
  /// **'Copied {completed} of {total} events'**
  String calendarImportProgress(int completed, int total);

  /// Calendar import first-failure stop summary
  ///
  /// In en, this message translates to:
  /// **'Copied {completed} of {total}. The next event was not copied.'**
  String calendarImportPartialFailure(int completed, int total);

  /// Retries a partial calendar import with frozen command identities
  ///
  /// In en, this message translates to:
  /// **'Retry the remaining events'**
  String get calendarImportRetryAction;

  /// Calendar import completion snackbar
  ///
  /// In en, this message translates to:
  /// **'Copied {count} events into the household calendar.'**
  String calendarImportSuccess(int count);

  /// Unavailable calendar import native picker
  ///
  /// In en, this message translates to:
  /// **'The document picker is unavailable in this app build.'**
  String get calendarImportPickerUnavailableError;

  /// Safe calendar import picker/read failure
  ///
  /// In en, this message translates to:
  /// **'The selected file could not be read safely. Choose it again or use another .ics file.'**
  String get calendarImportPickerFailedError;

  /// Invalid iCalendar structure error
  ///
  /// In en, this message translates to:
  /// **'This is not a valid supported iCalendar file. The source file was not changed.'**
  String get calendarImportInvalidFileError;

  /// Unsupported iCalendar version error
  ///
  /// In en, this message translates to:
  /// **'This file does not contain exactly one iCalendar version 2.0 calendar.'**
  String get calendarImportUnsupportedVersionError;

  /// Calendar import byte limit error
  ///
  /// In en, this message translates to:
  /// **'Choose an .ics file no larger than 256 KiB.'**
  String get calendarImportTooLargeError;

  /// Calendar import VEVENT limit error
  ///
  /// In en, this message translates to:
  /// **'Choose an .ics file with no more than 50 events.'**
  String get calendarImportTooManyEventsError;

  /// Edits a one-time calendar event
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get calendarEditAction;

  /// Deletes a one-time calendar event
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get calendarDeleteAction;

  /// Edits only the selected recurring event occurrence
  ///
  /// In en, this message translates to:
  /// **'Edit this occurrence'**
  String get calendarOccurrenceEditAction;

  /// Cancels only the selected recurring event occurrence
  ///
  /// In en, this message translates to:
  /// **'Cancel this occurrence'**
  String get calendarOccurrenceCancelAction;

  /// Marks a recurring occurrence with a one-off edit
  ///
  /// In en, this message translates to:
  /// **'Modified occurrence'**
  String get calendarOccurrenceModifiedLabel;

  /// Opens actions that affect the whole recurring series
  ///
  /// In en, this message translates to:
  /// **'Recurring series actions'**
  String get calendarSeriesMenuTooltip;

  /// Edits the whole recurring Calendar series from today
  ///
  /// In en, this message translates to:
  /// **'Edit entire series'**
  String get calendarSeriesEditAction;

  /// Edits the recurring Calendar series from the selected occurrence
  ///
  /// In en, this message translates to:
  /// **'Edit this and later'**
  String get calendarSeriesEditFromOccurrenceAction;

  /// Cancels the recurring Calendar series from the selected occurrence
  ///
  /// In en, this message translates to:
  /// **'End this and later'**
  String get calendarSeriesCancelFromOccurrenceAction;

  /// Ends the whole recurring Calendar series from today
  ///
  /// In en, this message translates to:
  /// **'End entire series'**
  String get calendarSeriesCancelAction;

  /// Displays the authoritative household time zone
  ///
  /// In en, this message translates to:
  /// **'Household time zone: {timeZone}'**
  String calendarHouseholdTimeZone(String timeZone);

  /// Timed event schedule summary
  ///
  /// In en, this message translates to:
  /// **'{date} · {time} · {duration}'**
  String calendarTimedSchedule(String date, String time, String duration);

  /// Single-day all-day event summary
  ///
  /// In en, this message translates to:
  /// **'All day · {date}'**
  String calendarAllDaySingle(String date);

  /// Multi-day all-day event summary using an inclusive display end
  ///
  /// In en, this message translates to:
  /// **'All day · {startDate} – {endDate}'**
  String calendarAllDayRange(String startDate, String endDate);

  /// Calendar participant display names
  ///
  /// In en, this message translates to:
  /// **'With {names}'**
  String calendarParticipantSummary(String names);

  /// One-time event creation dialog title
  ///
  /// In en, this message translates to:
  /// **'Add an event'**
  String get calendarEditorCreateTitle;

  /// One-time event editing dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get calendarEditorEditTitle;

  /// Single recurring occurrence editing dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit this occurrence'**
  String get calendarOccurrenceEditorEditTitle;

  /// Whole recurring Calendar series editing dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit entire series'**
  String get calendarSeriesEditorEditTitle;

  /// Selected-occurrence recurring Calendar series editing dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit this and later occurrences'**
  String get calendarSeriesEditFromOccurrenceEditorTitle;

  /// Explains the selected recurrence boundary and preserved Calendar history and exceptions
  ///
  /// In en, this message translates to:
  /// **'The selected occurrence and later series occurrences will use the new settings. Earlier occurrences and existing one-occurrence changes stay unchanged.'**
  String get calendarSeriesEditFromOccurrenceEditorBody;

  /// Calendar event title field
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get calendarTitleLabel;

  /// Required event title validation
  ///
  /// In en, this message translates to:
  /// **'Enter an event title.'**
  String get calendarTitleValidation;

  /// Optional event notes field
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get calendarDescriptionLabel;

  /// All-day event switch label
  ///
  /// In en, this message translates to:
  /// **'All-day event'**
  String get calendarAllDayLabel;

  /// Event start date field
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get calendarStartDateLabel;

  /// Inclusive all-day end date shown to the user
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get calendarEndDateLabel;

  /// Timed event local start time
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get calendarStartTimeLabel;

  /// Timed event duration selector
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get calendarDurationLabel;

  /// Event duration in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String calendarDurationMinutes(int minutes);

  /// Timed event IANA time zone
  ///
  /// In en, this message translates to:
  /// **'Time zone: {timeZone}'**
  String calendarTimeZoneLabel(String timeZone);

  /// DST overlap policy selector label
  ///
  /// In en, this message translates to:
  /// **'Repeated clock time'**
  String get calendarOverlapLabel;

  /// Earlier instant in a repeated DST clock time
  ///
  /// In en, this message translates to:
  /// **'Use the earlier occurrence'**
  String get calendarOverlapEarlier;

  /// Later instant in a repeated DST clock time
  ///
  /// In en, this message translates to:
  /// **'Use the later occurrence'**
  String get calendarOverlapLater;

  /// Household event participants heading
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get calendarParticipantsLabel;

  /// Participant selection validation
  ///
  /// In en, this message translates to:
  /// **'Choose at least one active household member.'**
  String get calendarParticipantValidation;

  /// Cancels calendar editing or deletion
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get calendarCancelAction;

  /// Saves a calendar event
  ///
  /// In en, this message translates to:
  /// **'Save event'**
  String get calendarSaveAction;

  /// Event deletion confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get calendarDeleteTitle;

  /// Event deletion confirmation body
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from the household calendar.'**
  String calendarDeleteBody(String title);

  /// Confirms event deletion
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get calendarDeleteConfirmAction;

  /// Single recurring occurrence cancellation confirmation title
  ///
  /// In en, this message translates to:
  /// **'Cancel this occurrence?'**
  String get calendarOccurrenceCancelTitle;

  /// Explains the scope of a single occurrence cancellation
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be cancelled only for this occurrence. The rest of the series will stay unchanged.'**
  String calendarOccurrenceCancelBody(String title);

  /// Confirms cancellation of one recurring occurrence
  ///
  /// In en, this message translates to:
  /// **'Cancel occurrence'**
  String get calendarOccurrenceCancelConfirmAction;

  /// Whole recurring Calendar series cancellation confirmation title
  ///
  /// In en, this message translates to:
  /// **'End this recurring series?'**
  String get calendarSeriesCancelTitle;

  /// Explains the server-owned today boundary and preserved past for whole-series cancellation
  ///
  /// In en, this message translates to:
  /// **'Today and future occurrences of “{title}” will be cancelled. Past occurrences will stay in calendar history.'**
  String calendarSeriesCancelBody(String title);

  /// Confirms cancellation of the whole recurring series
  ///
  /// In en, this message translates to:
  /// **'End series'**
  String get calendarSeriesCancelConfirmAction;

  /// Selected-occurrence recurring Calendar cancellation confirmation title
  ///
  /// In en, this message translates to:
  /// **'End this and later occurrences?'**
  String get calendarSeriesCancelFromOccurrenceTitle;

  /// Explains immutable recurrence-slot cancellation, preserved prefix and cancelled later exceptions
  ///
  /// In en, this message translates to:
  /// **'The selected recurrence of “{title}” and every later recurrence will be cancelled. Earlier recurrences stay unchanged, even if one was moved to a later display date. Existing one-occurrence changes at or after this recurrence will also be cancelled.'**
  String calendarSeriesCancelFromOccurrenceBody(String title);

  /// Confirms recurring Calendar cancellation from the selected occurrence
  ///
  /// In en, this message translates to:
  /// **'End this and later'**
  String get calendarSeriesCancelFromOccurrenceConfirmAction;

  /// Confirmation after selected-occurrence recurring Calendar cancellation
  ///
  /// In en, this message translates to:
  /// **'This and later occurrences were ended.'**
  String get calendarSeriesCancelFromOccurrenceSucceeded;

  /// Immediately restores a selected-occurrence recurring Calendar cancellation
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get calendarSeriesCancelFromOccurrenceUndoAction;

  /// Confirmation after immediate Calendar series cancellation Undo
  ///
  /// In en, this message translates to:
  /// **'The recurring calendar series was restored.'**
  String get calendarSeriesCancelFromOccurrenceUndoSucceeded;

  /// Retryable failure while restoring a selected-occurrence Calendar cancellation
  ///
  /// In en, this message translates to:
  /// **'Could not restore the recurring calendar series. Try again.'**
  String get calendarSeriesCancelFromOccurrenceUndoFailed;

  /// Safe participant roster loading error
  ///
  /// In en, this message translates to:
  /// **'Household participants could not be loaded. Try again.'**
  String get calendarRosterError;

  /// Safe invalid event input error
  ///
  /// In en, this message translates to:
  /// **'Check the event details and try again.'**
  String get calendarInvalidError;

  /// Safe event authorization error
  ///
  /// In en, this message translates to:
  /// **'This household, event, or participant is no longer available. Reload and try again.'**
  String get calendarPermissionError;

  /// Calendar command idempotency conflict
  ///
  /// In en, this message translates to:
  /// **'The event action changed during a retry. Reload and try again.'**
  String get calendarRetryConflictError;

  /// Stale event version error
  ///
  /// In en, this message translates to:
  /// **'This event changed elsewhere. Reload the latest calendar before trying again.'**
  String get calendarVersionConflictError;

  /// DST gap validation error
  ///
  /// In en, this message translates to:
  /// **'That local time does not exist because the clock changes then. Choose another time.'**
  String get calendarNonexistentTimeError;

  /// Safe recurring occurrence transition error
  ///
  /// In en, this message translates to:
  /// **'This occurrence can no longer be changed. Reload the latest calendar and try again.'**
  String get calendarOccurrenceTransitionError;

  /// Calendar agenda view selector
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get calendarAgendaView;

  /// Calendar day view selector
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calendarDayView;

  /// Calendar month view selector
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonthView;

  /// Moves the calendar to the previous period
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get calendarPreviousRangeAction;

  /// Moves the calendar to the next period
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get calendarNextRangeAction;

  /// Moves the current calendar view to the household-local current date
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get calendarGoToTodayAction;

  /// Inclusive displayed date range for an agenda
  ///
  /// In en, this message translates to:
  /// **'{startDate} – {endDate}'**
  String calendarDateRange(String startDate, String endDate);

  /// Heading for the selected date event list
  ///
  /// In en, this message translates to:
  /// **'Events on {date}'**
  String calendarSelectedDateHeading(String date);

  /// Empty message for the selected agenda, day, or month date
  ///
  /// In en, this message translates to:
  /// **'No events in this period.'**
  String get calendarNoEventsInView;

  /// Loads the next keyset page of calendar events
  ///
  /// In en, this message translates to:
  /// **'Load more events'**
  String get calendarLoadMoreAction;

  /// Safe calendar continuation loading failure
  ///
  /// In en, this message translates to:
  /// **'More events could not be loaded. Try again.'**
  String get calendarLoadMoreError;

  /// Short all-day event indicator
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calendarAllDayChip;

  /// Calendar recurrence selector label
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get calendarRecurrenceLabel;

  /// One-time calendar recurrence option
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get calendarRecurrenceOnce;

  /// Daily calendar recurrence option
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get calendarRecurrenceDaily;

  /// Weekly calendar recurrence option
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get calendarRecurrenceWeekly;

  /// Monthly calendar recurrence option
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get calendarRecurrenceMonthly;

  /// Weekly calendar recurrence weekday selector heading
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get calendarRecurrenceWeekdaysLabel;

  /// Explains the required weekly recurrence start-date anchor
  ///
  /// In en, this message translates to:
  /// **'The event\'s start weekday stays selected.'**
  String get calendarRecurrenceWeekdayAnchorHelper;

  /// Monday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get calendarRecurrenceWeekdayMonday;

  /// Tuesday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get calendarRecurrenceWeekdayTuesday;

  /// Wednesday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get calendarRecurrenceWeekdayWednesday;

  /// Thursday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get calendarRecurrenceWeekdayThursday;

  /// Friday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get calendarRecurrenceWeekdayFriday;

  /// Saturday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get calendarRecurrenceWeekdaySaturday;

  /// Sunday weekly recurrence choice
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get calendarRecurrenceWeekdaySunday;

  /// Selected weekly recurrence weekday list
  ///
  /// In en, this message translates to:
  /// **'On {weekdays}.'**
  String calendarRecurrenceWeekdaysSummary(String weekdays);

  /// Short weekly recurring event pattern and weekday summary
  ///
  /// In en, this message translates to:
  /// **'Repeats {pattern} on {weekdays}'**
  String calendarRecurrenceWeeklySummary(String pattern, String weekdays);

  /// Locked monthly calendar recurrence day label
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get calendarRecurrenceMonthDayLabel;

  /// Monthly calendar recurrence day option
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String calendarRecurrenceMonthDayOption(int day);

  /// Explains the required monthly recurrence start-date anchor
  ///
  /// In en, this message translates to:
  /// **'The event\'s start date sets this day.'**
  String get calendarRecurrenceMonthDayAnchorHelper;

  /// Explains the monthly recurrence missing-date policy
  ///
  /// In en, this message translates to:
  /// **'Months without this date are skipped, not moved to the last day.'**
  String get calendarRecurrenceMonthDayMissingDateHelper;

  /// Selected monthly calendar recurrence day summary
  ///
  /// In en, this message translates to:
  /// **'On day {day} of the month.'**
  String calendarRecurrenceMonthDaySummary(int day);

  /// Short monthly recurring event pattern and day summary
  ///
  /// In en, this message translates to:
  /// **'Repeats {pattern} on day {day}'**
  String calendarRecurrenceMonthlySummary(String pattern, int day);

  /// Number of recurrence units between calendar occurrences
  ///
  /// In en, this message translates to:
  /// **'Repeat interval'**
  String get calendarRecurrenceIntervalLabel;

  /// Supported calendar recurrence interval range
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to 30.'**
  String get calendarRecurrenceIntervalHelper;

  /// Invalid calendar recurrence interval message
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 30.'**
  String get calendarRecurrenceIntervalValidation;

  /// Calendar recurrence end mode selector
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get calendarRecurrenceEndLabel;

  /// Calendar recurrence has no explicit end
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get calendarRecurrenceEndNever;

  /// Calendar recurrence ends after a bounded occurrence count
  ///
  /// In en, this message translates to:
  /// **'After a number of occurrences'**
  String get calendarRecurrenceEndAfterCount;

  /// Calendar recurrence ends on a household-local date
  ///
  /// In en, this message translates to:
  /// **'On a date'**
  String get calendarRecurrenceEndOnDate;

  /// Calendar recurrence count input label
  ///
  /// In en, this message translates to:
  /// **'Number of occurrences'**
  String get calendarRecurrenceCountLabel;

  /// Supported calendar recurrence count range
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to 1,000.'**
  String get calendarRecurrenceCountHelper;

  /// Invalid calendar recurrence count message
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 1,000.'**
  String get calendarRecurrenceCountValidation;

  /// Calendar recurrence household-local until date picker label
  ///
  /// In en, this message translates to:
  /// **'Last occurrence date'**
  String get calendarRecurrenceUntilDateLabel;

  /// Calendar daily recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every day} other{Every {interval} days}}'**
  String calendarRecurrenceEveryDays(int interval);

  /// Calendar weekly recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every week} other{Every {interval} weeks}}'**
  String calendarRecurrenceEveryWeeks(int interval);

  /// Calendar monthly recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'{interval, plural, =1{Every month} other{Every {interval} months}}'**
  String calendarRecurrenceEveryMonths(int interval);

  /// Advanced calendar recurrence pattern and anchor summary
  ///
  /// In en, this message translates to:
  /// **'{pattern}, starting {startDate}.'**
  String calendarRecurrenceEditorSummary(String pattern, String startDate);

  /// Safe advanced calendar recurrence invalid-input summary
  ///
  /// In en, this message translates to:
  /// **'Complete the supported recurrence values.'**
  String get calendarRecurrenceInvalidSummary;

  /// Never-ending calendar recurrence summary
  ///
  /// In en, this message translates to:
  /// **'This series does not have an end date.'**
  String get calendarRecurrenceEndNeverSummary;

  /// Count-limited calendar recurrence summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ends after 1 occurrence.} other{Ends after {count} occurrences.}}'**
  String calendarRecurrenceEndCountSummary(int count);

  /// Date-limited calendar recurrence summary
  ///
  /// In en, this message translates to:
  /// **'Ends on {date}.'**
  String calendarRecurrenceEndUntilSummary(String date);

  /// Short recurring event pattern summary
  ///
  /// In en, this message translates to:
  /// **'Repeats {pattern}'**
  String calendarRecurrenceSummary(String pattern);

  /// Accessible month cell label with event count
  ///
  /// In en, this message translates to:
  /// **'{date}, {count} events'**
  String calendarMonthDateSemantics(String date, int count);

  /// Generic safe calendar failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or save calendar events. It is safe to try again.'**
  String get calendarGenericError;

  /// Heading for a deleted, cancelled, or unauthorized calendar deep-link target
  ///
  /// In en, this message translates to:
  /// **'Event unavailable'**
  String get calendarTargetUnavailableTitle;

  /// Safe content-free calendar deep-link failure
  ///
  /// In en, this message translates to:
  /// **'This event was removed, cancelled, or is no longer available to this household.'**
  String get calendarTargetUnavailableMessage;

  /// Returns from an unavailable event target to the normal calendar
  ///
  /// In en, this message translates to:
  /// **'Open calendar'**
  String get calendarBackToCalendarAction;

  /// Nonblocking Calendar Realtime disconnected state
  ///
  /// In en, this message translates to:
  /// **'Live updates are paused. The last loaded calendar may be out of date.'**
  String get calendarLiveDisconnectedMessage;

  /// Restarts Calendar Realtime and performs a full refetch
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get calendarReconnectAction;

  /// Nonblocking Chore Realtime disconnected state
  ///
  /// In en, this message translates to:
  /// **'Live chore updates are paused. The last loaded chores may be out of date.'**
  String get choreLiveDisconnectedMessage;

  /// Restarts visible Chore Realtime sources and performs full refetches
  ///
  /// In en, this message translates to:
  /// **'Reconnect chore updates'**
  String get choreReconnectAction;

  /// Nonblocking Notification Center Realtime disconnected state
  ///
  /// In en, this message translates to:
  /// **'Live notification updates are paused. The last loaded inbox and unread count may be out of date.'**
  String get notificationLiveDisconnectedMessage;

  /// Restarts Notification Center Realtime and performs a full snapshot refetch
  ///
  /// In en, this message translates to:
  /// **'Reconnect notification updates'**
  String get notificationReconnectAction;

  /// Conflict resolution after the target still exists
  ///
  /// In en, this message translates to:
  /// **'This event changed elsewhere. The latest calendar is loaded; review it before trying again.'**
  String get calendarConflictLatestReloadedMessage;

  /// Conflict resolution after the target can no longer be read
  ///
  /// In en, this message translates to:
  /// **'This event changed or was removed elsewhere. The latest calendar is loaded.'**
  String get calendarConflictTargetUnavailableMessage;

  /// Heading for the nonblocking same-member overlap preview
  ///
  /// In en, this message translates to:
  /// **'Schedule overlap hint'**
  String get calendarScheduleOverlapHeading;

  /// Calendar overlap preview loading state
  ///
  /// In en, this message translates to:
  /// **'Checking this schedule against household events…'**
  String get calendarScheduleOverlapChecking;

  /// Calendar overlap preview empty state
  ///
  /// In en, this message translates to:
  /// **'No same-member overlaps were found in the checked range.'**
  String get calendarScheduleOverlapNone;

  /// Safe nonblocking Calendar overlap preview failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check overlaps. You can still save, but review the household calendar first.'**
  String get calendarScheduleOverlapUnavailable;

  /// Explains that overlap hints never block Calendar writes
  ///
  /// In en, this message translates to:
  /// **'This is a hint only. Saving remains available.'**
  String get calendarScheduleOverlapSaveAllowed;

  /// Bounded Calendar overlap preview summary
  ///
  /// In en, this message translates to:
  /// **'{total} overlaps across {candidateCount} candidate occurrences checked from {fromDate} through {throughDate}.'**
  String calendarScheduleOverlapSummary(
    int total,
    int candidateCount,
    String fromDate,
    String throughDate,
  );

  /// Calendar overlap preview detail limit
  ///
  /// In en, this message translates to:
  /// **'Showing the first {limit} overlaps.'**
  String calendarScheduleOverlapTruncated(int limit);

  /// Local recurrence date for the proposed occurrence that overlaps
  ///
  /// In en, this message translates to:
  /// **'Candidate occurrence: {date}'**
  String calendarScheduleOverlapCandidateDate(String date);

  /// Notification inbox and settings screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// Opens the durable notification inbox
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get notificationOpenAction;

  /// Notification center loading status
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get notificationLoadingLabel;

  /// Durable notification inbox section heading
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notificationInboxHeading;

  /// Unread notification count
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notificationUnreadBadge(int count);

  /// Accessible unread badge label
  ///
  /// In en, this message translates to:
  /// **'{count} unread notifications'**
  String notificationBadgeSemantics(int count);

  /// Marks the recipient's active inbox items read
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationMarkAllReadAction;

  /// Empty notification inbox heading
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notificationEmptyTitle;

  /// Explains durable inbox behavior
  ///
  /// In en, this message translates to:
  /// **'New chore and calendar reminders will appear here even when push delivery is unavailable.'**
  String get notificationEmptyBody;

  /// Content-free chore due notification category
  ///
  /// In en, this message translates to:
  /// **'Chore due update'**
  String get notificationChoreDueLabel;

  /// Content-free chore assignment notification category
  ///
  /// In en, this message translates to:
  /// **'Chore assignment update'**
  String get notificationChoreAssignmentLabel;

  /// Content-free Calendar event reminder category
  ///
  /// In en, this message translates to:
  /// **'Calendar event reminder'**
  String get notificationCalendarEventLabel;

  /// Content-free chore or Calendar notification guidance
  ///
  /// In en, this message translates to:
  /// **'Open Today to securely load the latest authorized household details.'**
  String get notificationItemBody;

  /// Notification inbox creation display time
  ///
  /// In en, this message translates to:
  /// **'Received {date} · {time}'**
  String notificationCreatedSchedule(String date, String time);

  /// Opens fixed Calendar notification snooze choices
  ///
  /// In en, this message translates to:
  /// **'Remind me again'**
  String get notificationSnoozeAction;

  /// Calendar notification snooze choice sheet heading
  ///
  /// In en, this message translates to:
  /// **'When should we remind you again?'**
  String get notificationSnoozeSheetTitle;

  /// Explains durable inbox and push snooze behavior
  ///
  /// In en, this message translates to:
  /// **'The reminder will return to this inbox at the selected time and send another mobile push when enabled.'**
  String get notificationSnoozeSheetBody;

  /// Fixed notification snooze duration choice
  ///
  /// In en, this message translates to:
  /// **'In {minutes, plural, one{1 minute} other{{minutes} minutes}}'**
  String notificationSnoozeMinutesAction(int minutes);

  /// Calendar notification snooze success confirmation
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you again in {minutes, plural, one{1 minute} other{{minutes} minutes}}.'**
  String notificationSnoozeSucceeded(int minutes);

  /// Consecutive bounded snooze count
  ///
  /// In en, this message translates to:
  /// **'Snoozed {count} of 3 times'**
  String notificationSnoozeCount(int count);

  /// Revalidates authorization through the Today query
  ///
  /// In en, this message translates to:
  /// **'Open Today'**
  String get notificationOpenTodayAction;

  /// Loads the next notification keyset page
  ///
  /// In en, this message translates to:
  /// **'Load more notifications'**
  String get notificationLoadMoreAction;

  /// Safe inbox continuation error
  ///
  /// In en, this message translates to:
  /// **'More notifications could not be loaded. Try again.'**
  String get notificationLoadMoreError;

  /// Category preference section heading
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettingsHeading;

  /// Explains category and quiet-hour authority
  ///
  /// In en, this message translates to:
  /// **'Choose each category and set quiet hours in your current IANA timezone. Quiet hours delay future push and email delivery, not this inbox.'**
  String get notificationSettingsBody;

  /// Durable in-app channel preference
  ///
  /// In en, this message translates to:
  /// **'In-app inbox'**
  String get notificationInAppLabel;

  /// In-app channel explanation
  ///
  /// In en, this message translates to:
  /// **'Keep durable items in this inbox.'**
  String get notificationInAppBody;

  /// Native push preference prepared for device registration
  ///
  /// In en, this message translates to:
  /// **'Mobile push'**
  String get notificationNativePushLabel;

  /// Clarifies deferred device delivery
  ///
  /// In en, this message translates to:
  /// **'Saved now; delivery starts after a device is registered.'**
  String get notificationNativePushBody;

  /// Opt-in generic verified-account email preference
  ///
  /// In en, this message translates to:
  /// **'Account email'**
  String get notificationEmailLabel;

  /// Explains verified address, generic content, and durable inbox fallback
  ///
  /// In en, this message translates to:
  /// **'Send a generic reminder to your verified account email. No family details are included; this inbox remains available if delivery fails.'**
  String get notificationEmailBody;

  /// Quiet-hour preference label
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notificationQuietHoursLabel;

  /// Disabled quiet-hour summary
  ///
  /// In en, this message translates to:
  /// **'Off · {timezone}'**
  String notificationQuietHoursOff(String timezone);

  /// Enabled quiet-hour summary
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} · {timezone}'**
  String notificationQuietHoursSummary(
    String start,
    String end,
    String timezone,
  );

  /// Per-user Calendar reminder lead-time label
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get notificationReminderLeadLabel;

  /// Explains the pending-only Calendar reminder reschedule boundary
  ///
  /// In en, this message translates to:
  /// **'Changes apply only to Calendar reminders that have not been delivered yet.'**
  String get notificationReminderLeadBody;

  /// Zero-minute Calendar reminder lead option
  ///
  /// In en, this message translates to:
  /// **'At event time'**
  String get notificationReminderLeadAtStart;

  /// Positive Calendar reminder lead option
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{1 minute before} other{{minutes} minutes before}}'**
  String notificationReminderLeadMinutesBefore(int minutes);

  /// Calendar additional reminder selector label
  ///
  /// In en, this message translates to:
  /// **'Additional reminders'**
  String get notificationAdditionalRemindersLabel;

  /// Explains the bounded multiple-reminder behavior
  ///
  /// In en, this message translates to:
  /// **'Choose up to 2 more times. Each reminder is delivered separately.'**
  String get notificationAdditionalRemindersBody;

  /// Edits one notification category preference
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get notificationEditAction;

  /// Category preference editor title
  ///
  /// In en, this message translates to:
  /// **'Edit {category}'**
  String notificationEditorTitle(String category);

  /// Enables a category quiet-hour interval
  ///
  /// In en, this message translates to:
  /// **'Use quiet hours'**
  String get notificationQuietEnabledLabel;

  /// Quiet interval local start
  ///
  /// In en, this message translates to:
  /// **'Quiet starts'**
  String get notificationQuietStartLabel;

  /// Quiet interval local end
  ///
  /// In en, this message translates to:
  /// **'Quiet ends'**
  String get notificationQuietEndLabel;

  /// Recipient timezone preference field
  ///
  /// In en, this message translates to:
  /// **'IANA timezone'**
  String get notificationTimezoneLabel;

  /// Recipient IANA timezone selection hint
  ///
  /// In en, this message translates to:
  /// **'Choose by IANA region or city, such as Asia/Seoul'**
  String get notificationTimezoneHint;

  /// Recipient timezone picker title
  ///
  /// In en, this message translates to:
  /// **'Choose the notification timezone'**
  String get notificationTimezonePickerTitle;

  /// Client-side preference editor validation
  ///
  /// In en, this message translates to:
  /// **'Choose a valid IANA timezone and different quiet start and end times.'**
  String get notificationTimezoneValidation;

  /// Saves one category preference
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get notificationSaveAction;

  /// Closes the notification preference editor
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get notificationCancelAction;

  /// Safe invalid notification input error
  ///
  /// In en, this message translates to:
  /// **'Check the notification settings and try again.'**
  String get notificationInvalidInputError;

  /// Safe notification authorization error
  ///
  /// In en, this message translates to:
  /// **'This notification inbox or household is no longer available. Reload your session.'**
  String get notificationPermissionError;

  /// Stale notification preference version error
  ///
  /// In en, this message translates to:
  /// **'These settings changed elsewhere. Reload the latest settings and try again.'**
  String get notificationVersionConflictError;

  /// Safe bounded Calendar snooze unavailable error
  ///
  /// In en, this message translates to:
  /// **'This Calendar reminder can no longer be snoozed. Refresh the notification inbox.'**
  String get notificationSnoozeUnavailableError;

  /// Generic safe notification failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or save notifications. It is safe to try again.'**
  String get notificationGenericError;

  /// Android notification permission card heading
  ///
  /// In en, this message translates to:
  /// **'Device notifications'**
  String get notificationPushPermissionHeading;

  /// Privacy-preserving explanation shown before the Android permission prompt
  ///
  /// In en, this message translates to:
  /// **'KinFlow sends generic reminders only. Names, chore details, and calendar details stay out of push messages, and this in-app inbox remains available.'**
  String get notificationPushPrePromptBody;

  /// User gesture that may open the Android notification permission prompt
  ///
  /// In en, this message translates to:
  /// **'Enable device notifications'**
  String get notificationPushEnableAction;

  /// Notification permission denied guidance
  ///
  /// In en, this message translates to:
  /// **'Device notifications are off. You can allow them in Android settings; this in-app inbox still works.'**
  String get notificationPushDeniedBody;

  /// Opens this app's Android notification settings
  ///
  /// In en, this message translates to:
  /// **'Open Android settings'**
  String get notificationPushOpenSettingsAction;

  /// Authorized and registered notification status
  ///
  /// In en, this message translates to:
  /// **'Device notifications are enabled for this household.'**
  String get notificationPushAuthorizedBody;

  /// Unavailable mobile push adapter fallback
  ///
  /// In en, this message translates to:
  /// **'Device notifications are unavailable in this build. This in-app inbox still works.'**
  String get notificationPushUnavailableBody;

  /// Safe non-reflective mobile push setup error
  ///
  /// In en, this message translates to:
  /// **'Device notification setup could not finish. Your in-app inbox is unaffected.'**
  String get notificationPushSetupError;

  /// Generic content-free foreground notification title
  ///
  /// In en, this message translates to:
  /// **'KinFlow reminder'**
  String get notificationPushPresentationTitle;

  /// Generic content-free foreground notification body
  ///
  /// In en, this message translates to:
  /// **'Open KinFlow to view the latest household update.'**
  String get notificationPushPresentationBody;

  /// Android notification channel name
  ///
  /// In en, this message translates to:
  /// **'Household reminders'**
  String get notificationPushChannelName;

  /// Android notification channel description
  ///
  /// In en, this message translates to:
  /// **'Generic household reminders without private details'**
  String get notificationPushChannelDescription;

  /// Fail-closed feature policy unavailable message
  ///
  /// In en, this message translates to:
  /// **'Feature limits are not available yet. Try again after the household plan refreshes.'**
  String get featurePolicyUnavailableError;

  /// Server-authoritative household feature limit message
  ///
  /// In en, this message translates to:
  /// **'This household has reached the current plan limit. Review the plan to continue.'**
  String get featureLimitReachedError;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Opens account and application settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get settingsOpenAction;

  /// Account settings section heading
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// Active household switcher settings row title
  ///
  /// In en, this message translates to:
  /// **'Switch household'**
  String get settingsHouseholdSwitchTitle;

  /// Active household switcher settings row summary
  ///
  /// In en, this message translates to:
  /// **'View your households and choose which one is active.'**
  String get settingsHouseholdSwitchSummary;

  /// Active household switcher screen title
  ///
  /// In en, this message translates to:
  /// **'Switch household'**
  String get householdSwitchTitle;

  /// Privacy and behavior explanation for household switching
  ///
  /// In en, this message translates to:
  /// **'Only your own current memberships are shown. Switching reloads Today with the selected household.'**
  String get householdSwitchIntro;

  /// Accessible household selection loading label
  ///
  /// In en, this message translates to:
  /// **'Loading your households'**
  String get householdSwitchLoading;

  /// Empty household selection state
  ///
  /// In en, this message translates to:
  /// **'No available households were found for this account.'**
  String get householdSwitchEmpty;

  /// Label for the currently active household
  ///
  /// In en, this message translates to:
  /// **'Current household'**
  String get householdSwitchCurrentLabel;

  /// Owner role in household switcher
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get householdSwitchRoleOwner;

  /// Admin role in household switcher
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get householdSwitchRoleAdmin;

  /// Member role in household switcher
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get householdSwitchRoleMember;

  /// Active household switch confirmation title
  ///
  /// In en, this message translates to:
  /// **'Switch active household?'**
  String get householdSwitchConfirmTitle;

  /// Active household switch confirmation body
  ///
  /// In en, this message translates to:
  /// **'KinFlow will clear household-bound local data and reload Today for “{name}”.'**
  String householdSwitchConfirmBody(String name);

  /// Confirms active household switching
  ///
  /// In en, this message translates to:
  /// **'Switch household'**
  String get householdSwitchConfirmAction;

  /// Accessible active household switching progress
  ///
  /// In en, this message translates to:
  /// **'Switching household securely…'**
  String get householdSwitchInProgress;

  /// Safe household selection load error
  ///
  /// In en, this message translates to:
  /// **'Your household list could not be loaded. Try again.'**
  String get householdSwitchLoadError;

  /// Removed, deleted, or invalid household switch target error
  ///
  /// In en, this message translates to:
  /// **'That household is no longer available to this account. Refresh the list.'**
  String get householdSwitchTargetUnavailableError;

  /// Optimistic active household selection conflict
  ///
  /// In en, this message translates to:
  /// **'Your active household changed elsewhere. Refresh the list before switching.'**
  String get householdSwitchConflictError;

  /// Runtime-policy household mutation block
  ///
  /// In en, this message translates to:
  /// **'Household changes are temporarily paused. You can still view the current list.'**
  String get householdSwitchFeatureDisabledError;

  /// Fail-closed local transition failure after server commit
  ///
  /// In en, this message translates to:
  /// **'The server changed households, but this device could not safely clear local household data. Sign in again to recover.'**
  String get householdSwitchLocalStateError;

  /// Safe non-reflective household switch error
  ///
  /// In en, this message translates to:
  /// **'The household could not be switched safely. Refresh the list and try again.'**
  String get householdSwitchGenericError;

  /// Account deletion settings item
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountTitle;

  /// Account deletion settings item summary
  ///
  /// In en, this message translates to:
  /// **'Review eligibility, request deletion, or cancel a pending request.'**
  String get settingsDeleteAccountSummary;

  /// Account deletion lifecycle screen title
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeletionTitle;

  /// Accessible account deletion loading message
  ///
  /// In en, this message translates to:
  /// **'Checking account deletion status'**
  String get accountDeletionLoadingLabel;

  /// Account deletion explanation heading
  ///
  /// In en, this message translates to:
  /// **'What account deletion does'**
  String get accountDeletionIntroHeading;

  /// Explains personal data removed by account deletion
  ///
  /// In en, this message translates to:
  /// **'After the cancellation window, your profile, sign-in identity, personal notification settings, and device notification credentials are removed.'**
  String get accountDeletionIntroBody;

  /// Explains shared content retention
  ///
  /// In en, this message translates to:
  /// **'Shared household, chore, and calendar history stays available to the remaining household members under a deleted-member label.'**
  String get accountDeletionPreservedBody;

  /// Account deletion request status heading
  ///
  /// In en, this message translates to:
  /// **'Latest request'**
  String get accountDeletionStatusHeading;

  /// Queued account deletion status
  ///
  /// In en, this message translates to:
  /// **'Scheduled — you can still cancel'**
  String get accountDeletionStatusQueued;

  /// Verifying account deletion status
  ///
  /// In en, this message translates to:
  /// **'Verifying — you can still cancel'**
  String get accountDeletionStatusVerifying;

  /// Processing account deletion status
  ///
  /// In en, this message translates to:
  /// **'Deletion is being processed and can no longer be cancelled'**
  String get accountDeletionStatusProcessing;

  /// Completed account deletion status
  ///
  /// In en, this message translates to:
  /// **'Account deletion completed'**
  String get accountDeletionStatusCompleted;

  /// Failed account deletion status without provider details
  ///
  /// In en, this message translates to:
  /// **'Account deletion needs another attempt'**
  String get accountDeletionStatusFailed;

  /// Cancelled account deletion status
  ///
  /// In en, this message translates to:
  /// **'Account deletion cancelled'**
  String get accountDeletionStatusCancelled;

  /// Scheduled account deletion time
  ///
  /// In en, this message translates to:
  /// **'Deletion begins after {date}'**
  String accountDeletionScheduledFor(String date);

  /// Configured account deletion cancellation window
  ///
  /// In en, this message translates to:
  /// **'A new request can be cancelled for about {hours} hours.'**
  String accountDeletionCancellationWindow(int hours);

  /// Starts recent-authenticated account deletion request
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get accountDeletionRequestAction;

  /// Cancels a pending account deletion request
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion request'**
  String get accountDeletionCancelAction;

  /// Owner-transfer deletion blocker title
  ///
  /// In en, this message translates to:
  /// **'Transfer household ownership first'**
  String get accountDeletionOwnerBlockTitle;

  /// Owner-transfer deletion blocker body
  ///
  /// In en, this message translates to:
  /// **'You still own {count} active household(s). Transfer each one to another adult before deleting your account.'**
  String accountDeletionOwnerBlockBody(int count);

  /// Opens member management for ownership transfer
  ///
  /// In en, this message translates to:
  /// **'Manage household members'**
  String get accountDeletionManageHouseholdsAction;

  /// Active store subscription warning heading
  ///
  /// In en, this message translates to:
  /// **'Active subscription detected'**
  String get accountDeletionSubscriptionTitle;

  /// Store subscription survives account deletion warning
  ///
  /// In en, this message translates to:
  /// **'Deleting KinFlow does not cancel your App Store or Google Play subscription. Cancel it separately in the store if you no longer want it.'**
  String get accountDeletionSubscriptionBody;

  /// Required active subscription acknowledgement
  ///
  /// In en, this message translates to:
  /// **'I understand that account deletion does not cancel my store subscription.'**
  String get accountDeletionSubscriptionAcknowledge;

  /// Account deletion kill-switch state heading
  ///
  /// In en, this message translates to:
  /// **'Deletion requests are temporarily paused'**
  String get accountDeletionPausedTitle;

  /// Safe account deletion pause explanation
  ///
  /// In en, this message translates to:
  /// **'Your account remains active. Refresh later to check whether new requests are available.'**
  String get accountDeletionPausedBody;

  /// Account deletion confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Schedule account deletion?'**
  String get accountDeletionConfirmTitle;

  /// Account deletion confirmation and session effect
  ///
  /// In en, this message translates to:
  /// **'You will be signed out on this device immediately. Sign in again before the deadline if you need to cancel the request.'**
  String get accountDeletionConfirmBody;

  /// Confirms account deletion request
  ///
  /// In en, this message translates to:
  /// **'Schedule deletion'**
  String get accountDeletionConfirmAction;

  /// Dismisses account deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get accountDeletionConfirmCancelAction;

  /// Cancellation confirmation title
  ///
  /// In en, this message translates to:
  /// **'Cancel account deletion?'**
  String get accountDeletionCancelConfirmTitle;

  /// Cancellation confirmation body
  ///
  /// In en, this message translates to:
  /// **'Your account will remain active and this deletion request will not run.'**
  String get accountDeletionCancelConfirmBody;

  /// Confirms pending deletion cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion'**
  String get accountDeletionCancelConfirmAction;

  /// Safe account deletion authorization failure
  ///
  /// In en, this message translates to:
  /// **'This account deletion request is no longer available. Refresh your session.'**
  String get accountDeletionPermissionError;

  /// Recent authentication required failure
  ///
  /// In en, this message translates to:
  /// **'Confirm your Google sign-in again before requesting account deletion.'**
  String get accountDeletionRecentAuthError;

  /// Cancelled recent authentication message
  ///
  /// In en, this message translates to:
  /// **'Account confirmation was cancelled. No deletion request was sent.'**
  String get accountDeletionRecentAuthCancelled;

  /// Recent authentication account mismatch
  ///
  /// In en, this message translates to:
  /// **'The confirmed Google account did not match this KinFlow account. No deletion request was sent.'**
  String get accountDeletionAccountChangedError;

  /// Owner transfer required failure
  ///
  /// In en, this message translates to:
  /// **'Transfer every household you own before requesting deletion.'**
  String get accountDeletionOwnerTransferError;

  /// Subscription acknowledgement required failure
  ///
  /// In en, this message translates to:
  /// **'Acknowledge the active store subscription notice before continuing.'**
  String get accountDeletionSubscriptionError;

  /// Duplicate pending account deletion failure
  ///
  /// In en, this message translates to:
  /// **'An account deletion request is already pending. Refresh to view it.'**
  String get accountDeletionPendingError;

  /// Account deletion version or cancellation conflict
  ///
  /// In en, this message translates to:
  /// **'This request changed elsewhere. Refresh its latest status before trying again.'**
  String get accountDeletionConflictError;

  /// Account deletion requests paused failure
  ///
  /// In en, this message translates to:
  /// **'Account deletion requests are temporarily paused. Your account remains active.'**
  String get accountDeletionPausedError;

  /// Generic safe account deletion failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or update account deletion status. It is safe to try again.'**
  String get accountDeletionGenericError;

  /// Personal data export settings row title
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get settingsDataExportTitle;

  /// Personal data export settings row summary
  ///
  /// In en, this message translates to:
  /// **'Create private JSON and readable text copies of your personal KinFlow data.'**
  String get settingsDataExportSummary;

  /// Personal data export screen title
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get dataExportTitle;

  /// Accessible personal export loading message
  ///
  /// In en, this message translates to:
  /// **'Checking personal data export status'**
  String get dataExportLoadingLabel;

  /// Personal export explanation heading
  ///
  /// In en, this message translates to:
  /// **'Your personal KinFlow data'**
  String get dataExportIntroHeading;

  /// Explains the personal export contents
  ///
  /// In en, this message translates to:
  /// **'The export includes your profile, active memberships, items you authored, your participation and completion records, notification settings, and a provider-ID-free billing summary.'**
  String get dataExportIntroBody;

  /// Explains the personal versus household export boundary
  ///
  /// In en, this message translates to:
  /// **'It does not include other household members\' profiles or a full shared-household archive. Household Owners will get that separate workflow later.'**
  String get dataExportScopeBody;

  /// Configured export and one-time link retention
  ///
  /// In en, this message translates to:
  /// **'Finished files expire after about {hours} hours. Every download link works once and expires after {minutes} minutes.'**
  String dataExportRetentionBody(int hours, int minutes);

  /// Personal export request status heading
  ///
  /// In en, this message translates to:
  /// **'Latest export'**
  String get dataExportStatusHeading;

  /// Queued personal export status
  ///
  /// In en, this message translates to:
  /// **'Export queued'**
  String get dataExportStatusQueued;

  /// Verifying personal export status
  ///
  /// In en, this message translates to:
  /// **'Export is being verified'**
  String get dataExportStatusVerifying;

  /// Processing personal export status
  ///
  /// In en, this message translates to:
  /// **'Creating private files'**
  String get dataExportStatusProcessing;

  /// Completed personal export status
  ///
  /// In en, this message translates to:
  /// **'Personal export is ready'**
  String get dataExportStatusCompleted;

  /// Failed personal export status
  ///
  /// In en, this message translates to:
  /// **'This export could not be completed'**
  String get dataExportStatusFailed;

  /// Cancelled personal export status
  ///
  /// In en, this message translates to:
  /// **'Export request cancelled'**
  String get dataExportStatusCancelled;

  /// Starts a recent-authenticated personal export
  ///
  /// In en, this message translates to:
  /// **'Create personal export'**
  String get dataExportRequestAction;

  /// Cancels a queued personal export
  ///
  /// In en, this message translates to:
  /// **'Cancel export request'**
  String get dataExportCancelAction;

  /// Ready artifact download section heading
  ///
  /// In en, this message translates to:
  /// **'Private downloads'**
  String get dataExportDownloadHeading;

  /// One-time download behavior explanation
  ///
  /// In en, this message translates to:
  /// **'Confirm your account again to create a new one-time link. The file opens in your browser or download app.'**
  String get dataExportDownloadBody;

  /// Downloads the machine-readable export
  ///
  /// In en, this message translates to:
  /// **'Download JSON'**
  String get dataExportJsonAction;

  /// Downloads the human-readable export
  ///
  /// In en, this message translates to:
  /// **'Download readable text'**
  String get dataExportTextAction;

  /// Personal export artifact expiry
  ///
  /// In en, this message translates to:
  /// **'Files expire {date}'**
  String dataExportExpiresAt(String date);

  /// Personal export artifact sizes
  ///
  /// In en, this message translates to:
  /// **'JSON {jsonSize} · Text {textSize}'**
  String dataExportFileSizes(String jsonSize, String textSize);

  /// Export size in bytes
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String dataExportBytes(String count);

  /// Export size in kibibytes
  ///
  /// In en, this message translates to:
  /// **'{count} KB'**
  String dataExportKilobytes(String count);

  /// Export size in mebibytes
  ///
  /// In en, this message translates to:
  /// **'{count} MB'**
  String dataExportMegabytes(String count);

  /// Download launcher success message
  ///
  /// In en, this message translates to:
  /// **'The {format} one-time download was opened. Request another link if you need the file again.'**
  String dataExportOpenedMessage(String format);

  /// Machine-readable export format label
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get dataExportJsonFormat;

  /// Human-readable export format label
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get dataExportTextFormat;

  /// Immediately revokes and queues deletion of export files
  ///
  /// In en, this message translates to:
  /// **'Delete export files now'**
  String get dataExportRevokeAction;

  /// Revoked export status guidance
  ///
  /// In en, this message translates to:
  /// **'These export files were revoked and are queued for permanent removal.'**
  String get dataExportRevokedBody;

  /// Purged export status guidance
  ///
  /// In en, this message translates to:
  /// **'These export files were permanently removed.'**
  String get dataExportPurgedBody;

  /// Expired export status guidance
  ///
  /// In en, this message translates to:
  /// **'These export files expired. Create a new export if you still need a copy.'**
  String get dataExportExpiredBody;

  /// Personal export request kill-switch heading
  ///
  /// In en, this message translates to:
  /// **'New exports are temporarily paused'**
  String get dataExportRequestsPausedTitle;

  /// Safe personal export request pause explanation
  ///
  /// In en, this message translates to:
  /// **'Your data is unchanged. Refresh later to check whether a new export is available.'**
  String get dataExportRequestsPausedBody;

  /// Cross-privacy-request conflict guidance
  ///
  /// In en, this message translates to:
  /// **'Another privacy request is in progress. Finish or cancel it before creating an export.'**
  String get dataExportConflictingRequestBody;

  /// Download kill-switch guidance
  ///
  /// In en, this message translates to:
  /// **'Downloads are temporarily paused. Your completed file stays private until it expires or you delete it.'**
  String get dataExportDownloadsPausedBody;

  /// Personal export request confirmation title
  ///
  /// In en, this message translates to:
  /// **'Create a personal export?'**
  String get dataExportConfirmTitle;

  /// Personal export request confirmation body
  ///
  /// In en, this message translates to:
  /// **'You will confirm your Google account, then KinFlow will create private JSON and readable text files.'**
  String get dataExportConfirmBody;

  /// Confirms the personal export request
  ///
  /// In en, this message translates to:
  /// **'Create export'**
  String get dataExportConfirmAction;

  /// Dismisses a personal export confirmation
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get dataExportDismissAction;

  /// Personal export cancellation title
  ///
  /// In en, this message translates to:
  /// **'Cancel this export?'**
  String get dataExportCancelConfirmTitle;

  /// Personal export cancellation body
  ///
  /// In en, this message translates to:
  /// **'The queued job will stop and no download files will be created.'**
  String get dataExportCancelConfirmBody;

  /// Confirms personal export cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancel export'**
  String get dataExportCancelConfirmAction;

  /// Immediate artifact revocation title
  ///
  /// In en, this message translates to:
  /// **'Delete these export files now?'**
  String get dataExportRevokeConfirmTitle;

  /// Immediate artifact revocation consequence
  ///
  /// In en, this message translates to:
  /// **'Every outstanding download link will stop working and the private files will be queued for permanent removal.'**
  String get dataExportRevokeConfirmBody;

  /// Confirms immediate artifact revocation
  ///
  /// In en, this message translates to:
  /// **'Delete files'**
  String get dataExportRevokeConfirmAction;

  /// Safe export authorization failure
  ///
  /// In en, this message translates to:
  /// **'This export is no longer available to this account. Refresh your session.'**
  String get dataExportPermissionError;

  /// Recent authentication required for export
  ///
  /// In en, this message translates to:
  /// **'Confirm your Google sign-in again before creating or downloading an export.'**
  String get dataExportRecentAuthError;

  /// Cancelled export recent authentication
  ///
  /// In en, this message translates to:
  /// **'Account confirmation was cancelled. No export action was sent.'**
  String get dataExportRecentAuthCancelled;

  /// Export recent authentication account mismatch
  ///
  /// In en, this message translates to:
  /// **'The confirmed Google account did not match this KinFlow account. No export action was sent.'**
  String get dataExportAccountChangedError;

  /// Pending privacy request export failure
  ///
  /// In en, this message translates to:
  /// **'Another privacy request is already pending. Refresh its latest status before trying again.'**
  String get dataExportPendingError;

  /// Personal export version conflict
  ///
  /// In en, this message translates to:
  /// **'This export changed elsewhere. Refresh the latest status before trying again.'**
  String get dataExportConflictError;

  /// Personal export requests paused failure
  ///
  /// In en, this message translates to:
  /// **'New personal exports are temporarily paused. Your data is unchanged.'**
  String get dataExportPausedError;

  /// Personal export downloads paused failure
  ///
  /// In en, this message translates to:
  /// **'Personal export downloads are temporarily paused. Try again later.'**
  String get dataExportDownloadsPausedError;

  /// Unavailable personal export artifact failure
  ///
  /// In en, this message translates to:
  /// **'This private export expired, was revoked, or is no longer available. Create a new export if needed.'**
  String get dataExportUnavailableError;

  /// Bounded personal export size failure
  ///
  /// In en, this message translates to:
  /// **'This account has more export data than one file can safely contain. Contact support for help.'**
  String get dataExportTooLargeError;

  /// One-time URL launcher failure
  ///
  /// In en, this message translates to:
  /// **'The download app could not open. Request a new one-time link and try again.'**
  String get dataExportLaunchError;

  /// Generic safe personal export failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or update your personal export. It is safe to try again.'**
  String get dataExportGenericError;

  /// Owner household privacy settings row title
  ///
  /// In en, this message translates to:
  /// **'Household data and deletion'**
  String get settingsHouseholdPrivacyTitle;

  /// Owner household privacy settings row summary
  ///
  /// In en, this message translates to:
  /// **'Owners can export shared data or schedule household deletion'**
  String get settingsHouseholdPrivacySummary;

  /// Household privacy lifecycle screen title
  ///
  /// In en, this message translates to:
  /// **'Household data and deletion'**
  String get householdPrivacyTitle;

  /// Household privacy loading label
  ///
  /// In en, this message translates to:
  /// **'Checking Owner access and household privacy status…'**
  String get householdPrivacyLoadingLabel;

  /// Household privacy introduction heading
  ///
  /// In en, this message translates to:
  /// **'Owner-only controls'**
  String get householdPrivacyIntroHeading;

  /// Household privacy scope and authorization explanation
  ///
  /// In en, this message translates to:
  /// **'These controls affect shared household data and every current member. KinFlow checks current Owner access on the server for every action.'**
  String get householdPrivacyIntroBody;

  /// Current household member count
  ///
  /// In en, this message translates to:
  /// **'Current members: {count}'**
  String householdPrivacyMemberCount(int count);

  /// Household export retention and grant lifetime
  ///
  /// In en, this message translates to:
  /// **'Export files expire after about {hours} hours. Each one-time link lasts {minutes} minutes.'**
  String householdPrivacyExportRetention(int hours, int minutes);

  /// Household deletion cooling-off window
  ///
  /// In en, this message translates to:
  /// **'A deletion request can be cancelled for about {hours} hours before background removal begins.'**
  String householdPrivacyDeletionWindow(int hours);

  /// Household export section heading
  ///
  /// In en, this message translates to:
  /// **'Export shared household data'**
  String get householdPrivacyExportHeading;

  /// Household export exact safe scope summary
  ///
  /// In en, this message translates to:
  /// **'Create private JSON and readable text files containing household metadata, members, chores, calendar data, and a provider-free billing summary.'**
  String get householdPrivacyExportBody;

  /// Requests a household export
  ///
  /// In en, this message translates to:
  /// **'Create household export'**
  String get householdPrivacyExportAction;

  /// Household deletion section heading
  ///
  /// In en, this message translates to:
  /// **'Delete this household'**
  String get householdPrivacyDeleteHeading;

  /// Household deletion impact boundary
  ///
  /// In en, this message translates to:
  /// **'Deletion permanently removes member access, redacts shared content, revokes invites, and unlinks billing access. Member accounts and Store subscriptions are not deleted or cancelled.'**
  String get householdPrivacyDeleteBody;

  /// Opens household deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Schedule household deletion'**
  String get householdPrivacyDeleteAction;

  /// Active Store subscription deletion warning
  ///
  /// In en, this message translates to:
  /// **'This household has an active subscription assignment. Deleting the household does not cancel the Store subscription.'**
  String get householdPrivacySubscriptionWarning;

  /// Household privacy status card heading
  ///
  /// In en, this message translates to:
  /// **'Latest household privacy request'**
  String get householdPrivacyStatusHeading;

  /// Household export request kind
  ///
  /// In en, this message translates to:
  /// **'Household export'**
  String get householdPrivacyExportKind;

  /// Household deletion request kind
  ///
  /// In en, this message translates to:
  /// **'Household deletion'**
  String get householdPrivacyDeletionKind;

  /// Queued household privacy status
  ///
  /// In en, this message translates to:
  /// **'Queued during the cancellation window'**
  String get householdPrivacyStatusQueued;

  /// Verifying household privacy status
  ///
  /// In en, this message translates to:
  /// **'Verifying current Owner and request conditions'**
  String get householdPrivacyStatusVerifying;

  /// Processing household privacy status
  ///
  /// In en, this message translates to:
  /// **'Background processing is in progress'**
  String get householdPrivacyStatusProcessing;

  /// Completed household privacy status
  ///
  /// In en, this message translates to:
  /// **'Request completed'**
  String get householdPrivacyStatusCompleted;

  /// Failed household privacy status
  ///
  /// In en, this message translates to:
  /// **'The request could not be completed'**
  String get householdPrivacyStatusFailed;

  /// Cancelled household privacy status
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get householdPrivacyStatusCancelled;

  /// Cancels a mutable household privacy request
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get householdPrivacyCancelAction;

  /// Household export download section heading
  ///
  /// In en, this message translates to:
  /// **'Private household downloads'**
  String get householdPrivacyDownloadHeading;

  /// One-time household download guidance
  ///
  /// In en, this message translates to:
  /// **'Each link works once. KinFlow does not keep the link in app state or storage.'**
  String get householdPrivacyDownloadBody;

  /// Revokes household export files
  ///
  /// In en, this message translates to:
  /// **'Delete household export files now'**
  String get householdPrivacyRevokeAction;

  /// Safe retention hold status without operator details
  ///
  /// In en, this message translates to:
  /// **'Deletion is paused by a retention hold. Access is not removed while the hold is active.'**
  String get householdPrivacyRetentionBlocked;

  /// Retention hold review timestamp
  ///
  /// In en, this message translates to:
  /// **'Retention review: {date}'**
  String householdPrivacyRetentionReview(String date);

  /// Household download launcher success
  ///
  /// In en, this message translates to:
  /// **'The {format} one-time household download opened.'**
  String householdPrivacyOpenedMessage(String format);

  /// Household export confirmation title
  ///
  /// In en, this message translates to:
  /// **'Create a household export?'**
  String get householdPrivacyExportConfirmTitle;

  /// Household export confirmation body
  ///
  /// In en, this message translates to:
  /// **'Confirm your Google account, then KinFlow will create private JSON and readable text files for this household.'**
  String get householdPrivacyExportConfirmBody;

  /// Household privacy cancellation title
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get householdPrivacyCancelConfirmTitle;

  /// Household privacy cancellation consequence
  ///
  /// In en, this message translates to:
  /// **'The queued request will stop. A request already being processed cannot be cancelled.'**
  String get householdPrivacyCancelConfirmBody;

  /// Household export revocation title
  ///
  /// In en, this message translates to:
  /// **'Delete these household export files now?'**
  String get householdPrivacyRevokeConfirmTitle;

  /// Household export revocation consequence
  ///
  /// In en, this message translates to:
  /// **'Outstanding links will stop working and both private files will be queued for permanent removal.'**
  String get householdPrivacyRevokeConfirmBody;

  /// Household deletion confirmation title
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this household?'**
  String get householdPrivacyDeleteConfirmTitle;

  /// Household deletion confirmation instructions
  ///
  /// In en, this message translates to:
  /// **'Type the exact household name and confirm every impact. You will then confirm your Google account.'**
  String get householdPrivacyDeleteConfirmBody;

  /// Exact household name confirmation input label
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get householdPrivacyNameLabel;

  /// Exact household name confirmation hint
  ///
  /// In en, this message translates to:
  /// **'Type {name}'**
  String householdPrivacyNameHint(String name);

  /// Member access loss acknowledgment
  ///
  /// In en, this message translates to:
  /// **'I understand every current member will lose access to this household.'**
  String get householdPrivacyMemberAccessAck;

  /// Shared data redaction acknowledgment
  ///
  /// In en, this message translates to:
  /// **'I understand shared chores, calendar content, names, and endpoint material will be irreversibly redacted or removed.'**
  String get householdPrivacyRedactionAck;

  /// Store subscription non-cancellation acknowledgment
  ///
  /// In en, this message translates to:
  /// **'I understand this does not cancel the Store subscription, which must be managed separately.'**
  String get householdPrivacySubscriptionAck;

  /// Submits a confirmed household deletion request
  ///
  /// In en, this message translates to:
  /// **'Confirm and schedule deletion'**
  String get householdPrivacyDeleteConfirmAction;

  /// Owner authorization failure
  ///
  /// In en, this message translates to:
  /// **'Only the current household Owner can use these controls. Refresh if ownership changed.'**
  String get householdPrivacyPermissionError;

  /// Household recent authentication required
  ///
  /// In en, this message translates to:
  /// **'Confirm the same Google account again before this sensitive household action.'**
  String get householdPrivacyRecentAuthError;

  /// Cancelled household recent authentication
  ///
  /// In en, this message translates to:
  /// **'Account confirmation was cancelled. No household action was sent.'**
  String get householdPrivacyRecentAuthCancelled;

  /// Household recent authentication account mismatch
  ///
  /// In en, this message translates to:
  /// **'The confirmed Google account did not match this KinFlow account. No household action was sent.'**
  String get householdPrivacyAccountChangedError;

  /// Household privacy runtime pause failure
  ///
  /// In en, this message translates to:
  /// **'This household privacy action is temporarily paused. Shared data is unchanged.'**
  String get householdPrivacyPausedError;

  /// Pending household privacy request failure
  ///
  /// In en, this message translates to:
  /// **'Another household privacy request is already in progress. Refresh its status first.'**
  String get householdPrivacyPendingError;

  /// Household privacy version or mutability conflict
  ///
  /// In en, this message translates to:
  /// **'This household or request changed elsewhere. Refresh before trying again.'**
  String get householdPrivacyConflictError;

  /// Household exact-name confirmation mismatch
  ///
  /// In en, this message translates to:
  /// **'The typed household name no longer matches. Refresh and enter the current exact name.'**
  String get householdPrivacyConfirmationError;

  /// Missing subscription acknowledgment
  ///
  /// In en, this message translates to:
  /// **'Acknowledge that household deletion does not cancel the active Store subscription.'**
  String get householdPrivacySubscriptionAckError;

  /// Unavailable household export artifact
  ///
  /// In en, this message translates to:
  /// **'This household export expired, was revoked, or is unavailable. Create a new export if needed.'**
  String get householdPrivacyArtifactError;

  /// Already deleted household failure
  ///
  /// In en, this message translates to:
  /// **'This household has already been deleted. Refresh to select or create another household.'**
  String get householdPrivacyDeletedError;

  /// Household one-time URL launcher failure
  ///
  /// In en, this message translates to:
  /// **'The download app could not open. Request a fresh one-time link and try again.'**
  String get householdPrivacyLaunchError;

  /// Generic safe household privacy failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or update household privacy controls. It is safe to try again.'**
  String get householdPrivacyGenericError;

  /// Settings list title for profile and regional preferences
  ///
  /// In en, this message translates to:
  /// **'Profile and regional settings'**
  String get settingsProfilePreferencesTitle;

  /// Settings list summary for profile and regional preferences
  ///
  /// In en, this message translates to:
  /// **'Update your name, avatar, language, and timezones'**
  String get settingsProfilePreferencesSummary;

  /// Profile preference screen title
  ///
  /// In en, this message translates to:
  /// **'Profile and regional settings'**
  String get profilePreferencesTitle;

  /// Profile preferences loading state
  ///
  /// In en, this message translates to:
  /// **'Loading your profile and household timezone…'**
  String get profilePreferencesLoadingLabel;

  /// Profile settings introduction heading
  ///
  /// In en, this message translates to:
  /// **'Your minimal KinFlow profile'**
  String get profilePreferencesIntroHeading;

  /// Profile data minimization explanation
  ///
  /// In en, this message translates to:
  /// **'Use a display name and optional built-in avatar. KinFlow does not require a legal name, birthday, or extra personal details.'**
  String get profilePreferencesIntroBody;

  /// Profile form section heading
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profilePreferencesProfileHeading;

  /// Adult display name field label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profilePreferencesDisplayNameLabel;

  /// Display name validation message
  ///
  /// In en, this message translates to:
  /// **'Enter 1–80 visible characters.'**
  String get profilePreferencesDisplayNameValidation;

  /// Avatar preset selector heading
  ///
  /// In en, this message translates to:
  /// **'Built-in avatar'**
  String get profilePreferencesAvatarHeading;

  /// No avatar preset option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profilePreferencesAvatarNone;

  /// Sun avatar preset option
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get profilePreferencesAvatarSun;

  /// Heart avatar preset option
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get profilePreferencesAvatarHeart;

  /// Leaf avatar preset option
  ///
  /// In en, this message translates to:
  /// **'Leaf'**
  String get profilePreferencesAvatarLeaf;

  /// Star avatar preset option
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get profilePreferencesAvatarStar;

  /// Regional preference section heading
  ///
  /// In en, this message translates to:
  /// **'Language and personal timezone'**
  String get profilePreferencesRegionalHeading;

  /// Regional settings date and time preview heading
  ///
  /// In en, this message translates to:
  /// **'Current date and time preview'**
  String get timezonePreviewHeading;

  /// Explains the regional settings draft preview
  ///
  /// In en, this message translates to:
  /// **'This preview uses your unsaved language and timezone choices. Refresh it to use a new current instant and offset snapshot.'**
  String get timezonePreviewBody;

  /// Personal timezone preview row label
  ///
  /// In en, this message translates to:
  /// **'Personal preview'**
  String get timezonePreviewPersonalLabel;

  /// Household timezone preview row label
  ///
  /// In en, this message translates to:
  /// **'Household preview'**
  String get timezonePreviewHouseholdLabel;

  /// Refreshes the regional date and time preview snapshot
  ///
  /// In en, this message translates to:
  /// **'Refresh date and time preview'**
  String get timezonePreviewRefreshAction;

  /// Regional preview loading label
  ///
  /// In en, this message translates to:
  /// **'Preparing the current date and time preview…'**
  String get timezonePreviewLoadingLabel;

  /// Regional preview load failure
  ///
  /// In en, this message translates to:
  /// **'The preview could not be refreshed. Your language and timezone choices have not changed.'**
  String get timezonePreviewLoadFailure;

  /// Exact timezone is missing from the bundled preview catalog
  ///
  /// In en, this message translates to:
  /// **'{timezone} is not in the bundled timezone list, so no device-time fallback is shown.'**
  String timezonePreviewMissingTimezone(String timezone);

  /// Screen reader summary for an available timezone preview
  ///
  /// In en, this message translates to:
  /// **'{label}. {timezone}. {date}. {time}. {metadata}.'**
  String timezonePreviewSemantics(
    String label,
    String timezone,
    String date,
    String time,
    String metadata,
  );

  /// Screen reader summary for a missing timezone preview
  ///
  /// In en, this message translates to:
  /// **'{label}. Preview unavailable for {timezone}.'**
  String timezonePreviewUnavailableSemantics(String label, String timezone);

  /// App language selector label
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profilePreferencesLanguageLabel;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profilePreferencesLanguageEnglish;

  /// Korean language option
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get profilePreferencesLanguageKorean;

  /// Personal IANA timezone field label
  ///
  /// In en, this message translates to:
  /// **'Personal timezone'**
  String get profilePreferencesPersonalTimezoneLabel;

  /// Personal timezone field guidance
  ///
  /// In en, this message translates to:
  /// **'Choose an IANA region or city. This becomes your personal default.'**
  String get profilePreferencesPersonalTimezoneHelper;

  /// Personal timezone picker title
  ///
  /// In en, this message translates to:
  /// **'Choose your personal timezone'**
  String get profilePreferencesPersonalTimezonePickerTitle;

  /// IANA timezone input validation
  ///
  /// In en, this message translates to:
  /// **'Choose a valid IANA timezone such as Asia/Seoul or UTC.'**
  String get profilePreferencesTimezoneValidation;

  /// Household timezone section heading
  ///
  /// In en, this message translates to:
  /// **'Household default timezone'**
  String get profilePreferencesHouseholdHeading;

  /// Household IANA timezone field label
  ///
  /// In en, this message translates to:
  /// **'Household timezone'**
  String get profilePreferencesHouseholdTimezoneLabel;

  /// Household timezone authority guidance
  ///
  /// In en, this message translates to:
  /// **'Owner and Admin can choose the default used by household dates and newly created items.'**
  String get profilePreferencesHouseholdTimezoneHelper;

  /// Household timezone picker title
  ///
  /// In en, this message translates to:
  /// **'Choose the household timezone'**
  String get profilePreferencesHouseholdTimezonePickerTitle;

  /// Read-only household timezone summary
  ///
  /// In en, this message translates to:
  /// **'{timezone} · Only Owner or Admin can change this default.'**
  String profilePreferencesHouseholdTimezoneReadOnly(String timezone);

  /// Household timezone impact heading
  ///
  /// In en, this message translates to:
  /// **'What a household timezone change means'**
  String get profilePreferencesImpactHeading;

  /// Household timezone changed behavior
  ///
  /// In en, this message translates to:
  /// **'It changes the household-local Today boundary, defaults for new items, and notification preferences that still inherit the household default.'**
  String get profilePreferencesImpactBody;

  /// Existing recurrence preservation warning
  ///
  /// In en, this message translates to:
  /// **'Existing repeating chores and calendar series keep their saved timezone and occurrence instants.'**
  String get profilePreferencesImpactPreservedBody;

  /// Profile preferences save action
  ///
  /// In en, this message translates to:
  /// **'Save profile and regional settings'**
  String get profilePreferencesSaveAction;

  /// Profile settings save success message
  ///
  /// In en, this message translates to:
  /// **'Profile and regional settings saved.'**
  String get profilePreferencesSavedMessage;

  /// Household timezone confirmation title
  ///
  /// In en, this message translates to:
  /// **'Change the household timezone?'**
  String get profilePreferencesConfirmTimezoneTitle;

  /// Household timezone confirmation consequence
  ///
  /// In en, this message translates to:
  /// **'Today boundaries and new defaults will change immediately. Existing repeating items keep their saved timezone and instants.'**
  String get profilePreferencesConfirmTimezoneBody;

  /// Confirmed household timezone save action
  ///
  /// In en, this message translates to:
  /// **'Change timezone and save'**
  String get profilePreferencesConfirmTimezoneAction;

  /// Dismisses the household timezone confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profilePreferencesCancelAction;

  /// Timezone picker close action
  ///
  /// In en, this message translates to:
  /// **'Close timezone picker'**
  String get timezonePickerCloseAction;

  /// Current timezone selection label
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get timezonePickerCurrentLabel;

  /// Timezone search field label
  ///
  /// In en, this message translates to:
  /// **'Search by region or city'**
  String get timezonePickerSearchLabel;

  /// Timezone search guidance
  ///
  /// In en, this message translates to:
  /// **'Try Seoul, New York, or Europe.'**
  String get timezonePickerSearchHelper;

  /// Timezone search clear action
  ///
  /// In en, this message translates to:
  /// **'Clear timezone search'**
  String get timezonePickerClearSearchAction;

  /// Timezone catalog loading label
  ///
  /// In en, this message translates to:
  /// **'Loading the bundled timezone list…'**
  String get timezonePickerLoadingLabel;

  /// Timezone catalog load failure
  ///
  /// In en, this message translates to:
  /// **'The timezone list could not be loaded. Your current selection has not changed.'**
  String get timezonePickerLoadFailure;

  /// Empty timezone search result
  ///
  /// In en, this message translates to:
  /// **'No timezone matches this search.'**
  String get timezonePickerEmptyLabel;

  /// Current timezone daylight-saving metadata
  ///
  /// In en, this message translates to:
  /// **'daylight saving now'**
  String get timezonePickerDaylightSavingLabel;

  /// Current timezone standard-time metadata
  ///
  /// In en, this message translates to:
  /// **'standard time now'**
  String get timezonePickerStandardTimeLabel;

  /// Current offset and daylight-saving metadata for a timezone
  ///
  /// In en, this message translates to:
  /// **'UTC{offset} · {clockKind}'**
  String timezonePickerMetadata(String offset, String clockKind);

  /// Profile preferences authentication failure
  ///
  /// In en, this message translates to:
  /// **'Sign in again before loading or changing this profile.'**
  String get profilePreferencesErrorUnauthenticated;

  /// Profile preferences input failure
  ///
  /// In en, this message translates to:
  /// **'Check the display name, avatar, language, and IANA timezone values.'**
  String get profilePreferencesErrorInvalidInput;

  /// Profile or active household unavailable failure
  ///
  /// In en, this message translates to:
  /// **'This profile or active household is no longer available. Refresh your session.'**
  String get profilePreferencesErrorUnavailable;

  /// Household timezone authorization failure
  ///
  /// In en, this message translates to:
  /// **'Only the current Owner or Admin can change the household timezone. Your personal changes were not saved.'**
  String get profilePreferencesErrorForbidden;

  /// Profile optimistic version conflict
  ///
  /// In en, this message translates to:
  /// **'Your profile changed elsewhere. Reload the latest version before saving again.'**
  String get profilePreferencesErrorProfileConflict;

  /// Household optimistic version conflict
  ///
  /// In en, this message translates to:
  /// **'The household timezone changed elsewhere. Reload the latest version before saving again.'**
  String get profilePreferencesErrorHouseholdConflict;

  /// Profile settings temporary failure
  ///
  /// In en, this message translates to:
  /// **'Profile settings are temporarily unavailable. Your previous values remain unchanged.'**
  String get profilePreferencesErrorTemporarilyUnavailable;

  /// Profile settings fail-closed payload failure
  ///
  /// In en, this message translates to:
  /// **'KinFlow received an unexpected settings response and did not apply it.'**
  String get profilePreferencesErrorInvalidPayload;

  /// Generic profile settings failure
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load or save these settings. It is safe to try again.'**
  String get profilePreferencesErrorInternal;

  /// Settings list title for subscription status and Plus purchase controls
  ///
  /// In en, this message translates to:
  /// **'Subscription and Plus'**
  String get settingsSubscriptionTitle;

  /// Settings list summary for subscription controls
  ///
  /// In en, this message translates to:
  /// **'Check this household\'s plan, purchase or restore Plus, and manage billing'**
  String get settingsSubscriptionSummary;

  /// Subscription settings screen title
  ///
  /// In en, this message translates to:
  /// **'Subscription and Plus'**
  String get subscriptionTitle;

  /// Subscription loading state
  ///
  /// In en, this message translates to:
  /// **'Loading the server-confirmed subscription status…'**
  String get subscriptionLoading;

  /// Safe household name fallback while profile context is unavailable
  ///
  /// In en, this message translates to:
  /// **'Active household'**
  String get subscriptionHouseholdFallback;

  /// Subscription status card heading
  ///
  /// In en, this message translates to:
  /// **'Current household subscription'**
  String get subscriptionStatusHeading;

  /// Subscription household row label
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get subscriptionHouseholdLabel;

  /// Subscription plan row label
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get subscriptionPlanLabel;

  /// Subscription lifecycle row label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get subscriptionLifecycleLabel;

  /// Subscription source row label
  ///
  /// In en, this message translates to:
  /// **'Billing source'**
  String get subscriptionSourceLabel;

  /// Subscription billing owner row label
  ///
  /// In en, this message translates to:
  /// **'Billing owner'**
  String get subscriptionBillingOwnerLabel;

  /// No billing owner exists for a Free household
  ///
  /// In en, this message translates to:
  /// **'No billing owner'**
  String get subscriptionBillingOwnerNone;

  /// Subscription period row label
  ///
  /// In en, this message translates to:
  /// **'Billing period'**
  String get subscriptionPeriodLabel;

  /// Subscription verification timestamp row label
  ///
  /// In en, this message translates to:
  /// **'Server verified'**
  String get subscriptionVerifiedLabel;

  /// Free plan name
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionPlanFree;

  /// Plus plan name
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get subscriptionPlanPlus;

  /// No entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'No active Plus subscription'**
  String get subscriptionStatusNone;

  /// Trial entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Trial active'**
  String get subscriptionStatusTrialing;

  /// Active entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionStatusActive;

  /// Grace entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Payment retry grace period'**
  String get subscriptionStatusGrace;

  /// Billing issue entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Billing needs attention'**
  String get subscriptionStatusBillingIssue;

  /// Expired entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get subscriptionStatusExpired;

  /// Revoked entitlement lifecycle status
  ///
  /// In en, this message translates to:
  /// **'Revoked or refunded'**
  String get subscriptionStatusRevoked;

  /// No subscription source
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get subscriptionSourceNone;

  /// Google Play subscription source
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get subscriptionSourcePlayStore;

  /// Apple App Store subscription source
  ///
  /// In en, this message translates to:
  /// **'Apple App Store'**
  String get subscriptionSourceAppStore;

  /// Web billing subscription source
  ///
  /// In en, this message translates to:
  /// **'Web billing'**
  String get subscriptionSourceWeb;

  /// Manual support subscription source
  ///
  /// In en, this message translates to:
  /// **'KinFlow support'**
  String get subscriptionSourceSupport;

  /// Current account is the billing owner
  ///
  /// In en, this message translates to:
  /// **'You manage this subscription'**
  String get subscriptionBillingOwnerYou;

  /// Another account is the billing owner
  ///
  /// In en, this message translates to:
  /// **'Another household member manages it'**
  String get subscriptionBillingOwnerOther;

  /// Renewing subscription period end
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String subscriptionRenewsOn(String date);

  /// Non-renewing subscription period end
  ///
  /// In en, this message translates to:
  /// **'Current access through {date}'**
  String subscriptionAccessThrough(String date);

  /// Missing subscription period end
  ///
  /// In en, this message translates to:
  /// **'No period end reported'**
  String get subscriptionNoPeriodEnd;

  /// Server verification date
  ///
  /// In en, this message translates to:
  /// **'Checked {date}'**
  String subscriptionVerifiedAt(String date);

  /// Trial lifecycle guidance
  ///
  /// In en, this message translates to:
  /// **'Your Plus trial is active. The Store may renew it unless you cancel there.'**
  String get subscriptionLifecycleTrialing;

  /// Grace lifecycle guidance
  ///
  /// In en, this message translates to:
  /// **'Plus remains available while the Store retries payment. Review the payment method in the Store.'**
  String get subscriptionLifecycleGrace;

  /// Billing issue lifecycle guidance
  ///
  /// In en, this message translates to:
  /// **'The Store reported a billing problem. Existing data remains safe; review billing in the Store.'**
  String get subscriptionLifecycleBillingIssue;

  /// Expired lifecycle and data preservation guidance
  ///
  /// In en, this message translates to:
  /// **'Plus access ended. Existing household data is preserved, but new Free-plan limits apply.'**
  String get subscriptionLifecycleExpired;

  /// Revoked lifecycle and data preservation guidance
  ///
  /// In en, this message translates to:
  /// **'Plus access was revoked or refunded. Existing household data is preserved, but new Free-plan limits apply.'**
  String get subscriptionLifecycleRevoked;

  /// Plus benefit summary heading
  ///
  /// In en, this message translates to:
  /// **'Plus benefits'**
  String get subscriptionBenefitsHeading;

  /// Non-numeric member benefit category
  ///
  /// In en, this message translates to:
  /// **'More room for household members'**
  String get subscriptionBenefitMembers;

  /// Non-numeric recurrence benefit category
  ///
  /// In en, this message translates to:
  /// **'More active recurring chore and calendar series'**
  String get subscriptionBenefitRecurring;

  /// Data preservation benefit
  ///
  /// In en, this message translates to:
  /// **'Existing household data stays preserved if Plus ends'**
  String get subscriptionBenefitData;

  /// Unfinalized numeric pricing and limits disclosure
  ///
  /// In en, this message translates to:
  /// **'Final prices and limits come from the Store and server. No unconfirmed numeric limit is shown here.'**
  String get subscriptionLimitsPending;

  /// Current Store offering heading
  ///
  /// In en, this message translates to:
  /// **'Choose a Store option'**
  String get subscriptionOffersHeading;

  /// Exact localized Store price and period
  ///
  /// In en, this message translates to:
  /// **'{price} · {period}'**
  String subscriptionPackagePrice(String price, String period);

  /// Store billing period in days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{every day} other{every {count} days}}'**
  String subscriptionPeriodDays(int count);

  /// Store billing period in weeks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{every week} other{every {count} weeks}}'**
  String subscriptionPeriodWeeks(int count);

  /// Store billing period in months
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{every month} other{every {count} months}}'**
  String subscriptionPeriodMonths(int count);

  /// Store billing period in years
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{every year} other{every {count} years}}'**
  String subscriptionPeriodYears(int count);

  /// Starts a Store purchase after confirmation
  ///
  /// In en, this message translates to:
  /// **'Continue to Store purchase'**
  String get subscriptionPurchaseAction;

  /// Starts Store purchase restoration
  ///
  /// In en, this message translates to:
  /// **'Restore Store purchases'**
  String get subscriptionRestoreAction;

  /// Opens the authoritative Store subscription management page
  ///
  /// In en, this message translates to:
  /// **'Manage subscription in Store'**
  String get subscriptionManageAction;

  /// Reloads server-authoritative entitlement status
  ///
  /// In en, this message translates to:
  /// **'Refresh server status'**
  String get subscriptionRefreshAction;

  /// Returns from a terminal billing state to ready options
  ///
  /// In en, this message translates to:
  /// **'Back to subscription options'**
  String get subscriptionReturnAction;

  /// Opens configured billing support
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get subscriptionSupportAction;

  /// Opens public terms
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get subscriptionTermsAction;

  /// Opens public privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get subscriptionPrivacyAction;

  /// Purchase and restore role restriction
  ///
  /// In en, this message translates to:
  /// **'Only an active household Owner or Admin can purchase or restore Plus. You can still view the current status.'**
  String get subscriptionAdminRequired;

  /// Fail-closed active household profile mismatch
  ///
  /// In en, this message translates to:
  /// **'KinFlow could not verify your active household role. Refresh profile settings before purchasing or restoring.'**
  String get subscriptionProfileUnavailable;

  /// Unavailable Store catalog with preserved entitlement status
  ///
  /// In en, this message translates to:
  /// **'Store options are unavailable right now. The server-confirmed household status is still shown above.'**
  String get subscriptionStoreUnavailable;

  /// Purchase confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm this household purchase'**
  String get subscriptionPurchaseConfirmTitle;

  /// Household-scoped purchase confirmation using exact Store terms
  ///
  /// In en, this message translates to:
  /// **'Buy Plus for {household} at the Store price {price}, billed {period}?'**
  String subscriptionPurchaseConfirmBody(
    String household,
    String price,
    String period,
  );

  /// Purchase renewal disclosure
  ///
  /// In en, this message translates to:
  /// **'The Store may renew and charge this subscription until the billing owner cancels it there.'**
  String get subscriptionPurchaseConfirmRenewal;

  /// Server authority purchase disclosure
  ///
  /// In en, this message translates to:
  /// **'Store success is not final access. KinFlow waits for server confirmation before enabling Plus.'**
  String get subscriptionPurchaseConfirmServer;

  /// Confirmed purchase submission
  ///
  /// In en, this message translates to:
  /// **'Confirm and open Store'**
  String get subscriptionPurchaseConfirmAction;

  /// Restore confirmation title
  ///
  /// In en, this message translates to:
  /// **'Restore purchases for this household?'**
  String get subscriptionRestoreConfirmTitle;

  /// Household-scoped restore confirmation
  ///
  /// In en, this message translates to:
  /// **'KinFlow will check Store purchases for {household}. It will never transfer a subscription from another household automatically.'**
  String subscriptionRestoreConfirmBody(String household);

  /// Restore assignment conflict disclosure
  ///
  /// In en, this message translates to:
  /// **'If a purchase is assigned elsewhere, KinFlow stops and offers a support request without exposing billing identifiers.'**
  String get subscriptionRestoreConfirmConflict;

  /// Confirmed restore submission
  ///
  /// In en, this message translates to:
  /// **'Confirm restore'**
  String get subscriptionRestoreConfirmAction;

  /// Dismisses a billing confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get subscriptionCancelAction;

  /// Purchase assignment preparation state
  ///
  /// In en, this message translates to:
  /// **'Checking that this subscription can be safely assigned before opening the Store…'**
  String get subscriptionPreparingPurchase;

  /// Restore assignment preparation state
  ///
  /// In en, this message translates to:
  /// **'Checking that restored purchases can be safely assigned to this household…'**
  String get subscriptionPreparingRestore;

  /// Store purchase in progress
  ///
  /// In en, this message translates to:
  /// **'Waiting for the Store purchase result…'**
  String get subscriptionPurchasing;

  /// Store restoration in progress
  ///
  /// In en, this message translates to:
  /// **'Checking purchases with the Store…'**
  String get subscriptionRestoring;

  /// Ambiguous Store pending state
  ///
  /// In en, this message translates to:
  /// **'The Store is still processing this request. Purchase and restore controls stay paused to prevent duplicates.'**
  String get subscriptionStorePending;

  /// Server confirmation pending state
  ///
  /// In en, this message translates to:
  /// **'The Store responded, but KinFlow has not received authoritative server confirmation yet. Refresh status; do not purchase again.'**
  String get subscriptionServerPending;

  /// Empty restore result heading
  ///
  /// In en, this message translates to:
  /// **'No restorable purchase found'**
  String get subscriptionRestoreEmptyTitle;

  /// Empty restore result explanation
  ///
  /// In en, this message translates to:
  /// **'The Store did not return a Plus purchase for this account. No household subscription changed.'**
  String get subscriptionRestoreEmptyBody;

  /// Aggregate billing assignment conflict heading
  ///
  /// In en, this message translates to:
  /// **'Subscription assignment needs review'**
  String get subscriptionConflictTitle;

  /// Aggregate pre-Store assignment conflict explanation
  ///
  /// In en, this message translates to:
  /// **'KinFlow stopped before contacting the Store because this purchase or household is already linked elsewhere. No billing identifier is displayed.'**
  String get subscriptionConflictBody;

  /// Aggregate restore conflict explanation
  ///
  /// In en, this message translates to:
  /// **'The Store found a purchase, but KinFlow could not safely assign it to this household. No access or ownership changed.'**
  String get subscriptionRestoreConflictBody;

  /// Creates an aggregate support remediation request
  ///
  /// In en, this message translates to:
  /// **'Request assignment review'**
  String get subscriptionRemediationAction;

  /// Open remediation request confirmation
  ///
  /// In en, this message translates to:
  /// **'An assignment review request is open. Support can investigate without billing identifiers appearing here.'**
  String get subscriptionRemediationSubmitted;

  /// Remediation request failure
  ///
  /// In en, this message translates to:
  /// **'The review request could not be sent. No Store action occurred; contact support if this continues.'**
  String get subscriptionRemediationFailed;

  /// Cancelled purchase notice
  ///
  /// In en, this message translates to:
  /// **'The Store purchase was cancelled. Nothing was charged by KinFlow and the household plan did not change.'**
  String get subscriptionNoticePurchaseCancelled;

  /// Already active Plus notice
  ///
  /// In en, this message translates to:
  /// **'Server-confirmed Plus is already active for this household.'**
  String get subscriptionNoticeAlreadyActive;

  /// Server-confirmed purchase notice
  ///
  /// In en, this message translates to:
  /// **'The server confirmed the purchase and updated this household\'s Plus status.'**
  String get subscriptionNoticePurchaseConfirmed;

  /// Server-confirmed restore notice
  ///
  /// In en, this message translates to:
  /// **'The server confirmed the restored purchase for this household.'**
  String get subscriptionNoticeRestoreConfirmed;

  /// Server refresh success notice
  ///
  /// In en, this message translates to:
  /// **'The latest server-confirmed subscription status is shown.'**
  String get subscriptionNoticeServerRefreshed;

  /// External Store, policy, or support launch failure
  ///
  /// In en, this message translates to:
  /// **'That trusted external page could not be opened. Try again or use the Store app directly.'**
  String get subscriptionExternalUnavailable;

  /// Unsupported billing runtime failure
  ///
  /// In en, this message translates to:
  /// **'Store billing is not available on this device. You can still view the server-confirmed status.'**
  String get subscriptionFailureUnsupported;

  /// Billing authentication failure
  ///
  /// In en, this message translates to:
  /// **'Sign in again before loading or changing subscription status.'**
  String get subscriptionFailureUnauthenticated;

  /// Store identity conflict or clear failure
  ///
  /// In en, this message translates to:
  /// **'KinFlow could not safely bind or clear the Store account. Sign out and back in before trying again.'**
  String get subscriptionFailureIdentity;

  /// Billing input or active context failure
  ///
  /// In en, this message translates to:
  /// **'The active household or Store option changed. Refresh before continuing.'**
  String get subscriptionFailureInvalidInput;

  /// Store catalog failure
  ///
  /// In en, this message translates to:
  /// **'Store options could not be loaded. The server-confirmed status remains available.'**
  String get subscriptionFailureCatalog;

  /// Store availability or provider rejection failure
  ///
  /// In en, this message translates to:
  /// **'The Store could not complete this request. Check the Store app and refresh server status before retrying.'**
  String get subscriptionFailureStore;

  /// Billing network failure
  ///
  /// In en, this message translates to:
  /// **'The network is unavailable. No new subscription status was assumed; refresh when connected.'**
  String get subscriptionFailureNetwork;

  /// Billing server authorization failure
  ///
  /// In en, this message translates to:
  /// **'The server refused this subscription action for the current account or household.'**
  String get subscriptionFailureAuthorization;

  /// Billing server availability failure
  ///
  /// In en, this message translates to:
  /// **'The server could not confirm this request. Do not purchase again; refresh status first.'**
  String get subscriptionFailureServer;

  /// Invalid server billing state failure
  ///
  /// In en, this message translates to:
  /// **'KinFlow received an unexpected subscription state and did not enable Plus.'**
  String get subscriptionFailureInvalidState;

  /// Unknown safe billing failure
  ///
  /// In en, this message translates to:
  /// **'The subscription request could not be completed safely. Refresh status before trying another action.'**
  String get subscriptionFailureUnknown;

  /// Settings section heading for help and legal resources
  ///
  /// In en, this message translates to:
  /// **'Help and legal'**
  String get settingsHelpSection;

  /// Settings item title for legal, privacy, and support resources
  ///
  /// In en, this message translates to:
  /// **'Legal, privacy, and support'**
  String get settingsLegalSupportTitle;

  /// Settings item summary for legal, privacy, and support resources
  ///
  /// In en, this message translates to:
  /// **'Review published documents, manage privacy requests, or contact support.'**
  String get settingsLegalSupportSummary;

  /// Legal, privacy, and support hub title
  ///
  /// In en, this message translates to:
  /// **'Legal, privacy, and support'**
  String get legalSupportTitle;

  /// Introduction to the legal, privacy, and support hub
  ///
  /// In en, this message translates to:
  /// **'Use this hub to review KinFlow\'s published documents, reach support, and find your privacy controls.'**
  String get legalSupportIntro;

  /// Legal document version authority heading
  ///
  /// In en, this message translates to:
  /// **'Published document versions'**
  String get legalSupportDocumentVersionTitle;

  /// Explains where authoritative legal document versions are displayed
  ///
  /// In en, this message translates to:
  /// **'The publication date and version shown on each linked document are authoritative. The app\'s technical contract version is not a legal policy version.'**
  String get legalSupportDocumentVersionBody;

  /// Terms resource heading
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get legalSupportTermsTitle;

  /// Terms resource explanation
  ///
  /// In en, this message translates to:
  /// **'Review the current terms for using KinFlow, including account, household, and service responsibilities.'**
  String get legalSupportTermsBody;

  /// Terms publication version guidance
  ///
  /// In en, this message translates to:
  /// **'Opens the fixed terms page in your browser. Check that page for its publication date and version.'**
  String get legalSupportTermsVersionNote;

  /// Opens the trusted terms page
  ///
  /// In en, this message translates to:
  /// **'Open terms of service'**
  String get legalSupportTermsOpenAction;

  /// Privacy policy resource heading
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalSupportPrivacyTitle;

  /// Privacy policy resource explanation
  ///
  /// In en, this message translates to:
  /// **'Review how KinFlow handles account, household, device, notification, and subscription-related data.'**
  String get legalSupportPrivacyBody;

  /// Privacy policy publication version guidance
  ///
  /// In en, this message translates to:
  /// **'Opens the fixed privacy page in your browser. Check that page for its publication date and version.'**
  String get legalSupportPrivacyVersionNote;

  /// Opens the trusted privacy page
  ///
  /// In en, this message translates to:
  /// **'Open privacy policy'**
  String get legalSupportPrivacyOpenAction;

  /// Privacy request shortcuts heading
  ///
  /// In en, this message translates to:
  /// **'Your privacy controls'**
  String get legalSupportPrivacyControlsTitle;

  /// Privacy request shortcuts explanation
  ///
  /// In en, this message translates to:
  /// **'Create private copies of your data or review the separate account deletion process without leaving KinFlow.'**
  String get legalSupportPrivacyControlsBody;

  /// Support resource heading
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get legalSupportSupportTitle;

  /// Support resource explanation
  ///
  /// In en, this message translates to:
  /// **'Open KinFlow\'s configured support page for product, account, household, or subscription help.'**
  String get legalSupportSupportBody;

  /// Privacy note for the external support link
  ///
  /// In en, this message translates to:
  /// **'KinFlow does not automatically attach your account, household, billing, or diagnostic identifiers to this link.'**
  String get legalSupportSupportPrivacyNote;

  /// Opens the configured trusted support page
  ///
  /// In en, this message translates to:
  /// **'Open support'**
  String get legalSupportSupportOpenAction;

  /// Informational consent boundary heading
  ///
  /// In en, this message translates to:
  /// **'Consent on this screen'**
  String get legalSupportConsentTitle;

  /// Explains that the hub does not mutate consent
  ///
  /// In en, this message translates to:
  /// **'Opening or reading these resources does not grant or withdraw consent. If a specific policy version ever requires a decision, KinFlow will ask separately and record only that explicit choice.'**
  String get legalSupportConsentBody;

  /// Terms resource name used in launch status
  ///
  /// In en, this message translates to:
  /// **'terms of service'**
  String get legalSupportTermsResourceName;

  /// Privacy policy resource name used in launch status
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get legalSupportPrivacyResourceName;

  /// Support resource name used in launch status
  ///
  /// In en, this message translates to:
  /// **'support'**
  String get legalSupportSupportResourceName;

  /// External resource opening status
  ///
  /// In en, this message translates to:
  /// **'Opening {resource} in your browser…'**
  String legalSupportOpening(String resource);

  /// External resource opened status
  ///
  /// In en, this message translates to:
  /// **'Opened {resource} in your browser.'**
  String legalSupportOpened(String resource);

  /// Trusted legal or support page launch failure
  ///
  /// In en, this message translates to:
  /// **'That trusted page could not be opened. Check your connection or browser and try again.'**
  String get legalSupportExternalUnavailable;

  /// Settings item title for analytics governance
  ///
  /// In en, this message translates to:
  /// **'Analytics and data collection'**
  String get settingsAnalyticsPrivacyTitle;

  /// Settings item summary for analytics governance
  ///
  /// In en, this message translates to:
  /// **'Review optional usage analytics, collection limits, and SDK purposes.'**
  String get settingsAnalyticsPrivacySummary;

  /// Analytics privacy screen title
  ///
  /// In en, this message translates to:
  /// **'Analytics and data collection'**
  String get analyticsPrivacyTitle;

  /// Analytics preference loading status
  ///
  /// In en, this message translates to:
  /// **'Loading the privacy-safe analytics preference…'**
  String get analyticsPrivacyLoading;

  /// Analytics preference load failure without raw detail
  ///
  /// In en, this message translates to:
  /// **'The analytics preference could not be loaded safely. Optional usage analytics remains off. Try again.'**
  String get analyticsPrivacyLoadFailed;

  /// Analytics governance introduction heading
  ///
  /// In en, this message translates to:
  /// **'A minimal, optional usage signal'**
  String get analyticsPrivacyIntroTitle;

  /// Explains optional analytics scope and default
  ///
  /// In en, this message translates to:
  /// **'This device setting controls optional, content-free usage events. It is separate from operational error reporting and is off by default.'**
  String get analyticsPrivacyIntroBody;

  /// Optional usage analytics preference title
  ///
  /// In en, this message translates to:
  /// **'Allow optional usage analytics'**
  String get analyticsPrivacyPreferenceTitle;

  /// Versioned device analytics preference explanation
  ///
  /// In en, this message translates to:
  /// **'This choice applies only to analytics-usage-v1 on this device and environment. A provider, purpose, field, or policy expansion requires a new choice.'**
  String get analyticsPrivacyPreferenceBody;

  /// Analytics disabled status
  ///
  /// In en, this message translates to:
  /// **'Off. Optional usage events are not sent.'**
  String get analyticsPrivacyStatusOff;

  /// Analytics allowed with available sink status
  ///
  /// In en, this message translates to:
  /// **'Allowed. Only the approved content-free event envelope may reach the configured sink.'**
  String get analyticsPrivacyStatusAvailable;

  /// Analytics allowed but unavailable sink status
  ///
  /// In en, this message translates to:
  /// **'Choice saved, but no external behavioral analytics sink is installed, so nothing is sent.'**
  String get analyticsPrivacyStatusNoSink;

  /// Analytics preference saving status
  ///
  /// In en, this message translates to:
  /// **'Saving the device analytics preference…'**
  String get analyticsPrivacySaving;

  /// Analytics preference save failure
  ///
  /// In en, this message translates to:
  /// **'The preference could not be saved. The previous choice remains in effect and no raw error was retained.'**
  String get analyticsPrivacySaveFailed;

  /// Analytics preference saved status
  ///
  /// In en, this message translates to:
  /// **'The device analytics preference was saved.'**
  String get analyticsPrivacySaved;

  /// Analytics event allowlist heading
  ///
  /// In en, this message translates to:
  /// **'Exact event boundary'**
  String get analyticsPrivacyAllowlistTitle;

  /// Explains typed event and envelope limits
  ///
  /// In en, this message translates to:
  /// **'KinFlow accepts only six typed product events and a five-field public build envelope. Free-form event names and attributes are rejected by the application boundary.'**
  String get analyticsPrivacyAllowlistBody;

  /// Managed Child analytics policy heading
  ///
  /// In en, this message translates to:
  /// **'Managed Child protection'**
  String get analyticsPrivacyChildPolicyTitle;

  /// Explains future child-mode fail-closed analytics gate
  ///
  /// In en, this message translates to:
  /// **'Managed Child mode is not part of the adult-only Store MVP. If added later, optional analytics is blocked before preference storage or any sink is accessed.'**
  String get analyticsPrivacyChildPolicyBody;

  /// SDK inventory heading
  ///
  /// In en, this message translates to:
  /// **'Current data-handling SDK inventory'**
  String get analyticsPrivacyInventoryTitle;

  /// Behavioral analytics SDK inventory entry
  ///
  /// In en, this message translates to:
  /// **'Behavioral analytics and advertising: no external SDK installed.'**
  String get analyticsPrivacyInventoryBehavioral;

  /// Operational error SDK inventory entry
  ///
  /// In en, this message translates to:
  /// **'Sentry: privacy-filtered crashes and operational errors only; it is not the optional usage analytics sink.'**
  String get analyticsPrivacyInventoryOperational;

  /// Notification SDK inventory entry
  ///
  /// In en, this message translates to:
  /// **'Firebase Messaging and local notifications: notification transport and display only.'**
  String get analyticsPrivacyInventoryNotifications;

  /// Billing SDK inventory entry
  ///
  /// In en, this message translates to:
  /// **'RevenueCat: Store purchase and entitlement processing only.'**
  String get analyticsPrivacyInventoryBilling;

  /// Identity and data SDK inventory entry
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In and Supabase: authentication and app data services, not behavioral analytics.'**
  String get analyticsPrivacyInventoryIdentity;

  /// Analytics forbidden data heading
  ///
  /// In en, this message translates to:
  /// **'Never included in optional analytics'**
  String get analyticsPrivacyNeverCollectedTitle;

  /// Analytics forbidden data categories
  ///
  /// In en, this message translates to:
  /// **'No account, household, member or child identifiers; email, names or family content; tokens, receipts, URLs or raw errors; location, contacts, advertising IDs or device fingerprints.'**
  String get analyticsPrivacyNeverCollectedBody;

  /// Settings item title for the local diagnostic report
  ///
  /// In en, this message translates to:
  /// **'Diagnostic information'**
  String get settingsDiagnosticsTitle;

  /// Settings item summary for the local diagnostic report
  ///
  /// In en, this message translates to:
  /// **'Review and copy a PII-free app, build, platform, and incident report.'**
  String get settingsDiagnosticsSummary;

  /// Diagnostic report screen title
  ///
  /// In en, this message translates to:
  /// **'Diagnostic information'**
  String get diagnosticsTitle;

  /// Diagnostic report introduction heading
  ///
  /// In en, this message translates to:
  /// **'A local support reference'**
  String get diagnosticsIntroHeading;

  /// Explains local generation, explicit sharing, and incident ID behavior
  ///
  /// In en, this message translates to:
  /// **'KinFlow creates this report on your device and does not upload its contents. A random incident ID may be recorded in PII-filtered app diagnostics so support can correlate an issue. Copy the report only when you choose to share it.'**
  String get diagnosticsIntroBody;

  /// Diagnostic data allowlist heading
  ///
  /// In en, this message translates to:
  /// **'Included information'**
  String get diagnosticsIncludedTitle;

  /// Exact categories included in the diagnostic report
  ///
  /// In en, this message translates to:
  /// **'App ID, app version, build number, dev or prod environment, API contract date, broad platform category, random incident ID, and UTC creation time.'**
  String get diagnosticsIncludedBody;

  /// Diagnostic excluded data heading
  ///
  /// In en, this message translates to:
  /// **'Never included'**
  String get diagnosticsExcludedTitle;

  /// Sensitive and identifying categories excluded from the diagnostic report
  ///
  /// In en, this message translates to:
  /// **'No account, household, profile, email, chores, calendar, notifications, billing content, credentials, network data, device model, serial number, advertising ID, locale, or timezone.'**
  String get diagnosticsExcludedBody;

  /// Diagnostic report initial loading status
  ///
  /// In en, this message translates to:
  /// **'Creating a local PII-free diagnostic report…'**
  String get diagnosticsLoading;

  /// Diagnostic metadata source unavailable failure
  ///
  /// In en, this message translates to:
  /// **'Diagnostic information is temporarily unavailable. No partial report was copied or uploaded.'**
  String get diagnosticsUnavailable;

  /// Installed and configured app metadata mismatch failure
  ///
  /// In en, this message translates to:
  /// **'The installed app metadata does not match this configured build, so KinFlow refused to create a partial or misleading report.'**
  String get diagnosticsInvalidMetadata;

  /// Generic diagnostic generation failure
  ///
  /// In en, this message translates to:
  /// **'The diagnostic report could not be created safely. No partial report was copied or uploaded.'**
  String get diagnosticsInternal;

  /// Diagnostic report preview heading
  ///
  /// In en, this message translates to:
  /// **'Report preview'**
  String get diagnosticsReportTitle;

  /// Diagnostic application identifier label
  ///
  /// In en, this message translates to:
  /// **'Application ID'**
  String get diagnosticsApplicationIdLabel;

  /// Diagnostic app version label
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get diagnosticsAppVersionLabel;

  /// Diagnostic build number label
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get diagnosticsBuildNumberLabel;

  /// Diagnostic dev or prod environment label
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get diagnosticsEnvironmentLabel;

  /// Diagnostic API contract date label
  ///
  /// In en, this message translates to:
  /// **'API contract date'**
  String get diagnosticsContractVersionLabel;

  /// Diagnostic coarse device platform label
  ///
  /// In en, this message translates to:
  /// **'Broad platform category'**
  String get diagnosticsDevicePlatformLabel;

  /// Diagnostic random incident identifier label
  ///
  /// In en, this message translates to:
  /// **'Incident ID'**
  String get diagnosticsIncidentIdLabel;

  /// Diagnostic UTC creation timestamp label
  ///
  /// In en, this message translates to:
  /// **'Created at (UTC)'**
  String get diagnosticsGeneratedAtLabel;

  /// Clipboard privacy and retention guidance
  ///
  /// In en, this message translates to:
  /// **'Copying writes this JSON report to the system clipboard without reading its existing contents. Paste it only into a trusted support request, then clear it if your device or keyboard keeps clipboard history.'**
  String get diagnosticsClipboardNotice;

  /// Explicit diagnostic clipboard write action
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostic information'**
  String get diagnosticsCopyAction;

  /// Regenerates the local report with a new random incident ID
  ///
  /// In en, this message translates to:
  /// **'Create a new incident ID'**
  String get diagnosticsNewIncidentAction;

  /// Diagnostic report refresh status
  ///
  /// In en, this message translates to:
  /// **'Creating a new local report while keeping the current report available…'**
  String get diagnosticsRefreshing;

  /// Diagnostic clipboard write status
  ///
  /// In en, this message translates to:
  /// **'Writing the PII-free JSON report to the system clipboard…'**
  String get diagnosticsCopying;

  /// Diagnostic clipboard write success notice
  ///
  /// In en, this message translates to:
  /// **'Diagnostic information was copied. The report contents were not uploaded automatically.'**
  String get diagnosticsCopied;

  /// Diagnostic clipboard write failure notice
  ///
  /// In en, this message translates to:
  /// **'The system clipboard could not be written. The report remains visible and its contents were not uploaded.'**
  String get diagnosticsCopyFailed;

  /// Diagnostic refresh failure notice
  ///
  /// In en, this message translates to:
  /// **'A new incident ID could not be created. The previous report remains unchanged.'**
  String get diagnosticsRefreshFailed;

  /// Heading for the adult household activation progress card
  ///
  /// In en, this message translates to:
  /// **'Get the household started together'**
  String get householdActivationTitle;

  /// Explains the activation milestone card
  ///
  /// In en, this message translates to:
  /// **'Finish these four milestones to establish a shared household routine.'**
  String get householdActivationBody;

  /// Activation completion message
  ///
  /// In en, this message translates to:
  /// **'Your household completed all four getting-started milestones.'**
  String get householdActivationCompleteBody;

  /// Accessible activation progress loading status
  ///
  /// In en, this message translates to:
  /// **'Refreshing household getting-started progress'**
  String get householdActivationLoadingLabel;

  /// Activation progress summary
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} milestones complete'**
  String householdActivationSummary(int completed, int total);

  /// Activation adult participation step
  ///
  /// In en, this message translates to:
  /// **'Invite a second adult'**
  String get householdActivationAdultTitle;

  /// Adult participation milestone count
  ///
  /// In en, this message translates to:
  /// **'{current} of {goal} adults have joined this household.'**
  String householdActivationAdultProgress(int current, int goal);

  /// Opens household invite creation from activation progress
  ///
  /// In en, this message translates to:
  /// **'Invite an adult'**
  String get householdActivationInviteAction;

  /// Activation chore creation step
  ///
  /// In en, this message translates to:
  /// **'Create three chores'**
  String get householdActivationChoreTitle;

  /// Chore creation milestone count
  ///
  /// In en, this message translates to:
  /// **'{current} of {goal} chores have been created.'**
  String householdActivationChoreProgress(int current, int goal);

  /// Opens chore creation from activation progress
  ///
  /// In en, this message translates to:
  /// **'Add a chore'**
  String get householdActivationCreateAction;

  /// Activation distinct-adult completion step
  ///
  /// In en, this message translates to:
  /// **'Complete one chore each'**
  String get householdActivationCompletionTitle;

  /// Distinct adult completion milestone count
  ///
  /// In en, this message translates to:
  /// **'{current} of {goal} adults have completed at least one chore.'**
  String householdActivationCompletionProgress(int current, int goal);

  /// Activation return visit step
  ///
  /// In en, this message translates to:
  /// **'Come back on another day'**
  String get householdActivationReturnTitle;

  /// Return milestone pending explanation
  ///
  /// In en, this message translates to:
  /// **'Open Today again after the household\'s first local date has passed.'**
  String get householdActivationReturnPending;

  /// Return milestone completion explanation
  ///
  /// In en, this message translates to:
  /// **'Today was opened after the household\'s first local date.'**
  String get householdActivationReturnComplete;

  /// Accessible label for a completed activation step
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get householdActivationStepComplete;

  /// Non-blocking activation projection failure
  ///
  /// In en, this message translates to:
  /// **'Getting-started progress is unavailable. Today\'s chores and events still work, and you can retry this card.'**
  String get householdActivationUnavailableBody;

  /// Activation actions disabled for cached Today
  ///
  /// In en, this message translates to:
  /// **'Invite and chore actions are unavailable while Today is showing saved data.'**
  String get householdActivationReadOnlyBody;

  /// Heading for the closed-week household chore aggregate
  ///
  /// In en, this message translates to:
  /// **'Household weekly recap'**
  String get weeklyReportTitle;

  /// Opens the detailed weekly report sheet
  ///
  /// In en, this message translates to:
  /// **'Open household weekly recap'**
  String get weeklyReportOpenAction;

  /// Accessible weekly report loading status
  ///
  /// In en, this message translates to:
  /// **'Loading household weekly recap…'**
  String get weeklyReportLoading;

  /// Accessible weekly report refresh status
  ///
  /// In en, this message translates to:
  /// **'Refreshing household weekly recap…'**
  String get weeklyReportRefreshing;

  /// Non-blocking weekly report failure heading
  ///
  /// In en, this message translates to:
  /// **'Weekly recap unavailable'**
  String get weeklyReportUnavailableTitle;

  /// Non-blocking weekly report failure explanation
  ///
  /// In en, this message translates to:
  /// **'Today\'s chores still work. Try this recap again when you\'re ready.'**
  String get weeklyReportUnavailableBody;

  /// Inclusive household-local report week range
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String weeklyReportWeekRange(String start, String end);

  /// Label for the newest fully closed household-local week
  ///
  /// In en, this message translates to:
  /// **'Latest closed week'**
  String get weeklyReportLatestWeek;

  /// Completed versus due weekly chore count
  ///
  /// In en, this message translates to:
  /// **'{completed} of {due} due chores completed'**
  String weeklyReportSummary(int completed, int due);

  /// Compact on-time completion versus due weekly chore count
  ///
  /// In en, this message translates to:
  /// **'{completed} of {due} due chores completed by the end of the week'**
  String weeklyReportCardSummary(int completed, int due);

  /// Empty weekly report message
  ///
  /// In en, this message translates to:
  /// **'No chores were due or skipped this week.'**
  String get weeklyReportEmpty;

  /// Accessible on-time weekly completion rate
  ///
  /// In en, this message translates to:
  /// **'{percent}% completed by the end of the week'**
  String weeklyReportByWeekEndRate(int percent);

  /// Weekly chores completed by the week boundary
  ///
  /// In en, this message translates to:
  /// **'{count} completed by the end of the week'**
  String weeklyReportCompletedByWeekEnd(int count);

  /// Weekly chores completed after the week boundary
  ///
  /// In en, this message translates to:
  /// **'{count} completed later'**
  String weeklyReportCompletedLater(int count);

  /// Weekly due chores still scheduled
  ///
  /// In en, this message translates to:
  /// **'{count} still open'**
  String weeklyReportStillOpen(int count);

  /// Weekly skipped chore count
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String weeklyReportSkipped(int count);

  /// Current viewer weekly completion contribution
  ///
  /// In en, this message translates to:
  /// **'You completed {count}'**
  String weeklyReportYourContribution(int count);

  /// Weekly active household member breakdown heading
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get weeklyReportBreakdownTitle;

  /// Named active member weekly completion contribution
  ///
  /// In en, this message translates to:
  /// **'{name}: {count} completed'**
  String weeklyReportMemberContribution(String name, int count);

  /// Named member weekly completions by the week boundary
  ///
  /// In en, this message translates to:
  /// **'{count} by the end of the week'**
  String weeklyReportMemberByWeekEnd(int count);

  /// Privacy-preserving aggregate for removed, deleted, or overflow contributors
  ///
  /// In en, this message translates to:
  /// **'Other or former members: {count} completed'**
  String weeklyReportOtherContribution(int count);

  /// Explains the privacy and payload bound on named contributors
  ///
  /// In en, this message translates to:
  /// **'Showing up to 20 current household members. Remaining contributions are combined above.'**
  String get weeklyReportTruncatedNotice;

  /// Loads the previous closed report week
  ///
  /// In en, this message translates to:
  /// **'Older week'**
  String get weeklyReportOlderWeek;

  /// Loads the next closed report week
  ///
  /// In en, this message translates to:
  /// **'Newer week'**
  String get weeklyReportNewerWeek;

  /// Runtime policy fetch failure banner title
  ///
  /// In en, this message translates to:
  /// **'Service status couldn\'t be verified'**
  String get runtimePolicyUnavailableTitle;

  /// Non-blocking runtime policy failure explanation
  ///
  /// In en, this message translates to:
  /// **'Saved information remains available. Online changes may be unavailable until this check succeeds.'**
  String get runtimePolicyUnavailableBody;

  /// Emergency mutation kill-switch banner title
  ///
  /// In en, this message translates to:
  /// **'KinFlow is temporarily read-only'**
  String get runtimePolicyReadOnlyTitle;

  /// Emergency read-only mode preserved operations
  ///
  /// In en, this message translates to:
  /// **'You can still view information and use export, deletion, legal, support, and diagnostics. Other changes are paused.'**
  String get runtimePolicyReadOnlyBody;

  /// Minimum supported build banner title
  ///
  /// In en, this message translates to:
  /// **'Update required before making changes'**
  String get runtimePolicyUpdateTitle;

  /// Minimum supported version explanation
  ///
  /// In en, this message translates to:
  /// **'Update KinFlow to version {version} or later. Reading, export, deletion, legal, support, and diagnostics remain available.'**
  String runtimePolicyUpdateBody(String version);

  /// Opens the fixed Play Store listing
  ///
  /// In en, this message translates to:
  /// **'Open Play Store'**
  String get runtimePolicyUpdateAction;

  /// Safe fixed update-link launch failure
  ///
  /// In en, this message translates to:
  /// **'The Play Store couldn\'t be opened. Try again or update KinFlow directly in the Store app.'**
  String get runtimePolicyUpdateUnavailable;

  /// Capability-specific runtime mutation switch banner title
  ///
  /// In en, this message translates to:
  /// **'Some changes are temporarily paused'**
  String get runtimePolicyFeatureDisabledTitle;

  /// Lists disabled mutation capabilities while preserving other actions
  ///
  /// In en, this message translates to:
  /// **'Paused: {features}. Other features, reading, export, deletion, legal, support, and diagnostics remain available.'**
  String runtimePolicyFeatureDisabledBody(String features);

  /// Runtime policy household capability label
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get runtimePolicyFeatureHousehold;

  /// Runtime policy chores capability label
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get runtimePolicyFeatureChores;

  /// Runtime policy calendar capability label
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get runtimePolicyFeatureCalendar;

  /// Runtime policy notifications capability label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get runtimePolicyFeatureNotifications;

  /// Runtime policy profile capability label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get runtimePolicyFeatureProfile;

  /// Runtime policy billing capability label
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get runtimePolicyFeatureBilling;

  /// Title of the one-time chore trash screen
  ///
  /// In en, this message translates to:
  /// **'Recently deleted chores'**
  String get choreTrashTitle;

  /// Opens the one-time chore trash screen
  ///
  /// In en, this message translates to:
  /// **'Open recently deleted chores'**
  String get choreTrashOpenAction;

  /// Returns from chore trash to Today
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get choreTrashTodayAction;

  /// Accessible loading status for chore trash
  ///
  /// In en, this message translates to:
  /// **'Loading recently deleted chores…'**
  String get choreTrashLoading;

  /// Empty chore trash heading
  ///
  /// In en, this message translates to:
  /// **'No recently deleted chores'**
  String get choreTrashEmptyTitle;

  /// Empty chore trash explanation
  ///
  /// In en, this message translates to:
  /// **'Deleted one-time chores will appear here so an adult can restore them.'**
  String get choreTrashEmptyBody;

  /// Safe stale-content notice after trash refresh failure
  ///
  /// In en, this message translates to:
  /// **'Recently deleted chores could not be refreshed. The current list is still shown.'**
  String get choreTrashRefreshFailed;

  /// Localized chore deletion timestamp
  ///
  /// In en, this message translates to:
  /// **'Deleted {date} at {time}'**
  String choreTrashDeletedAt(String date, String time);

  /// Preserved all-day chore due date
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String choreTrashDueDate(String date);

  /// Preserved timed chore due intent
  ///
  /// In en, this message translates to:
  /// **'Due {date} at {time}'**
  String choreTrashDueDateTime(String date, String time);

  /// Preserved assignee for a deleted chore
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name}'**
  String choreTrashAssignee(String name);

  /// Restores one deleted one-time chore
  ///
  /// In en, this message translates to:
  /// **'Restore chore'**
  String get choreTrashRestoreAction;

  /// Pending one-time chore restore action
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get choreTrashRestoringAction;

  /// Confirmation after trash restore
  ///
  /// In en, this message translates to:
  /// **'The one-time chore was restored.'**
  String get choreTrashRestoreSucceeded;

  /// Loads the next bounded trash page
  ///
  /// In en, this message translates to:
  /// **'Load more deleted chores'**
  String get choreTrashLoadMoreAction;

  /// Safe trash pagination failure
  ///
  /// In en, this message translates to:
  /// **'More deleted chores could not be loaded.'**
  String get choreTrashLoadMoreFailed;

  /// Immediately restores the one-time chore that was just deleted
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get choreDeleteUndoAction;

  /// Confirmation after immediate deletion undo
  ///
  /// In en, this message translates to:
  /// **'The deleted chore was restored.'**
  String get choreRestoreOneTimeSucceeded;

  /// Safe immediate deletion undo failure
  ///
  /// In en, this message translates to:
  /// **'The deleted chore could not be restored. Try again from Recently deleted chores.'**
  String get choreRestoreOneTimeFailed;

  /// Settings tile title for the local platform capability registry
  ///
  /// In en, this message translates to:
  /// **'Device capability status'**
  String get settingsDeviceCapabilitiesTitle;

  /// Settings tile summary for platform capabilities
  ///
  /// In en, this message translates to:
  /// **'Review support, setup needs, and safe fallbacks for this device.'**
  String get settingsDeviceCapabilitiesSummary;

  /// Platform capability status screen title
  ///
  /// In en, this message translates to:
  /// **'Device capability status'**
  String get platformCapabilitiesTitle;

  /// Platform capability screen introduction heading
  ///
  /// In en, this message translates to:
  /// **'How KinFlow works on this device'**
  String get platformCapabilitiesIntroTitle;

  /// Scope of the local capability snapshot
  ///
  /// In en, this message translates to:
  /// **'This local snapshot shows the Android integrations selected by this app build and the current notification permission state. It does not test provider or server connectivity.'**
  String get platformCapabilitiesIntroBody;

  /// Capability screen privacy boundary
  ///
  /// In en, this message translates to:
  /// **'No account, household, device, payment, configuration, or provider error details are included or uploaded from this screen.'**
  String get platformCapabilitiesPrivacyNote;

  /// Capability self-check card heading
  ///
  /// In en, this message translates to:
  /// **'Capability self-check and recovery plan'**
  String get platformCapabilitiesSelfCheckTitle;

  /// Capability self-check summary explanation
  ///
  /// In en, this message translates to:
  /// **'Review what is ready first, then follow the ordered recovery steps for anything that needs attention or a fallback.'**
  String get platformCapabilitiesSelfCheckBody;

  /// Count of fully available capabilities
  ///
  /// In en, this message translates to:
  /// **'{count} ready'**
  String platformCapabilitiesReadyCount(int count);

  /// Count of capability states needing attention
  ///
  /// In en, this message translates to:
  /// **'{count} need attention'**
  String platformCapabilitiesAttentionCount(int count);

  /// Count of fallback-only or intentionally limited capabilities
  ///
  /// In en, this message translates to:
  /// **'{count} use a fallback or limitation'**
  String platformCapabilitiesAlternativeCount(int count);

  /// Heading above ordered capability recovery steps
  ///
  /// In en, this message translates to:
  /// **'Recommended recovery order'**
  String get platformCapabilitiesRecoveryHeading;

  /// Message when a capability snapshot has no recovery steps
  ///
  /// In en, this message translates to:
  /// **'All primary capabilities are ready. Safe fallbacks still remain available when needed.'**
  String get platformCapabilitiesRecoveryEmpty;

  /// Stable recovery plan position
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String platformCapabilitiesRecoveryStep(int number);

  /// Explicitly refreshes notification permission and binding state
  ///
  /// In en, this message translates to:
  /// **'Recheck notification setup'**
  String get platformCapabilitiesSelfCheckAction;

  /// Pending capability self-check action
  ///
  /// In en, this message translates to:
  /// **'Checking notification setup…'**
  String get platformCapabilitiesSelfCheckRefreshing;

  /// Side-effect boundary for the notification capability self-check
  ///
  /// In en, this message translates to:
  /// **'This action does not request permission or open system settings. The existing notification coordinator may safely clean up or restore the device binding when the current permission changed.'**
  String get platformCapabilitiesSelfCheckScope;

  /// Successful local capability self-check message
  ///
  /// In en, this message translates to:
  /// **'Notification permission and device binding status were checked again.'**
  String get platformCapabilitiesSelfCheckSucceeded;

  /// Stable capability self-check failure message
  ///
  /// In en, this message translates to:
  /// **'Notification setup could not be checked right now. The inbox and the listed safe fallbacks remain available.'**
  String get platformCapabilitiesSelfCheckFailed;

  /// Label for a selected platform provider
  ///
  /// In en, this message translates to:
  /// **'Selected integration'**
  String get platformCapabilitiesProviderLabel;

  /// Label for a capability fallback
  ///
  /// In en, this message translates to:
  /// **'Safe fallback'**
  String get platformCapabilitiesFallbackLabel;

  /// Notification platform capability title
  ///
  /// In en, this message translates to:
  /// **'Notification delivery'**
  String get platformCapabilitiesNotificationTitle;

  /// Billing platform capability title
  ///
  /// In en, this message translates to:
  /// **'Google Play billing'**
  String get platformCapabilitiesBillingTitle;

  /// Secure storage platform capability title
  ///
  /// In en, this message translates to:
  /// **'Encrypted local storage'**
  String get platformCapabilitiesSecureStorageTitle;

  /// External URI platform capability title
  ///
  /// In en, this message translates to:
  /// **'External links and downloads'**
  String get platformCapabilitiesExternalLinksTitle;

  /// Background delivery platform capability title
  ///
  /// In en, this message translates to:
  /// **'Background delivery'**
  String get platformCapabilitiesBackgroundTitle;

  /// Capability state when the primary adapter is supported
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get platformCapabilitiesStateAvailable;

  /// Capability state when user setup is needed
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get platformCapabilitiesStateActionRequired;

  /// Capability state for an intentional client limitation
  ///
  /// In en, this message translates to:
  /// **'Limited by design'**
  String get platformCapabilitiesStateLimited;

  /// Capability state when only the safe fallback is available
  ///
  /// In en, this message translates to:
  /// **'Using fallback'**
  String get platformCapabilitiesStateFallbackOnly;

  /// Capability state for a temporary local provider problem
  ///
  /// In en, this message translates to:
  /// **'Temporary issue'**
  String get platformCapabilitiesStateTemporaryIssue;

  /// Safe display label for the Android push provider
  ///
  /// In en, this message translates to:
  /// **'Firebase Messaging for Android'**
  String get platformCapabilitiesProviderFirebaseMessaging;

  /// Safe display label for the Android billing provider
  ///
  /// In en, this message translates to:
  /// **'RevenueCat with Google Play'**
  String get platformCapabilitiesProviderRevenueCatPlay;

  /// Safe display label for encrypted Android storage
  ///
  /// In en, this message translates to:
  /// **'Android Keystore-backed storage'**
  String get platformCapabilitiesProviderAndroidKeystore;

  /// Safe display label for the external URI provider
  ///
  /// In en, this message translates to:
  /// **'Android system link handler'**
  String get platformCapabilitiesProviderAndroidUriLauncher;

  /// Safe display label for the Web external URI provider
  ///
  /// In en, this message translates to:
  /// **'Browser trusted link handler'**
  String get platformCapabilitiesProviderBrowserUriLauncher;

  /// Safe display label for the Android background push handler
  ///
  /// In en, this message translates to:
  /// **'Firebase Android background handler'**
  String get platformCapabilitiesProviderFirebaseBackground;

  /// Safe provider label when no primary adapter was composed
  ///
  /// In en, this message translates to:
  /// **'Not configured in this app build'**
  String get platformCapabilitiesProviderUnavailable;

  /// Notification delivery fallback
  ///
  /// In en, this message translates to:
  /// **'Durable in-app notification inbox'**
  String get platformCapabilitiesFallbackInbox;

  /// Web notification delivery fallback without Web Push
  ///
  /// In en, this message translates to:
  /// **'Durable in-app inbox and configured generic email'**
  String get platformCapabilitiesFallbackInboxAndEmail;

  /// Billing capability fallback
  ///
  /// In en, this message translates to:
  /// **'Server-confirmed entitlement and read-only subscription status'**
  String get platformCapabilitiesFallbackEntitlement;

  /// Secure storage capability fallback
  ///
  /// In en, this message translates to:
  /// **'Re-authentication without persistent offline data'**
  String get platformCapabilitiesFallbackReauthentication;

  /// External link capability fallback
  ///
  /// In en, this message translates to:
  /// **'On-screen guidance and local diagnostics'**
  String get platformCapabilitiesFallbackGuidance;

  /// Background delivery capability fallback
  ///
  /// In en, this message translates to:
  /// **'Server notification processing and the in-app inbox'**
  String get platformCapabilitiesFallbackServerNotifications;

  /// Notification capability ready explanation
  ///
  /// In en, this message translates to:
  /// **'Android push is supported. Important events also remain available in Notifications.'**
  String get platformCapabilitiesNotificationAvailable;

  /// Notification permission not determined explanation
  ///
  /// In en, this message translates to:
  /// **'A notification choice has not been made yet. Choose it in Notifications; the inbox still works.'**
  String get platformCapabilitiesNotificationNotDetermined;

  /// Notification permission denied explanation
  ///
  /// In en, this message translates to:
  /// **'System notifications are turned off for KinFlow. You can review the choice in Notifications; the inbox still works.'**
  String get platformCapabilitiesNotificationDenied;

  /// Notification runtime unavailable explanation
  ///
  /// In en, this message translates to:
  /// **'Android notification delivery is unavailable on this runtime. Important events remain in the inbox.'**
  String get platformCapabilitiesNotificationRuntimeUnavailable;

  /// Notification temporary failure explanation
  ///
  /// In en, this message translates to:
  /// **'The notification adapter reported a temporary local problem. Existing inbox content remains available.'**
  String get platformCapabilitiesNotificationTemporary;

  /// Notification adapter missing explanation
  ///
  /// In en, this message translates to:
  /// **'Push delivery is not configured in this app build. Important events remain in the inbox.'**
  String get platformCapabilitiesNotificationNotConfigured;

  /// Billing capability ready explanation
  ///
  /// In en, this message translates to:
  /// **'Google Play purchasing is supported. Household access still follows the server-confirmed entitlement.'**
  String get platformCapabilitiesBillingAvailable;

  /// Billing adapter missing explanation
  ///
  /// In en, this message translates to:
  /// **'Store purchasing is unavailable in this app build. Existing server-confirmed access and subscription details remain readable.'**
  String get platformCapabilitiesBillingNotConfigured;

  /// Secure storage capability ready explanation
  ///
  /// In en, this message translates to:
  /// **'Sensitive session and supported offline snapshots use Android encrypted storage.'**
  String get platformCapabilitiesSecureStorageAvailable;

  /// Secure storage adapter missing explanation
  ///
  /// In en, this message translates to:
  /// **'Persistent encrypted offline data is unavailable. KinFlow falls back to re-authentication and fresh online reads.'**
  String get platformCapabilitiesSecureStorageNotConfigured;

  /// External URI capability ready explanation
  ///
  /// In en, this message translates to:
  /// **'Trusted support, policy, Store, and export links can use the Android system handler.'**
  String get platformCapabilitiesExternalLinksAvailable;

  /// External URI adapter missing explanation
  ///
  /// In en, this message translates to:
  /// **'External link handling is unavailable in this app build. On-screen guidance and diagnostics remain available.'**
  String get platformCapabilitiesExternalLinksNotConfigured;

  /// Intentional background delivery limitation explanation
  ///
  /// In en, this message translates to:
  /// **'Android can receive background push entry events, while the server pipeline remains the delivery source of truth.'**
  String get platformCapabilitiesBackgroundLimited;

  /// Background adapter missing explanation
  ///
  /// In en, this message translates to:
  /// **'Client background delivery is not configured. Server processing and the in-app inbox remain the fallback.'**
  String get platformCapabilitiesBackgroundNotConfigured;

  /// Fail-closed generic capability explanation
  ///
  /// In en, this message translates to:
  /// **'This capability state is unavailable. Use the named fallback and local diagnostics.'**
  String get platformCapabilitiesSafeUnknownState;

  /// Opens notification settings and inbox
  ///
  /// In en, this message translates to:
  /// **'Open Notifications'**
  String get platformCapabilitiesOpenNotificationsAction;

  /// Opens subscription settings
  ///
  /// In en, this message translates to:
  /// **'Open subscription settings'**
  String get platformCapabilitiesOpenSubscriptionAction;

  /// Opens the local diagnostic report
  ///
  /// In en, this message translates to:
  /// **'Open diagnostics'**
  String get platformCapabilitiesOpenDiagnosticsAction;
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
