# Phase 04 WP04-10 Advanced Calendar Recurrence Editor Evidence

- Work Package: WP04-10 — advanced Calendar recurrence editor
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CAL-004 | PASS FOR LOCAL AUTOMATED SLICE | Calendar 생성 화면에서 daily/weekly/monthly 반복 간격 `1..30`과 `never`, count `1..1000`, until 종료 조건을 입력하고 strict recurrence rule로 저장할 수 있다. |
| FR-CAL-006 | PASS FOR LOCAL AUTOMATED SLICE | 전체 시리즈 편집은 현재 interval/end를 prefill하고, 빈도가 같으면 기존 weekday/month-day anchor를 보존하며 빈도가 바뀌면 active revision의 local start date로 다시 anchor한다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | invalid recurrence는 preview, command ID, repository에 도달하지 않는다. full rule이 overlap preview와 mutation에 전달되고 변경된 interval/end는 새 idempotency fingerprint를 만든다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | editor는 scroll 가능하고 live recurrence summary를 제공한다. 320×568, EN-XA, 200% text에서 interval/end/count/until controls의 overflow가 없다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | 새 문구와 복수형은 EN/KO/EN-XA ARB로만 제공하며 localization exact-coverage와 generated ICU plural 검증을 통과했다. |
| D-019 / D-020 | PASS FOR CLIENT TIME BOUNDARY | create until은 event start 이상, series until은 active revision start와 server-returned household local date 중 늦은 날짜 이상이어야 한다. 저장 시 최종 household date authority는 기존 server command가 유지한다. |

이 결과는 기존 server-supported recurrence contract를 Calendar UI에 노출한 local automated
slice에 한정한다. hosted Supabase, 실제 계정, 두 기기, physical-device 검증은 사용자 지시에
따라 마지막 통합 Gate에 남겨 둔다.

## Domain and Command Contract

- `CalendarRecurrenceRule.tryAnchored`가 frequency와 event local start date에서 weekly
  weekday 또는 monthly month-day anchor를 만들고 interval/count/until bounds를 함께
  검증한다.
- `tryWithIntervalAndEnd`는 frequency, weekdays와 month-day를 그대로 유지하면서
  interval/end만 교체한다. 따라서 현재 UI가 직접 선택하지 못하는 server-read 다중
  weekday도 같은 빈도 편집에서 소실되지 않는다.
- interval은 `1..30`, count는 `1..1000`, until은 전달된 minimum local date 이상만
  허용한다. invalid 값은 nullable domain result로 닫히며 one-time recurrence로 약화하지
  않는다.
- recurring create와 whole-series update가 편집된 full rule을 overlap preview와 repository
  command에 그대로 전달한다. 기존 recurrence fingerprint가 interval/end를 포함하므로 같은
  입력 retry는 key를 재사용하고 변경된 advanced input은 새 key를 받는다.
- series update는 household-local today보다 이른 until을 application boundary에서도
  pre-command 차단한다. 서버는 기존 RPC에서 저장 시점의 household-local date를 다시
  계산하므로 client snapshot은 authority를 대체하지 않는다.

Normative contract는 `docs/contracts/calendar-advanced-recurrence.yaml.md`다.

## Presentation Behavior

- recurring frequency를 고르면 interval과 종료 방식 selector가 표시되고 count 또는 until
  입력이 조건부로 나타난다.
- 시작 날짜를 until 뒤로 옮기면 until을 새 최소 날짜로 즉시 clamp한다.
- whole-series editor는 active source recurrence를 prefill한다. frequency 변경 시에도
  interval/end는 유지하고 anchor만 active revision event local start date에 맞춘다.
- event card와 editor live region은 interval 1의 기존 daily/weekly/monthly 문구를 유지하고
  interval 2 이상을 locale-aware plural summary로 표시한다.
- single-occurrence edit/cancel은 source recurrence를 변경하지 않으며 arbitrary
  this-and-future split은 이번 범위에 포함하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Calendar domain/controller/widget suite | PASS, 55/55 |
| anchored/copy domain bounds and exact JSON | PASS |
| create interval/count, until clamp and exact overlap preview | PASS |
| invalid interval/count preview/save suppression | PASS |
| whole-series prefill, same-anchor preservation and changed-frequency re-anchor | PASS |
| household-today pre-command until guard | PASS |
| compact EN-XA 200% editor regression | PASS |
| full Flutter regression | PASS, 985 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 574 files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 136/136 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, contract 11 root keys; 13 matrices; requirements 116×18; tests 70×11; MASTER embedded tests 63×11 |
| whitespace | PASS, `git diff --check` |
| database/Edge regression | **NOT RUN BY DESIGN**; DB/API/RLS/Edge source와 signature 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test test/features/calendar/calendar_recurrence_test.dart test/features/calendar/calendar_events_controller_test.dart test/features/calendar/calendar_events_widget_test.dart
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
- Application: `apps/kinflow_app/lib/features/calendar/application/calendar_events_controller.dart`
- UI: `calendar_events_screen.dart`, 새 `calendar_recurrence_editor.dart`
- Localization: EN/KO/EN-XA ARB와 generated localizations
- Tests: recurrence domain, Calendar controller, Calendar widget suites
- Contract/tracking: advanced recurrence contract, Phase 04 plan, requirement/test/time matrices,
  master spec와 changelog

새 migration, table, index, RLS, RPC/Edge signature, dependency, native permission, analytics,
log event 또는 persistent client data를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Authority

- editor와 summary는 이미 authorized projection에 포함된 schedule fields만 사용하며 새
  content를 route, log, analytics 또는 error string에 복제하지 않는다.
- domain/application validation은 사용자 오류를 stable `invalidInput`으로 닫고 provider
  exception이나 raw payload를 UI에 노출하지 않는다.
- expected version, immutable series revision, past occurrence/exception 보존과 authoritative
  post-command refresh는 기존 server boundary를 그대로 사용한다.
- 자동 검증은 fake repository와 synthetic household/event만 사용했으며 production project,
  실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 계정으로 recurring create와 whole-series edit
- hosted RPC의 household-local today 재검증, version conflict와 RLS denial
- 두 기기의 동일 시리즈 동시 편집과 Realtime reconciliation
- 자정, DST gap/fold, device timezone travel 중 remote materialization 확인
- TalkBack, 실제 200% font, hardware keyboard, phone/tablet/split layout
- physical Android lifecycle와 production-like release build

## Remaining Risks and Completion Boundary

1. weekly multiple-weekday 선택 UI는 아직 없다. 다만 기존 다중 weekday는 same-frequency
   interval/end 편집에서 보존된다.
2. ordinal monthly, multiple month dates, yearly/business-day recurrence는 server contract와
   UI 모두 이번 범위 밖이다.
3. application의 household date는 최근 server projection snapshot이므로 오래 열린 dialog의
   자정 경계는 최종 server validation에 의존한다.
4. 실제 RPC의 conflict/retry와 multi-device propagation은 local fake 자동화만으로 release
   완료 근거가 되지 않는다.
5. 따라서 WP04-10 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- advanced editor widget과 screen full-rule mapping을 함께 revert하면 기존 interval 1/never
  frequency-only UI로 돌아간다.
- domain factory/copy helper는 새 editor 전용 호출부와 함께 제거할 수 있다.
- DB/API 변경이 없어 migration rollback, data backfill 또는 server deployment rollback은
  없다.

## Next Entry Condition

- 다음 Calendar 기능 후보는 weekly multiple-weekday selection이다. 시작 전에 기존 server
  rule의 weekday ordering, 최소 1개 선택, anchor-independent preview와 series edit 보존
  계약을 별도 work package로 고정한다.
- 또는 전체 제품 우선순위에서 더 큰 사용자 흐름 공백이 확인되면 해당 vertical slice를
  먼저 선택하되 real-account/remote/device 검증은 마지막 통합 Gate에 유지한다.
