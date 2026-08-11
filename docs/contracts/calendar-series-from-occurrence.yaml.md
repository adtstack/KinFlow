# 반복 일정 선택 회차 이후 수정 계약

```yaml
version: "2026-08-10-wp04-14"
requirements: [FR-CAL-004, FR-CAL-005, FR-CAL-006, FR-CAL-010, NFR-SEC-01, NFR-REL-01]
decisions: [D-017, D-019, D-020, D-046, D-048, D-062]
actor:
  authentication: required
  membership: active member of the requested non-deleted household
  unavailable: missing, removed, ended, deleted, or cross-household resources share the same result
command:
  name: update_recurring_calendar_series_from_occurrence
  inputs:
    - idempotencyKey: uuid
    - householdId: uuid
    - seriesId: uuid
    - effectiveOccurrenceId: uuid
    - expectedSeriesVersion: positive integer
    - normalized title and nullable description
    - timed or all-day household-local event shape
    - strict daily, weekly, or monthly recurrence rule
    - one to fifty unique active household participants
  forbidden:
    - client supplied effective boundary date
    - targeting an occurrence from an old revision
    - targeting an explicit one-occurrence exception
effectiveBoundary:
  authority: server
  value: target occurrence immutable recurrence_local_start_date
  targetRequirements:
    - belongs to the requested household and series
    - belongs to the active immutable series revision
    - status is scheduled
    - has no explicit occurrence exception
    - recurrence slot is not before server-derived household-local today
  newDraft:
    - local start date is not before the selected boundary
    - until date is not before the selected boundary
    - weekly and monthly anchors satisfy the existing strict recurrence contract
concurrency:
  series: exact optimistic version
  targetOccurrence: row lock before boundary derivation
  idempotency: authenticated-user plus command UUID and full normalized request hash
  legacyCompatibility: legacy update request hash is byte-compatible with its previous command shape
mutation:
  - append one immutable active series revision
  - replace the current participant projection with the new active participant set
  - preserve every occurrence before the selected boundary
  - preserve every explicit one-occurrence exception at or after the boundary exactly
  - reuse matching non-exception occurrence identities at or after the boundary
  - cancel obsolete non-exception source slots at or after the boundary
  - materialize the bounded 365-day window from the selected boundary using the canonical generator
  - reset rolling materialization coverage to the selected boundary and new revision
  - append one content-free aggregate series-change event and existing audit event
output:
  exactKeys:
    - household_id
    - household_timezone
    - household_local_date
    - series_id
    - revision_id
    - revision_number
    - effective_local_date
    - materialized_through
    - version
    - rebuilt_count
    - cancelled_count
    - preserved_exception_count
    - changed
  replay: same exact summary with changed false
errors:
  unauthenticated: KFE01
  notFoundOrForbidden: KFE03
  idempotencyConflict: KFE04
  staleVersion: KFE05
  nonexistentLocalTime: KFE06
  invalidRecurrenceOrBoundary: KFE07
  noOpTransition: KFE08
client:
  availability: scheduled recurring non-exception occurrence on or after the page household-local date
  runtimePolicy: Calendar mutation guard runs before command ID or repository I/O
  editor:
    prefill: current active revision
    initialDate: selected immutable recurrence slot
    minimumDate: selected immutable recurrence slot
    overlapPreviewWindowStart: selected immutable recurrence slot
    disclosure:
      - selected and later source occurrences use the new settings
      - earlier occurrences remain unchanged
      - existing one-occurrence changes remain unchanged
  authority:
    clientEffectiveDate: advisory validation and retry fingerprint only
    rpcBoundaryInput: selected occurrence UUID only
  recovery:
    retry: identical normalized input and target reuse the same command UUID
    staleInvalidTransitionOrUnavailableTarget: authoritative current-query reload
    success: authoritative current-query reload
privacy:
  newUserContentSurface: none
  commandState: irreversible request hash, revision identity, boundary, versions, and aggregate counts only
  audit: does not store the selected target identity, title, description, display name, email, or auth subject in payload metadata
dbApiImpact:
  migration: additive authenticated public RPC plus private shared engine
  tables: none
  columns: none
  constraints: none
  rls: unchanged
  legacyWholeSeriesUpdate: same public signature, request hash, result, and today boundary
rollback:
  client: remove the selected-occurrence action and adapter method
  server: revoke execute from the additive RPC in a forward migration
  sharedEngine: retain while the legacy wrapper depends on it or restore the previous legacy body in a forward migration
  data: immutable revisions already created remain valid and readable
related:
  selectedBoundaryCancellation: defined separately by WP04-15 in calendar-series-cancel-from-occurrence.yaml.md
deferred:
  - undo or resume of a selected-boundary edit
  - ordinal, yearly, business-day, or multi-month-day recurrence
  - real-account, hosted, two-device, timezone-boundary, and physical-device validation
```
