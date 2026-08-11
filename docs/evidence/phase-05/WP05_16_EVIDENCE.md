# Phase 05 WP05-16 Notification Center Realtime Invalidation Evidence

## Result

- 상태: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED (2026-08-10)**
- 범위: notification-visible DB change → self-scoped content-free watermark → one Realtime channel → authoritative first-page snapshot → inbox/Today badge stale·reconnect UX
- 계약: `docs/contracts/notification-center-sync.yaml.md`
- Workplan: `docs/evidence/phase-05/WP05_16_WORKPLAN.md`

## Implemented slice

- `public.notification_sync_watermarks(auth_user_id, generation, changed_at)` exact 3-column read-only table
- self-only forced RLS, authenticated SELECT-only grant, private security-definer monotonic writer, `supabase_realtime` publication
- statement-level inbox insert/update, preference insert/update, household member update and household update producers
- strict auth-user filter/projection parser that rejects extra content, wrong scope, non-positive generation and non-UTC timestamps
- one-channel `NotificationSyncSession` with connected-gap refetch, monotonic ordering, in-flight coalescing, reconnect/resume replacement and deterministic cancellation
- Notification Center authoritative first-page replacement, disconnected content retention, authorization purge and household-switch cleanup
- Today/Chores unread badge reuse of the same live snapshot while its route is mounted
- EN/KO/EN-XA stale copy and semantic reconnect action, including 200% text-scale coverage

## Automated evidence

| Gate | Command | Result |
|---|---|---|
| Clean local DB | `npm run supabase:reset` | PASS; 67 migrations including `20260810220000_notification_center_realtime_invalidation.sql` |
| Focused DB | `node_modules/.bin/supabase test db supabase/tests/database/notification_center_realtime_invalidation.test.sql` | PASS; 1 file / 42 tests |
| Focused Flutter | `flutter test --no-pub` for strict adapter, provider mapping, session, controller, existing controller and Notification Center widget | PASS; 30 tests |
| Full DB | `npm run supabase:test` | PASS; 68 files / 3,349 tests / failure 0 |
| DB lint | `supabase db lint --local --level error` | PASS; `app_private`, `extensions`, `public`, schema error 0 |
| Full Flutter | `flutter test --no-pub` | PASS; 1,424 tests / existing local-connectivity opt-in 1 skip / failure 0 |
| Flutter quality | `scripts/ci/flutter-quality.sh` with exact Flutter/Dart and offline pub | PASS; analyzer 0, formatter 738 files drift 0, public config valid, high-confidence secret finding 0 |
| Localization/codegen | `flutter gen-l10n`; generated-code verifier | PASS; EN/KO/EN-XA current, build runner wrote 0 outputs, 8 generated files current |
| Coverage | quality-gate LCOV summary | PASS; 30,240 / 37,715 lines, 80.18% |
| Repository Node | `node --test`; `npm run ci:test` | PASS; full Node 288 tests and CI-contract 157 tests, failure 0 |
| Workflow lint | `npm run ci:workflow`; `scripts/ci/actionlint.sh` | PASS; 6 jobs, 22 pinned action uses, `contents:read`, actionlint pass |
| Documentation | fenced YAML, matrices, Markdown fences and ARB JSON validation | PASS; 13 rectangular matrices, 439 balanced Markdown files, ARB JSON valid |
| Production Web | `scripts/ci/web-build.sh prod` | PASS; 6,486,772-byte `main.dart.js`, SHA-256 `b1f09f6bc6b8939b3fd5605a372b48cf1c7997e73d54bd11bd898d2dbbbe213b`; PWA manifest absent, service worker/cache disabled |
| Whitespace | `git diff --check` | PASS; output 0 |

All Flutter commands use Flutter SDK 3.44.7 stable with `DART_TOOL_HOME=/private/tmp/kinflow-dart-tool` and `CI=true`.

The single Flutter skip is the pre-existing opt-in local-connectivity test and is not a skipped WP05-16 assertion. The first full regression exposed an older Runtime Policy test harness that constructed the now user-scoped notification provider without its auth graph; the harness was isolated with an explicit Notification Center controller, its focused regression passed 9/9, and the complete suite then passed.

## Security and privacy evidence

- Realtime storage contains only the current user's already-known auth UUID plus positive generation and UTC change time.
- RLS continues to expose a removed member's own signal long enough for the client to refetch, receive the existing not-found-or-forbidden result and purge the previously readable snapshot.
- another authenticated user and anonymous clients cannot read the row; authenticated/service roles cannot invoke the private writer or mutate the table.
- notification preference and inbox content tables are not added to the Realtime publication.
- malformed provider frames become a disconnected state without raw payload, provider exception, household, member, item, category or content exposure.

## Deferred manual evidence

- hosted Supabase Realtime propagation and RLS timing
- real-account and two-device concurrent preference/read/materialization flows
- Android physical-device foreground/background/network transitions
- app-shell global subscription and five-destination badge were completed locally by WP05-17; operating-system suspended-process execution remains deferred
- actual Firebase, SendGrid, mailbox and device delivery

These are intentionally deferred to the final live-account/device Gate per the feature-first instruction.

## Rollback

- set `notificationSyncRepositoryProvider` to `null` or remove its composition to retain existing initial/manual snapshot reads without Realtime.
- remove the watermark from `supabase_realtime`, then remove producer triggers, private helpers, policy and table in that order.
- the table is derived content-free metadata; rollback does not delete preferences, inbox items, unread state, source events, provider queues or delivery history.
