# Phase 03 WP03-21 Chore Series Cancellation From Selected Occurrence Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 03, P1 activation and release completion are not claimed
- Requirements: `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-013`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-061` provisional
- Trace IDs: `API-048`, `T-CHORE-SERIES-CANCEL-FROM-HERE`, `TIME-040`
- Vertical slice: Upcoming selected occurrence → server-derived recurrence boundary → later incomplete cancellation → bounded terminal prefix or immediate series end → authoritative current-query reconciliation
- Actual account, hosted Supabase, two-device, timezone-boundary and physical-device validation: intentionally not run by current priority

## Acceptance results

| Criterion | Result |
|---|---|
| Exact action scope | PASS — only a future manageable active scheduled repeating occurrence in the current Upcoming query exposes `이 회차부터 취소`; Today, completed, skipped, one-time, unauthorized and read-only cached rows fail closed before mutation I/O |
| Server-owned boundary | PASS — the RPC locks the exact active-revision target and derives its immutable `recurrence_local_date`; no client boundary date is accepted |
| Historical preservation | PASS — every earlier occurrence and every completed occurrence at or after the boundary keeps its status, historical revision and completion data |
| Selected-and-later cancellation | PASS — scheduled and skipped incomplete rows at or after the boundary are cancelled across historical revisions |
| Scheduled prefix | PASS — when an earlier scheduled row remains, the latest surviving source revision content, assignee, time and recurrence anchor are cloned into an immutable bounded terminal revision |
| Immediate end | PASS — when no earlier scheduled prefix remains, the series uses the existing soft-delete behavior and returns a null terminal revision pair |
| Worker termination | PASS — never/until sources end before the boundary, count sources are capped to existing prefix slots, materialization coverage resets and canonical worker replay creates nothing after the boundary |
| Optimistic and replay safety | PASS — exact series expected-version, target lock, same-command replay, cross-operation or different-input collision and retry-key target rotation are enforced |
| Existing behavior compatibility | PASS — legacy whole-series cancellation and both series-edit RPC signatures retain their behavior; table, column and RLS grants are unchanged |
| Reconciliation | PASS — success, stale version, invalid transition and unavailable target reload the authoritative current Upcoming query; duplicate submission is coalesced |
| Localization and accessibility | PASS — distinct EN/KO/EN-XA copy, compact 320×568 layout at 200%, scrolling and destructive styling pass |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/chore-series-cancel-from-occurrence.yaml.md` defines authority, eligibility, preservation, terminal prefix, response, recovery and rollback boundaries |
| Ordered migration | `supabase/migrations/20260810110000_chore_series_cancel_from_occurrence.sql` adds authenticated-only `cancel_repeating_chore_series_from_occurrence` and widens existing cancellation audit/replay revision checks for an optional terminal revision |
| DB contract tests | `supabase/tests/database/chore_series_cancel_from_occurrence.test.sql` covers 46 schema, grant, role, target, preservation, never/until/count bound, worker, replay, collision, audit and legacy compatibility assertions |
| Contract skeletons | `docs/contracts/database-schema.sql.md`, `docs/contracts/rls-contract.sql.md` and `docs/contracts/error-catalog.yaml.md` record the additive RPC, constraint shape and stable failures |

No table, column, RLS policy, client cache slot, analytics event, dependency, native permission or public configuration key was added. The response exposes only household/series identity, server boundary, version, aggregate counts, changed state and an optional terminal revision identity/number pair.

## Flutter implementation

| Area | Evidence |
|---|---|
| Draft and retry identity | `apps/kinflow_app/lib/features/chores/domain/entities/repeating_chore_series_change.dart` binds operation, household, series, target occurrence and expected version without a client date |
| Repository boundary | `apps/kinflow_app/lib/features/chores/domain/repositories/chore_repository.dart`, `data/datasources/chore_data_source.dart` and `data/repositories/provider_chore_repository.dart` expose one typed operation and reject malformed terminal pairs or counts |
| Supabase adapter | `apps/kinflow_app/lib/infrastructure/supabase/supabase_chore_data_source.dart` sends the exact five RPC inputs and parses the exact nine-key result |
| Cache boundary | `apps/kinflow_app/lib/infrastructure/cache/cached_chore_data_source.dart` forwards the target and invalidates Chore/Today reads only after a successful mutation |
| Controller and policy | `apps/kinflow_app/lib/features/chores/application/today_chores_controller.dart` enforces Upcoming, future date, scheduled state, capability and online-cache gates; `presentation/providers/chore_providers.dart` applies the Chores runtime-policy guard before I/O |
| UI | `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart` adds a separate destructive action, confirmation and success check while leaving whole cancellation available |

## Automated verification

| Gate | Result |
|---|---|
| Focused selected-occurrence cancellation pgTAP | **PASS — 46 tests** |
| Clean local database reset | **PASS — all ordered migrations applied from zero through `20260810110000`** |
| Full local database regression | **PASS — 57 files, 2,868 tests** |
| Local database lint | **PASS — 0 schema errors at warning level** |
| Focused Flutter domain/repository/parser/controller/cache/widget/architecture suite | **PASS — 201 tests** |
| Full exact Flutter regression | **PASS — 1,325 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,865,056 bytes, SHA-256 `8c25d63e91c00a7ebb367e3956b23cc23fff001cd239a8f093bfe73e996cd638`** |
| Documentation structure | **PASS — selected-cancellation YAML parsed; 554 Markdown fences balanced; 13 matrices rectangular with exact declared counts, including API 48×6, requirements 120×18, tests 90×11 and time 40×12** |
| Whitespace | **PASS — `git diff --check`** |

The first combined focused test run exposed one fixture mistake: a future occurrence is correctly filtered out of the Today query before the controller can reject the action. The test was corrected to use an actual Today occurrence for the non-Upcoming gate. No product implementation changed for that correction, and the final 201-test focused suite plus the 1,325-test full regression passed.

## Security, privacy and compatibility

- The client submits only the occurrence UUID and expected series version. PostgreSQL derives the boundary from the locked immutable recurrence slot and the household-local current date.
- Authentication, active membership and Owner/Admin authority are derived in the empty-search-path security-definer function. Cross-household and unavailable targets use the same bounded denial.
- The audit and replay rows contain aggregate identifiers, boundary, versions and counts only. Title, notes, display name, email, auth subject, target occurrence identity and per-row payload are not copied into audit metadata.
- The terminal revision necessarily contains the existing series content required for recurrence execution; it is not a new content surface and remains protected by existing RLS.
- Existing readers and the canonical worker continue to consume the immutable revision model. Existing whole cancellation and series editing signatures are unchanged.
- No new telemetry, persistent local storage, SDK, package, platform channel, permission, secret or provider connection was introduced.

## Deferred manual validation and risks

- Hosted migration, grant and RPC execution with actual adult Owner/Admin/Member accounts
- Two-device observation of prefix retention, selected-and-later removal, completion preservation and expected-version conflict
- Household timezone changes and selected recurrence slots around local midnight, DST gaps/folds and month boundaries
- Android physical-device TalkBack, system font scaling, hardware keyboard, phone/tablet and split-screen behavior
- Product research for the distinction between whole-series cancellation and scheduled cancellation from a selected occurrence
- Persistent or arbitrary historical resume and Calendar `this and later` parity; immediate process-memory Undo is implemented separately by WP03-22

The principal remaining product risk is user expectation around a scheduled series end. WP03-21 itself remains cancellation-only; its additive WP03-22 successor provides immediate process-memory Undo without changing this RPC's signature or result.

## Rollback

- Hide/remove the Upcoming selected-cancellation action and Flutter adapter while leaving legacy whole cancellation and both edit paths available.
- Revoke authenticated execute on the additive RPC in a forward migration. Keep the widened compatible cancellation checks while any immutable terminal revision is referenced by audit or replay history.
- Existing bounded terminal revisions remain valid recurrence history and can continue through the canonical worker. Do not delete or rewrite completed history.
- No cache row, analytics data, dependency, permission or configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/chore_series_cancel_from_occurrence.test.sql
npx supabase test db
npx supabase db lint --local --level warning
flutter gen-l10n
flutter test --no-pub <focused selected-occurrence cancellation paths>
flutter test --no-pub --reporter failures-only
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
