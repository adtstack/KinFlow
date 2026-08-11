# Phase 03 WP03-17 Guided Advanced Recurrence Evidence

## Result

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Scope: first-household exact-three guided chore setup → full supported recurrence editing → frozen secure resume → existing recurring-create path
- Requirements: FR-CHORE-005, FR-CHORE-010, NFR-REL-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01
- Test IDs: T-CHORE-RECURRENCE-EDITOR, T-CHORE-WEEKDAYS, T-CHORE-MONTH-DAY, T-GUIDED-RESUME, T-I18N-01, T-A11Y-03
- Remote Supabase, real-account, multi-device and physical-device verification remains deferred to the final integration Gate by user direction.

## Delivered behavior

- Each of the exact three guided entries can edit daily, weekly or monthly recurrence, interval `1..30`, and `never`, count `1..1000` or household-local until end conditions.
- Weekly editing requires the frozen start weekday and permits additional unique weekdays serialized in canonical ISO Monday-to-Sunday order.
- Monthly editing keeps the frozen start-date day locked and preserves the existing missing-date skip-not-clamp semantics.
- The exact full `ChoreRecurrenceRule` now reaches the draft fingerprint, recurring create request, partial-failure retry and process-recreated frozen batch without frequency-only widening.
- Submission still freezes all three drafts, coalesces duplicate submit, checkpoints before each next mutation and reuses the same command IDs for identical retry payloads.
- No unsubmitted editing draft is persisted.

## Secure resume v2

- The submitted-batch key is `kinflow.guided_chore_setup.resume.v2` with contract version `2`.
- Every entry uses exact keys `templateKey`, `title`, `recurrenceRule` and `commandId`; recurrence JSON is rebuilt through the strict domain parser.
- Scope remains exact environment, household and adult member, with the existing 8 KiB UTF-8 bound and fail-closed corrupt/scope cleanup.
- Noncanonical weekly ordering, widened recurrence JSON and unknown versions are rejected and purged.
- Legacy v1 data is never replayed because it cannot prove full-rule fidelity; read and clear paths delete it.

## Implementation evidence

| Area | Evidence |
|---|---|
| Domain draft and fingerprint | `apps/kinflow_app/lib/features/chores/domain/entities/guided_chore_setup.dart` preserves exact advanced rules and validates frozen anchors/end bounds |
| Secure submitted batch | `apps/kinflow_app/lib/features/chores/data/services/secure_guided_chore_setup_resume_store.dart` implements strict v2 exact-rule codec and v1 no-replay cleanup |
| Guided presentation | `apps/kinflow_app/lib/features/chores/presentation/screens/guided_chore_setup_screen.dart` reuses `ChoreRecurrenceEditor`, restores exact frozen rules and locks post-submit editing |
| Domain coverage | `apps/kinflow_app/test/features/chores/guided_chore_setup_domain_test.dart` covers advanced daily/weekly/monthly fidelity and anchor rejection |
| Resume coverage | `apps/kinflow_app/test/features/chores/secure_guided_chore_setup_resume_store_test.dart` covers v2 round trip, canonical encoding, v1 cleanup and corrupt/widened rejection |
| Retry coverage | `apps/kinflow_app/test/features/chores/guided_chore_setup_controller_test.dart` proves full-rule fingerprint freeze and same-command retry |
| UI coverage | `apps/kinflow_app/test/features/chores/guided_chore_setup_widget_test.dart` maps monthly count and weekly multi-day input, cold resume and compact pseudo 200% layout |

## Automated verification

| Gate | Result |
|---|---|
| Focused guided domain/controller/secure-store/widget suite | **PASS — 33 tests** |
| Chore/offline/auth-lifecycle/architecture/localization impact suite | **PASS — 261 tests** |
| Full exact Flutter regression | **PASS — 1,125 tests, 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 649 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Repository Node contract suite | **PASS — 141/141** |
| CI workflow and supply-chain contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Documentation structure | **PASS — 368 Markdown files have balanced fences; 6 relevant YAML contracts parse; 13 matrices are rectangular with declared counts; requirements 116×18, platform 20×12, tests 81×11** |

The secret scanner's first concurrent invocation collided with another Dart process while bundling a local Objective-C native asset. A serial rerun completed successfully with zero findings; this was a local tool-process race, not a product or scanner finding.

## Security, privacy and compatibility

- Invalid or noncanonical recurrence is blocked before command-ID creation, secure write, repository or network I/O.
- No title, recurrence payload, template key, command ID, household ID or member ID was added to logs or analytics.
- UI continues to expose only localized stable error states; raw storage, provider and repository failures remain hidden.
- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI and remote DTO signatures are unchanged.
- No runtime dependency, native permission or ARB key was added; existing generated EN, KO and EN-XA recurrence strings are reused.

## Deferred manual verification

- Hosted Supabase recurrence materialization with real adult accounts
- Two-device partial failure, retry and concurrency behavior
- Android Keystore process-kill recovery and legacy-v1 cleanup on physical storage
- Android date picker, TalkBack and phone/tablet layout
- DST boundary behavior in the hosted household timezone
- Schema extensions such as multiple month dates, last-day, ordinal weekday, yearly and business-day rules

## Rollback

- Hide the guided advanced editor and return new drafts to interval-one, never-ending daily/weekly suggestions.
- Purge the v2 frozen batch before any basic frequency-only fallback so an exact rule is never narrowed and replayed.
- No database migration, RLS, RPC or remote-data rollback is required.

## Commands

```text
flutter test <guided focused and impact paths>
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
python3 documentation contract and matrix validator
git diff --check
```
