# Phase 04 WP04-12 Calendar Monthly Start-Date Anchor Evidence

- Work Package: WP04-12 — monthly Calendar start-date anchor synchronization
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CAL-004 | PASS FOR LOCAL AUTOMATED SLICE | Monthly Calendar 생성은 event local start-date day를 locked `monthDay`로 표시하고 동일한 full rule을 overlap preview와 create request에 전달한다. |
| FR-CAL-006 | PASS FOR LOCAL AUTOMATED SLICE | 전체 시리즈에서 start date를 바꾸면 stale active `monthDay`를 새 일자로 교체하면서 interval/end를 보존해 update request에 전달한다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | start date와 derived `monthDay` 변경은 recurring draft fingerprint와 command key를 회전하고 exact retry는 기존 key 재사용 계약을 유지한다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | Monthly 기준일은 expanded disabled form control, anchor helper와 live summary로 표시되며 320×568 EN-XA 200%에서 overflow 없이 scroll된다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | month-day label/options, anchor와 missing-date helper, editor/card summary를 EN/KO/EN-XA ARB로 제공하고 exact coverage와 pseudo expansion을 통과했다. |
| D-019 / D-020 | PASS FOR CLIENT TIME BOUNDARY | locale display와 무관한 integer `monthDay`를 edited event local date에서 파생하며 기존 server local-date/time authority를 유지한다. |

이 결과는 기존 server-enforced `monthDay == local_start_date.day` 계약을 Calendar
editor 전체에 일관되게 연결한 local automated slice에 한정한다. hosted Supabase, 실제
계정, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 통합 Gate에 남긴다.

## Defect and Compatibility Boundary

- 기존 whole-series editor는 active monthly rule의 frequency가 유지되면
  `tryWithIntervalAndEnd`로 old `monthDay`를 그대로 복사했다.
- 사용자가 start date를 day 7에서 day 15로 바꾸면 event는 15일이지만 rule은
  `monthDay: 7`로 남았다. 이 값은 overlap preview draft와
  `RecurringCalendarEventDraft.tryCreate`의 start-anchor 검증에서 거부되고 기존
  create/update RPC에서도 거부되는 상태였다.
- WP04-12는 schema를 확장하지 않고 monthly 전용 `tryWithMonthlyStartDate`를 추가했다.
  factory는 monthly frequency와 interval/end bounds를 닫고 current edited local date의
  day만 canonical `monthDay`로 만든다.
- `_editedRecurrenceRule`은 create, overlap preview와 save가 공유하는 단일 경계이므로
  monthly create, 같은-frequency whole-series edit, changed-to-monthly와 frequency
  round-trip이 모두 같은 re-anchor 경로를 사용한다.
- daily/weekly wire shape, single occurrence exception, server-authoritative effective date,
  immutable revision과 expected-version 동작은 바뀌지 않았다.

## Presentation Behavior

- Monthly 선택 시 1~31 localized option을 가진 expanded dropdown으로 current event
  start-date day를 표시한다. 서버 계약상 독립 선택은 허용되지 않으므로 control은 잠긴다.
- start date가 바뀌면 keyed control과 live summary가 즉시 새 day를 표시한다.
- anchor helper는 start date가 값을 소유한다고 설명하고, 별도 helper는 해당 날짜가 없는
  달을 마지막 날로 옮기지 않고 건너뛴다고 설명한다.
- editor live region은 selected day를 표시하고 recurring event card도 interval pattern과
  month day를 함께 표시한다.
- KO 문구와 expanded EN-XA pseudo 문구는 ARB와 generated localization을 통해서만
  제공한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Calendar domain/controller/widget suite | PASS, 63 tests total |
| monthly factory day 7→15 re-anchor, interval/end preservation | PASS |
| non-monthly and invalid-until factory rejection | PASS |
| recurring create locked day, start-date update and exact full-rule preview/create mapping | PASS |
| same-frequency whole-series day 7→15 preview/update re-anchor | PASS |
| whole-series interval 2 and count 10 preservation | PASS |
| changed frequency round-trip derives current start date | PASS |
| monthly start-anchor command-key rotation and existing exact retry reuse | PASS |
| localized editor/card summary and missing-date policy | PASS |
| compact EN-XA 200% locked control and helper overflow regression | PASS |
| localization exact coverage and pseudo expansion | PASS, 4/4 |
| full Flutter regression | PASS, 1,004 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 574 files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 136/136 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, contract 12 root keys; 13 matrices; requirements 116×18; tests 74×11; time 38×12; MASTER embedded tests 67×11 |
| whitespace | PASS, `git diff --check` output 0 |
| database/Edge regression | **NOT RUN BY DESIGN**; DB/API/RLS/Edge source와 signature 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test test/features/calendar/calendar_recurrence_test.dart test/features/calendar/calendar_events_controller_test.dart test/features/calendar/calendar_events_widget_test.dart
flutter test test/localization/localization_contract_test.dart
flutter test
flutter analyze --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
git diff --check
```

모든 Flutter/Dart 명령은 `/private/tmp/kinflow-flutter-exact-3.44.7`의 exact SDK로
실행했다. 최초 sandbox `gen-l10n`은 user telemetry timestamp 권한 때문에 종료됐지만
생성된 crash log를 제거하고 동일 exact 명령을 승인된 환경에서 재실행해 성공했다.

## Files and Data Impact

- Domain: `apps/kinflow_app/lib/features/calendar/domain/entities/calendar_recurrence.dart`
- UI: `calendar_events_screen.dart`, `calendar_recurrence_editor.dart`
- Localization: EN/KO/EN-XA ARB와 generated localizations
- Tests: Calendar recurrence domain, controller, widget와 localization contract
- Contract/tracking: monthly-anchor contract, Phase 04 plan, requirement/test/time matrices,
  master spec와 changelog

새 migration, table, index, RLS, RPC/Edge signature, dependency, native permission, analytics,
log event 또는 persistent client data를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Authority

- month-day UI는 event content나 identity를 새 route, log, analytics, storage 또는 error
  string에 복제하지 않는다.
- UI validation은 advisory이며 existing database validator와 create/update RPC가 최종
  rule, local-start anchor, expected version과 household-local series boundary를 계속 강제한다.
- invalid monthly frequency 또는 interval/end는 overlap preview, command ID, repository와
  network 이전에 차단된다.
- raw provider exception과 payload는 UI에 노출하지 않으며 기존 exact Calendar runtime
  feature guard를 변경하지 않았다.
- 자동 검증은 fake repository와 synthetic household/event만 사용했고 production project,
  실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 계정으로 day 31 monthly create와 start-date whole-series edit
- hosted materializer가 February와 30-day month에서 missing day를 skip하고 clamp하지 않는지 확인
- 두 기기의 start-date/interval/end 동시 편집, expected-version conflict와 Realtime reconciliation
- DST·자정·device timezone travel 중 monthly wall-time과 local-date anchor 유지
- TalkBack disabled dropdown/helper/live-region announcement, 실제 font 200%와 date picker
- physical Android phone/tablet/split layout와 production-like release build

## Remaining Risks and Completion Boundary

1. 실제 screen reader가 disabled day control과 두 helper를 자연스럽게 함께 읽는지는
   physical-device 검증 전까지 완료 근거가 아니다.
2. existing SQL은 monthly missing date를 skip하지만 이번 client mapping과 hosted
   materializer를 잇는 실계정 end-to-end 증적은 아직 없다.
3. 독립 또는 복수 month date, last-day, ordinal weekday, yearly/business-day recurrence는
   현재 strict schema에서 지원하지 않는다.
4. arbitrary this-and-future split과 single-occurrence recurrence 변경은 별도 제품 계약이
   필요하다.
5. 따라서 WP04-12 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- locked month-day control, helper와 card/live summary를 숨겨도 monthly domain mapping은
  current edited start date에서 계속 re-anchor하여 기존 server invariant를 지켜야 한다.
- monthly copy helper는 `_editedRecurrenceRule`의 equivalent anchored reconstruction과 함께
  교체할 수 있다.
- DB/API 변경이 없어 migration rollback, data backfill 또는 server deployment rollback은
  없다.

## Next Entry Condition

- 다음 기능 우선순위는 남은 기능 매트릭스와 현재 client/server 계약을 다시 점검해
  독립적인 다음 수직 조각으로 선택할 수 있다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히
  진행된 뒤 마지막 통합 Gate에 계속 유지한다.
