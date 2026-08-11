# Phase 04 WP04-15 Calendar Series Cancellation From Selected Occurrence Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 04, P1 activation and release completion are not claimed
- Requirements: `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-011`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-063` provisional
- Trace IDs: `API-050`, `T-CALENDAR-SERIES-CANCEL-FROM-HERE`, `TIME-042`
- Vertical slice: selected recurring Calendar occurrence → server-derived immutable recurrence boundary → later occurrence cancellation including moved exceptions → bounded terminal prefix or boundary end → authoritative Calendar reconciliation
- Actual account, hosted Supabase, two-device, timezone-boundary, DST and physical-device validation: intentionally not run by current priority

## Acceptance results

| Criterion | Result |
|---|---|
| Exact action scope | PASS — only a current-page scheduled recurring non-exception occurrence whose immutable slot is on or after the page household-local date exposes `이 회차부터 취소`; exception and past targets hide or reject the action |
| Server-owned boundary | PASS — the RPC locks the exact active-revision target and derives its immutable `recurrence_local_start_date`; no client boundary date is accepted |
| Prefix preservation | PASS — every earlier occurrence and explicit exception keeps its recurrence identity, content, time, participants, status and historical versions; an earlier exception remains even when moved to a displayed date after the selected boundary |
| Selected-and-later cancellation | PASS — every non-cancelled occurrence whose immutable recurrence slot is at or after the boundary is cancelled, including an explicit exception moved to another displayed date |
| Terminal prefix | PASS — when an actionable scheduled non-exception prefix remains, the server clones its source snapshot and participants into an immutable `until = boundary - 1` revision, activates it, repoints only matching actionable source rows and marks terminal materialization complete |
| No-prefix ending | PASS — when no actionable non-exception prefix remains, the series receives `ended_at` plus the selected effective local date and its materialization state is removed |
| Worker safety | PASS — targeted canonical worker execution does not regenerate a selected-or-later occurrence after either terminal path |
| Optimistic and replay safety | PASS — exact series expected-version, target row lock, same-command replay, cross-operation/different-input collision and retry-key target rotation are enforced |
| Existing behavior compatibility | PASS — legacy today-boundary `cancel_recurring_calendar_series` retains its exact signature, normalized request hash and nine-key result; whole/selected series edit and one-occurrence update/cancel remain compatible |
| Reconciliation and cache | PASS — success, stale version, invalid transition and unavailable target converge through authoritative Calendar reload; successful mutation invalidates the Today Calendar snapshot |
| Localization and accessibility | PASS — distinct EN/KO/EN-XA action/title/disclosure, a scrollable 320×568 layout at 200%, 48dp confirmation and exact selected-target forwarding pass without overflow |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/calendar-series-cancel-from-occurrence.yaml.md` defines authority, target eligibility, immutable-slot exception semantics, terminal revision, response, recovery, privacy and rollback boundaries |
| Ordered migration | `supabase/migrations/20260810130000_calendar_series_cancel_from_occurrence.sql` adds authenticated-only `cancel_recurring_calendar_series_from_occurrence`, a private shared cancellation engine, compatible optional-terminal replay/event shapes and an exact legacy wrapper |
| DB contract tests | `supabase/tests/database/calendar_series_cancel_from_occurrence.test.sql` covers 48 schema, grant, auth, target, boundary, prefix/exception preservation, suffix cancellation, terminal snapshot/participants, worker, no-prefix end, replay, collision, audit/state and legacy compatibility assertions |
| Contract skeletons | `docs/contracts/database-schema.sql.md` and `docs/contracts/rls-contract.sql.md` record the additive RPC, private-engine boundary, optional terminal pair and exact authenticated grant |

No table, column, index, RLS policy, client cache slot, analytics event, dependency, native permission or public configuration key was added. The existing cancellation event and replay constraints were widened only from an all-null revision/materialization result to either that legacy shape or a complete terminal revision/materialized-through pair.

## Flutter implementation

| Area | Evidence |
|---|---|
| Draft and retry identity | `calendar_recurrence.dart` validates household, series, target, immutable slot and future boundary and binds operation, occurrence, slot and expected version into one retry fingerprint |
| Repository boundary | `calendar_repository.dart`, `calendar_data_source.dart`, `provider_calendar_repository.dart` and unavailable/cache decorators expose one typed operation with an exact eleven-key response and all-null-or-complete terminal pair |
| Supabase adapter | `supabase_calendar_data_source.dart` sends `p_effective_occurrence_id` and deliberately sends no effective date; widened or malformed responses fail closed |
| Controller and policy | `calendar_events_controller.dart` revalidates the exact page occurrence, series/revision/version, scheduled recurring non-exception state and future slot and runs the Calendar runtime-policy guard before command or repository I/O |
| UI | `calendar_events_screen.dart` adds a distinct destructive action and confirmation that later exceptions are cancelled while earlier recurrence slots remain even when moved after the boundary |
| Cache and recovery | `today_cache_invalidating_calendar_repository.dart` removes the Today Calendar snapshot on success; controller success/conflict/unavailable paths reload the authoritative page |
| Localization | EN/KO/EN-XA ARB and generated localization files contain the selected action, title, disclosure and confirmation copy |

## Automated verification

| Gate | Result |
|---|---|
| Focused selected-occurrence pgTAP | **PASS — 48 tests** |
| Clean local database reset | **PASS — all ordered migrations applied from zero through `20260810130000`** |
| Full local database regression | **PASS — 59 files, 2,951 tests** |
| Local database lint | **PASS — 0 schema errors at warning level** |
| Focused Flutter domain/repository/controller/cache/widget/adapter/architecture suite | **PASS — 124 tests** |
| Full exact Flutter regression | **PASS — 1,336 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Localization generation and generated-code drift | **PASS — l10n current; 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,887,063 bytes, SHA-256 `e9ac645f2de0665510c0167a6ee00685a6891b10db9fc078d17114b55a4d6843`** |
| Documentation structure | **PASS — selected-cancellation YAML has 15 root keys; 403 Markdown files have balanced fences; 63 contract YAML files parse; 13 matrices are rectangular with exact declared counts, including API 50×6, requirements 122×18, tests 92×11 and time 42×12; MASTER embedded tests are 69×11** |
| Whitespace | **PASS — `git diff --check` and new-file trailing-whitespace scan** |

The first full Flutter run correctly failed because the new EN-XA cancellation body expanded the English source by slightly less than the required 30%. The pseudo-localized copy was lengthened, localization was regenerated, and the full 1,336-test regression then passed. The first Android script invocation inherited a different PATH-level Flutter and exited at its exact-version guard; rerunning with the pinned 3.44.7 binary completed the build and artifact contract.

## Security, privacy and compatibility

- The client submits the occurrence UUID and expected series version; PostgreSQL derives the boundary from the locked immutable recurrence slot and current household-local date.
- Authentication and active household membership are derived inside empty-search-path security-definer functions. Missing, ended, deleted, old-revision, exception and cross-household targets share one bounded unavailable failure.
- The selected occurrence identity is bound into the irreversible request hash and existing private audit row but is not added as a replay-state column, content payload, analytics event or client cache key.
- Existing event title, description and participants are copied only when required for the immutable terminal revision and remain protected by existing RLS; no new content-bearing surface is introduced.
- The legacy wrapper constructs its previous command name and exact normalized hash and projects the original nine response keys, protecting in-flight N-1 retries.
- No new SDK, package, persistent local storage, platform channel, permission, provider connection or external telemetry was introduced.

## Deferred manual validation and risks

- Hosted migration, grants, constraint replacement and both cancellation RPC paths with actual adult household accounts
- Two-device observation of prefix retention, later moved-exception cancellation, terminal revision propagation and expected-version conflict
- Household timezone changes and selected recurrence slots around local midnight, DST gaps/folds and month boundaries
- Android physical-device TalkBack, system font scaling, hardware keyboard, phone/tablet and split-screen behavior
- Product research for the distinction among one-occurrence cancel, immediate whole-series end and selected-boundary cancellation
- Immediate process-memory Undo is implemented by WP04-16; persistent history, arbitrary historical resume and arbitrary end-date scheduling remain deferred

The principal remaining product risk is whether users understand that recurrence identity, not the currently displayed moved date, determines which exceptions cancel. The destructive confirmation states both sides of that rule, but actual household usability evidence remains deferred.

## Rollback

- Hide/remove the selected-boundary Calendar cancellation action and Flutter adapter while leaving legacy whole-series and one-occurrence operations available.
- Revoke authenticated execute on the additive RPC in a forward migration. Keep the private shared engine while the legacy wrapper depends on it, or restore the previous legacy body in a forward migration.
- Keep the widened compatible cancellation constraints while immutable terminal revisions or replay rows exist; do not narrow them destructively.
- Existing immutable terminal revisions, occurrence cancellation history, replay state and append-only audit remain valid and must not be deleted or rewritten.
- No cache row, analytics data, dependency, permission or configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_series_cancel_from_occurrence.test.sql
npx supabase test db
npx supabase db lint --local --level warning
flutter gen-l10n
flutter test --no-pub <focused selected-occurrence Calendar paths>
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> scripts/ci/android-build.sh dev
Ruby/Python YAML, Markdown and matrix structure checks
git diff --check
```
