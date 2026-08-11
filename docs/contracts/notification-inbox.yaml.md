# 원본 파일 문서화: `contracts/notification-inbox.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/notification-inbox.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: WP03-07 producer, WP05-01 latest-state candidate/suppression worker, WP05-02 preference/quiet hours·durable inbox/read state, WP05-03 endpoint/token lifecycle과 WP05-04 Android provider/OS lifecycle은 로컬 구현됐다. 실제 Firebase project·실기기 delivery는 마지막 Gate다.

```yaml
version: "2026-08-09-wp05-08"
itemVersion: 1
categories:
  chore_due:
    sourceEvent: chore.occurrence_due_changed
    subjectType: chore_occurrence
  chore_assignment:
    sourceEvent: chore.occurrence_assigned
    subjectType: chore_occurrence
  calendar_event:
    sourceEvent: calendar.occurrence_start_changed
    subjectType: calendar_occurrence
preferences:
  key: [authUserId, householdId, category]
  channels: [nativePush, webPush, email, inApp]
  optimisticVersion: true
  defaults:
    nativePush: true
    webPush: false
    email: false
    inApp: true
    timezone: household timezone
    version: 0
  quietHours:
    fields: [quietStart, quietEnd, timezone]
    timezone: valid IANA identifier
    partialRange: forbidden
    equalStartAndEnd: forbidden
    precision: minute
    crossesMidnight: supported
    dstGap: advance to first valid minute
    dstOverlap: choose later instant
item:
  inboxItemId: uuid
  itemVersion: positive integer
  sourceEventId: uuid
  recipientUserId: server-resolved uuid
  householdId: uuid
  category: chore_due | chore_assignment | calendar_event
  subjectTypeByCategory:
    chore_due: chore_occurrence
    chore_assignment: chore_occurrence
    calendar_event: calendar_occurrence
  subjectId: occurrence uuid
  scheduledAt: ISO-8601 UTC timestamp
  createdAt: ISO-8601 UTC timestamp
  readAt: ISO-8601 UTC timestamp or null
  cancelledAt: ISO-8601 UTC timestamp or null
  payload:
    exactKeys: [householdId, occurrenceId]
    householdId: uuid
    occurrenceId: uuid
  clientOmittedFields:
    - recipientUserId
    - recipientMemberId
    - sourceAggregateVersion
    - cancelledAt
    - cancellationReason
materialization:
  source: app_private.notification_event_resolutions
  uniqueBy: sourceEventId
  concurrency: FOR UPDATE SKIP LOCKED
  outcomes: [created, disabled, stale, suppressed]
  deliveryNotBefore:
    purpose: future provider delivery timing only
    affectsInboxCreation: false
  cancellationReasons: [superseded, state_inactive]
dedupe:
  unique: [recipientUserId, sourceEventId, category]
pagination:
  order: [createdAt DESC, inboxItemId DESC]
  cursor: [beforeCreatedAt, beforeInboxItemId]
  maximumPageSize: 100
authenticatedApis:
  - get_notification_preferences
  - update_notification_preference
  - list_notification_inbox_items
  - get_notification_unread_count
  - mark_notification_inbox_items_read
  - mark_all_notification_inbox_read
serviceRoleApis:
  - materialize_chore_notification_inbox
routing:
  choreCategories: [chore_due, chore_assignment]
  choreDestination: /chores/occurrence/:occurrenceId
  calendarCategories: [calendar_event]
  calendarDestination: /calendar/event/:occurrenceId
  invalidOrUnavailableDestination: /notifications
  routeIdentifier: strict subject UUID only
rules:
  - A WP05-01 candidate is routing input to this inbox contract, not an inbox item or successful delivery.
  - The server MUST resolve the recipient from the latest authorized occurrence state.
  - A stale, completed, skipped, cancelled, deleted-series, or inactive-recipient event MUST NOT create a new inbox item.
  - An all-day due event without an approved reminder instant remains unresolved and MUST NOT invent a device-local schedule.
  - Inbox creation MUST NOT depend on push provider success.
  - Quiet hours MUST NOT hide or delay durable inbox creation; they only calculate deliveryNotBefore for later provider work.
  - Read commands MUST bind auth.uid and active household membership and MUST return the server-authoritative unread count.
  - Preference writes MUST use optimistic versioning and identical response-loss replay MUST return the existing value.
  - Payload MUST NOT contain title, description, display name, email, auth subject, token, receipt, or raw error.
  - Opening an item MUST route by the strict category/subject pair, then revalidate the session, active household, and occurrence authorization before an authoritative refetch.
  - Consumers MUST deduplicate by sourceEventId and tolerate late or out-of-order events.
```
