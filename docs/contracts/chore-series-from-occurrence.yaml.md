# 반복 집안일 선택 회차 이후 수정 계약

```yaml
version: "2026-08-10-wp03-20"
requirements: [FR-CHORE-005, FR-CHORE-008, FR-CHORE-012, NFR-SEC-01, NFR-REL-01]
decisions: [D-017, D-019, D-020, D-048, D-060]
actor:
  authentication: required
  roles: [owner, admin]
  member: denied with the same not-found-or-forbidden result
command:
  name: update_repeating_chore_series_from_occurrence
  inputs:
    - idempotencyKey: uuid
    - householdId: uuid
    - seriesId: uuid
    - effectiveOccurrenceId: uuid
    - expectedSeriesVersion: positive integer
    - normalized title and nullable description
    - active household default assignee
    - nullable minute-precision household-local due time
    - strict daily, weekly, or monthly recurrence rule
  effectiveBoundary:
    authority: server
    value: target occurrence immutable recurrence_local_date
    targetRequirements:
      - belongs to requested household and series
      - belongs to the active immutable series revision
      - status is scheduled
      - recurrence slot is not before server-derived household-local today
    forbidden:
      - client supplied boundary date
      - due_local_date as recurrence authority
      - targeting a completed, skipped, cancelled, old-revision, or one-time occurrence
  concurrency:
    series: exact optimistic version
    targetOccurrence: row lock before boundary derivation
    idempotency: authenticated-user plus command UUID and full normalized request hash
  mutation:
    - append one immutable series revision effective at the target recurrence slot
    - point the series active revision at the new revision
    - reuse matching incomplete occurrence identities at or after the boundary
    - cancel obsolete incomplete slots at or after the boundary
    - materialize the bounded 365-day window using the shared canonical generator
    - preserve every occurrence before the boundary
    - preserve completed occurrences at or after the boundary on their historical revision
    - reset non-completed single-occurrence overrides at or after the boundary to the new series defaults
    - clear stale materialization coverage and append a content-free aggregate audit event
  output:
    exactKeys:
      - household_id
      - series_id
      - revision_id
      - revision_number
      - effective_local_date
      - version
      - rebuilt_count
      - cancelled_count
      - preserved_completed_count
      - changed
    replay: same exact summary with changed false
errors:
  unauthenticated: KFC01
  notFoundOrForbidden: KFC03
  idempotencyConflict: KFC04
  staleVersion: KFC05
  invalidTransition: KFC06
  invalidRecurrence: KFC07
client:
  availability: upcoming scheduled recurring item with canManageSeries only
  runtimePolicy: chores mutation guard runs before command ID or repository I/O
  editor:
    prefill: current active revision
    minimumDate: selected item date for fail-closed local validation
    disclosure:
      - selected occurrence and later incomplete occurrences change
      - earlier and completed occurrences remain unchanged
      - later non-completed one-occurrence adjustments are reset
  recovery:
    retry: identical normalized input reuses the same command UUID
    staleOrInvalidTransition: authoritative list reload
    success: authoritative current query reload
privacy:
  newUserContent: none
  commandState: hash and aggregate result only
  audit: no title, notes, display name, email, or auth subject
dbApiImpact:
  migration: additive public RPC only
  tables: none
  columns: none
  rls: unchanged
  legacyRpc: preserved
rollback:
  client: remove the from-occurrence action and adapter method
  server: revoke execute from the additive RPC in a forward migration
  data: immutable revisions already created remain valid and readable
deferred:
  - cancel from selected occurrence
  - Calendar edit and cancellation parity are defined by WP04-14 and WP04-15
  - preserving later non-completed one-occurrence overrides
  - real-account, hosted, two-device, and physical-device validation
```
