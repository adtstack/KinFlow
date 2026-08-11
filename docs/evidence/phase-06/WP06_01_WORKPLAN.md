# Phase 06 WP06-01 Billing Domain and Schema Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: provider-independent billing customer/verified event/transaction/household assignment/authoritative entitlement schema, state audit, authenticated entitlement read contract와 server-only feature-capacity primitive
- 제외: RevenueCat SDK, Store offering/price/paywall, webhook HTTP/signature adapter, provider reconciliation network call, household transfer/support UI, 실제 purchase/restore/refund와 실계정·실기기 검증

## Entry Decision

- D-024, D-025와 D-028은 확정되어 provider-independent identity와 entitlement schema를 구현할 수 있다.
- D-027의 가격, Free/Plus 수치 한도, trial과 연간 할인은 OPEN이다. 이번 WP는 가격을 저장하거나 표시하지 않고 plan별 feature-limit policy를 versioned configuration으로 만든다.
- 미확정 policy는 `limits_finalized=false`로 저장하고 server capacity assertion은 fail closed한다. 기존 mutation에는 WP06-06 전까지 이 assertion을 연결하지 않아 임의의 provisional 수치로 현재 기능을 차단하지 않는다.
- ingestion runtime은 기본 `disabled`다. local pgTAP fixture만 sandbox ingestion을 명시적으로 활성화하며 hosted environment 구성은 후속 deployment Gate다.

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP06-01 / D-024 | RevenueCat customer reference는 authenticated KinFlow user UUID와 exact match하고 household ID를 provider customer identity로 허용하지 않는다. provider/environment/customer mapping은 unique하다. |
| WP06-01 / D-025 / FR-SUB-005 | 서버가 customer와 하나의 active paid household assignment를 분리하고 household entitlement를 최종 materialized authority로 제공한다. 같은 customer 또는 household의 두 active assignment는 불가능하다. |
| WP06-01 / FR-SUB-004 / NFR-REL-01 | verified normalized event는 provider/environment/event ID와 exact request hash로 멱등 처리한다. 같은 ID의 다른 payload는 충돌하고 오래되거나 같은 시각의 후속 event는 현재 state를 회귀시키지 않는다. |
| WP06-01 / FR-SUB-006 / D-028 | `none`, `trialing`, `active`, `grace`, `billing_issue`, `expired`, `revoked`를 보존하고 effective plan을 별도 materialize한다. expiry/revoke는 family data를 삭제하지 않는다. |
| WP06-01 / FR-HH-010 | versioned plan policy와 server-only `members`/`activeSeries` usage 및 capacity assertion을 제공한다. 미확정 또는 누락 limit는 허용으로 오인하지 않는다. |
| WP06-01 / NFR-SEC-01 / NFR-PRIV-01 | billing mutation은 service-only security-definer API다. authenticated client는 자기 customer와 active household projection만 읽고 receipt ciphertext, transaction hash와 audit에 접근하지 못한다. 로그나 client response에 receipt/provider reference를 반환하지 않는다. |
| WP06-01 / D-047 | Flutter billing domain과 strict RPC mapper는 Flutter/Riverpod/RevenueCat SDK에 독립적이며 provider type을 domain 밖에 둔다. |

## Database and API Impact

- migration: `20260808060000_billing_domain_and_entitlements.sql`
- public enum/table: entitlement status, billing customers, webhook receipts, transactions, household assignments, plan catalog, household entitlements
- private table: runtime configuration, immutable entitlement transition audit, immutable policy audit
- authenticated read: `get_household_entitlement(household_id)` only after exact active-membership check
- service-only command: runtime configuration, plan limit configuration, verified normalized billing event application
- private limit functions: current usage and capacity assertion; no authenticated execute grant
- new household trigger and additive backfill create a Free/none entitlement without changing existing household data.

## State and Ordering Contract

- customer authority is `(provider, environment, auth_user_id)` and RevenueCat customer ref must equal `auth_user_id::text`.
- event authority is `(provider, environment, provider_event_id, request_hash)`. exact replay is idempotent; event-ID payload collision is rejected.
- `provider_occurred_at` advances monotonically at customer scope. older events are recorded as stale; a different event at the same timestamp is quarantined instead of choosing arrival order.
- transaction references are SHA-256 hashes. optional raw provider snapshots/webhook bodies are ciphertext only and never enter read projections.
- existing assignment remains bound through expiry/revoke so another account or household cannot silently steal restore ownership. transfer is WP06-05.
- `plan_code` is effective access and `status` is lifecycle state. `billing_issue` can therefore remain Plus or become Free according to a later finalized policy without changing the state enum.

## Test Plan

- exact schema, enum, columns, constraints, indexes, triggers, RLS, grants and security-definer search path
- runtime disabled and sandbox/production environment mismatch quarantine
- RevenueCat auth-user identity exactness and active Owner/Admin initial assignment
- duplicate exact event with one transaction/assignment/audit and replay counter
- duplicate ID with different normalized payload rejection
- out-of-order and equal-time ambiguous event non-regression
- customer/household/transaction cross-binding conflict quarantine
- active/trial/grace/billing-issue/cancel-valid/expired/refund/revoke materialization
- membership-scoped entitlement read and cross-household denial with no private reference leakage
- plan policy optimistic version, JSON validation, Plus≥Free comparison, provisional fail-closed and members/activeSeries capacity
- expiry/revoke changes no household/member/chore/event row counts
- Flutter domain invariant, strict payload parsing, repository mapping and Supabase RPC/error mapping
- clean local reset, focused/full pgTAP, database lint, focused/full Flutter, analyzer, formatter, codegen, secret/dependency/whitespace gates

## Rollback

- production 적용 전에는 migration, billing Dart slice와 계약 문서를 함께 revert한다.
- production 적용 후에는 ingestion runtime을 disabled로 유지하거나 service-only config로 즉시 닫는다. applied migration은 수정·삭제하지 않고 forward migration으로 execute revoke, view/function 교체 또는 additive correction을 수행한다.
- billing tables를 drop하거나 entitlement row를 삭제하는 destructive rollback은 사용하지 않는다. 기존 Free/none entitlement read를 유지한다.
- RevenueCat/Store SDK와 secret을 이번 WP에서 추가하지 않으므로 mobile provider rollback은 없다.

## Completion Boundary

- local clean schema에서 customer→verified event→transaction→assignment→household entitlement와 read/limit projection이 deterministic pgTAP으로 통과하면 WP06-01을 `LOCAL IMPLEMENTED`로 기록한다.
- 실제 provider webhook signature와 reconciliation은 WP06-04, Store SDK는 WP06-03, limit integration은 WP06-06이다.
- 가격/상품 UX는 D-027 확정 후 WP06-02에 진입한다. 실계정·sandbox purchase·실기기 검증은 사용자 지시에 따라 기능 개발 후 마지막 Gate다.
