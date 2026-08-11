# 원본 파일 문서화: `contracts/chore-completion-outbox.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-completion-outbox.yaml`
- 원본 형식: `yaml`
- 범위: WP05-10 Android authenticated adult Today/Chores list의 단일 완료 outbox

```yaml
version: "2026-08-09-wp05-10"
requirements: [FR-CHORE-004, FR-TODAY-003, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-002, D-006, D-013, D-017, D-018, D-023, D-043, D-048, D-049, D-051]
dependsOn:
  readCache: WP05-06
  targetAuthorizationRead: get_chore_occurrence_action_target@WP05-09
  completionMutation: public.set_chore_occurrence_completion
scope:
  platform: Android Store MVP phone and tablet
  principal: authenticated adult with an active household
  entryPoints: [Today chore list, Chores list, Today overdue section]
  operation: scheduled_to_completed
  capacity: exactly one pending occurrence completion
  excludedOperations:
    - completed_to_scheduled
    - skip_or_restore
    - reschedule_or_reassign
    - one_time_create_edit_delete_restore
    - repeating_series_create_edit_cancel
    - role_invite_billing_deletion_or_export
    - notification_target_detail_action
availability:
  composedWhen:
    - Android runtime
    - persistent encrypted read cache composition is enabled
    - dedicated secure-storage namespace is available
  unavailableWhen: [Web, iOS before its platform ADR, bootstrap fallback]
  failClosed: no optimistic state and no network replay when secure persistence fails
queueTrigger:
  cachedRead:
    - exact cached occurrence is scheduled at expectedVersion
    - cached authorization projection canSetCompletion is true
    - active household and actor member are available
    - write the queue item before applying the local completed presentation
  onlineTransientFailure:
    - only typed temporarilyUnavailable from the completion mutation
    - reuse the exact idempotency key already sent for the same fingerprint
    - persist before retaining the optimistic completed presentation
  forbidden:
    - raw exception or internal failure
    - unauthenticated, forbidden, invalid payload, stale version, invalid transition, idempotency conflict
    - queueing a different occurrence while the single slot is occupied
item:
  exactFields:
    - contractVersion
    - userId
    - sessionId
    - householdId
    - actorMemberId
    - occurrenceId
    - expectedVersion
    - requestedStatus
    - idempotencyKey
    - createdAt
    - expiresAt
    - attemptCount
  requestedStatus: completed
  ttl:
    policyMaximum: 30 minutes
    effectiveExpiry: earlier of createdAt plus 30 minutes or current access-session expiry
  replayAttempts:
    automaticMaximum: 3
    incrementAndPersistBeforeAnyTargetReadOrMutation: true
  encodedMaximumBytes: 4096
  forbiddenContent:
    - title
    - description
    - assignee display name
    - email
    - access or refresh token
    - raw provider error
storage:
  key: kinflow.chore_completion_outbox.v1
  namespace: environment-specific dedicated FlutterSecureStorage namespace
  backup: disabled
  encryption: Android Keystore-backed existing secure-storage configuration
  serialization: exact-key canonical JSON only
  corruption: delete the slot and return unavailable content
  purge:
    - logout, session termination, account switch
    - active household switch or removal
    - exact user, session, household, or actor-member mismatch
    - expiry, malformed payload, unsupported contract version, or oversize value
foregroundReplay:
  triggers: [initial list load, explicit refresh, app resume]
  backgroundWorker: none
  order:
    - resolve the exact current auth session, active household, and actor member
    - read and validate the single encrypted item
    - stop without replay when the chores runtime mutation policy is blocked
    - persist the incremented attempt count
    - call get_chore_occurrence_action_target without read-cache fallback
    - revalidate current membership and server-derived canSetCompletion
    - replay the exact completion request with its original expectedVersion and idempotency key
    - load Today and overdue lists after replay resolution
  alreadyApplied:
    condition: target is completed at expectedVersion plus one
    result: clear the item and report reconciled success without a second mutation
  replayableTarget:
    condition: target is scheduled at exact expectedVersion and canSetCompletion is true
    mutation: same occurrence, expectedVersion, completed true, and idempotency key
  successValidation:
    - exact household and occurrence
    - completed status
    - exact expectedVersion plus one
  transientFailure:
    - retain until expiry or automatic attempt maximum
    - after maximum, keep the item visible but require discard and a fresh online action
  terminalFailure:
    - clear on stale version, invalid transition, unavailable target, authorization failure, invalid payload, or mismatched success
    - show authoritative server data and a stable localized recovery notice
  terminalClearFailure:
    - persist attemptCount at the automatic maximum before any later foreground preflight
    - never preserve the optimistic completed presentation
    - require explicit discard and a fresh authoritative online action
  reauthenticationOrContextChange:
    behavior: purge without automatic replay
presentation:
  queued:
    - show a localized live-region banner that the completion is saved on this device
    - expose an explicit discard action
    - show the desired completed state when the occurrence exists in the current cached list
  syncing: localized live-region status and disabled duplicate action
  reconciled: localized success notice after authoritative list load
  needsAttention: localized discard-and-retry-online recovery
  discarded: localized conflict/authorization/expiry notice without raw provider text
  cachedMutationPolicy:
    allowed: scheduled_to_completed when queue gate passes
    denied: every other write and pagination/filter expansion covered by WP05-06
  accessibility: status uses semantics liveRegion and buttons retain minimum Material tap targets
privacy:
  loggingAndTelemetry: none added
  storageKeyIdentifiers: none
  familyContentAtRest: none beyond UUID command metadata in the encrypted value
dbApiImpact:
  migration: none
  tableOrRlsChange: none
  rpcChange: none
  edgeFunctionChange: none
rollback:
  client: compose UnavailableChoreCompletionOutbox and restore WP05-06 read-only completion behavior
  storage: delete only the dedicated chore-completion-outbox namespace
  server: none
  dataMigrationRequired: false
deferred:
  - notification target detail completion remains online-only under WP05-09
  - physical Android process-death, airplane-mode, Keystore, backup/restore, and OEM validation
  - hosted membership removal, session rotation, and two-device race validation
  - iOS and Web composition
```
