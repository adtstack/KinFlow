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
  String get retryAction => 'Try again';

  @override
  String get foundationReadyTitle => 'KinFlow is ready';

  @override
  String get foundationReadyBody =>
      'The app foundation is running. Sign-in comes next.';

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get pageNotFoundBody => 'This page is unavailable.';

  @override
  String get goHomeAction => 'Go home';
}
