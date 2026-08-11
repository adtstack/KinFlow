# Phase 10 WP10-01A Web Invite Sharing Evidence

## Result

- **LOCAL IMPLEMENTED / PARTIAL (2026-08-10)**
- Scope: Web adult invite result → explicit Web Share → unsupported/rejected state → separate explicit clipboard recovery
- Requirements: FR-HH-003, FR-HH-004, NFR-PRIV-01, NFR-WEB-001
- Capability: CAP-016
- Decisions: D-002, D-006, D-015, D-017, D-047, D-070
- Contract: `docs/contracts/web-invite-sharing.yaml.md`
- Test: T-LINK-03
- Hosted/browser/recipient completion is **not** claimed.

## Delivered behavior

- Configured invite sharing now selects the existing Android MethodChannel gateway on native builds and a Web-only JS interop gateway on Web builds.
- The Web adapter checks for `navigator.share` before invocation. Unsupported browsers return the existing `unavailable` state without a provider call.
- An explicit Share action passes exactly the localized chooser title and the already validated canonical `HouseholdInviteLink`; no text, files, recipient, email, subject or provider metadata is created.
- Empty or oversized titles fail before browser I/O. Browser rejection, cancellation and provider exceptions collapse to the stable credential-free `failed` result.
- A resolved share Promise maps to the existing share-sheet handoff result. KinFlow still does not claim recipient delivery, opening or invitation acceptance.
- The existing controller single-flight, localized live region and manual `Copy link` recovery remain unchanged. Share failure never performs an automatic clipboard write.
- No Web-specific result entered domain state; the injectable browser client makes support, allowlisted payload and failure mapping testable on the VM.

## Implementation evidence

| Area | Evidence |
|---|---|
| Platform conditional composition | `apps/kinflow_app/lib/app/providers/invite_sharing_dependencies.dart`, `apps/kinflow_app/lib/infrastructure/share/platform_household_invite_share_gateway*.dart` |
| Provider-neutral Web gateway | `apps/kinflow_app/lib/infrastructure/share/web_household_invite_share_gateway.dart` |
| Browser JS interop client | `apps/kinflow_app/lib/infrastructure/share/browser_web_share_client.dart` |
| Exact Web adapter tests | `apps/kinflow_app/test/infrastructure/web_household_invite_share_gateway_test.dart` |
| Native/controller/composition regressions | Existing invite-sharing infrastructure, controller and dependency tests |
| Conditional Web source boundary | `apps/kinflow_app/test/architecture/web_companion_baseline_test.dart` |

## Automated verification

| Gate | Result |
|---|---|
| Web gateway plus native/composition/controller focus | **PASS — 18 tests** |
| Full invite creation/accept/share/copy impact aggregate | **PASS — 63 tests** |
| Full exact Flutter regression | **PASS — 1,397 tests; 1 existing opt-in live-connectivity test skipped** |
| Exact Flutter analyzer | **PASS — 0 issues** |
| Exact Dart format | **PASS — 716 files, 0 changed** |
| Web prod release gate | **PASS — 6,460,297-byte `main.dart.js`, SHA-256 `24c544909c234b3f8e6a516213b698a0517693cd8b75b1a422ca0b02bf0d2f91`** |
| Documentation structure | **PASS — 433 Markdown files, 73 YAML contracts, 13 rectangular matrices; requirements 127×18, platform 20×12, tests 99×11** |
| Whitespace | **PASS — `git diff --check` output 0** |

The Web build used example public configuration, made no real invitation and contacted no account, recipient or hosted application origin.

## Security, privacy and compatibility

- The share URL remains the existing exact HTTPS `/invite/{token}` value object. No new parsing, URL construction or credential persistence path was added.
- Browser support and invocation details remain inside infrastructure; features, controllers, providers and widgets receive only the existing three stable results.
- Provider exception names/messages are never surfaced, logged or added to analytics. The new code emits no event and adds no storage.
- The raw URL crosses into the browser provider only after the existing explicit user gesture and is not duplicated into `text`, subject or another payload field.
- Clipboard recovery remains separate, explicit and write-only. Unsupported or failed share never mutates it automatically.
- No DB, migration, RLS, RPC, Edge, remote DTO, public config, runtime dependency, browser permission, manifest, service worker or cache changed.
- Android compilation behavior retains the existing MethodChannel implementation through the native conditional factory.

## Manual and real-environment verification

The following is **NOT RUN** and remains intentionally deferred:

- owned HTTPS origin with the final `Permissions-Policy: web-share` policy
- Chrome, Edge, Firefox and Safari support, share-target, cancel/back/resume behavior
- real-account invitation generation, intended-recipient delivery, revoke/accept race and verified App Link open
- browser clipboard, history, storage and exception forensic inspection
- screen reader announcement around the browser-owned share UI
- iOS native share implementation and device behavior

Local fakes, source contracts and a production compiler cannot be interpreted as browser-provider or recipient completion.

## Remaining risk

- Browser and OS combinations expose different Web Share support; unsupported combinations intentionally retain the explicit Copy link fallback.
- A host can deny Web Share with its Permissions Policy even when the API exists. This becomes a stable failed state until hosted policy is verified.
- Browser cancellation and provider failure cannot be distinguished without exposing provider-specific detail; both remain safe, retryable failure.
- The browser owns target selection and external application handling, so actual delivery and post-share credential residue require the final manual Gate.

## Rollback

- Select an unavailable gateway in the Web factory to disable Web Share while preserving Android sharing and manual clipboard recovery.
- Remove the browser client, Web gateway and conditional export to return to the previous Android-only implementation.
- No migration, persisted state, dependency or account/provider cleanup is required.

## Conclusion

The Web Companion can now share a generated adult invitation through a supported browser without changing the Android flow or weakening credential lifetime and fallback rules. CAP-016, T-LINK-03 and PDOD-046 remain `PARTIAL` until hosted policy, actual browser, recipient, real-account and App Link evidence is completed at the final Web integration Gate.
