// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'KinFlow';

  @override
  String get developmentBanner => '개발';

  @override
  String get startupLoadingLabel => 'KinFlow를 시작하는 중입니다';

  @override
  String get startupErrorTitle => 'KinFlow를 시작하지 못했습니다';

  @override
  String get startupErrorBody => '다시 시도해 주세요. 문제가 계속되면 앱을 다시 실행해 주세요.';

  @override
  String get retryAction => '다시 시도';

  @override
  String get retryActionHint => '이 확인을 다시 실행합니다';

  @override
  String get foundationReadyTitle => 'KinFlow를 사용할 준비가 되었습니다';

  @override
  String get foundationReadyBody =>
      '앱 기반과 코드 경계가 정상적으로 실행 중입니다. 이제 제품 기능을 안전하게 추가할 수 있습니다.';

  @override
  String foundationLayoutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '반응형 레이아웃 $count개를 사용할 수 있습니다.',
      one: '반응형 레이아웃 1개를 사용할 수 있습니다.',
    );
    return '$_temp0';
  }

  @override
  String get foundationLoadingLabel => '앱 기반을 확인하는 중입니다';

  @override
  String get foundationErrorTitle => '앱 기반을 확인할 수 없습니다';

  @override
  String get foundationErrorBody => '기반 확인을 다시 시도해 주세요.';

  @override
  String get pageNotFoundTitle => '페이지를 찾을 수 없습니다';

  @override
  String get pageNotFoundBody => '이 페이지는 사용할 수 없습니다.';

  @override
  String get goHomeAction => '홈으로 이동';

  @override
  String get primaryNavigationLabel => '주요 탐색';

  @override
  String get homeNavigationLabel => '홈';
}
