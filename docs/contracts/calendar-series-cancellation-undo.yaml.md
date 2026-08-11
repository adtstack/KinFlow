# 반복 일정 선택 경계 취소 즉시 Undo 계약

```yaml
version: "2026-08-10-wp04-16"
requirements: [FR-CAL-004, FR-CAL-005, FR-CAL-006, FR-CAL-011, FR-CAL-012, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-017, D-019, D-020, D-046, D-048, D-063, D-066]
scope:
  sourceCommand: cancel_recurring_calendar_series_from_occurrence
  recovery: immediate process-memory Undo backed by an authoritative server resume command
  actor: original cancellation actor who is still an active member of the exact household
compatibility:
  cancellationRpc:
    publicName: cancel_recurring_calendar_series_from_occurrence
    exactInputs: [p_idempotency_key, p_household_id, p_series_id, p_effective_occurrence_id, p_expected_version]
    exactResultKeys: [household_id, household_timezone, household_local_date, series_id, effective_local_date, version, cancelled_count, preserved_past_count, terminal_revision_id, terminal_revision_number, changed]
    behavior: unchanged for old and new clients
  engine:
    visibility: private and not executable by client or service roles
ledger:
  schema: app_private
  table: calendar_series_cancellation_undo_items
  key: [authenticated_user_id, cancellation_idempotency_key, occurrence_id]
  fields:
    - household, series and occurrence identifiers
    - mutation kind: cancelled_status or terminal_repoint
    - previous and post occurrence status
    - previous and post immutable revision identifier
    - previous and post occurrence version
  forbidden:
    - title or description
    - local date, local time, duration or timezone
    - participant, display identity or email
    - token, provider response or arbitrary payload
  grants: none for public, anon, authenticated, or service_role
resumeCommand:
  name: resume_recurring_calendar_series_cancellation
  inputs:
    - idempotencyKey: new uuid for the resume attempt
    - householdId: uuid
    - seriesId: uuid
    - cancellationIdempotencyKey: exact original cancellation command uuid
    - expectedVersion: exact cancellation result series version
  authorization:
    - authenticated caller owns the original cancellation command
    - caller is still an active member of the exact non-deleted household
    - household and series match the cancellation record
  concurrency:
    - series row is locked and must still equal expectedVersion
    - bounded terminal revision or ended-series shape must still match the cancellation result
    - every cancelled-status ledger row must still match its recorded post state
    - same resume key and input returns the original result with changed false
    - same key with different input or another Calendar operation is rejected
  mutation:
    - clone the pre-cancellation source revision as a new immutable resumed revision
    - preserve source title, description, timed or all-day shape, timezone, recurrence rule, anchor and end rule
    - reject resume when a source participant is no longer an active household member
    - reactivate a series ended by the no-prefix cancellation path or replace its bounded terminal active revision
    - restore every cancellation-status row to its previous scheduled, completed, or skipped state
    - point rows that used the source revision at the new resumed revision while preserving explicit exception overrides
    - restore unchanged terminal-prefix repoints without overwriting a later-edited prefix row
    - replace the denormalized active participant set from the immutable source participant snapshot
    - clear materialization coverage so the canonical worker can extend the resumed recurrence
    - append one immutable content-free resumed aggregate event and private audit event
  output:
    exactKeys: [household_id, series_id, effective_local_date, version, restored_count, preserved_past_count, revision_id, revision_number, changed]
    invariant:
      - restored_count is positive and equals the cancellation result cancelled_count
      - revision_id and revision_number identify the new immutable active revision
      - replay returns the same summary with changed false
errors:
  unauthenticated: KFE01
  invalidInput: KFE02
  notFoundOrForbidden: KFE03
  idempotencyConflict: KFE04
  staleVersion: KFE05
  invalidTransition: KFE08
client:
  availability: only the successful selected-boundary cancellation Snackbar in the current controller lifetime
  runtimePolicy: Calendar mutation guard before command ID and repository I/O
  persistence: none
  success: clear receipt and resume retry key only after authoritative current-query reload succeeds
  transientFailure: preserve receipt and exact resume command key for retry
  successReloadFailure: preserve receipt and exact resume command key so response-loss replay can reconcile
  terminalFailure: clear receipt and authoritative current-query reload
  competingMutationOrScopeChange: clear receipt
  localization: [EN, KO, EN-XA]
  accessibility: persistent scrollable Snackbar with a minimum 48dp Undo target at 200 percent text scale
privacy:
  newUserContentSurface: none
  localReceipt: household, series, boundary, original command and cancellation-result version only
  audit: identifiers, versions, operation and aggregate counts only
rollback:
  client: hide immediate Undo while selected-boundary cancellation remains available
  server: revoke execute from the additive resume command in a forward migration
  data: keep immutable ledger, revisions, request, aggregate and audit records
deferred:
  - persistent recent-cancellation history after process death
  - arbitrary historical resume or occurrence resurrection
  - hosted, real-account, two-device, timezone-boundary, DST, and physical-device evidence
```
