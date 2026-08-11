# Phase 03 WP03-22 Repeating Chore Cancellation Immediate Undo Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 03, P1 activation and release completion are not claimed
- Requirements: `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-013`, `FR-CHORE-014`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-065` provisional; existing recurrence and authority decisions remain in force
- Trace IDs: `API-052`, `T-CHORE-SERIES-CANCEL-UNDO`, `TIME-044`
- Vertical slice: successful Upcoming selected-boundary cancellation → private metadata-only pre-state ledger → process-memory Snackbar receipt → actor/version-bound resume → new immutable revision and exact row restoration → authoritative current-query reload
- Actual account, hosted Supabase, two-device, timezone-boundary, process-death product validation and physical-device validation: intentionally not run by current priority

## Acceptance results

| Criterion | Result |
|---|---|
| Legacy cancellation compatibility | PASS — `cancel_repeating_chore_series_from_occurrence` retains its exact five inputs, nine outputs and authenticated grant; the previous 46-case contract passes unchanged through the compatible wrapper |
| Private pre-state capture | PASS — only the first successful cancellation records exact changed occurrence metadata keyed by actor, cancellation command and occurrence; replay creates no duplicate ledger rows |
| Privacy boundary | PASS — the grant-free private ledger contains identifiers, mutation kind and previous/post status, revision and version only; title, description, due, timezone, assignee, completer, display identity, email, token and arbitrary payload are absent |
| Resume authorization | PASS — only the original cancellation actor who is still an active Owner/Admin in the exact household can resume; Member, another Owner, removed actor, unauthenticated and cross-household calls fail closed |
| Optimistic concurrency | PASS — exact cancellation-result series version, terminal revision or soft-delete shape and every cancellation-status post-state are checked under lock before mutation |
| State restoration | PASS — cancellation-created `cancelled` rows return to their exact prior `scheduled` or `skipped` state and version lineage; a new immutable revision clones the pre-cancellation source and becomes active |
| Historical preservation | PASS — completed rows and prefix rows completed or edited after cancellation are not overwritten; original completion actor and history remain intact |
| Recurrence continuation | PASS — materialization coverage is cleared and the canonical worker extends the resumed series without recreating obsolete cancellation state |
| Replay and audit | PASS — same resume key/input returns the original summary with `changed=false`, different input conflicts, and one immutable content-free `resumed` aggregate event is appended |
| Client receipt and retry | PASS — only a successful selected-boundary cancellation exposes an in-memory receipt; success clears it, transient failure preserves it and reuses the exact resume key, and terminal conflict clears it before authoritative reconciliation |
| Runtime and cache policy | PASS — Chores runtime policy and read-only cache guards run before command ID or repository I/O; a successful resume invalidates Today/Chore reads and reloads the current query |
| Localization and accessibility | PASS — EN/KO/EN-XA copy, a minimum 48 dp Undo action and compact 320×568 pseudo text at 200% render without exception |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/chore-series-cancellation-undo.yaml.md` defines compatibility, ledger privacy, authorization, concurrency, restoration, replay, client lifetime and rollback |
| Ordered migration | `supabase/migrations/20260810150000_chore_series_cancellation_undo.sql` moves the WP03-21 engine private, preserves its public wrapper, adds the immutable private ledger, widens operation checks with `resumed` and adds the authenticated resume RPC |
| DB contract tests | `supabase/tests/database/chore_series_cancellation_undo.test.sql` covers 46 signature, grant, privacy, role, version, terminal-prefix, soft-delete, scheduled/skipped/completed preservation, drift, worker, replay, collision and audit assertions |
| Legacy compatibility tests | `supabase/tests/database/chore_series_cancel_from_occurrence.test.sql` retains all 46 WP03-21 assertions against the new wrapper |
| Contract skeletons | `docs/contracts/database-schema.sql.md` and `docs/contracts/rls-contract.sql.md` record the private ledger and mediated resume surface without a public table grant |

The public response contains only household/series identifiers, the server boundary, series version, aggregate restored/preserved counts, new revision identity/number and `changed`. No Edge Function, notification payload, public configuration, dependency, native permission, RLS policy or public content column was added.

## Flutter implementation

| Area | Evidence |
|---|---|
| Domain and retry identity | `apps/kinflow_app/lib/features/chores/domain/entities/repeating_chore_series_change.dart` binds the resume operation to the original cancellation command and exact cancellation-result version and produces a stable operation-specific fingerprint |
| Repository boundary | `apps/kinflow_app/lib/features/chores/domain/repositories/chore_repository.dart`, `data/datasources/chore_data_source.dart` and `data/repositories/provider_chore_repository.dart` expose typed resume results and reject mismatched household/series/version, invalid counts or revision identity |
| Supabase adapter | `apps/kinflow_app/lib/infrastructure/supabase/supabase_chore_data_source.dart` sends the exact five resume inputs and strictly parses the exact nine-key result |
| Cache boundary | `apps/kinflow_app/lib/infrastructure/cache/cached_chore_data_source.dart` forwards the original cancellation key/version and invalidates both Chore read slots only after success |
| Controller state | `apps/kinflow_app/lib/features/chores/application/today_chores_controller.dart` and `today_chores_state.dart` create and expose the cancellation receipt, coalesce work, preserve the resume key on transient failure and reconcile terminal outcomes |
| Runtime policy and UI | `presentation/providers/chore_providers.dart` applies the exact Chores feature guard; `presentation/screens/today_chores_screen.dart` shows a persistent localized Snackbar Undo only for the selected-boundary path and reports success or retryable failure without raw provider details |

## Automated verification

| Gate | Result |
|---|---|
| Focused cancellation Undo pgTAP | **PASS — 46 tests** |
| Focused legacy selected-cancellation pgTAP | **PASS — 46 tests** |
| Clean local database reset | **PASS — all 60 ordered migrations applied from zero through `20260810150000`** |
| Full local database regression | **PASS — 61 files, 3,042 tests** |
| Local database lint | **PASS — 0 schema issues at warning level** |
| Focused Flutter domain/parser/repository/controller/widget suite | **PASS — 179 tests** |
| Focused cache adapter suite | **PASS — 19 tests** |
| Focused compact EN-XA 200% Undo widget | **PASS — 1 test** |
| Full exact Flutter regression | **PASS — 1,345 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Localization generation | **PASS** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,901,845 bytes, SHA-256 `a87b0a015ef9c8316fe002ceae6fe20dafcb7bac2b5e6d1f17cacc0f8a10ca03`** |
| Documentation structure | **PASS — Undo YAML exact nine-key output; 570 fence delimiter lines balanced; 13 matrices rectangular with exact declared counts, including API 52×6, requirements 124×18, tests 94×11 and time 44×12** |
| Whitespace | **PASS — `git diff --check`** |

The first final DB lint found one unused local variable that was removed without changing the query or mutation. A clean reset, both focused DB suites, lint and the full 3,042-test regression then passed on the final migration. The first full Flutter run found the static Chores runtime-guard count still expected 18 providers; adding the new correctly guarded resume notifier made the actual count 19. The architecture contract was updated to 19 and the final full regression passed. A targeted test-name command was initially split by the shell, then rerun with the name as one argument and passed; this was a test invocation issue, not a product failure.

## Security, privacy and compatibility

- The compatible cancellation wrapper and additive resume function are empty-search-path `SECURITY DEFINER` boundaries. They derive `auth.uid()`, current active membership and Owner/Admin role server-side.
- Possession of a cancellation UUID is insufficient: actor, household, series, version, terminal shape and ledger post-state must all match.
- The private ledger is immutable and has no public, anon, authenticated or service-role grant. Its metadata is the minimum required to reverse only the exact cancellation mutation.
- Resume never accepts title, notes, due, timezone, assignee or recurrence content from the client. The new revision clones the already-authorized immutable source inside PostgreSQL.
- The client receipt exists only in controller memory, does not enter read cache, completion outbox, secure storage, logs, analytics or notification payloads, and is cleared by competing writes or scope transitions.
- Existing cancellation clients remain compatible. Existing whole-series cancellation, selected/whole editing, occurrence exceptions, Calendar and notification contracts are unchanged.

## Deferred manual validation and risks

- Hosted migration, grant and RPC execution with actual adult Owner/Admin/Member accounts
- Two-device cancellation/resume observation, response-loss replay and races with completion, role removal or another series edit
- Household timezone changes and selected recurrence slots around local midnight, DST gaps/folds and month boundaries
- Android physical-device TalkBack, font scaling, keyboard, phone/tablet, split-screen and Snackbar timing
- Product research for Undo timeout expectations and demand for process-death recent-cancellation history
- Persistent cancellation history and arbitrary historical resume; Calendar immediate selected-cancellation Undo is implemented separately by WP04-16

The local feature slice is complete, but `FR-CHORE-014`, Phase 03 and release readiness remain `PARTIAL` until the deferred live gates are executed. The current process-memory receipt intentionally disappears after controller disposal or process death.

## Rollback

- Hide/remove the Snackbar Undo action and controller/repository adapter while leaving selected and whole cancellation available.
- Revoke authenticated execute on the additive resume RPC in a forward migration.
- Keep the immutable private ledger, widened `resumed` operation checks, new revisions and aggregate audit rows while records exist; do not delete or rewrite history.
- The compatible cancellation wrapper can continue calling the private WP03-21 engine even when resume is disabled. No cache row, analytics data, SDK, permission or public configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/chore_series_cancellation_undo.test.sql
npx supabase test db supabase/tests/database/chore_series_cancel_from_occurrence.test.sql
npx supabase test db
npx supabase db lint --local --level warning
flutter gen-l10n
flutter test <focused WP03-22 paths>
flutter test --reporter failures-only
flutter analyze
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
dart run tool/verify_codegen.dart
npm run ci:test
npm run ci:workflow
scripts/ci/android-build.sh dev
ruby YAML/Markdown/matrix structure checks
git diff --check
```
