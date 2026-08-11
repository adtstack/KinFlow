# Phase 07 WP07-07A Legal, Privacy, and Support Hub Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07-07 전체와 G7 완료는 아님
- 범위: `FR-SET-003`, `FR-SET-004`, `FR-SET-005`, `FR-PLAT-001`, `FR-PLAT-002`
- 구현 수직 조각: settings tile → authenticated hub route → fixed legal/privacy/configured support destination → external launch state → existing export/deletion privacy shortcuts
- DB migration/API 변경: 없음

## 수용 기준

| 기준 | 결과 |
|---|---|
| 설정에서 terms/privacy/support에 접근 가능 | PASS — 별도 Help and legal section과 `/settings/legal-support` route에서 세 action 제공 |
| 법률 문서 본문·버전 authority가 명확함 | PASS — 각 외부 문서의 게시일/버전이 authoritative하며 API contract version은 법률 버전이 아니라고 명시 |
| 필요성이 승인되지 않은 동의를 만들지 않음 | PASS — informational-only 화면이며 consent mutation/API/DB insert 없음. 향후 필요 시 별도 versioned server 계약 Gate로 분리 |
| privacy control 접근 | PASS — 기존 개인 데이터 export와 계정 삭제 route 바로가기 제공 |
| URL injection·context leakage 차단 | PASS — enum-only input, fixed `/terms`·`/privacy`, exact configured support, HTTPS/no user-info/query/fragment |
| 외부 링크 실패가 앱 상태를 변경하지 않음 | PASS — unavailable/exception은 localized retryable status만 표시하며 account/privacy/consent state mutation 없음 |
| 중복 실행 차단 | PASS — 한 external launch가 pending인 동안 세 external CTA 모두 disabled, 추가 launcher call 0 |
| 접근성·국제화 | PASS — EN/KO/EN-XA exact coverage, live status, scrollable compact 200% text, action 48dp 이상, overflow 0 |

## 구현 파일

- application port/fallback:
  - `apps/kinflow_app/lib/features/settings/application/ports/legal_support_resource_launcher.dart`
  - `apps/kinflow_app/lib/features/settings/application/unavailable_legal_support_resource_launcher.dart`
- presentation:
  - `apps/kinflow_app/lib/features/settings/presentation/providers/legal_support_providers.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/screens/legal_support_screen.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/screens/settings_screen.dart`
- composition/routing:
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
  - `apps/kinflow_app/lib/app/router/app_router.dart`
- infrastructure:
  - `apps/kinflow_app/lib/infrastructure/url_launcher/trusted_external_uri_policy.dart`
  - `apps/kinflow_app/lib/infrastructure/url_launcher/url_launcher_legal_support_resource_launcher.dart`
  - `apps/kinflow_app/lib/infrastructure/url_launcher/url_launcher_billing_external_link_launcher.dart`
- localization/tests:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/test/features/settings/legal_support_widget_test.dart`
  - `apps/kinflow_app/test/infrastructure/url_launcher_legal_support_resource_launcher_test.dart`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused Flutter | legal support widget/URI adapter, existing billing URI, settings tile, auth composition, localization contract | PASS, 25 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 775 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 485 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 0 output / generated drift 0 |
| Localization | exact EN/KO/EN-XA coverage, pseudo ≥30%, compact 200% widget | PASS |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| External destination | fixed document paths, exact support, inherited query/fragment removal, HTTP/user-info/query/fragment rejection, open false/exception | PASS |
| Contract parse | fenced `legal-support-hub.yaml` | PASS, version/destination contract valid |
| Matrix parse | fenced CSV matrix 13개 declared-row/column 검사 | PASS, requirements 116×18 / tests 64×11 |
| Whitespace | `git diff --check` | PASS |

최초 focused test 시도는 Flutter test runner의 loopback socket bind가 sandbox에서 거부되어 test body를 실행하지 못했다. 같은 명령을 허용된 local loopback 환경에서 재실행해 25개를 통과했다. 최초 localization 생성은 결과를 쓴 뒤 사용자 홈 telemetry mtime 갱신에서 sandbox 오류가 났으며, 격리된 `XDG_CONFIG_HOME`으로 재실행해 exit 0과 generated drift 0을 확인했다. 두 건 모두 제품 코드 실패로 계산하지 않는다.

## 보안·개인정보 검토

- presentation과 launcher 호출에는 URL 문자열, 사용자 ID, household/member ID, 이메일, billing identifier 또는 diagnostic identifier가 없다.
- public document destination은 configured origin에서 path를 다시 구성하므로 base의 기존 path/query/fragment를 상속하지 않는다.
- invalid support configuration은 외부 앱을 호출하지 않고 unavailable로 닫힌다.
- opener exception detail은 UI, logger 또는 state에 반사하지 않는다.
- existing billing launcher도 같은 shared URI policy를 사용하며 회귀 테스트가 통과했다.
- 기존 `consent_records` 골격에 client write grant나 자동 insert를 추가하지 않았다.

## 수동·실환경 검증

다음은 **NOT RUN**이다.

- owned production HTTPS host의 `/terms`, `/privacy`, configured support 실제 응답과 redirect/CSP/content type
- 최종 법률 검토를 받은 본문, 정확한 publication/version, 지원 SLA와 연락 주체
- 실제 browser chooser, browser 없음, captive portal, 완전 offline, 복귀 후 앱 상태
- Android TalkBack/iOS VoiceOver, system 200% font, keyboard, tablet/split-screen
- versioned consent가 실제로 필요한지에 대한 product/legal 결정 및 grant/withdraw/not-required lifecycle

로컬 fake opener와 정적 URL parser 통과를 실제 웹 게시, 법률 승인 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- 현재 dev/prod example의 public/support URL은 placeholder이며 실제 문서 페이지는 WP07-07 후속 작업이다.
- 공개 문서가 redirect나 query 기반 ticket form을 요구하면 현재 엄격한 no-query 계약과 충돌한다. 개인정보 첨부 없는 고정 HTTPS landing page를 별도 구성하는 방식을 우선한다.
- 정책 버전을 API `CONTRACT_VERSION`과 결합하면 잘못된 동의 이력을 만들 수 있으므로 별도 policy manifest/contract 승인 전에는 표시·기록하지 않는다.
- 법률 검토가 명시적 동의를 요구하면 current-user server authorization, exact consent type/version, withdrawal, immutable audit와 retention을 함께 설계해야 한다.

## Rollback

- `AppRoutes.legalSupport`, settings tile과 screen을 제거하면 기존 export, account deletion, subscription settings는 유지된다.
- `legalSupportResourceLauncherProvider`를 unavailable fallback으로 되돌리면 external resource만 fail closed한다.
- shared URI policy를 이전 billing-local validator로 되돌릴 수 있으며 기존 destination 의미는 바뀌지 않는다.
- DB/API migration이 없어 data rollback은 없다.

## 다음 단계

- 기능 우선순위상 다음 로컬 vertical slice를 계속 구현한다.
- WP07-07에서 accessible no-JS public terms/privacy/support/deletion pages, publication version, owned domain과 link tests를 구현하되 최종 법률 copy 승인은 별도 Gate로 유지한다.
- 실계정·실browser·실기기 검증은 사용자 요청대로 마지막 통합 Gate에서 수행한다.
