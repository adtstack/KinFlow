# Phase 01 WP01-12 Web Companion Baseline Evidence

## Result

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Scope: Flutter Web dev/prod release build → exact Web runtime identity/policy → email-first sign-in → exact-five safe capability fallback → independent CI artifact
- Decision: D-070 (`PROVISIONAL`)
- Contract: `docs/contracts/web-companion-baseline.yaml.md`
- Test ID: T-WEB-BASELINE
- Web Beta, hosted origin and real-account completion are **not** claimed.

## Delivered behavior

- The same Flutter repository now produces independent Web `dev` and `prod` release bundles from `main_dev.dart` and `main_prod.dart`.
- Web uses path URLs and a minimal no-referrer/noindex shell without an install manifest.
- The release gate requires an absent manifest, empty disabled `flutter_service_worker.js`, no loader service-worker registration and no persistent API cache.
- Web runtime identity uses package `kinflow_app`, platform header `web`, exact environment/build/contract headers and an exact `version.json` derived from `APP_VERSION`.
- The server has compatibility-open dev/prod Web global policies and exact six feature policies; service-only configuration, replay, audit and DB-authoritative mutation enforcement preserve the Android function signatures.
- PostgREST UTC timestamps ending in either `Z` or `+00:00` now map strictly; non-UTC timestamps still fail closed.
- Web authentication exposes the existing email OTP flow while the native Google launcher is unavailable.
- Web retains the shared authenticated server repositories and entitlement read but disables RevenueCat purchase, FCM endpoint lifecycle, persistent read cache, guided setup resume and Chore completion outbox.
- The exact-five Web capability registry resolves to inbox+configured email, server entitlement read, re-auth without persistent cache, browser external links and server notification/inbox fallback.

## Implementation evidence

| Area | Evidence |
|---|---|
| Web shell and URL strategy | `apps/kinflow_app/web/index.html`, `.metadata`, `lib/app/router/platform_url_strategy*.dart` and bootstrap conditional setup |
| Web-safe composition | `apps/kinflow_app/lib/app/providers/auth_dependencies.dart` and `notification_push_composition.dart` select shared server adapters or explicit unavailable implementations by runtime |
| Capability fallback | `platform_capability_registry.dart` and providers define the exact Web snapshot without initializing native providers |
| Runtime identity and mapping | `app_environment.dart`, runtime-policy domain/mappers and provider repository tests cover package/platform headers plus strict UTC variants |
| Server policy | `supabase/migrations/20260810200000_web_runtime_policy_baseline.sql` and `web_runtime_policy_baseline.test.sql` |
| Release gate | `scripts/ci/web-public-config.mjs`, `scripts/ci/web-build.sh` and the independent Web matrix in `.github/workflows/ci.yml` |
| Architecture regression | `test/architecture/web_companion_baseline_test.dart`, auth composition/purge tests and platform registry snapshot tests |

## Build evidence

| Build | Runtime version | Main bytes | SHA-256 | Result |
|---|---:|---:|---|---|
| Web dev release | `0.1.0-dev+1` | 6,457,587 | `846241d0b3ac7a55618c67c910bb7df6e9a8b00d95bde920959c811bce2b966c` | PASS |
| Web prod release | `0.1.0+1` | 6,453,814 | `75da1f403a2882baf2f577952f7fbfc2bdc022cee72d95d43bb9667723096a12` | PASS |
| Android dev regression APK | `me.newlines.kinflow.dev` | 219,949,785 | `5b6571766c9fe3d6744bde622c758a18de96ad3ce7b42bd47f57149fbec82b7a` | PASS |

Both Web reports record path URL enabled, manifest absent, service worker disabled, persistent API cache disabled and dirty source state. The Android build confirms the conditional Web composition did not break the existing dev application ID, API or manifest audit.

## Local browser evidence

The in-app Browser control workflow was used against a temporary local release build connected only to the local Supabase stack. No OTP was requested and no real account was used.

- `/` completed client-side navigation to `http://127.0.0.1:8091/sign-in` with title `KinFlow`.
- Both Web runtime-policy RPCs returned HTTP 200 and no runtime-policy unavailable banner remained after the strict `+00:00` mapper fix.
- The accessibility tree exposed the localized heading `KinFlow에 로그인`, a disabled Google action, visible/enabled email textbox and enabled login-code request action.
- Locator assertions passed: Google disabled, email visible/enabled, send-code enabled, one sign-in heading and zero runtime-policy error banners.
- A direct `/sign-in` reload on the generic Python static server returned HTTP 404. This is recorded as an unresolved hosting SPA rewrite requirement, so FR-PLAT-011 and NFR-WEB-004 remain `PARTIAL`.
- Browser tabs and the temporary HTTP server were closed after inspection.

## Automated verification

| Gate | Result |
|---|---|
| Focused Web registry/identity/auth/architecture/runtime-policy suites | PASS — all focused sets green |
| Full exact Flutter regression | **PASS — 1,367 tests, 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 703 files, 0 changed** |
| Generated-code drift | **PASS — 8 generated files current; 1 identical output regenerated** |
| Public configuration allowlist | **PASS** |
| High-confidence secret scan | **PASS — 0 findings** |
| Repository Node contract suite | **PASS — 157/157** |
| Supabase Edge unit contracts | **PASS — 118/118** |
| Web runtime-policy focused pgTAP | **PASS — 13/13** |
| Android+Web runtime-policy combined pgTAP | **PASS — 3 files, 71 tests** |
| Full database contract regression | **PASS — 66 files, 3,278 tests** |
| Supabase schema lint | **PASS — 0 schema errors** |
| CI workflow/supply-chain contract | **PASS — 6 jobs, 22 pinned action uses, `contents:read`** |
| Dependency licenses | **PASS — 167 Pub, 15 npm runtime, 365 npm build-only** |
| OSV lockfile scan | **PASS — scanner 2.3.8 checksum verified, 2 offline DB files, actual scan network disabled** |
| Documentation structure | **PASS — 424 Markdown files, 70 YAML contracts, 13 rectangular matrices; requirements 127×18, platform 20×12, tests 99×11** |
| Whitespace | **PASS — final `git diff --check` output 0** |

## Security, privacy and compatibility

- No server secret, new public config key, native permission, behavioral analytics event or provider SDK was added.
- The new SDK dependency is Flutter-owned `flutter_web_plugins`; the exact runtime dependency/privacy inventory and contract were updated together.
- No Web Push permission, device token or notification endpoint is created.
- No Web Store purchase SDK is initialized; household entitlement remains server authoritative and read-only on Web.
- Broad user-content persistence is absent. Authentication session state remains provider-owned and participates in logout/account-switch/removal purge.
- The migration expands existing platform constraints and functions without changing public signatures, grants, stable errors or Android seed semantics.
- Runtime-policy headers contain only version/build/contract/platform/environment metadata and no account, household or family content.

## Deferred completion evidence

- owned HTTPS origin, CSP/security headers and production SPA fallback rewrite
- OAuth PKCE callback, redirect allowlist and callback URL scrub
- real email OTP/account, logout/account switch/removal browser residue
- authenticated core keyboard-only, zoom, screen-reader, BFCache and browser matrix
- hosted runtime-policy propagation, atomic deployment, stale-tab recovery and rollback
- mobile purchase to Web entitlement parity and reverse journey
- Web Push and Web purchase provider decisions
- real accounts, multi-device and physical-device verification, per user direction

## Rollback

- Remove the Web scaffold, conditional URL strategy and independent Web CI job to return to the Android-only build surface.
- Remove Web policy rows and constraint support with a forward-only migration while preserving Android rows and public function signatures.
- No PWA installation, service-worker user cache, Web purchase binding or notification endpoint cleanup is required.

## Commands

```text
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub --fatal-infos --fatal-warnings
flutter test --no-pub
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
node --test supabase/tests/*.test.mjs
npx --no-install supabase test db supabase/tests/database
npx --no-install supabase db lint --local --schema app_private,public --level warning --fail-on error
scripts/ci/web-build.sh dev
scripts/ci/web-build.sh prod
scripts/ci/android-build.sh dev
npm run ci:dependency
ruby documentation YAML/CSV/fence validator
git diff --check
```
