# Phase 03 WP03-18 Household Weekly Report Evidence

## Result

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Scope: active adult household → server-derived latest closed ISO week → content-free aggregate → nonblocking Today summary → isolated 12-week detail navigation
- Requirements: FR-CHORE-011, FR-TODAY-005, NFR-SEC-01, NFR-PRIV-01, NFR-PERF-01, NFR-A11Y-01, NFR-I18N-01
- Trace IDs: API-046, T-WEEKLY-REPORT
- Remote Supabase, production-size query plan, real-account, two-device, timezone-boundary and physical-device verification remain deferred to the final/P1 Gate by user direction.

## Delivered behavior

- Offset 0 is the latest fully closed household-local ISO Monday-to-Sunday week; offsets 1 through 11 expose older closed weeks.
- `scheduled + completed` is the due total, completed rows are classified by the household-local week-end instant, skipped is separate and cancelled is excluded.
- The response has exact aggregate fields and at most 20 current active contributor rows ordered by case-folded display name and member UUID.
- Removed, deleted and overflow contributors are combined into a count-only `other` bucket. No former identity, chore content, occurrence identity, auth identity or per-action timestamp is returned.
- Today loads the latest report independently, hides only the report card on report-source failure and keeps every existing Chore/Calendar surface available.
- The detail sheet owns its controller, retry and offset navigation so historical browsing never replaces the latest Today card.
- Authoritative completion and reopen force a fresh offset-0 request after mutation reconciliation; duplicate navigation remains coalesced and older responses cannot replace newer state.
- The report uses process memory only. The existing persistent Chore cache delegates this read directly and creates no report slot or offline fallback.

## Server and privacy evidence

| Area | Evidence |
|---|---|
| Additive migration | `supabase/migrations/20260809170000_household_weekly_report.sql` adds the bounded partial covering index and authenticated-only empty-search-path RPC |
| DB contract tests | `supabase/tests/database/household_weekly_report.test.sql` covers 53 schema, grant, input, authorization, boundary, aggregate, cap and privacy assertions |
| Normative contract | `docs/contracts/household-weekly-report.yaml.md` defines authority, exact response, invariants, cache/analytics prohibition and rollback |
| Schema/RLS skeletons | `docs/contracts/database-schema.sql.md` and `docs/contracts/rls-contract.sql.md` record the bounded index and exact execute grant |

The local database was advanced with the additive migration and tested without a destructive reset so existing workspace data was preserved. A clean-from-zero migration rehearsal and hosted plan/latency evidence are not claimed by this work package.

## Flutter evidence

| Area | Evidence |
|---|---|
| Domain and repository | `apps/kinflow_app/lib/features/chores/domain/entities/household_weekly_report.dart` and `domain/repositories/chore_repository.dart` enforce offsets, dates, sums, contributor identity and result boundaries |
| Strict provider mapping | `apps/kinflow_app/lib/infrastructure/supabase/supabase_chore_data_source.dart` and `data/repositories/provider_chore_repository.dart` reject non-exact or inconsistent rows |
| No persistent report cache | `apps/kinflow_app/lib/infrastructure/cache/cached_chore_data_source.dart` delegates the report source directly |
| Concurrency state | `apps/kinflow_app/lib/features/chores/application/household_weekly_report_controller.dart` provides duplicate coalescing, forced authoritative refresh and latest-request-wins |
| Today and detail UI | `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart` plus the two `household_weekly_report_*` widgets provide nonblocking summary and isolated navigation |
| Localization | `apps/kinflow_app/lib/l10n/app_en.arb`, `app_ko.arb` and `app_en_XA.arb` provide generated localized copy |

## Automated verification

| Gate | Result |
|---|---|
| Focused weekly-report pgTAP | **PASS — 53 tests** |
| Full local database regression | **PASS — 55 files, 2,786 tests** |
| Focused Flutter domain/controller/widget/repository/cache/parser suite | **PASS — 68 tests** |
| Today/Chore widget impact suite | **PASS — 43 tests** |
| Full exact Flutter regression | **PASS — 1,274 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 685 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Documentation structure | **PASS — weekly YAML parsed; 386 Markdown fences balanced; 13 matrices rectangular including API 46×6, requirements 117×18 and tests 86×11** |

## Security and compatibility

- Authentication and active membership are derived inside the RPC on every call; the client cannot select a date boundary or contributor identity.
- The SQL function uses an empty search path, authenticated-only execute and a generic unavailable/forbidden boundary.
- Exact Flutter parsing rejects unknown keys, type widening, mismatched household/offset, invalid UTC/date data, duplicate or unordered members and divergent totals.
- No SDK, runtime package, platform permission, native configuration, telemetry event or persistent storage namespace was added.
- Existing Today loading, partial failure, saved read-only data, completion outbox and mutation behavior remain independent.

## Deferred manual verification

- Hosted `EXPLAIN (ANALYZE, BUFFERS)` with production-size occurrence/member distributions
- Actual removed/deleted member histories and active-member overflow using real adult accounts
- Two-device completion/reopen propagation and simultaneous historical navigation
- Household timezone change near Monday and DST week boundaries
- TalkBack, real font scaling, phone/tablet/split-screen and physical Android devices
- Product decision to activate the P1 card and retain or remove named contribution rows

## Rollback

- Hide the Today card and detail entry while leaving core Today and Chore paths unchanged.
- Revoke authenticated execute before replacing or removing the RPC through a forward migration.
- No report rows, client cache or analytics data require migration or deletion.

## Commands

```text
supabase migration up --local
supabase test db --local supabase/tests/database/household_weekly_report.test.sql
supabase test db --local supabase/tests/database
flutter test --no-pub <weekly focused paths>
flutter test --no-pub test/features/chores/one_time_chore_widget_test.dart
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
git diff --check
```
