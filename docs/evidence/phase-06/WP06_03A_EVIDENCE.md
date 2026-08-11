# Phase 06 WP06-03A Provider-Neutral Billing Flow Evidence

- Work Package: WP06-03A — provider-neutral catalog/identity/purchase/restore contract and server-authoritative confirmation state machine
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2
- 결과: **WP06-03A LOCAL AUTOMATED PASS / REVENUECAT·STORE·PAYWALL·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP06-03 / FR-SUB-001 | PASS FOR PROVIDER-NEUTRAL CATALOG / OVERALL PARTIAL | Offering/package/product identifier, Store-localized price와 period를 strict immutable value로 운반한다. 실제 product ID·가격·통화·trial/annual policy나 paywall은 넣지 않았다. |
| WP06-03 / D-024 / FR-SUB-002 | PASS FOR LOCAL IDENTITY AND PURCHASE FLOW / OVERALL PARTIAL | exact authenticated `AuthUserId` bind와 returned identity 일치를 요구하고 cancel/pending/retryable/final/store-success 결과를 분리한다. RevenueCat SDK와 Store transaction은 남았다. |
| WP06-03 / FR-SUB-003 | PASS FOR LOCAL RESTORE FLOW / OVERALL PARTIAL | restore empty/pending/records-found/conflict를 구분하고 provider identity mismatch와 다른 billing owner를 fail closed한다. 실제 reinstall·Store account·support UI는 남았다. |
| WP06-03 / D-025 / FR-SUB-005 | PASS FOR CLIENT SERVER-AUTHORITY GATE / OVERALL PARTIAL | Store success나 client snapshot만으로 Plus를 열지 않는다. current household의 newer server Plus와 current-user billing-owner 상태가 확인돼야 purchase confirmed다. |
| WP06-03 / NFR-REL-01 | PASS FOR NEW CLIENT SURFACE | duplicate purchase/restore를 한 provider call로 합치고 bounded confirmation 후에도 pending을 유지하며 explicit refresh로 회복한다. |
| WP06-03 / D-049 / NFR-SEC-01 | PASS FOR IDENTITY-SWITCH BOUNDARY | account/household switch, logout과 dispose가 previous generation을 invalidate한다. account 변경 시 identity clear 실패는 rebind 전에 닫힌다. |
| WP06-03 / D-047 / NFR-PLAT-001 / NFR-PLAT-002 | PASS FOR BILLING SLICE / OVERALL PARTIAL | domain/application/port는 Flutter, Riverpod, Supabase와 RevenueCat import가 없고 unavailable/catalog-failure fallback이 server entitlement를 보존한다. |
| WP06-03 / NFR-PRIV-01 | PASS FOR NEW CLIENT SURFACE | receipt, transaction/customer reference, raw provider error, email, family content나 secret을 contract/state/test에 넣지 않았다. |

## Implemented Contract

- `BillingPort`는 availability, identity bind/clear, catalog, purchase, restore와 provider snapshot stream만 노출한다. 외부 SDK type과 raw error는 application/domain 밖에 머문다.
- catalog는 offering/package/product ID 중복과 malformed identifier를 거부하고 current offering을 exact하게 요구한다. collections는 defensive copy + unmodifiable view다.
- `BillingFlowController.synchronize`는 server entitlement를 먼저 읽는다. Store capability가 없거나 catalog load가 실패해도 server Free/Plus 상태는 남고 새 purchase는 port 호출 전에 차단된다. capability 자체가 unavailable이면 restore도 port 호출 전에 차단된다.
- purchase는 `ready → purchasing → cancelled | storePending | serverConfirmationPending → serverConfirmed`로 이동한다. confirmation은 Plus, billing owner와 purchase 전보다 새로운 version 또는 `verifiedAt`을 모두 확인한다.
- restore는 `ready → restoring → empty | conflict | storePending | serverConfirmationPending → serverConfirmed`로 이동한다. existing Plus owner는 restore confirmation에 허용하지만 다른 owner는 conflict다.
- bounded delay policy는 최대 wait 7개, 개별 30초, 합계 2분이며 immutable하다. timeout은 pending을 유지하고 explicit server refresh가 같은 provider purchase를 반복하지 않고 회복한다.
- matching client snapshot은 server refetch만 유발한다. mismatched snapshot은 identity conflict로 닫고 provider identity clear를 시도한다.
- duplicate action은 in-flight future를 공유한다. already-Plus household는 purchase port를 호출하지 않는다.
- same-user household switch는 provider identity를 재사용하되 target household server entitlement와 catalog를 다시 읽는다. account switch는 old provider identity를 clear한 뒤 exact new user를 bind하며 old completion은 무시한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused billing tests | PASS — 36/36; WP06-01 entitlement 8 + WP06-03A flow/port/catalog 28 |
| focused billing analyzer | PASS — issue 0 |
| full Flutter regression after final change | PASS — 578 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| full Flutter analyzer | PASS — Flutter 3.44.7 `analyze --no-pub --fatal-infos --fatal-warnings`; issue 0 |
| formatter | PASS — 346 Dart files checked; 0 drift at full check; final billing formatter applied before focused rerun |
| repository code generation check | PASS — 341/682 generator inputs inspected; wrote 0 outputs; 8 generated files unchanged |
| public configuration validation | PASS — dev/prod examples remain allowlisted; no billing key added |
| repository secret scan | PASS — high-confidence secret 0 |
| repository JavaScript contract suite | PASS — 97/97 |
| CI workflow/supply-chain contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| matrix structure | PASS — billing 38×11, test 62×11, requirements 116×18, risk 30×15 |

The focused fixtures use only synthetic UUIDs, deterministic UTC timestamps, fake billing ports, fake entitlement repositories and injected confirmation delays. No Store product, provider account/customer, receipt, family content or network was used.

## Files, Migration, Dependency

- New WP06-03A domain/application:
  - `apps/kinflow_app/lib/features/billing/domain/entities/billing_store_models.dart`
  - `apps/kinflow_app/lib/features/billing/domain/failures/billing_failure.dart`
  - `apps/kinflow_app/lib/features/billing/application/ports/billing_port.dart`
  - `apps/kinflow_app/lib/features/billing/application/ports/billing_confirmation_delay.dart`
  - `apps/kinflow_app/lib/features/billing/application/billing_flow_state.dart`
  - `apps/kinflow_app/lib/features/billing/application/billing_flow_controller.dart`
- New WP06-03A tests:
  - `apps/kinflow_app/test/features/billing/billing_store_models_test.dart`
  - `apps/kinflow_app/test/features/billing/billing_port_contract_test.dart`
  - `apps/kinflow_app/test/features/billing/billing_flow_controller_test.dart`
- Governance: Phase 06, billing implementation docs, consolidated specs, billing/test/requirements/risk matrices and `WP06_03A_WORKPLAN.md`
- Database migration/RLS/RPC/Edge/OpenAPI: **none**. WP06-01 `EntitlementRepository` read contract만 사용한다.
- Runtime/dev dependency, lockfile, native permission/platform source, public configuration: **none**.
- `purchases_flutter`, Store product/API key와 provider-specific adapter는 이 slice에 없다.

## Security and Privacy Impact

- client provider state는 authority가 아니라 invalidation hint다. entitlement grant는 server repository 결과만 사용한다.
- identity mismatch는 catalog/purchase/restore 전에 닫히며 account switch는 clear 성공 전 new bind를 하지 않는다.
- in-flight operation은 user/household generation에 묶인다. 늦은 Store completion이 새 scope 상태를 바꾸지 못한다.
- catalog/provider outage는 이미 검증된 server entitlement를 지우지 않고 신규 Store action만 닫는다.
- failure는 stable enum만 운반하고 provider exception body, receipt, transaction/customer identifier를 반사하지 않는다.
- 실제 SDK가 없으므로 이번 slice에서 tracking, native permission, network endpoint, secret 또는 privacy disclosure 증가는 없다.

## Manual and Deferred Validation

- 사용자 지시에 따라 RevenueCat, Apple/Google Store, Supabase hosted account와 실제 customer/product/API key는 **NOT USED**다.
- Apple Sandbox/TestFlight, Google license tester/internal track, purchase/restore/reinstall/pending/refund/account switch와 real-device locale/accessibility는 **NOT RUN**이다.
- concrete `purchases_flutter` login/logout, offerings/customer-info listener, Store error mapping과 native build는 **NOT IMPLEMENTED/NOT RUN**이며 WP06-03B다.
- paywall/settings composition, localized benefit/terms/privacy/restore copy는 D-027과 WP06-02 범위다.
- purchase intent, signed webhook HTTP, reconciliation scheduler/dead letter와 support remediation은 WP06-04/05 범위다.

## Remaining Risks and Completion Boundary

1. D-027 actual product IDs, 가격, trial/annual policy와 numeric Free/Plus limits가 OPEN이다. fake catalog 값은 test fixture일 뿐 production policy가 아니다.
2. provider-neutral result mapping은 고정됐지만 actual RevenueCat SDK error/customer semantics와 Apple/Google pending behavior는 검증되지 않았다.
3. confirmation policy는 local bounded behavior만 검증했다. hosted webhook SLO, retry interval과 mismatch metrics는 operational decision이 필요하다.
4. restore conflict는 안전하게 잠그지만 사용자가 해결할 support/ownership verification UI와 audited transfer command는 WP06-05에 남아 있다.
5. controller는 아직 app provider/router/paywall/settings에 composition되지 않았다. 현재 기존 사용자 화면에서 구매할 수 있다는 의미가 아니다.
6. billing domain/application은 platform-free지만 concrete adapter의 Android/iOS build, license, privacy와 rollback 검토는 아직 수행하지 않았다.
7. WP06-03 상위 Gate와 Phase 06 Exit Gate는 actual Store/server/real-account/device 결과 전까지 `PARTIAL`이다.

WP06-03A 자체는 provider-neutral client operation contract의 local synthetic slice로 완료했다. 이를 production billing, RevenueCat integration 또는 Store readiness 완료로 보고하지 않는다.

## Rollback

- 새 WP06-03A application/domain/port/tests와 관련 문서 행을 함께 revert하면 WP06-01 server entitlement read 상태로 돌아간다.
- database, dependency, native source, public config나 provider state 변경이 없어 migration/provider rollback은 없다.
- 후속 concrete adapter에 문제가 생기면 unavailable `BillingPort`를 주입해 purchase/restore entry를 닫고 server entitlement read는 계속 유지한다.

## Next Entry Condition

- 다음 기능 slice는 **WP06-03B concrete RevenueCat adapter + app dependency composition**이다.
- 시작 전 current official RevenueCat Flutter documentation을 확인하고 exact dependency version, license, maintenance, privacy/network, Android/iOS minimum/target support, native build와 rollback을 작업계획에 기록한다.
- adapter는 이 port 밖으로 provider type/raw error를 노출하지 않고 authenticated exact user bind/clear, Store-localized offering, purchase/restore mapping과 snapshot invalidation만 구현해야 한다.
- Store API key/product/account가 없을 때 unavailable fail-closed로 실행 가능해야 하며, 실제 계정·sandbox·device 검증은 사용자 지시대로 마지막 Billing Gate에 남긴다.
