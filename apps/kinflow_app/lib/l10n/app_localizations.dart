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
