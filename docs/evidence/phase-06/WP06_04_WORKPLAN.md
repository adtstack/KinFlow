# Phase 06 WP06-04 RevenueCat Webhook and Reconciliation Workplan

- 상태: `COMPLETED — LOCAL AUTOMATED PASS (2026-08-08)`
- 범위: RevenueCat server-to-server webhook authorization + raw-body HMAC ingress, private idempotent inbox, leased reconciliation worker, authoritative subscriber refresh, WP06-01 normalized-event application, bounded retry/dead-letter와 aggregate health
- 제외: RevenueCat project/webhook/API secret 실제 등록, Google Play product/account/sandbox, first paid-household assignment/transfer policy, paywall, iOS, hosted scheduler/alert sink와 실기기

## Entry Decision

- WP06-01의 `apply_verified_billing_event`가 environment, customer/transaction hash, assignment, monotonic provider time와 entitlement materialization의 authority다. 이번 slice는 이 함수 앞에 provider-authenticated HTTP/inbox를, 뒤에 authoritative subscriber refresh worker를 연결하며 동일 권한 규칙을 우회하지 않는다.
- RevenueCat은 webhook을 at-least-once로 전달하고 같은 retry에 같은 event `id`를 사용한다. ingress는 raw request hash + provider event ID로 exact replay를 합치고 같은 ID의 다른 body는 collision으로 닫는다.
- RevenueCat은 webhook payload 자체를 최종 상태로 복사하기보다 subscriber API를 다시 조회할 것을 권장한다. worker는 webhook을 trigger로만 사용하고 `GET /v1/subscribers/{app_user_id}` snapshot을 strict parse해 `reconciliation` normalized event를 만든다.
- Webhook에는 KinFlow paid household가 없다. 현재 active-household selection을 purchase-time intent로 추정하면 account/household switch 사이에 잘못 부여될 수 있으므로 금지한다. active billing assignment가 없으면 `ASSIGNMENT_REQUIRED` dead letter이며 WP06-05의 explicit assignment/intent 후에만 재처리한다.
- actual secrets와 accounts 없이 handler/RPC/provider boundaries를 injection한 deterministic JS tests와 local pgTAP으로 완료 근거를 만든다. live provider delivery는 마지막 Billing Gate다.

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP06-04 / FR-SUB-004 | exact configured Authorization과 `X-RevenueCat-Webhook-Signature`를 모두 검증한다. HMAC-SHA256 input은 JSON 재직렬화가 아닌 `timestamp + "." + raw body bytes`이고 timestamp tolerance는 300초다. |
| WP06-04 / FR-SUB-004 / NFR-SEC-01 | POST + JSON + no-query + bounded body만 허용한다. 인증 실패, malformed/oversized payload와 RPC outage는 stable content-free response로 매핑하고 raw body/provider identifiers/secrets를 response 또는 log에 반사하지 않는다. |
| WP06-04 / FR-SUB-004 / NFR-REL-01 | private inbox는 provider event ID + raw SHA-256 hash로 exact replay를 one row/delivery count로 합치고 collision을 거부한다. provider unknown fields는 허용하며 entitlement와 무관한 event는 200 ignored로 future-safe 처리한다. |
| WP06-04 / FR-SUB-009 | leased worker는 webhook trigger와 due periodic customer를 bounded batch로 claim하고 RevenueCat subscriber API를 다시 조회한다. provider/RPC transient failure는 bounded retry, permanent/identity/assignment/schema failure는 dead letter다. |
| WP06-04 / D-024 / D-025 | subscriber identity는 exact UUID custom App User ID여야 한다. snapshot environment, entitlement/product/subscription/store transaction을 strict 검증하고 active household assignment가 없으면 entitlement를 만들지 않는다. |
| WP06-04 / FR-SUB-005 / FR-SUB-006 | valid provider snapshot은 WP06-01 `apply_verified_billing_event`에 `reconciliation` event로 전달한다. active/trial/grace/billing issue/cancel-valid/expired/refunded 상태와 will-renew를 server projection으로 변환하되 client/provider snapshot 자체가 grant authority가 아니다. |
| WP06-04 / NFR-REL-01 | job claim은 `FOR UPDATE SKIP LOCKED`, lease token/expiry와 max attempts를 사용한다. completion replay는 같은 lease에 idempotent하고 expired lease/attempt exhaustion은 terminal dead letter가 된다. |
| WP06-04 / NFR-OBS-01 / NFR-PRIV-01 | immutable transition audit와 aggregate queue health가 queued/leased/retry/dead-letter/oldest due를 제공한다. audit/health에는 raw body, receipt, transaction/customer reference, subscriber attributes 또는 provider response body가 없다. |

## HTTP and Cryptographic Contract

- Edge path: `POST /functions/v1/revenuecat-webhook`; Supabase gateway JWT verification은 끄고 function 내부에서 dedicated Authorization + HMAC을 검증한다.
- Authorization은 dashboard에 설정한 full header value와 exact match한다. user JWT, public SDK key, service-role key를 webhook credential로 재사용하지 않는다.
- HMAC header format은 `t=<unix_seconds>,v1=<64 lowercase hex>`이고 signing secret은 server-only다. signature는 raw bytes를 읽은 뒤 JSON parse 전에 WebCrypto HMAC verify로 검사한다.
- body는 최대 256 KiB, UTF-8 JSON root `api_version` + `event`다. provider의 추가 fields는 허용하지만 common `id`, `type`, `event_timestamp_ms`와 routing에 필요한 identity/environment는 strict type/length/range 검증한다.
- successfully queued, exact duplicate, ignored 또는 manual-review receipt는 모두 빠른 200 aggregate response다. invalid authorization/signature는 401, invalid shape는 400, oversized는 413, durable enqueue unavailable은 503, event-ID/body collision은 409다.
- response에는 provider event/customer/transaction/product ID가 없다. request ID와 contract version, aggregate status만 포함한다.

## Inbox, Lease and Retry Contract

- `app_private.billing_reconciliation_jobs`는 raw request hash, bounded event metadata, UUID auth identity, environment, source와 state만 보존한다. raw webhook JSON과 RevenueCat API response는 저장하지 않는다.
- 상태는 `queued | leased | retry_wait | succeeded | ignored | dead_letter`이고 direct table access는 `service_role` 포함 모두 revoke한다. service-only RPC만 enqueue/claim/complete/schedule/health를 수행한다.
- webhook `TRANSFER` 또는 identity/environment가 없어 자동 처리할 수 없는 billing event는 `MANUAL_REVIEW_REQUIRED`; known analytics/paywall/experiment event는 `ignored`다. unknown future event가 exact UUID+environment를 가지면 authoritative refresh를 queue한다.
- claim batch 1..100, lease 5..300초, attempts 최대 5다. 첫 4회 실패의 retry schedule은 1m, 5m, 30m, 2h이며 5번째 실패는 terminal dead letter로 DB가 결정한다.
- periodic scheduler는 stale active billing customer/assignment만 bounded enqueue하며 같은 customer의 due periodic job을 중복 생성하지 않는다. runtime ingestion이 disabled면 worker claim은 0이다.
- dead-letter count와 oldest due/expired lease는 aggregate health에서 감시 가능하다. 실제 alert delivery/hosted cron은 deployment Gate다.

## Provider Snapshot Mapping

- provider request는 fixed `https://api.revenuecat.com/v1/subscribers/{url_encoded_uuid}` GET + server-only Bearer key이며 redirect를 따르지 않고 timeout을 둔다.
- configured entitlement identifier만 읽고 `subscriber.original_app_user_id`가 requested UUID와 exact match해야 한다. aliases, subscriber attributes와 management URL은 저장/반환하지 않는다.
- entitlement의 `product_identifier`와 matching subscription row를 요구한다. `store_transaction_id`, purchase/expiry/grace/refund/billing-issue/unsubscribe timestamps, sandbox flag와 store를 strict parse한다.
- `PLAY_STORE`/`APP_STORE`만 `play_store`/`app_store` source로 허용한다. claimed environment와 `is_sandbox`가 다르면 permanent mismatch다.
- active entitlement + trial은 `trialing/plus`, active normal은 `active/plus`, grace expiry가 유효하면 `grace/plus`, billing issue지만 provider entitlement가 유효하면 `billing_issue/plus`, unsubscribe는 valid-until + `will_renew=false`, expired/refunded는 `expired|revoked/free`다.
- provider request time을 normalized `provider_occurred_at`으로 사용해 webhook delivery order보다 최신 authoritative snapshot을 monotonic apply한다.

## Database, API and Config Impact

- migration: `supabase/migrations/20260808070000_billing_webhook_reconciliation.sql`
- tests: billing reconciliation pgTAP + claim concurrency, webhook and worker Node contract suites
- Edge/shared: `revenuecat-webhook`, `billing-reconciliation-worker`, provider-neutral contract/runtime modules
- server-only env: `KINFLOW_REVENUECAT_WEBHOOK_AUTHORIZATION`, `KINFLOW_REVENUECAT_WEBHOOK_SIGNING_SECRET`, `KINFLOW_REVENUECAT_SECRET_API_KEY`, `KINFLOW_REVENUECAT_ENTITLEMENT_ID`, `KINFLOW_BILLING_RECONCILIATION_WORKER_SECRET`
- public client config, Flutter runtime dependency, Android permission와 user-facing ARB: 변화 없음
- OpenAPI/DB/domain-event/billing test matrix와 Phase 06 문서를 실제 구현에 맞춘다.

## Test Plan

- exact Authorization + valid raw-body signature success; tampered whitespace/body, wrong signature, missing/duplicate/malformed parts와 stale/future timestamp denial
- POST/content-type/no-query/body-size/UTF-8/JSON/common-field validation과 extra provider field tolerance
- exact event replay one row, delivery count, hash collision, ignored/manual-review/future event routing, disabled/environment behavior
- service-only grants, forced-private table, immutable provider metadata/audit and no receipt/customer/transaction field persistence
- claim `SKIP LOCKED`, lease ownership/expiry, attempts, retry schedule, completion replay, dead-letter and aggregate health
- periodic stale-customer scheduling idempotency and no assignment inference
- fixed RevenueCat URL/header/timeout/no redirect; provider 2xx schema mapping, 401/403 permanent, 429/5xx/network retryable, invalid body permanent
- active/trial/grace/billing issue/cancel-valid/expired/refund mapping, identity/environment/product/subscription mismatch and missing assignment fail closed
- worker aggregate-only response, exact scheduler secret, empty POST, RPC/provider error redaction
- focused pgTAP/Node, full database/JavaScript regression, database lint, config/secret/workflow/whitespace gates

## Rollback

- 두 Edge functions, shared modules/tests/config entries와 WP06-04 migration/docs를 함께 revert한다.
- production emergency stop은 RevenueCat dashboard webhook URL을 disable하고 `billing_runtime_config.ingestion_enabled=false`로 worker claim을 닫는다. 기존 WP06-01 entitlement projection과 WP06-03 client pending/refresh는 유지된다.
- 새 inbox/audit tables에는 raw provider payload가 없으며 아직 provider account를 사용하지 않는다. rollback 전에 queued/dead-letter aggregate를 기록한 뒤 tables/functions를 drop할 수 있다.
- migration은 additive이고 기존 billing customer/transaction/assignment/entitlement rows를 rewrite하지 않는다.

## Completion Boundary

- signed ingress → durable idempotent inbox → leased authoritative subscriber refresh → existing normalized apply → retry/dead-letter/health 경로가 synthetic provider fixtures와 local DB에서 실행되고 전체 local gates가 통과하면 `WP06-04 LOCAL IMPLEMENTED`다.
- active billing assignment가 있는 fixture에서는 entitlement materialization까지 증명한다. 첫 purchase household 선택, transfer/requeue/remediation은 WP06-05 전까지 fail closed다.
- live RevenueCat dashboard event, secret rotation, subscriber API, Google Play sandbox/internal track, hosted cron/alert와 real device는 마지막 Billing Gate까지 `NOT RUN`이다.

## Completion Evidence

- `docs/evidence/phase-06/WP06_04_EVIDENCE.md`
- local result: signed ingress, exact replay/collision, metadata-only private inbox, leased subscriber refresh, strict lifecycle mapping, normalized entitlement apply, periodic repair, retry/dead-letter/health와 `SKIP LOCKED` competition PASS
- automated totals: Node focused 18/18, JavaScript 115/115, WP06-04 pgTAP 47/47, full DB 37 files/2,050 tests, Flutter 599 pass + opt-in 1 skip, analyzer/lint/format/config/secret/codegen/YAML/workflow/matrix/whitespace gates PASS

## Official References

- RevenueCat webhooks, authorization, HMAC, retries and idempotency: <https://www.revenuecat.com/docs/integrations/webhooks>
- RevenueCat webhook event types and fields: <https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields>
- RevenueCat common webhook flows and out-of-order warning: <https://www.revenuecat.com/docs/integrations/webhooks/event-flows>
- RevenueCat API v1 customer endpoint/authentication: <https://www.revenuecat.com/docs/api-v1>
- RevenueCat API key security: <https://www.revenuecat.com/docs/projects/authentication>
