# Phase 06 WP06-02A Subscription Settings and Paywall Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 범위: `FR-SUB-001`, `FR-SUB-002`, `FR-SUB-003`, `FR-SUB-008`, `FR-SET-006`
- 구현 수직 조각: server entitlement status → Store-localized offering → active-household confirmation → purchase/restore state UI → pending/conflict recovery → Store management and public policy links
- 실계정, hosted RevenueCat/Google Play, license tester, sandbox transaction, 실제 기기 검증은 사용자 우선순위에 따라 **NOT RUN / 마지막 Billing Gate**다.

## 요구사항과 동작 증거

| 요구사항 | 로컬 구현 증거 | 남은 Gate |
|---|---|---|
| FR-SUB-001 | current Store offering의 exact localized price와 derived period를 표시하고 package/product ID와 hardcoded price/limits를 표시하지 않는다. | D-027 실제 product/price/trial/limits와 Store copy 승인 |
| FR-SUB-002 | authoritative profile household가 billing context와 같고 current role이 Owner/Admin인 경우에만 household·가격·기간·갱신·server confirmation 확인 뒤 purchase를 호출한다. cancelled/pending/failure는 별도 UX다. | actual Play transaction, provider ownership, webhook timing, device |
| FR-SUB-003 | restore 확인, empty, pending, conflict를 분리하고 conflict는 자동 이전 없이 aggregate review/configured support만 제공한다. | reinstall, 다른 Store account, actual restore sandbox/device |
| FR-SUB-008 | server-declared billing owner에게 source별 Google Play 또는 Apple 관리 화면을 제공하며 enum allowlist HTTPS 외부 앱만 연다. | actual Play activity와 future Apple runtime/device |
| FR-SET-006 | active household, plan, lifecycle, source, billing-owner 관계, 갱신/기간 종료일, server verified date, restore/manage 경로를 설정 화면에서 제공한다. | actual provider lifecycle, cross-device freshness, screen reader/device |

Store success/client snapshot은 entitlement 권위가 아니다. 기존 `BillingFlowController`가 newer server Plus와 current billing-owner를 확인해야만 화면 상태가 Plus로 바뀐다. Store/server pending에서는 purchase/restore CTA가 사라지고 explicit server refresh만 남는다.

## DB와 API 영향

- 신규 migration, RPC, Edge Function, RLS, grant 또는 server payload 변경은 없다.
- 기존 WP06-01/04/05/06 server-authoritative entitlement, assignment, reconciliation, feature-enforcement 계약을 그대로 소비한다.
- 외부 링크는 앱 내부 application port의 enum만 받으며 remote/user URL, provider customer/transaction ID 또는 receipt를 입력으로 받지 않는다.
- 상세 client 계약: `docs/contracts/subscription-settings.yaml.md` version `2026-08-08-wp06-02a`.

## 주요 구현 파일

- 화면/상태
  - `apps/kinflow_app/lib/features/billing/presentation/screens/subscription_settings_screen.dart`
  - `apps/kinflow_app/lib/features/billing/presentation/providers/billing_providers.dart`
  - `apps/kinflow_app/lib/features/settings/presentation/screens/settings_screen.dart`
  - `apps/kinflow_app/lib/app/router/app_router.dart`
- 외부 링크 경계/조립
  - `apps/kinflow_app/lib/features/billing/application/ports/billing_external_link_launcher.dart`
  - `apps/kinflow_app/lib/features/billing/application/unavailable_billing_external_link_launcher.dart`
  - `apps/kinflow_app/lib/infrastructure/url_launcher/url_launcher_billing_external_link_launcher.dart`
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
- 지역화
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - generated `app_localizations*.dart`
- 자동화
  - `apps/kinflow_app/test/features/billing/subscription_settings_widget_test.dart`
  - `apps/kinflow_app/test/infrastructure/url_launcher_billing_external_link_launcher_test.dart`
  - `apps/kinflow_app/test/support/fakes/fake_subscription_dependencies.dart`
  - `apps/kinflow_app/test/app/auth_dependencies_test.dart`
  - `apps/kinflow_app/test/features/settings/household_privacy_settings_widget_test.dart`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused Flutter | subscription widget + external launcher + settings tile + auth composition + localization contract | PASS, 26 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 768 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 477 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 0 output / generated drift 0 |
| Localization | exact EN/KO/EN-XA coverage, pseudo ≥30%, ICU period plural, compact 200% widget | PASS |
| Architecture | full suite dependency boundary (presentation/application/domain/data/infrastructure) | PASS, violation 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| External destinations | exact Store URL, policy origin rewrite, no query/fragment, invalid HTTP/query, open false/exception | PASS |
| Contract parse | fenced subscription settings YAML | PASS, 11 states / 5 destinations |
| Matrix parse | billing 38, requirements 116, global tests 63 declared rows and uniform columns | PASS |
| Whitespace | `git diff --check` | PASS |

초기 정적 실행은 새 widget test의 불필요한 `dart:async` import 한 건을 fatal info로 탐지해 제거했다. 여러 `dart run` 명령을 동시에 시작한 첫 codegen 검사는 native build-hook 임시 dylib 충돌로 실패했으며, 단독 재실행에서 0 output으로 통과했다. 기능·생성 코드 실패로 해석하지 않는다.

## UI 상태와 자동화 범위

- Owner Free: household 이름, exact `₩4,900` fake Store price/월 period, provider ID 비노출, purchase 확인과 cancelled notice.
- Member Free: status read는 유지하고 purchase/restore callback은 `null`, Store call 0.
- Plus billing owner: purchase/restore 미표시, source-matched Google Play management action.
- Store pending: purchase/restore 미표시, refresh 하나만 노출, Store purchase call 1.
- assignment conflict: Store call 0, identifier 없는 aggregate copy, remediation request open.
- restore empty: 별도 terminal state와 safe return.
- catalog failure: server Free status와 role-gated restore를 보존하고 offer/purchase만 닫는다. unsupported Store runtime에서는 restore도 닫는다.
- EN-XA compact 320×568, 200% text: scrollable, action 48dp 이상, overflow exception 0.

## 외부 링크 보안

- 허용 destination은 Google Play subscriptions, Apple subscriptions, public origin `/terms`, public origin `/privacy`, configured support의 다섯 enum뿐이다.
- URL은 `https`, non-empty host, empty user-info/query/fragment 조건을 모두 만족해야 한다.
- public policy URL은 configured origin에서 새 `Uri`를 구성해 기존 path/query/fragment를 상속하지 않는다.
- UI나 billing state에서 customer ID, transaction/receipt, purchaser/member ID, package/product ID를 URL·copy·query에 넣지 않는다.
- external launcher 실패는 entitlement, assignment, purchase, restore 상태를 변경하지 않는다.
- 공식 기준 대조: Google Play Help의 subscriptions destination과 Apple StoreKit/account-deletion guidance의 subscriptions management URL이 local allowlist와 일치함을 2026-08-08 확인했다.

## 수동·실환경 검증

다음은 **NOT RUN**이다.

- RevenueCat public key/real offering, Google Play license tester와 internal track purchase/cancel/restore
- Store pending, network loss, delayed webhook, explicit refresh와 duplicate tap 실기기 흐름
- 다른 Play account/reinstall/다른 KinFlow account/다른 household conflict
- grace, account hold, expiry, revoke/refund와 실제 manage activity
- 실제 locale price/trial/base plan/renewal copy와 최종 D-027 member/recurrence limits
- Android TalkBack, 200% system font, keyboard, tablet/split-screen
- Apple sandbox/TestFlight/iOS runtime; Android MVP에서는 URL contract만 유지

로컬 fake Store 결과나 공식 URL 확인을 실제 계정, hosted entitlement 또는 실제 기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- D-027의 가격, trial, Free/Plus 수치와 activation 승인 전에는 catalog fake 외 숫자 정책을 확정할 수 없다.
- Google Play product/base-plan/offer token과 RevenueCat offering 구성 오류는 실제 console/sandbox 전에는 검출할 수 없다.
- external web management는 사용자가 올바른 Store account에 로그인했는지 앱이 보장하지 못하므로 copy와 server refresh를 유지한다.
- billing-owner와 household Owner/Admin은 독립적이다. 구매/복원은 household 관리 역할을 요구하고 기존 구독 관리는 server billing-owner만 허용한다.
- Web/manual-support source의 self-service management는 별도 승인된 provider 계약 전까지 노출하지 않는다.

## Rollback

- `AppRoutes.subscription`과 settings tile/screen을 제거하면 기존 Today·settings·billing lifecycle과 server enforcement는 유지된다.
- `billingExternalLinkLauncherProvider` override를 unavailable fallback으로 되돌리면 모든 외부 링크가 fail closed되고 entitlement read는 유지된다.
- RevenueCat key/catalog가 unavailable이면 현재 구현처럼 server status만 남기고 purchase/restore를 닫는다.
- migration rollback은 필요하지 않다. DB/API/schema 변경이 없기 때문이다.

## 다음 단계

- 기능 우선순위상 다음 로컬 vertical slice를 계속 구현한다.
- D-027 승인과 마지막 Billing Gate에서만 real offering/license tester/hosted reconciliation/device matrix를 실행한다.
