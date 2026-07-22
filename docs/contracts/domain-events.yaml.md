# 원본 파일 문서화: `contracts/domain-events.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/domain-events.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
version: "2026-07-21"
delivery: at-least-once
envelope:
  eventId: uuid
  eventType: string
  eventVersion: positive integer
  occurredAt: ISO-8601 UTC timestamp
  householdId: uuid or null
  actorUserId: uuid or null
  actorMemberId: uuid or null
  actingMemberId: uuid or null
  aggregateType: string
  aggregateId: uuid
  aggregateVersion: integer or null
  correlationId: uuid
  causationId: uuid or null
  payload: event-specific object
rules:
  - Consumers MUST deduplicate by eventId.
  - Events are immutable and may arrive late or out of order.
  - Payloads MUST NOT contain secrets, raw invite tokens, push tokens, receipts, or free-form user content unless explicitly approved.
  - Breaking payload changes require a new eventVersion and migration strategy.
events:
  household.created: {version: 1, aggregate: household}
  household.updated: {version: 1, aggregate: household}
  household.deletion_requested: {version: 1, aggregate: household}
  household.deleted: {version: 1, aggregate: household}
  household.owner_transferred: {version: 1, aggregate: household}
  member.joined: {version: 1, aggregate: household_member}
  member.role_changed: {version: 1, aggregate: household_member}
  member.removed: {version: 1, aggregate: household_member}
  managed_child.created: {version: 1, aggregate: household_member}
  managed_child.updated: {version: 1, aggregate: household_member}
  managed_child.deleted: {version: 1, aggregate: household_member}
  invite.created: {version: 1, aggregate: household_invite}
  invite.accepted: {version: 1, aggregate: household_invite}
  invite.revoked: {version: 1, aggregate: household_invite}
  chore.series_created: {version: 1, aggregate: chore_series}
  chore.series_revised: {version: 1, aggregate: chore_series}
  chore.series_deleted: {version: 1, aggregate: chore_series}
  chore.occurrence_completed: {version: 1, aggregate: chore_occurrence}
  chore.occurrence_reopened: {version: 1, aggregate: chore_occurrence}
  chore.occurrence_skipped: {version: 1, aggregate: chore_occurrence}
  calendar.series_created: {version: 1, aggregate: event_series}
  calendar.series_revised: {version: 1, aggregate: event_series}
  calendar.occurrence_overridden: {version: 1, aggregate: event_occurrence}
  calendar.occurrence_cancelled: {version: 1, aggregate: event_occurrence}
  notification.intent_created: {version: 1, aggregate: notification_intent}
  notification.delivery_succeeded: {version: 1, aggregate: notification_delivery}
  notification.delivery_failed: {version: 1, aggregate: notification_delivery}
  billing.purchase_synced: {version: 1, aggregate: billing_customer}
  billing.household_assigned: {version: 1, aggregate: billing_household_assignment}
  billing.household_unassigned: {version: 1, aggregate: billing_household_assignment}
  billing.entitlement_changed: {version: 1, aggregate: household_entitlement}
  privacy.export_requested: {version: 1, aggregate: privacy_request}
  privacy.deletion_requested: {version: 1, aggregate: privacy_request}
  privacy.request_completed: {version: 1, aggregate: privacy_request}
  security.kill_switch_changed: {version: 1, aggregate: kill_switch}
```
