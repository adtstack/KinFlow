# Phase 10 WP10-03B Web Route Recovery Evidence

## Result

- **LOCAL IMPLEMENTED / PARTIAL (2026-08-10)**
- Scope: protected direct URL → fixed sign-in continuation → expiry/revoke recovery → logout/user/household isolation → safe 404/unavailable route
- Requirements: FR-AUTH-004, FR-AUTH-011, FR-PLAT-011, NFR-WEB-001, NFR-WEB-004
- Decisions: D-032, D-038, D-070
- Contract: `docs/contracts/web-route-recovery.yaml.md`
- Test: T-WEB-02
- Web route reliability completion is **not** claimed.

## Delivered behavior

- Route definitions are separated from router construction and one typed recovery policy classifies every current replayable application destination.
- A protected unauthenticated route produces `/sign-in?continue=<fixed-marker>`; raw path, resource UUID, arbitrary query and fragment never enter the continuation value.
- The only replayed query is a validated and canonicalized Chore creation `due=YYYY-MM-DD`. Calendar import falls back to Calendar because its required route context is process memory.
- The same runtime retains an exact validated resource route through session expiry/revocation and returns to it after the same user re-authenticates.
- A refreshed sign-in route can reconstruct only the fixed marker's coarse destination, so detailed identifiers are not persisted in browser-visible continuation state.
- Explicit logout, provider/purge failure, changed authenticated user and changed active household discard prior route intent. A different user after expiry is forced to Today rather than inheriting the previous user's detail.
- Plain sign-in navigation cancels stale continuation. Unauthenticated household onboarding fails closed to sign-in.
- An already-authenticated direct route is canonicalized before rendering, so arbitrary query parameters and fragments cannot remain in browser history. The process-memory-only Calendar import route is explicitly exempt because it requires trusted `state.extra`.
- Unknown paths and malformed Calendar UUID, Chore UUID and Chore due-date routes use one internal safe 404 screen instead of silently opening an unrelated feature.
- Authoritative Chore and Calendar resource not-found/forbidden responses retain their existing indistinguishable unavailable states.
- A route-screen auth listener no longer races the guard by navigating to `/` while a session-expiry redirect is preserving the exact destination.

## Implementation evidence

| Area | Evidence |
|---|---|
| Route constants | `apps/kinflow_app/lib/app/router/app_routes.dart` |
| Safe intent classification | `apps/kinflow_app/lib/app/router/app_route_recovery_policy.dart` |
| Auth/session/scope transition guard | `apps/kinflow_app/lib/app/router/auth_route_guard.dart` |
| GoRouter integration and safe invalid-route redirects | `apps/kinflow_app/lib/app/router/app_router.dart` |
| Session-expiry route race removal | `apps/kinflow_app/lib/features/chores/presentation/screens/chore_occurrence_target_screen.dart` |
| Guard and policy tests | `apps/kinflow_app/test/app/auth_route_guard_test.dart`, `apps/kinflow_app/test/app/app_route_recovery_policy_test.dart` |
| Integrated app-router tests | `apps/kinflow_app/test/app_shell_test.dart` |
| Existing resource anti-enumeration regressions | Chore occurrence target and Calendar events widget tests |

## Automated verification

| Gate | Result |
|---|---|
| Guard, policy and integrated app-router focus | **PASS — 45 tests** |
| Route plus Chore/Calendar unavailable focused aggregate | **PASS — 81 tests** |
| Full exact Flutter regression | **PASS — 1,392 tests; 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 710 files, 0 changed** |
| Web prod release gate | **PASS — 6,460,172-byte `main.dart.js`, SHA-256 `7e0aadfdb5be2efde3affc9bd99d212eeafc018fd33f1c11610f9b40d76b4d82`** |
| Documentation structure | **PASS — 430 Markdown files, 72 YAML contracts, 13 rectangular matrices; requirements 127×18, platform 20×12, tests 99×11** |
| Whitespace | **PASS — `git diff --check` output 0** |

The Web release audit also reconfirmed path URLs, absent PWA manifest, disabled service worker and disabled persistent API cache. The build used example public configuration and no real account or hosted endpoint.

## Security, privacy and compatibility

- No DB, migration, RLS, RPC, Edge, JSON payload, dependency, permission, secret, public config, cache or analytics event changed.
- Continuation markers are a closed fixed set and do not contain route paths, resource identifiers, due dates, invite tokens, callbacks or arbitrary values.
- Exact destinations remain process-memory only and are discarded at logout, provider/purge failure, user change, household change or plain sign-in cancellation.
- Session-expiry exact recovery is bound to the originating authenticated user. A different re-authenticated user cannot receive that route.
- Unknown and malformed route material is collapsed to an internal constant path. Server `notFoundOrForbidden` results remain indistinguishable to avoid resource enumeration.
- Native routing uses the same guard behavior; no browser-only API entered domain or feature layers.
- GoRouter remains the route-information authority and browser history is not suppressed, but actual engine history behavior is a deferred manual Gate.

## Manual and real-environment verification

The following is **NOT RUN** and remains intentionally deferred:

- owned hosted HTTPS origin with an SPA rewrite for every non-root route
- Chrome, Edge, Firefox and Safari direct load, refresh and back/forward
- BFCache restore, stale tab, multi-tab logout and browser forensic residue
- real session expiry/revoke followed by OTP/OAuth re-authentication
- real account A→B and active-household switch isolation
- membership removal, deleted-resource and forbidden races against hosted RLS/RPC

Local synthetic sessions and GoRouter widget tests cannot be interpreted as hosted rewrite, browser-history, BFCache or real-account completion.

## Remaining risk

- A generic static host still returns HTTP 404 for a non-root refresh until the selected host provides an SPA fallback to `index.html`.
- Browser engines can differ in history event ordering and BFCache restoration even when route-information state is correct in Flutter tests.
- Multi-tab logout and provider-owned browser session persistence require an actual hosted origin and browser storage inspection.
- A future route must be added to the explicit recovery policy; unknown routes fail safely to the constant 404 surface until then.

## Rollback

- Remove the route recovery policy and auth transition hook to restore the previous path-only in-memory guard.
- Move `AppRoutes` back into router construction and remove the internal not-found route if the separation must be reverted.
- Restore invalid dynamic-route redirects to their former feature fallbacks.
- No migration or persisted-state rollback is required.

## Conclusion

The local Web route-recovery vertical slice is implemented and automatically testable without a real account. FR-PLAT-011, NFR-WEB-004, T-WEB-02 and PDOD-055 remain `PARTIAL` until hosted SPA rewrite, actual browser history/BFCache and real-account transition evidence is completed at the final Web integration Gate.
