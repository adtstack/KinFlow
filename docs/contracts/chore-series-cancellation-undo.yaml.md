# 반복 집안일 선택 경계 취소 즉시 Undo 계약

```yaml
version: "2026-08-10-wp03-22"
requirements: [FR-CHORE-005, FR-CHORE-008, FR-CHORE-013, FR-CHORE-014, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-017, D-019, D-020, D-048, D-061, D-065]
scope:
  sourceCommand: cancel_repeating_chore_series_from_occurrence
  recovery: immediate process-memory Undo backed by an authoritative server resume command
  actor: original cancellation actor who is still an active Owner or Admin
compatibility:
  cancellationRpc:
    publicName: cancel_repeating_chore_series_from_occurrence
    exactInputs: [p_idempotency_key, p_household_id, p_series_id, p_effective_occurrence_id, p_expected_version]
    exactResultKeys: [household_id, series_id, effective_local_date, version, cancelled_count, preserved_completed_count, terminal_revision_id, terminal_revision_number, changed]
    behavior: unchanged for old and new clients
  engine:
    visibility: private and not executable by client or service roles
ledger:
  schema: app_private
  key: [authenticated_user_id, cancellation_idempotency_key, occurrence_id]
  fields:
    - household and series identifiers
    - mutation kind: cancelled_status or terminal_repoint
    - previous and post occurrence status
    - previous and post immutable revision identifier
    - previous and post occurrence version
  forbidden:
    - title or description
    - due date, due time or timezone
    - assignee, completer or display identity
    - email, token, provider response or arbitrary payload
  grants: none for public, anon, authenticated, or service_role
resumeCommand:
  name: resume_repeating_chore_series_cancellation
  inputs:
    - idempotencyKey: new uuid for the resume attempt
    - householdId: uuid
    - seriesId: uuid
    - cancellationIdempotencyKey: exact original cancellation command uuid
    - expectedVersion: exact cancellation result series version
  authorization:
    - authenticated caller owns the original cancellation command
    - caller is still an active Owner or Admin in the exact household
    - household and series match the cancellation record
  concurrency:
    - series row is locked and must still equal expectedVersion
    - terminal revision or soft-delete shape must still match the cancellation result
    - every cancellation-status ledger row must still match its recorded post state
    - same resume key and input returns the original result with changed false
    - same key with different input is rejected
  mutation:
    - clone the pre-cancellation source revision as a new immutable resumed revision
    - preserve source title, description, assignee, due local time, recurrence frequency, interval, weekdays, month day, anchor and end rule
    - reactivate a soft-deleted series or replace a bounded terminal active revision
    - restore cancellation-status rows to their previous scheduled or skipped state
    - point rows from the source revision at the new resumed revision while preserving other historical revision identity
    - restore unchanged terminal-prefix revision moves without overwriting any later completion or edit
    - preserve every completed occurrence and completion actor/history
    - clear materialization coverage for canonical future repair
    - append one immutable content-free resumed aggregate event
  output:
    exactKeys: [household_id, series_id, effective_local_date, version, restored_count, preserved_completed_count, revision_id, revision_number, changed]
    invariant:
      - restored_count is positive and counts status-restored occurrences
      - revision_id and revision_number identify the new immutable active revision
      - replay returns the same summary with changed false
errors:
  unauthenticated: KFC01
  invalidInput: KFC02
  notFoundOrForbidden: KFC03
  idempotencyConflict: KFC04
  staleVersion: KFC05
  invalidTransition: KFC06
client:
  availability: only the successful selected-boundary cancellation Snackbar in the current controller lifetime
  runtimePolicy: chores mutation guard before command ID and repository I/O
  persistence: none
  success: clear receipt and authoritative current-query reload
  transientFailure: preserve receipt and exact resume command key for retry
  terminalFailure: clear receipt and authoritative current-query reload
  localization: [EN, KO, EN-XA]
rollback:
  client: hide immediate Undo while cancellation remains available
  server: revoke the additive resume command in a forward migration
  data: keep immutable ledger, revisions, request and aggregate audit records
deferred:
  - persistent recent-cancellation history after process death
  - arbitrary historical resume
  - persistent Calendar cancellation history beyond the immediate WP04-16 parity
  - hosted, real-account, two-device, timezone-boundary, and physical-device evidence
```
