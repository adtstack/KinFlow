# Phase 04 WP04-16 Calendar Cancellation Immediate Undo Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 04, P1 activation and release completion are not claimed
- Requirements: `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-011`, `FR-CAL-012`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-066` provisional; existing Calendar recurrence and active-member authority decisions remain in force
- Trace IDs: `API-053`, `T-CALENDAR-SERIES-CANCEL-UNDO`, `TIME-045`
- Vertical slice: successful selected-boundary Calendar cancellation → private metadata-only exact pre-state ledger → process-memory persistent Snackbar receipt → actor/version/post-state-bound resume → new immutable source/participant revision and exact status restoration → authoritative current-query reload
- Actual account, hosted Supabase, two-device, timezone/DST boundary, process-death product validation and physical-device validation: intentionally not run by current priority

## Acceptance results

| Criterion | Result |
|---|---|
| Legacy cancellation compatibility | PASS — `cancel_recurring_calendar_series_from_occurrence` retains its exact five inputs, eleven outputs and authenticated grant; the previous 48-case contract passes unchanged through the compatible wrapper |
| Private pre-state capture | PASS — only the first successful cancellation records exact changed occurrence metadata keyed by actor, original cancellation command and occurrence; same-key cancellation replay creates no duplicate ledger rows |
| Privacy and immutability | PASS — the grant-free private ledger contains identifiers, mutation kind and previous/post status, revision and version only; content, date/time, timezone, participant/display identity, email, token and arbitrary payload are absent; update and delete are rejected |
| Resume authorization | PASS — only the original cancellation actor who is still an active member of the exact household can resume; another active member, removed actor, unauthenticated and cross-household calls fail closed |
| Optimistic concurrency | PASS — exact cancellation-result series version, bounded-terminal or ended-series shape and every cancelled-status ledger row post-state are checked under lock before mutation |
| State and exception restoration | PASS — cancelled suffix rows return to their prior scheduled, completed or skipped status; moved explicit exception payload and recurrence semantics remain intact while source rows attach to the new active revision |
| Revision and participant restoration | PASS — source title, description, timed/all-day values, timezone, recurrence rule and active participant snapshot are cloned into a new immutable resumed revision; a removed source participant blocks the transition |
| Historical preservation | PASS — the earlier explicit exception remains exact and a prefix row changed after cancellation is not overwritten; unchanged terminal-prefix rows attach to the resumed revision |
| Recurrence continuation | PASS — both bounded-terminal and no-prefix ended-series paths reactivate, materialization coverage is cleared and the canonical worker extends the resumed recurrence without restoring obsolete cancellation state |
| Replay and audit | PASS — same resume key/input returns the original summary with `changed=false`, different input or cross-operation key use conflicts, and one content-free immutable `resumed` aggregate/private audit event is appended |
| Client receipt and retry | PASS — only successful selected-boundary cancellation exposes an in-memory receipt; transient failure and server-success/reload-failure preserve the exact resume key; authoritative reload success clears it; terminal conflict clears it before reconciliation |
| Runtime and cache policy | PASS — the Calendar mutation guard runs in the production notifier before controller command-ID/repository I/O, and successful resume invalidates Today Calendar reads before authoritative page reload |
| Localization and accessibility | PASS — EN/KO/EN-XA copy, persistent scrollable Snackbar, minimum 48dp action and compact 320×568 pseudo text at 200% keep Undo reachable without overflow |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/calendar-series-cancellation-undo.yaml.md` defines compatibility, ledger privacy, original-actor active-member authority, concurrency, exception/status restoration, response-loss replay, client lifetime and rollback |
| Ordered migration | `supabase/migrations/20260810160000_calendar_series_cancellation_undo.sql` moves the WP04-15 engine private, preserves its public wrapper, adds the immutable private ledger, widens aggregate/request/audit operation checks with `resumed` and adds the authenticated resume RPC |
| DB contract tests | `supabase/tests/database/calendar_series_cancellation_undo.test.sql` covers 58 signature, grant, privacy, actor, version, terminal-prefix, ended-series, moved-exception, scheduled/completed/skipped, participant, drift, worker, replay, collision and audit assertions |
| Legacy compatibility tests | `supabase/tests/database/calendar_series_cancel_from_occurrence.test.sql` retains all 48 WP04-15 assertions against the new wrapper |
| Contract skeletons | `docs/contracts/database-schema.sql.md` and `docs/contracts/rls-contract.sql.md` record the private ledger/engine and mediated resume surface without a public table grant |

The public resume response contains only household/series identifiers, the original server boundary, series version, restored/preserved aggregate counts, new revision identity/number and `changed`. No Edge Function, notification payload, public configuration key, dependency, native permission, RLS policy or public content column was added.

## Flutter implementation

| Area | Evidence |
|---|---|
| Domain and retry identity | `calendar_recurrence.dart` binds resume to the original cancellation command, boundary and exact cancellation-result version and produces a stable operation-specific fingerprint |
| Repository boundary | `calendar_repository.dart`, `calendar_data_source.dart`, `provider_calendar_repository.dart` and `unavailable_calendar_repository.dart` expose typed resume results and reject mismatched household/series/version, non-positive counts or invalid revision identity |
| Supabase adapter | `supabase_calendar_data_source.dart` sends the exact five resume inputs and strictly parses the exact nine-key response |
| Cache boundary | `today_cache_invalidating_calendar_repository.dart` forwards original cancellation identity/version and invalidates the Today Calendar snapshot only after successful resume |
| Controller state | `calendar_events_controller.dart` and `calendar_events_state.dart` create and expose the cancellation receipt, coalesce work, preserve the resume key on transient or success-reload failure and reconcile terminal outcomes |
| Runtime policy and UI | `calendar_providers.dart` applies the Calendar feature guard; `calendar_events_screen.dart` shows a persistent localized scrollable Snackbar Undo only for selected-boundary cancellation and reports success or retryable failure without raw provider details |

## Automated verification

| Gate | Result |
|---|---|
| Focused Calendar cancellation Undo pgTAP | **PASS — 58 tests** |
| Focused legacy selected-cancellation pgTAP | **PASS — 48 tests** |
| Clean local database reset | **PASS — all 61 ordered migrations applied from zero through `20260810160000`** |
| Full local database regression | **PASS — 62 files, 3,100 tests** |
| Local database lint | **PASS — 0 findings in `public,app_private` at warning level with warnings configured to fail** |
| Focused Flutter domain/parser/repository/cache/controller/widget/architecture suite | **PASS — 130 tests** |
| Full exact Flutter regression | **PASS — 1,351 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Localization generation | **PASS** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,922,003 bytes, SHA-256 `02434a3afb8fa8931804817bdc64ef7137e39713998bfdf65e3b0a9408be32ff`** |
| Documentation structure | **PASS — 412 Markdown files have balanced fences; 66 contract YAML files parse; 13 matrices are rectangular with exact declared counts, including API 53×6, requirements 125×18, tests 95×11 and time 45×12; MASTER embedded tests are 71×11** |
| Whitespace | **PASS — `git diff --check` and targeted new-file trailing-whitespace scan** |

The initial compact 200% widget run exposed a real reachability defect: the persistent Snackbar Undo action was below the 320×568 viewport. Constraining the Snackbar content to 45% of viewport height and making it scrollable kept the 48dp action reachable; the focused and full regressions then passed. A separate controller test also proves that a successful server resume followed by a transient page reload failure keeps the same receipt and command key for idempotent response-loss replay.

## Security, privacy and compatibility

- Authentication and active household membership are derived inside an empty-search-path security-definer function; possession of an original cancellation UUID is not authorization.
- The cancellation-result series version, exact terminal/ended shape and suffix occurrence post-state prevent last-write-wins restoration over newer work.
- The private ledger has no public, anon, authenticated or service-role grant and stores no Calendar content, wall time, timezone, participant identity, display identity or provider material.
- Content and participants are read only from the existing immutable source revision and participant snapshot while the transaction holds the authoritative series boundary.
- The legacy wrapper preserves the selected-cancellation public name, input order, exact eleven-key result, replay identity and behavior for N-1 clients.
- The client receipt is controller-memory only and is cleared by competing mutations, terminal failure, household/session transition or disposal; no offline mutation, outbox or persistent cache is added.

## Deferred manual validation and risks

- Hosted migration, grants, compatible cancellation wrapper and resume RPC with actual adult household accounts
- Two-device observation of cancellation/resume propagation, another-member denial, expected-version race and suffix/prefix drift
- Household timezone changes and selected recurrence slots around local midnight, DST gaps/folds and month boundaries
- Process death while the Snackbar is present and product research on whether persistent recent-cancellation history is valuable
- Android physical-device TalkBack, system font scaling, hardware keyboard, phone/tablet and split-screen behavior

The principal remaining product risk is whether users expect another member to undo someone else's cancellation or expect Undo to survive process death. This slice deliberately binds Undo to the original actor and current controller lifetime; actual household usability evidence remains deferred.

## Rollback

- Hide the Snackbar action and keep selected-boundary cancellation available.
- Revoke authenticated execute on the additive resume RPC in a forward migration. Keep the compatible cancellation wrapper and private WP04-15 engine.
- Keep the widened `resumed` constraints and immutable ledger/revision/request/event/audit history; do not narrow, delete or rewrite already recorded state.
- No cache row, analytics data, dependency, permission or configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_series_cancellation_undo.test.sql
npx supabase test db supabase/tests/database/calendar_series_cancel_from_occurrence.test.sql
npx supabase test db
npx supabase db lint --local --schema public,app_private --level warning --fail-on warning
flutter gen-l10n
flutter test --no-pub <focused Calendar Undo paths>
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/android-build.sh dev
Ruby YAML, Markdown and matrix structure checks
git diff --check
```
