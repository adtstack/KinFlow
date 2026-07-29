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
  String get todayInviteAction => '성인 초대';

  @override
  String get inviteCreateTitle => '가구에 초대하기';

  @override
  String get inviteCreateHeading => '다른 성인과 KinFlow 함께 쓰기';

  @override
  String get inviteCreateBody =>
      '7일 뒤 만료되는 일회용 링크를 만듭니다. 필요하면 특정 이메일 계정만 수락하도록 제한할 수 있습니다.';

  @override
  String get inviteEmailLabel => '받는 사람 이메일(선택)';

  @override
  String get inviteEmailHint => '로그인한 계정의 이메일이 이 주소와 일치해야 합니다.';

  @override
  String get inviteCreateAction => '초대 링크 만들기';

  @override
  String get inviteCreatingAction => '초대 링크를 만드는 중';

  @override
  String get inviteLinkHeading => '초대 링크가 준비되었습니다';

  @override
  String get inviteLinkBody =>
      '초대할 성인에게만 공유하세요. 이 화면을 닫으면 KinFlow에서 토큰을 다시 표시하지 않습니다.';

  @override
  String get inviteCopyAction => '링크 복사';

  @override
  String get inviteCopiedBody => '초대 링크를 복사했습니다.';

  @override
  String get inviteTokenUnavailableBody =>
      '재시도는 안전하게 처리됐지만 일회용 링크를 다시 표시할 수 없습니다. 이 초대를 회수하고 새로 만들어 주세요.';

  @override
  String get inviteRevokeAction => '초대 회수';

  @override
  String get inviteRevokingAction => '초대를 회수하는 중';

  @override
  String get inviteNewAction => '새 초대 만들기';

  @override
  String get inviteOpenTitle => '가구 초대';

  @override
  String get inviteLoadingLabel => '초대를 확인하는 중입니다';

  @override
  String get inviteMissingTitle => '초대를 사용할 수 없습니다';

  @override
  String get inviteMissingBody => '원래 초대 링크를 다시 열거나 보낸 사람에게 새 링크를 요청해 주세요.';

  @override
  String invitePreviewSentence(String inviterName, String householdName) {
    return '$inviterName님이 $householdName 가구에 초대했습니다.';
  }

  @override
  String get inviteRoleMember => '가구 구성원';

  @override
  String get inviteRoleAdmin => '가구 관리자';

  @override
  String inviteExpiryLabel(String expiresAt) {
    return '$expiresAt 만료';
  }

  @override
  String get inviteSignInBody =>
      '이 가구에 참여할 성인 계정으로 로그인하세요. 로그인하는 동안 초대는 메모리에만 보관됩니다.';

  @override
  String get inviteSignInAction => '로그인하고 수락';

  @override
  String get inviteSwitchTitle => '활성 가구를 전환할까요?';

  @override
  String get inviteSwitchBody =>
      '이미 활성 가구가 있습니다. 참여하면 두 가구의 구성원 자격은 유지되고 KinFlow의 활성 가구가 이 가구로 바뀝니다.';

  @override
  String get inviteSwitchConfirmation => '이 가구에 참여하고 활성 가구를 전환하겠습니다.';

  @override
  String get inviteAcceptAction => '초대 수락';

  @override
  String get inviteAcceptingAction => '가구에 참여하는 중';

  @override
  String get inviteAcceptedBody => '가구에 참여했습니다. 오늘 화면을 여는 중입니다…';

  @override
  String get inviteInvalidError => '올바르지 않은 초대 링크입니다.';

  @override
  String get inviteExpiredError => '만료된 초대입니다. 보낸 사람에게 새 링크를 요청해 주세요.';

  @override
  String get inviteRevokedError => '회수된 초대입니다. 보낸 사람에게 새 링크를 요청해 주세요.';

  @override
  String get inviteAlreadyUsedError => '이미 수락된 일회용 초대입니다.';

  @override
  String get inviteEmailMismatchError => '이 초대가 지정한 이메일 계정으로 로그인해 주세요.';

  @override
  String get inviteRateLimitedError => '초대 요청이 너무 많습니다. 몇 분 뒤 다시 시도해 주세요.';

  @override
  String get invitePermissionError => '가구 Owner 또는 Admin만 초대를 관리할 수 있습니다.';

  @override
  String get inviteGenericError => '초대 요청을 완료하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get todayMembersAction => '가구 구성원 관리';

  @override
  String get membersTitle => '가구 구성원';

  @override
  String get membersLoadingLabel => '가구 구성원을 불러오는 중입니다';

  @override
  String membersHeading(String householdName) {
    return '$householdName 구성원';
  }

  @override
  String get membersBody => '활성 성인 구성원과 역할을 확인하고 관리합니다. 모든 변경은 온라인에서 처리됩니다.';

  @override
  String get membersYouLabel => '나';

  @override
  String get membersRoleOwner => 'Owner';

  @override
  String get membersRoleAdmin => 'Admin';

  @override
  String get membersRoleMember => 'Member';

  @override
  String membersMenuTooltip(String memberName) {
    return '$memberName 구성원 작업';
  }

  @override
  String get memberPromoteAdminAction => 'Admin으로 변경';

  @override
  String get memberDemoteMemberAction => 'Member로 변경';

  @override
  String get memberTransferOwnerAction => 'Owner 이전';

  @override
  String get memberRemoveAction => '가구에서 제거';

  @override
  String get householdLeaveAction => '이 가구 나가기';

  @override
  String get memberRoleChangeTitle => '역할을 변경할까요?';

  @override
  String memberRoleChangeBody(String memberName, String role) {
    return '$memberName님의 역할을 $role(으)로 변경합니다. 계속하면 Google에서 본인 확인을 요청합니다.';
  }

  @override
  String get memberRemoveTitle => '구성원을 제거할까요?';

  @override
  String memberRemoveBody(String memberName) {
    return '$memberName님은 즉시 이 가구에 접근할 수 없고, 이 구성원이 만든 사용 전 초대도 회수됩니다.';
  }

  @override
  String get ownerTransferTitle => 'Owner를 이전할까요?';

  @override
  String ownerTransferBody(String memberName) {
    return '$memberName님이 새 Owner가 되고 나는 Admin이 됩니다. 계속하면 Google에서 본인 확인을 요청합니다.';
  }

  @override
  String get householdLeaveTitle => '이 가구에서 나갈까요?';

  @override
  String get householdLeaveBody =>
      '내 구성원 자격과 이 가구 접근이 즉시 종료됩니다. 공동 기록은 가구에 남습니다.';

  @override
  String get ownerMustTransferBody =>
      'Owner는 가구에서 나가기 전에 다른 성인에게 Owner를 이전해야 합니다.';

  @override
  String get memberActionInProgress => '변경을 안전하게 처리하는 중입니다';

  @override
  String get memberCancelAction => '취소';

  @override
  String get memberConfirmAction => '계속';

  @override
  String get membersLoadError => '가구 구성원을 불러오지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get membersPermissionError => '이 구성원 작업을 수행할 권한이 없습니다.';

  @override
  String get membersVersionConflictError =>
      '구성원 정보가 다른 곳에서 변경되었습니다. 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get membersOwnerTransferRequiredError =>
      '마지막 Owner는 제거하거나 나갈 수 없습니다. 먼저 Owner를 이전해 주세요.';

  @override
  String get membersRecentAuthError =>
      '이 변경에는 최근 Google 본인 확인이 필요합니다. 다시 시도해 주세요.';

  @override
  String get membersRecentAuthCancelled =>
      'Google 본인 확인을 취소했습니다. 가구 정보는 변경되지 않았습니다.';

  @override
  String get membersAccountChangedError =>
      '다른 Google 계정이 선택되어 변경을 중단했습니다. 현재 계정을 확인해 주세요.';

  @override
  String get membersGenericError =>
      '가구 구성원 변경을 완료하지 못했습니다. 같은 요청을 안전하게 다시 시도할 수 있습니다.';

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
