# Phase 03 WP03-20 Chore Series Edit From Selected Occurrence Evidence

## Result

- Status: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — Phase 03, P1 activation and release completion are not claimed
- Requirements: `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-012`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-060` provisional
- Trace IDs: `API-047`, `T-CHORE-SERIES-FROM-HERE`, `TIME-039`
- Vertical slice: Upcoming selected occurrence → server-derived recurrence boundary → immutable series revision → later incomplete rebuild → authoritative current-query reconciliation
- Actual account, hosted Supabase, two-device, timezone-boundary and physical-device validation: not run by priority

## Acceptance results

| Criterion | Result |
|---|---|
| Exact action scope | PASS — only a manageable active scheduled repeating occurrence in the current Upcoming query exposes `이 회차부터 수정`; Today, completed, skipped, one-time and read-only cached rows fail closed before I/O |
| Server-owned boundary | PASS — the RPC locks the exact target and derives its immutable `recurrence_local_date`; no client date is accepted as mutation authority |
| Historical preservation | PASS — occurrences before the boundary and completed occurrences on or after it keep their original revision, content and completion actor |
| Future rebuild | PASS — later incomplete occurrences are rebuilt from the new immutable title, notes, assignee, local time and strict daily/weekly/monthly rule |
| Exception disclosure | PASS — the editor warns that later incomplete one-occurrence adjustments may reset to the new defaults before save |
| Optimistic and replay safety | PASS — exact series expected-version, same-command replay, different-input collision, target locking and retry-key rotation are enforced |
| Existing behavior compatibility | PASS — legacy today-boundary series editing keeps its public signature and behavior; one-occurrence exception, cancellation and canonical worker materialization remain compatible |
| Reconciliation | PASS — success, stale version and invalid transition reload the authoritative current Upcoming query; duplicate submission is coalesced |
| Localization and accessibility | PASS — EN/KO/EN-XA copy, compact 320×568 layout at 200%, scrollability and existing 48dp action contracts pass |

## Server contract and implementation

| Area | Evidence |
|---|---|
| Normative contract | `docs/contracts/chore-series-from-occurrence.yaml.md` defines authority, eligibility, preservation, reset, response, error and rollback boundaries |
| Additive migration | `supabase/migrations/20260810100000_chore_series_from_occurrence.sql` introduces a private shared boundary engine and authenticated-only `update_repeating_chore_series_from_occurrence` RPC |
| Compatibility wrapper | Existing `update_repeating_chore_series` calls the same private engine with its original today-boundary behavior and unchanged public signature |
| DB contract tests | `supabase/tests/database/chore_series_from_occurrence.test.sql` covers 36 schema, grant, authorization, target, preservation, rebuild, replay, collision, audit and legacy-compatibility assertions |
| Contract skeletons | `docs/contracts/database-schema.sql.md`, `docs/contracts/rls-contract.sql.md` and `docs/contracts/error-catalog.yaml.md` record the additive RPC and stable failures |

No table, column, RLS policy, persistent client cache slot, analytics event, dependency, native permission or public configuration key was added. The private helper has execute revoked from all client roles; only the additive public RPC is granted to `authenticated`.

## Flutter implementation

| Area | Evidence |
|---|---|
| Strict draft and retry fingerprint | `apps/kinflow_app/lib/features/chores/domain/entities/repeating_chore_series_change.dart` includes target occurrence, expected version and normalized full rule |
| Repository boundary | `apps/kinflow_app/lib/features/chores/domain/repositories/chore_repository.dart`, `data/datasources/chore_data_source.dart` and `data/repositories/provider_chore_repository.dart` expose one typed operation and reject malformed results |
| Supabase adapter | `apps/kinflow_app/lib/infrastructure/supabase/supabase_chore_data_source.dart` sends the exact RPC payload and parses the exact response |
| Cache boundary | `apps/kinflow_app/lib/infrastructure/cache/cached_chore_data_source.dart` forwards the mutation and invalidates affected Chore/Today reads without adding persistent data |
| Controller and policy | `apps/kinflow_app/lib/features/chores/application/today_chores_controller.dart` enforces view, status, capability and cache gates, while `presentation/providers/chore_providers.dart` applies the exact Chores runtime-policy guard before repository access |
| UI | `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart` reuses the recurrence editor with a selected-date minimum, disclosure and localized success/failure behavior |

## Automated verification

| Gate | Result |
|---|---|
| Focused selected-occurrence pgTAP | **PASS — 36 tests** |
| Clean local database reset | **PASS — all migrations applied from zero, including `20260810100000`** |
| Full local database regression | **PASS — 56 files, 2,822 tests** |
| Local database lint | **PASS — 0 schema errors at warning level** |
| Focused Flutter domain/repository/controller/widget/cache suite | **PASS — 152 tests** |
| Full exact Flutter regression | **PASS — 1,314 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 699 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Node contract regression | **PASS — 141 tests** |
| Workflow contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Android dev APK contract | **PASS — 219,851,088 bytes, SHA-256 `1cb3b1466dc7ab0e74deb3deb9f62a42495c084a056fb1e7bd643348d4647b67`** |
| Documentation structure | **PASS — selected-occurrence YAML parsed; 550 Markdown fences balanced; 13 matrices rectangular with exact declared counts, including API 47×6, requirements 119×18, tests 89×11 and time 39×12** |
| Whitespace | **PASS — `git diff --check`** |

The first full Flutter run found two stale test expectations introduced by the new surface: the architecture inventory still expected 16 Chore mutation guards instead of 17, and the new pseudo-locale disclosure did not reach the global 30% expansion pressure threshold. The inventory and pseudo copy were corrected; their focused tests and the second full 1,314-test regression passed. Product mutation behavior was unchanged by those corrections.

## Security, privacy and compatibility

- The client submits an occurrence UUID, never a trusted effective date. The server locks and validates that row against the active revision and household-local current date.
- Authentication, active membership and Owner/Admin series-management authority are derived in the database. Cross-household and unavailable targets share bounded typed failures without existence leakage.
- The security-definer functions use an empty search path and explicit schema qualification. Public execute is revoked before the exact authenticated grant.
- Audit data contains aggregate identifiers and version/boundary metadata only; title, notes, member display name and other household content are not copied into the event payload.
- Completed history and pre-boundary rows are never rewritten. Later incomplete exception reset is explicit product behavior and is disclosed before confirmation.
- Existing readers, worker materialization, legacy series edit, occurrence actions and cancellation continue to consume the same tables and immutable revision model.
- No new telemetry, persistent local storage, package, SDK, platform channel, permission, secret or provider connection was introduced.

## Deferred manual validation and risks

- Hosted migration, grants and RPC execution with actual adult Owner/Admin/Member accounts
- Two-device observation of boundary updates, completion preservation and concurrent expected-version conflict
- Household timezone changes and selected dates around local midnight, DST gaps/folds and month boundaries
- Android physical-device TalkBack, system font scaling, hardware keyboard, phone/tablet and split-screen behavior
- Product research for wording and user understanding when later incomplete one-occurrence adjustments reset
- Calendar `this and later` parity remains separate; selected-occurrence Chore cancellation is implemented in WP03-21

The principal remaining product risk is expectation mismatch around reset one-occurrence exceptions. This slice discloses the behavior and preserves every completed record, but it intentionally does not migrate arbitrary future exception overlays into the new series revision.

## Rollback

- Hide/remove the Upcoming action and Flutter adapter while leaving legacy today-boundary editing and one-occurrence actions available.
- Revoke authenticated execute on the additive RPC through a forward migration before replacing or dropping it; keep the private shared engine while the legacy wrapper depends on it.
- Already created immutable revisions and historical occurrences remain readable by existing clients and workers. Do not delete or rewrite completed history during rollback.
- No cache row, analytics data, dependency, permission or configuration cleanup is required.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/chore_series_from_occurrence.test.sql
npx supabase test db
npx supabase db lint --local --level warning
flutter gen-l10n
flutter test --no-pub <focused selected-occurrence paths>
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
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
