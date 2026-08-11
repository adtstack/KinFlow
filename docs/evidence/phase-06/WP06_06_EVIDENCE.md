# Phase 06 WP06-06 Lifecycle and Feature Enforcement Evidence

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 범위: entitlement lifecycle client policy, versioned feature-enforcement activation, safe household gate projection, active member와 recurring chore/calendar capacity의 authoritative mutation wiring, downgrade data preservation
- 제외: D-027 실제 Free/Plus 숫자 결정, 가격·trial·annual discount, paywall, hosted policy rollout, RevenueCat/Store 실계정·sandbox·실기기

## Acceptance Result

| 계약 | 결과 |
|---|---|
| D-027 수치 한도를 추정하지 않고 기본 rollout이 닫혀 있음 | PASS — 두 baseline plan은 unfinalized이고 `feature_enforcement_enabled=false`; activation 전 gate는 nullable limit의 `policy_unavailable`이며 mutation trigger는 기능 개발을 막지 않음 |
| activation이 service-only, versioned, audited임 | PASS — expected runtime version과 correlation ID 필수, Free/Plus readiness 및 Plus≥Free 검증, immutable `billing_policy_events` 기록 |
| enabled policy를 불완전하게 만들 수 없음 | PASS — inactive/unfinalized/필수 key 제거/member<1 update 거부; emergency runtime disable은 허용 |
| active member에게 safe aggregate gate만 노출 | PASS — exact 15-field projection, membership check, feature/delta validation, provider/customer/transaction/receipt/owner/member/content field 없음 |
| member/recurring mutation이 같은 authoritative gate를 사용 | PASS — member insert/reactivation, first recurring chore/event revision, recurring series reactivation trigger가 동일 serialized capacity function 호출 |
| 동시 요청이 마지막 capacity slot을 초과하지 않음 | PASS — household+feature transaction advisory lock; 두 concurrent member insert 중 정확히 하나만 commit |
| one-time과 기존 데이터 작업을 보존 | PASS — one-time chore/event는 `activeSeries`에서 제외; over-limit read/update/cancel/delete 및 one-time creation 유지 |
| downgrade가 기존 family data를 삭제하지 않음 | PASS — expiry/revoke/over-limit fixture 유지, 새·재활성화 member/recurring expansion만 거부 |
| Flutter lifecycle/gate가 provider-neutral이고 fail closed | PASS — 모든 lifecycle 상태, billing_issue Free/Plus, exact projection/UTC/version/산술/request echo invariant와 unavailable fallback 검증 |
| mutation 오류가 안정된 localized UX로 전달됨 | PASS — chore/calendar PostgREST와 invite Edge의 KFB10/KFB11/KFB12를 policy-unavailable/limit-reached domain failure 및 EN/KO/EN-XA l10n으로 매핑 |

## Implemented Contract

- `configure_billing_feature_enforcement(enabled, expectedVersion, correlationId)`는 service role만 실행한다. enable은 active finalized Free/Plus 정책 모두에 `members`, `activeSeries`가 있고 members≥1이며 Plus가 Free의 모든 capacity보다 작지 않을 때만 성공한다.
- runtime change는 version을 증가시키고 `runtime/feature_enforcement` immutable policy audit를 남긴다. enabled 상태에서는 required catalog policy를 inactive/unfinalized로 만들거나 필수 key를 제거할 수 없다.
- `get_household_feature_gate(household, feature, delta)`는 active household member만 실행하며 `allowed | policy_unavailable | feature_unconfigured | limit_reached`를 반환한다. feature는 `members | activeSeries`, delta는 1..1000이다.
- `members` usage는 `removed_at is null`인 구성원이다. `activeSeries`는 active revision이 recurring인 non-deleted chore/event series 합계이며 one-time series는 제외한다.
- actual enforcement는 runtime enabled 확인 뒤 household+feature advisory transaction lock을 잡고 entitlement와 catalog를 `FOR SHARE`로 고정한 후 usage를 다시 계산한다. client count, cached entitlement 또는 provider snapshot은 authority가 아니다.
- capacity expansion trigger는 active member insert/reactivation, first recurring chore/event revision과 deleted recurring series reactivation이다. `KFB10` policy unavailable, `KFB11` feature unconfigured, `KFB12` limit reached다.
- downgrade/expiry/refund/revoke 뒤 existing over-limit data는 삭제하지 않는다. 기존 read/update/cancel/delete, member removal과 one-time chore/event creation은 capacity expansion이 아니므로 유지한다.
- Flutter domain은 plan/status 조합, UTC timestamp, version positivity와 remaining arithmetic을 strict validate한다. gate repository는 RPC request echo가 다르면 invalid payload로 닫는다.
- invite Edge contract `2026-08-08-wp06-06`은 member insert trigger SQLSTATE를 `FEATURE_POLICY_UNAVAILABLE`(503/retryable) 또는 `FEATURE_LIMIT_REACHED`(409/final)로 변환하고 provider detail을 반사하지 않는다.
- 상세 normative contract는 `docs/contracts/billing-feature-enforcement.yaml.md`다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 33 migrations including `20260808090000_billing_lifecycle_feature_enforcement.sql` and synthetic seed |
| focused WP06-06 pgTAP | PASS — 2 files / 48 tests; main 42 + advisory-lock concurrency 6 |
| full database regression | PASS — 41 files / 2,166 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; schema error 0 |
| focused WP06-06 Flutter/compatibility suites | PASS — 115 executions across lifecycle/gate/parser/repository/error/l10n/composition tests |
| full Flutter regression | PASS — 635 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — issue 0 |
| formatter | PASS — 381 Dart files checked; 0 changed |
| repository JavaScript contract regression | PASS — 115/115 |
| invite Edge contract | PASS — 25/25 including KFB10/KFB11/KFB12 |
| member Edge compatibility | PASS — 18/18 |
| localization generation | PASS — exact Flutter 3.44.7 `gen-l10n`; generated feature-policy/limit keys present in EN/KO/EN-XA |
| public configuration validation | PASS — exact public allowlist; enforcement/provider secrets not added |
| repository secret scan | PASS — high-confidence secret 0 |
| repository code generation check | PASS — build_runner wrote 0 outputs; generated-code drift 0 across 8 files |
| feature/assignment/reconciliation/domain/error/OpenAPI YAML parse | PASS — 6 contracts parsed |
| CI workflow/supply-chain contract and actionlint | PASS — 5 jobs, 17 pinned action uses, `contents:read`; workflow lint clean |
| matrix structure | PASS — billing 38×11, test 62×11, requirements 116×18, risk 30×15, release 23×10 |
| whitespace | PASS — `git diff --check` output 0 after final documentation |

All household IDs, users, members, policy values, versions, timestamps, series and concurrency actors are synthetic local fixtures. No production credential, provider customer, transaction, receipt, family content, RevenueCat/Store account, sandbox purchase or physical device was used. The only external download was the repository-pinned actionlint tooling needed for workflow lint; it did not access an application provider or account.

## Files and Migration

- Migration and DB tests:
  - `supabase/migrations/20260808090000_billing_lifecycle_feature_enforcement.sql`
  - `supabase/tests/database/billing_lifecycle_feature_enforcement.test.sql`
  - `supabase/tests/database/billing_lifecycle_feature_enforcement_concurrency.test.sql`
- Flutter lifecycle/gate:
  - `apps/kinflow_app/lib/features/billing/domain/entities/household_entitlement.dart`
  - `apps/kinflow_app/lib/features/billing/domain/entities/household_feature_gate.dart`
  - `apps/kinflow_app/lib/features/billing/domain/repositories/household_feature_gate_repository.dart`
  - `apps/kinflow_app/lib/features/billing/data/datasources/household_feature_gate_data_source.dart`
  - `apps/kinflow_app/lib/features/billing/data/repositories/provider_household_feature_gate_repository.dart`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_household_feature_gate_data_source.dart`
  - `apps/kinflow_app/lib/features/billing/application/unavailable_household_feature_gate_repository.dart`
- Composition and stable UX:
  - `apps/kinflow_app/lib/features/billing/presentation/providers/billing_providers.dart`
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
  - chore/calendar/invite data failure, repository failure and localized presentation mappings
  - EN/KO/EN-XA ARB and generated localizations
  - `supabase/functions/_shared/invite_contract.mjs`
- Focused Flutter tests:
  - `apps/kinflow_app/test/features/billing/household_feature_gate_test.dart`
  - `apps/kinflow_app/test/features/billing/provider_household_feature_gate_repository_test.dart`
  - `apps/kinflow_app/test/features/billing/household_entitlement_test.dart`
  - `apps/kinflow_app/test/features/billing/feature_limit_failure_message_test.dart`
  - `apps/kinflow_app/test/infrastructure/supabase_household_feature_gate_data_source_test.dart`
- Contracts/traces:
  - `docs/contracts/billing-feature-enforcement.yaml.md`
  - database schema, RLS, domain event and OpenAPI contracts
  - Phase 06, billing specification, billing/test/requirements/risk matrices and this evidence
- Runtime dependency, lockfile, native permission and client public config delta: **none in WP06-06**.

## Security, Privacy and Operational Impact

- activation과 numeric policy mutation은 authenticated client가 실행할 수 없다. direct billing/runtime/private-helper access는 service role을 포함해 revoke되고 reviewed RPC execute만 최소 grant한다.
- active membership은 gate RPC에서 server-side 확인한다. household UUID를 아는 것만으로 usage나 plan을 읽을 수 없다.
- gate는 aggregate count/limit/decision/version만 반환한다. provider/customer/transaction/receipt/billing-owner/member ID와 chore/calendar/family content가 없다.
- advisory lock key는 household+feature이며 최종 count check와 insert가 같은 transaction에 있다. UI preflight는 race correctness를 담당하지 않는다.
- enabled policy의 불완전 update는 trigger로 차단한다. emergency disable은 data mutation 없이 enforcement만 닫고 audit version을 남긴다.
- `policy_unavailable`은 임의 Free 값 fallback을 금지한다. `feature_unconfigured`도 limit을 노출하지 않는다.
- invite Edge error는 SQLSTATE만 안정 코드로 바꾸며 DB message/detail을 client에 반사하지 않는다.

## Manual and Deferred Validation

- 사용자 지시에 따라 RevenueCat project/customer/API, Apple/Google Store product/account, sandbox purchase/restore/reinstall, Google license tester와 physical device는 **NOT USED / NOT RUN**이다.
- D-027 household member/active recurring-series 실제 Free/Plus 수치, price/trial/annual discount와 grace/billing-issue product policy는 **OPEN**이다. 따라서 production feature enforcement는 기본 disabled다.
- hosted Supabase migration/deploy, policy approval/activation, service credential boundary, remote concurrency/latency와 emergency-disable operator drill은 **NOT RUN**이다.
- paywall, subscription management/deep link, lifecycle banner와 localized product/price/copy는 WP06-02/마지막 Billing Gate에 남는다. 이번 slice의 localized UX는 server feature-policy/limit failure까지다.
- actual multi-account/member invite race, real provider lifecycle, offline/reconnect와 old app binary against migrated remote DB는 마지막 Gate다.

## Remaining Risks and Completion Boundary

1. Local synthetic limits는 제품 승인 값이 아니다. D-027이 승인되기 전 `configure_plan_feature_limits`와 enforcement activation을 production에서 실행하면 안 된다.
2. gate preflight와 actual mutation 사이 race는 server trigger가 안전하게 막지만, paywall/upsell 화면은 아직 없으므로 사용자는 generic localized plan-limit 안내만 받는다.
3. recurring usage는 현재 active revision semantics를 기준으로 한다. 향후 새로운 premium capacity key나 non-series resource가 추가되면 같은 activation/trigger/matrix 계약을 확장해야 한다.
4. DB trigger의 hosted lock contention, latency, plan rollout/rollback observability와 alert는 local pgTAP으로 production SLO를 증명하지 않는다.
5. billing_issue가 Free 또는 Plus일 수 있는 선택은 server materialized policy다. final grace/billing policy 전 client가 이를 하드코딩하면 안 된다.
6. WP06-06 local path는 완료했지만 D-027, paywall, actual provider/Store/account/device 결과가 없으므로 Phase 06 Exit Gate와 FR-SUB-006은 계속 `PARTIAL`이다.

WP06-06 자체는 finalized policy → versioned activation → safe aggregate gate → serialized member/recurring mutation → localized stable failure와 downgrade preservation을 local DB/Flutter/Edge automation으로 실행하는 slice로 완료했다. 이는 production billing readiness나 실계정 검증 완료가 아니다.

## Rollback

- Flutter gate/lifecycle additions, invite error mapping, WP06-06 migration/tests/contracts/evidence를 한 slice로 revert한다.
- hosted migration 적용 후에는 destructive rollback 대신 `configure_billing_feature_enforcement(false, expectedVersion, correlationId)`로 emergency disable하고 forward migration으로 RPC/trigger를 조정한다.
- rollback 또는 disable은 entitlement, plan policy, household member, chore/calendar series와 immutable policy audit를 삭제하지 않는다.
- 이번 local 작업은 외부 product/provider/customer/account를 만들지 않아 application-provider rollback 대상이 없다.

## Next Entry Condition

- Phase 06의 남은 큰 기능은 WP06-02 paywall/product presentation과 subscription management UX지만 실제 product/price/trial/limit copy는 D-027 결정이 필요하다.
- 실계정 테스트를 마지막에 유지하면서 기능 우선으로 계속하려면 다음 독립 slice는 Phase 07 profile/settings 또는 privacy export/deletion의 server-first local contract가 적합하다.
- billing UI를 먼저 진행한다면 Store 값을 하드코딩하지 않는 policy-neutral paywall shell과 unavailable/pending/lifecycle 상태만 구현하고 실제 가격·purchase evidence는 마지막 Billing Gate로 남겨야 한다.
