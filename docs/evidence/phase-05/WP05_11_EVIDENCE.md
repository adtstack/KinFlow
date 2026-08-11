# Phase 05 WP05-11 Per-user Calendar Reminder Lead Time Evidence

- Work Package: WP05-11 — 사용자·가구별 Calendar 알림 선행 시간과 미평가 schedule 재계산
- 기준 commit: base `a85f262`; implementation은 2026-08-10 현재 연속 workspace
- 검증일: 2026-08-10
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-11 / FR-NOTIF-010 / D-064 | PASS FOR LOCAL SLICE / OVERALL PARTIAL | 사용자는 가구별 자신의 Calendar 알림을 정시·5·10·15·30·60분 전 중 하나로 선택한다. timed와 all-day, 두 참여자의 서로 다른 lead와 default 0분을 자동 검증했다. |
| FR-NOTIF-001 / FR-NOTIF-003–006 / D-019 / D-020 | PASS FOR LOCAL SCHEDULING | timed start 또는 household-local 09:00 base에서 lead를 먼저 뺀 뒤 quiet hours를 적용하고, 기존 1시간 usefulness window를 reminder instant부터 유지한다. |
| D-022 / D-023 / NFR-REL-01 | PASS FOR LOCAL COMPATIBILITY | source `scheduledAt`과 멱등 payload는 base instant를 유지한다. v1 exact 12-key API와 기존 lead 보존, v2 exact 13-key API, pending-only reschedule과 evaluated history 동결을 검증했다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | active self-membership과 기존 forced RLS가 권위이며 helper 실행은 private다. lead, 일정 제목·설명·사용자 식별자와 provider 원문을 payload·log·analytics에 추가하지 않았다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | Calendar editor 전용 selector, 요약과 pending-only 도움말을 EN/KO/EN-XA ARB로 제공한다. pseudo-locale 30% 확장 계약도 통과했다. 실제 TalkBack·폰트 확대는 남았다. |

## Scheduling and Compatibility Contract

- `notification_preferences.reminder_lead_minutes`는 non-null integer이고 기본값은 0이다. 허용값은 `0, 5, 10, 15, 30, 60`이며 Chore category는 0만 허용한다.
- timed occurrence는 `starts_at`, all-day occurrence는 현재 household IANA timezone의 local date 09:00을 base instant로 사용한다.
- exact audience member가 연결된 auth user의 Calendar preference만 읽는다. 같은 occurrence의 다른 참여자 preference는 현재 recipient schedule에 영향을 주지 않는다.
- latest-state resolver는 delivery `dueAt`만 `base - lead`로 계산한다. source payload freshness는 계속 base `scheduledAt`과 비교하므로 outbox payload와 dedupe identity는 변하지 않는다.
- quiet-hours 계산은 lead subtraction 뒤에 수행한다. 기존 provider usefulness window는 최종 personal reminder instant부터 한 시간이다.
- 기존 `get_notification_preferences(uuid)`와 `update_notification_preference(...)`의 signature 및 exact 12-key 결과를 유지한다. v1 update는 저장된 lead를 덮어쓰지 않고 신규 row는 default 0을 받는다.
- Flutter는 `get_notification_preferences_v2`와 `update_notification_preference_v2`를 사용하며 exact 13-key DTO와 실제 integer만 허용한다. missing/extra key와 bool/double/string coercion은 fail closed한다.

## Pending-only Reconciliation

1. Calendar preference가 실제로 바뀌면 현재 사용자에게 속한 future candidate resolution만 선택한다.
2. inbox evaluation이 없고 push evaluation이 없거나 `pending`인 source만 새 personal reminder instant로 이동한다.
3. 같은 트랜잭션에서 기존 pending push의 `next_evaluation_at`도 resolution schedule과 맞춘다.
4. inbox가 평가됐거나 push가 materialized/disabled/stale/no-endpoint 등 non-pending 상태면 저장된 resolution schedule을 유지한다.
5. 이후 latest-state resolve도 평가 이력 존재 여부를 확인해 기존 schedule을 반환하므로 이미 표시·발송·억제된 알림을 철회하거나 재전송하지 않는다.
6. 동일값 update는 version과 schedule을 올리지 않고, stale changed write는 기존 optimistic conflict로 거부한다.

## Client Surface

- domain preference는 Calendar 고정 option set과 Chore zero-only invariant를 강제한다.
- repository와 Supabase adapter는 lead를 v2 parameter에 전달하고 malformed default/non-integer response를 거부한다.
- Calendar notification card만 `Remind me / 미리 알림` selector를 보인다. Chore 편집기에는 selector가 없다.
- card summary는 현재 lead를 표시하고 editor help는 아직 전달되지 않은 reminder에만 변경이 적용됨을 알린다.
- channel, quiet hours, timezone, expected version/conflict recovery와 runtime-policy mutation Gate는 기존 흐름을 그대로 사용한다.
- 새 package, native permission, persistent local storage, analytics property와 Edge provider surface는 없다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local database reset | PASS — ordered migrations including `20260810140000_calendar_reminder_lead_time.sql` applied |
| focused WP05-11 pgTAP | PASS — 45/45 |
| existing notification/Calendar reminder regression | PASS — 131/131 |
| full database regression | PASS — 60 files, 2,996 tests, failure 0 |
| database lint | PASS — `app_private,public`, schema error 0 |
| focused notification/data Flutter suite | PASS — 51 tests |
| targeted notification widget suite | PASS — 6 tests |
| localization contract | PASS — 4/4, exact key coverage and EN-XA 30% expansion |
| full Flutter regression | PASS — 1,339 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — fatal info/warning enabled, issue 0 |
| Dart formatter | PASS — 699 files checked, drift 0 |
| localization and generated code | PASS — generated localization current; build runner wrote 0 outputs; 8 generated files current |
| public configuration and secret scan | PASS — examples valid/allowlisted; high-confidence finding 0 |
| repository Node contracts | PASS — 141/141 |
| CI workflow contract | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| documentation structure | PASS — 64 fenced YAML contracts parse; 13 matrices rectangular with declared counts; API 51×6, requirements 123×18, tests 93×11, time 43×12 |
| Android dev APK | PASS — 219,891,726 bytes; SHA-256 `f199937f69f74c2d34494aabb71d674aa5551dafa28d9b8dd8f65887361090d0` |
| whitespace | PASS — `git diff --check` output 0 at final handoff |

The first full Flutter run exposed only the new EN-XA lead-option string below the repository's 30% layout-pressure threshold. The pseudo copy was expanded, localization regenerated, the focused contract passed 4/4, and the complete suite then passed 1,339 with the existing opt-in skip.

## Files and Impact

- Contract/traceability: `calendar-reminder-lead-time.yaml.md`, D-064, FR-NOTIF-010, Phase 05 WP05-11, API/requirements/test/time/spec matrices and master/changelog references
- Database: `supabase/migrations/20260810140000_calendar_reminder_lead_time.sql`, schema contract and `calendar_reminder_lead_time.test.sql`; existing notification preference test updated for additive schema and exact v1 shape
- Domain/data: notification preference entity, data-source port, provider repository and strict Supabase v2 adapter
- Presentation: notification center Calendar-only selector/summary/help, EN/KO/EN-XA ARBs and generated localization
- Tests: notification domain/repository/controller/widget, strict Supabase DTO and shared fake updates
- Edge Function, source outbox payload, provider request, native permission, dependency and local cache delta: **none**

## Security and Privacy Boundary

- authenticated active household membership is checked inside security-definer RPCs; direct table writes remain unavailable and existing forced RLS remains authoritative.
- private schedule helpers are revoked from public, anon, authenticated and service-role execution. Workers reach them only through fixed database functions.
- exact source event and immutable audience member identify the recipient. Another household or participant cannot select or mutate the current user's preference/schedule.
- content-free outbox payload remains unchanged. No title, description, household/member name, email, token, lead preference or raw provider response is newly logged, persisted in analytics or sent to FCM.
- malformed v2 response maps and category/lead combinations fail closed before presentation or mutation.

## Manual and Deferred Validation

- 사용자 지시에 따라 hosted migration/grants, scheduler cadence, 실제 Firebase provider, 성인 실계정과 두 기기 timing/race는 **NOT RUN**이다.
- Android physical-device notification permission, foreground/background/terminated delivery, notification shade/tap, OEM battery policy와 device timezone/DST 이동은 **NOT RUN**이다.
- phone/tablet 200% font, TalkBack/keyboard focus와 long pseudo copy의 실제 화면 layout은 **NOT RUN**이다.
- iOS/APNs, Web Push, 복수 reminder와 category-specific visible copy는 이 WP 완료 시점의 범위 밖이었다. bounded Snooze는 WP05-12, 복수 reminder는 WP05-13에서 이 증거와 분리해 구현했다.

## Remaining Risks and Completion Boundary

1. local transaction tests는 preference update와 worker evaluation 경계를 고정하지만 hosted scheduler와 실제 두 프로세스 race의 관찰 증거는 남아 있다.
2. 일정 시작까지 남은 시간보다 큰 lead로 변경하면 새 reminder instant가 과거가 되어 다음 worker batch에서 즉시 처리 대상이 된다. 계약상 결정적이지만 실제 사용자 인지는 Beta에서 확인해야 한다.
3. all-day 09:00, DST와 quiet-hours 순서는 synthetic timezone fixture로 통과했지만 기기 timezone 이동 및 실제 provider 수신 시간은 남아 있다.
4. v2 client가 출시된 뒤 rollback은 모든 v2 client retirement 전까지 API/column을 유지하는 forward-only 절차가 필요하다.
5. 한 일정에 여러 reminder 또는 snooze가 필요한지는 Beta 사용성·불만 신호로 판단한다.

WP05-11 자체는 local synthetic Android/server slice로 완료했다. 운영 알림 신뢰성의 최종 판정은 사용자 지시에 따라 실계정·두 기기·실기기 검증을 기능 개발 이후 마지막 Gate에 유지한다.

## Rollback

- client는 selector를 숨기고 v1 preference RPC로 복귀할 수 있다. 기존 default row는 즉시 start-time behavior를 유지한다.
- server는 v2로 Calendar lead를 0으로 되돌린 뒤 pending resolution/push schedule을 base instant로 재계산하는 forward migration을 배포한다.
- 출시된 v2 client가 남아 있는 동안 v2 RPC나 column을 제거하지 않는다. 제거는 N-1 retirement 뒤 forward migration으로만 수행한다.
- immutable inbox/push evaluation과 delivery history는 삭제·수정하지 않는다.

## Commands

```text
npx supabase db reset
npx supabase test db supabase/tests/database/calendar_reminder_lead_time.test.sql
npx supabase test db <existing notification/Calendar reminder regressions>
npx supabase test db
npx supabase db lint --local --schema app_private,public --level warning --fail-on error
flutter gen-l10n
flutter test --no-pub <focused notification/data paths>
flutter test --no-pub test/features/notifications/notification_center_widget_test.dart
flutter test --no-pub test/localization/localization_contract_test.dart
flutter test --no-pub --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
npm run ci:workflow
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> scripts/ci/android-build.sh dev
Ruby YAML/Markdown/matrix structure checks
git diff --check
```
