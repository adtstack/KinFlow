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
  String get authLoadingLabel => '로그인 상태를 확인하는 중입니다';

  @override
  String get authSignInTitle => 'KinFlow에 로그인';

  @override
  String get authSignInBody => '현재 KinFlow는 성인 계정의 Google 로그인만 지원합니다.';

  @override
  String get authGoogleSignInAction => 'Google로 계속';

  @override
  String get authGoogleSignInHint => '성인 Google 계정으로 로그인합니다';

  @override
  String get authSigningInLabel => 'Google에 연결하는 중입니다';

  @override
  String get authProviderUnavailableBody =>
      '현재 Google 로그인을 사용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get authSessionExpiredBody => '세션이 만료되었거나 회수되었습니다. 다시 로그인해 주세요.';

  @override
  String get authLocalStateLockedBody =>
      '로컬 데이터를 안전하게 지우지 못해 접근을 잠갔습니다. 앱을 다시 실행한 뒤 시도해 주세요.';

  @override
  String get authLogoutAction => '로그아웃';

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
