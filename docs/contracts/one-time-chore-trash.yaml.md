# 원본 파일 문서화: `contracts/one-time-chore-trash.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/one-time-chore-trash.yaml`
- 원본 형식: `yaml`
- 범위: WP03-13 scheduled one-time chore delete undo, trash projection and restore lifecycle

```yaml
version: "2026-08-09-wp03-13"
requirements: [FR-CHORE-001, FR-CHORE-003, NFR-SEC-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-017, D-048]
scope:
  caller: active adult household member
  target: soft-deleted scheduled one-time chore only
  recurringSeries: excluded
  completedOccurrence: excluded
authority:
  authorization: PostgreSQL security-definer RPC plus active-household checks
  concurrency: expected series version and expected occurrence version
  content: preserved immutable active chore revision
  clientUndo: advisory process-memory receipt only
trashRead:
  rpc: get_deleted_one_time_chores
  input: [householdId, limit, optionalBeforeCursor]
  bounds: {minimumLimit: 1, maximumLimit: 100, defaultLimit: 30}
  ordering: [deletedAt descending, seriesId descending]
  cursor: opaque lowercase-hex encoded exact versioned JSON bound to deletedAt and seriesId
  exactResultKeys:
    - household_id
    - household_timezone
    - generated_at
    - page_limit
    - has_more
    - page_cursor
    - occurrence_id
    - series_id
    - title
    - description
    - assignee_member_id
    - assignee_display_name
    - due_local_date
    - due_local_time
    - due_at
    - deleted_at
    - series_version
    - occurrence_version
  emptyResult: one metadata row with all item fields null
  visibility: active members of the exact household only
restore:
  rpc: restore_one_time_chore
  input: [idempotencyKey, householdId, seriesId, occurrenceId, expectedSeriesVersion, expectedOccurrenceVersion]
  preconditions:
    - series deletedAt is non-null
    - active revision recurrence type is once
    - exact occurrence status is cancelled
    - original assignee remains an active exact-household member
    - series and occurrence versions both match
  atomicEffects:
    - clear series deletedAt
    - transition occurrence from cancelled to scheduled
    - preserve title, description, revision, assignee and due intent
    - increment series and occurrence versions
    - append content-free immutable restored audit event
  exactResultKeys: [household_id, series_id, occurrence_id, status, series_version, occurrence_version, changed]
idempotency:
  namespace: existing caller plus one-time-chore change command key
  sameOperationAndPayload: replay exact metadata with changed false
  changedPayloadOrCrossOperation: KFC04
errors:
  KFC01: unauthenticated
  KFC02: invalid input or cursor
  KFC03: not found, inactive, cross-household, wrong type, or forbidden
  KFC04: idempotency conflict
  KFC05: stale series or occurrence version
  KFC06: invalid transition or inactive original assignee
audit:
  table: public.one_time_chore_change_events
  operation: restored
  immutable: true
  contentFree: true
  preservedIdentifiersAndIntent: true
client:
  route: /chores/trash
  deletionUndo:
    receipt: original visible occurrence plus post-delete series and occurrence versions
    lifetime: process memory only; cleared by another mutation, scope change or successful restore
    presentation: localized Snackbar action after authoritative deletion reload
  trashScreen:
    - initial load, retry, refresh and bounded pagination
    - localized deleted timestamp and preserved assignee/due intent
    - restore action with pending, conflict and unavailable states
  mutationGuard: exact chores runtime capability before repository or ID generation
  successReconciliation: authoritative current-list and trash reload; no local content reconstruction as authority
  offlineCache: no persistent trash cache and no offline restore
  localization: [EN, KO, EN-XA]
  rawErrorText: forbidden
security:
  directSeriesRevisionOccurrenceMutation: denied
  commandTableAccess: denied to anon, authenticated and service_role
  featurePolicyIsAuthorization: false
  independentBoundaries: [RLS, membership, recurrence type, status, expected versions, idempotency]
rollback:
  emergency: revoke authenticated execute on restore RPC while retaining trash read and preserved soft-deleted data
  client: remove route and undo action while existing deletion behavior remains
  schema: forward-only restore previous audit constraints and drop new functions only after client retirement
deferred:
  - permanent purge, retention expiry, archive and bulk restore
  - repeating-series cancellation restore and completed-item delete/restore
  - restore-time reassignment when the original assignee was removed
  - managed-child authorization and approval
  - real-account, hosted Supabase, Realtime two-device and physical-device evidence
```
