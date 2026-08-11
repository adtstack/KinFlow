# Phase 05 WP05-13 Per-user Calendar Multiple Reminders Evidence

- Work Package: WP05-13 — one primary plus up to two additional per-user Calendar reminders
- 기준 commit: base `a85f262`; implementation은 2026-08-10 현재 연속 workspace
- 검증일: 2026-08-10
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-13 / FR-NOTIF-012 / D-068 | PASS FOR LOCAL SLICE / OVERALL PARTIAL | 개인·가구별 Calendar 기본 알림 1개와 distinct fixed 추가 알림 최대 2개를 전체 local regression으로 검증했다. |
| FR-NOTIF-003–006 / D-018 / D-022 / D-023 | PASS FOR LOCAL PIPELINE | 각 선택 시간은 독립 content-free source로 기존 latest-state, quiet-hours, durable inbox, Snooze와 reliable Android push 경로를 재사용한다. |
| FR-NOTIF-010–011 / D-064 / D-067 | PASS FOR COMPATIBILITY | v1은 기본·추가를 보존하고 v2는 기본만 편집하며, Snooze explicit schedule은 preference 변경과 분리된다. |
| NFR-REL-01 | PASS FOR LOCAL RECONCILIATION | 새 시간은 future-only로 추가하고 removed source는 stale 처리하며 unevaluated resolution/pending push만 이동하고 평가 이력은 동결한다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | active self membership과 exact recipient가 권위이며 기존 exact 5-key source payload에 content나 lead를 추가하지 않았다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | bounded checkbox editor, scrollable dialog, EN/KO/EN-XA와 compact 200% text-scale reachability가 통과했다. 실제 TalkBack/phone/tablet은 남았다. |

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local database reset | PASS — 63 ordered migrations including `20260810180000_calendar_multiple_reminders.sql` applied; seed and private Storage bucket restored |
| focused WP05-13 pgTAP | PASS — 50/50 |
| affected preference/source compatibility regression | PASS — 2 files, 164 tests |
| existing Calendar lead and Snooze regression | PASS — 2 files, 92 tests |
| full database regression | PASS — 64 files, 3,197 tests, failure 0 |
| database lint | PASS — `app_private,public`, schema error 0 |
| focused WP05-13 Flutter suite | PASS — 30/30 domain, strict DTO, repository, controller and widget tests |
| full Flutter regression | PASS — 1,360 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — fatal info/warning enabled, issue 0 |
| Dart formatter | PASS — 699 files checked, drift 0 |
| localization and generated code | PASS — localization regenerated; build runner wrote 0 outputs; 8 generated files current |
| public configuration and secret scan | PASS — examples valid/allowlisted; high-confidence finding 0 |
| repository Node contracts | PASS — 141/141 |
| CI workflow contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| documentation structure | PASS — 69 fenced YAML contracts parse; 13 matrices rectangular with declared counts; API 55×6, requirements 127×18, tests 97×11, time 47×12 |
| Android dev APK | PASS — 219,942,120 bytes; SHA-256 `1082f9ac0d3a85eb5d03939883c8198a425a630b8e3a2927abbd7b05eaf1fade` |
| whitespace | PASS — `git diff --check` output 0 at final handoff |

The first Android build attempt inside the restricted sandbox could not open the existing Gradle wrapper cache lock. The same exact offline build command passed after granting access to that cache; no product code or dependency version changed between attempts.

## Contract Evidence

- Calendar preference is one fixed primary plus zero-to-two sorted, distinct fixed additional leads; Chore categories reject additional values.
- additive v3 returns exactly 14 keys and accepts a real integer list only. Missing, extra, coerced, duplicate, unsorted, unsupported and over-limit input fails closed.
- v1 exact 12-key read/write preserves the full set. v2 exact 13-key changes only the primary and removes only an extra promoted to primary.
- the existing `calendar.occurrence_start_changed` exact 5-key payload remains content-free. A private nullable lead column distinguishes primary and additional sources without exposing lead in the payload.
- the occurrence trigger and 32-day horizon create one independently deduped source per selected lead and recipient.
- setting reconciliation never sends a newly selected reminder whose instant has passed. It updates only candidate resolution or pending push and never rewrites evaluated inbox or terminal push history.
- removing an additional lead preserves immutable source history but makes unevaluated work stale through latest-state resolution.
- sequentially due reminders retain independent evaluations while only the latest item for the occurrence remains active in the inbox.

## Manual and Deferred Validation

- hosted migration/grants, scheduler cadence, actual Firebase provider, adult real accounts and two-device timing/race: **NOT RUN**.
- Android physical-device permission, foreground/background/terminated delivery, shade/tap, OEM battery policy and timezone/DST travel: **NOT RUN**.
- TalkBack, real phone/tablet 200% font and long pseudo copy: **NOT RUN**.
- arbitrary lead input, more than three reminders, per-occurrence override, iOS/APNs and Web Push remain outside this slice.

## Files and Impact

- Contract/traceability: `calendar-multiple-reminders.yaml.md`, D-068, FR-NOTIF-012, Phase 05 WP05-13, API/requirements/test/time/spec matrices and master/changelog references
- Database: `supabase/migrations/20260810180000_calendar_multiple_reminders.sql`, `calendar_multiple_reminders.test.sql` and compatible existing preference/source assertions
- Domain/data: immutable additional lead set, strict v3 DTO, repository/data-source ports and Supabase adapter
- Presentation: primary dropdown, bounded additional checkboxes, all-timing summary, scrollable 200% editor and EN/KO/EN-XA localization
- Edge Function, event type, provider request, native permission, dependency, secret, analytics property and persistent client cache delta: **none**

## Remaining Risks and Completion Boundary

1. local transactions and workers prove independent scheduling, dedupe and reconciliation, but hosted scheduler/provider latency remains unobserved.
2. latest preference suppresses removed future sources; an already displayed or terminally submitted reminder is immutable by design.
3. v3 client rollback to v2 preserves extras but cannot edit them. v3 removal therefore waits until every released v3 client retires.
4. real timezone/DST travel and OEM delivery behavior require the final physical-device Gate.

WP05-13 자체는 local synthetic Android/server slice로 완료했다. 운영 알림 신뢰성의 최종 판정은 사용자 지시에 따라 실계정·두 기기·실기기 검증을 기능 개발 이후 마지막 Gate에 유지한다.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_multiple_reminders.test.sql
npx supabase test db <affected preference/source and existing lead/Snooze files>
npx supabase test db supabase/tests/database
npx supabase db lint --local --schema app_private,public --level warning --fail-on error
flutter gen-l10n
flutter test --no-pub <focused notification domain/data/controller/widget paths>
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

- return the client to v2 so only the primary remains editable while the server preserves extras.
- stop v3 exposure only after released v3 clients retire; retain immutable sources and evaluations.
- remove the additive preference/source identity only through a forward migration after compatibility retirement.
