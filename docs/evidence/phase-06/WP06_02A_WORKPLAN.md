# Phase 06 WP06-02A Subscription Settings and Paywall Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 시작일: 2026-08-08
- 수직 조각: server entitlement status → Store-localized offering → explicit active-household confirmation → purchase/restore state machine → server confirmation recovery → platform subscription management and policy links

## Requirements and decisions

- `FR-SUB-001`: paywall 가격과 기간은 Store catalog가 반환한 값을 그대로 표시하며 앱에 가격을 하드코딩하지 않는다.
- `FR-SUB-002`: 구매는 authenticated identity와 active household에만 연결하고 pending/provider/server failure를 구분한다.
- `FR-SUB-003`: restore empty/pending/conflict/found를 구분하고 충돌 시 자동 이전이나 재구매를 유도하지 않는다.
- `FR-SUB-008`: Google Play/App Store 관리 화면으로 가는 신뢰된 고정 경로와 실패 안내를 제공한다.
- `FR-SET-006`: 적용 household, lifecycle, 갱신/종료일, billing-owner 여부, 복원/관리 경로를 한 화면에서 보여준다.
- `D-024`, `D-025`, `D-028`, `D-047`: provider snapshot이나 Store 성공은 Plus 권위가 아니며 newer server entitlement만 최종 상태다.
- `D-027`: 가격과 Free/Plus 수치 정책을 임의로 만들지 않는다. catalog가 없으면 기존 entitlement read는 유지하고 구매만 닫는다.
- offerings 실패만으로 restore를 닫지 않는다. Store runtime 자체가 unsupported인 경우에만 restore를 비활성화하고, 그 외 실패는 기존 controller의 bounded restore 결과로 처리한다.

## Security and billing boundary

- 화면은 global billing lifecycle이 서버에서 먼저 읽은 active-household entitlement만 표시한다.
- purchase/restore CTA는 authoritative profile household ID가 billing context와 일치하고 current role이 Owner/Admin일 때만 활성화한다.
- 구매 전에 active household 이름, Store-localized price/period, 자동 갱신 가능성, server confirmation 경계를 명시적으로 확인한다.
- assignment conflict는 Store 호출 전에 정지하고 반대편 user/household/provider/customer 식별자를 노출하지 않는다.
- Store success/pending 이후 중복 구매 CTA를 숨기고 explicit server refresh만 제공한다.
- 관리/약관/개인정보/지원 링크는 allowlisted HTTPS destination enum으로만 열며 URL, query, token을 UI 입력에서 만들지 않는다.
- provider package/product ID는 UI copy, log, analytics에 표시하지 않는다.

## Flutter impact

- provider-neutral `BillingExternalLinkLauncher` port와 unavailable fallback을 추가한다.
- infrastructure adapter는 Google Play subscriptions, Apple subscriptions, public `/terms`, public `/privacy`, configured support URI만 외부 앱으로 연다.
- `SubscriptionSettingsScreen`은 loading/ready/preflight/purchase/restore/store-pending/server-pending/empty/conflict/failure 상태를 완전하게 렌더링한다.
- status card는 household, plan/status/source, billing owner, renewal/period end와 downgrade data preservation을 보여준다.
- paywall은 Store price/period와 accepted benefit categories를 보여주고 Owner/Admin household confirmation 뒤 controller action을 호출한다.
- 설정 목록과 authenticated settings route에 구독 화면을 추가한다.
- EN/KO/EN-XA, stable keys, semantics, 200% text scroll layout을 검증한다.

## Automated evidence plan

- link adapter: exact trusted URI, no token/query construction, open false/exception mapping, unsupported action absence.
- widget: Free catalog/price, Owner purchase confirmation, Member disabled, Plus lifecycle/manage, restore empty, assignment/restore conflict remediation, Store/server pending duplicate-action suppression, catalog unavailable entitlement preservation, failure recovery, EN/KO/EN-XA 200% layout.
- composition: live/unavailable launcher selection and provider override.
- full Flutter analyzer/format/test/codegen/localization/architecture/secret/whitespace regression.
- DB migration은 없으며 기존 full pgTAP 결과를 재사용하지 않고 이번 client-only 조각에 맞는 Flutter 전체 회귀를 증거로 남긴다.

## Manual and deferred evidence

- RevenueCat/Google Play 실제 product/price/trial, license tester purchase/restore, Play manage screen, network-loss pending, refund/expiry는 사용자 요청대로 마지막 Billing Gate에서 검증한다.
- Apple/iOS는 D-054에 따라 현재 Android MVP 범위 밖이며 URL contract만 local test한다.
- 최종 가격, trial, limits, Store copy는 D-027/provider console 승인 전 임의로 채우지 않는다.

## Local completion summary

- Store-localized price/period paywall, household-scoped confirmation, Owner/Admin fail-closed gate와 purchase/restore state UI를 구현했다.
- pending duplicate suppression, conflict remediation/support, restore-empty, catalog unavailable, server refresh 및 billing-owner Store management를 구현했다.
- trusted external destination adapter와 unavailable fallback을 app composition에 연결했다.
- focused 26 tests와 full Flutter regression, analyzer/format/codegen/localization/public-config/secret checks가 통과했다.
- 실계정, hosted provider, Store sandbox와 실기기 항목은 이 workplan의 완료 조건에서 의도적으로 제외하고 마지막 Billing Gate에 유지한다.

## Rollback

- subscription route/tile과 external-link provider override를 제거해도 billing lifecycle과 server entitlement enforcement는 유지된다.
- RevenueCat public key가 없거나 adapter가 unavailable이면 화면은 server status만 표시하고 purchase/restore를 닫는다.
- management/policy link failure는 결제 상태를 변경하지 않으며 support 경로를 유지한다.
