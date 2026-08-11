# Phase 01 WP01-11 Core Primary Navigation Evidence

## Result

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Scope: authenticated adult core shell → responsive exact-five primary navigation → dedicated Chores hub → route-authoritative selected state
- Requirements: FR-CHORE-009, FR-PLAT-009, NFR-A11Y-01, NFR-I18N-01
- Test IDs: T-NAV-01, T-A11Y-03, T-I18N-01
- Remote services, real accounts, multi-device and physical-device verification remain deferred to the final integration Gate by user direction.

## Delivered behavior

- Today, Chores, Calendar, Family and Settings are available in that exact order on every authenticated core surface.
- Compact layouts use a bottom `NavigationBar`, medium layouts use a collapsed `NavigationRail`, and expanded layouts use an extended rail.
- Current top-level route is the only selected-state authority; choosing the already selected destination is a no-op.
- `/chores` opens an upcoming-first hub with exactly upcoming, overdue and completed views plus Everyone and Me assignee filters.
- The Chores hub reuses the existing chore repository and mutation/offline boundaries but does not request or render the Today Calendar composition.
- `/family` is the primary Family route while `/family/members` remains a compatible alias to the same authorized screen.
- Subflows that do not explicitly declare a core destination render without primary navigation.

## Implementation evidence

| Area | Evidence |
|---|---|
| Destination model and routes | `apps/kinflow_app/lib/app/router/app_primary_destination.dart` and `apps/kinflow_app/lib/app/router/app_router.dart` define exact-five mapping plus `/chores` and `/family` |
| Responsive shell | `apps/kinflow_app/lib/app/presentation/widgets/responsive_scaffold.dart` renders optional compact bar or medium/expanded rail with route-selected state and navigation-first rail focus order |
| Chores hub | `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart` initializes upcoming and constrains the hub to exact three views without Today composition loads |
| Core screens | Calendar, household members and settings screens declare their current primary destination and use fixed route mapping |
| Localization | EN, KO and EN-XA ARB sources and generated localization files provide exact destination labels |
| Route, layout and accessibility coverage | `apps/kinflow_app/test/app/adaptive_accessibility_test.dart` covers actual traversal, selected state, same-target no-op, Chores authority, alias compatibility, 48dp, 200 percent pseudo, RTL and hidden subflows |

## Automated verification

| Gate | Result |
|---|---|
| Focused adaptive navigation suite | **PASS — 15 tests** |
| Shell, Chores, Calendar, Family, Settings, localization and architecture impact suite | **PASS — 108 tests** |
| Full exact Flutter regression | **PASS — 1,128 tests, 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 650 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current, build runner wrote 0 outputs** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Repository Node contract suite | **PASS — 141/141** |
| CI workflow and supply-chain contract | **PASS — 5 jobs, 17 pinned action uses, `contents:read`** |
| Documentation structure | **PASS — 371 documentation Markdown files have balanced fences; core YAML parses with exact routes/views; 13 matrices are rectangular with declared counts; requirements 116×18, platform 20×12, tests 82×11** |
| Whitespace | **PASS — `git diff --check` output 0** |

## Security, privacy and compatibility

- Primary navigation uses fixed content-free paths and never places household, member or resource identifiers in a route.
- Navigation selection performs no repository mutation, cache write, network request, command-ID generation or telemetry emission.
- No provider state, persisted navigation state or analytics event was added.
- The Chores hub retains existing authorization, server filter, runtime mutation guard and offline read-only behavior.
- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI and remote DTO signatures are unchanged.
- No runtime dependency, native permission or sensitive configuration key was added.
- All user-facing destination labels come from generated ARB localization; no raw provider or repository error is exposed.

## Deferred manual verification

- Android TalkBack destination and selected-state announcements
- Representative phone and tablet orientation, split-screen and system-back behavior
- Process recreation and destination restoration
- Real adult accounts and cross-device household changes
- Web direct URL, browser history and keyboard-only behavior at its independent platform Gate
- iOS navigation conventions at its deferred platform Gate

## Rollback

- Remove the shared destination model and optional compact/rail navigation parameters.
- Remove `/chores` and `/family`; retain the existing `/today`, `/calendar`, `/family/members` and `/settings` routes and top-bar shortcuts.
- No database migration, remote cleanup, cache purge or telemetry cleanup is required.

## Commands

```text
flutter test test/app/adaptive_accessibility_test.dart
flutter test <shell, Chores, Calendar, Family, Settings, localization and architecture impact paths>
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
