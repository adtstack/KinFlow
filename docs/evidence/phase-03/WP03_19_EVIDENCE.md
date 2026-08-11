# Phase 03 WP03-19 Searchable Internal Chore Template Library Evidence

## Result

- Status: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — Phase 03, P1 activation and release completion are not claimed
- Requirements: `FR-CHORE-010`, `FR-CHORE-001`, `FR-CHORE-002`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decision: `D-058` provisional
- Vertical slice: exact app catalog → localized search/category discovery → editable one-time or guided draft → existing create contract
- Database migration, API/RLS, dependency, native permission, public config, persistent storage and analytics additions: none
- Actual account, remote provider, multi-device and physical-device validation: not run by priority

## Acceptance results

| Criterion | Result |
|---|---|
| Expanded internal catalog | PASS — preserves the original 6 stable keys and relative order while exposing exactly 16 immutable entries |
| Category model | PASS — every entry belongs to exactly one of 5 exact PII-free categories and every category is populated |
| Localized discovery | PASS — current-locale title search is trimmed and case-insensitive; category and query intersect; explicit empty and clear states work |
| Draft preservation | PASS — a filter may hide a selected template without clearing selection, editable title, repeat or other form values |
| Shared feature flow | PASS — the same browser preserves one-time single-select and guided exact-three multi-select semantics |
| Existing persistence boundary | PASS — only the user-confirmed title and existing recurrence/request fields reach create; query/category/key/version are absent |
| Secure guided recovery | PASS — newly added stable keys round-trip through the existing strict v2 submitted-batch checkpoint without schema widening |
| Accessibility and localization | PASS — EN/KO/EN-XA exact coverage and 30% pseudo expansion; 48dp search/category/template actions and compact 200% scroll regression |

## Exact catalog

Catalog version is `2026-08-09-wp03-19`.

| Stable key | Category | Suggested cadence |
|---|---|---|
| `dishes` | kitchen | daily |
| `kitchen_reset` | kitchen | daily |
| `laundry` | laundry | weekly |
| `vacuuming` | cleaning | weekly |
| `bathroom_cleaning` | cleaning | weekly |
| `trash_and_recycling` | home care | weekly |
| `wipe_counters` | kitchen | daily |
| `fridge_cleanout` | kitchen | weekly |
| `mop_floors` | cleaning | weekly |
| `dusting` | cleaning | weekly |
| `change_bed_linen` | laundry | weekly |
| `fold_clothes` | laundry | weekly |
| `make_beds` | home care | daily |
| `water_plants` | home care | weekly |
| `feed_pets` | pet care | daily |
| `clean_pet_area` | pet care | weekly |

- `stableKey`, category key and parser matching are exact lowercase ASCII snake case. Case folding, trimming and unknown fallback are rejected at the domain boundary.
- Domain entries contain only stable generic enum metadata. Localized titles and category labels are exhaustively mapped from ARB in presentation.
- The original six stable keys stay first in their previous relative order, preserving guided request ordering and existing submitted-record compatibility.

## User flow and implementation

1. The quick-start section opens with an empty search and All category.
2. Search filters the current locale's visible title; category chips filter the immutable domain category; both conditions must match.
3. A localized live empty state replaces the template chip wrap when no entry matches. The suffix action clears only the query and keeps the chosen category.
4. Category chips use a horizontally scrollable padded row, while template chips wrap inside the parent form's vertical scroll.
5. One-time/repeating creation uses `ChoiceChip` single selection. Guided setup uses `FilterChip`, keeps selected entries removable, and disables only unselected entries after three choices.
6. Selecting a template copies its localized title and suggested daily/weekly cadence into editable form state. Existing assignee, date, time and description values remain authoritative and unchanged.
7. Filtering does not own selection or form state; returning to a matching filter shows the selected chip again.

## Main implementation files

- `apps/kinflow_app/lib/features/chores/domain/entities/chore_template.dart`
- `apps/kinflow_app/lib/features/chores/presentation/chore_template_localization.dart`
- `apps/kinflow_app/lib/features/chores/presentation/widgets/chore_template_browser.dart`
- `apps/kinflow_app/lib/features/chores/presentation/screens/one_time_chore_creation_screen.dart`
- `apps/kinflow_app/lib/features/chores/presentation/screens/guided_chore_setup_screen.dart`
- `apps/kinflow_app/lib/l10n/app_en.arb`, `app_ko.arb`, `app_en_XA.arb` and generated localization files

## Automated verification

| Gate | Result |
|---|---|
| Focused domain/widget/resume/localization/architecture suite | **PASS — 113 tests** |
| Full exact Flutter regression | **PASS — 1,276 tests, 1 existing opt-in live test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 686 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Documentation structure | **PASS — template YAML parsed; 388 Markdown fences balanced; 13 matrices rectangular including API 46×6, requirements 117×18 and tests 87×11** |

The first new guided browser test attempted to tap the horizontally scrolled All chip without bringing it back into view. The test was corrected to perform the same horizontal reveal a user would, then the focused suite passed. No product state or network behavior was changed by that correction.

## Security, privacy and compatibility

- No user/account/household/member identifier, name, email, location, date, description, household content, token, URL, remote image or executable content exists in the catalog.
- Search text, category, selected key, version and ordering are not written to secure storage, read cache, database, request DTO, log, diagnostics or analytics.
- Existing active-household/member authorization and create RPC validation remain the only mutation authority; template selection does not grant or infer permission.
- No remote catalog, arbitrary server map, recommendation, personalization, recently-used list, ranking or usage event was introduced.
- The guided resume contract remains v2 and exact. Adding known parser enum values is backward compatible with existing six-key records and does not alter the stored envelope.
- No runtime SDK/package, platform configuration, permission, secret or native implementation changed.

## Deferred manual validation and risks

- Real adult account creation and cross-device observation of template-created chores
- Android hardware keyboard, IME search action, TalkBack traversal, system font scaling and phone/tablet/split-screen layout
- Household/user research for the catalog's cultural relevance, category labels, missing chores and title tone
- Beta measurement decision for adoption; no behavioral analytics is added by this slice
- Remote or household-specific catalog versioning, localization, cache/fallback, authorization and threat review

The static 16-entry catalog is intentionally generic. It may not fit every household or culture; every applied value remains editable and templates remain optional. Product research is still required before treating catalog quality as validated.

## Rollback

- Remove the reusable browser, the ten added enum/title mappings, category metadata and new ARB keys, then restore the WP03-08 six-entry catalog version.
- Reconnect the existing six template chip wraps in the one-time and guided screens. Existing draft/create controllers and requests remain unchanged.
- Existing v2 resume records using the original six keys remain readable. Records containing one of the ten new keys must be allowed to finish before a downgrade or be explicitly cleared through the existing secure local-state path.
- No DB migration, server artifact, cache row, analytics data or dependency cleanup is required.

## Commands

```text
flutter gen-l10n
flutter test --no-pub <focused domain/widget/resume/localization/architecture paths>
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
ruby YAML/Markdown/matrix structure checks
git diff --check
```
