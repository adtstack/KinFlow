# Phase 06 WP06-01 Billing Domain and Schema Evidence

- Work Package: WP06-01 — provider-independent billing identity, verified event ordering, household assignment, authoritative entitlement, policy/limit primitive and Flutter read contract
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP06-01 LOCAL AUTOMATED PASS / HOSTED·REVENUECAT·STORE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP06-01 / D-024 | PASS FOR SERVER IDENTITY BOUNDARY / OVERALL PARTIAL | RevenueCat customer reference는 exact authenticated user UUID이고 provider/environment별 mapping이 unique하다. household ID를 customer identity로 사용할 수 없다. 실제 SDK login과 provider customer는 남았다. |
| WP06-01 / D-025 / FR-SUB-005 | PASS FOR LOCAL MATERIALIZATION / OVERALL PARTIAL | customer, normalized transaction, active household assignment와 household entitlement를 분리하고 customer/household 각각 active assignment 한 개만 허용한다. Store purchase/restore와 transfer는 남았다. |
| WP06-01 / FR-SUB-004 / FR-SUB-009 / NFR-REL-01 | PASS FOR VERIFIED NORMALIZED EVENT BOUNDARY / OVERALL PARTIAL | exact event replay는 한 transition만 만들고 request hash 충돌은 거부한다. older event는 stale, equal-time different event는 quarantine되어 state를 회귀시키지 않는다. HTTP signature와 provider API reconciliation은 남았다. |
| WP06-01 / FR-SUB-006 / D-028 | PASS FOR LOCAL LIFECYCLE / OVERALL PARTIAL | active/trial/grace/billing issue/cancel-valid/expired/refund/revoke/restore를 materialize하고 expiry/revoke에도 household/member/chore/calendar data를 삭제하지 않는다. 최종 UI와 provider timing은 남았다. |
| WP06-01 / FR-HH-010 / D-027 | PASS FOR POLICY PRIMITIVE / PRODUCT DECISION OPEN | versioned Free/Plus policy, optimistic version, JSON validation, Plus≥Free invariant와 members/activeSeries capacity를 제공한다. 미확정 limit는 fail closed하지만 D-027 수치 전에는 기존 mutation에 연결하지 않는다. |
| WP06-01 / NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW BILLING SURFACE | mutation과 policy command는 service-only다. receipt/provider snapshot은 ciphertext, transaction reference는 SHA-256 hash이고 client read에는 provider/customer/event/transaction/receipt 식별자가 없다. |
| WP06-01 / D-047 | PASS FOR PROVIDER-INDEPENDENT FLUTTER CONTRACT | entitlement domain/repository는 Flutter, Riverpod, Supabase, RevenueCat import가 없다. Supabase adapter는 exact 12-field RPC payload를 strict parse하고 household scope와 UTC timestamp를 재검증한다. |

## Authoritative Data and Ordering Contract

- `billing_runtime_config`는 private singleton이며 기본 `disabled`/`ingestion_enabled=false`다. environment를 명시적으로 열기 전에는 verified event도 Plus를 만들지 않는다.
- billing customer authority는 `(provider, environment, auth_user_id)`다. RevenueCat customer reference와 user UUID가 다르면 `IDENTITY_MISMATCH` quarantine이다.
- receipt authority는 `(provider, environment, provider_event_id, request_hash)`다. 같은 ID와 같은 hash는 replay count만 증가시키고 다른 hash는 `KFB20` collision으로 거부한다.
- customer의 `provider_occurred_at`은 monotonic하다. 더 오래된 event는 `OLDER_THAN_CUSTOMER_STATE`, 같은 timestamp의 다른 event는 `AMBIGUOUS_EVENT_ORDER`로 보존하고 entitlement를 바꾸지 않는다.
- provider/environment/customer와 transaction, assignment owner/household, entitlement assignment/owner/household 사이에 composite FK를 둔다. conflict를 새 account나 household로 조용히 rebind하지 않는다.
- initial assignment는 active Owner/Admin만 허용한다. Member, unknown user/household, 다른 customer/transaction/household binding은 stable quarantine reason으로 닫힌다.
- `plan_code`는 effective access이고 `status`는 lifecycle이다. `trialing|active|grace`는 Plus, `none|expired|revoked`는 Free이며 `billing_issue`만 최종 정책에 따라 둘 중 하나를 허용한다.
- expiry/revoke 후 assignment binding은 남는다. 이는 restore ownership theft를 막으며 explicit transfer/support remediation은 WP06-05다.

## Read and Limit Contract

- 모든 household에는 additive backfill/new-household trigger로 Free/none entitlement 한 행이 존재한다.
- authenticated active member의 `get_household_entitlement(household_id)`만 공개한다. 결과는 exact `household_id`, `entitlement_key`, `plan_code`, `status`, `source`, `current_period_end`, `will_renew`, `feature_limits`, `limits_finalized`, `verified_at`, `version`, `is_billing_owner` 12개 field다.
- Free default의 `is_billing_owner`도 nullable이 아니라 `false`다. 다른 household나 탈퇴한 member는 동일 generic authorization failure로 닫힌다.
- `billing_webhook_receipts`와 `billing_transactions`에는 client policy/grant가 없다. private runtime, immutable transition/policy audit와 capacity 함수는 authenticated/service-role direct access가 없다.
- plan policy는 optimistic version과 immutable audit를 사용한다. finalized JSON은 `members`와 `activeSeries`의 bounded non-negative integer만 허용하고 Plus가 Free보다 작을 수 없다.
- unfinalized/missing policy는 `KFB10|KFB11`, capacity 초과는 `KFB12`로 fail closed한다. D-027 전에는 이 primitive를 기존 create mutation에 연결하지 않아 provisional 값으로 기능을 차단하지 않는다.

## Flutter Contract

- `HouseholdEntitlement`는 provider-independent `free|plus`, lifecycle status와 `none|appStore|playStore|web|manualSupport` source를 표현하고 plan/status/source/terminal invariant를 생성 시 검증한다.
- feature limit map은 immutable하며 finalized limit에 대해서만 remaining capacity를 계산한다. missing/unfinalized limit를 unlimited로 오인하지 않는다.
- repository는 requested household ID와 payload household ID가 정확히 같은지, timestamp에 UTC offset이 있는지, domain invariant가 유지되는지 다시 검사한다.
- Supabase adapter는 `get_household_entitlement` RPC만 호출하고 exact top-level/nested key와 타입을 검증한다. provider exception message를 UI/domain으로 반사하지 않고 stable failure kind로 변환한다.
- 이 WP는 data/domain read contract까지만 구성했다. app provider composition, state controller, paywall/settings 화면과 RevenueCat SDK는 후속 WP다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 30 migrations including `20260808060000_billing_domain_and_entitlements.sql` and synthetic seed |
| focused WP06-01 billing pgTAP | PASS — 96/96 |
| full database regression | PASS — 35 files / 2,003 pgTAP tests |
| database lint | PASS — `public`, `app_private`, `extensions`; schema error 0 |
| focused WP06-01 Flutter suite | PASS — 11/11 domain/repository/Supabase adapter tests |
| full Flutter regression | PASS — 550 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — exact Flutter 3.44.7 `analyze --no-pub`; issue 0 |
| formatter | PASS — 337 Dart files checked; 0 changed |
| repository code generation check | PASS — build_runner inspected 332/664 inputs; wrote 0 outputs; 8 generated files current |
| public configuration validation | PASS — dev/prod examples remain allowlisted; WP06-01 added no public billing key |
| repository secret scan | PASS — high-confidence secret 0 |
| repository JavaScript contract suite | PASS — 97/97 |
| matrix structure | PASS — billing 38×11, test 62×11, requirements 116×18, risk 30×15 |
| whitespace | PASS — `git diff --check`, output 0 before evidence finalization; post-document check repeated |

Database fixtures cover exact enum/schema/columns/constraints/indexes/triggers, forced RLS/grants/search path, default Free projection, disabled runtime, policy version/validation, capacity, authenticated mutation denial, environment/identity quarantine, duplicate/collision/stale/equal-time ordering, cancellation/grace/billing issue/expiration/refund/revoke/restore, customer/transaction/assignment conflicts, Member denial, membership read and immutable audit.

Flutter fixtures use only synthetic UUIDs, deterministic timestamps, fake data sources and fake Supabase RPC responses. No production credential, customer account, family content, Store transaction or provider network was used.

## Files and Migration

- Migration: `supabase/migrations/20260808060000_billing_domain_and_entitlements.sql`
- Database tests: `supabase/tests/database/billing_domain_and_entitlements.test.sql`
- Flutter domain/data: `apps/kinflow_app/lib/features/billing/`
- Supabase Flutter adapter: `apps/kinflow_app/lib/infrastructure/supabase/supabase_entitlement_data_source.dart`
- Flutter tests: `apps/kinflow_app/test/features/billing/`, `apps/kinflow_app/test/infrastructure/supabase_entitlement_data_source_test.dart`
- Decision: `docs/adr/ADR-0006-server-authoritative-household-entitlement.md`
- Contracts: database schema, RLS and domain-event contracts
- Governance: Phase 06, consolidated implementation/master specs, billing/test/requirements/risk matrices and `WP06_01_WORKPLAN.md`
- WP06-01 runtime dependency, RevenueCat SDK, native permission, Android/iOS source, Edge HTTP/OpenAPI and public configuration delta: **none**

## Security, Privacy, and Data Impact

- billing mutation은 client-supplied entitlement나 role만 믿지 않는다. service-only command도 exact runtime environment, auth user identity, current membership role, composite binding과 event ordering을 모두 검증한다.
- public billing table은 모두 RLS enabled/forced다. authenticated에는 self customer와 active-member assignment/catalog/entitlement select만 있으며 receipt/transaction과 private audit에는 policy/grant가 없다.
- receipt body와 provider snapshot은 최대 1 MiB ciphertext만 허용한다. raw transaction/original transaction reference는 저장하지 않고 32-byte SHA-256 hash만 저장한다.
- client projection, Flutter domain, error와 evidence에는 provider event/customer/transaction reference, receipt, ciphertext, raw provider error와 family content를 포함하지 않는다.
- applied transition과 policy change audit는 append-only trigger로 update/delete를 거부한다. quarantine reason은 allowlisted stable code이고 raw payload를 반사하지 않는다.
- downgrade는 entitlement access만 바꾸며 household/member/chore/calendar row를 삭제하지 않는다. 실제 account deletion retention/cancellation 정책은 Phase 07과 법적 결정 전까지 별도다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Supabase/RevenueCat/Store 계정, provider project/customer, hosted Supabase migration과 remote RLS는 **NOT RUN**이다.
- RevenueCat webhook HTTP authorization/signature, raw payload normalization, provider API reconciliation, scheduler/dead-letter/alert와 key-manager ciphertext 복호화는 **NOT IMPLEMENTED/NOT RUN**이며 WP06-04 범위다.
- App Store/Google Play offering, purchase, pending, cancel, restore, reinstall, refund, account switch와 cross-platform entitlement는 **NOT RUN**이다.
- physical Android/iOS/Web의 purchase UI, background/provider delay, locale price, accessibility와 real-device account/household conflict는 **NOT RUN**이다.
- 실제 계정·sandbox·실기기 검증은 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 마지막 Billing Gate에 유지한다.

## Remaining Risks and Completion Boundary

1. D-027 가격, Free/Plus 수치 한도, trial과 annual discount가 OPEN이다. 따라서 WP06-02 product UX와 WP06-06 mutation limit wiring을 완료로 주장할 수 없다.
2. runtime은 local fixture에서만 sandbox로 열었다. hosted environment는 기본 disabled이며 signature adapter와 secret deployment 전에는 열면 안 된다.
3. provider timestamp가 같은 서로 다른 event는 안전을 위해 quarantine된다. actual provider ordering key/API reconciliation 없이 자동 해소하지 않는다.
4. assignment를 expiry/revoke 후 보존하므로 billing owner leave/account delete/household transfer에는 explicit WP06-05 policy와 support flow가 필요하다.
5. immutable audit는 데이터 근거를 제공하지만 operator read-only tool, retention, runbook, alert와 remediation UI는 아직 없다.
6. Flutter entitlement read adapter는 app composition/UI에 연결되지 않았다. provider SDK snapshot도 권한을 직접 만들 수 없다는 server confirmation state가 후속 slice에 필요하다.
7. Phase 06 상위 Exit Gate인 Store sandbox lifecycle, hosted reconciliation, cross-account/household conflict와 실기기 검증은 계속 `PARTIAL`이다.

WP06-01 자체는 local synthetic schema/domain/read-contract slice로 완료했다. 이는 production billing 또는 Store readiness 완료를 의미하지 않는다.

## Rollback

- hosted 배포 전에는 migration, billing Dart slice, tests, ADR와 계약 문서를 함께 revert할 수 있다.
- hosted 적용 후에는 ingestion runtime을 disabled로 유지하거나 service-only config로 즉시 닫고 current Free/none read projection을 보존한다.
- applied migration을 수정·삭제하거나 billing/family row를 destructive drop하지 않는다. forward migration으로 execute revoke, policy/view/function 교체와 additive correction을 수행한다.
- Flutter slice는 아직 composition되지 않았으므로 adapter/provider wiring을 제거해도 기존 app path에 영향이 없다. 새 RevenueCat SDK나 native permission은 없어 mobile rollback이 필요하지 않다.

## Next Entry Condition

- 정규 다음 package인 WP06-02 product catalog/paywall은 D-027 가격·limit·trial/annual policy와 Store product identifiers가 확정돼야 실제 local price/copy를 구현할 수 있다.
- D-027을 임의로 결정하지 않고 기능 개발을 계속하려면 다음 안전한 slice는 **WP06-03A provider-neutral BillingPort와 purchase/restore pending-server-confirmation application state**다. deterministic fake gateway로 성공·취소·pending·실패·account mismatch를 검증하고 실제 RevenueCat 계정/Store sandbox는 마지막 Gate에 둔다.
- RevenueCat SDK를 추가하는 후속 slice는 dependency/license/privacy/native-platform 검토와 lockfile Gate를 별도로 통과해야 하며 client snapshot이 server entitlement를 직접 승인하게 만들지 않는다.
