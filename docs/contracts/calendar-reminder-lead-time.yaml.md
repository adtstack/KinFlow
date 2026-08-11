# 원본 파일 문서화: `contracts/calendar-reminder-lead-time.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-reminder-lead-time.yaml`
- 원본 형식: `yaml`
- 범위: WP05-11 per-user Calendar reminder lead preference and pending-only schedule reconciliation

```yaml
version: "2026-08-10-wp05-11"
requirements: [FR-NOTIF-010, FR-NOTIF-001, FR-NOTIF-003, FR-NOTIF-004, FR-NOTIF-005, FR-NOTIF-006, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-019, D-020, D-022, D-023, D-064]
scope:
  category: calendar_event
  audience: exact active participant member mapped to the authenticated user
  optionsMinutes: [0, 5, 10, 15, 30, 60]
  defaultMinutes: 0
  onePreferencePer: [authUserId, householdId, category]
  compatibility: source payload and all v1 preference RPC signatures and exact result shapes remain unchanged
schedule:
  timedBase: occurrence.starts_at
  allDayBase:
    localTime: "09:00"
    timezone: current authoritative household IANA timezone
    semanticDate: occurrence.local_start_date remains date-only
  reminderInstant: baseInstant minus recipient reminderLeadMinutes
  quietHoursOrder: apply the recipient quiet-hours rule after lead subtraction
  usefulnessWindow: existing one hour begins at reminderInstant
  multipleReminders: extended separately by WP05-13 without changing this v1/v2 primary-lead contract
preferenceStorage:
  table: public.notification_preferences
  column: reminder_lead_minutes
  constraints:
    - integer and non-null with zero default
    - one of 0, 5, 10, 15, 30, 60
    - non-calendar categories must remain zero
  rls: existing self-scoped forced RLS remains authoritative
api:
  v1Read:
    function: get_notification_preferences
    exactResultKeys: [household_id, category, native_push, web_push, email, in_app, quiet_start, quiet_end, timezone, updated_at, version, is_default]
    behavior: existing row lead is omitted; missing rows still project zero-minute behavior
  v1Write:
    function: update_notification_preference
    behavior: existing lead is preserved and a new row receives the database zero default
  v2Read:
    function: get_notification_preferences_v2
    exactResultKeys: [household_id, category, native_push, web_push, email, in_app, quiet_start, quiet_end, timezone, reminder_lead_minutes, updated_at, version, is_default]
  v2Write:
    function: update_notification_preference_v2
    addsInput: p_reminder_lead_minutes
    concurrency: existing optimistic expected-version and identical response-loss no-op semantics
    authorization: authenticated active household membership only
sourceAndResolution:
  sourcePayload:
    scheduledAt: base Calendar start or all-day 09:00 instant, never the personal reminder instant
    additiveKeys: forbidden
    forbiddenContent: [title, description, householdName, memberDisplayName, email, accountIdentifier]
  latestState:
    sourceFreshness: compares payload scheduledAt with the base schedule
    deliveryDueAt: resolves the exact recipient lead dynamically before evaluation
    recipientIsolation: one participant preference cannot change another participant resolution
reconciliation:
  onV2Change:
    eligible:
      - future Calendar candidate resolution for the authenticated user
      - no notification_inbox_evaluations row
      - no non-pending notification_push_evaluations row
    mutation:
      - set resolution scheduled_at to the new personal reminder instant
      - set an existing pending push next_evaluation_at to that same instant atomically
    frozen:
      - any inbox evaluation outcome
      - materialized, disabled, stale, or no-endpoint push evaluation
    effect: already evaluated history is never retracted, duplicated, or rescheduled
client:
  rpcVersion: v2 only
  dto: exact 13-key strict map with a real integer lead
  domain:
    calendar: fixed option set only
    choreCategories: zero only
  ui:
    surface: Calendar notification preference editor only
    copy: changes apply only to reminders not yet delivered
    localization: [EN, KO, EN-XA]
security:
  directPublicTableWrites: forbidden
  helperExecution: private from authenticated, anon, and service_role
  logsAnalyticsPayloads: lead value is not added to analytics or notification payloads
rollback:
  client: return to v1 RPCs and hide the selector
  operational: set Calendar lead values to zero through v2 before contract retirement
  database: forward-only removal after every released v2 client is retired
deferred:
  - WP05-13 multiple reminders and WP05-12 bounded Snooze are separate additive contracts
  - category-specific visible push content
  - hosted scheduler and production alert wiring
  - actual Firebase account, real-account, two-device and physical-device evidence
  - iOS/APNs and Web Push
```
