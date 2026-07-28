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
  String get householdLookupErrorTitle => '가구 정보를 불러오지 못했습니다';

  @override
  String get householdLookupErrorBody =>
      '연결 상태를 확인하고 다시 시도해 주세요. 가구 데이터는 변경되지 않았습니다.';

  @override
  String get householdOnboardingTitle => '가구 설정';

  @override
  String get householdOnboardingHeading => '함께 사용할 집 만들기';

  @override
  String get householdOnboardingBody =>
      '이름, 언어와 IANA 시간대를 확인해 주세요. 이 가구의 Owner가 됩니다.';

  @override
  String get ownerDisplayNameLabel => '내 표시 이름';

  @override
  String get householdNameLabel => '가구 이름';

  @override
  String get householdNameValidation => '제어 문자를 제외한 1~80자를 입력해 주세요.';

  @override
  String get householdLocaleLabel => '언어';

  @override
  String get householdTimezoneLabel => '시간대';

  @override
  String get householdTimezoneHint => 'Asia/Seoul 같은 IANA 이름을 사용하세요.';

  @override
  String get householdTimezoneValidation => 'IANA 시간대를 입력해 주세요.';

  @override
  String get householdCreateAction => '가구 만들기';

  @override
  String get householdCreatingAction => '가구를 만드는 중';

  @override
  String get householdInvalidInputError => '입력한 내용을 확인하고 다시 시도해 주세요.';

  @override
  String get householdAlreadyExistsError =>
      '이 계정에는 이미 활성 가구가 있습니다. 가구 정보를 다시 불러와 주세요.';

  @override
  String get householdRequestConflictError =>
      '재시도 중 입력 내용이 변경되었습니다. 내용을 확인하고 다시 제출해 주세요.';

  @override
  String get householdCreateError =>
      '가구를 만들지 못했습니다. 같은 요청을 안전하게 다시 시도할 수 있습니다.';

  @override
  String get todayTitle => '오늘';

  @override
  String get todayEmptyTitle => '오늘 예정된 일이 없습니다';

  @override
  String get todayEmptyBody => '함께 사용할 가구가 준비되었습니다. 집안일을 추가하면 여기에 표시됩니다.';

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

  @override
  String get todayNavigationLabel => '오늘';
}
