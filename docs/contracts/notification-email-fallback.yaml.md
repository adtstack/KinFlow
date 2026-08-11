# WP05-14 Generic Notification Email Fallback Contract

- 상태: `LOCAL IMPLEMENTATION / HOSTED·REAL-ACCOUNT·MAILBOX DEFERRED`
- 요구사항: `FR-NOTIF-008`, `FR-NOTIF-003`–`006`
- 결정: `D-069`
- API: `API-056`
- 구현: `supabase/migrations/20260810190000_notification_email_fallback.sql`

```yaml
version: "2026-08-10-wp05-14"
feature: notification_email_fallback
scope:
  categories: [chore_due, chore_assignment, calendar_event]
  defaultEnabled: false
  recipient: current active member mapped to one confirmed Auth email
  channelsIndependent: [in_app, native_push, email]
  deferred:
    - marketing, digest, arbitrary content, attachments, and unsubscribe campaigns
    - Web Push and email deep links containing user or resource identifiers
    - hosted scheduler and SendGrid sender authentication, reputation, quota, and activity feed
    - real mailbox, account, two-device, spam-folder, and physical-device validation
preference:
  storage: existing public.notification_preferences.email
  compatibility: existing exact v1, v2, and v3 RPC shapes remain unchanged
  updatePreserves:
    - every other notification channel
    - quiet hours and timezone
    - Calendar primary and additional reminder leads
source:
  storage: existing app_private.chore_notification_outbox
  payloadChange: none
  evaluation:
    onePerSource: true
    latestStateChecks:
      - current occurrence version and scheduled status
      - current active recipient membership
      - current category email preference
      - current confirmed Auth email existence
    schedule:
      base: existing notification_event_resolutions.scheduled_at
      quietHours: existing recipient-local DST-aware resolver
      usefulnessWindow: 1 hour after source schedule
    outcomes:
      - materialized
      - disabled
      - stale
      - no_confirmed_email
      - expired
delivery:
  table: app_private.notification_email_deliveries
  unique: source_event_id
  persistedIdentity:
    - source_event_id
    - recipient user/member IDs
    - household ID
    - category and subject type/ID
  forbiddenPersistence:
    - recipient or sender email
    - name, title, description, schedule display copy, or household content
    - provider request/response body or raw error
  lifecycle: [pending, leased, retry_wait, succeeded, failed, cancelled]
  maxAttempts: 5
  retrySchedule: [1 minute, 5 minutes, 30 minutes, 2 hours]
  atMostOnce:
    marker: durable submission_started_at plus exact lease token before network I/O
    ambiguous: terminal EMAIL_SUBMISSION_AMBIGUOUS without automatic replay
    explicitRetryOnly: HTTP 429, 500, 502, 503, or 504
  receipt: optional provider message ID is stored only as SHA-256
serviceRpc:
  claim:
    name: claim_notification_email_deliveries
    exactOutputKeys:
      - delivery_id
      - source_event_id
      - inbox_item_id
      - household_id
      - category
      - subject_type
      - subject_id
      - recipient_email
      - locale
      - attempt
      - max_attempts
      - lease_token
      - lease_expires_at
      - scheduled_at
      - expires_at
    rawEmailLifetime: service response through one provider call only
  submissionMarker: mark_notification_email_submission_started
  completion: complete_notification_email_delivery
  pause: set_notification_email_worker_paused
  grants:
    execute: service_role only
    directPrivateTables: none
edgeWorker:
  function: notification-email-worker
  transport:
    method: POST
    query: forbidden
    body: empty only
    authentication: exact dedicated Bearer secret
    response: aggregate counts and contract version only
  configuration:
    required:
      - SUPABASE_URL
      - SUPABASE_SERVICE_ROLE_KEY
      - NOTIFICATION_EMAIL_WORKER_SECRET
      - SENDGRID_API_KEY
      - KINFLOW_NOTIFICATION_EMAIL_FROM
    neverReturnedOrLogged: true
provider:
  name: sendgrid
  api:
    method: POST
    url: https://api.sendgrid.com/v3/mail/send
    authorization: Bearer SENDGRID_API_KEY
    dependency: raw fetch only, no provider SDK
  payload:
    recipientCount: 1
    recipient: ephemeral confirmed Auth email
    from: configured verified sender
    subjectAndText: fixed locale template only
    customArgs: forbidden
    attachments: forbidden
    html: forbidden
  templates:
    en:
      subject: KinFlow reminder
      text: You have a family reminder waiting in KinFlow. Open KinFlow to view the details.
    ko:
      subject: KinFlow 알림
      text: KinFlow에 가족 알림이 도착했습니다. 자세한 내용은 KinFlow를 열어 확인하세요.
  statusMapping:
    accepted: [202]
    retryable: [429, 500, 502, 503, 504]
    permanent: every other completed HTTP response
    ambiguous: network or response-processing failure after submission marker
client:
  quickToggle: email
  editorToggle: email
  explanation:
    - uses the verified account email
    - message content is generic
    - durable inbox remains available if email cannot be delivered
  localization: [EN, KO, EN-XA]
  accessibility: 48dp controls, scrollable editor, 200 percent text scale
security:
  emailAtRestInQueue: forbidden
  directClientOrServiceTableAccess: forbidden
  sourceAndProviderContent: content-free
  logging: aggregate stable codes only
  analytics: no new event or property
rollback:
  immediate: pause worker before provider I/O
  client: hide the switch or write false while preserving other preferences
  history: retain succeeded, failed, and ambiguous terminal audit rows
  providerChange: replace the Edge adapter and secrets without changing preference or source contracts
```
