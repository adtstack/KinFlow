# ADR-0006 — Server-authoritative household entitlement

- 상태: ACCEPTED
- 작성일: 2026-08-08
- 결정일: 2026-08-08
- 결정자: Product owner direction / Engineering
- 관련 요구사항: WP06-01, FR-SUB-004, FR-SUB-005, FR-SUB-006, FR-HH-010, NFR-SEC-01, NFR-REL-01
- 관련 결정: D-024, D-025, D-027, D-028, D-047
- 관련 위험: RISK-003, RISK-010, RISK-011, RISK-025, RISK-026
- 대체 ADR: 없음

## Context

Store 또는 RevenueCat client snapshot만으로 Plus를 승인하면 account 전환, restore, webhook 재전송·순서 역전과 purchaser가 속한 여러 household 사이에서 권한이 누출될 수 있다. KinFlow의 유료 단위는 Store account 자체가 아니라 선택된 household이며, 만료나 환불도 가족 데이터를 삭제해서는 안 된다.

D-027의 가격과 Free/Plus 수치 한도는 아직 OPEN이다. 따라서 identity·ordering·authorization schema는 먼저 구현하되 임의의 가격이나 provisional limit를 production 정책처럼 취급할 수 없다.

## Decision

1. provider customer identity는 `(provider, environment, auth_user_id)`이고 RevenueCat customer reference는 authenticated KinFlow user UUID와 정확히 일치한다. household ID를 provider customer ID로 사용하지 않는다.
2. purchaser customer, normalized transaction, active household assignment와 materialized household entitlement를 분리한다. 한 customer와 한 household에는 각각 최대 하나의 active assignment만 존재한다.
3. household entitlement가 최종 access authority다. client SDK snapshot은 Plus를 직접 부여하지 않으며 active household member는 provider/receipt/transaction 식별자가 빠진 projection만 읽는다.
4. verified normalized event는 `(provider, environment, provider_event_id, request_hash)`로 처리한다. exact replay는 멱등이고 같은 event ID의 다른 payload는 충돌한다. 더 오래된 event는 stale, 같은 provider timestamp의 다른 event는 ambiguous quarantine으로 기록해 state를 회귀시키지 않는다.
5. lifecycle status와 effective plan을 분리한다. `trialing`, `active`, `grace`는 Plus이고 `none`, `expired`, `revoked`는 Free다. `billing_issue`의 effective plan은 최종 정책에 따라 둘 중 하나일 수 있다.
6. expiry/revoke 뒤에도 assignment ownership을 보존하고 household/member/chore/calendar 데이터를 삭제하지 않는다. 명시적 transfer와 support remediation만 binding을 변경한다.
7. receipt와 provider snapshot은 ciphertext로만 저장하고 transaction reference는 SHA-256 hash로만 저장한다. applied transition과 policy 변경은 private immutable audit에 남긴다.
8. ingestion runtime은 기본 disabled다. plan limits는 versioned configuration이지만 D-027 전에는 `limits_finalized=false`이고 capacity assertion은 fail closed한다. 기존 mutation에는 WP06-06 전까지 provisional assertion을 연결하지 않는다.

## Consequences

- duplicate, out-of-order, cancellation, expiration, refund와 restore가 하나의 서버 state machine으로 수렴한다.
- purchaser와 household Owner를 같은 개념으로 오인하지 않고 conflict를 조용히 재할당하지 않는다.
- client가 로컬 상태를 변조해도 premium write authority를 획득하지 못한다.
- equal-time provider event는 자동 추측 대신 quarantine되므로 reconciliation/support 경로가 필요하다.
- webhook HTTP 서명, provider API reconciliation, transfer UI와 최종 limit mutation wiring은 별도 WP로 남는다.

## Validation

- pgTAP: schema/constraints/RLS/grants, identity/environment, duplicate/payload collision, stale/equal-time, lifecycle, cross-binding conflict, data preservation, plan policy와 capacity
- Flutter: provider-independent invariant, strict 12-field RPC payload, household scope와 provider error mapping
- 마지막 Gate: 실제 RevenueCat/Store sandbox purchase·restore·refund, hosted webhook/reconciliation과 실기기 account-switch

## Rollback / Revisit Trigger

- runtime config를 disabled로 유지하면 verified event ingestion을 즉시 닫고 현재 Free/none projection을 보존할 수 있다.
- 출시 전에는 migration·Flutter slice·contract를 함께 revert한다. 적용 후에는 destructive drop 없이 forward migration으로 function/grant/view를 교체한다.
- provider가 stable ordering key를 제공하거나 D-027/transfer/account-delete 정책이 확정되면 이 ADR의 ordering 또는 lifecycle 세부를 additive ADR로 보완한다.
