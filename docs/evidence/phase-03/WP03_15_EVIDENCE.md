# Phase 03 WP03-15 Chore Weekly Multiple-Weekday Evidence

- Work Package: WP03-15 — weekly Chore multiple-weekday selector
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CHORE-005 | PASS FOR LOCAL AUTOMATED SLICE | Weekly 반복 집안일 생성에서 unique 요일 1~7개를 선택하고 ISO 월요일~일요일 순서의 strict rule로 create에 전달한다. |
| FR-CHORE-008 | PASS FOR LOCAL AUTOMATED SLICE | 미래 시리즈 editor가 active weekly rule의 전체 요일 set을 prefill하고 최소 한 요일을 유지하며 추가·해제를 update에 전달한다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | empty/duplicate/non-weekly 및 생성 start-anchor 누락 selection은 domain에서 닫힌다. semantic weekday set 변경은 recurrence fingerprint와 command key를 회전시킨다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | seven-day toggle은 48dp target과 selected state를 가지며 생성 anchor 또는 시리즈의 마지막 요일은 잠기고 이유를 표시한다. 생성과 시리즈 editor가 320×568 EN-XA 200%에서 overflow 없이 동작한다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | weekday labels, surface별 helper와 live summary를 EN/KO/EN-XA ARB로 제공하고 exact coverage와 pseudo expansion을 통과했다. |
| D-017 | PASS FOR CLIENT TIME BOUNDARY | 생성은 local start date 요일을 포함하고 미래 시리즈 boundary는 server-authoritative household effective local date를 계속 사용한다. locale display와 무관한 ISO wire weekday만 저장한다. |

이 결과는 기존 server-supported weekly weekday-array contract를 Chore UI에 노출한 local
automated slice에 한정한다. hosted Supabase, 실제 계정, 두 기기, physical-device 검증은
사용자 지시에 따라 마지막 통합 Gate에 남겨 둔다.

## Domain and Command Contract

- `tryWithWeeklyWeekdays`는 weekly rule에만 허용되며 1~7개, 중복 없음, optional creation
  start weekday 포함과 interval/end bounds를 한 번에 검증한다.
- 입력 순서와 locale에 관계없이 `MO, TU, WE, TH, FR, SA, SU` 순서로 canonicalize한다.
  따라서 같은 semantic set은 toggle 순서 때문에 fingerprint를 흔들지 않는다.
- recurring create는 start date weekday를 required anchor로 전달한다. future-series update는
  server contract와 맞춰 특정 요일 anchor 없이 non-empty set을 허용한다.
- create와 series update는 canonical full rule을 기존 repository command에 그대로 전달한다.
  weekday set 변경은 기존 full-draft fingerprint에 포함된다.
- creation anchor 누락, empty/duplicate selection 또는 invalid interval/end는 command ID,
  repository와 network 이전에 차단된다.
- expected version, immutable revision, future incomplete rebuild, past/completed 보존과
  authoritative refresh는 기존 server boundary를 그대로 사용한다.

Normative contract는 `docs/contracts/chore-weekly-weekdays.yaml.md`다.

## Presentation Behavior

- Weekly 선택 시 월요일부터 일요일까지 localized `FilterChip` 7개를 표시한다.
- 생성 화면의 current start weekday chip은 selected 상태로 잠기고 helper/tooltip이 이유를
  설명한다. 다른 요일은 자유롭게 추가·해제할 수 있다.
- 생성 start date 변경은 기존 선택을 유지하면서 새 start weekday를 추가한다. 이전
  anchor는 일반 선택으로 바뀌어 사용자가 해제할 수 있다.
- template 적용은 interval 1/never와 함께 현재 due-date weekday 하나로 명시적으로
  재설정한다.
- 미래 시리즈 editor는 active rule의 full weekday set을 prefill하고 마지막 selected chip만
  잠가 최소 한 요일을 보장한다. household effective-date 요일도 다른 요일처럼 해제할 수 있다.
- frequency를 weekly에서 다른 값으로 바꾸면 weekday field를 직렬화하지 않는다. 같은
  editor에서 weekly로 돌아오면 in-progress set을 복원한다. changed-to-weekly 최초 선택은
  server-authoritative household effective local-date weekday다.
- editor live region은 선택된 localized weekday list를 표시한다. compact 검증 중 발견한
  시리즈 담당자·frequency dropdown 긴 문자열 overflow도 expanded/ellipsis로 함께 닫았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Chore domain/controller/widget suite | PASS, 80 tests total |
| weekly factory 1/7 bounds, duplicate/empty/non-weekly/missing-anchor rejection | PASS |
| ISO canonical JSON and locale-independent set fingerprint | PASS |
| create toggles → exact repository request | PASS |
| locked creation start weekday and removable non-anchor weekdays | PASS |
| start-date change retains prior choices, adds new anchor and unlocks old anchor | PASS |
| template reset to current due-date weekday | PASS |
| future-series full-set prefill, minimum-one lock, removal/addition and update | PASS |
| changed-to-weekly household-date initialization and frequency round-trip preservation | PASS |
| weekday-set command-key rotation and exact retry reuse | PASS |
| localized live summaries and compact EN-XA 200% create/series editor | PASS |
| localization exact coverage and pseudo expansion | PASS, 4/4 |
| full Flutter regression | PASS, 994 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 574 files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 136/136 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, contract 12 root keys; 13 matrices; requirements 116×18; tests 72×11; time 36×12; MASTER embedded tests 65×11 |
| database/Edge regression | **NOT RUN BY DESIGN**; DB/API/RLS/Edge source와 signature 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test test/features/chores/chore_domain_test.dart test/features/chores/recurring_chore_creation_controller_test.dart test/features/chores/one_time_chore_widget_test.dart
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

- Domain: `apps/kinflow_app/lib/features/chores/domain/entities/recurring_chore_request.dart`
- UI: `one_time_chore_creation_screen.dart`, `today_chores_screen.dart`,
  `chore_recurrence_editor.dart`
- Localization: EN/KO/EN-XA ARB와 generated localizations
- Tests: Chore recurrence domain, recurring-create controller, creation/series widget와
  localization contract
- Contract/tracking: weekly-weekdays contract, Phase 03 plan, requirement/test/time matrices,
  master spec와 changelog

새 migration, table, index, RLS, RPC/Edge signature, dependency, native permission, analytics,
log event 또는 persistent client data를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Authority

- weekday selector는 chore content나 identity를 새 route, log, analytics, storage 또는 error
  string에 복제하지 않는다.
- UI는 advisory validation만 제공하고 existing database recurrence validator와
  create/update RPC가 최종 rule, expected version과 household-local boundary를 계속 강제한다.
- raw provider exception과 payload는 UI에 노출하지 않으며 기존 Chores runtime feature guard가
  command ID와 repository I/O보다 먼저 유지된다.
- 자동 검증은 fake repository와 synthetic household/chore만 사용했고 production project,
  실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 계정으로 MO/WE/FR recurring create와 future-series edit
- hosted materializer가 선택 요일의 exact household-local dates만 생성하는지 확인
- 두 기기의 weekday set 동시 편집, expected-version conflict와 Realtime reconciliation
- DST·자정·device timezone travel 중 multi-day due local-time 유지
- TalkBack selected/disabled announcement, 실제 font 200%, hardware keyboard와 date picker
- physical Android phone/tablet/split layout와 production-like release build

## Remaining Risks and Completion Boundary

1. 실제 screen reader가 disabled anchor/minimum chip과 helper를 함께 읽는지는 physical-device
   검증 전까지 완료 근거가 아니다.
2. server validator/materializer의 multi-weekday SQL은 기존 구현을 사용하지만 이번 client
   set과의 hosted end-to-end 증적은 아직 없다.
3. multiple month dates, ordinal weekday, yearly/business-day recurrence는 지원하지 않는다.
4. guided exact-three setup은 활성화 속도를 위해 simple daily/weekly rule을 유지한다.
5. 따라서 WP03-15 local automated slice만 완료하며 Phase 03, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- weekday toggle fields와 creation/series weekday state/full-rule mapping을 함께 revert하면
  WP03-14의 start-date-only creation 및 stored-anchor-preserving series UI로 돌아간다.
- weekly domain copy helper와 localized summary를 해당 호출부와 함께 제거할 수 있다.
- DB/API 변경이 없어 migration rollback, data backfill 또는 server deployment rollback은 없다.

## Next Entry Condition

- 다음 기능 우선순위 후보는 Chore/Calendar monthly recurrence 선택 확장이다. 기존 단일
  month-day skip semantics를 유지할지 last-day/ordinal을 새 strict server rule로 추가할지
  먼저 제품·materializer 계약을 확정해야 한다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히 진행된
  뒤 마지막 통합 Gate에 계속 유지한다.
