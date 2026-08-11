# Phase 04 WP04-11 Calendar Weekly Multiple-Weekday Evidence

- Work Package: WP04-11 — weekly Calendar multiple-weekday selector
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CAL-004 | PASS FOR LOCAL AUTOMATED SLICE | Weekly Calendar 생성에서 unique 요일 1~7개를 선택하고 ISO 월요일~일요일 순서의 strict rule로 preview와 create에 전달한다. |
| FR-CAL-006 | PASS FOR LOCAL AUTOMATED SLICE | 전체 시리즈 editor가 active weekly rule의 전체 요일 set을 prefill하고 non-anchor 요일 추가·해제를 future-series update에 전달한다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | source start weekday가 없는 empty/duplicate/non-weekly selection은 domain에서 닫힌다. semantic weekday set 변경은 recurrence fingerprint와 command key를 회전시킨다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | seven-day toggle은 48dp target과 selected state를 가지며 anchor는 잠기고 이유를 표시한다. editor와 multi-day card가 320×568 EN-XA 200%에서 overflow 없이 동작한다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | weekday labels, helper, live summary와 card summary를 EN/KO/EN-XA ARB로 제공하고 exact coverage와 pseudo expansion을 통과했다. |
| D-019 / D-020 | PASS FOR CLIENT TIME BOUNDARY | locale display와 무관한 ISO wire weekday를 사용하고 edited event local start-date weekday를 rule에 항상 포함한다. 기존 server local-date/time authority는 그대로다. |

이 결과는 기존 server-supported weekly weekday-array contract를 Calendar UI에 노출한 local
automated slice에 한정한다. hosted Supabase, 실제 계정, 두 기기, physical-device 검증은
사용자 지시에 따라 마지막 통합 Gate에 남겨 둔다.

## Domain and Command Contract

- `tryWithWeeklyWeekdays`는 weekly rule에만 허용되며 1~7개, 중복 없음, edited event
  local start weekday 포함, interval/end bounds를 한 번에 검증한다.
- 입력 순서와 locale에 관계없이 `MO, TU, WE, TH, FR, SA, SU` 순서로 canonicalize한다.
  따라서 같은 semantic set은 toggle 순서 때문에 fingerprint를 흔들지 않는다.
- recurring create와 whole-series update는 canonical full rule을 overlap preview와 repository
  command에 그대로 전달한다. weekday set 변경은 기존 full-draft fingerprint에 포함된다.
- source date anchor 누락, empty/duplicate selection 또는 invalid interval/end는 preview,
  command ID, repository와 network 이전에 차단된다.
- expected version, immutable revision, future non-exception rebuild, past/explicit-exception
  보존과 authoritative refresh는 기존 server boundary를 그대로 사용한다.

Normative contract는 `docs/contracts/calendar-weekly-weekdays.yaml.md`다.

## Presentation Behavior

- Weekly 선택 시 월요일부터 일요일까지 localized `FilterChip` 7개를 표시한다.
- current event start weekday chip은 selected 상태로 잠기고 helper/tooltip이 이유를 설명한다.
  다른 요일은 자유롭게 추가·해제할 수 있다.
- start date 변경은 기존 선택을 유지하면서 새 start weekday를 추가한다. 이전 anchor는
  일반 선택으로 바뀌어 사용자가 해제할 수 있다.
- frequency를 weekly에서 다른 값으로 바꾸면 weekday field를 직렬화하지 않는다. 같은
  editor에서 weekly로 돌아오면 in-progress set을 복원하고 현재 start anchor를 재강제한다.
- whole-series editor는 active rule의 전체 weekday set을 prefill한다.
- editor live region과 recurring event card는 선택된 localized weekday list를 표시한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Calendar domain/controller/widget suite | PASS, 59 tests total |
| weekly factory 1/7 bounds, duplicate/empty/non-weekly/missing-anchor rejection | PASS |
| ISO canonical JSON and locale-independent set fingerprint | PASS |
| create toggles → exact overlap preview and repository request | PASS |
| locked start weekday and removable non-anchor weekdays | PASS |
| start-date change retains prior choices and adds new anchor | PASS |
| whole-series multi-day prefill, removal/addition and update | PASS |
| frequency round-trip in-progress selection preservation | PASS |
| weekday-set command-key rotation | PASS |
| localized live/card summaries and compact EN-XA 200% | PASS |
| localization exact coverage and pseudo expansion | PASS, 4/4 |
| full Flutter regression | PASS, 989 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 574 files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 136/136 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, contract 12 root keys; 13 matrices; requirements 116×18; tests 71×11; time 35×12; MASTER embedded tests 64×11 |
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

## Files and Data Impact

- Domain: `apps/kinflow_app/lib/features/calendar/domain/entities/calendar_recurrence.dart`
- UI: `calendar_events_screen.dart`, `calendar_recurrence_editor.dart`
- Localization: EN/KO/EN-XA ARB와 generated localizations
- Tests: Calendar recurrence domain, controller, widget와 localization contract
- Contract/tracking: weekly-weekdays contract, Phase 04 plan, requirement/test/time matrices,
  master spec와 changelog

새 migration, table, index, RLS, RPC/Edge signature, dependency, native permission, analytics,
log event 또는 persistent client data를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Authority

- weekday selector는 일정 content나 identity를 새 route, log, analytics, storage 또는 error
  string에 복제하지 않는다.
- UI는 advisory validation만 제공하고 existing database recurrence validator와
  create/update RPC가 최종 rule, start anchor, expected version과 household-local boundary를
  계속 강제한다.
- raw provider exception과 payload는 UI에 노출하지 않으며 기존 Calendar runtime feature
  guard가 command ID와 repository I/O보다 먼저 유지된다.
- 자동 검증은 fake repository와 synthetic household/event만 사용했고 production project,
  실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 계정으로 MO/WE/FR recurring create와 whole-series edit
- hosted materializer가 선택 요일의 exact local dates만 생성하는지 확인
- 두 기기의 weekday set 동시 편집, expected-version conflict와 Realtime reconciliation
- DST·자정·device timezone travel 중 multi-day wall-time 유지
- TalkBack selected/disabled announcement, 실제 font 200%, hardware keyboard와 date picker
- physical Android phone/tablet/split layout와 production-like release build

## Remaining Risks and Completion Boundary

1. 실제 screen reader가 disabled anchor chip과 helper를 함께 읽는지는 physical-device
   검증 전까지 완료 근거가 아니다.
2. server validator/materializer의 multi-weekday SQL은 기존 자동화가 있지만 이번 client
   set과의 hosted end-to-end 증적은 아직 없다.
3. multiple month dates, ordinal weekday, yearly/business-day recurrence는 지원하지 않는다.
4. arbitrary this-and-future split과 single-occurrence recurrence 변경은 별도 제품 계약이
   필요하다.
5. 따라서 WP04-11 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- weekday toggle fields와 screen weekday state/full-rule mapping을 함께 revert하면 WP04-10의
  start-date-only weekly anchor UI로 돌아간다.
- weekly domain copy helper와 localized summary를 해당 호출부와 함께 제거할 수 있다.
- DB/API 변경이 없어 migration rollback, data backfill 또는 server deployment rollback은
  없다.

## Next Entry Condition

- 다음 기능 우선순위 후보는 Chore weekly multiple-weekday selector다. Chore의 existing
  strict weekday-array와 household-local first-date anchor를 유지하면서 create와 future-series
  edit에 같은 bounded selector를 별도 WP03 slice로 연결한다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히 진행된
  뒤 마지막 통합 Gate에 계속 유지한다.
