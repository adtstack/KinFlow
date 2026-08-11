# Phase 06 WP06-03A Provider-Neutral Billing Flow Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: provider-independent store catalog/identity/purchase/restore port, server-authoritative confirmation state machine, duplicate-action containment, account/household switch invalidation과 deterministic fake-adapter tests
- 제외: `purchases_flutter` dependency와 RevenueCat concrete adapter, Store product/API key, paywall/settings UI, purchase-intent/webhook/reconciliation HTTP, 실제 account/sandbox/device 검증

## Entry Decision

- WP06-01 server household entitlement와 strict Flutter read repository가 local automated pass이므로 client operation state를 그 authority 위에 구성할 수 있다.
- D-027 가격·수치 한도·trial/annual policy는 OPEN이다. 이번 slice는 store가 돌려준 opaque package/product ID와 localized display price를 운반할 뿐 product ID, 가격, 통화 환산 또는 benefit copy를 하드코딩하지 않는다.
- 실제 RevenueCat SDK를 먼저 추가하면 계정·상품 준비가 없는 상태에서 adapter wiring만 생긴다. 이번 slice는 같은 port를 deterministic fake로 완전히 실행해 purchase/restore와 server confirmation 안전 규칙을 먼저 고정한다.
- client store snapshot은 invalidation hint다. Plus 활성화는 오직 `EntitlementRepository`가 반환한 current household의 server materialization으로만 전이한다.

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP06-03 / FR-SUB-001 | catalog는 provider type 없이 immutable offering/package로 표현하고 package/product ID, localized price, billing period를 검증한다. 앱 코드에 실제 가격·통화·product ID를 넣지 않는다. |
| WP06-03 / D-024 / FR-SUB-002 | 모든 purchase/restore 전 exact `AuthUserId`를 provider port에 bind하며 returned identity가 다르면 operation을 시작하지 않는다. anonymous purchase를 허용하지 않는다. |
| WP06-03 / D-025 / FR-SUB-005 | store success는 즉시 Plus가 아니라 `serverConfirmationPending`이다. current household의 server entitlement가 Plus이고 current user가 billing owner일 때만 ready/active로 전이한다. |
| WP06-03 / FR-SUB-002 / FR-SUB-003 | purchase cancel, store pending, retryable/final failure, restore empty/conflict/pending/found를 stable provider-neutral result/state로 구분한다. conflict에서 silent transfer나 duplicate purchase를 유도하지 않는다. |
| WP06-03 / D-049 / NFR-SEC-01 | logout/account/household switch는 in-flight generation을 즉시 invalidate한다. provider identity clear가 실패하면 새 identity를 bind하지 않고 fail closed한다. old result가 새 account state를 갱신할 수 없다. |
| WP06-03 / NFR-REL-01 | duplicate tap은 provider call 한 번으로 coalesce하고 server confirmation은 injected bounded policy/delay로 retry한다. timeout 뒤 pending/retry 상태를 유지해 재구매를 유도하지 않는다. |
| WP06-03 / D-047 | domain/application은 Flutter, Riverpod, Supabase, RevenueCat import가 없고 clock/delay/provider/server는 port로 주입한다. |
| WP06-03 / NFR-PRIV-01 | state, error, snapshot과 tests에는 receipt, transaction/customer reference, raw provider error, email 또는 family content가 없다. |

## State Contract

- `initial` → `loading` → `ready`
- purchase: `ready` → `purchasing` → `ready(cancelled)` | `storePending` | `serverConfirmationPending` → `ready(server confirmed)`
- restore: `ready` → `restoring` → `restoreEmpty` | `restoreConflict` | `storePending` | `serverConfirmationPending` → `ready(server confirmed)`
- unsupported/identity/catalog/server authorization/invalid payload는 stable failure state다.
- `BillingClientSnapshot`은 matching user의 refetch trigger만 제공하며 client entitlement flag로 ready를 직접 만들지 않는다.
- 이미 server Plus인 household의 duplicate purchase는 provider를 호출하지 않는다.

## Database, API, Dependency Impact

- database migration/RLS/RPC/Edge/OpenAPI: 없음. WP06-01 `get_household_entitlement`만 사용한다.
- runtime dependency/native permission/platform source/public config: 없음.
- 실제 Store catalog와 RevenueCat SDK adapter는 dependency/privacy/license/platform audit가 포함된 후속 WP06-03B다.

## Test Plan

- catalog/package exact validation, duplicate IDs, immutable collections, localized price transport
- identity bind exact match와 anonymous/unsupported/conflict denial
- catalog + Free entitlement initialization
- purchase success가 server 확인 전 Plus를 열지 않음
- bounded temporary failure/free-state polling 뒤 newer Plus owner confirmation
- confirmation timeout이 pending을 유지하고 explicit refresh로 recovery
- purchase cancellation/store pending/retryable/final failure
- restore empty/conflict/pending/found와 no silent transfer
- duplicate purchase/restore tap provider call one
- already-Plus duplicate purchase denial
- account/household switch during in-flight operation ignores stale completion
- identity clear failure blocks rebind
- client snapshot matching/mismatching identity and server-only refetch
- dispose and late completion safety
- focused/full Flutter, analyzer, formatter, codegen, secret/config/architecture/whitespace gates

## Rollback

- 새 application/domain/port/tests와 계약 문서를 함께 revert하면 WP06-01 entitlement read slice로 돌아간다.
- concrete SDK, native source, secret, database/API 변경이 없으므로 provider/server rollback은 없다.
- 후속 adapter에서 문제가 생기면 unavailable BillingPort를 주입하고 purchase entry를 닫되 server entitlement read는 유지한다.

## Completion Boundary

- deterministic fake port + fake entitlement repository로 catalog/purchase/restore/pending/confirmation/account-switch state가 모두 실행되고 full Flutter regression이 통과하면 `WP06-03A LOCAL IMPLEMENTED`다.
- 이는 WP06-03 전체 또는 production purchase 완료가 아니다. RevenueCat concrete adapter는 WP06-03B, purchase intent/hosted reconciliation은 WP06-04/05, actual sandbox/account/device는 마지막 Billing Gate다.
