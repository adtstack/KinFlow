# 원본 파일 문서화: `contracts/billing-reconciliation.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/billing-reconciliation.yaml`
- 원본 형식: `yaml`
- 범위: WP06-04 RevenueCat signed ingress, metadata-only inbox, leased authoritative refresh와 retry/dead-letter

```yaml
version: "2026-08-08-wp06-04"
authority:
  providerSignal: trigger only
  providerSnapshot: RevenueCat API v1 subscriber response
  entitlementCommand: public.apply_verified_billing_event
  finalProjection: public.household_entitlements
  assignmentRule: never infer active household; missing active assignment is ASSIGNMENT_REQUIRED
webhook:
  path: /functions/v1/revenuecat-webhook
  method: POST
  query: forbidden
  contentType: application/json; optional charset=utf-8
  maximumBodyBytes: 262144
  authentication:
    exactAuthorization: required
    signatureHeader: X-RevenueCat-Webhook-Signature
    signatureFormat: "t=<unix_seconds>,v1=<64 lowercase hex>"
    signingInput: "timestamp + '.' + exact raw body bytes"
    algorithm: HMAC-SHA256
    toleranceSeconds: 300
    verificationOrder: raw body bound -> Authorization and HMAC -> UTF-8 JSON parse
  requiredCommonFields:
    root: [api_version, event]
    event: [id, type, event_timestamp_ms]
  futureFields: accepted
  routing:
    reconcile: exact UUID app_user_id and SANDBOX or PRODUCTION environment
    ignored:
      - TEST
      - EXPERIMENT_ENROLLMENT
      - INVOICE_ISSUANCE
      - VIRTUAL_CURRENCY_TRANSACTION
      - PRICE_INCREASE_CONSENT_APPROVED
      - PRICE_INCREASE_CONSENT_REQUIRED
      - PAYWALL_*
    manualReview: [PURCHASE_REDEEMED, SUBSCRIBER_ALIAS, TRANSFER, missing identity, missing environment]
  responses:
    accepted: 200
    validation: 400
    authentication: 401
    method: 405
    collision: 409
    oversized: 413
    unavailable: 503
    privacy: aggregate disposition, duplicate flag, request ID and contract version only
inbox:
  table: app_private.billing_reconciliation_jobs
  rawProviderPayloadStored: false
  providerSnapshotStored: false
  exactReplayKey: [provider, provider_event_id]
  exactReplayProof: SHA-256 of raw request bytes
  concurrentReplayRule: transaction advisory lock on provider event ID
  collisionRule: same provider event ID and different raw hash is KFB40
  states: [queued, leased, retry_wait, succeeded, ignored, dead_letter]
  directTableAccess: revoked from public, anon, authenticated and service_role
worker:
  path: /functions/v1/billing-reconciliation-worker
  method: POST
  body: forbidden
  query: forbidden
  authentication: exact dedicated Bearer secret
  batchRange: [1, 100]
  defaultBatch: 50
  leaseSecondsRange: [5, 300]
  defaultLeaseSeconds: 120
  maximumAttempts: 5
  retryScheduleBeforeFinalAttempt: [1m, 5m, 30m, 2h]
  fifthFailure: terminal ATTEMPTS_EXHAUSTED dead letter
  claimOrdering: [next_attempt_at, received_at, id]
  concurrency: FOR UPDATE SKIP LOCKED
  completionReplay: idempotent for the same completed lease token
  response: aggregate scheduled, claimed, succeeded, retryScheduled and deadLetter counts only
providerFetch:
  method: GET
  endpoint: "https://api.revenuecat.com/v1/subscribers/{url_encoded_uuid}"
  redirect: forbidden
  timeoutMilliseconds: 8000
  maximumResponseBytes: 1048576
  authorization: server-only RevenueCat secret API key
  identityRule: subscriber.original_app_user_id exactly equals claimed auth UUID
  environmentRule: subscription.is_sandbox exactly matches claimed environment
  configuredEntitlementOnly: true
  acceptedStores:
    PLAY_STORE: play_store
    APP_STORE: app_store
  retryableFailures: [network, timeout, HTTP_408, HTTP_429, HTTP_5XX, RPC_UNAVAILABLE]
  permanentFailures:
    - provider authentication rejected
    - subscriber not found
    - malformed or oversized response
    - identity or environment mismatch
    - entitlement, product, subscription or store unmapped
mapping:
  trial: trialing/plus
  active: active/plus
  grace: grace/plus
  billingIssueWithAccess: billing_issue/plus
  unsubscribeWithAccess: current status with will_renew=false
  prepaidWithAccess: current status with will_renew=false
  expired: expired/free
  refunded: revoked/free
  orderingClock: provider request_date
periodicRepair:
  candidate: stale RevenueCat customer with active persisted household assignment
  defaultStaleSeconds: 3600
  activeJobDeduplication: [queued, leased, retry_wait]
  disabledRuntimeBehavior: schedules and claims zero jobs
observability:
  immutableTransitionTable: app_private.billing_reconciliation_transitions
  aggregateHealth:
    - queued_count
    - leased_count
    - retry_wait_count
    - dead_letter_count
    - succeeded_24h_count
    - dead_letter_24h_count
    - expired_lease_count
    - oldest_due_at
    - next_retry_at
  forbidden:
    - raw webhook body
    - provider response body
    - receipt
    - transaction or customer reference
    - product identifier
    - subscriber attributes or aliases
deferredLiveGate:
  - RevenueCat project, webhook and API key registration
  - hosted scheduler and alert sink
  - Google Play product, license tester and internal track
  - real account, Store transaction and device
```
