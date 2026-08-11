# Phase 06 WP06-04 RevenueCat Webhook and Reconciliation Evidence

- Work Package: WP06-04 — signed RevenueCat webhook ingress, metadata-only inbox, leased authoritative subscriber reconciliation, bounded retry/dead-letter와 aggregate health
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Node.js 24.15.0, Flutter 3.44.7, Dart 3.12.2, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP06-04 LOCAL AUTOMATED PASS / REVENUECAT PROJECT·SECRET·API·HOSTED SCHEDULER·ALERT·STORE·REAL ACCOUNT/DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP06-04 / FR-SUB-004 / NFR-SEC-02 | PASS FOR LOCAL SIGNED INGRESS / OVERALL PARTIAL | exact configured full Authorization과 raw-body HMAC-SHA256을 JSON parse 전에 모두 검증한다. timestamp tolerance 300초, POST/JSON/no-query/256 KiB bound와 content-free 오류가 deterministic tests를 통과했다. 실제 RevenueCat secret/delivery는 사용하지 않았다. |
| WP06-04 / FR-SUB-004 / NFR-REL-01 | PASS FOR DURABLE IDEMPOTENT INBOX / OVERALL PARTIAL | provider event ID + raw SHA-256 hash로 exact replay를 한 row에 합치고 delivery count만 증가시킨다. 동일 ID/다른 body는 `KFB40`, 동시 최초 delivery는 transaction advisory lock으로 직렬화한다. |
| WP06-04 / FR-SUB-009 | PASS FOR SYNTHETIC AUTHORITATIVE REFRESH / OVERALL PARTIAL | fixed RevenueCat API v1 subscriber endpoint를 exact auth UUID로 조회하는 runtime boundary, strict response size/status mapping과 provider request-time normalized reconciliation을 fake responses로 검증했다. 실제 API는 호출하지 않았다. |
| WP06-04 / D-024 / D-025 / FR-SUB-005 | PASS FOR FAIL-CLOSED ASSIGNMENT | subscriber original App User ID와 environment가 claim과 같아야 한다. persisted active billing assignment가 없으면 provider fetch/entitlement grant 없이 `ASSIGNMENT_REQUIRED` dead letter이며 active household를 추정하지 않는다. |
| WP06-04 / FR-SUB-006 | PASS FOR LOCAL SNAPSHOT MAPPING / OVERALL PARTIAL | trial/active/grace/billing issue/cancel-valid/prepaid/expired/refunded를 `trialing|active|grace|billing_issue|expired|revoked`와 Free/Plus/will-renew로 strict 변환한다. 실제 provider lifecycle timing과 UI는 남았다. |
| WP06-04 / NFR-REL-01 | PASS FOR LEASE/RETRY CONCURRENCY | `FOR UPDATE SKIP LOCKED`, opaque lease token/expiry, max 5 attempts, 1m/5m/30m/2h retry, same-lease completion replay, expired lease와 terminal dead letter를 DB가 소유한다. 잠긴 선두 job을 건너뛰는 경쟁 worker 테스트가 통과했다. |
| WP06-04 / NFR-PRIV-01 / NFR-OBS-01 | PASS FOR METADATA-ONLY STORAGE AND HEALTH / OVERALL PARTIAL | raw webhook/API response를 저장하지 않는다. private job/audit tables에는 bounded routing/lease/result metadata만 있고 aggregate health는 queue/retry/dead-letter/oldest due만 제공한다. hosted dashboard/pager는 남았다. |

## Implemented Contract

- `revenuecat-webhook`은 gateway JWT를 사용하지 않고 function 내부 dedicated full Authorization + `X-RevenueCat-Webhook-Signature`를 모두 검증한다. HMAC input은 `timestamp + "." + exact raw bytes`다.
- ingress는 body를 parse하기 전에 실제 bytes를 256 KiB로 제한한다. common `api_version`, event ID/type/timestamp는 strict 검증하되 provider future fields는 허용한다.
- analytics/paywall/test event는 ignored, transfer/alias/purchase-redeemed 또는 identity/environment가 없는 event는 manual review, exact UUID+environment의 future event는 authoritative refresh trigger로 queue한다.
- `app_private.billing_reconciliation_jobs`는 raw request digest와 bounded metadata만 보존한다. exact replay는 한 job에 합치고 같은 event ID의 hash collision을 거부한다. direct table access는 `service_role`까지 revoke한다.
- worker는 stale assigned customer를 periodic job으로 bounded schedule하고 due jobs를 lease claim한다. runtime ingestion disabled이면 schedule/claim은 0이며 environment mismatch는 provider network 전에 terminal로 닫힌다.
- provider request는 fixed `https://api.revenuecat.com/v1/subscribers/{uuid}` GET, server-only Bearer key, no redirect, 8초 timeout과 1 MiB response limit을 사용한다.
- mapper는 original App User ID, sandbox flag, configured entitlement, matching product/subscription, Play/App Store, transaction reference, period type와 UTC timestamps를 strict 검증한다. provider `request_date`가 worker 시계보다 5분 이상 미래이면 거부한다.
- valid snapshot은 existing WP06-01 `apply_verified_billing_event`에 `reconciliation` event로 전달한다. apply 결과가 applied/stale가 아니면 job은 terminal quarantine code로 닫힌다.
- provider network/408/429/5xx와 RPC outage만 retryable이다. auth/not-found/schema/identity/environment/product/subscription/store/assignment mismatch는 permanent dead letter다.
- transition audit는 immutable하고 health/result response는 aggregate-only다. provider event/customer/transaction/product ID, subscriber attributes, receipt와 raw body를 response/audit/health에 포함하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 31 migrations including `20260808070000_billing_webhook_reconciliation.sql` and synthetic seed |
| focused webhook + reconciliation Node contracts | PASS — 18/18 |
| repository JavaScript contract regression | PASS — 115/115 |
| focused WP06-04 pgTAP + concurrency | PASS — 2 files / 47 tests |
| full database regression | PASS — 37 files / 2,050 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; schema error 0 |
| focused public-config/secret boundary Flutter tests | PASS — 14/14 |
| full Flutter regression | PASS — 599 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — `analyze --no-pub --fatal-infos --fatal-warnings`; issue 0 |
| formatter | PASS — 358 Dart files checked; 0 changed |
| public configuration validation | PASS — exact public allowlist; all new RevenueCat/worker server keys rejected from client config |
| repository secret scan | PASS — high-confidence secret 0 |
| repository code generation check | PASS — build_runner wrote 0 outputs; generated-code drift 0 across 8 files |
| OpenAPI/domain/reconciliation YAML parse | PASS — 3 contracts parsed |
| CI workflow/supply-chain contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| matrix structure | PASS — billing 38×11, test 62×11, requirements 116×18, risk 30×15 |
| whitespace | PASS — `git diff --check`, output 0 before evidence finalization; post-document check repeated |

Node fixtures cover exact Authorization, raw whitespace tamper, stale/future/malformed signature, method/query/content/body bounds, strict/future event routing, replay/collision, RPC redaction, every lifecycle mapping, missing assignment, provider status/network/oversize/content-type handling, aggregate worker response and fixed URL/credentials.

Database fixtures cover exact schema/function/grants/search path, disabled runtime, exact replay/collision, ignored/manual/environment routing, assignment fail-close, retry schedule, completion replay, persisted assignment resolution, periodic scheduling, aggregate health, immutable metadata/audit and `SKIP LOCKED` competition.

All identities, timestamps, HMAC keys, subscriber responses and Store transaction references are synthetic local fixtures. No provider network request, production credential, customer, receipt or family content was used.

## Files and Migration

- Migration and DB tests:
  - `supabase/migrations/20260808070000_billing_webhook_reconciliation.sql`
  - `supabase/tests/database/billing_webhook_reconciliation.test.sql`
  - `supabase/tests/database/billing_webhook_reconciliation_concurrency.test.sql`
- Signed ingress:
  - `supabase/functions/revenuecat-webhook/index.ts`
  - `supabase/functions/_shared/billing_webhook_contract.mjs`
  - `supabase/functions/_shared/billing_webhook_runtime.mjs`
- Reconciliation worker:
  - `supabase/functions/billing-reconciliation-worker/index.ts`
  - `supabase/functions/_shared/billing_reconciliation_contract.mjs`
  - `supabase/functions/_shared/billing_reconciliation_runtime.mjs`
- Edge contracts:
  - `scripts/ci/billing-webhook-contract.test.mjs`
  - `scripts/ci/billing-reconciliation-contract.test.mjs`
- Config boundary:
  - `supabase/config.toml`
  - `apps/kinflow_app/lib/app/config/app_public_configuration.dart`
  - `apps/kinflow_app/tool/security/secret_scanner.dart`
- Normative contract: `docs/contracts/billing-reconciliation.yaml.md`, OpenAPI, DB schema, domain event and env contracts
- Dependency/lockfile/native permission/public client key delta: **none** in WP06-04.

## Security, Privacy, Data and Operational Impact

- RevenueCat webhook credential, HMAC signing secret, secret API key and worker scheduler secret are distinct server-only settings. user JWT, service-role key and Android public SDK key are not reused as webhook/scheduler credentials.
- raw bytes are held only long enough to verify HMAC, parse common metadata and compute SHA-256. Database rows contain no raw JSON, API response, customer/transaction reference, product, attribute, alias or receipt.
- fixed provider/RPC URLs, no redirect, bounded timeout/body, exact auth UUID and strict response keys reduce SSRF, body amplification, confused-deputy and identity-alias risks.
- account/household selection is not accepted from a webhook. Only a persisted active billing assignment can be returned by claim and passed to the normalized service command.
- private queue and immutable audit are not directly selectable by authenticated or service roles. Service-only RPCs expose bounded job leases or aggregate health without provider bodies.
- webhook always returns stable content-free errors. Runtime exception/provider/SQL response bodies and secret material are neither logged nor reflected by the implemented code.
- operational enablement remains explicit through WP06-01 `billing_runtime_config`; local tests temporarily enable sandbox inside rolled-back transactions.

## Manual and Deferred Validation

- 사용자 지시에 따라 RevenueCat project, webhook URL, Authorization/HMAC/API secrets, customer/subscriber, Google Play product/license tester/internal track와 actual Store account는 **NOT USED**다.
- hosted Supabase deploy, secret rotation, cron invocation, dashboard/pager, dead-letter operator tool와 outage drill은 **NOT RUN**이다.
- actual RevenueCat retry, duplicate, event ordering, future event type, API v1 schema/latency/rate limit과 provider `request_date` skew는 **NOT RUN**이다.
- real purchase/restore/reinstall/pending/cancel/refund/revoke, multiple KinFlow/Store accounts, household transfer와 physical device는 **NOT RUN**이다.
- missing-assignment requeue/intent, transfer/alias remediation와 support audit command는 WP06-05다.
- paywall/product/price/trial/benefit copy와 D-027 numeric limits는 WP06-02/06 전까지 계속 OPEN이다.

## Remaining Risks and Completion Boundary

1. Synthetic API v1 fixtures prove the parser boundary, not that a deployed RevenueCat project returns every Store lifecycle shape identically. Hosted contract smoke remains required.
2. RevenueCat webhook/API credential rotation and overlapping HMAC signature policy need a deployment runbook. Current local contract accepts one configured `v1` signature.
3. assignment가 없는 최초 purchase webhook은 의도적으로 dead letter다. WP06-05 explicit purchase intent/household assignment 없이 자동 재처리하거나 active household를 추정하면 안 된다.
4. periodic repair requires an existing billing customer + active assignment. First-purchase recovery is therefore WP06-05 command/remediation responsibility다.
5. aggregate health exists but hosted alert thresholds, owner/runbook, retention and safe operator requeue UI가 없다.
6. product entitlement identifier와 Store product mapping은 server config에 존재하지만 actual catalog/D-027 approval 전 production enablement가 금지된다.
7. WP06-04 자체 local path는 완료했지만 Phase 06 Exit Gate와 FR-SUB requirements는 actual provider/Store/account/device 결과 전까지 `PARTIAL`이다.

WP06-04 자체는 signed trigger → durable metadata inbox → leased provider refresh → existing normalized entitlement apply → retry/dead-letter/health의 local automated slice로 완료했다. 이는 production billing readiness나 actual RevenueCat/Google Play 검증 완료가 아니다.

## Rollback

- 두 Edge functions, shared modules, contract tests, config sections, migration/tests와 WP06-04 docs를 한 slice로 revert한다.
- hosted emergency stop은 RevenueCat webhook delivery를 disable하고 `billing_runtime_config.ingestion_enabled=false`로 worker schedule/claim을 닫는다. 기존 server entitlement read와 WP06-03 client pending/refresh는 유지한다.
- hosted migration 적용 후에는 destructive rollback 대신 forward migration으로 RPC execute를 revoke하고 functions를 교체한다. 적용된 entitlement/customer/assignment row나 audit를 삭제하지 않는다.
- 이번 local 작업은 provider account/customer/secret을 만들지 않아 외부 rollback 대상이 없다.

## Next Entry Condition

- 기능 우선순위의 다음 안전한 slice는 **WP06-05 explicit paid-household assignment intent/conflict/remediation command**다. first purchase에서 household 선택을 서버에 고정하고 missing-assignment dead letter를 안전하게 requeue할 수 있어야 한다.
- transfer/alias, billing owner leave/account delete와 restore conflict는 최근 인증, optimistic version, one-active-assignment invariant와 immutable support audit를 함께 가져야 한다.
- D-027 가격/limits/product copy를 임의로 정하지 않고, 실제 provider/Store/account/device 검증은 사용자 지시대로 기능 개발의 마지막 Billing Gate에 유지한다.

## Official References

- RevenueCat webhook authorization, HMAC, retries and idempotency: <https://www.revenuecat.com/docs/integrations/webhooks>
- RevenueCat webhook event types and fields: <https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields>
- RevenueCat event flows and out-of-order delivery: <https://www.revenuecat.com/docs/integrations/webhooks/event-flows>
- RevenueCat API v1 subscriber endpoint/authentication: <https://www.revenuecat.com/docs/api-v1>
- RevenueCat API key security: <https://www.revenuecat.com/docs/projects/authentication>
