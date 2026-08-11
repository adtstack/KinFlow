# 원본 파일 문서화: `contracts/one-time-chore-lifecycle.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/one-time-chore-lifecycle.yaml`
- 원본 형식: `yaml`
- 범위: WP03-09 scheduled one-time chore update/delete lifecycle

```yaml
version: "2026-08-09-wp03-09"
requirements: [FR-CHORE-001, FR-CHORE-003, NFR-SEC-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-017, D-048]
authority:
  authorization: PostgreSQL security-definer RPC plus active-household checks
  concurrency: expected series version and expected occurrence version
  time: household IANA timezone on the server
  content: immutable chore_series_revisions
eligibility:
  caller: active adult household member
  targetRecurrenceRule: {type: once}
  targetStatus: scheduled
  assignee: active member of the exact household
update:
  rpc: update_one_time_chore
  input:
    - idempotencyKey
    - householdId
    - seriesId
    - occurrenceId
    - expectedSeriesVersion
    - expectedOccurrenceVersion
    - title
    - optional description
    - assigneeMemberId
    - dueLocalDate
    - optional dueLocalTime
  normalized: [trim title, trim description, empty description to null]
  atomicEffects:
    - insert next immutable one-time revision
    - set series title, description, and active revision
    - update the stable occurrence revision, assignee, due intent, timezone, and UTC instant
    - increment series and occurrence versions
    - append content-free immutable audit event
  noOp: KFC06
delete:
  rpc: delete_one_time_chore
  input: [idempotencyKey, householdId, seriesId, occurrenceId, expectedSeriesVersion, expectedOccurrenceVersion]
  atomicEffects:
    - transition occurrence from scheduled to cancelled
    - soft-delete series with deletedAt
    - preserve occurrence and all revisions
    - increment series and occurrence versions
    - append content-free immutable audit event
idempotency:
  scope: authenticated user plus idempotency key
  sameOperationAndPayload: replay exact metadata with changed false
  changedPayload: KFC04
  updateDeleteCrossReuse: KFC04
errors:
  KFC01: unauthenticated
  KFC02: invalid input
  KFC03: not found, inactive, cross-household, wrong type, or forbidden
  KFC04: idempotency conflict
  KFC05: stale series or occurrence version
  KFC06: invalid transition, completed target, or no-op update
audit:
  table: public.one_time_chore_change_events
  immutable: true
  rlsSelect: active household member only
  forbiddenContent: [title, description, display name, token, provider error]
  allowedMetadata:
    - household, series, occurrence, revision and member identifiers
    - previous and new due intent
    - series and occurrence versions
    - operation, actor, correlation and occurredAt
permissions:
  directSeriesRevisionOccurrenceMutation: denied
  commandTableAccess: denied to anon, authenticated, and service_role
  rpcExecute: authenticated only
client:
  source: scheduled one-time row in Today or chore list
  editFields: [title, description, assignee, due local date, due local time]
  deleteConfirmation: required
  offlineCacheMutation: denied
  conflictRecovery: authoritative current-query reload
  localization: [EN, KO, EN-XA]
  rawErrorText: forbidden
deferred:
  - completed item direct edit/delete
  - trash, archive, restore, bulk and undo-delete UI
  - managed-child authorization and approval
  - content-change history presentation
  - real-account, remote Supabase, Realtime two-device and physical-device evidence
```
