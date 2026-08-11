# Phase 04 WP04-14 Calendar Series Edit From Selected Occurrence Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 04, P1 activation and release completion are not claimed
- Requirements: `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-010`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-062` provisional
- Trace IDs: `API-049`, `T-CALENDAR-SERIES-FROM-HERE`, `TIME-041`
- Vertical slice: selected recurring Calendar occurrence → server-derived immutable recurrence boundary → later non-exception source rebuild with explicit-exception preservation → authoritative Calendar reconciliation
- Actual account, hosted Supabase, two-device, timezone-boundary, DST and physical-device validation: intentionally not run by current priority

## Acceptance results

| Criterion | Result |
|---|---|
| Exact action scope | PASS — only a current-page scheduled recurring non-exception occurrence whose immutable slot is on or after the page household-local date exposes `이 회차부터 수정`; a one-occurrence exception and a past boundary hide or reject the action |
| Server-owned boundary | PASS — the RPC locks the exact active-revision target and derives its immutable `recurrence_local_start_date`; no client boundary date is accepted |
| Historical preservation | PASS — every occurrence before the boundary keeps its identity, revision, time, content and version |
| Explicit exception preservation | PASS — a moved later one-occurrence exception keeps its exception revision, date/time, title, participants, status and versions exactly |
| Selected-and-later rebuild | PASS — the selected matching source row retains identity and adopts the new revision; obsolete non-exception rows cancel and canonical matching rows materialize from the selected boundary |
| Full recurring draft | PASS — timed/all-day shape, title/description, active participants and strict daily/weekly/monthly interval/end rules use the existing validators; new anchor and until cannot precede the selected slot |
| Optimistic and replay safety | PASS — exact series expected-version, target row lock, same-command replay, cross-operation/different-input collision and retry-key target rotation are enforced |
| Existing behavior compatibility | PASS — legacy today-boundary `update_recurring_calendar_series` retains its exact signature, request hash, result and behavior; one-occurrence update/cancel, whole cancellation, table schema and RLS policies remain compatible |
| Reconciliation and cache | PASS — success, stale version, invalid transition and unavailable target converge through authoritative Calendar reload; successful mutation invalidates the Today Calendar snapshot |
| Localization and accessibility | PASS — distinct EN/KO/EN-XA action/title/disclosure, scrollable 320×568 layout at 200% and a hit-testable selected action pass without overflow |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/calendar-series-from-occurrence.yaml.md` defines authority, eligibility, preservation, response, recovery, privacy and rollback boundaries |
| Ordered migration | `supabase/migrations/20260810120000_calendar_series_from_occurrence.sql` adds authenticated-only `update_recurring_calendar_series_from_occurrence`, moves common behavior to a private boundary engine and keeps the legacy wrapper exact |
| DB contract tests | `supabase/tests/database/calendar_series_from_occurrence.test.sql` covers 35 schema, grant, auth, target, boundary, prefix, exception, projection, replay, collision, audit/state, invalid input and legacy compatibility assertions |
| Contract skeletons | `docs/contracts/database-schema.sql.md` and `docs/contracts/rls-contract.sql.md` record the additive RPC, private-engine boundary and exact authenticated grant |

No table, column, index, constraint, RLS policy, client cache slot, analytics event, dependency, native permission or public configuration key was added. Private replay state retains its existing shape and stores only the irreversible full request hash, revision identity, effective boundary, versions and aggregate result.

## Flutter implementation

| Area | Evidence |
|---|---|
| Draft and retry identity | `calendar_recurrence.dart` validates household/series/target/future boundary and binds operation, occurrence, immutable slot, expected version and full recurring draft into one fingerprint |
| Repository boundary | `calendar_repository.dart`, `calendar_data_source.dart`, `provider_calendar_repository.dart` and unavailable/cache decorators expose one typed operation and strict result mapping |
| Supabase adapter | `supabase_calendar_data_source.dart` sends the exact additive RPC fields including `p_effective_occurrence_id` and deliberately sends no effective date |
| Controller and policy | `calendar_events_controller.dart` revalidates exact page occurrence, series/revision/version/non-exception/future state and uses the Calendar runtime-policy guard before command or repository I/O |
| UI | `calendar_events_screen.dart` adds the distinct action, boundary-prefilled/minimum-date editor, boundary overlap window, all-day span preservation and authoritative save routing |
| Localization | EN/KO/EN-XA ARB and generated localization files contain the selected action, title and preservation disclosure |

## Automated verification

| Gate | Result |
|---|---|
| Focused selected-occurrence pgTAP | **PASS — 35 tests** |
| Clean local database reset | **PASS — all ordered migrations applied from zero through `20260810120000`** |
| Full local database regression | **PASS — 58 files, 2,903 tests** |
| Local database lint | **PASS — 0 schema errors at warning level** |
| Focused Flutter domain/repository/controller/cache/widget/adapter/architecture suite | **PASS — 118 tests** |
| Final Calendar widget suite | **PASS — 24 tests, including selected EN-XA compact 200% flow** |
| Final Calendar controller suite | **PASS — 31 tests** |
| Full exact Flutter regression | **PASS — 1,330 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Localization generation and generated-code drift | **PASS — l10n current; 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,872,142 bytes, SHA-256 `008c944220602137c8e58af8a55801f265397f616d20bcbdb9f5e4917d200409`** |
| Documentation structure | **PASS — selected-boundary YAML has 15 root keys; 400 Markdown files have balanced fences; 13 matrices are rectangular with exact declared counts, including API 49×6, requirements 121×18, tests 91×11 and time 41×12; MASTER embedded tests are 68×11** |
| Whitespace | **PASS — `git diff --check`** |

The first focused controller expectation treated a locally rejected past target as a normal action failure. The controller correctly used its existing conflict-recovery path and performed no mutation I/O, so the fixture was corrected to assert `latestReloaded`; product behavior did not change. The compact widget hardening now positions the actual Calendar scrollable relative to the selected menu before tapping, proving the long pseudo-localized action remains reachable and hit-testable at 200%.

## Security, privacy and compatibility

- The client submits the occurrence UUID and expected series version; PostgreSQL derives the boundary from the locked immutable recurrence slot and current household-local date.
- Authentication and active household membership are derived inside empty-search-path security-definer functions. Missing, ended, deleted, old-revision, exception and cross-household targets use the same bounded unavailable failure.
- The selected occurrence identity is included in the irreversible request hash for collision safety but is not added as a replay-state column or audit payload field.
- Existing event title, description and participant content necessarily live in immutable revisions under existing RLS; this work adds no new content copy, log, analytics or cache surface.
- The legacy wrapper builds its previous command name and exact normalized hash when no target is supplied, protecting in-flight N-1 retries.
- No new SDK, package, persistent local storage, platform channel, permission, provider connection or external telemetry was introduced.

## Deferred manual validation and risks

- Hosted migration, grant and RPC execution with actual adult household accounts
- Two-device observation of previous occurrence retention, selected-and-later rebuild, explicit exception preservation and expected-version conflict
- Household timezone changes and selected recurrence slots around local midnight, DST gaps/folds and month boundaries
- Android physical-device TalkBack, system font scaling, hardware keyboard, phone/tablet and split-screen behavior
- Product research for the distinction among one-occurrence edit, today-boundary whole-series edit and selected-boundary edit
- Calendar selected-occurrence cancellation is implemented by WP04-15 and immediate process-memory Undo by WP04-16; persistent history and arbitrary historical resume remain deferred

The principal remaining product risk is user expectation when an existing one-occurrence exception sits after the selected boundary. This slice preserves it and states that behavior before save, but actual household usability evidence remains deferred.

## Rollback

- Hide/remove the selected-boundary Calendar action and Flutter adapter while leaving legacy whole-series and one-occurrence operations available.
- Revoke authenticated execute on the additive RPC in a forward migration. Keep the private shared engine while the legacy wrapper depends on it, or restore the previous legacy body in a forward migration.
- Existing immutable revisions and occurrence history remain valid for current readers and the canonical horizon worker; do not delete or rewrite them.
- No cache row, analytics data, dependency, permission or configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_series_from_occurrence.test.sql
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
scripts/ci/android-build.sh dev
ruby YAML/Markdown/matrix structure checks
git diff --check
```
