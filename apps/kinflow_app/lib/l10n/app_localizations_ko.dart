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
  String get authSignInBody => '이메일로 받은 일회용 코드를 사용하거나 성인 Google 계정으로 계속하세요.';

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
  String get authIdentityConflictTitle => '이 계정을 자동으로 연결할 수 없습니다';

  @override
  String get authIdentityConflictBody =>
      'KinFlow는 계정을 자동으로 합치지 않았습니다. 다른 Google 계정을 선택하거나 이 계정이 이미 연결되어 있어야 한다면 지원 페이지를 열어 주세요.';

  @override
  String get authIdentityChooseAnotherAction => '다른 Google 계정 선택';

  @override
  String get authIdentityChooseAnotherHint => '계정을 합치지 않고 Google 계정 선택을 다시 엽니다';

  @override
  String get authIdentitySupportAction => '지원 페이지 열기';

  @override
  String get authIdentitySupportOpening => '지원 페이지를 여는 중입니다';

  @override
  String get authIdentitySupportOpened => 'KinFlow 밖에서 지원 페이지를 열었습니다.';

  @override
  String get authIdentitySupportUnavailable =>
      '지원 페이지를 열 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get authEmailSectionLabel => '이메일로 계속';

  @override
  String get authEmailLabel => '이메일 주소';

  @override
  String get authEmailHint =>
      '여섯 자리 코드를 보내 드립니다. 필요한 경우 새 성인 KinFlow 계정이 생성됩니다.';

  @override
  String get authEmailSendCodeAction => '로그인 코드 보내기';

  @override
  String get authEmailSendingCodeAction => '코드를 보내는 중';

  @override
  String authEmailCodeSentBody(String maskedEmail) {
    return '$maskedEmail 주소를 사용할 수 있다면 여섯 자리 코드를 보냈습니다. 받은편지함과 스팸함을 확인해 주세요.';
  }

  @override
  String get authEmailCodeLifetimeBody =>
      '가장 최근 코드는 10분 후 만료됩니다. 60초 후 새 코드를 요청할 수 있습니다.';

  @override
  String get authEmailCodeLabel => '여섯 자리 코드';

  @override
  String get authEmailCodeHint => '가장 최근 이메일의 숫자 여섯 자리를 모두 입력하세요.';

  @override
  String get authEmailVerifyAction => '확인하고 계속';

  @override
  String get authEmailVerifyingAction => '코드를 확인하는 중';

  @override
  String get authEmailResendAction => '새 코드 보내기';

  @override
  String get authEmailResendingAction => '새 코드를 보내는 중';

  @override
  String get authEmailChangeAction => '다른 이메일 사용';

  @override
  String get authEmailSigningInLabel => '코드를 확인했습니다. 로그인을 마치는 중입니다.';

  @override
  String get authEmailInvalidEmailError => '올바른 이메일 주소를 입력해 주세요.';

  @override
  String get authEmailInvalidCodeError => '가장 최근의 올바른 여섯 자리 코드를 입력해 주세요.';

  @override
  String get authEmailExpiredError => '이 코드는 만료되었습니다. 계속하려면 새 코드를 보내 주세요.';

  @override
  String get authEmailAlreadyUsedError => '이미 사용한 코드입니다.';

  @override
  String get authEmailRateLimitedError => '다른 코드를 요청하거나 확인하기 전에 잠시 기다려 주세요.';

  @override
  String get authEmailTemporarilyUnavailableError =>
      '현재 이메일 로그인을 사용할 수 없습니다. 나중에 다시 시도해 주세요.';

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
      '내 이름과 함께 사용할 가구 이름을 입력해 주세요. 이 가구의 Owner가 됩니다.';

  @override
  String get householdAdditionalSettingsTitle => '추가 설정';

  @override
  String get householdAdditionalSettingsBody => '언어와 시간대를 확인하거나 변경할 수 있습니다.';

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
  String get householdTimezoneHint => 'Asia/Seoul 같은 IANA 지역이나 도시를 선택하세요.';

  @override
  String get householdTimezonePickerTitle => '가구 시간대 선택';

  @override
  String get householdTimezoneValidation => 'IANA 시간대를 선택해 주세요.';

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
      '7일 링크와 24시간 보조 코드를 함께 만듭니다. 필요하면 특정 이메일 계정만 수락하도록 제한할 수 있습니다.';

  @override
  String get inviteEmailLabel => '받는 사람 이메일(선택)';

  @override
  String get inviteEmailHint => '로그인한 계정의 이메일이 이 주소와 일치해야 합니다.';

  @override
  String get inviteCreateAction => '초대 만들기';

  @override
  String get inviteCreatingAction => '초대 링크를 만드는 중';

  @override
  String get inviteLinkHeading => '초대가 준비되었습니다';

  @override
  String get inviteLinkBody =>
      '초대할 성인에게만 공유하세요. 이 화면을 닫으면 KinFlow에서 토큰을 다시 표시하지 않습니다.';

  @override
  String get inviteCodeHeading => '24시간 초대 코드';

  @override
  String get inviteCodeBody =>
      '초대할 성인에게만 공유하세요. 링크보다 먼저 만료되며 이 화면을 닫으면 다시 표시되지 않습니다.';

  @override
  String get inviteCodeCopyAction => '코드 복사';

  @override
  String get inviteCodeCopiedBody => '초대 코드를 복사했습니다.';

  @override
  String get inviteCopyAction => '링크 복사';

  @override
  String get inviteCopiedBody => '초대 링크를 복사했습니다.';

  @override
  String get inviteShareAction => '링크 공유';

  @override
  String get inviteShareChooserTitle => 'KinFlow 초대 공유';

  @override
  String get inviteShareOpeningBody => '공유 시트를 여는 중…';

  @override
  String get inviteShareOpenedBody =>
      '공유 시트를 열었습니다. 보내기 전에 받는 사람을 확인하세요. KinFlow는 전달 완료를 확인할 수 없습니다.';

  @override
  String get inviteShareUnavailableBody =>
      '공유 시트를 열 수 없습니다. 아래의 링크 복사를 눌러 초대할 성인에게만 보내세요.';

  @override
  String get inviteShareFailedBody =>
      '공유를 안전하게 중단했습니다. 아래의 링크 복사를 사용하거나 링크 공유를 다시 시도하세요.';

  @override
  String get inviteCopyingBody => '초대를 시스템 클립보드에 쓰는 중…';

  @override
  String get inviteCopyFailedBody => '초대를 복사하지 못했습니다. 위 값을 직접 선택하거나 다시 시도하세요.';

  @override
  String get inviteClipboardNotice =>
      '복사하면 일회용 초대가 시스템 클립보드에 저장됩니다. 초대할 성인에게만 보내고 기기나 키보드가 기록을 보관한다면 이후 클립보드 기록을 지워 주세요.';

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
  String get inviteCodeEntryTitle => '초대 코드 입력';

  @override
  String get inviteCodeEntryBody =>
      '가구 Owner에게 받은 8자리 코드를 입력하세요. 초대 확인과 수락에는 인터넷 연결이 필요합니다.';

  @override
  String get inviteCodeLabel => '초대 코드';

  @override
  String get inviteCodeHint => 'ABCD-EFGH';

  @override
  String get inviteCodeValidation => '올바른 8자리 초대 코드를 입력해 주세요.';

  @override
  String get inviteCodeSubmitAction => '초대 확인';

  @override
  String get inviteEnterCodeAction => '초대 코드 입력';

  @override
  String get inviteAnotherCodeAction => '다른 코드 입력';

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
  String get inviteInvalidError => '올바르지 않거나 더 이상 사용할 수 없는 초대입니다.';

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
  String get todayEmptyBody => '함께 사용할 가구가 준비되었습니다. 집안일과 일정을 추가하면 여기에 표시됩니다.';

  @override
  String get todayLoadingLabel => '오늘의 집안일을 불러오는 중입니다';

  @override
  String get todayCreateChoreAction => '첫 집안일 추가';

  @override
  String get todayCreateAnotherChoreAction => '집안일 추가';

  @override
  String todayChoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘 집안일 $count개',
      one: '오늘 집안일 1개',
    );
    return '$_temp0';
  }

  @override
  String todayChoreMetadata(String assigneeName, String dueLabel) {
    return '$assigneeName · $dueLabel';
  }

  @override
  String get todayCalendarSectionTitle => '오늘의 일정';

  @override
  String get todayOverdueSectionTitle => '밀린 집안일';

  @override
  String get todayNowAndNextSectionTitle => '지금·다음 일정';

  @override
  String get todayChoresSectionTitle => '오늘의 집안일';

  @override
  String get todayRemainingEventsSectionTitle => '오늘의 나머지 일정';

  @override
  String get todayCompletedSectionTitle => '오늘 완료한 항목';

  @override
  String get todayCompletedExpandAction => '완료한 집안일 펼치기';

  @override
  String get todayCompletedCollapseAction => '완료한 집안일 접기';

  @override
  String get todayCalendarLoadingLabel => '오늘의 일정을 불러오는 중입니다';

  @override
  String get todayCalendarRefreshingLabel => '오늘의 일정을 새로 불러오는 중입니다';

  @override
  String get todayCalendarEmptyLabel => '오늘 예정된 가구 일정이 없습니다.';

  @override
  String todayCalendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '일정 $count개',
    );
    return '$_temp0';
  }

  @override
  String get todayCalendarHappeningNowLabel => '지금 진행 중';

  @override
  String todayCalendarStaleMessage(String syncLabel) {
    return '$syncLabel에 불러온 일정을 표시합니다. 일정을 새로 고치지 못했습니다.';
  }

  @override
  String todayCalendarOfflineMessage(String syncLabel) {
    return '$syncLabel에 저장한 일정 스냅샷을 표시합니다.';
  }

  @override
  String get todayCalendarOfflineReadOnlyHint =>
      '저장된 일정은 읽기 전용입니다. Today 보기나 가구 일정을 변경하려면 다시 연결한 뒤 새로 고치세요.';

  @override
  String get todayCalendarTruncatedMessage =>
      '오늘 일정이 500개를 넘습니다. 전체 일정은 캘린더에서 확인해 주세요.';

  @override
  String todayCalendarEventSemantics(
    String title,
    String schedule,
    String participants,
  ) {
    return '$title. $schedule. $participants';
  }

  @override
  String get todayOpenCalendarAction => '가구 캘린더 열기';

  @override
  String get todayChoresUnavailableTitle => '집안일을 일시적으로 불러올 수 없습니다';

  @override
  String get todayPartialFailureHint => 'Today의 다른 영역은 계속 사용할 수 있습니다.';

  @override
  String get choreListViewFilterLabel => '집안일 날짜 및 상태 필터';

  @override
  String get choreListAssigneeFilterLabel => '집안일 담당자 필터';

  @override
  String get choreListTodayFilter => '오늘';

  @override
  String get choreListUpcomingFilter => '예정';

  @override
  String get choreListOverdueFilter => '지연';

  @override
  String get choreListCompletedFilter => '완료';

  @override
  String get choreListEveryoneFilter => '모두';

  @override
  String get choreListMeFilter => '나';

  @override
  String choreListBoundaryDate(String dateLabel) {
    return '가구 기준 날짜: $dateLabel';
  }

  @override
  String choreListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '집안일 $count개',
    );
    return '$_temp0';
  }

  @override
  String choreListMetadata(
    String assigneeName,
    String dateLabel,
    String dueLabel,
  ) {
    return '$assigneeName · $dateLabel · $dueLabel';
  }

  @override
  String get choreListRefreshing => '집안일을 새로 불러오는 중입니다';

  @override
  String choreListLastSynced(String syncLabel) {
    return '마지막 업데이트 $syncLabel';
  }

  @override
  String choreListStaleMessage(String syncLabel) {
    return '$syncLabel에 불러온 집안일을 표시합니다. 새로 고치지 못했습니다.';
  }

  @override
  String get choreListStaleUnknown => '마지막으로 불러온 집안일을 표시합니다. 새로 고치지 못했습니다.';

  @override
  String choreListOfflineMessage(String syncLabel) {
    return '$syncLabel에 저장한 집안일을 표시합니다.';
  }

  @override
  String get choreListOfflineReadOnlyHint =>
      '완료 권한이 있는 예정 집안일 한 건은 이 기기에 저장할 수 있습니다. 그 밖의 변경은 다시 연결한 뒤 진행하세요.';

  @override
  String get choreListUpcomingEmptyTitle => '예정된 집안일이 없습니다';

  @override
  String get choreListUpcomingEmptyBody => '앞으로 예정된 집안일이 여기에 표시됩니다.';

  @override
  String get choreListOverdueEmptyTitle => '지연된 집안일이 없습니다';

  @override
  String get choreListOverdueEmptyBody => '이전 날짜의 모든 집안일을 처리했습니다.';

  @override
  String get choreListCompletedEmptyTitle => '완료된 집안일이 아직 없습니다';

  @override
  String get choreListCompletedEmptyBody => '완료한 가구 집안일이 여기에 계속 표시됩니다.';

  @override
  String get choreListLoadingMore => '집안일을 더 불러오는 중입니다';

  @override
  String get choreListLoadMoreAction => '집안일 더 보기';

  @override
  String get choreListLoadMoreFailed =>
      '집안일을 더 불러오지 못했습니다. 이미 표시된 집안일은 그대로 볼 수 있습니다.';

  @override
  String get choreScheduledStatus => '할 일';

  @override
  String get choreCompletedStatus => '완료됨';

  @override
  String get choreMarkCompleteAction => '완료로 표시';

  @override
  String get choreReopenAction => '다시 열기';

  @override
  String get choreCompletionInProgress => '집안일 상태를 변경하는 중입니다';

  @override
  String get choreCompletionQueuedStatus => '동기화 대기 중';

  @override
  String get choreCompletionQueuedMessage =>
      '완료를 이 기기에 저장했습니다. 다시 연결되면 권한을 확인한 뒤 동기화합니다.';

  @override
  String get choreCompletionSyncingMessage => '권한을 확인하고 저장된 완료를 동기화하는 중입니다…';

  @override
  String get choreCompletionPausedMessage =>
      '완료는 저장되어 있지만 현재 앱 정책에 따라 동기화가 일시 중지되었습니다.';

  @override
  String get choreCompletionReconciledMessage => '완료를 최신 가구 데이터와 동기화했습니다.';

  @override
  String get choreCompletionNeedsAttentionMessage =>
      '자동 동기화를 안전하게 중지했습니다. 저장된 완료를 버리고 새로 고친 뒤 온라인에서 다시 완료해 주세요.';

  @override
  String get choreCompletionDiscardedMessage =>
      '집안일 상태나 접근 권한이 변경되어 저장된 완료를 적용하지 못했습니다. 최신 가구 데이터를 표시합니다.';

  @override
  String get choreCompletionExpiredMessage =>
      '동기화되기 전에 저장된 완료가 만료되었습니다. 새로 고친 뒤 온라인에서 다시 완료해 주세요.';

  @override
  String get choreCompletionQueueUnavailableMessage =>
      '이 기기에 완료를 안전하게 저장하지 못했습니다. 다시 연결한 뒤 시도해 주세요.';

  @override
  String get choreCompletionQueueOccupiedMessage =>
      '이 기기에 이미 완료 한 건이 저장되어 있습니다. 다른 완료를 저장하려면 먼저 기존 항목을 버리세요.';

  @override
  String get choreCompletionDiscardAction => '저장된 완료 버리기';

  @override
  String get choreOccurrenceMenuTooltip => '집안일 추가 작업';

  @override
  String get choreSkipOccurrenceAction => '이번 회차 건너뛰기';

  @override
  String get choreSkipOccurrenceDialogTitle => '이번 회차를 건너뛸까요?';

  @override
  String get choreSkipOccurrenceDialogBody =>
      '이 날짜의 회차만 건너뜁니다. 반복 일정과 다른 모든 회차는 변경되지 않습니다.';

  @override
  String get choreSkipOccurrenceConfirmAction => '회차 건너뛰기';

  @override
  String get choreSkipOccurrenceSucceeded => '이번 회차를 건너뛰었습니다.';

  @override
  String get choreRestoreSkippedAction => '되돌리기';

  @override
  String get choreRestoreSkippedSucceeded => '이번 회차를 Today에 다시 표시했습니다.';

  @override
  String get choreRestoreSkippedFailed => '이번 회차를 되돌리지 못했습니다.';

  @override
  String get choreRescheduleOccurrenceAction => '이번 회차 일정 변경';

  @override
  String get choreRescheduleDialogTitle => '이번 회차 일정 변경';

  @override
  String get choreRescheduleDialogBody =>
      '이 회차의 날짜와 시간만 변경합니다. 반복 일정과 다른 모든 회차는 변경되지 않습니다.';

  @override
  String get choreRescheduleConfirmAction => '새 일정 저장';

  @override
  String get choreRescheduleSucceeded => '이번 회차 일정을 변경했습니다.';

  @override
  String get choreReassignOccurrenceAction => '이번 회차 담당자 변경';

  @override
  String get choreReassignDialogTitle => '이번 회차 담당자 변경';

  @override
  String get choreReassignDialogBody =>
      '이 회차의 담당자만 변경합니다. 반복 일정과 다른 모든 회차의 담당자는 변경되지 않습니다.';

  @override
  String get choreReassignConfirmAction => '담당자 저장';

  @override
  String get choreReassignSucceeded => '이번 회차 담당자를 변경했습니다.';

  @override
  String get choreReassignRosterFailed => '가구 구성원을 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get choreEditOneTimeAction => '이 단건 집안일 수정';

  @override
  String get choreDeleteOneTimeAction => '이 단건 집안일 삭제';

  @override
  String get choreEditOneTimeDialogTitle => '단건 집안일 수정';

  @override
  String get choreEditOneTimeDialogBody =>
      '내용, 담당자, 날짜 또는 시간을 변경합니다. 완료한 집안일은 다시 열어야 수정할 수 있습니다.';

  @override
  String get choreEditOneTimeConfirmAction => '변경 사항 저장';

  @override
  String get choreEditOneTimeSucceeded => '단건 집안일을 수정했습니다.';

  @override
  String get choreDeleteOneTimeDialogTitle => '이 단건 집안일을 삭제할까요?';

  @override
  String get choreDeleteOneTimeDialogBody => '집안일 목록에서 제거되며 보호된 이력은 유지됩니다.';

  @override
  String get choreDeleteOneTimeConfirmAction => '집안일 삭제';

  @override
  String get choreDeleteOneTimeSucceeded => '단건 집안일을 삭제했습니다.';

  @override
  String get choreEditSeriesAction => '반복 시리즈 수정';

  @override
  String get choreCancelSeriesAction => '반복 시리즈 취소';

  @override
  String get choreEditSeriesDialogTitle => '반복 시리즈 수정';

  @override
  String get choreEditSeriesDialogBody =>
      '가구 시간대의 오늘부터 변경 사항을 적용합니다. 이전 회차와 완료한 집안일은 그대로 유지됩니다.';

  @override
  String get choreEditSeriesConfirmAction => '시리즈 변경 저장';

  @override
  String get choreEditSeriesSucceeded => '오늘부터 반복 시리즈를 변경했습니다.';

  @override
  String get choreEditSeriesFromOccurrenceAction => '이 회차부터 수정';

  @override
  String get choreEditSeriesFromOccurrenceDialogTitle => '이 회차와 이후 회차 수정';

  @override
  String get choreEditSeriesFromOccurrenceDialogBody =>
      '선택한 회차와 이후 미완료 집안일에 새 시리즈 설정을 적용합니다. 이전 회차와 완료한 집안일은 그대로 유지됩니다. 이후 미완료 회차에 따로 적용한 조정은 새 기본값으로 초기화될 수 있습니다.';

  @override
  String get choreEditSeriesFromOccurrenceConfirmAction => '이 회차부터 변경 저장';

  @override
  String get choreEditSeriesFromOccurrenceSucceeded =>
      '선택한 회차부터 반복 시리즈를 변경했습니다.';

  @override
  String get choreCancelSeriesFromOccurrenceAction => '이 회차부터 취소';

  @override
  String get choreCancelSeriesFromOccurrenceDialogTitle =>
      '이 회차와 이후 회차를 취소할까요?';

  @override
  String get choreCancelSeriesFromOccurrenceDialogBody =>
      '선택한 회차와 이후의 미완료 집안일을 제거합니다. 이전 회차와 완료한 집안일은 그대로 유지됩니다.';

  @override
  String get choreCancelSeriesFromOccurrenceConfirmAction => '이 회차부터 취소';

  @override
  String get choreCancelSeriesFromOccurrenceSucceeded =>
      '선택한 회차부터 반복 시리즈를 취소했습니다.';

  @override
  String get choreCancelSeriesFromOccurrenceUndoAction => '실행 취소';

  @override
  String get choreCancelSeriesFromOccurrenceUndoSucceeded => '반복 시리즈를 복원했습니다.';

  @override
  String get choreCancelSeriesFromOccurrenceUndoFailed =>
      '반복 시리즈를 복원하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get choreCancelSeriesDialogTitle => '이 반복 시리즈를 취소할까요?';

  @override
  String get choreCancelSeriesDialogBody =>
      '오늘 이후의 미완료 회차를 제거합니다. 이전 회차와 완료한 집안일은 그대로 유지됩니다.';

  @override
  String get choreCancelSeriesConfirmAction => '시리즈 취소';

  @override
  String get choreCancelSeriesSucceeded => '오늘부터 반복 시리즈를 취소했습니다.';

  @override
  String get choreDetailsAction => '집안일 상세 및 활동 보기';

  @override
  String get choreDetailsTitle => '집안일 상세';

  @override
  String get choreDetailsCloseTooltip => '집안일 상세 닫기';

  @override
  String get choreDetailsCurrentHeading => '현재 정보';

  @override
  String get choreTargetLoading => '최신 집안일 정보를 불러오는 중입니다';

  @override
  String get choreTargetUnavailableTitle => '이 집안일을 열 수 없습니다';

  @override
  String get choreTargetUnavailableBody =>
      '내용이 변경 또는 삭제되었거나 현재 가구에서 더 이상 볼 수 없을 수 있습니다.';

  @override
  String get choreTargetLoadFailedTitle => '집안일 정보를 불러오지 못했습니다';

  @override
  String get choreTargetLoadFailedBody =>
      '연결을 확인하고 다시 시도해 주세요. 이 화면에는 캐시된 집안일 정보를 표시하지 않습니다.';

  @override
  String get choreTargetNotificationsAction => '알림 열기';

  @override
  String get choreTargetChoresAction => '집안일 열기';

  @override
  String get choreHistoryHeading => '활동 내역';

  @override
  String get choreHistoryLoading => '집안일 활동을 불러오는 중입니다';

  @override
  String get choreHistoryEmptyTitle => '아직 활동 내역이 없습니다';

  @override
  String get choreHistoryEmptyBody => '이 회차를 변경하면 여기에 표시됩니다.';

  @override
  String get choreHistoryLoadFailed => '집안일 활동을 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get choreHistoryLoadMoreAction => '이전 활동 더 보기';

  @override
  String get choreHistoryLoadingMore => '이전 활동을 불러오는 중입니다';

  @override
  String get choreHistoryLoadMoreFailed => '이전 활동을 불러오지 못했습니다.';

  @override
  String choreHistoryActorActingAs(String actorName, String actingName) {
    return '$actingName님을 대신한 $actorName';
  }

  @override
  String choreHistoryCompleted(String actorName) {
    return '$actorName님이 이 집안일을 완료했습니다.';
  }

  @override
  String choreHistoryReopened(String actorName) {
    return '$actorName님이 이 집안일을 다시 열었습니다.';
  }

  @override
  String choreHistorySkipped(String actorName) {
    return '$actorName님이 이번 회차를 건너뛰었습니다.';
  }

  @override
  String choreHistoryRestored(String actorName) {
    return '$actorName님이 이번 회차를 복원했습니다.';
  }

  @override
  String choreHistoryRescheduled(
    String actorName,
    String previousSchedule,
    String newSchedule,
  ) {
    return '$actorName님이 일정을 $previousSchedule에서 $newSchedule(으)로 변경했습니다.';
  }

  @override
  String choreHistoryReassigned(
    String actorName,
    String previousAssignee,
    String newAssignee,
  ) {
    return '$actorName님이 담당자를 $previousAssignee님에서 $newAssignee님으로 변경했습니다.';
  }

  @override
  String choreHistoryTimestamp(String date, String time) {
    return '$date · $time';
  }

  @override
  String choreScheduleLabel(String date, String time) {
    return '$date · $time';
  }

  @override
  String get choreCreateTitle => '집안일 추가';

  @override
  String get choreCreateHeading => '집안일 일정 정하기';

  @override
  String get choreCreateBody => '담당할 성인, 첫 마감일과 반복 여부를 선택하세요.';

  @override
  String get choreTemplatesHeading => '빠른 시작';

  @override
  String get choreTemplatesBody =>
      '제목과 반복 주기를 채울 항목을 선택하세요. 모든 내용은 수정할 수 있습니다.';

  @override
  String get choreTemplateSearchLabel => '빠른 시작 검색';

  @override
  String get choreTemplateSearchClearAction => '템플릿 검색 지우기';

  @override
  String get choreTemplateCategoryAll => '전체';

  @override
  String get choreTemplateCategoryKitchen => '주방';

  @override
  String get choreTemplateCategoryCleaning => '청소';

  @override
  String get choreTemplateCategoryLaundry => '세탁';

  @override
  String get choreTemplateCategoryHomeCare => '집 관리';

  @override
  String get choreTemplateCategoryPetCare => '반려동물';

  @override
  String get choreTemplateNoResults => '검색과 분류에 맞는 빠른 시작이 없습니다.';

  @override
  String get choreTemplateDishes => '설거지';

  @override
  String get choreTemplateKitchenReset => '주방 정리';

  @override
  String get choreTemplateLaundry => '세탁';

  @override
  String get choreTemplateVacuuming => '청소기 돌리기';

  @override
  String get choreTemplateBathroomCleaning => '욕실 청소';

  @override
  String get choreTemplateTrashAndRecycling => '쓰레기와 재활용품 버리기';

  @override
  String get choreTemplateWipeCounters => '조리대 닦기';

  @override
  String get choreTemplateFridgeCleanout => '냉장고 정리';

  @override
  String get choreTemplateMopFloors => '바닥 물걸레질';

  @override
  String get choreTemplateDusting => '먼지 닦기';

  @override
  String get choreTemplateChangeBedLinen => '침구 교체';

  @override
  String get choreTemplateFoldClothes => '옷 개기';

  @override
  String get choreTemplateMakeBeds => '침대 정리';

  @override
  String get choreTemplateWaterPlants => '식물 물주기';

  @override
  String get choreTemplateFeedPets => '반려동물 밥 주기';

  @override
  String get choreTemplateCleanPetArea => '반려동물 공간 청소';

  @override
  String get guidedChoreSetupTitle => '첫 집안일 설정';

  @override
  String get guidedChoreSetupHeading => '함께 시작할 집안일 세 개 고르기';

  @override
  String get guidedChoreSetupBody =>
      '작은 공유 목록을 만들면 Today를 바로 활용할 수 있습니다. 집안일을 정확히 세 개 고른 뒤 추가하기 전에 확인하세요.';

  @override
  String get guidedChoreSetupLoading => '가구의 집안일 추천을 준비하는 중';

  @override
  String get guidedChoreSetupResumeNotice =>
      '저장된 설정을 복원했습니다. 마지막으로 확인된 집안일부터 안전하게 이어서 진행합니다.';

  @override
  String guidedChoreSetupSelectionProgress(int selected, int required) {
    return '$required개 중 $selected개 선택';
  }

  @override
  String guidedChoreSetupAddingProgress(int completed, int total) {
    return '집안일 $total개 중 $completed개 추가됨';
  }

  @override
  String guidedChoreSetupDefaultsBody(String startDate, String timezone) {
    return '내 담당으로 지정되고, $timezone 기준 $startDate부터 시간 지정 없이 반복됩니다. 나중에 다시 수정할 수 있습니다.';
  }

  @override
  String get guidedChoreSetupChooseBody =>
      '추천 항목을 정확히 세 개 고르세요. 선택한 제목과 반복 주기는 수정할 수 있습니다.';

  @override
  String get guidedChoreSetupReviewHeading => '집안일 세 개 확인';

  @override
  String get guidedChoreSetupAddAction => '집안일 3개 추가';

  @override
  String get guidedChoreSetupRetryAction => '남은 집안일 계속 추가';

  @override
  String get guidedChoreSetupSkipAction => '나중에 설정';

  @override
  String get guidedChoreSetupExitTitle => '빠른 설정을 나갈까요?';

  @override
  String get guidedChoreSetupExitBody =>
      'Today에서 나중에 집안일을 추가할 수 있습니다. 지금 빠른 설정을 나갈까요?';

  @override
  String guidedChoreSetupPartialExitBody(int completed) {
    return '지금까지 $completed개를 추가했습니다. 추가된 집안일은 가구에 남고 나머지는 나중에 만들 수 있습니다. Today로 이동할까요?';
  }

  @override
  String get guidedChoreSetupStayAction => '계속 설정';

  @override
  String get guidedChoreSetupContinueTodayAction => 'Today로 이동';

  @override
  String get choreTitleLabel => '집안일';

  @override
  String get choreTitleValidation => '집안일 이름을 입력해 주세요.';

  @override
  String get choreDescriptionLabel => '메모(선택)';

  @override
  String get choreAssigneeLabel => '담당자';

  @override
  String choreAssigneeYou(String memberName) {
    return '$memberName (나)';
  }

  @override
  String get choreRecurrenceLabel => '반복';

  @override
  String get choreRecurrenceOnce => '반복 안 함';

  @override
  String get choreRecurrenceDaily => '매일';

  @override
  String get choreRecurrenceWeekly => '매주';

  @override
  String get choreRecurrenceMonthly => '매월';

  @override
  String choreRecurrenceSummary(String pattern, String startDate) {
    return '$startDate부터 $pattern 반복합니다. 이후 날짜는 가구 시간대를 기준으로 생성됩니다.';
  }

  @override
  String get choreRecurrenceWeekdaysLabel => '반복 요일';

  @override
  String get choreRecurrenceWeekdayCreationAnchorHelper =>
      '집안일 시작일의 요일은 항상 선택되어야 합니다.';

  @override
  String get choreRecurrenceWeekdayMinimumHelper => '반복 요일을 하나 이상 선택해 주세요.';

  @override
  String get choreRecurrenceWeekdayMonday => '월요일';

  @override
  String get choreRecurrenceWeekdayTuesday => '화요일';

  @override
  String get choreRecurrenceWeekdayWednesday => '수요일';

  @override
  String get choreRecurrenceWeekdayThursday => '목요일';

  @override
  String get choreRecurrenceWeekdayFriday => '금요일';

  @override
  String get choreRecurrenceWeekdaySaturday => '토요일';

  @override
  String get choreRecurrenceWeekdaySunday => '일요일';

  @override
  String choreRecurrenceWeekdaysSummary(String weekdays) {
    return '$weekdays에 반복합니다.';
  }

  @override
  String get choreRecurrenceMonthDayLabel => '매월 반복일';

  @override
  String choreRecurrenceMonthDayOption(int day) {
    return '매월 $day일';
  }

  @override
  String get choreRecurrenceMonthDayCreationAnchorHelper =>
      '첫 예정일의 날짜가 매월 반복일로 설정됩니다.';

  @override
  String get choreRecurrenceMonthDayMissingDateHelper =>
      '해당 날짜가 없는 달은 말일로 옮기지 않고 건너뜁니다.';

  @override
  String choreRecurrenceMonthDaySummary(int day) {
    return '매월 $day일에 반복합니다.';
  }

  @override
  String get choreRecurrenceIntervalLabel => '반복 간격';

  @override
  String get choreRecurrenceIntervalHelper => '1에서 30 사이의 정수를 입력하세요.';

  @override
  String get choreRecurrenceIntervalValidation => '1에서 30 사이의 숫자를 입력해 주세요.';

  @override
  String get choreRecurrenceEndLabel => '반복 종료';

  @override
  String get choreRecurrenceEndNever => '종료하지 않음';

  @override
  String get choreRecurrenceEndAfterCount => '횟수만큼 반복한 뒤';

  @override
  String get choreRecurrenceEndOnDate => '날짜에 종료';

  @override
  String get choreRecurrenceCountLabel => '반복 횟수';

  @override
  String get choreRecurrenceCountHelper => '1에서 1,000 사이의 정수를 입력하세요.';

  @override
  String get choreRecurrenceCountValidation => '1에서 1,000 사이의 숫자를 입력해 주세요.';

  @override
  String get choreRecurrenceUntilDateLabel => '종료 날짜';

  @override
  String get choreRecurrenceInvalidSummary => '반복 설정을 확인해 주세요.';

  @override
  String choreRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval일마다',
      one: '매일',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval주마다',
      one: '매주',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval개월마다',
      one: '매월',
    );
    return '$_temp0';
  }

  @override
  String get choreRecurrenceEndNeverSummary => '이 반복 시리즈는 종료 날짜가 없습니다.';

  @override
  String choreRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회 반복한 뒤 종료합니다.',
      one: '1회 반복한 뒤 종료합니다.',
    );
    return '$_temp0';
  }

  @override
  String choreRecurrenceEndUntilSummary(String date) {
    return '$date에 종료합니다.';
  }

  @override
  String get choreDueDateLabel => '마감일';

  @override
  String get choreDueTimeLabel => '마감 시간';

  @override
  String get choreAllDayLabel => '시간 지정 없음';

  @override
  String get choreClearTimeAction => '마감 시간 지우기';

  @override
  String get choreCreateAction => '집안일 추가';

  @override
  String get choreCreatingAction => '집안일을 추가하는 중';

  @override
  String get choreCreatedBody => '가구에 집안일을 추가했습니다.';

  @override
  String get choreCreateInvalidError => '집안일 내용을 확인하고 다시 시도해 주세요.';

  @override
  String get choreRecurrenceInvalidError =>
      '지원하지 않는 반복 일정입니다. 내용을 확인하고 다시 시도해 주세요.';

  @override
  String get chorePermissionError =>
      '이 가구 또는 담당자를 더 이상 사용할 수 없습니다. 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get choreCreateConflictError =>
      '재시도 중 집안일 내용이 변경되었습니다. 내용을 확인하고 다시 제출해 주세요.';

  @override
  String get choreActionConflictError =>
      '재시도 중 집안일 작업이 변경되었습니다. 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get choreVersionConflictError =>
      '이 집안일이 다른 곳에서 변경되었습니다. 가구의 최신 상태를 표시했습니다.';

  @override
  String get choreTransitionConflictError =>
      '현재 집안일 상태에는 이 작업을 적용할 수 없습니다. 최신 상태를 표시했습니다.';

  @override
  String get choreGenericError => '집안일을 불러오거나 저장하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get choreOfflineReadOnlyError =>
      '저장된 화면은 읽기 전용입니다. 변경하려면 다시 연결한 뒤 새로 고치세요.';

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

  @override
  String get choresNavigationLabel => '집안일';

  @override
  String get calendarNavigationLabel => '일정';

  @override
  String get familyNavigationLabel => '가족';

  @override
  String get settingsNavigationLabel => '설정';

  @override
  String get calendarTitle => '캘린더';

  @override
  String get calendarTodayAction => '오늘로 돌아가기';

  @override
  String get calendarLoadingLabel => '가구 일정을 불러오는 중입니다';

  @override
  String get calendarEmptyTitle => '아직 일정이 없습니다';

  @override
  String get calendarEmptyBody => '가구의 시간 일정이나 종일 계획을 추가하세요.';

  @override
  String get calendarCreateAction => '일정 추가';

  @override
  String get calendarImportAction => '.ics 가져오기';

  @override
  String get calendarImportTitle => '캘린더 파일 가져오기';

  @override
  String get calendarImportIntro =>
      'UTF-8 .ics 파일 하나를 선택하고 지원되는 일정을 검토한 뒤 선택한 일정만 이 가구에 복사하세요.';

  @override
  String get calendarImportCopyDisclosure =>
      '한 번 복사하는 기능이며 동기화가 아닙니다. 같은 파일을 다시 가져오면 일정이 중복될 수 있고 이후 외부 변경은 반영되지 않습니다.';

  @override
  String get calendarImportChooseFileAction => '.ics 파일 선택';

  @override
  String get calendarImportChooseAnotherAction => '다른 파일 선택';

  @override
  String get calendarImportBackAction => '가져오기 닫기';

  @override
  String get calendarImportPickingLabel => '안전한 문서 선택기를 여는 중입니다';

  @override
  String get calendarImportRosterLoading => '활성 가구 구성원을 불러오는 중입니다';

  @override
  String calendarImportSupportedCount(int count) {
    return '지원 일정: $count개';
  }

  @override
  String calendarImportSkippedCount(int count) {
    return '건너뛴 일정: $count개';
  }

  @override
  String calendarImportSkippedDetails(
    int invalid,
    int unsupported,
    int duplicate,
  ) {
    return '유효하지 않음 $invalid · 미지원 $unsupported · 파일 내 중복 $duplicate';
  }

  @override
  String get calendarImportIgnoredFieldsDisclosure =>
      '장소, 링크, 주최자, 참석자, 첨부 파일, 알람은 복사하거나 열지 않습니다.';

  @override
  String calendarImportFloatingDisclosure(String timeZone) {
    return '시간대가 없는 일정은 가구 시간대 $timeZone을 사용합니다.';
  }

  @override
  String get calendarImportOverlapDisclosure =>
      '시계가 반복되는 시간은 더 이른 유효 시각을 사용합니다.';

  @override
  String get calendarImportEventsHeading => '복사할 일정';

  @override
  String calendarImportSelectedCount(int selected, int total) {
    return '전체 $total개 중 $selected개 선택';
  }

  @override
  String get calendarImportNoSupportedEvents =>
      'KinFlow가 복사할 수 있는 일정이 없습니다. 미지원 또는 유효하지 않은 일정은 원본 파일에 그대로 남습니다.';

  @override
  String get calendarImportParticipantsHeading => '복사할 일정의 참석자';

  @override
  String get calendarImportParticipantsHelper =>
      '선택한 모든 일정에 같은 활성 가구 구성원이 추가됩니다.';

  @override
  String calendarImportAllDayRange(String startDate, String endDate) {
    return '종일 · $startDate~$endDate';
  }

  @override
  String calendarImportTimedSummary(
    String date,
    String time,
    String duration,
    String timeZone,
  ) {
    return '$date · $time · $duration · $timeZone';
  }

  @override
  String calendarImportSubmitAction(int count) {
    return '선택한 일정 $count개 복사';
  }

  @override
  String calendarImportProgress(int completed, int total) {
    return '일정 $total개 중 $completed개 복사함';
  }

  @override
  String calendarImportPartialFailure(int completed, int total) {
    return '$total개 중 $completed개를 복사했습니다. 다음 일정은 복사되지 않았습니다.';
  }

  @override
  String get calendarImportRetryAction => '남은 일정 다시 시도';

  @override
  String calendarImportSuccess(int count) {
    return '가구 캘린더에 일정 $count개를 복사했습니다.';
  }

  @override
  String get calendarImportPickerUnavailableError =>
      '이 앱 빌드에서는 문서 선택기를 사용할 수 없습니다.';

  @override
  String get calendarImportPickerFailedError =>
      '선택한 파일을 안전하게 읽지 못했습니다. 다시 선택하거나 다른 .ics 파일을 사용하세요.';

  @override
  String get calendarImportInvalidFileError =>
      '지원되는 유효한 iCalendar 파일이 아닙니다. 원본 파일은 변경되지 않았습니다.';

  @override
  String get calendarImportUnsupportedVersionError =>
      '이 파일에는 iCalendar 2.0 캘린더가 정확히 하나 있어야 합니다.';

  @override
  String get calendarImportTooLargeError => '256 KiB 이하의 .ics 파일을 선택하세요.';

  @override
  String get calendarImportTooManyEventsError => '일정이 50개 이하인 .ics 파일을 선택하세요.';

  @override
  String get calendarEditAction => '일정 수정';

  @override
  String get calendarDeleteAction => '일정 삭제';

  @override
  String get calendarOccurrenceEditAction => '이번 회차 수정';

  @override
  String get calendarOccurrenceCancelAction => '이번 회차 취소';

  @override
  String get calendarOccurrenceModifiedLabel => '수정된 회차';

  @override
  String get calendarSeriesMenuTooltip => '반복 일정 작업';

  @override
  String get calendarSeriesEditAction => '반복 일정 전체 수정';

  @override
  String get calendarSeriesEditFromOccurrenceAction => '이 회차부터 수정';

  @override
  String get calendarSeriesCancelFromOccurrenceAction => '이 회차부터 취소';

  @override
  String get calendarSeriesCancelAction => '반복 일정 전체 종료';

  @override
  String calendarHouseholdTimeZone(String timeZone) {
    return '가구 시간대: $timeZone';
  }

  @override
  String calendarTimedSchedule(String date, String time, String duration) {
    return '$date · $time · $duration';
  }

  @override
  String calendarAllDaySingle(String date) {
    return '종일 · $date';
  }

  @override
  String calendarAllDayRange(String startDate, String endDate) {
    return '종일 · $startDate~$endDate';
  }

  @override
  String calendarParticipantSummary(String names) {
    return '함께: $names';
  }

  @override
  String get calendarEditorCreateTitle => '일정 추가';

  @override
  String get calendarEditorEditTitle => '일정 수정';

  @override
  String get calendarOccurrenceEditorEditTitle => '이번 회차 수정';

  @override
  String get calendarSeriesEditorEditTitle => '반복 일정 전체 수정';

  @override
  String get calendarSeriesEditFromOccurrenceEditorTitle => '이 회차와 이후 일정 수정';

  @override
  String get calendarSeriesEditFromOccurrenceEditorBody =>
      '선택한 회차와 이후 반복 일정에 새 설정을 적용합니다. 이전 회차와 기존 한 회차 수정은 그대로 유지됩니다.';

  @override
  String get calendarTitleLabel => '일정 제목';

  @override
  String get calendarTitleValidation => '일정 제목을 입력해 주세요.';

  @override
  String get calendarDescriptionLabel => '메모(선택)';

  @override
  String get calendarAllDayLabel => '종일 일정';

  @override
  String get calendarStartDateLabel => '시작일';

  @override
  String get calendarEndDateLabel => '종료일';

  @override
  String get calendarStartTimeLabel => '시작 시간';

  @override
  String get calendarDurationLabel => '소요 시간';

  @override
  String calendarDurationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String calendarTimeZoneLabel(String timeZone) {
    return '시간대: $timeZone';
  }

  @override
  String get calendarOverlapLabel => '시계가 반복되는 시간';

  @override
  String get calendarOverlapEarlier => '앞의 시각 사용';

  @override
  String get calendarOverlapLater => '뒤의 시각 사용';

  @override
  String get calendarParticipantsLabel => '참여자';

  @override
  String get calendarParticipantValidation => '활성 가구 구성원을 한 명 이상 선택해 주세요.';

  @override
  String get calendarCancelAction => '취소';

  @override
  String get calendarSaveAction => '일정 저장';

  @override
  String get calendarDeleteTitle => '이 일정을 삭제할까요?';

  @override
  String calendarDeleteBody(String title) {
    return '가구 캘린더에서 ‘$title’ 일정을 삭제합니다.';
  }

  @override
  String get calendarDeleteConfirmAction => '삭제';

  @override
  String get calendarOccurrenceCancelTitle => '이번 회차를 취소할까요?';

  @override
  String calendarOccurrenceCancelBody(String title) {
    return '‘$title’ 일정의 이번 회차만 취소합니다. 나머지 반복 일정은 그대로 유지됩니다.';
  }

  @override
  String get calendarOccurrenceCancelConfirmAction => '이번 회차 취소';

  @override
  String get calendarSeriesCancelTitle => '이 반복 일정을 종료할까요?';

  @override
  String calendarSeriesCancelBody(String title) {
    return '‘$title’ 일정의 오늘 회차부터 이후 회차까지 취소합니다. 지난 회차는 캘린더 기록에 그대로 남습니다.';
  }

  @override
  String get calendarSeriesCancelConfirmAction => '반복 일정 종료';

  @override
  String get calendarSeriesCancelFromOccurrenceTitle => '이 회차부터 반복 일정을 취소할까요?';

  @override
  String calendarSeriesCancelFromOccurrenceBody(String title) {
    return '‘$title’의 선택한 반복 회차와 이후 반복 회차를 취소합니다. 이전 반복 회차는 나중 날짜로 옮겨졌더라도 그대로 유지됩니다. 선택한 회차부터 적용된 기존 한 회차 수정도 함께 취소됩니다.';
  }

  @override
  String get calendarSeriesCancelFromOccurrenceConfirmAction => '이 회차부터 취소';

  @override
  String get calendarSeriesCancelFromOccurrenceSucceeded =>
      '선택한 회차부터 반복 일정을 취소했습니다.';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoAction => '실행 취소';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoSucceeded =>
      '반복 일정을 복원했습니다.';

  @override
  String get calendarSeriesCancelFromOccurrenceUndoFailed =>
      '반복 일정을 복원하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get calendarRosterError => '가구 참여자를 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get calendarInvalidError => '일정 내용을 확인하고 다시 시도해 주세요.';

  @override
  String get calendarPermissionError =>
      '이 가구, 일정 또는 참여자를 더 이상 사용할 수 없습니다. 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get calendarRetryConflictError =>
      '재시도 중 일정 작업이 변경되었습니다. 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get calendarVersionConflictError =>
      '이 일정이 다른 곳에서 변경되었습니다. 최신 캘린더를 불러온 뒤 다시 시도해 주세요.';

  @override
  String get calendarNonexistentTimeError =>
      '시계가 바뀌어 존재하지 않는 현지 시각입니다. 다른 시간을 선택해 주세요.';

  @override
  String get calendarOccurrenceTransitionError =>
      '이 회차는 더 이상 변경할 수 없습니다. 최신 캘린더를 불러온 뒤 다시 시도해 주세요.';

  @override
  String get calendarAgendaView => '일정';

  @override
  String get calendarDayView => '일';

  @override
  String get calendarMonthView => '월';

  @override
  String get calendarPreviousRangeAction => '이전 기간';

  @override
  String get calendarNextRangeAction => '다음 기간';

  @override
  String get calendarGoToTodayAction => '오늘로 이동';

  @override
  String calendarDateRange(String startDate, String endDate) {
    return '$startDate – $endDate';
  }

  @override
  String calendarSelectedDateHeading(String date) {
    return '$date 일정';
  }

  @override
  String get calendarNoEventsInView => '이 기간에는 일정이 없습니다.';

  @override
  String get calendarLoadMoreAction => '일정 더 불러오기';

  @override
  String get calendarLoadMoreError => '일정을 더 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get calendarAllDayChip => '종일';

  @override
  String get calendarRecurrenceLabel => '반복';

  @override
  String get calendarRecurrenceOnce => '반복 안 함';

  @override
  String get calendarRecurrenceDaily => '매일';

  @override
  String get calendarRecurrenceWeekly => '매주';

  @override
  String get calendarRecurrenceMonthly => '매월';

  @override
  String get calendarRecurrenceWeekdaysLabel => '반복 요일';

  @override
  String get calendarRecurrenceWeekdayAnchorHelper =>
      '일정 시작일의 요일은 항상 선택되어야 합니다.';

  @override
  String get calendarRecurrenceWeekdayMonday => '월요일';

  @override
  String get calendarRecurrenceWeekdayTuesday => '화요일';

  @override
  String get calendarRecurrenceWeekdayWednesday => '수요일';

  @override
  String get calendarRecurrenceWeekdayThursday => '목요일';

  @override
  String get calendarRecurrenceWeekdayFriday => '금요일';

  @override
  String get calendarRecurrenceWeekdaySaturday => '토요일';

  @override
  String get calendarRecurrenceWeekdaySunday => '일요일';

  @override
  String calendarRecurrenceWeekdaysSummary(String weekdays) {
    return '$weekdays에 반복합니다.';
  }

  @override
  String calendarRecurrenceWeeklySummary(String pattern, String weekdays) {
    return '$weekdays에 $pattern 반복';
  }

  @override
  String get calendarRecurrenceMonthDayLabel => '월 기준일';

  @override
  String calendarRecurrenceMonthDayOption(int day) {
    return '매월 $day일';
  }

  @override
  String get calendarRecurrenceMonthDayAnchorHelper => '일정 시작일이 이 날짜를 정합니다.';

  @override
  String get calendarRecurrenceMonthDayMissingDateHelper =>
      '해당 날짜가 없는 달은 마지막 날로 옮기지 않고 건너뜁니다.';

  @override
  String calendarRecurrenceMonthDaySummary(int day) {
    return '매월 $day일에 반복합니다.';
  }

  @override
  String calendarRecurrenceMonthlySummary(String pattern, int day) {
    return '$pattern $day일에 반복';
  }

  @override
  String get calendarRecurrenceIntervalLabel => '반복 간격';

  @override
  String get calendarRecurrenceIntervalHelper => '1에서 30 사이의 정수를 입력하세요.';

  @override
  String get calendarRecurrenceIntervalValidation => '1에서 30 사이의 숫자를 입력해 주세요.';

  @override
  String get calendarRecurrenceEndLabel => '반복 종료';

  @override
  String get calendarRecurrenceEndNever => '종료하지 않음';

  @override
  String get calendarRecurrenceEndAfterCount => '횟수만큼 반복한 뒤';

  @override
  String get calendarRecurrenceEndOnDate => '날짜에 종료';

  @override
  String get calendarRecurrenceCountLabel => '반복 횟수';

  @override
  String get calendarRecurrenceCountHelper => '1에서 1,000 사이의 정수를 입력하세요.';

  @override
  String get calendarRecurrenceCountValidation => '1에서 1,000 사이의 숫자를 입력해 주세요.';

  @override
  String get calendarRecurrenceUntilDateLabel => '마지막 반복 날짜';

  @override
  String calendarRecurrenceEveryDays(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval일마다',
      one: '매일',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryWeeks(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval주마다',
      one: '매주',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEveryMonths(int interval) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: '$interval개월마다',
      one: '매월',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEditorSummary(String pattern, String startDate) {
    return '$startDate부터 $pattern';
  }

  @override
  String get calendarRecurrenceInvalidSummary => '지원되는 반복 값을 모두 입력해 주세요.';

  @override
  String get calendarRecurrenceEndNeverSummary => '이 반복 시리즈는 종료 날짜가 없습니다.';

  @override
  String calendarRecurrenceEndCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회 반복한 뒤 종료합니다.',
      one: '1회 반복한 뒤 종료합니다.',
    );
    return '$_temp0';
  }

  @override
  String calendarRecurrenceEndUntilSummary(String date) {
    return '$date에 종료합니다.';
  }

  @override
  String calendarRecurrenceSummary(String pattern) {
    return '$pattern 반복';
  }

  @override
  String calendarMonthDateSemantics(String date, int count) {
    return '$date, 일정 $count개';
  }

  @override
  String get calendarGenericError =>
      '캘린더 일정을 불러오거나 저장하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get calendarTargetUnavailableTitle => '일정을 사용할 수 없음';

  @override
  String get calendarTargetUnavailableMessage =>
      '이 일정은 삭제 또는 취소되었거나 이 가구에서 더 이상 볼 수 없습니다.';

  @override
  String get calendarBackToCalendarAction => '캘린더 열기';

  @override
  String get calendarLiveDisconnectedMessage =>
      '실시간 업데이트가 중단되었습니다. 마지막으로 불러온 캘린더가 최신이 아닐 수 있습니다.';

  @override
  String get calendarReconnectAction => '다시 연결';

  @override
  String get choreLiveDisconnectedMessage =>
      '실시간 집안일 업데이트가 중단되었습니다. 마지막으로 불러온 집안일이 최신이 아닐 수 있습니다.';

  @override
  String get choreReconnectAction => '집안일 업데이트 다시 연결';

  @override
  String get notificationLiveDisconnectedMessage =>
      '실시간 알림함 업데이트가 중단되었습니다. 마지막으로 불러온 알림과 읽지 않은 개수가 최신이 아닐 수 있습니다.';

  @override
  String get notificationReconnectAction => '알림 업데이트 다시 연결';

  @override
  String get calendarConflictLatestReloadedMessage =>
      '다른 곳에서 일정이 변경되었습니다. 최신 캘린더를 불러왔으니 확인한 뒤 다시 시도해 주세요.';

  @override
  String get calendarConflictTargetUnavailableMessage =>
      '다른 곳에서 일정이 변경되거나 삭제되었습니다. 최신 캘린더를 불러왔습니다.';

  @override
  String get calendarScheduleOverlapHeading => '일정 겹침 힌트';

  @override
  String get calendarScheduleOverlapChecking => '가구 일정과 겹치는지 확인하는 중입니다…';

  @override
  String get calendarScheduleOverlapNone =>
      '확인한 범위에서 같은 구성원의 겹치는 일정을 찾지 못했습니다.';

  @override
  String get calendarScheduleOverlapUnavailable =>
      '일정 겹침을 확인하지 못했습니다. 저장은 가능하지만 먼저 가구 캘린더를 확인해 주세요.';

  @override
  String get calendarScheduleOverlapSaveAllowed => '참고용 힌트이며 저장을 막지 않습니다.';

  @override
  String calendarScheduleOverlapSummary(
    int total,
    int candidateCount,
    String fromDate,
    String throughDate,
  ) {
    return '$fromDate부터 $throughDate까지 후보 $candidateCount회에서 겹침 $total건을 찾았습니다.';
  }

  @override
  String calendarScheduleOverlapTruncated(int limit) {
    return '처음 $limit건만 표시합니다.';
  }

  @override
  String calendarScheduleOverlapCandidateDate(String date) {
    return '후보 회차: $date';
  }

  @override
  String get notificationTitle => '알림';

  @override
  String get notificationOpenAction => '알림 열기';

  @override
  String get notificationLoadingLabel => '알림을 불러오는 중입니다';

  @override
  String get notificationInboxHeading => '알림함';

  @override
  String notificationUnreadBadge(int count) {
    return '읽지 않음 $count개';
  }

  @override
  String notificationBadgeSemantics(int count) {
    return '읽지 않은 알림 $count개';
  }

  @override
  String get notificationMarkAllReadAction => '모두 읽음';

  @override
  String get notificationEmptyTitle => '새 알림이 없습니다';

  @override
  String get notificationEmptyBody => '푸시를 전달할 수 없을 때도 집안일과 일정 알림이 여기에 보관됩니다.';

  @override
  String get notificationChoreDueLabel => '집안일 기한 변경';

  @override
  String get notificationChoreAssignmentLabel => '집안일 담당 변경';

  @override
  String get notificationCalendarEventLabel => '일정 시작 알림';

  @override
  String get notificationItemBody => '오늘 화면을 열어 현재 권한으로 최신 가구 내용을 안전하게 불러옵니다.';

  @override
  String notificationCreatedSchedule(String date, String time) {
    return '수신 $date · $time';
  }

  @override
  String get notificationSnoozeAction => '다시 알림';

  @override
  String get notificationSnoozeSheetTitle => '언제 다시 알릴까요?';

  @override
  String get notificationSnoozeSheetBody =>
      '선택한 시간이 되면 알림함에 다시 표시하고, 모바일 푸시가 켜져 있으면 다시 전송합니다.';

  @override
  String notificationSnoozeMinutesAction(int minutes) {
    return '$minutes분 후';
  }

  @override
  String notificationSnoozeSucceeded(int minutes) {
    return '$minutes분 후 다시 알리도록 설정했습니다.';
  }

  @override
  String notificationSnoozeCount(int count) {
    return '다시 알림 $count/3회';
  }

  @override
  String get notificationOpenTodayAction => '오늘 열기';

  @override
  String get notificationLoadMoreAction => '알림 더 불러오기';

  @override
  String get notificationLoadMoreError => '알림을 더 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get notificationSettingsHeading => '알림 설정';

  @override
  String get notificationSettingsBody =>
      '종류별 채널과 현재 IANA 시간대의 방해 금지 시간을 설정하세요. 방해 금지 시간은 향후 푸시와 이메일 전송만 늦추며 이 알림함은 지연하지 않습니다.';

  @override
  String get notificationInAppLabel => '앱 내 알림함';

  @override
  String get notificationInAppBody => '이 알림함에 항목을 계속 보관합니다.';

  @override
  String get notificationNativePushLabel => '모바일 푸시';

  @override
  String get notificationNativePushBody => '지금 설정을 저장하며 기기를 등록한 뒤부터 전달됩니다.';

  @override
  String get notificationEmailLabel => '계정 이메일';

  @override
  String get notificationEmailBody =>
      '확인된 계정 이메일로 일반적인 알림을 보냅니다. 가족 세부정보는 포함하지 않으며 전송에 실패해도 이 알림함은 계속 사용할 수 있습니다.';

  @override
  String get notificationQuietHoursLabel => '방해 금지 시간';

  @override
  String notificationQuietHoursOff(String timezone) {
    return '사용 안 함 · $timezone';
  }

  @override
  String notificationQuietHoursSummary(
    String start,
    String end,
    String timezone,
  ) {
    return '$start–$end · $timezone';
  }

  @override
  String get notificationReminderLeadLabel => '미리 알림';

  @override
  String get notificationReminderLeadBody => '아직 전달되지 않은 일정 알림에만 변경 사항이 적용됩니다.';

  @override
  String get notificationReminderLeadAtStart => '일정 시간에';

  @override
  String notificationReminderLeadMinutesBefore(int minutes) {
    return '$minutes분 전';
  }

  @override
  String get notificationAdditionalRemindersLabel => '추가 알림';

  @override
  String get notificationAdditionalRemindersBody =>
      '시간을 최대 2개 더 선택할 수 있습니다. 각 알림은 별도로 전달됩니다.';

  @override
  String get notificationEditAction => '수정';

  @override
  String notificationEditorTitle(String category) {
    return '$category 설정';
  }

  @override
  String get notificationQuietEnabledLabel => '방해 금지 시간 사용';

  @override
  String get notificationQuietStartLabel => '시작';

  @override
  String get notificationQuietEndLabel => '종료';

  @override
  String get notificationTimezoneLabel => 'IANA 시간대';

  @override
  String get notificationTimezoneHint => 'Asia/Seoul 같은 IANA 지역이나 도시를 선택하세요.';

  @override
  String get notificationTimezonePickerTitle => '알림 시간대 선택';

  @override
  String get notificationTimezoneValidation =>
      '올바른 IANA 시간대와 서로 다른 시작·종료 시간을 선택해 주세요.';

  @override
  String get notificationSaveAction => '설정 저장';

  @override
  String get notificationCancelAction => '취소';

  @override
  String get notificationInvalidInputError => '알림 설정을 확인하고 다시 시도해 주세요.';

  @override
  String get notificationPermissionError =>
      '이 알림함이나 가구를 더 이상 사용할 수 없습니다. 세션을 새로 불러와 주세요.';

  @override
  String get notificationVersionConflictError =>
      '이 설정이 다른 곳에서 변경되었습니다. 최신 설정을 불러온 뒤 다시 시도해 주세요.';

  @override
  String get notificationSnoozeUnavailableError =>
      '이 일정 알림은 더 이상 다시 알림으로 설정할 수 없습니다. 알림함을 새로고침해 주세요.';

  @override
  String get notificationGenericError =>
      '알림을 불러오거나 저장하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get notificationPushPermissionHeading => '기기 알림';

  @override
  String get notificationPushPrePromptBody =>
      'KinFlow은 일반적인 리마인더만 보냅니다. 이름과 집안일·일정 세부정보는 푸시 메시지에 포함하지 않으며 앱 내 알림함은 계속 사용할 수 있습니다.';

  @override
  String get notificationPushEnableAction => '기기 알림 켜기';

  @override
  String get notificationPushDeniedBody =>
      '기기 알림이 꺼져 있습니다. Android 설정에서 허용할 수 있으며 앱 내 알림함은 계속 작동합니다.';

  @override
  String get notificationPushOpenSettingsAction => 'Android 설정 열기';

  @override
  String get notificationPushAuthorizedBody => '이 가구의 기기 알림이 켜져 있습니다.';

  @override
  String get notificationPushUnavailableBody =>
      '이 빌드에서는 기기 알림을 사용할 수 없습니다. 앱 내 알림함은 계속 작동합니다.';

  @override
  String get notificationPushSetupError =>
      '기기 알림 설정을 완료하지 못했습니다. 앱 내 알림함에는 영향이 없습니다.';

  @override
  String get notificationPushPresentationTitle => 'KinFlow 알림';

  @override
  String get notificationPushPresentationBody =>
      '최근 가족 업데이트를 확인하려면 KinFlow를 열어 주세요.';

  @override
  String get notificationPushChannelName => '가족 리마인더';

  @override
  String get notificationPushChannelDescription =>
      '가족의 비공개 세부정보를 포함하지 않는 일반 가구 알림';

  @override
  String get featurePolicyUnavailableError =>
      '기능 한도 정책을 아직 확인할 수 없습니다. 가구 요금제 상태를 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get featureLimitReachedError =>
      '이 가구가 현재 요금제 한도에 도달했습니다. 계속하려면 요금제를 확인해 주세요.';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsOpenAction => '설정 열기';

  @override
  String get settingsAccountSection => '계정';

  @override
  String get settingsHouseholdSwitchTitle => '가구 전환';

  @override
  String get settingsHouseholdSwitchSummary => '내 가구 목록을 보고 사용할 가구를 선택합니다.';

  @override
  String get householdSwitchTitle => '가구 전환';

  @override
  String get householdSwitchIntro =>
      '본인의 현재 가구 가입 정보만 표시됩니다. 전환하면 선택한 가구 기준으로 오늘 화면을 다시 불러옵니다.';

  @override
  String get householdSwitchLoading => '내 가구를 불러오는 중입니다';

  @override
  String get householdSwitchEmpty => '이 계정에서 사용할 수 있는 가구가 없습니다.';

  @override
  String get householdSwitchCurrentLabel => '현재 가구';

  @override
  String get householdSwitchRoleOwner => '소유자';

  @override
  String get householdSwitchRoleAdmin => '관리자';

  @override
  String get householdSwitchRoleMember => '구성원';

  @override
  String get householdSwitchConfirmTitle => '사용할 가구를 바꿀까요?';

  @override
  String householdSwitchConfirmBody(String name) {
    return '가구별 로컬 데이터를 안전하게 비운 뒤 ‘$name’의 오늘 화면을 다시 불러옵니다.';
  }

  @override
  String get householdSwitchConfirmAction => '가구 전환';

  @override
  String get householdSwitchInProgress => '가구를 안전하게 전환하는 중입니다…';

  @override
  String get householdSwitchLoadError => '가구 목록을 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get householdSwitchTargetUnavailableError =>
      '이 계정에서 더 이상 사용할 수 없는 가구입니다. 목록을 새로 불러오세요.';

  @override
  String get householdSwitchConflictError =>
      '다른 곳에서 현재 가구가 변경되었습니다. 목록을 새로 불러온 뒤 전환하세요.';

  @override
  String get householdSwitchFeatureDisabledError =>
      '가구 변경이 잠시 중지되었습니다. 현재 목록은 계속 볼 수 있습니다.';

  @override
  String get householdSwitchLocalStateError =>
      '서버의 가구는 변경됐지만 이 기기의 가구별 데이터를 안전하게 비우지 못했습니다. 다시 로그인해 복구하세요.';

  @override
  String get householdSwitchGenericError =>
      '가구를 안전하게 전환하지 못했습니다. 목록을 새로 불러온 뒤 다시 시도해 주세요.';

  @override
  String get settingsDeleteAccountTitle => '계정 삭제';

  @override
  String get settingsDeleteAccountSummary =>
      '삭제 가능 여부를 확인하고 삭제 요청 또는 대기 중인 요청 취소를 진행합니다.';

  @override
  String get accountDeletionTitle => '계정 삭제';

  @override
  String get accountDeletionLoadingLabel => '계정 삭제 상태를 확인하는 중입니다';

  @override
  String get accountDeletionIntroHeading => '계정을 삭제하면';

  @override
  String get accountDeletionIntroBody =>
      '취소 가능 시간이 지난 뒤 프로필, 로그인 정보, 개인 알림 설정과 기기 알림 인증 정보가 삭제됩니다.';

  @override
  String get accountDeletionPreservedBody =>
      '공유 가구, 집안일과 캘린더 기록은 남은 가구 구성원이 계속 볼 수 있으며 삭제된 구성원으로 표시됩니다.';

  @override
  String get accountDeletionStatusHeading => '최근 요청';

  @override
  String get accountDeletionStatusQueued => '삭제 예약됨 · 아직 취소할 수 있습니다';

  @override
  String get accountDeletionStatusVerifying => '확인 중 · 아직 취소할 수 있습니다';

  @override
  String get accountDeletionStatusProcessing => '삭제 처리 중이며 이제 취소할 수 없습니다';

  @override
  String get accountDeletionStatusCompleted => '계정 삭제가 완료되었습니다';

  @override
  String get accountDeletionStatusFailed => '계정 삭제를 다시 처리해야 합니다';

  @override
  String get accountDeletionStatusCancelled => '계정 삭제 요청을 취소했습니다';

  @override
  String accountDeletionScheduledFor(String date) {
    return '$date 이후 삭제가 시작됩니다';
  }

  @override
  String accountDeletionCancellationWindow(int hours) {
    return '새 요청은 약 $hours시간 동안 취소할 수 있습니다.';
  }

  @override
  String get accountDeletionRequestAction => '계정 삭제 요청';

  @override
  String get accountDeletionCancelAction => '삭제 요청 취소';

  @override
  String get accountDeletionOwnerBlockTitle => '먼저 가구 소유권을 이전해 주세요';

  @override
  String accountDeletionOwnerBlockBody(int count) {
    return '현재 활성 가구 $count개의 소유자입니다. 계정을 삭제하기 전에 각 가구를 다른 성인에게 이전해 주세요.';
  }

  @override
  String get accountDeletionManageHouseholdsAction => '가구 구성원 관리';

  @override
  String get accountDeletionSubscriptionTitle => '활성 구독이 있습니다';

  @override
  String get accountDeletionSubscriptionBody =>
      'KinFlow 계정 삭제만으로 App Store 또는 Google Play 구독은 취소되지 않습니다. 더 이상 원하지 않으면 스토어에서 별도로 취소해 주세요.';

  @override
  String get accountDeletionSubscriptionAcknowledge =>
      '계정을 삭제해도 스토어 구독은 취소되지 않는다는 점을 확인했습니다.';

  @override
  String get accountDeletionPausedTitle => '계정 삭제 요청이 잠시 중단되었습니다';

  @override
  String get accountDeletionPausedBody =>
      '계정은 그대로 유지됩니다. 나중에 새로고침하여 요청 가능 여부를 확인해 주세요.';

  @override
  String get accountDeletionConfirmTitle => '계정 삭제를 예약할까요?';

  @override
  String get accountDeletionConfirmBody =>
      '이 기기에서는 즉시 로그아웃됩니다. 요청을 취소하려면 기한 전에 다시 로그인하세요.';

  @override
  String get accountDeletionConfirmAction => '삭제 예약';

  @override
  String get accountDeletionConfirmCancelAction => '계정 유지';

  @override
  String get accountDeletionCancelConfirmTitle => '계정 삭제를 취소할까요?';

  @override
  String get accountDeletionCancelConfirmBody =>
      '계정은 활성 상태로 유지되고 이 삭제 요청은 실행되지 않습니다.';

  @override
  String get accountDeletionCancelConfirmAction => '삭제 취소';

  @override
  String get accountDeletionPermissionError =>
      '이 계정 삭제 요청을 더 이상 사용할 수 없습니다. 세션을 새로 불러와 주세요.';

  @override
  String get accountDeletionRecentAuthError =>
      '계정 삭제를 요청하기 전에 Google 로그인을 다시 확인해 주세요.';

  @override
  String get accountDeletionRecentAuthCancelled =>
      '계정 확인을 취소했습니다. 삭제 요청은 전송되지 않았습니다.';

  @override
  String get accountDeletionAccountChangedError =>
      '확인한 Google 계정이 현재 KinFlow 계정과 다릅니다. 삭제 요청은 전송되지 않았습니다.';

  @override
  String get accountDeletionOwnerTransferError =>
      '소유한 모든 가구를 이전한 뒤 계정 삭제를 요청해 주세요.';

  @override
  String get accountDeletionSubscriptionError =>
      '계속하기 전에 활성 스토어 구독 안내를 확인해 주세요.';

  @override
  String get accountDeletionPendingError =>
      '계정 삭제 요청이 이미 대기 중입니다. 새로고침하여 확인해 주세요.';

  @override
  String get accountDeletionConflictError =>
      '이 요청이 다른 곳에서 변경되었습니다. 최신 상태를 불러온 뒤 다시 시도해 주세요.';

  @override
  String get accountDeletionPausedError =>
      '계정 삭제 요청이 잠시 중단되었습니다. 계정은 그대로 유지됩니다.';

  @override
  String get accountDeletionGenericError =>
      '계정 삭제 상태를 불러오거나 변경하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get settingsDataExportTitle => '내 데이터 다운로드';

  @override
  String get settingsDataExportSummary =>
      '내 KinFlow 개인 데이터를 비공개 JSON과 읽기 쉬운 텍스트 파일로 만듭니다.';

  @override
  String get dataExportTitle => '내 데이터 다운로드';

  @override
  String get dataExportLoadingLabel => '개인 데이터 내보내기 상태를 확인하는 중입니다';

  @override
  String get dataExportIntroHeading => '내 KinFlow 개인 데이터';

  @override
  String get dataExportIntroBody =>
      '내보내기에는 내 프로필, 활성 멤버십, 내가 작성한 항목, 내 참여·완료 기록, 알림 설정과 제공자 식별자를 제거한 결제 요약이 포함됩니다.';

  @override
  String get dataExportScopeBody =>
      '다른 가구 구성원의 프로필이나 전체 공유 가구 보관본은 포함하지 않습니다. 가구 소유자용 절차는 나중에 별도로 제공됩니다.';

  @override
  String dataExportRetentionBody(int hours, int minutes) {
    return '완성된 파일은 약 $hours시간 뒤 만료됩니다. 다운로드 링크는 한 번만 작동하며 $minutes분 뒤 만료됩니다.';
  }

  @override
  String get dataExportStatusHeading => '최근 내보내기';

  @override
  String get dataExportStatusQueued => '내보내기 대기 중';

  @override
  String get dataExportStatusVerifying => '내보내기를 확인하는 중';

  @override
  String get dataExportStatusProcessing => '비공개 파일을 만드는 중';

  @override
  String get dataExportStatusCompleted => '개인 데이터 내보내기 준비 완료';

  @override
  String get dataExportStatusFailed => '내보내기를 완료하지 못했습니다';

  @override
  String get dataExportStatusCancelled => '내보내기 요청을 취소했습니다';

  @override
  String get dataExportRequestAction => '개인 데이터 내보내기 만들기';

  @override
  String get dataExportCancelAction => '내보내기 요청 취소';

  @override
  String get dataExportDownloadHeading => '비공개 다운로드';

  @override
  String get dataExportDownloadBody =>
      '새 일회용 링크를 만들려면 계정을 다시 확인하세요. 파일은 브라우저나 다운로드 앱에서 열립니다.';

  @override
  String get dataExportJsonAction => 'JSON 다운로드';

  @override
  String get dataExportTextAction => '읽기 쉬운 텍스트 다운로드';

  @override
  String dataExportExpiresAt(String date) {
    return '파일 만료: $date';
  }

  @override
  String dataExportFileSizes(String jsonSize, String textSize) {
    return 'JSON $jsonSize · 텍스트 $textSize';
  }

  @override
  String dataExportBytes(String count) {
    return '$count B';
  }

  @override
  String dataExportKilobytes(String count) {
    return '$count KB';
  }

  @override
  String dataExportMegabytes(String count) {
    return '$count MB';
  }

  @override
  String dataExportOpenedMessage(String format) {
    return '$format 일회용 다운로드를 열었습니다. 파일이 다시 필요하면 새 링크를 요청하세요.';
  }

  @override
  String get dataExportJsonFormat => 'JSON';

  @override
  String get dataExportTextFormat => '텍스트';

  @override
  String get dataExportRevokeAction => '내보내기 파일 지금 삭제';

  @override
  String get dataExportRevokedBody => '이 내보내기 파일을 폐기했으며 영구 삭제 대기열에 추가했습니다.';

  @override
  String get dataExportPurgedBody => '이 내보내기 파일을 영구 삭제했습니다.';

  @override
  String get dataExportExpiredBody =>
      '이 내보내기 파일은 만료되었습니다. 사본이 필요하면 새로 만들어 주세요.';

  @override
  String get dataExportRequestsPausedTitle => '새 내보내기가 잠시 중단되었습니다';

  @override
  String get dataExportRequestsPausedBody =>
      '데이터는 변경되지 않습니다. 나중에 새로고침하여 요청 가능 여부를 확인해 주세요.';

  @override
  String get dataExportConflictingRequestBody =>
      '다른 개인정보 요청을 처리 중입니다. 완료하거나 취소한 뒤 내보내기를 만들어 주세요.';

  @override
  String get dataExportDownloadsPausedBody =>
      '다운로드가 잠시 중단되었습니다. 완성된 파일은 만료되거나 직접 삭제할 때까지 비공개로 유지됩니다.';

  @override
  String get dataExportConfirmTitle => '개인 데이터 내보내기를 만들까요?';

  @override
  String get dataExportConfirmBody =>
      'Google 계정을 확인한 뒤 비공개 JSON과 읽기 쉬운 텍스트 파일을 만듭니다.';

  @override
  String get dataExportConfirmAction => '내보내기 만들기';

  @override
  String get dataExportDismissAction => '나중에';

  @override
  String get dataExportCancelConfirmTitle => '이 내보내기를 취소할까요?';

  @override
  String get dataExportCancelConfirmBody => '대기 중인 작업을 중지하며 다운로드 파일을 만들지 않습니다.';

  @override
  String get dataExportCancelConfirmAction => '내보내기 취소';

  @override
  String get dataExportRevokeConfirmTitle => '이 내보내기 파일을 지금 삭제할까요?';

  @override
  String get dataExportRevokeConfirmBody =>
      '발급된 모든 다운로드 링크가 중단되고 비공개 파일이 영구 삭제 대기열에 추가됩니다.';

  @override
  String get dataExportRevokeConfirmAction => '파일 삭제';

  @override
  String get dataExportPermissionError =>
      '이 계정에서 해당 내보내기를 더 이상 사용할 수 없습니다. 세션을 새로 불러와 주세요.';

  @override
  String get dataExportRecentAuthError =>
      '내보내기를 만들거나 다운로드하기 전에 Google 로그인을 다시 확인해 주세요.';

  @override
  String get dataExportRecentAuthCancelled =>
      '계정 확인을 취소했습니다. 내보내기 작업은 전송되지 않았습니다.';

  @override
  String get dataExportAccountChangedError =>
      '확인한 Google 계정이 현재 KinFlow 계정과 다릅니다. 내보내기 작업은 전송되지 않았습니다.';

  @override
  String get dataExportPendingError =>
      '다른 개인정보 요청이 이미 대기 중입니다. 최신 상태를 불러온 뒤 다시 시도해 주세요.';

  @override
  String get dataExportConflictError =>
      '이 내보내기가 다른 곳에서 변경되었습니다. 최신 상태를 불러온 뒤 다시 시도해 주세요.';

  @override
  String get dataExportPausedError =>
      '새 개인 데이터 내보내기가 잠시 중단되었습니다. 데이터는 변경되지 않습니다.';

  @override
  String get dataExportDownloadsPausedError =>
      '개인 데이터 내보내기 다운로드가 잠시 중단되었습니다. 나중에 다시 시도해 주세요.';

  @override
  String get dataExportUnavailableError =>
      '이 비공개 내보내기는 만료 또는 폐기되었거나 더 이상 사용할 수 없습니다. 필요하면 새로 만들어 주세요.';

  @override
  String get dataExportTooLargeError =>
      '안전한 단일 파일 한도보다 내보낼 데이터가 많습니다. 지원팀에 문의해 주세요.';

  @override
  String get dataExportLaunchError =>
      '다운로드 앱을 열지 못했습니다. 새 일회용 링크를 요청해 다시 시도해 주세요.';

  @override
  String get dataExportGenericError =>
      '개인 데이터 내보내기를 불러오거나 변경하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get settingsHouseholdPrivacyTitle => '가구 데이터 및 삭제';

  @override
  String get settingsHouseholdPrivacySummary =>
      'Owner는 공유 데이터를 내보내거나 가구 삭제를 예약할 수 있습니다';

  @override
  String get householdPrivacyTitle => '가구 데이터 및 삭제';

  @override
  String get householdPrivacyLoadingLabel => 'Owner 권한과 가구 개인정보 요청 상태를 확인하는 중…';

  @override
  String get householdPrivacyIntroHeading => 'Owner 전용 관리';

  @override
  String get householdPrivacyIntroBody =>
      '이 기능은 공유 가구 데이터와 모든 현재 구성원에게 영향을 줍니다. KinFlow는 모든 작업에서 현재 Owner 권한을 서버에서 확인합니다.';

  @override
  String householdPrivacyMemberCount(int count) {
    return '현재 구성원: $count명';
  }

  @override
  String householdPrivacyExportRetention(int hours, int minutes) {
    return '내보내기 파일은 약 $hours시간 뒤 만료되고, 일회용 링크는 $minutes분 동안 유효합니다.';
  }

  @override
  String householdPrivacyDeletionWindow(int hours) {
    return '백그라운드 삭제가 시작되기 전 약 $hours시간 동안 삭제 요청을 취소할 수 있습니다.';
  }

  @override
  String get householdPrivacyExportHeading => '공유 가구 데이터 내보내기';

  @override
  String get householdPrivacyExportBody =>
      '가구 정보, 구성원, 집안일, 캘린더 데이터와 제공자 식별자가 없는 결제 요약을 비공개 JSON 및 읽기 쉬운 텍스트 파일로 만듭니다.';

  @override
  String get householdPrivacyExportAction => '가구 내보내기 만들기';

  @override
  String get householdPrivacyDeleteHeading => '이 가구 삭제';

  @override
  String get householdPrivacyDeleteBody =>
      '삭제하면 구성원 접근을 영구 종료하고 공유 내용을 비식별 처리하며 초대를 폐기하고 결제 접근을 연결 해제합니다. 구성원 계정과 Store 구독은 삭제하거나 취소하지 않습니다.';

  @override
  String get householdPrivacyDeleteAction => '가구 삭제 예약';

  @override
  String get householdPrivacySubscriptionWarning =>
      '이 가구에는 활성 구독 할당이 있습니다. 가구를 삭제해도 Store 구독은 취소되지 않습니다.';

  @override
  String get householdPrivacyStatusHeading => '최근 가구 개인정보 요청';

  @override
  String get householdPrivacyExportKind => '가구 내보내기';

  @override
  String get householdPrivacyDeletionKind => '가구 삭제';

  @override
  String get householdPrivacyStatusQueued => '취소 가능 기간 동안 대기 중';

  @override
  String get householdPrivacyStatusVerifying => '현재 Owner와 요청 조건을 확인하는 중';

  @override
  String get householdPrivacyStatusProcessing => '백그라운드에서 처리 중';

  @override
  String get householdPrivacyStatusCompleted => '요청 완료';

  @override
  String get householdPrivacyStatusFailed => '요청을 완료하지 못했습니다';

  @override
  String get householdPrivacyStatusCancelled => '요청 취소됨';

  @override
  String get householdPrivacyCancelAction => '요청 취소';

  @override
  String get householdPrivacyDownloadHeading => '비공개 가구 다운로드';

  @override
  String get householdPrivacyDownloadBody =>
      '각 링크는 한 번만 사용할 수 있으며 앱 상태나 저장소에 보관하지 않습니다.';

  @override
  String get householdPrivacyRevokeAction => '가구 내보내기 파일 지금 삭제';

  @override
  String get householdPrivacyRetentionBlocked =>
      '보존 조치로 삭제가 일시 중지되었습니다. 조치가 활성화된 동안에는 접근 권한을 제거하지 않습니다.';

  @override
  String householdPrivacyRetentionReview(String date) {
    return '보존 검토: $date';
  }

  @override
  String householdPrivacyOpenedMessage(String format) {
    return '$format 가구 일회용 다운로드를 열었습니다.';
  }

  @override
  String get householdPrivacyExportConfirmTitle => '가구 내보내기를 만들까요?';

  @override
  String get householdPrivacyExportConfirmBody =>
      'Google 계정을 확인한 뒤 이 가구의 비공개 JSON과 읽기 쉬운 텍스트 파일을 만듭니다.';

  @override
  String get householdPrivacyCancelConfirmTitle => '이 요청을 취소할까요?';

  @override
  String get householdPrivacyCancelConfirmBody =>
      '대기 중인 요청을 중지합니다. 이미 처리 중인 요청은 취소할 수 없습니다.';

  @override
  String get householdPrivacyRevokeConfirmTitle => '이 가구 내보내기 파일을 지금 삭제할까요?';

  @override
  String get householdPrivacyRevokeConfirmBody =>
      '발급된 링크가 모두 중단되고 두 비공개 파일이 영구 삭제 대기열에 추가됩니다.';

  @override
  String get householdPrivacyDeleteConfirmTitle => '이 가구를 영구 삭제할까요?';

  @override
  String get householdPrivacyDeleteConfirmBody =>
      '가구 이름을 정확히 입력하고 모든 영향을 확인하세요. 그다음 Google 계정을 확인합니다.';

  @override
  String get householdPrivacyNameLabel => '가구 이름';

  @override
  String householdPrivacyNameHint(String name) {
    return '$name 입력';
  }

  @override
  String get householdPrivacyMemberAccessAck =>
      '모든 현재 구성원이 이 가구에 접근할 수 없게 됨을 이해합니다.';

  @override
  String get householdPrivacyRedactionAck =>
      '공유 집안일, 캘린더 내용, 이름과 알림 장치 정보가 되돌릴 수 없게 비식별 처리되거나 삭제됨을 이해합니다.';

  @override
  String get householdPrivacySubscriptionAck =>
      'Store 구독은 취소되지 않으며 별도로 관리해야 함을 이해합니다.';

  @override
  String get householdPrivacyDeleteConfirmAction => '확인 후 삭제 예약';

  @override
  String get householdPrivacyPermissionError =>
      '현재 가구 Owner만 이 기능을 사용할 수 있습니다. 소유권이 바뀌었다면 새로고침해 주세요.';

  @override
  String get householdPrivacyRecentAuthError =>
      '민감한 가구 작업 전에 같은 Google 계정을 다시 확인해 주세요.';

  @override
  String get householdPrivacyRecentAuthCancelled =>
      '계정 확인을 취소했습니다. 가구 작업은 전송되지 않았습니다.';

  @override
  String get householdPrivacyAccountChangedError =>
      '확인한 Google 계정이 현재 KinFlow 계정과 다릅니다. 가구 작업은 전송되지 않았습니다.';

  @override
  String get householdPrivacyPausedError =>
      '이 가구 개인정보 작업은 잠시 중단되었습니다. 공유 데이터는 변경되지 않습니다.';

  @override
  String get householdPrivacyPendingError =>
      '다른 가구 개인정보 요청을 처리 중입니다. 먼저 최신 상태를 불러와 주세요.';

  @override
  String get householdPrivacyConflictError =>
      '이 가구 또는 요청이 다른 곳에서 변경되었습니다. 새로고침한 뒤 다시 시도해 주세요.';

  @override
  String get householdPrivacyConfirmationError =>
      '입력한 가구 이름이 더 이상 일치하지 않습니다. 새로고침 후 현재 이름을 정확히 입력해 주세요.';

  @override
  String get householdPrivacySubscriptionAckError =>
      '가구 삭제가 활성 Store 구독을 취소하지 않음을 확인해 주세요.';

  @override
  String get householdPrivacyArtifactError =>
      '이 가구 내보내기는 만료 또는 폐기되었거나 사용할 수 없습니다. 필요하면 새로 만들어 주세요.';

  @override
  String get householdPrivacyDeletedError =>
      '이 가구는 이미 삭제되었습니다. 새로고침하여 다른 가구를 선택하거나 만들어 주세요.';

  @override
  String get householdPrivacyLaunchError =>
      '다운로드 앱을 열지 못했습니다. 새 일회용 링크를 요청해 다시 시도해 주세요.';

  @override
  String get householdPrivacyGenericError =>
      '가구 개인정보 기능을 불러오거나 변경하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get settingsProfilePreferencesTitle => '프로필 및 지역 설정';

  @override
  String get settingsProfilePreferencesSummary => '이름, 아바타, 언어와 시간대를 변경합니다';

  @override
  String get profilePreferencesTitle => '프로필 및 지역 설정';

  @override
  String get profilePreferencesLoadingLabel => '프로필과 가구 시간대를 불러오는 중…';

  @override
  String get profilePreferencesIntroHeading => '최소한의 KinFlow 프로필';

  @override
  String get profilePreferencesIntroBody =>
      '표시명과 선택적 기본 아바타만 사용합니다. 법적 이름, 생년월일이나 불필요한 개인정보를 요구하지 않습니다.';

  @override
  String get profilePreferencesProfileHeading => '프로필';

  @override
  String get profilePreferencesDisplayNameLabel => '표시명';

  @override
  String get profilePreferencesDisplayNameValidation =>
      '보이는 문자 1~80자를 입력해 주세요.';

  @override
  String get profilePreferencesAvatarHeading => '기본 아바타';

  @override
  String get profilePreferencesAvatarNone => '없음';

  @override
  String get profilePreferencesAvatarSun => '해';

  @override
  String get profilePreferencesAvatarHeart => '하트';

  @override
  String get profilePreferencesAvatarLeaf => '잎';

  @override
  String get profilePreferencesAvatarStar => '별';

  @override
  String get profilePreferencesRegionalHeading => '언어 및 개인 시간대';

  @override
  String get timezonePreviewHeading => '현재 날짜와 시간 미리보기';

  @override
  String get timezonePreviewBody =>
      '저장하지 않은 언어와 시간대 선택을 미리 보여 줍니다. 새 현재 시각과 오프셋을 사용하려면 새로고침하세요.';

  @override
  String get timezonePreviewPersonalLabel => '개인 미리보기';

  @override
  String get timezonePreviewHouseholdLabel => '가구 미리보기';

  @override
  String get timezonePreviewRefreshAction => '날짜와 시간 미리보기 새로고침';

  @override
  String get timezonePreviewLoadingLabel => '현재 날짜와 시간 미리보기를 준비하는 중…';

  @override
  String get timezonePreviewLoadFailure =>
      '미리보기를 새로고침하지 못했습니다. 언어와 시간대 선택은 바뀌지 않았습니다.';

  @override
  String timezonePreviewMissingTimezone(String timezone) {
    return '$timezone이 앱의 시간대 목록에 없어 기기 시간으로 대신 표시하지 않습니다.';
  }

  @override
  String timezonePreviewSemantics(
    String label,
    String timezone,
    String date,
    String time,
    String metadata,
  ) {
    return '$label. $timezone. $date. $time. $metadata.';
  }

  @override
  String timezonePreviewUnavailableSemantics(String label, String timezone) {
    return '$label. $timezone 시간대는 미리보기를 사용할 수 없습니다.';
  }

  @override
  String get profilePreferencesLanguageLabel => '앱 언어';

  @override
  String get profilePreferencesLanguageEnglish => 'English';

  @override
  String get profilePreferencesLanguageKorean => '한국어';

  @override
  String get profilePreferencesPersonalTimezoneLabel => '개인 시간대';

  @override
  String get profilePreferencesPersonalTimezoneHelper =>
      'IANA 지역이나 도시를 선택하면 개인 기본값으로 저장됩니다.';

  @override
  String get profilePreferencesPersonalTimezonePickerTitle => '개인 시간대 선택';

  @override
  String get profilePreferencesTimezoneValidation =>
      'Asia/Seoul 또는 UTC 같은 유효한 IANA 시간대를 선택해 주세요.';

  @override
  String get profilePreferencesHouseholdHeading => '가구 기본 시간대';

  @override
  String get profilePreferencesHouseholdTimezoneLabel => '가구 시간대';

  @override
  String get profilePreferencesHouseholdTimezoneHelper =>
      'Owner와 Admin은 가구 날짜와 새 항목의 기본 시간대를 선택할 수 있습니다.';

  @override
  String get profilePreferencesHouseholdTimezonePickerTitle => '가구 시간대 선택';

  @override
  String profilePreferencesHouseholdTimezoneReadOnly(String timezone) {
    return '$timezone · Owner 또는 Admin만 이 기본값을 변경할 수 있습니다.';
  }

  @override
  String get profilePreferencesImpactHeading => '가구 시간대를 바꾸면 달라지는 점';

  @override
  String get profilePreferencesImpactBody =>
      '가구 기준 Today 날짜 경계, 새 항목의 기본값과 가구 기본값을 상속 중인 알림 설정이 즉시 바뀝니다.';

  @override
  String get profilePreferencesImpactPreservedBody =>
      '기존 반복 집안일과 캘린더 시리즈는 저장된 시간대와 회차 시각을 그대로 유지합니다.';

  @override
  String get profilePreferencesSaveAction => '프로필 및 지역 설정 저장';

  @override
  String get profilePreferencesSavedMessage => '프로필 및 지역 설정을 저장했습니다.';

  @override
  String get profilePreferencesConfirmTimezoneTitle => '가구 시간대를 변경할까요?';

  @override
  String get profilePreferencesConfirmTimezoneBody =>
      'Today 날짜 경계와 새 기본값은 즉시 바뀌지만 기존 반복 항목은 저장된 시간대와 시각을 유지합니다.';

  @override
  String get profilePreferencesConfirmTimezoneAction => '시간대 변경 후 저장';

  @override
  String get profilePreferencesCancelAction => '취소';

  @override
  String get timezonePickerCloseAction => '시간대 선택 닫기';

  @override
  String get timezonePickerCurrentLabel => '현재 선택';

  @override
  String get timezonePickerSearchLabel => '지역 또는 도시 검색';

  @override
  String get timezonePickerSearchHelper =>
      'Seoul, New_York 또는 Europe처럼 IANA 이름으로 검색해 보세요.';

  @override
  String get timezonePickerClearSearchAction => '시간대 검색어 지우기';

  @override
  String get timezonePickerLoadingLabel => '앱에 포함된 시간대 목록을 불러오는 중…';

  @override
  String get timezonePickerLoadFailure =>
      '시간대 목록을 불러오지 못했습니다. 현재 선택은 바뀌지 않았습니다.';

  @override
  String get timezonePickerEmptyLabel => '검색과 일치하는 시간대가 없습니다.';

  @override
  String get timezonePickerDaylightSavingLabel => '현재 일광 절약 시간';

  @override
  String get timezonePickerStandardTimeLabel => '현재 표준 시간';

  @override
  String timezonePickerMetadata(String offset, String clockKind) {
    return 'UTC$offset · $clockKind';
  }

  @override
  String get profilePreferencesErrorUnauthenticated =>
      '이 프로필을 불러오거나 변경하려면 다시 로그인해 주세요.';

  @override
  String get profilePreferencesErrorInvalidInput =>
      '표시명, 아바타, 언어와 IANA 시간대 값을 확인해 주세요.';

  @override
  String get profilePreferencesErrorUnavailable =>
      '이 프로필 또는 활성 가구를 더 이상 사용할 수 없습니다. 세션을 새로 불러와 주세요.';

  @override
  String get profilePreferencesErrorForbidden =>
      '현재 Owner 또는 Admin만 가구 시간대를 변경할 수 있습니다. 개인 변경 내용도 저장하지 않았습니다.';

  @override
  String get profilePreferencesErrorProfileConflict =>
      '다른 곳에서 프로필이 변경되었습니다. 최신 버전을 다시 불러온 뒤 저장해 주세요.';

  @override
  String get profilePreferencesErrorHouseholdConflict =>
      '다른 곳에서 가구 시간대가 변경되었습니다. 최신 버전을 다시 불러온 뒤 저장해 주세요.';

  @override
  String get profilePreferencesErrorTemporarilyUnavailable =>
      '프로필 설정을 잠시 사용할 수 없습니다. 기존 값은 변경되지 않았습니다.';

  @override
  String get profilePreferencesErrorInvalidPayload =>
      '예상하지 못한 설정 응답을 받아 적용하지 않았습니다.';

  @override
  String get profilePreferencesErrorInternal =>
      '설정을 불러오거나 저장하지 못했습니다. 안전하게 다시 시도할 수 있습니다.';

  @override
  String get settingsSubscriptionTitle => '구독 및 Plus';

  @override
  String get settingsSubscriptionSummary =>
      '이 가구의 요금제를 확인하고 Plus 구매·복원 및 결제를 관리합니다';

  @override
  String get subscriptionTitle => '구독 및 Plus';

  @override
  String get subscriptionLoading => '서버에서 확인한 구독 상태를 불러오는 중…';

  @override
  String get subscriptionHouseholdFallback => '활성 가구';

  @override
  String get subscriptionStatusHeading => '현재 가구 구독';

  @override
  String get subscriptionHouseholdLabel => '가구';

  @override
  String get subscriptionPlanLabel => '요금제';

  @override
  String get subscriptionLifecycleLabel => '상태';

  @override
  String get subscriptionSourceLabel => '결제 출처';

  @override
  String get subscriptionBillingOwnerLabel => '결제 관리자';

  @override
  String get subscriptionBillingOwnerNone => '결제 관리자 없음';

  @override
  String get subscriptionPeriodLabel => '결제 기간';

  @override
  String get subscriptionVerifiedLabel => '서버 확인';

  @override
  String get subscriptionPlanFree => 'Free';

  @override
  String get subscriptionPlanPlus => 'Plus';

  @override
  String get subscriptionStatusNone => '활성 Plus 구독 없음';

  @override
  String get subscriptionStatusTrialing => '체험 기간 활성';

  @override
  String get subscriptionStatusActive => '활성';

  @override
  String get subscriptionStatusGrace => '결제 재시도 유예 기간';

  @override
  String get subscriptionStatusBillingIssue => '결제 확인 필요';

  @override
  String get subscriptionStatusExpired => '만료됨';

  @override
  String get subscriptionStatusRevoked => '취소 또는 환불됨';

  @override
  String get subscriptionSourceNone => '없음';

  @override
  String get subscriptionSourcePlayStore => 'Google Play';

  @override
  String get subscriptionSourceAppStore => 'Apple App Store';

  @override
  String get subscriptionSourceWeb => '웹 결제';

  @override
  String get subscriptionSourceSupport => 'KinFlow 지원팀';

  @override
  String get subscriptionBillingOwnerYou => '내가 이 구독을 관리함';

  @override
  String get subscriptionBillingOwnerOther => '다른 가구 구성원이 관리함';

  @override
  String subscriptionRenewsOn(String date) {
    return '$date에 갱신';
  }

  @override
  String subscriptionAccessThrough(String date) {
    return '$date까지 현재 접근 가능';
  }

  @override
  String get subscriptionNoPeriodEnd => '보고된 기간 종료일 없음';

  @override
  String subscriptionVerifiedAt(String date) {
    return '$date 확인';
  }

  @override
  String get subscriptionLifecycleTrialing =>
      'Plus 체험 기간이 활성 상태입니다. Store에서 취소하지 않으면 갱신될 수 있습니다.';

  @override
  String get subscriptionLifecycleGrace =>
      'Store가 결제를 재시도하는 동안 Plus를 계속 사용할 수 있습니다. Store에서 결제 수단을 확인해 주세요.';

  @override
  String get subscriptionLifecycleBillingIssue =>
      'Store에서 결제 문제를 보고했습니다. 기존 데이터는 안전하게 유지되며 Store에서 결제를 확인할 수 있습니다.';

  @override
  String get subscriptionLifecycleExpired =>
      'Plus 접근이 종료되었습니다. 기존 가구 데이터는 유지되며 새 작업에는 Free 요금제 제한이 적용됩니다.';

  @override
  String get subscriptionLifecycleRevoked =>
      'Plus 접근이 취소 또는 환불되었습니다. 기존 가구 데이터는 유지되며 새 작업에는 Free 요금제 제한이 적용됩니다.';

  @override
  String get subscriptionBenefitsHeading => 'Plus 혜택';

  @override
  String get subscriptionBenefitMembers => '더 많은 가구 구성원을 위한 공간';

  @override
  String get subscriptionBenefitRecurring => '더 많은 활성 반복 집안일 및 캘린더 시리즈';

  @override
  String get subscriptionBenefitData => 'Plus가 끝나도 기존 가구 데이터 유지';

  @override
  String get subscriptionLimitsPending =>
      '최종 가격과 한도는 Store와 서버에서 제공합니다. 확인되지 않은 숫자 한도는 여기에 표시하지 않습니다.';

  @override
  String get subscriptionOffersHeading => 'Store 옵션 선택';

  @override
  String subscriptionPackagePrice(String price, String period) {
    return '$price · $period';
  }

  @override
  String subscriptionPeriodDays(int count) {
    return '$count일마다';
  }

  @override
  String subscriptionPeriodWeeks(int count) {
    return '$count주마다';
  }

  @override
  String subscriptionPeriodMonths(int count) {
    return '$count개월마다';
  }

  @override
  String subscriptionPeriodYears(int count) {
    return '$count년마다';
  }

  @override
  String get subscriptionPurchaseAction => 'Store 구매로 계속';

  @override
  String get subscriptionRestoreAction => 'Store 구매 복원';

  @override
  String get subscriptionManageAction => 'Store에서 구독 관리';

  @override
  String get subscriptionRefreshAction => '서버 상태 새로고침';

  @override
  String get subscriptionReturnAction => '구독 옵션으로 돌아가기';

  @override
  String get subscriptionSupportAction => '지원팀 문의';

  @override
  String get subscriptionTermsAction => '이용약관';

  @override
  String get subscriptionPrivacyAction => '개인정보 처리방침';

  @override
  String get subscriptionAdminRequired =>
      '현재 가구의 Owner 또는 Admin만 Plus를 구매하거나 복원할 수 있습니다. 현재 상태는 계속 확인할 수 있습니다.';

  @override
  String get subscriptionProfileUnavailable =>
      '현재 가구 역할을 확인하지 못했습니다. 구매 또는 복원 전에 프로필 설정을 새로고침해 주세요.';

  @override
  String get subscriptionStoreUnavailable =>
      '지금은 Store 옵션을 사용할 수 없습니다. 위에는 서버에서 확인한 가구 상태가 계속 표시됩니다.';

  @override
  String get subscriptionPurchaseConfirmTitle => '이 가구의 구매 확인';

  @override
  String subscriptionPurchaseConfirmBody(
    String household,
    String price,
    String period,
  ) {
    return '$household 가구에 Plus를 Store 가격 $price, $period 결제로 구매할까요?';
  }

  @override
  String get subscriptionPurchaseConfirmRenewal =>
      '결제 관리자가 Store에서 취소할 때까지 구독이 갱신되고 결제될 수 있습니다.';

  @override
  String get subscriptionPurchaseConfirmServer =>
      'Store 성공만으로 접근이 확정되지 않습니다. 서버 확인 후 Plus를 활성화합니다.';

  @override
  String get subscriptionPurchaseConfirmAction => '확인 후 Store 열기';

  @override
  String get subscriptionRestoreConfirmTitle => '이 가구에 구매를 복원할까요?';

  @override
  String subscriptionRestoreConfirmBody(String household) {
    return '$household 가구에 사용할 Store 구매를 확인합니다. 다른 가구의 구독을 자동으로 이전하지 않습니다.';
  }

  @override
  String get subscriptionRestoreConfirmConflict =>
      '구매가 다른 곳에 할당되어 있으면 결제 식별자를 노출하지 않고 중지한 뒤 지원 요청을 안내합니다.';

  @override
  String get subscriptionRestoreConfirmAction => '복원 확인';

  @override
  String get subscriptionCancelAction => '취소';

  @override
  String get subscriptionPreparingPurchase =>
      'Store를 열기 전에 이 구독을 안전하게 할당할 수 있는지 확인하는 중…';

  @override
  String get subscriptionPreparingRestore =>
      '복원된 구매를 이 가구에 안전하게 할당할 수 있는지 확인하는 중…';

  @override
  String get subscriptionPurchasing => 'Store 구매 결과를 기다리는 중…';

  @override
  String get subscriptionRestoring => 'Store에서 구매를 확인하는 중…';

  @override
  String get subscriptionStorePending =>
      'Store에서 아직 요청을 처리 중입니다. 중복을 막기 위해 구매와 복원 기능을 일시 중지합니다.';

  @override
  String get subscriptionServerPending =>
      'Store가 응답했지만 서버의 최종 확인을 받지 못했습니다. 다시 구매하지 말고 상태를 새로고침해 주세요.';

  @override
  String get subscriptionRestoreEmptyTitle => '복원할 구매가 없습니다';

  @override
  String get subscriptionRestoreEmptyBody =>
      'Store가 이 계정의 Plus 구매를 반환하지 않았습니다. 가구 구독은 변경되지 않았습니다.';

  @override
  String get subscriptionConflictTitle => '구독 할당 검토 필요';

  @override
  String get subscriptionConflictBody =>
      '구매 또는 가구가 이미 다른 곳에 연결되어 있어 Store에 접속하기 전에 중지했습니다. 결제 식별자는 표시하지 않습니다.';

  @override
  String get subscriptionRestoreConflictBody =>
      'Store에서 구매를 찾았지만 이 가구에 안전하게 할당할 수 없었습니다. 접근 권한이나 소유권은 변경되지 않았습니다.';

  @override
  String get subscriptionRemediationAction => '할당 검토 요청';

  @override
  String get subscriptionRemediationSubmitted =>
      '할당 검토 요청이 열렸습니다. 이 화면에 결제 식별자를 표시하지 않고 지원팀에서 확인할 수 있습니다.';

  @override
  String get subscriptionRemediationFailed =>
      '검토 요청을 보내지 못했습니다. Store 작업은 발생하지 않았으며 문제가 계속되면 지원팀에 문의해 주세요.';

  @override
  String get subscriptionNoticePurchaseCancelled =>
      'Store 구매를 취소했습니다. KinFlow에서 청구하지 않았으며 가구 요금제도 변경되지 않았습니다.';

  @override
  String get subscriptionNoticeAlreadyActive =>
      '서버에서 확인한 Plus가 이 가구에 이미 활성 상태입니다.';

  @override
  String get subscriptionNoticePurchaseConfirmed =>
      '서버가 구매를 확인하고 이 가구의 Plus 상태를 변경했습니다.';

  @override
  String get subscriptionNoticeRestoreConfirmed => '서버가 이 가구의 복원된 구매를 확인했습니다.';

  @override
  String get subscriptionNoticeServerRefreshed => '서버에서 확인한 최신 구독 상태입니다.';

  @override
  String get subscriptionExternalUnavailable =>
      '신뢰된 외부 페이지를 열지 못했습니다. 다시 시도하거나 Store 앱에서 직접 확인해 주세요.';

  @override
  String get subscriptionFailureUnsupported =>
      '이 기기에서는 Store 결제를 사용할 수 없습니다. 서버에서 확인한 상태는 계속 볼 수 있습니다.';

  @override
  String get subscriptionFailureUnauthenticated =>
      '구독 상태를 불러오거나 변경하려면 다시 로그인해 주세요.';

  @override
  String get subscriptionFailureIdentity =>
      'Store 계정을 안전하게 연결하거나 해제하지 못했습니다. 로그아웃 후 다시 로그인해 주세요.';

  @override
  String get subscriptionFailureInvalidInput =>
      '활성 가구 또는 Store 옵션이 변경되었습니다. 계속하기 전에 새로고침해 주세요.';

  @override
  String get subscriptionFailureCatalog =>
      'Store 옵션을 불러오지 못했습니다. 서버에서 확인한 상태는 계속 사용할 수 있습니다.';

  @override
  String get subscriptionFailureStore =>
      'Store가 이 요청을 완료하지 못했습니다. 다시 시도하기 전에 Store 앱을 확인하고 서버 상태를 새로고침해 주세요.';

  @override
  String get subscriptionFailureNetwork =>
      '네트워크를 사용할 수 없습니다. 새 구독 상태를 추정하지 않았으며 연결 후 새로고침해 주세요.';

  @override
  String get subscriptionFailureAuthorization =>
      '현재 계정 또는 가구에 대해 서버가 이 구독 작업을 거부했습니다.';

  @override
  String get subscriptionFailureServer =>
      '서버가 이 요청을 확인하지 못했습니다. 다시 구매하지 말고 먼저 상태를 새로고침해 주세요.';

  @override
  String get subscriptionFailureInvalidState =>
      '예상하지 못한 구독 상태를 받아 Plus를 활성화하지 않았습니다.';

  @override
  String get subscriptionFailureUnknown =>
      '구독 요청을 안전하게 완료하지 못했습니다. 다른 작업을 하기 전에 상태를 새로고침해 주세요.';

  @override
  String get settingsHelpSection => '도움말 및 법률';

  @override
  String get settingsLegalSupportTitle => '약관·개인정보·지원';

  @override
  String get settingsLegalSupportSummary =>
      '게시된 문서를 확인하고 개인정보 요청을 관리하거나 지원팀에 문의합니다.';

  @override
  String get legalSupportTitle => '약관·개인정보·지원';

  @override
  String get legalSupportIntro =>
      'KinFlow의 게시 문서를 확인하고 지원팀에 문의하거나 개인정보 관리 기능을 찾을 수 있습니다.';

  @override
  String get legalSupportDocumentVersionTitle => '게시 문서 버전';

  @override
  String get legalSupportDocumentVersionBody =>
      '각 링크 문서에 표시된 게시일과 버전이 기준입니다. 앱의 기술 계약 버전은 법률 정책 버전이 아닙니다.';

  @override
  String get legalSupportTermsTitle => '서비스 이용약관';

  @override
  String get legalSupportTermsBody =>
      '계정, 가구, 서비스 이용 책임을 포함한 현재 KinFlow 이용약관을 확인합니다.';

  @override
  String get legalSupportTermsVersionNote =>
      '브라우저에서 고정된 약관 페이지를 엽니다. 게시일과 버전은 해당 페이지에서 확인해 주세요.';

  @override
  String get legalSupportTermsOpenAction => '서비스 이용약관 열기';

  @override
  String get legalSupportPrivacyTitle => '개인정보 처리방침';

  @override
  String get legalSupportPrivacyBody =>
      'KinFlow가 계정, 가구, 기기, 알림 및 구독 관련 데이터를 처리하는 방식을 확인합니다.';

  @override
  String get legalSupportPrivacyVersionNote =>
      '브라우저에서 고정된 개인정보 페이지를 엽니다. 게시일과 버전은 해당 페이지에서 확인해 주세요.';

  @override
  String get legalSupportPrivacyOpenAction => '개인정보 처리방침 열기';

  @override
  String get legalSupportPrivacyControlsTitle => '내 개인정보 관리';

  @override
  String get legalSupportPrivacyControlsBody =>
      'KinFlow를 나가지 않고 내 데이터의 비공개 사본을 만들거나 별도의 계정 삭제 절차를 확인합니다.';

  @override
  String get legalSupportSupportTitle => '지원';

  @override
  String get legalSupportSupportBody =>
      '제품, 계정, 가구 또는 구독 관련 도움을 받을 수 있는 KinFlow 지원 페이지를 엽니다.';

  @override
  String get legalSupportSupportPrivacyNote =>
      '이 링크에는 계정, 가구, 결제 또는 진단 식별자가 자동으로 첨부되지 않습니다.';

  @override
  String get legalSupportSupportOpenAction => '지원 페이지 열기';

  @override
  String get legalSupportConsentTitle => '이 화면의 동의 처리';

  @override
  String get legalSupportConsentBody =>
      '이 자료를 열거나 읽는 것만으로 동의가 부여되거나 철회되지 않습니다. 특정 정책 버전에 대한 결정이 필요해지면 KinFlow가 별도로 요청하고 명시적으로 선택한 결과만 기록합니다.';

  @override
  String get legalSupportTermsResourceName => '서비스 이용약관';

  @override
  String get legalSupportPrivacyResourceName => '개인정보 처리방침';

  @override
  String get legalSupportSupportResourceName => '지원 페이지';

  @override
  String legalSupportOpening(String resource) {
    return '브라우저에서 $resource을(를) 여는 중…';
  }

  @override
  String legalSupportOpened(String resource) {
    return '브라우저에서 $resource을(를) 열었습니다.';
  }

  @override
  String get legalSupportExternalUnavailable =>
      '신뢰된 페이지를 열지 못했습니다. 네트워크 또는 브라우저를 확인한 후 다시 시도해 주세요.';

  @override
  String get settingsAnalyticsPrivacyTitle => '분석 및 데이터 수집';

  @override
  String get settingsAnalyticsPrivacySummary =>
      '선택적 사용 분석, 수집 제한과 SDK 목적을 확인합니다.';

  @override
  String get analyticsPrivacyTitle => '분석 및 데이터 수집';

  @override
  String get analyticsPrivacyLoading => '개인정보를 보호하는 분석 설정을 불러오는 중…';

  @override
  String get analyticsPrivacyLoadFailed =>
      '분석 설정을 안전하게 불러오지 못했습니다. 선택적 사용 분석은 꺼진 상태로 유지됩니다. 다시 시도해 주세요.';

  @override
  String get analyticsPrivacyIntroTitle => '최소한의 선택적 사용 신호';

  @override
  String get analyticsPrivacyIntroBody =>
      '이 기기 설정은 내용이 없는 선택적 사용 이벤트만 제어합니다. 운영 오류 보고와 분리되어 있으며 기본값은 꺼짐입니다.';

  @override
  String get analyticsPrivacyPreferenceTitle => '선택적 사용 분석 허용';

  @override
  String get analyticsPrivacyPreferenceBody =>
      '이 선택은 이 기기와 환경의 analytics-usage-v1에만 적용됩니다. 공급자, 목적, 필드 또는 정책이 확대되면 다시 선택해야 합니다.';

  @override
  String get analyticsPrivacyStatusOff => '꺼짐. 선택적 사용 이벤트를 보내지 않습니다.';

  @override
  String get analyticsPrivacyStatusAvailable =>
      '허용됨. 승인된 내용 없는 이벤트 봉투만 구성된 분석 경로로 보낼 수 있습니다.';

  @override
  String get analyticsPrivacyStatusNoSink =>
      '선택을 저장했지만 외부 행동 분석 경로가 설치되지 않아 아무것도 보내지 않습니다.';

  @override
  String get analyticsPrivacySaving => '기기 분석 설정을 저장하는 중…';

  @override
  String get analyticsPrivacySaveFailed =>
      '설정을 저장하지 못했습니다. 이전 선택이 유지되며 원본 오류는 보관하지 않았습니다.';

  @override
  String get analyticsPrivacySaved => '기기 분석 설정을 저장했습니다.';

  @override
  String get analyticsPrivacyAllowlistTitle => '정확한 이벤트 경계';

  @override
  String get analyticsPrivacyAllowlistBody =>
      'KinFlow는 타입이 정해진 제품 이벤트 6개와 공개 빌드 정보 5개로 된 봉투만 허용합니다. 자유 형식 이벤트 이름과 속성은 앱 경계에서 거부합니다.';

  @override
  String get analyticsPrivacyChildPolicyTitle => 'Managed Child 보호';

  @override
  String get analyticsPrivacyChildPolicyBody =>
      'Managed Child 모드는 성인 전용 Store MVP 범위가 아닙니다. 나중에 추가되더라도 설정 저장소나 분석 경로에 접근하기 전에 선택적 분석을 차단합니다.';

  @override
  String get analyticsPrivacyInventoryTitle => '현재 데이터 처리 SDK 목록';

  @override
  String get analyticsPrivacyInventoryBehavioral =>
      '행동 분석 및 광고: 외부 SDK가 설치되어 있지 않습니다.';

  @override
  String get analyticsPrivacyInventoryOperational =>
      'Sentry: 개인정보가 제거된 충돌과 운영 오류에만 사용하며 선택적 사용 분석 경로가 아닙니다.';

  @override
  String get analyticsPrivacyInventoryNotifications =>
      'Firebase Messaging 및 로컬 알림: 알림 전송과 표시에만 사용합니다.';

  @override
  String get analyticsPrivacyInventoryBilling =>
      'RevenueCat: Store 구매와 권한 처리에만 사용합니다.';

  @override
  String get analyticsPrivacyInventoryIdentity =>
      'Google 로그인 및 Supabase: 인증과 앱 데이터 서비스에 사용하며 행동 분석에는 사용하지 않습니다.';

  @override
  String get analyticsPrivacyNeverCollectedTitle => '선택적 분석에 포함하지 않는 정보';

  @override
  String get analyticsPrivacyNeverCollectedBody =>
      '계정·가구·구성원·자녀 식별자, 이메일·이름·가족 내용, 토큰·영수증·URL·원본 오류, 위치·연락처·광고 ID·기기 지문을 포함하지 않습니다.';

  @override
  String get settingsDiagnosticsTitle => '진단 정보';

  @override
  String get settingsDiagnosticsSummary =>
      '개인정보 없는 앱·빌드·플랫폼·사고 보고서를 확인하고 복사합니다.';

  @override
  String get diagnosticsTitle => '진단 정보';

  @override
  String get diagnosticsIntroHeading => '기기에서 만든 지원 참조 정보';

  @override
  String get diagnosticsIntroBody =>
      'KinFlow는 이 보고서를 기기에서 만들며 본문을 업로드하지 않습니다. 지원팀이 문제를 연결할 수 있도록 무작위 사고 ID만 개인정보가 제거된 앱 진단에 기록될 수 있습니다. 보고서를 공유하기로 선택한 경우에만 복사하세요.';

  @override
  String get diagnosticsIncludedTitle => '포함되는 정보';

  @override
  String get diagnosticsIncludedBody =>
      '앱 ID, 앱 버전, 빌드 번호, 개발 또는 운영 환경, API 계약일, 거친 플랫폼 분류, 무작위 사고 ID, UTC 생성 시각입니다.';

  @override
  String get diagnosticsExcludedTitle => '포함되지 않는 정보';

  @override
  String get diagnosticsExcludedBody =>
      '계정, 가구, 프로필, 이메일, 집안일, 일정, 알림, 결제 내용, 인증 정보, 네트워크 정보, 기기 모델·일련번호·광고 ID, 언어 또는 시간대는 포함하지 않습니다.';

  @override
  String get diagnosticsLoading => '개인정보 없는 로컬 진단 보고서를 만드는 중…';

  @override
  String get diagnosticsUnavailable =>
      '진단 정보를 일시적으로 사용할 수 없습니다. 일부 보고서를 복사하거나 업로드하지 않았습니다.';

  @override
  String get diagnosticsInvalidMetadata =>
      '설치된 앱 정보가 구성된 빌드와 일치하지 않아 일부 또는 잘못된 보고서 생성을 중단했습니다.';

  @override
  String get diagnosticsInternal =>
      '진단 보고서를 안전하게 만들지 못했습니다. 일부 보고서를 복사하거나 업로드하지 않았습니다.';

  @override
  String get diagnosticsReportTitle => '보고서 미리보기';

  @override
  String get diagnosticsApplicationIdLabel => '애플리케이션 ID';

  @override
  String get diagnosticsAppVersionLabel => '앱 버전';

  @override
  String get diagnosticsBuildNumberLabel => '빌드 번호';

  @override
  String get diagnosticsEnvironmentLabel => '환경';

  @override
  String get diagnosticsContractVersionLabel => 'API 계약일';

  @override
  String get diagnosticsDevicePlatformLabel => '거친 플랫폼 분류';

  @override
  String get diagnosticsIncidentIdLabel => '사고 ID';

  @override
  String get diagnosticsGeneratedAtLabel => '생성 시각(UTC)';

  @override
  String get diagnosticsClipboardNotice =>
      '복사하면 기존 내용을 읽지 않고 이 JSON 보고서만 시스템 클립보드에 씁니다. 신뢰하는 지원 요청에만 붙여넣고 기기나 키보드가 기록을 보관한다면 이후 클립보드를 지워 주세요.';

  @override
  String get diagnosticsCopyAction => '진단 정보 복사';

  @override
  String get diagnosticsNewIncidentAction => '새 사고 ID 만들기';

  @override
  String get diagnosticsRefreshing => '현재 보고서를 유지하면서 새 로컬 보고서를 만드는 중…';

  @override
  String get diagnosticsCopying => '개인정보 없는 JSON 보고서를 시스템 클립보드에 쓰는 중…';

  @override
  String get diagnosticsCopied => '진단 정보를 복사했습니다. 보고서 본문은 자동으로 업로드되지 않았습니다.';

  @override
  String get diagnosticsCopyFailed =>
      '시스템 클립보드에 쓰지 못했습니다. 보고서는 계속 표시되며 본문은 업로드되지 않았습니다.';

  @override
  String get diagnosticsRefreshFailed =>
      '새 사고 ID를 만들지 못했습니다. 이전 보고서는 변경되지 않았습니다.';

  @override
  String get householdActivationTitle => '가족과 함께 시작하기';

  @override
  String get householdActivationBody => '네 단계를 완료해 함께 쓰는 가구 루틴을 만들어 보세요.';

  @override
  String get householdActivationCompleteBody => '가구의 시작 단계 네 개를 모두 완료했습니다.';

  @override
  String get householdActivationLoadingLabel => '가구 시작 진행 상황을 새로 불러오는 중입니다';

  @override
  String householdActivationSummary(int completed, int total) {
    return '시작 단계 $total개 중 $completed개 완료';
  }

  @override
  String get householdActivationAdultTitle => '두 번째 성인 초대하기';

  @override
  String householdActivationAdultProgress(int current, int goal) {
    return '성인 $goal명 중 $current명이 이 가구에 참여했습니다.';
  }

  @override
  String get householdActivationInviteAction => '성인 초대하기';

  @override
  String get householdActivationChoreTitle => '집안일 세 개 만들기';

  @override
  String householdActivationChoreProgress(int current, int goal) {
    return '집안일 $goal개 중 $current개를 만들었습니다.';
  }

  @override
  String get householdActivationCreateAction => '집안일 추가하기';

  @override
  String get householdActivationCompletionTitle => '성인마다 집안일 하나 완료하기';

  @override
  String householdActivationCompletionProgress(int current, int goal) {
    return '성인 $goal명 중 $current명이 집안일을 한 번 이상 완료했습니다.';
  }

  @override
  String get householdActivationReturnTitle => '다른 날 다시 방문하기';

  @override
  String get householdActivationReturnPending =>
      '가구를 만든 첫 현지 날짜가 지난 뒤 오늘 화면을 다시 열어 주세요.';

  @override
  String get householdActivationReturnComplete =>
      '가구를 만든 첫 현지 날짜가 지난 뒤 오늘 화면을 열었습니다.';

  @override
  String get householdActivationStepComplete => '완료';

  @override
  String get householdActivationUnavailableBody =>
      '시작 진행 상황을 불러오지 못했습니다. 오늘의 집안일과 일정은 계속 사용할 수 있으며 이 카드만 다시 시도할 수 있습니다.';

  @override
  String get householdActivationReadOnlyBody =>
      '저장된 오늘 데이터를 표시하는 동안에는 초대와 집안일 추가를 사용할 수 없습니다.';

  @override
  String get weeklyReportTitle => '가구 주간 리포트';

  @override
  String get weeklyReportOpenAction => '가구 주간 리포트 열기';

  @override
  String get weeklyReportLoading => '가구 주간 리포트를 불러오는 중…';

  @override
  String get weeklyReportRefreshing => '가구 주간 리포트를 새로 불러오는 중…';

  @override
  String get weeklyReportUnavailableTitle => '주간 리포트를 불러오지 못했습니다';

  @override
  String get weeklyReportUnavailableBody =>
      '오늘의 집안일은 계속 사용할 수 있습니다. 준비되면 이 리포트만 다시 시도해 주세요.';

  @override
  String weeklyReportWeekRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get weeklyReportLatestWeek => '가장 최근에 끝난 주';

  @override
  String weeklyReportSummary(int completed, int due) {
    return '기한이 있었던 집안일 $due개 중 $completed개 완료';
  }

  @override
  String weeklyReportCardSummary(int completed, int due) {
    return '기한이 있었던 집안일 $due개 중 주가 끝날 때까지 $completed개 완료';
  }

  @override
  String get weeklyReportEmpty => '이번 주에는 기한이 있거나 건너뛴 집안일이 없습니다.';

  @override
  String weeklyReportByWeekEndRate(int percent) {
    return '주가 끝날 때까지 $percent% 완료';
  }

  @override
  String weeklyReportCompletedByWeekEnd(int count) {
    return '주가 끝날 때까지 $count개 완료';
  }

  @override
  String weeklyReportCompletedLater(int count) {
    return '이후에 $count개 완료';
  }

  @override
  String weeklyReportStillOpen(int count) {
    return '아직 진행 중 $count개';
  }

  @override
  String weeklyReportSkipped(int count) {
    return '건너뜀 $count개';
  }

  @override
  String weeklyReportYourContribution(int count) {
    return '내가 완료한 집안일 $count개';
  }

  @override
  String get weeklyReportBreakdownTitle => '구성원별 기여';

  @override
  String weeklyReportMemberContribution(String name, int count) {
    return '$name: $count개 완료';
  }

  @override
  String weeklyReportMemberByWeekEnd(int count) {
    return '주가 끝날 때까지 $count개';
  }

  @override
  String weeklyReportOtherContribution(int count) {
    return '기타 또는 이전 구성원: $count개 완료';
  }

  @override
  String get weeklyReportTruncatedNotice =>
      '현재 가구원은 최대 20명까지 표시하며 나머지 기여는 위 항목에 합산됩니다.';

  @override
  String get weeklyReportOlderWeek => '이전 주';

  @override
  String get weeklyReportNewerWeek => '다음 주';

  @override
  String get runtimePolicyUnavailableTitle => '서비스 상태를 확인하지 못했습니다';

  @override
  String get runtimePolicyUnavailableBody =>
      '저장된 정보는 계속 볼 수 있습니다. 확인이 완료될 때까지 온라인 변경은 실패할 수 있습니다.';

  @override
  String get runtimePolicyReadOnlyTitle => 'KinFlow가 잠시 읽기 전용입니다';

  @override
  String get runtimePolicyReadOnlyBody =>
      '정보 조회와 내보내기, 삭제, 법적 문서, 지원, 진단은 계속 사용할 수 있습니다. 그 밖의 변경은 잠시 중단됩니다.';

  @override
  String get runtimePolicyUpdateTitle => '변경하려면 앱 업데이트가 필요합니다';

  @override
  String runtimePolicyUpdateBody(String version) {
    return 'KinFlow를 $version 이상으로 업데이트해 주세요. 조회와 내보내기, 삭제, 법적 문서, 지원, 진단은 계속 사용할 수 있습니다.';
  }

  @override
  String get runtimePolicyUpdateAction => 'Play 스토어 열기';

  @override
  String get runtimePolicyUpdateUnavailable =>
      'Play 스토어를 열지 못했습니다. 다시 시도하거나 Store 앱에서 KinFlow를 직접 업데이트해 주세요.';

  @override
  String get runtimePolicyFeatureDisabledTitle => '일부 변경이 잠시 중단되었습니다';

  @override
  String runtimePolicyFeatureDisabledBody(String features) {
    return '중단된 기능: $features. 다른 기능과 정보 조회, 내보내기, 삭제, 법적 문서, 지원, 진단은 계속 사용할 수 있습니다.';
  }

  @override
  String get runtimePolicyFeatureHousehold => '가구 관리';

  @override
  String get runtimePolicyFeatureChores => '집안일';

  @override
  String get runtimePolicyFeatureCalendar => '일정';

  @override
  String get runtimePolicyFeatureNotifications => '알림';

  @override
  String get runtimePolicyFeatureProfile => '프로필';

  @override
  String get runtimePolicyFeatureBilling => '구독 및 결제';

  @override
  String get choreTrashTitle => '최근 삭제한 집안일';

  @override
  String get choreTrashOpenAction => '최근 삭제한 집안일 열기';

  @override
  String get choreTrashTodayAction => '오늘로 돌아가기';

  @override
  String get choreTrashLoading => '최근 삭제한 집안일을 불러오는 중…';

  @override
  String get choreTrashEmptyTitle => '최근 삭제한 집안일이 없습니다';

  @override
  String get choreTrashEmptyBody => '삭제한 일회성 집안일이 여기에 표시되며 성인 가구원이 복원할 수 있습니다.';

  @override
  String get choreTrashRefreshFailed =>
      '최근 삭제한 집안일을 새로고침하지 못했습니다. 현재 목록은 계속 표시됩니다.';

  @override
  String choreTrashDeletedAt(String date, String time) {
    return '$date $time에 삭제';
  }

  @override
  String choreTrashDueDate(String date) {
    return '기한 $date';
  }

  @override
  String choreTrashDueDateTime(String date, String time) {
    return '기한 $date $time';
  }

  @override
  String choreTrashAssignee(String name) {
    return '담당 $name';
  }

  @override
  String get choreTrashRestoreAction => '집안일 복원';

  @override
  String get choreTrashRestoringAction => '복원 중…';

  @override
  String get choreTrashRestoreSucceeded => '일회성 집안일을 복원했습니다.';

  @override
  String get choreTrashLoadMoreAction => '삭제한 집안일 더 불러오기';

  @override
  String get choreTrashLoadMoreFailed => '삭제한 집안일을 더 불러오지 못했습니다.';

  @override
  String get choreDeleteUndoAction => '실행 취소';

  @override
  String get choreRestoreOneTimeSucceeded => '삭제한 집안일을 복원했습니다.';

  @override
  String get choreRestoreOneTimeFailed =>
      '삭제한 집안일을 복원하지 못했습니다. 최근 삭제한 집안일에서 다시 시도해 주세요.';

  @override
  String get settingsDeviceCapabilitiesTitle => '기기 기능 상태';

  @override
  String get settingsDeviceCapabilitiesSummary =>
      '이 기기의 지원 여부와 필요한 설정, 안전한 대안을 확인합니다.';

  @override
  String get platformCapabilitiesTitle => '기기 기능 상태';

  @override
  String get platformCapabilitiesIntroTitle => '이 기기에서 KinFlow가 동작하는 방식';

  @override
  String get platformCapabilitiesIntroBody =>
      '이 로컬 상태는 현재 앱 빌드가 선택한 Android 연동과 알림 권한 상태를 보여 줍니다. provider나 서버 연결 상태를 검사하지는 않습니다.';

  @override
  String get platformCapabilitiesPrivacyNote =>
      '이 화면은 계정, 가구, 기기, 결제, 구성 값 또는 provider 오류 상세를 포함하거나 업로드하지 않습니다.';

  @override
  String get platformCapabilitiesSelfCheckTitle => '기능 자체 점검과 복구 계획';

  @override
  String get platformCapabilitiesSelfCheckBody =>
      '먼저 준비된 기능을 확인하고, 설정이나 대안이 필요한 항목은 표시된 복구 순서대로 진행하세요.';

  @override
  String platformCapabilitiesReadyCount(int count) {
    return '준비됨 $count개';
  }

  @override
  String platformCapabilitiesAttentionCount(int count) {
    return '조치 필요 $count개';
  }

  @override
  String platformCapabilitiesAlternativeCount(int count) {
    return '대안 또는 제한 $count개';
  }

  @override
  String get platformCapabilitiesRecoveryHeading => '권장 복구 순서';

  @override
  String get platformCapabilitiesRecoveryEmpty =>
      '모든 기본 기능이 준비되었습니다. 필요한 경우 안전한 대안도 계속 사용할 수 있습니다.';

  @override
  String platformCapabilitiesRecoveryStep(int number) {
    return '$number단계';
  }

  @override
  String get platformCapabilitiesSelfCheckAction => '알림 설정 다시 확인';

  @override
  String get platformCapabilitiesSelfCheckRefreshing => '알림 설정 확인 중…';

  @override
  String get platformCapabilitiesSelfCheckScope =>
      '이 동작은 권한을 요청하거나 시스템 설정을 열지 않습니다. 현재 권한이 바뀌었다면 기존 알림 조정자가 기기 연결을 안전하게 정리하거나 복원할 수 있습니다.';

  @override
  String get platformCapabilitiesSelfCheckSucceeded =>
      '알림 권한과 기기 연결 상태를 다시 확인했습니다.';

  @override
  String get platformCapabilitiesSelfCheckFailed =>
      '지금은 알림 설정을 확인할 수 없습니다. 알림함과 표시된 안전한 대안은 계속 사용할 수 있습니다.';

  @override
  String get platformCapabilitiesProviderLabel => '선택된 연동';

  @override
  String get platformCapabilitiesFallbackLabel => '안전한 대안';

  @override
  String get platformCapabilitiesNotificationTitle => '알림 전달';

  @override
  String get platformCapabilitiesBillingTitle => 'Google Play 결제';

  @override
  String get platformCapabilitiesSecureStorageTitle => '암호화 로컬 저장소';

  @override
  String get platformCapabilitiesExternalLinksTitle => '외부 링크와 다운로드';

  @override
  String get platformCapabilitiesBackgroundTitle => '백그라운드 전달';

  @override
  String get platformCapabilitiesStateAvailable => '지원됨';

  @override
  String get platformCapabilitiesStateActionRequired => '설정 필요';

  @override
  String get platformCapabilitiesStateLimited => '의도된 제한';

  @override
  String get platformCapabilitiesStateFallbackOnly => '대안 사용 중';

  @override
  String get platformCapabilitiesStateTemporaryIssue => '일시 문제';

  @override
  String get platformCapabilitiesProviderFirebaseMessaging =>
      'Android용 Firebase Messaging';

  @override
  String get platformCapabilitiesProviderRevenueCatPlay =>
      'RevenueCat과 Google Play';

  @override
  String get platformCapabilitiesProviderAndroidKeystore =>
      'Android Keystore 기반 저장소';

  @override
  String get platformCapabilitiesProviderAndroidUriLauncher =>
      'Android 시스템 링크 처리기';

  @override
  String get platformCapabilitiesProviderBrowserUriLauncher =>
      '브라우저의 신뢰할 수 있는 링크 처리기';

  @override
  String get platformCapabilitiesProviderFirebaseBackground =>
      'Firebase Android 백그라운드 처리기';

  @override
  String get platformCapabilitiesProviderUnavailable => '이 앱 빌드에 구성되지 않음';

  @override
  String get platformCapabilitiesFallbackInbox => '내구성 있는 앱 내 알림함';

  @override
  String get platformCapabilitiesFallbackInboxAndEmail =>
      '내구성 있는 앱 내 알림함과 설정된 일반 이메일';

  @override
  String get platformCapabilitiesFallbackEntitlement =>
      '서버 확인 이용 권한과 읽기 전용 구독 상태';

  @override
  String get platformCapabilitiesFallbackReauthentication =>
      '영구 오프라인 데이터 없이 다시 인증';

  @override
  String get platformCapabilitiesFallbackGuidance => '화면 안내와 로컬 진단 정보';

  @override
  String get platformCapabilitiesFallbackServerNotifications =>
      '서버 알림 처리와 앱 내 알림함';

  @override
  String get platformCapabilitiesNotificationAvailable =>
      'Android 푸시를 지원합니다. 중요한 이벤트는 알림 화면에도 계속 남습니다.';

  @override
  String get platformCapabilitiesNotificationNotDetermined =>
      '아직 알림 허용 여부를 선택하지 않았습니다. 알림 화면에서 선택할 수 있으며 앱 내 알림함은 계속 동작합니다.';

  @override
  String get platformCapabilitiesNotificationDenied =>
      'KinFlow의 시스템 알림이 꺼져 있습니다. 알림 화면에서 선택을 확인할 수 있으며 앱 내 알림함은 계속 동작합니다.';

  @override
  String get platformCapabilitiesNotificationRuntimeUnavailable =>
      '현재 실행 환경에서 Android 알림 전달을 사용할 수 없습니다. 중요한 이벤트는 앱 내 알림함에 계속 남습니다.';

  @override
  String get platformCapabilitiesNotificationTemporary =>
      '알림 연동에서 일시적인 로컬 문제가 보고되었습니다. 기존 알림함 내용은 계속 확인할 수 있습니다.';

  @override
  String get platformCapabilitiesNotificationNotConfigured =>
      '이 앱 빌드에는 푸시 전달이 구성되지 않았습니다. 중요한 이벤트는 앱 내 알림함에 계속 남습니다.';

  @override
  String get platformCapabilitiesBillingAvailable =>
      'Google Play 구매를 지원합니다. 가구 이용 권한은 계속 서버에서 확인된 상태를 따릅니다.';

  @override
  String get platformCapabilitiesBillingNotConfigured =>
      '이 앱 빌드에서는 Store 구매를 사용할 수 없습니다. 기존 서버 확인 이용 권한과 구독 정보는 계속 읽을 수 있습니다.';

  @override
  String get platformCapabilitiesSecureStorageAvailable =>
      '민감한 세션과 지원되는 오프라인 snapshot은 Android 암호화 저장소를 사용합니다.';

  @override
  String get platformCapabilitiesSecureStorageNotConfigured =>
      '영구 암호화 오프라인 데이터를 사용할 수 없습니다. 다시 인증하고 새 온라인 데이터를 읽는 방식으로 대체합니다.';

  @override
  String get platformCapabilitiesExternalLinksAvailable =>
      '신뢰된 지원, 정책, Store, 내보내기 링크를 Android 시스템 처리기로 열 수 있습니다.';

  @override
  String get platformCapabilitiesExternalLinksNotConfigured =>
      '이 앱 빌드에서는 외부 링크를 열 수 없습니다. 화면 안내와 진단 정보는 계속 사용할 수 있습니다.';

  @override
  String get platformCapabilitiesBackgroundLimited =>
      'Android가 백그라운드 푸시 진입 이벤트를 받을 수 있지만 전달의 최종 기준은 서버 파이프라인입니다.';

  @override
  String get platformCapabilitiesBackgroundNotConfigured =>
      '클라이언트 백그라운드 전달이 구성되지 않았습니다. 서버 처리와 앱 내 알림함이 대안으로 유지됩니다.';

  @override
  String get platformCapabilitiesSafeUnknownState =>
      '이 기능 상태를 확인할 수 없습니다. 표시된 안전한 대안과 로컬 진단 정보를 사용해 주세요.';

  @override
  String get platformCapabilitiesOpenNotificationsAction => '알림 열기';

  @override
  String get platformCapabilitiesOpenSubscriptionAction => '구독 설정 열기';

  @override
  String get platformCapabilitiesOpenDiagnosticsAction => '진단 정보 열기';
}
