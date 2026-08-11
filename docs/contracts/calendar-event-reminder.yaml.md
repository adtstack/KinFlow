# 원본 파일 문서화: `contracts/calendar-event-reminder.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-event-reminder.yaml`
- 원본 형식: `yaml`
- 범위: WP05-07 Calendar occurrence start reminder source events, durable inbox, and Android push routing

```yaml
version: "2026-08-09-wp05-07"
requirements: [FR-NOTIF-001, FR-NOTIF-003, FR-NOTIF-004, FR-NOTIF-005, FR-NOTIF-006, FR-CAL-001, FR-CAL-002, FR-CAL-004, FR-CAL-005, FR-CAL-006, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-019, D-020, D-022, D-023]
scope:
  source: public.event_occurrences
  audience: exact active participant snapshot for the occurrence revision
  category: calendar_event
  subjectType: calendar_occurrence
  channels: [durable_in_app, android_native_push]
  compatibility: existing chore worker, materializer, push RPC names and payloads remain valid
schedule:
  timed:
    instant: occurrence.starts_at
    timezone: occurrence.timezone
  allDay:
    semanticDate: occurrence.local_start_date remains date-only
    reminderLocalTime: "09:00"
    reminderTimezone: current authoritative household timezone
    dstResolution: PostgreSQL IANA timezone conversion for the notification instant only
  userLeadTime: zero-minute default; extended by calendar-reminder-lead-time.yaml in WP05-11
  usefulnessWindow: existing one hour after provider eligibility
sourceEvent:
  table: app_private.chore_notification_outbox
  legacyTableNameReason: backward-compatible worker RPC and deployed migration surface
  eventType: calendar.occurrence_start_changed
  aggregateType: calendar_occurrence
  uniqueBy: [householdId, eventType, occurrenceId, occurrenceVersion, audienceMemberId]
  payloadExactKeys: [recipientMemberId, localStartDate, scheduledAt, timezone, status]
  forbiddenContent: [title, description, householdName, memberDisplayName, email, accountIdentifier]
  capture:
    occurrenceInsert: only within the bounded 32-day notification horizon
    occurrenceUpdate: always when schedule, revision, or status changes
    oneTimeParticipantChange: exact added and removed member audiences
    horizonSweep: service-role worker enqueue through at most 32 days
  actor: authenticated active member when available; otherwise null for server materialization
participantSnapshot:
  recurringOrException: public.event_revision_participants for occurrence.revision_id
  oneTimeFallback: public.event_participants only when that revision has no revision participant rows
  removedAudience: receives a newer source event so any prior inbox or pending push becomes stale or cancelled
latestState:
  checks:
    - newest source aggregate version for the exact occurrence and audience
    - current occurrence version and exact reminder schedule fields
    - scheduled occurrence status
    - active non-deleted and non-ended series
    - audience remains in the current occurrence participant snapshot
    - audience is an active household member with an auth user
  suppressionReasons: [stale_event, inactive_series, occurrence_not_scheduled, inactive_recipient, schedule_unresolved]
resolution:
  oneSourceEventPerAudience: true
  storesAudienceForSuppressedEvents: true
  scheduledAt: timed start or all-day 09:00 household-local instant
inbox:
  futureCalendarMaterialization: only when scheduledAt is at or before materializer asOf
  cancellationIsolation: exact recipient member plus category and subject
  payloadExactKeys: [householdId, occurrenceId]
  titleOrDescription: forbidden
push:
  evaluationStartsAt: resolution.scheduledAt
  exactRequiredDataKeys: [contractVersion, deliveryId, sourceEventId, householdId, category, subjectType, subjectId]
  optionalDataKeys: [inboxItemId]
  content: generic localized application resources only
  tapAuthorization: current recipient, household membership, subject and latest source state
preferences:
  categories: [chore_due, chore_assignment, calendar_event]
  calendarDefault: {nativePush: true, webPush: false, email: false, inApp: true}
  quietHours: existing recipient IANA timezone rule
client:
  strictCategory: calendar_event
  strictSubjectPair: [calendar_event, calendar_occurrence]
  inboxDestination: /calendar/event/:occurrenceId
  localization: [EN, KO, EN-XA]
security:
  directPublicTableWrites: forbidden
  workerMutation: service_role only
  rawErrorText: forbidden
  familyContentInOutboxInboxPushLogsEvidence: forbidden
rollback:
  enqueue: stop calendar horizon enqueue while preserving chore processing
  category: disable calendar_event preferences or pause existing notification workers
  database: forward migration only after deployment
deferred:
  - multiple reminders and bounded Snooze are specified by additive WP05-13 and WP05-12 contracts
  - category-specific visible push copy
  - hosted scheduler and production queue alert wiring
  - actual Firebase account, real-account, multi-device and physical-device evidence
  - iOS/APNs pending D-021 follow-up
```
