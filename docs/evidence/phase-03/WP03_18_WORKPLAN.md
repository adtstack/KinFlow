# Phase 03 WP03-18 Household Weekly Report Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Phase: 03 only
- Vertical slice: active household → server-derived closed week aggregate → provider-neutral client → Today summary → detailed week navigation
- Release boundary: P1 local automated implementation; production activation and live validation are not claimed

## Requirements and decisions

- Requirements: FR-CHORE-011, FR-TODAY-005, NFR-SEC-01, NFR-PRIV-01, NFR-PERF-01, NFR-A11Y-01, NFR-I18N-01
- Decisions: D-002, D-006, D-013, D-017, D-019, D-036, D-043, D-047, D-049, D-057
- Contract: `docs/contracts/household-weekly-report.yaml.md`
- New test ID: T-WEEKLY-REPORT

## Product and domain boundary

1. offset 0 is the latest fully closed household-local ISO Monday..Sunday week; offsets 1..11 navigate older closed weeks.
2. scheduled plus completed rows are due work; skipped is shown separately and cancelled is excluded.
3. completed rows are divided at the selected week's exclusive end instant into completed-by-week-end and completed-later.
4. the response contains only aggregate counts and up to 20 current active member contribution rows. Removed/deleted/overflow contributors are a count-only `other` bucket.
5. the domain rejects mismatched household, invalid dates/timezone/timestamps, duplicate member rows, inconsistent sums, out-of-range counts or malformed member names.
6. the report is a nonblocking read source. It is not derived from the encrypted Today cache and is not persisted locally.

## DB and API implementation

- Add `public.get_household_weekly_report(uuid, integer)` as a stable security-definer function with empty search path and authenticated-only execute.
- Derive caller, current household timezone, latest closed ISO week and exclusive end from server state.
- Scan only the selected seven `due_local_date` values using a bounded household/date/status index.
- Return exactly one row, including an exact-key JSON member array; never return Chore content or occurrence identity.
- Reject unauthenticated, null/out-of-range input, deleted household, removed caller and cross-household access before aggregate read.
- Add pgTAP coverage for grants/search path, boundary derivation, empty and mixed status sums, week-end classification, member privacy, offset bounds and authorization.

## Flutter implementation

- Add platform-free immutable report/member entities and repository result contract.
- Add strict Supabase payload parsing, DTO-to-domain revalidation and stable failure mapping.
- Delegate report reads through the network data source even when Today persistent read cache is composed.
- Add latest-request-wins controller/state and Riverpod composition for the latest report card.
- Add a source-isolated detail sheet with offsets 0..11, retry and navigation.
- Add EN/KO/EN-XA copy, semantic heading/live status and compact 200% text tests.
- Refresh the latest report after authoritative Today completion/reopen without blocking the mutation result.

## Security, privacy and performance

- active membership and week boundary are server-authoritative; no client row or cached capability grants access.
- no title, description, occurrence/series/command/auth-user ID, email, token, timestamp-level activity or raw provider error reaches the response, log or analytics.
- no new SDK, runtime dependency, native permission, secret or local storage namespace.
- query scope is exactly one household, one seven-day date range and at most 20 named rows.

## Automated verification

- focused pgTAP weekly report contract and full database regression
- Dart domain invalid/valid invariant matrix
- strict data-source parser and provider repository mapping
- controller scope/concurrency/navigation/failure tests
- Today card and detail loading/empty/mixed/member/other/retry/navigation tests
- EN/KO/EN-XA and compact 320x568 200% regression
- full Flutter tests, analyzer, format, localization/codegen, public config, Node contracts, docs parse, secret and whitespace gates

## Manual and deferred verification

- hosted production-size `EXPLAIN (ANALYZE, BUFFERS)` and latency
- actual account membership removal, account deletion tombstone and two-device refresh
- household timezone change near ISO week boundary
- TalkBack, real font scaling, phone/tablet/split-screen and physical device
- product review for P1 activation, tone and whether member contribution rows should remain enabled

## Stop conditions and rollback

- stop if another household or removed identity is disclosed, a caller controls the date boundary, aggregate equations diverge, Today becomes blocked, or report data enters persistent cache/telemetry.
- client rollback hides the report surfaces; server rollback first revokes execute and then uses a forward migration. No report data exists to migrate or delete.
