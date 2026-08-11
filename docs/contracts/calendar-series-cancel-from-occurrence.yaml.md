# 반복 일정 선택 회차 이후 취소 계약

```yaml
version: "2026-08-10-wp04-15"
requirements: [FR-CAL-004, FR-CAL-005, FR-CAL-006, FR-CAL-011, NFR-SEC-01, NFR-REL-01]
decisions: [D-017, D-019, D-020, D-046, D-048, D-063]
actor:
  authentication: required
  membership: active member of the requested non-deleted household
  unavailable: missing, removed, ended, deleted, or cross-household resources share the same result
command:
  name: cancel_recurring_calendar_series_from_occurrence
  inputs:
    - idempotencyKey: uuid
    - householdId: uuid
    - seriesId: uuid
    - effectiveOccurrenceId: uuid
    - expectedSeriesVersion: positive integer
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
concurrency:
  series: exact optimistic version
  targetOccurrence: row lock before boundary derivation
  idempotency: authenticated-user plus command UUID and full normalized request hash
  legacyCompatibility: legacy cancellation request hash remains byte-compatible with its previous command shape
mutation:
  - preserve every occurrence whose immutable recurrence slot is before the selected boundary
  - preserve every earlier explicit exception exactly even when its displayed date lies after the boundary
  - cancel every non-cancelled occurrence at or after the boundary, including moved explicit exceptions
  - if no actionable scheduled non-exception prefix remains between household-local today and the boundary, end the series at the selected boundary and remove materialization state
  - otherwise clone the latest actionable prefix source revision and its participant snapshot as an immutable terminal revision
  - preserve that source title, description, timed or all-day shape, timezone, recurrence frequency, interval, and anchor
  - replace the terminal recurrence end with until at boundary minus one local day
  - repoint only actionable non-exception prefix rows from the cloned source revision; historical rows and explicit exceptions remain exact
  - activate the terminal revision without ending the series and mark its boundary-minus-one materialization coverage complete with no future repair
  - append one content-free aggregate cancellation event and existing audit event
output:
  exactKeys:
    - household_id
    - household_timezone
    - household_local_date
    - series_id
    - effective_local_date
    - version
    - cancelled_count
    - preserved_past_count
    - terminal_revision_id
    - terminal_revision_number
    - changed
  invariant:
    - terminal revision identity and number are both null or both non-null
    - null terminal revision means no actionable scheduled non-exception prefix remained and the series ended at the selected boundary
    - non-null terminal revision means the earlier actionable prefix remains queryable and the worker cannot generate at or after the selected slot
  replay: same exact summary with changed false
errors:
  unauthenticated: KFE01
  invalidInput: KFE02
  notFoundOrForbidden: KFE03
  idempotencyConflict: KFE04
  staleVersion: KFE05
  invalidTransition: KFE08
client:
  availability: scheduled recurring non-exception occurrence on or after the page household-local date
  runtimePolicy: Calendar mutation guard runs before command ID or repository I/O
  confirmation:
    - selected occurrence and every later recurrence slot are cancelled
    - later one-occurrence exceptions are also cancelled even when moved to another displayed date
    - earlier recurrence slots remain unchanged even when an exception moved them after the boundary
    - this is distinct from one-occurrence cancellation and immediate whole-series cancellation
  authority:
    clientEffectiveDate: advisory validation and retry fingerprint only
    rpcBoundaryInput: selected occurrence UUID only
  recovery:
    retry: identical target and version reuse the same command UUID
    staleInvalidTransitionOrUnavailableTarget: authoritative current-query reload
    success: authoritative current-query reload and Today Calendar cache invalidation
privacy:
  newUserContentSurface: none
  commandState: irreversible request hash, optional terminal revision identity, boundary, versions, and aggregate counts only
  audit: uses the selected occurrence identity in the existing private audit row but adds no content, display name, email, auth subject, target column, or per-row payload
dbApiImpact:
  migration: additive authenticated public RPC plus private shared cancellation engine
  tables: none
  columns: none
  constraints: cancellation replay and event shapes allow either an all-null terminal pair or a complete terminal revision and materialized-through pair
  rls: unchanged
  legacyWholeSeriesCancellation: same public signature, normalized request hash, exact nine-key result, and today boundary
  existingSeriesEditingAndExceptions: preserved
rollback:
  client: remove the selected-occurrence cancellation action and adapter method
  server: revoke execute from the additive RPC in a forward migration
  sharedEngine: retain while the legacy wrapper depends on it or restore the previous legacy body in a forward migration
  constraints: retain the widened compatible cancellation shapes while immutable terminal revisions exist
  data: terminal revisions, cancelled occurrences, replay state, and append-only audit remain valid history and are not rewritten
deferred:
  - persistent recent-cancellation history or arbitrary historical resume beyond the immediate WP04-16 Undo
  - arbitrary end-date picker or occurrence resurrection
  - ordinal, yearly, business-day, or multi-month-day recurrence
  - real-account, hosted, two-device, timezone-boundary, DST, and physical-device validation
```
