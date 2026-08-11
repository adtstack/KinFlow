# Phase 06 WP06-05 Household Assignment and Conflict Workplan

- 상태: `COMPLETED — LOCAL AUTOMATED PASS (2026-08-08)`
- 범위: 구매/복원 전 명시적 household assignment intent, provisional binding 수명주기, 충돌·이탈 상태 projection, missing-assignment reconciliation 재처리, support remediation request와 service-only audited resolution, Flutter preflight/recovery integration
- 제외: 실제 RevenueCat/Store 계정과 상품, provider alias/transfer API 호출, support 운영자 UI와 티켓 시스템, hosted scheduler, sandbox/실기기 검증

## Entry Decision

- WP06-04는 active assignment가 없으면 `ASSIGNMENT_REQUIRED`로 닫아 잘못된 household 추정을 막는다. 이번 slice는 authenticated Owner/Admin이 Store 작업 전에 선택한 household만 서버에 provisional binding으로 기록하고, 해당 선택으로만 webhook reconciliation을 다시 열어 준다.
- provisional binding은 Store 구매 권한이 아니다. verified provider transaction이 적용될 때만 confirmed가 되며, 만료·명시적 해제 전에는 하나의 billing customer와 하나의 household만 연결한다.
- 이미 다른 household에 confirmed된 customer 또는 다른 customer가 사용 중인 household는 자동 이전하지 않는다. client에는 provider/customer/다른 household 식별자 없이 stable conflict만 반환한다.
- purchaser가 household에서 나가거나 역할이 바뀌어도 기존 유료 권한을 임의 삭제하거나 다른 사용자에게 넘기지 않는다. assignment health는 support-required로 표시하고, 이전은 service-only command와 immutable audit를 요구한다.
- 실제 provider alias/ownership verification은 마지막 Billing Gate다. 이번 slice의 manual resolution은 synthetic support verification 결과를 입력받는 서버 명령까지 구현하고 local pgTAP/fake로 검증한다.

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP06-05 / FR-SUB-002 | purchase/restore 전 current authenticated user와 명시적으로 선택한 household를 idempotent server command로 고정한다. active Owner/Admin만 준비할 수 있다. |
| WP06-05 / D-024 / D-025 | 한 customer↔한 household, 한 household↔한 customer active invariant를 유지한다. confirmed 충돌은 자동 해제·이전·재구매 없이 stable conflict다. |
| WP06-05 / FR-SUB-003 | restore conflict는 customer-assigned-elsewhere와 household-assigned-elsewhere를 provider identifier 없이 구분하고 support request를 생성할 수 있다. |
| WP06-05 / FR-SUB-009 / NFR-REL-01 | valid assignment가 준비되면 같은 user/environment의 `ASSIGNMENT_REQUIRED` dead letter를 idempotently requeue하고 immutable queue transition을 남긴다. |
| WP06-05 / FR-HH-007 | billing owner가 household에서 제거되거나 Owner/Admin 권한을 잃어도 entitlement는 자동 이전되지 않는다. status projection은 owner membership drift와 remediation 필요를 명시한다. |
| WP06-05 / NFR-SEC-01 | provisional binding은 bounded expiry를 가지며 verified transaction만 confirmed로 승격한다. 만료된 provisional binding은 reconciliation과 periodic scheduling에 사용하지 않는다. |
| WP06-05 / NFR-AUD-01 | support resolution은 expected assignment version, allowlisted reason, SHA-256 case reference와 correlation ID를 요구하고 immutable audit를 남긴다. raw ticket text/provider reference는 저장하지 않는다. |
| WP06-05 / NFR-PRIV-01 | client status/result에는 provider customer, transaction, receipt, 다른 household ID, billing-owner user ID 또는 support case 원문이 없다. |

## State and Command Contract

- assignment binding: `provisional` → verified transaction → `confirmed`; provisional은 `released | expired`로만 끝낼 수 있다.
- client ownership projection: `unassigned | current_user | another_user`; binding projection: `none | provisional | confirmed`; owner membership: `none | active | removed`.
- prepare outcomes: `ready | already_ready | customer_conflict | household_conflict`.
- authenticated commands:
  - `prepare_billing_household_assignment(household, idempotency_key)`
  - `release_billing_household_assignment(household, expected_version, idempotency_key)`
  - `get_billing_household_assignment_status(household)`
  - `request_billing_assignment_remediation(household, issue_kind, idempotency_key)`
- service commands:
  - expired provisional cleanup
  - remediation `transfer_customer | release_expired_provisional | reject`
- transfer는 requester가 target household의 active Owner/Admin이고 target에 active assignment가 없을 때만 같은 provider customer의 binding과 entitlement를 원자적으로 이동한다. 다른 customer의 paid household를 탈취하지 않는다.

## Flutter Contract

- `BillingAssignmentRepository`는 provider-neutral prepare/release/status/remediation 결과만 노출한다.
- `BillingFlowController`는 purchase/restore provider 호출 전에 assignment prepare를 완료한다. conflict면 Store를 호출하지 않고 stable conflict state를 표시한다.
- purchase cancel, restore empty 또는 provider 시작 전 최종 실패는 이 작업에서 만든 provisional binding만 best-effort release한다. pending/success는 reconciliation을 위해 유지한다.
- account/household generation switch는 늦은 prepare/release/provider 결과를 기존 규칙대로 무효화한다.
- command UUID는 주입 가능한 generator로 만들며 deterministic fake tests에서 replay와 call ordering을 검증한다.

## Database and API Impact

- migration: `supabase/migrations/20260808080000_billing_household_assignment.sql`
- private records: hashed idempotency result, remediation request, immutable manual resolution audit
- existing assignment: binding state/confirmation/intent expiry metadata 추가
- existing reconciliation: confirmed 또는 아직 유효한 provisional만 claim하고 confirmed만 periodic schedule; assignment prepare가 eligible dead letter를 requeue
- public contract: assignment RPC schemas를 OpenAPI/database/domain-event 문서에 추가
- client: domain/data/repository/Supabase mapper/composition/controller state와 local fake tests

## Test Plan

- Owner/Admin prepare, Member/removed/unauthenticated denial, disabled/environment gate
- same-command replay와 changed-input collision, duplicate tap one server prepare + one Store call
- customer conflict, household conflict, no other household/provider identifier leakage
- provisional expiry/release, verified transaction confirmation, expired provisional claim/schedule exclusion
- missing-assignment dead-letter requeue and immutable `requeued` transition
- owner removal/role drift projection without entitlement loss or silent owner transfer
- support request idempotency/privacy, expected-version resolution, transfer atomicity, target conflict denial, immutable audit
- Flutter strict payload mapping, failure mapping, preflight ordering, cancel/empty best-effort release, conflict no Store call, account/household switch invalidation
- focused/full pgTAP and Flutter regression, analyzer/formatter, secret/config/codegen/YAML/matrix/whitespace gates

## Rollback

- Flutter preflight repository/controller changes and WP06-05 migration/docs/tests are reverted together.
- runtime emergency stop remains `billing_runtime_config.ingestion_enabled=false`; purchase entry closes while current server entitlement read remains available.
- provisional assignments contain no receipt or provider response. Before rollback, expire/release provisional rows; confirmed legacy assignment/entitlement rows remain compatible with WP06-01/04.

## Completion Boundary

- explicit household selection → provisional binding → Store fake → verified transaction confirmation, conflict → support request, missing-assignment requeue, purchaser membership drift와 audited transfer가 local DB/Flutter automation으로 실행되면 `WP06-05 LOCAL IMPLEMENTED`다.
- live RevenueCat alias/transfer, actual Store restore ownership, support ticket integration, sandbox/account/device는 마지막 Billing Gate까지 `NOT RUN`이다.
- 완료 검증: clean local reset, WP06-05 pgTAP 68/68, full DB 39 files/2,118, focused Flutter 45/45, full Flutter 616 pass + opt-in 1 skip, JS 115/115, analyzer/lint/format/config/secret/codegen/YAML/matrix/whitespace gates가 통과했다. 상세 결과와 미실행 경계는 `WP06_05_EVIDENCE.md`에 고정했다.
