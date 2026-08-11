# Phase 06 WP06-05 Household Assignment and Conflict Evidence

- Work Package: WP06-05 — explicit paid-household preflight, bounded provisional binding, conflict projection, missing-assignment recovery와 audited support remediation
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Node.js 24.15.0, Flutter 3.44.7, Dart 3.12.2, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP06-05 LOCAL AUTOMATED PASS / PROVIDER OWNERSHIP·SUPPORT OPERATOR·HOSTED SCHEDULER·STORE SANDBOX·REAL ACCOUNT/DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP06-05 / FR-SUB-002 / D-024 / D-025 | PASS FOR EXPLICIT LOCAL PREFLIGHT / OVERALL PARTIAL | active Owner/Admin이 purchase 전에 선택한 household만 30분 provisional binding으로 준비한다. server가 auth UUID/provider/environment를 파생하고 Store call 전에 terminal outcome을 반환한다. actual Store transaction은 사용하지 않았다. |
| WP06-05 / FR-SUB-003 / RISK-011 | PASS FOR LOCAL CONFLICT AND SUPPORT REQUEST / OVERALL PARTIAL | customer/household conflict를 구분하고 Store call을 0으로 유지한다. provider/customer/다른 household/owner identifier 없이 aggregate remediation request를 idempotently 생성한다. actual Store ownership verification과 operator UI는 남았다. |
| WP06-05 / FR-SUB-005 / NFR-SEC-01 | PASS FOR BOUNDED BINDING AND VERIFIED CONFIRMATION / OVERALL PARTIAL | 한 customer↔한 household active unique invariant, concurrent prepare one-winner, provisional expiry/release와 verified transaction-only confirmation이 pgTAP을 통과했다. provisional 자체는 Plus가 아니다. |
| WP06-05 / FR-SUB-009 / NFR-REL-01 | PASS FOR LOCAL ASSIGNMENT RECOVERY / OVERALL PARTIAL | valid prepare는 같은 auth UUID/environment의 `ASSIGNMENT_REQUIRED` dead letter만 idempotently requeue하고 immutable `requeued` transition을 남긴다. periodic repair는 confirmed assignment만 사용한다. hosted operator replay는 남았다. |
| WP06-05 / FR-HH-007 / BILL-016 / BILL-017 | PASS FOR MEMBERSHIP-DRIFT PRESERVATION / OVERALL PARTIAL | purchaser membership 제거·role drift 뒤에도 assignment/entitlement를 자동 삭제·이전하지 않는다. aggregate status는 owner membership `removed`와 support 필요를 표시한다. 실제 다계정/기기 흐름은 남았다. |
| WP06-05 / FR-SUB-007 / NFR-AUD-01 | PASS FOR LOCAL VERSIONED SUPPORT RESOLUTION / OVERALL PARTIAL | service-only resolution은 expected assignment version, allowlisted reason, exact SHA-256 case-reference와 correlation ID를 요구한다. target conflict를 거부하고 source reset + target confirmed entitlement 이동을 atomic하게 수행하며 immutable audit를 남긴다. provider verification/cooldown/operator workflow는 남았다. |
| WP06-05 / NFR-PRIV-01 | PASS FOR NEW SURFACE | client projection/result와 Flutter domain에는 provider customer, transaction, receipt, 다른 household ID, billing-owner user ID, case text/reference가 없다. private command/audit table direct access는 service role까지 revoke했다. |

## Implemented Contract

- `prepare_billing_household_assignment(household, idempotencyKey)`는 active Owner/Admin만 실행한다. exact authenticated UUID와 runtime RevenueCat environment로 customer를 찾거나 만들고 user + household advisory lock을 잡는다.
- prepare outcome은 `ready | already_ready | customer_conflict | household_conflict`다. exact replay는 저장된 결과를 반환하고 같은 key/다른 input은 `KFB50`으로 닫는다.
- 새 assignment는 `provisional`이며 30분 expiry를 가진다. verified billing transaction insert/update trigger만 `confirmed`와 `confirmed_at`으로 승격하고 matching intent를 소비한다.
- client release는 current user's provisional + expected version만 끝낸다. absent/ended는 idempotent `already_released`, confirmed는 `support_required`다.
- status RPC는 binding `none|provisional|confirmed`, ownership `unassigned|current_user|another_user`, owner membership `none|active|removed`, prepare/support/version/expiry만 노출한다.
- prepare 성공은 same identity/environment의 terminal missing-assignment work만 retry queue로 되돌린다. claim은 confirmed 또는 유효한 provisional만 해석하고 periodic scheduler는 confirmed만 대상으로 한다.
- expiry cleanup은 transaction 없는 expired provisional만 bounded `SKIP LOCKED`로 끝낸다. explicit household re-selection도 transaction 없는 current-user provisional만 supersede한다.
- remediation request는 conflict kind만 저장하고 free-form text를 받지 않는다. 새 idempotency key가 기존 open request로 수렴해도 alias result를 저장하며 해당 key의 changed-input replay를 거부한다.
- service resolution action은 `transfer_customer | release_expired_provisional | reject`다. transfer는 requester/customer ownership, target Owner/Admin, confirmed source와 empty target를 확인하고 source entitlement를 Free/none으로 reset한 뒤 target assignment/entitlement를 같은 transaction에서 만든다.
- assignment lifecycle transition과 support resolution action은 private immutable audit다. external case reference는 raw string 대신 32-byte SHA-256 digest만 저장한다.
- Flutter `BillingFlowController`는 purchase/restore 전에 assignment prepare를 완료한다. conflict는 stable state로 끝나며 Store port를 호출하지 않는다. cancel/restore-empty/final provider failure는 created provisional을 best-effort release하고 pending/success는 유지한다.
- account/household generation switch는 늦은 prepare/release/Store result를 무효화한다. presentation provider는 application-layer unavailable fallback만 참조하고 concrete secure generator는 app composition에서 주입한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 32 migrations including `20260808080000_billing_household_assignment.sql` and synthetic seed |
| focused WP06-05 pgTAP | PASS — 2 files / 68 tests; main 61 + advisory-lock concurrency 7 |
| focused legacy billing compatibility | PASS — billing domain 96/96 and webhook/reconciliation 40/40 after final timestamp fix |
| full database regression | PASS — 39 files / 2,118 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; schema error 0 |
| focused WP06-05 Flutter tests | PASS — 45/45 |
| architecture/app-shell regression after boundary hardening | PASS — 26/26 |
| full Flutter regression | PASS — 616 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — `analyze --no-pub --fatal-infos --fatal-warnings`; issue 0 |
| formatter | PASS — 371 Dart files checked; 0 changed |
| repository JavaScript contract regression | PASS — 115/115 |
| public configuration validation | PASS — exact public allowlist; no assignment/provider secret key added |
| repository secret scan | PASS — high-confidence secret 0 |
| repository code generation check | PASS — build_runner wrote 0 outputs; generated-code drift 0 across 8 files |
| assignment/reconciliation/domain/OpenAPI YAML parse | PASS — 4 contracts parsed |
| CI workflow/supply-chain contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| matrix structure | PASS — billing 38×11, test 62×11, requirements 116×18, risk 30×15 |
| whitespace | PASS — `git diff --check`, output 0 before evidence finalization; post-document check repeated |

All IDs, users, households, timestamps, transaction hashes, case-reference digests and Store/provider results are synthetic local fixtures. No provider network request, production credential, customer, receipt, ticket, family content or physical device was used.

The full regression found two compatibility issues before final PASS. First, a presentation provider imported the concrete data-layer UUID generator; it now uses a layer-safe unavailable application fallback and production composition supplies the secure generator. Second, legacy verified-event assignment used statement time while the new confirmation default used transaction time; `confirmed_at` now uses the same statement clock, preserving the confirmation-order invariant in long pgTAP transactions.

## Files and Migration

- Migration and DB tests:
  - `supabase/migrations/20260808080000_billing_household_assignment.sql`
  - `supabase/tests/database/billing_household_assignment.test.sql`
  - `supabase/tests/database/billing_household_assignment_concurrency.test.sql`
- Flutter domain/application/data:
  - `apps/kinflow_app/lib/features/billing/domain/entities/billing_assignment.dart`
  - `apps/kinflow_app/lib/features/billing/domain/failures/billing_assignment_failure.dart`
  - `apps/kinflow_app/lib/features/billing/domain/repositories/billing_assignment_repository.dart`
  - `apps/kinflow_app/lib/features/billing/domain/services/billing_assignment_command_id_generator.dart`
  - `apps/kinflow_app/lib/features/billing/application/unavailable_billing_assignment_repository.dart`
  - `apps/kinflow_app/lib/features/billing/application/unavailable_billing_assignment_command_id_generator.dart`
  - `apps/kinflow_app/lib/features/billing/data/datasources/billing_assignment_data_source.dart`
  - `apps/kinflow_app/lib/features/billing/data/repositories/provider_billing_assignment_repository.dart`
  - `apps/kinflow_app/lib/features/billing/data/services/secure_billing_assignment_command_id_generator.dart`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_billing_assignment_data_source.dart`
- Flutter flow/composition:
  - `apps/kinflow_app/lib/features/billing/application/billing_flow_controller.dart`
  - `apps/kinflow_app/lib/features/billing/application/billing_flow_state.dart`
  - `apps/kinflow_app/lib/features/billing/presentation/providers/billing_providers.dart`
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
- Focused Flutter tests:
  - `apps/kinflow_app/test/features/billing/billing_assignment_models_test.dart`
  - `apps/kinflow_app/test/features/billing/provider_billing_assignment_repository_test.dart`
  - `apps/kinflow_app/test/features/billing/billing_flow_controller_test.dart`
  - `apps/kinflow_app/test/infrastructure/supabase_billing_assignment_data_source_test.dart`
- Normative contract: `docs/contracts/billing-assignment.yaml.md`, OpenAPI, database schema and domain-event contracts
- Runtime/dependency/lockfile/native permission/public config delta: **none** in WP06-05.

## Security, Privacy and Operational Impact

- household, provider, environment와 customer를 함께 request에서 받지 않는다. household만 explicit user selection이고 나머지는 trusted server context에서 파생한다.
- advisory locks plus active unique indexes protect both sides of the assignment under concurrent owners/customers. conflict response carries no counterparty identity.
- provisional binding cannot grant Plus and expires. verified server transaction is the only confirmation signal.
- client cannot release a confirmed assignment or invoke transfer. service resolution is versioned, policy-checked and audited; another customer's paid target cannot be overwritten.
- membership drift does not silently revoke family access or transfer billing ownership. status separates household role health from billing ownership.
- private idempotency, request and audit tables are inaccessible by direct grants, including service role. mediated functions return bounded exact projections.
- logs/state/errors contain stable enums/codes only; no provider response, receipt, transaction/customer reference, case text, other-household ID or owner ID is reflected.
- runtime emergency stop remains `billing_runtime_config.ingestion_enabled=false`. default product policy/limits remain unfinalized until D-027.

## Manual and Deferred Validation

- 사용자 지시에 따라 RevenueCat project/customer/alias/transfer API, Apple/Google Store product/account, sandbox purchase/restore/reinstall과 physical device는 **NOT USED / NOT RUN**이다.
- actual Store account와 KinFlow account ownership proof, alias merge semantics, refund/transfer interaction과 provider race는 **NOT RUN**이다.
- hosted Supabase deploy, cleanup cron, dead-letter operator replay, support ticket integration, operator UI, case retention과 on-call runbook은 **NOT RUN**이다.
- recent-auth/cooldown business policy, localized assignment/conflict/support UI와 paywall selection screen은 WP06-02/정책 Gate에 남았다. 이번 slice는 controller/state와 server command까지 testable하다.
- actual multi-account/household/device role drift와 reinstall restore matrix는 마지막 Billing Gate다.

## Remaining Risks and Completion Boundary

1. Local synthetic case-reference hash는 operator가 provider/store ownership을 실제 확인했다는 증거가 아니다. hosted support workflow가 service command 호출 권한과 proof lifecycle을 소유해야 한다.
2. RevenueCat alias/transfer event는 WP06-04에서 계속 manual review다. provider API ownership/alias 동작을 확인하기 전 자동 resolution과 customer merge를 활성화하면 안 된다.
3. provisional 30분과 cleanup batch는 local contract다. hosted scheduler cadence, clock/lag metrics와 retention을 마지막 Billing Gate에서 정해야 한다.
4. membership drift는 데이터 손실을 막지만 사용자-facing 역할/결제 소유자 설명 화면과 support SLA가 아직 없다.
5. D-027 product/price/trial/limits와 transfer cooldown 정책은 OPEN이다. 이번 migration은 임의 숫자 한도나 가격을 추가하지 않는다.
6. WP06-05 자체 local path는 완료했지만 Phase 06 Exit Gate와 FR-SUB requirements는 actual provider/Store/account/device 결과 전까지 `PARTIAL`이다.

WP06-05 자체는 explicit household choice → provisional binding → Store fake → verified confirmation, conflict → aggregate support request, missing-assignment requeue, membership drift와 audited atomic transfer를 local DB/Flutter automation으로 실행하는 slice로 완료했다. 이는 production billing readiness나 실계정 검증 완료가 아니다.

## Rollback

- Flutter assignment repository/controller/composition, WP06-05 migration/tests/contracts/evidence를 한 slice로 revert한다.
- hosted migration 적용 후에는 destructive rollback 대신 forward migration으로 authenticated prepare/release/remediation execute를 revoke하고 purchase entry를 닫는다. confirmed assignment, entitlement와 immutable audit는 삭제하지 않는다.
- emergency stop은 billing ingestion을 disabled로 바꾸고 Store entry를 unavailable port로 닫는다. 기존 authoritative entitlement read는 유지한다.
- 이번 local 작업은 외부 provider/customer/ticket/account를 만들지 않아 external rollback 대상이 없다.

## Next Entry Condition

- 기능 우선순위의 다음 slice는 **WP06-06 lifecycle/limits enforcement**다. 이미 materialized된 `trialing|active|grace|billing_issue|expired|revoked`를 client visibility뿐 아니라 실제 Plus mutation/capacity gate에 연결하고 downgrade 시 기존 family data를 보존해야 한다.
- D-027 numeric Free/Plus limits가 승인되지 않았으므로 먼저 policy-neutral gate primitive와 unfinalized fail-closed behavior를 확장하고 임의 수치를 넣지 않는다.
- 실제 RevenueCat/Store/account/device 검증은 사용자 지시대로 모든 주요 기능 slice 뒤 마지막 Billing Gate에 유지한다.
