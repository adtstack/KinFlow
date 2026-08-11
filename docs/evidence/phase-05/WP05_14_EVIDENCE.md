# Phase 05 WP05-14 Generic Notification Email Fallback Evidence

- Work Package: WP05-14 — confirmed-account generic notification email fallback
- 기준 commit: base `a85f262`; implementation은 2026-08-10 현재 연속 dirty workspace
- 검증일: 2026-08-10
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase
- 결과: **LOCAL AUTOMATED PASS / HOSTED·SENDGRID·REAL-ACCOUNT·MAILBOX·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-14 / FR-NOTIF-008 / D-069 | PASS FOR LOCAL SLICE / OVERALL PARTIAL | 기본 OFF category email을 inbox·push와 독립적으로 설정하고 confirmed Auth address에 fixed generic EN/KO 알림을 보내는 local vertical slice를 구현했다. Web Push와 hosted live delivery는 남았다. |
| FR-NOTIF-003–006 / D-022 / D-023 | PASS FOR LOCAL PIPELINE | 기존 content-free source, exact recipient, latest-state, quiet-hours, one-hour usefulness window와 durable inbox authority를 재사용한다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | email은 service-only claim부터 한 provider call까지 일시적으로만 존재한다. queue·transition·log·evidence에는 address/content/provider body/raw error가 없고 optional receipt는 SHA-256만 저장한다. |
| NFR-REL-01 | PASS FOR LOCAL STATE MACHINE | one-source-one-delivery, lease, marker-before-I/O, explicit retry, terminal ambiguity, bounded expiry와 kill switch를 deterministic DB/Node tests로 검증했다. |
| NFR-I18N-01 / NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | fixed EN/KO provider copy, EN/KO/EN-XA client copy, 48dp switch와 scrollable 200% editor가 통과했다. 실제 screen reader/phone/tablet은 남았다. |

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local database reset | PASS — 64 ordered migrations including `20260810190000_notification_email_fallback.sql` applied; seed and private Storage bucket restored |
| focused WP05-14 pgTAP | PASS — 68/68 |
| full database regression | PASS — 65 files, 3,265 tests, failure 0 |
| database lint | PASS — `app_private,public`, schema error 0 |
| focused email sender/worker Node contract | PASS — 13/13 |
| repository Node contracts | PASS — 154/154 |
| focused notification center Flutter widget | PASS — 10/10 |
| localization contract | PASS — 4/4 |
| full Flutter regression | PASS — 1,361 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — fatal info/warning enabled, issue 0 |
| Dart formatter | PASS — 699 files checked, drift 0 |
| localization and generated code | PASS — generated localization current; build runner wrote 0 outputs; 8 generated files current |
| public configuration and secret scan | PASS — examples valid/allowlisted; high-confidence finding 0 |
| CI workflow contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| documentation structure | PASS — 69 fenced YAML contracts parse; 13 matrices rectangular with declared counts; API 56×6, requirements 127×18, tests 98×11, time 48×12 |
| line coverage | PASS — 29,587/36,943, 80.09% |
| Android dev APK | PASS — 219,944,403 bytes; SHA-256 `d690d4c9f15effe376ddd8576612edf044effc9cb9ee0e79fad7589efef9acd4` |
| whitespace | PASS — `git diff --check` output 0 at final handoff |

The Android build retains the existing non-blocking Kotlin Gradle plugin compatibility warning from `purchases_flutter`/`sentry_flutter`; it did not change this feature's dependencies or build result.

## Contract Evidence

- `notification_preferences.email` remains the existing category-scoped boolean, defaults OFF and is independent of inbox and Android push. Existing exact v1/v2/v3 preference shapes remain unchanged.
- every candidate rechecks current occurrence state/version, active exact recipient, latest email preference and confirmed Auth address. Chore due/assignment and Calendar reminder categories are allowed; marketing/digest/arbitrary content are not.
- recipient email is selected from `auth.users` only inside `claim_notification_email_deliveries` and returned in its exact 15-key service response. No private delivery, transition, audit, log or evidence field persists it.
- the queue persists only source/inbox/recipient/household/subject IDs, category, scheduling state, stable result code and optional 32-byte provider receipt hash. Family names, titles, descriptions, display times, deep links, provider bodies and raw errors are absent.
- recipient-local quiet hours and DST-aware resolution run before delivery. The source remains useful for at most one hour; expired claims and retries are cancelled without provider submission.
- the worker records the exact lease submission marker before network I/O. A post-marker network ambiguity becomes terminal `EMAIL_SUBMISSION_AMBIGUOUS` and is not replayed automatically.
- SendGrid uses one fixed `POST https://api.sendgrid.com/v3/mail/send` request with Bearer API key, one ephemeral recipient, configured sender and fixed plain-text EN/KO copy. HTML, attachment, custom args, IDs and deep links are forbidden.
- HTTP `202` is accepted submission. Only `429/500/502/503/504` receive the fixed `60/300/1800/7200` second retry schedule within five total attempts; every other completed response is terminal.
- the Edge Function accepts only a query-free, body-free POST authenticated by a dedicated exact Bearer secret and returns seven aggregate counts plus contract version. Raw claims, addresses, secrets and provider errors are neither returned nor logged.
- optional SendGrid `X-Message-Id` is never stored raw; the worker passes only its SHA-256 digest to completion.

## Manual and Deferred Validation

- hosted migration/grants and scheduler cadence: **NOT RUN**.
- SendGrid API authentication, verified sender/domain, reputation, quota and activity feed: **NOT RUN**.
- real mailbox acceptance, delivery latency, spam-folder placement, account email change/reconfirmation and bounce behavior: **NOT RUN**.
- adult real accounts, two-device preference race and household switching: **NOT RUN**.
- Android physical-device notification center, TalkBack, real phone/tablet 200% text and timezone/DST travel timing: **NOT RUN**.
- Web Push, email deep links, marketing/digest, arbitrary templates, HTML, attachments and unsubscribe campaigns remain outside this slice.

## Files and Impact

- Contract/traceability: `notification-email-fallback.yaml.md`, D-069, FR-NOTIF-008, API-056, Phase 05 WP05-14, API/requirements/test/time/spec/platform matrices, master/changelog and notification design references
- Database: `supabase/migrations/20260810190000_notification_email_fallback.sql`, `supabase/tests/database/notification_email_fallback.test.sql`
- Edge: `supabase/functions/notification-email-worker/`, `_shared/notification_email_contract.mjs`, `_shared/notification_email_runtime.mjs`, `supabase/config.toml`, `scripts/ci/notification-email-contract.test.mjs`
- Presentation: `notification_center_screen.dart`, EN/KO/EN-XA ARBs/generated localization and notification center widget tests
- Public/client table, preference RPC version, event payload/type, provider SDK, Android permission, native manifest, persistent client cache, analytics event/property and app deep-link delta: **none**

## Remaining Risks and Completion Boundary

1. SendGrid `202` proves provider submission acceptance, not mailbox delivery, inbox placement or user read.
2. marker-before-I/O intentionally favors at-most-once behavior. A rare post-marker ambiguous request may have been delivered even though KinFlow records no accepted receipt, so automatic replay is prohibited.
3. sender/domain authentication, reputation, quota, throttling and bounce policy remain unknown until the final hosted Gate.
4. generic privacy-preserving copy intentionally has no household context or deep link; the user must open KinFlow and use the durable inbox.
5. local timezone and clock-controlled tests cover deterministic boundaries, while actual travel/DST/provider latency still require the final real environment Gate.

WP05-14 자체는 local synthetic server/Android slice로 완료했다. FR-NOTIF-008 전체와 운영 email 신뢰성의 최종 판정은 사용자 지시에 따라 기능 개발 이후 실계정·mailbox·두 기기·실기기 Gate에 유지한다.

## Commands

```text
npx --no-install supabase db reset
npx --no-install supabase test db supabase/tests/database/notification_email_fallback.test.sql
npx --no-install supabase test db supabase/tests/database
npx --no-install supabase db lint --local --schema app_private,public --level warning --fail-on error
node --test scripts/ci/notification-email-contract.test.mjs
flutter test --no-pub test/features/notifications/presentation/notification_center_widget_test.dart
flutter test --no-pub test/localization/localization_contract_test.dart
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/flutter-quality.sh
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/android-build.sh dev
Ruby YAML/Markdown/matrix structure checks
git diff --check
```

## Rollback

- call `set_notification_email_worker_paused(true, ...)` before further provider I/O and keep pending/retry state for inspection.
- hide the client switch or write only `email=false` while preserving inbox, push, quiet hours, timezone and Calendar reminder settings.
- retain accepted, failed and ambiguous terminal history; do not delete or replay it during rollback.
- replace the provider adapter and server secrets through a forward change without changing the preference or source contracts.
