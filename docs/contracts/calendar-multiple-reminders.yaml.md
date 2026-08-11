# WP05-13 Per-user Calendar Multiple Reminders Contract

- 상태: `LOCAL IMPLEMENTED / HOSTED·REAL-ACCOUNT·DEVICE DEFERRED`
- 요구사항: `FR-NOTIF-012`
- 결정: `D-068`
- API: `API-055`
- 구현: `supabase/migrations/20260810180000_calendar_multiple_reminders.sql`

```yaml
version: "2026-08-10-wp05-13"
feature: calendar_multiple_reminders
scope:
  category: calendar_event
  audience: exact active participant member mapped to the preference owner
  fixedLeadMinutes: [0, 5, 10, 15, 30, 60]
  primaryCount: 1
  additionalCount: 0..2
  totalCount: 1..3
  deferred:
    - arbitrary minute input or more than three reminders
    - per-occurrence override and persistent reminder history UI
    - category-specific sensitive visible push content
    - iOS/APNs and Web Push
    - hosted scheduler, actual Firebase, real accounts, two-device race, and physical-device timing
preferenceStorage:
  table: public.notification_preferences
  primaryColumn: reminder_lead_minutes
  additionalColumn: additional_reminder_lead_minutes
  additionalRules:
    - non-null integer array with empty default
    - cardinality from zero through two
    - one-dimensional and one-based
    - values use only the fixed vocabulary
    - values are strictly increasing and contain no null
    - no value equals the primary lead
    - non-Calendar categories remain empty
compatibility:
  v1:
    read: get_notification_preferences returns the unchanged exact 12 keys
    write: update_notification_preference preserves primary and additional leads
  v2:
    read: get_notification_preferences_v2 returns the unchanged exact 13 keys and only the primary lead
    write: update_notification_preference_v2 replaces only the primary and preserves extras except a value promoted to primary
  v3:
    read: get_notification_preferences_v3
    write: update_notification_preference_v3
    exactResultKeys:
      - household_id
      - category
      - native_push
      - web_push
      - email
      - in_app
      - quiet_start
      - quiet_end
      - timezone
      - reminder_lead_minutes
      - additional_reminder_lead_minutes
      - updated_at
      - version
      - is_default
    writeInputs:
      - p_household_id: uuid
      - p_category: fixed category text
      - p_native_push: boolean
      - p_web_push: boolean
      - p_email: boolean
      - p_in_app: boolean
      - p_quiet_start: nullable minute-aligned time
      - p_quiet_end: nullable minute-aligned time
      - p_timezone: valid IANA timezone
      - p_reminder_lead_minutes: fixed integer primary
      - p_additional_reminder_lead_minutes: strict integer array
      - p_expected_version: non-negative bigint
    concurrency:
      optimisticVersion: existing exact row version
      replay: identical payload is a version-preserving no-op even after response loss
      conflict: stale different payload returns KNP06
sourceIdentity:
  table: app_private.chore_notification_outbox
  eventType: calendar.occurrence_start_changed
  aggregateType: calendar_occurrence
  privateLeadColumn:
    null: primary reminder resolved from the current primary preference
    integer: one explicit additional reminder
  uniqueFields:
    - household_id
    - event_type
    - aggregate_id
    - aggregate_version
    - audience_member_id
    - causation_id
    - reminder_lead_minutes
  immutable: true
  payload:
    exactKeys: [recipientMemberId, localStartDate, scheduledAt, timezone, status]
    scheduledAt: base timed start or all-day household-local 09:00, never a personal lead instant
    leadKey: forbidden
    contentFree: true
resolution:
  primary: base schedule minus the recipient current primary lead
  additional: base schedule minus the source explicit lead only while that lead remains selected
  quietHoursOrder: after each independent lead subtraction
  snooze: explicit Snooze schedule remains fixed across preference changes
  latestState:
    - current occurrence version and exact base schedule
    - current participant membership
    - current additional-lead selection for explicit sources
reconciliation:
  occurrenceOrHorizonCapture: emit the primary plus every current additional source inside the existing 32-day boundary
  settingChange:
    add: emit only selected reminder instants that are still in the future
    reschedule: update only candidate resolutions without inbox evaluation or terminal push evaluation
    remove: leave immutable source history and make the source stale in latest-state resolution
    frozen: evaluated inbox and terminal push history is not moved, retracted, or duplicated
delivery:
  eachSelectedLeadUses:
    - existing source worker
    - existing durable inbox materializer
    - existing recipient quiet-hours and DST policy
    - existing active Android endpoint and reliable push worker
    - existing Calendar Snooze action after materialization
  inbox: a later reminder supersedes the prior active badge item for the same occurrence while immutable evaluations remain
client:
  rpcVersion: v3
  parser: exact 14-key rows with real integers and a real integer list only
  domain: one fixed primary plus zero-to-two sorted fixed extras
  ui:
    primary: dropdown
    additional: checkboxes excluding the current primary
    limit: at two selections other unchecked values are disabled
    summary: renders every selected timing
    localization: [EN, KO, EN-XA]
    accessibility: scrollable editor and 200 percent text-scale reachability
security:
  authentication: required
  authorization: active membership in the requested household
  directTableWrites: forbidden
  privateHelperExecution: revoked from public, anon, authenticated, and service_role
  forbiddenPayloadContent:
    - title or description
    - household or member display name
    - email or account identifier
    - endpoint token, provider response, or raw error
rollback:
  client: return to v2 and edit only the primary while server extras stay preserved
  server: stop v3 exposure but retain immutable source and evaluation history
  database: forward-only removal after every released v3 client is retired
```
