# Phase 05 WP05-17 App-shell Notification Sync and Global Badge Evidence

## Result

- 상태: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED (2026-08-10)**
- 범위: authenticated user/active household → one root Notification Center owner → one self-user Realtime channel → authoritative unread snapshot → Today·Chores·Calendar·Family·Settings badge
- 계약: `docs/contracts/notification-app-shell.yaml.md`
- Workplan: `docs/evidence/phase-05/WP05_17_WORKPLAN.md`
- 요구사항: `WP05-17`, `FR-NOTIF-007`, `FR-NOTIF-008`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `T-SYNC-02`

## Implemented slice

- app root의 `NotificationCenterLifecycleHost`가 route와 독립적으로 Notification Center provider/controller를 앱 셸 수명 동안 유지한다.
- auth user/active household pair가 같으면 snapshot과 channel을 재사용하고, resume에는 channel을 교체한 뒤 active household first page를 authoritative하게 다시 읽는다.
- household, user 또는 no-household 전환은 이전 content와 badge를 먼저 비우고 channel을 취소한 뒤 새 context만 읽는다.
- controller context epoch가 전환 중 완료된 load, preference, read, mark-all-read, pagination과 Snooze 응답을 무시한다. `ensureLoaded`는 같은 context의 중복 initial read를 합친다.
- Today와 Notification Center의 중복 resume owner를 제거하고 화면 initial read는 root가 없는 격리 환경에서도 안전한 `ensureLoaded` fallback으로 유지한다.
- root가 authoritative unread count만 read-only inherited scope로 투영하며 공용 action은 Today, Chores, Calendar, Family, Settings에서 같은 count와 Notification Center route를 제공한다.
- 시각 badge는 0에서 숨고 100 이상은 `99+`로 제한한다. semantic button은 실제 count를 EN/KO/EN-XA로 읽고 200% text scale에서 접근 가능하다.
- migration, table, trigger, publication, RPC, Edge function, payload, route, native permission, dependency, analytics와 persistent cache 변경은 없다.

## Automated evidence

| Gate | Command | Result |
|---|---|---|
| Focused controller/widget | `flutter test` for Notification Center controller and widget files | PASS; 26 tests |
| Notification regression | `flutter test test/features/notifications` | PASS; 77 tests |
| Isolated screen regression | focused Settings and adaptive accessibility tests after root-scope fallback | PASS; direct screen requires no Notification auth graph and pending timer 0 |
| Full Flutter | `flutter test --reporter compact` | PASS; 1,433 tests / existing local-connectivity opt-in 1 skip / failure 0 |
| Flutter quality | `scripts/ci/flutter-quality.sh` with exact SDK and offline pub | PASS; formatter 740 files drift 0, analyzer 0, public config valid, high-confidence secret finding 0 |
| Coverage | quality-gate LCOV summary | PASS; 30,358 / 37,846 lines, 80.21% |
| Localization/codegen | generated ARB coverage plus quality-gate codegen verifier | PASS; EN/KO/EN-XA unread semantics, build runner wrote 0 outputs, 8 generated files current |
| Repository Node | `node --test`; quality-gate `npm run ci:test` | PASS; full Node 288 tests and CI-contract 157 tests, failure 0 |
| Workflow | quality-gate workflow contract and actionlint | PASS; 6 jobs, 22 pinned action uses, `contents:read`, actionlint pass |
| Documentation | fenced YAML, rectangular matrices, Markdown fences and ARB JSON validation | PASS; 13 matrices, 442 balanced Markdown files, 76 YAML contract documents, 3 ARBs |
| Production Web | `scripts/ci/web-build.sh prod` | PASS; 6,492,064-byte `main.dart.js`, SHA-256 `403fa55e7ea279ada7da46366d70da1d73aaaa9c6589e210e1b49ce0b594d180`; PWA manifest absent, service worker/cache disabled |
| Whitespace | `git diff --check` | PASS; output 0 |

All Flutter commands use Flutter SDK 3.44.7 stable and Dart 3.12.2 with `DART_TOOL_HOME=/private/tmp/kinflow-dart-tool` and `CI=true`.

The single Flutter skip is the pre-existing opt-in local-connectivity test and is not a skipped WP05-17 assertion. The first full regression found that direct Settings screens should not construct the Notification auth graph and that a root-watched auto-dispose provider schedules a test teardown timer. The final boundary uses an app-lifetime provider plus a read-only inherited unread scope; the isolated Settings/adaptive regressions and complete suite then passed.

No DB/API surface changed in WP05-17, so a new reset or pgTAP run was not required. WP05-16 already fixed the unchanged 67-migration, 3,349-test DB and self-user Realtime contract evidence.

## Security and privacy evidence

- root scope contains only the server-authoritative integer unread aggregate and never household, member, item, source, category, content, token or provider detail.
- auth user and household jointly identify the client context; no-session and no-household states map to no active context.
- deactivate increments the context epoch before emitting `NotificationCenterInitial`, so an old response cannot repopulate content even after re-entering the same household.
- logout automation proves immediate presentation purge and deterministic old-channel cancellation. household-switch automation proves zero/empty transition state before the new snapshot and a single new channel afterward.
- authorization failure continues to purge retained content and stop sync; transport disconnect continues to retain only the last authorized snapshot and aggregate badge.
- rootless isolated screens fail closed to an accessible zero badge without constructing auth, repository or Realtime dependencies.

## Deferred manual evidence

- hosted Supabase Realtime propagation, reconnect and token-refresh timing
- real-account and two-device concurrent read, preference and materialization flows
- Android physical-device foreground/background/network transitions and TalkBack journey
- operating-system suspended-process background execution
- actual Firebase, SendGrid, mailbox and external provider delivery

These are intentionally deferred to the final live-account/device Gate per the feature-first instruction.

## Rollback

- remove `NotificationCenterLifecycleHost` from the app root and restore screen-owned resume calls to return to the WP05-16 route-lifetime behavior.
- remove `NotificationAppShellAction` from the five primary screens and its read-only badge scope without changing notification history or server state.
- revert the Notification Center providers to auto-dispose if root ownership is removed.
- remove `ensureLoaded`, `deactivate` and context epoch guards only together with the root lifecycle host; no DB/API rollback is required.
