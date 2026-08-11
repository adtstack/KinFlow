# 원본 파일 문서화: `contracts/notification-worker.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/notification-worker.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: 이 계약은 WP05-01 source event → candidate/suppression과 WP05-02 candidate/suppression → durable inbox 단계를 다룬다. WP05-03 endpoint token lifecycle과 WP05-04 Android provider send는 각각 별도 계약으로 로컬 구현됐으며 실제 provider/device 검증은 마지막 Gate다.

```yaml
version: "2026-08-08"
source:
  table: app_private.chore_notification_outbox
  eventTypes:
    - chore.occurrence_due_changed
    - chore.occurrence_assigned
  envelopeVersion: 1
lifecycle:
  statuses: [pending, leased, retry_wait, succeeded, dead_letter]
  maxAttempts: 5
  batchSize: {minimum: 1, maximum: 100}
  leaseSeconds: {minimum: 5, maximum: 300}
  heartbeatCapSecondsFromAsOf: 300
  claimOrder: [readyAt, occurredAt, eventId]
  concurrency: FOR UPDATE SKIP LOCKED
  retry:
    baseSeconds: 30
    exponential: true
    baseMaximumSeconds: 3600
    deterministicJitterSeconds: [0, 15]
  expiredFinalLeaseErrorCode: LEASE_EXPIRED
resolution:
  uniqueBy: sourceEventId
  outcomes: [candidate, suppressed]
  candidate:
    exactRoutingFields:
      - sourceEventId
      - notificationCategory
      - subjectType
      - subjectId
      - recipientMemberId
      - recipientUserId
      - scheduledAt
      - timezone
      - resolvedAt
  suppressed:
    recipientAndScheduleMustBeNull: true
    reasons:
      - stale_event
      - inactive_series
      - occurrence_not_scheduled
      - inactive_recipient
      - schedule_unresolved
inboxMaterialization:
  source: app_private.notification_event_resolutions
  uniqueBy: sourceEventId
  batchSize: {minimum: 1, maximum: 100}
  concurrency: FOR UPDATE SKIP LOCKED
  outcomes: [created, disabled, stale, suppressed]
  reevaluatesLatestState: true
  appliesCurrentPreference: true
  cancelsSupersededActiveItems: true
  providerIndependent: true
  response: aggregate counts only
serviceRoleApis:
  - claim_chore_notification_events
  - heartbeat_chore_notification_event
  - process_chore_notification_event
  - fail_chore_notification_event
  - replay_chore_notification_dead_letter
  - set_chore_notification_worker_paused
  - get_chore_notification_queue_health
  - materialize_chore_notification_inbox
edgeWorker:
  function: notification-outbox-worker
  method: POST
  requestBody: forbidden
  queryParameters: forbidden
  authorization: dedicated server-only Bearer secret
  response: aggregate counts only
  workflow:
    - claim and resolve source events
    - materialize resolved events into the durable inbox
  inboxSummaryFields:
    - inboxClaimedCount
    - inboxCreatedCount
    - inboxDisabledCount
    - inboxStaleCount
    - inboxSuppressedCount
    - inboxCancelledCount
  errorCodes:
    INVALID_REQUEST: {httpStatus: 400, retryable: false}
    METHOD_NOT_ALLOWED: {httpStatus: 405, retryable: false}
    WORKER_AUTH_REQUIRED: {httpStatus: 401, retryable: false}
    WORKER_UNAVAILABLE: {httpStatus: 503, retryable: true}
  hostedSchedule: deferred
rules:
  - Client roles MUST NOT execute worker APIs or read worker-private tables.
  - The service role MUST use mediated security-definer APIs and MUST NOT receive direct private table or helper privileges.
  - Processing MUST re-evaluate the latest occurrence, series, and recipient state.
  - Resolution insert and succeeded transition MUST be atomic and response-loss replay MUST return the original resolution.
  - Failure storage MUST accept only an uppercase stable code and MUST NOT store raw exceptions or provider bodies.
  - A failed event MUST NOT prevent later events from being claimed or processed.
  - Health and Edge responses MUST NOT expose event, household, recipient, content, token, email, or raw error data.
  - Pause MUST block new claims while allowing an already valid lease to finish.
  - Durable candidate creation, inbox creation, and provider delivery MUST remain independently retryable stages.
  - Inbox materialization MUST re-evaluate latest state and current preference before creating a content-free item.
  - Quiet hours MUST affect only future delivery timing and MUST NOT defer inbox persistence.
```
