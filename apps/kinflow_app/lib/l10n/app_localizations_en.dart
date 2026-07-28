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
}
