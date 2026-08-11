# 반복 집안일 선택 회차 이후 취소 계약

```yaml
version: "2026-08-10-wp03-21"
requirements: [FR-CHORE-005, FR-CHORE-008, FR-CHORE-013, NFR-SEC-01, NFR-REL-01]
decisions: [D-017, D-019, D-020, D-048, D-061]
actor:
  authentication: required
  roles: [owner, admin]
  member: denied with the same not-found-or-forbidden result
command:
  name: cancel_repeating_chore_series_from_occurrence
  inputs:
    - idempotencyKey: uuid
    - householdId: uuid
    - seriesId: uuid
    - effectiveOccurrenceId: uuid
    - expectedSeriesVersion: positive integer
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
    - preserve every occurrence whose immutable recurrence slot is before the boundary
    - preserve every completed occurrence at or after the boundary on its historical revision
    - cancel every non-completed non-cancelled occurrence at or after the boundary across revisions
    - when no scheduled prefix remains, soft-delete the series like the legacy whole-series cancellation
    - when a scheduled prefix remains, clone the latest surviving scheduled occurrence revision as an immutable terminal revision
    - preserve the terminal source title, description, assignee, time, frequency, interval and recurrence anchor
    - bound a never or until source rule at boundary minus one local day
    - bound a count source rule to the lesser of its original count and existing source-revision recurrence slots before the boundary
    - point the series active revision at the terminal revision without soft-deleting the series
    - repoint only matching surviving scheduled source-revision rows to the equivalent terminal revision; keep due and assignee exceptions unchanged
    - clear stale materialization coverage so the canonical worker observes the bounded terminal rule
    - append one content-free aggregate cancellation audit event
  output:
    exactKeys:
      - household_id
      - series_id
      - effective_local_date
      - version
      - cancelled_count
      - preserved_completed_count
      - terminal_revision_id
      - terminal_revision_number
      - changed
    invariant:
      - terminal revision identity and number are both null or both non-null
      - null terminal revision means no scheduled prefix remained and the series was soft-deleted
      - non-null terminal revision means the scheduled prefix remains queryable and materialization is bounded before the selected slot
    replay: same exact summary with changed false
errors:
  unauthenticated: KFC01
  invalidInput: KFC02
  notFoundOrForbidden: KFC03
  idempotencyConflict: KFC04
  staleVersion: KFC05
  invalidTransition: KFC06
client:
  availability: future Upcoming scheduled recurring item with canManageSeries only
  runtimePolicy: chores mutation guard runs before command ID or repository I/O
  confirmation:
    - selected occurrence and later incomplete occurrences are cancelled
    - earlier occurrences remain
    - completed history remains
    - this is distinct from immediate whole-series cancellation
  recovery:
    retry: identical target and version reuse the same command UUID
    staleInvalidTransitionOrUnavailableTarget: authoritative current-query reload
    success: authoritative current-query reload
privacy:
  newUserContent: none
  commandState: request hash, revision identity, boundary, versions and aggregate counts only
  audit: no title, notes, display name, email, auth subject, occurrence identity, or per-row payload
dbApiImpact:
  migration: additive authenticated public RPC
  tables: none
  columns: none
  constraints: existing cancellation audit and replay revision shapes allow an optional terminal revision
  rls: unchanged
  legacyWholeCancellation: preserved
  legacySeriesEditing: preserved
rollback:
  client: remove the from-occurrence cancellation action and adapter method
  server: revoke execute from the additive RPC in a forward migration
  constraints: keep the widened compatible cancellation shapes while immutable terminal revisions exist
  data: bounded terminal revisions remain valid immutable history and can continue through the canonical worker
deferred:
  - immediate process-memory Undo is an additive successor contract in WP03-22; persistent or arbitrary historical resume remains deferred
  - Calendar parity is defined separately by WP04-15
  - real-account, hosted, two-device, timezone-boundary, and physical-device validation
```
