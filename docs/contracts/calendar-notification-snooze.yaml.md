# WP05-12 Calendar Notification Snooze Contract

- 상태: `LOCAL IMPLEMENTED / HOSTED·REAL-ACCOUNT·DEVICE DEFERRED`
- 요구사항: `FR-NOTIF-011`
- 결정: `D-067`
- API: `API-054`
- 구현: `supabase/migrations/20260810170000_calendar_notification_snooze.sql`

```yaml
version: "2026-08-10-wp05-12"
feature: calendar_notification_snooze
scope:
  client: Android Flutter notification center
  server: authenticated PostgreSQL RPC plus existing notification workers
  eligibleItem:
    category: calendar_event
    subjectType: calendar_occurrence
    state: active current inbox item owned by the caller
  deferred:
    - actual Firebase delivery and provider receipt
    - hosted scheduler and production alert wiring
    - real account, two-device race, and physical-device timing
    - device timezone travel and DST transition evidence
    - iOS/APNs and Web Push
policy:
  fixedMinutes: [5, 10, 30]
  maximumConsecutiveCount: 3
  latestAllowedInstant: occurrence base start plus 1 hour
  unavailableWhen:
    - item is read-cancelled, superseded, missing, or not Calendar
    - occurrence or series is inactive
    - caller is no longer an active participant
    - expected item version is stale
    - consecutive count reached three
    - requested delay would exceed the latest allowed instant
  scheduleAuthority:
    source: server statement timestamp plus selected fixed minutes
    preferenceLeadChangeAfterSnooze: does not move explicit snooze schedule
    quietHours: existing resolver applies after the explicit snooze instant
compatibility:
  inboxV1:
    rpc: list_notification_inbox_items
    rule: name, signature, and exact result remain unchanged
  inboxV2:
    rpc: list_notification_inbox_items_v2
    inputs:
      - p_household_id: uuid
      - p_limit: integer 1..100
      - p_before_created_at: nullable timestamptz
      - p_before_id: nullable uuid
    exactResultKeys:
      - inbox_item_id
      - item_version
      - source_event_id
      - household_id
      - category
      - subject_type
      - subject_id
      - scheduled_at
      - created_at
      - read_at
      - payload
      - snooze_count
      - snooze_max_minutes
      - has_more
      - next_before_created_at
      - next_before_id
    metadataRule:
      snooze_count: integer 0..3
      snooze_max_minutes: one of 0, 5, 10, 30
command:
  rpc: snooze_calendar_notification
  inputs:
    p_household_id: uuid
    p_inbox_item_id: uuid
    p_snooze_minutes: integer in 5, 10, 30
    p_command_id: caller-generated uuid
    p_expected_item_version: positive integer
  exactResultKeys:
    - command_id
    - source_event_id
    - inbox_item_id
    - item_version
    - snoozed_until
    - snooze_minutes
    - snooze_count
    - unread_count
    - recorded_at
  concurrency:
    serialization: transaction advisory lock by command ID plus inbox row lock
    optimisticVersion: exact current inbox item version
    replay: same actor, household, item, minutes, and command ID returns the exact stored receipt
    collision: a reused command ID with a different command returns KNP06
  atomicEffects:
    - mark the source inbox item read and cancelled with reason snoozed
    - return the authoritative unread count
    - cancel only pending, retry-wait, or leased source push delivery
    - preserve terminal evaluation and provider history
    - emit one new content-free source event
sourceEvent:
  eventType: calendar.occurrence_reminder_snoozed
  aggregateType: calendar_occurrence
  audience: exact immutable participant member
  correlationId: command ID
  causationId: command ID
  exactPayloadKeys:
    - recipientMemberId
    - originalInboxItemId
    - localStartDate
    - occurrenceScheduledAt
    - scheduledAt
    - snoozeMinutes
    - snoozeCount
    - timezone
    - status
  contentFree: true
  forbidden:
    - event title or description
    - household or member display name
    - email, push token, provider response, or raw error
delivery:
  path:
    - existing latest-state source resolution
    - durable notification inbox materialization when due
    - existing quiet-hours policy
    - active Android endpoint resolution
    - reliable push delivery queue
  earlyClaimRule: a snoozed source cannot materialize or be claimed before scheduledAt
  dedupe: unique source identity includes non-null causation ID
client:
  parser:
    inbox: exact 16-key v2 map with real integers only
    receipt: exact 9-key single-row map with UUID and timestamp validation
    malformedResponse: fail closed as invalid payload
  retry:
    retainSameCommandIdFor: temporary unavailable, invalid payload, unknown failure
    discardCommandIdFor: success and terminal domain failure
  ui:
    entry: eligible Calendar notification card only
    chooser: scrollable fixed 5, 10, and 30 minute bottom sheet filtered by server maximum
    success: remove original item immediately and apply authoritative unread count
    localization: [EN, KO, EN-XA]
    accessibility: minimum touch target and 200 percent text-scale reachability
security:
  authentication: required
  authorization: active household membership plus exact recipient ownership and current participant state
  tableWrites: direct authenticated writes forbidden
  ledger: private immutable metadata-only command table
  helperExecution: revoked from public, anon, authenticated, and service_role
  loggingAnalytics: no new content, recipient identity, or provider field
rollback:
  client: hide snooze action and return inbox reads to v1
  server: stop exposing new action while retaining immutable receipts and source history
  database: forward-only removal only after every released v2 client is retired
```
