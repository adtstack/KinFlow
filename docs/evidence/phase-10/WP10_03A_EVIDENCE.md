# Phase 10 WP10-03A Web Core Keyboard and Focus Evidence

## Result

- **LOCAL IMPLEMENTED / PARTIAL (2026-08-10)**
- Scope: visible Web focus → authenticated exact-five keyboard navigation → app-owned dialog/sheet focus containment → opener focus return
- Requirements: FR-PLAT-010, NFR-A11Y-01, NFR-WEB-002
- Decisions: D-028, D-036, D-070
- Contract: `docs/contracts/web-keyboard-focus.yaml.md`
- Test: T-WEB-03 with existing T-WEB-07 trace alias
- Web Beta accessibility completion is **not** claimed.

## Delivered behavior

- Web bootstrap selects `FocusHighlightStrategy.alwaysTraditional`; native platforms keep Flutter's automatic input policy.
- The shared light/dark Material theme derives a 24% primary focus color so keyboard focus is not represented only by an implicit platform default.
- All 26 application-owned dialog callsites and 4 modal bottom-sheet callsites use one shared route wrapper.
- Dialogs explicitly request focus and use closed-loop traversal. Modal sheets own and dispose a closed-loop `FocusScopeNode`.
- On modal completion, the opener receives focus on the next frame when it is still attached and can request focus; removed or disabled targets safely no-op.
- Top-level route traversal remains parent-scoped so the Web application does not trap users away from browser UI.
- Required task completion uses standard Tab, Shift+Tab, Enter and Escape rather than undiscoverable custom shortcuts.

## Implementation evidence

| Area | Evidence |
|---|---|
| Web focus visibility | `apps/kinflow_app/lib/app/presentation/focus_highlight_policy.dart`, bootstrap and `app_theme.dart` |
| Shared modal contract | `apps/kinflow_app/lib/app/presentation/widgets/app_modal_route.dart` |
| Full callsite adoption | billing, calendar, chores, household, notifications, settings presentation plus `timezone_picker_sheet.dart` |
| Modal keyboard tests | `apps/kinflow_app/test/app/modal_keyboard_focus_test.dart` |
| Authenticated route test | `apps/kinflow_app/test/app/adaptive_accessibility_test.dart` |
| Drift prevention | `apps/kinflow_app/test/architecture/app_modal_route_adoption_test.dart` |

## Focused automated verification

| Gate | Result |
|---|---|
| Dialog and modal-sheet keyboard/focus contract | PASS |
| Web traditional highlight and theme focus policy | PASS |
| Raw modal call architecture guard | PASS |
| Authenticated expanded exact-five keyboard-only routes | PASS |
| Adaptive accessibility regression | PASS |
| Focused aggregate | **PASS — 21 tests** |
| Full exact Flutter regression | **PASS — 1,373 tests, 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 707 files, 0 changed** |
| Web prod release gate | **PASS — 6,455,211-byte `main.dart.js`, SHA-256 `59e8b896313051bca49954788ccbb4b171fd953e6078047aeb03421c574180ea`** |
| Documentation structure | **PASS — 427 Markdown files, 71 YAML contracts, 13 rectangular matrices; requirements 127×18, platform 20×12, tests 99×11** |
| Whitespace | **PASS — `git diff --check` output 0** |

The Web release audit also confirmed path URLs, absent PWA manifest, disabled service worker and disabled persistent API cache. No real account or hosted endpoint was used.

## Security, privacy and compatibility

- No DB, RLS, RPC, Edge, JSON, cache, dependency, permission, secret, public config or analytics event changed.
- Focus nodes, key actions and route results remain process-memory UI state and are not persisted or logged.
- The wrapper does not bypass confirmation, authorization, recent-authentication or runtime-policy checks; it only standardizes route focus behavior.
- The restore callback checks target attachment and eligibility before requesting focus, preventing access to a disposed opener.
- Existing Android/iOS input policy remains automatic; Web-specific behavior is isolated at bootstrap.
- A source architecture test prevents future feature screens from silently bypassing the focus contract with raw modal calls.

## Manual and real-environment verification

The following is **NOT RUN** and remains intentionally deferred:

- actual Chrome, Edge, Firefox and Safari authenticated journeys
- browser-native 200% zoom/reflow and light/dark focus contrast
- NVDA, JAWS and VoiceOver announcement/order
- hosted HTTPS, real account, account switch and browser session behavior
- physical keyboard and assistive-technology device checks

Local synthetic authentication and Flutter semantics cannot be interpreted as browser-matrix, screen-reader or real-account completion.

## Remaining risk

- Browser engines can differ in focus paint, key dispatch and route restoration despite the shared Flutter contract.
- Automated text scaling is not identical to browser-native zoom; 200% browser reflow remains a separate Gate.
- Visual focus color still requires manual contrast/appearance review in light and dark themes.
- The architecture guard covers Flutter Material dialog and modal-bottom-sheet entry points; a future custom overlay must define equivalent containment and return behavior explicitly.

## Rollback

- Remove the Web focus bootstrap call and theme focus color to return to Flutter defaults.
- Revert the 30 callsites to direct Flutter modal functions, then remove the wrapper and architecture tests.
- No migration or persisted-state rollback is required.

## Conclusion

The local Web keyboard/focus vertical slice is implemented and automatically testable without a real account. FR-PLAT-010, T-WEB-03 and PDOD-052 remain `PARTIAL` until the deferred real-browser, zoom, screen-reader and hosted authenticated evidence is completed at the final integration Gate.
