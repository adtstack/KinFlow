# Phase 07 WP07-07A Legal, Privacy, and Support Hub Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07-07 전체와 G7 완료는 아님
- 수직 조각: settings entry → legal/privacy/support hub → enum-only trusted external launch → privacy request shortcuts → localized launch state
- 완료 증거: `docs/evidence/phase-07/WP07_07A_EVIDENCE.md`

## Requirements and decisions

- `FR-SET-005`: 인증된 사용자가 설정에서 이용약관, 개인정보 처리방침, 지원 경로에 접근할 수 있어야 한다.
- `FR-SET-003` / `FR-SET-004`: 개인정보 허브에서 기존 개인 데이터 내보내기와 계정 삭제 흐름으로 바로 이동할 수 있어야 한다.
- `D-005`: 법률·지원 문서의 authority는 Flutter에 복제한 본문이 아니라 별도 공개 정적 사이트다.
- `FR-PLAT-001` / `FR-PLAT-002`: EN/KO/EN-XA, 200% text, scrollable layout, 48dp action target과 live status를 유지한다.

## Product and legal boundary

- terms와 privacy는 configured public-site origin의 고정 `/terms`, `/privacy` 경로만 연다.
- support는 configured support URI만 열며 화면·사용자 입력·계정 상태로 URL을 조립하지 않는다.
- 각 공개 문서의 게시일과 버전은 해당 문서가 authoritative하다. API `CONTRACT_VERSION`을 법률 문서 버전으로 오인해 표시하지 않는다.
- 이 informational hub는 동의를 요구하거나 기록하지 않는다. 특정 버전의 명시적 동의가 법률·제품 검토에서 필요해질 때만 별도 server-mediated consent 계약과 UI를 추가한다.
- 최종 법률 문구, 게시 정책 버전, 지원 SLA와 실제 공개 사이트 배포는 WP07-07 후속 Gate에서 승인한다.

## Security and privacy boundary

- presentation에는 URL을 전달하지 않고 allowlisted enum만 전달한다.
- launcher는 HTTPS, non-empty host, empty user-info/query/fragment를 요구한다.
- public document URI는 configured origin에서 새로 만들며 기존 path/query/fragment를 상속하지 않는다.
- support URI에 query, fragment, user-info 또는 HTTP가 있으면 fail closed한다.
- 지원 링크에 사용자 ID, household ID, 이메일, 사건 내용 또는 진단 정보를 자동 첨부하지 않는다.
- launch 실패는 계정, 개인정보 요청, 동의 또는 다른 앱 상태를 변경하지 않는다.

## Database and API impact

- DB migration 없음.
- Edge/API 변경 없음.
- 기존 `consent_records` 참조 골격에 client insert 권한을 추가하지 않는다.
- 공개 사이트 문서 본문과 게시 버전은 이 조각에서 생성하거나 배포하지 않는다.

## Flutter impact

- settings application port에 terms/privacy/support enum과 opened/unavailable/failed 결과를 추가한다.
- unavailable composition은 모든 destination을 fail closed한다.
- `url_launcher` adapter는 fixed path/configured URI만 외부 application mode로 연다.
- settings에 별도 Help and legal section과 route를 추가한다.
- hub는 각 문서의 authority, informational-only consent 경계, 지원 요청의 개인정보 비첨부를 설명한다.
- 중복 tap 동안 모든 외부 action을 비활성화하고 opening/success/failure를 accessibility live region으로 알린다.

## Automated evidence plan

- adapter: exact `/terms`, `/privacy`, configured support, inherited query/fragment 제거, HTTP/user-info/query/fragment 거부, opener false/throw mapping.
- widget: 세 destination enum mapping, no raw URL, single-flight, unavailable recovery, privacy shortcuts, settings tile.
- accessibility/i18n: EN/KO/EN-XA exact coverage, compact 320×568 at 200%, 48dp action target, overflow 0.
- composition: live adapter와 unavailable fail-closed dependency.
- focused tests 후 full Flutter regression, analyzer, format, codegen, localization, secret scan, matrix/contract parse와 whitespace 검사를 실행한다.

## Manual and deferred evidence

- 실제 owned HTTPS public site, final legal copy/version, support destination과 browser behavior는 마지막 통합 Gate에서 검증한다.
- 법률 검토가 versioned consent를 요구하면 consent type/version/status, recent auth, withdrawal semantics, immutable audit와 retention을 별도 계약으로 승인한다.
- TalkBack/VoiceOver, physical-device external browser, offline captive portal과 OS-specific browser chooser는 마지막 실기기 Gate에 둔다.

## Rollback

- route와 settings tile을 제거하면 기존 개인정보 내보내기·계정 삭제·구독 흐름은 유지된다.
- launcher provider를 unavailable fallback으로 바꾸면 모든 외부 링크만 fail closed한다.
- DB/API migration이 없으므로 data rollback은 없다.
