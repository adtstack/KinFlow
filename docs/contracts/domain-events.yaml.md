# 원본 파일 문서화: `contracts/domain-events.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/domain-events.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 범위 주의: `managed_child.*` event는 P1 참조 전용이며 Store MVP producer/consumer에 등록하지 않는다(D-013).

```yaml
version: "2026-08-10-wp05-15"
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
realtimeInvalidations:
  chore.sync:
    source: public.chore_sync_watermarks
    domainEvent: false
    delivery: lossy invalidation hint
    exactPayload: [household_id, generation, changed_at]
    forbiddenPayload:
      - chore title or description
      - assignee, member, or actor identifiers
      - series or occurrence identifiers
      - command or correlation identifiers
    consumerRule: authoritative full first-page refetch on connect, newer generation, reconnect, and resume; retain stale content on transport loss and discard it on authorization failure
  calendar.sync:
    source: public.calendar_sync_watermarks
    domainEvent: false
    delivery: lossy invalidation hint
    exactPayload: [household_id, generation, changed_at]
    forbiddenPayload:
      - event content
      - participant or actor identifiers
      - command or correlation identifiers
    consumerRule: authoritative full refetch on connect, newer generation, reconnect, and resume; discard retained content on authorization failure
notificationWorkerResolution:
  sourceEvents:
    - chore.occurrence_due_changed
    - chore.occurrence_assigned
    - calendar.occurrence_start_changed
    - calendar.occurrence_reminder_snoozed
  durableResult: candidate | suppressed
  idempotencyKey: source eventId
  latestStateInputs: [occurrence, series, recipient]
  suppressionReasons:
    - stale_event
    - inactive_series
    - occurrence_not_scheduled
    - inactive_recipient
    - schedule_unresolved
  deliveryRule: candidate resolution is not an inbox item or provider send
  privacyRule: result contains routing IDs and schedule only; no household content, token, email, or raw error
billingState:
  reconciliation:
    domainEvent: false
    ingressAuthentication: exact Authorization plus raw-body RevenueCat HMAC
    inbox: app_private.billing_reconciliation_jobs
    rawPayloadStored: false
    exactReplayKey: [provider, providerEventId, rawRequestSha256]
    workerConcurrency: leased FOR UPDATE SKIP LOCKED
    providerRead: GET RevenueCat API v1 subscriber by exact auth UUID
    assignmentFailure: ASSIGNMENT_REQUIRED dead letter; never infer current household
    retryable: [network, timeout, rate_limit, provider_5xx, rpc_unavailable]
    terminal: [identity_mismatch, environment_mismatch, unmapped_snapshot, assignment_required]
    transitionAudit: app_private.billing_reconciliation_transitions
  normalizedIngest:
    source: verified provider adapter
    serverOnly: true
    identityKey: [provider, environment, authUserId]
    revenueCatCustomerRule: providerCustomerRef exactly equals authUserId
    idempotencyKey: [provider, environment, providerEventId]
    replayRule: identical request hash increments replay count without another transition
    collisionRule: same event ID with different request hash is rejected
    orderingClock: providerOccurredAt at customer scope
    olderEventRule: record stale and do not regress materialized entitlement
    equalTimeRule: quarantine a different event as ambiguous
  materializedAuthority:
    aggregate: household_entitlement
    lifecycleStatuses: [none, trialing, active, grace, billing_issue, expired, revoked]
    effectivePlans: [free, plus]
    terminalRule: expiration or revoke changes effective plan to free without deleting family data
    assignmentRule: one active customer per household and one active household per customer
  featureEnforcement:
    domainEvent: false
    runtimeAudit: app_private.billing_policy_events
    activation: service-only expected-version command after both policies are finalized
    features: [members, activeSeries]
    concurrency: transaction advisory lock by household and feature
    downgradeRule: preserve existing data and deny only new or reactivated expansion
    clientProjection: aggregate decision, usage, limit, plan/status, versions, and timestamp only
    defaultBeforeD027: disabled mutation enforcement and policy_unavailable client gate
  privacyRule:
    forbiddenDomainPayload:
      - providerCustomerRef
      - providerEventId
      - transactionRef
      - originalTransactionRef
      - receipt
      - providerSnapshot
      - payloadCiphertext
    allowedEntitlementPayload:
      - planCode
      - status
      - source
      - currentPeriodEnd
      - willRenew
      - version
  producerStatus: WP06-01 materialization and WP06-04 local reconciliation implemented; billing outbox producers remain deferred
privacyState:
  accountDeletion:
    domainEventProducer: false
    requestAuthority: public.privacy_requests
    privateAudit: app_private.account_deletion_events
    runtimeAudit: app_private.privacy_runtime_events
    transitions: [requested, cancelled, claimed, tombstoned, retry_scheduled, completed, failed]
    immutable: true
    metadataRule: aggregate counts and allowlisted reason/attempt/window values only
    forbiddenAuditData:
      - email, display name, avatar, or family content
      - bearer token, recent-auth proof, idempotency key, or endpoint material
      - provider customer, transaction, or receipt reference
    publicEventStatus: privacy event names below remain reference taxonomy until an outbox producer is separately approved
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
  chore.occurrence_due_changed:
    version: 1
    aggregate: chore_occurrence
    payload: choreOccurrenceDueChangedV1
  chore.occurrence_assigned:
    version: 1
    aggregate: chore_occurrence
    payload: choreOccurrenceAssignedV1
  calendar.series_created: {version: 1, aggregate: event_series}
  calendar.series_revised: {version: 1, aggregate: event_series}
  calendar.series_cancelled: {version: 1, aggregate: event_series}
  calendar.occurrence_overridden: {version: 1, aggregate: event_occurrence}
  calendar.occurrence_cancelled: {version: 1, aggregate: event_occurrence}
  calendar.occurrence_reminder_snoozed:
    version: 1
    aggregate: event_occurrence
    payload: calendarOccurrenceReminderSnoozedV1
  notification.intent_created: {version: 1, aggregate: notification_intent}
  notification.delivery_succeeded: {version: 1, aggregate: notification_delivery}
  notification.delivery_failed: {version: 1, aggregate: notification_delivery}
  billing.purchase_synced: {version: 1, aggregate: billing_customer}
  billing.assignment_prepared:
    version: 1
    aggregate: billing_household_assignment
    payload: billingAssignmentLifecycleV1
  billing.assignment_confirmed:
    version: 1
    aggregate: billing_household_assignment
    payload: billingAssignmentLifecycleV1
  billing.assignment_released:
    version: 1
    aggregate: billing_household_assignment
    payload: billingAssignmentLifecycleV1
  billing.assignment_transferred:
    version: 1
    aggregate: billing_household_assignment
    payload: billingAssignmentLifecycleV1
  billing.assignment_remediation_requested:
    version: 1
    aggregate: billing_assignment_remediation_request
    payload: billingAssignmentRemediationV1
  billing.household_assigned: {version: 1, aggregate: billing_household_assignment}
  billing.household_unassigned: {version: 1, aggregate: billing_household_assignment}
  billing.entitlement_changed: {version: 1, aggregate: household_entitlement}
  privacy.export_requested: {version: 1, aggregate: privacy_request}
  privacy.deletion_requested: {version: 1, aggregate: privacy_request}
  privacy.request_completed: {version: 1, aggregate: privacy_request}
  security.kill_switch_changed: {version: 1, aggregate: kill_switch}
payloads:
  choreOccurrenceDueChangedV1:
    exactKeys: [dueLocalDate, dueAt, timezone, status]
    dueLocalDate: ISO-8601 local date
    dueAt: ISO-8601 UTC timestamp or null
    timezone: IANA timezone
    status: scheduled | completed | skipped | cancelled
  choreOccurrenceAssignedV1:
    exactKeys: [assigneeMemberId, status]
    assigneeMemberId: same-household member UUID
    status: scheduled | completed | skipped | cancelled
  calendarOccurrenceReminderSnoozedV1:
    exactKeys:
      - recipientMemberId
      - originalInboxItemId
      - localStartDate
      - occurrenceScheduledAt
      - scheduledAt
      - snoozeMinutes
      - snoozeCount
      - timezone
      - status
    recipientMemberId: exact immutable participant UUID
    originalInboxItemId: superseded caller-owned inbox UUID
    localStartDate: ISO-8601 local date
    occurrenceScheduledAt: ISO-8601 UTC base-start timestamp
    scheduledAt: ISO-8601 UTC explicit Snooze timestamp
    snoozeMinutes: 5 | 10 | 30
    snoozeCount: 1 | 2 | 3
    timezone: IANA timezone
    status: scheduled
    forbidden:
      - event title or description
      - household or member display name
      - email, push token, provider receipt, or raw error
  billingAssignmentLifecycleV1:
    exactKeys: [action, bindingState, reasonCode]
    action: prepared | confirmed | released | expired | transferred
    bindingState: provisional | confirmed
    reasonCode: allowlisted non-content code or null
    forbidden:
      - provider or customer reference
      - transaction or receipt identifier
      - source or other household identifier
      - billing-owner user identifier
      - support case reference
  billingAssignmentRemediationV1:
    exactKeys: [issueKind, status]
    issueKind: customer_conflict | household_conflict | owner_membership_changed | restore_conflict
    status: open | resolved | rejected
    forbidden:
      - free-form case text
      - provider, customer, transaction or receipt identifier
      - another household or user identifier
```
