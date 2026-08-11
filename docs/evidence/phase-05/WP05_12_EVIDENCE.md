# Phase 05 WP05-12 Calendar Notification Snooze Evidence

- Work Package: WP05-12 — bounded Calendar notification Snooze and existing delivery-path reuse
- 기준 commit: base `a85f262`; implementation은 2026-08-10 현재 연속 workspace
- 검증일: 2026-08-10
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-12 / FR-NOTIF-011 / D-067 | PASS FOR LOCAL SLICE / OVERALL PARTIAL | Calendar inbox에서 fixed 5/10/30분, 연속 최대 3회, occurrence 시작 후 1시간 bound를 서버 권위로 구현하고 전체 local regression을 통과했다. |
| FR-NOTIF-003–006 / D-018 / D-022 / D-023 | PASS FOR LOCAL PIPELINE | 원본 inbox/pending push를 원자적으로 supersede하고 content-free source를 기존 latest-state, inbox, quiet-hours, Android endpoint와 reliable delivery 경로로 보낸다. |
| D-048 / NFR-REL-01 | PASS FOR LOCAL COMMAND SAFETY | optimistic item version, caller UUID, advisory lock, immutable receipt와 same-key replay/different-payload collision을 검증했다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | active self membership, exact recipient/participant, private grant-free ledger가 권위다. 가족 content, token, email과 provider 원문을 새 payload·log·analytics에 추가하지 않았다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | scrollable fixed-choice sheet, 48dp action, EN/KO/EN-XA 30% expansion과 200% text-scale reachability가 focused/full Flutter 회귀를 통과했다. 실제 TalkBack/phone/tablet은 남았다. |

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local database reset | PASS — 62 ordered migrations including `20260810170000_calendar_notification_snooze.sql` applied; seed and private Storage bucket restored |
| focused WP05-12 pgTAP | PASS — 47/47 |
| affected notification/Calendar DB regression | PASS — 7 files, 405 tests |
| full database regression | PASS — 63 files, 3,147 tests, failure 0 |
| database lint | PASS — `app_private,public`, schema error 0 |
| focused notification/data Flutter suite | PASS — 27/27 |
| targeted notification widget and localization | PASS — 8 widget tests plus 4/4 localization contract; EN-XA new messages exceed 30% expansion |
| architecture and runtime-policy guards | PASS — 18/18 |
| full Flutter regression | PASS — 1,358 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — fatal info/warning enabled, issue 0 |
| Dart formatter | PASS — 699 files checked, drift 0 |
| localization and generated code | PASS — localization regenerated; build runner wrote 0 outputs; 8 generated files current |
| public configuration and secret scan | PASS — examples valid/allowlisted; high-confidence finding 0 |
| repository Node contracts | PASS — 141/141 |
| CI workflow contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| documentation structure | PASS — 68 fenced YAML contracts parse; 13 matrices rectangular with declared counts; API 54×6, requirements 126×18, tests 96×11, time 46×12 |
| Android dev APK | PASS — 219,938,243 bytes; SHA-256 `072def2f88cfb69c218bfe343ad2a21f22cdafdd8a34856dd588df527b75101b` |
| whitespace | PASS — `git diff --check` output 0 at final handoff |

The first combined full-DB attempt accidentally left overlapping `pg_prove` containers against the same local test database. Those results were discarded, the exact orphan test containers were stopped, and a clean reset preceded the definitive single-run 63-file/3,147-test PASS above. No product failure was waived.

## Contract Evidence

- v1 inbox RPC remains callable and exact; v2 returns exactly 16 keys including bounded Snooze metadata.
- the command returns exactly 9 keys and validates command echo, original item, fixed minutes, count and `recorded_at + minutes = snoozed_until`.
- the original item becomes read/cancelled with `snoozed`, its authoritative unread count falls immediately, and only pending/retry/leased source deliveries are cancelled.
- a new exact 9-key `calendar.occurrence_reminder_snoozed` event is not materialized or claimed early and becomes eligible through the existing workers at its explicit schedule.
- changing personal reminder lead after Snooze does not move the explicit schedule.
- response-loss retry with the same command UUID returns the stored receipt without a second source; mismatched reuse fails closed.

## Manual and Deferred Validation

- hosted migration/grants, scheduler cadence, actual Firebase provider, adult real account and two-device timing/race: **NOT RUN**.
- Android physical-device permission, foreground/background/terminated delivery, shade/tap, OEM battery policy and timezone/DST travel: **NOT RUN**.
- TalkBack, real phone/tablet 200% font and long pseudo copy: **NOT RUN**.
- iOS/APNs, Web Push, arbitrary Snooze duration and persistent Snooze history remain outside this slice. Multiple reminder rules are implemented separately by WP05-13.

## Files and Impact

- Contract/traceability: `calendar-notification-snooze.yaml.md`, D-067, FR-NOTIF-011, Phase 05 WP05-12, API/requirements/test/time/spec matrices and master/changelog references
- Database: `supabase/migrations/20260810170000_calendar_notification_snooze.sql`, schema/domain-event/error contracts, `calendar_notification_snooze.test.sql` and compatible existing producer/inbox contract assertions
- Domain/data: notification Snooze command ID, bounded inbox metadata, receipt, repository/data-source ports and strict Supabase adapter
- Presentation: Calendar-only fixed-choice sheet, immediate item/badge reconciliation, failure copy, EN/KO/EN-XA ARBs and generated localization
- Tests: notification domain/repository/controller/widget, strict Supabase parser, runtime-policy/architecture guards and shared fake updates
- Edge Function, FCM provider request, native permission, dependency, secret, analytics property and persistent client cache delta: **none**

## Remaining Risks and Completion Boundary

1. local transaction and worker tests prove source replacement, pre-due suppression and due materialization, but hosted scheduler/provider timing remains unobserved.
2. server `statement_timestamp()` is schedule authority; real-device clock skew does not affect the command, but notification-shade timing and OEM delay remain device risks.
3. explicit Snooze survives later lead preference changes by design. User understanding of this distinction requires Beta observation.
4. v2 removal requires N-1 retirement; immutable receipt and terminal delivery history must not be rewritten during rollback.

WP05-12 자체는 local synthetic Android/server slice로 완료했다. 운영 알림 신뢰성의 최종 판정은 사용자 지시에 따라 실계정·두 기기·실기기 검증을 기능 개발 이후 마지막 Gate에 유지한다.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_notification_snooze.test.sql
npx supabase test db <seven affected notification/Calendar files>
npx supabase test db supabase/tests/database
npx supabase db lint --local --schema app_private,public --level warning --fail-on error
flutter gen-l10n
flutter test --no-pub <focused notification/data/guard/localization paths>
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/android-build.sh dev
Ruby YAML/Markdown/matrix structure checks
git diff --check
```

## Rollback

- hide the client action and return inbox reads to v1.
- retain immutable command/source/evaluation history; do not delete already queued valid reminders.
- remove v2/event/ledger support only through a forward migration after released v2 clients retire.
