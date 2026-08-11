# Phase 03 WP03-16 Chore Monthly Day-of-Month Evidence

- Work Package: WP03-16 — monthly Chore day-of-month selector
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CHORE-005 | PASS FOR LOCAL AUTOMATED SLICE | Monthly 반복 생성은 첫 due date day를 strict `monthDay`로 전달하고 날짜 변경 시 새 day를 전달한다. |
| FR-CHORE-008 | PASS FOR LOCAL AUTOMATED SLICE | 미래 시리즈 editor가 active monthly day를 정확히 prefill하고 1~31일 변경을 full rule update로 전달한다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | `0/32`, non-monthly copy와 invalid interval/end는 domain에서 닫힌다. monthDay 변경은 recurrence fingerprint와 command key를 회전시킨다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | Expanded dropdown, form label, helper와 live summary를 제공하고 320×568 EN-XA 200% dialog/menu에서 overflow 없이 동작한다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | Day option, 생성 anchor, missing-date 정책과 live summary를 EN/KO/EN-XA ARB로 제공하고 exact coverage와 pseudo expansion을 통과했다. |
| D-017 | PASS FOR CLIENT TIME BOUNDARY | 생성 anchor는 source local date day이고 미래 시리즈 변경 경계는 server-authoritative household effective local date를 계속 사용한다. 없는 월은 skip하고 말일로 clamp하지 않는다. |

이 결과는 기존 server-supported monthly `monthDay` 계약을 Chore UI에 완전히 노출한 local
automated slice에 한정한다. hosted Supabase, 실제 계정, 두 기기, physical-device 검증은
사용자 지시에 따라 마지막 통합 Gate에 남겨 둔다.

## Domain and Command Contract

- `tryWithMonthlyDay`는 monthly rule에만 허용되며 day `1..31`과 interval/end bounds를 한 번에
  검증한다. 결과는 weekly anchor를 포함하지 않는 exact monthly JSON이다.
- recurring create는 기존 `RecurringChoreDraft.startsOn` 불변식에 따라 due/start date day를
  사용한다. UI selector는 이 값을 보여 주되 변경할 수 없고 due date 변경으로만 바뀐다.
- future-series update는 active monthly rule의 exact day를 prefill하며 server contract에 맞춰
  effective local-date day와 다른 값도 허용한다. server가 boundary 이후 첫 matching date부터
  새 immutable revision을 materialize한다.
- monthly로 처음 전환할 때는 server snapshot의 household local date day를 사용한다. 다른
  frequency로 갔다가 돌아오면 editor process 안의 in-progress day를 보존한다.
- `monthDay`는 기존 full recurrence JSON fingerprint에 포함된다. 같은 day 재시도는 기존
  command ID를 재사용하고 semantic day 변경은 새 ID를 받는다.
- existing SQL materializer의 day 31 fixture는 해당 날짜가 없는 달을 건너뛰고 말일로
  보정하지 않으며 skipped month는 count를 소비하지 않는다.

Normative contract는 `docs/contracts/chore-monthly-month-day.yaml.md`다.

## Presentation Behavior

- Monthly 선택 시 localized 1~31일 `DropdownButtonFormField`와 live summary를 표시한다.
- 생성 화면은 selector를 비활성화하고 “첫 예정일이 기준”임을 설명한다. due date를 6일에서
  8일로 바꾸면 option, summary와 serialized rule이 모두 day 8로 갱신된다.
- 미래 시리즈 화면은 selector를 활성화하고 active day, interval과 end를 함께 prefill한다.
  검증 fixture에서 day 31/count 8을 day 15로 바꾸어 같은 bounds와 함께 저장했다.
- Daily active rule에서 monthly로 바꾸면 household effective date인 6일로 시작한다. day 12로
  변경한 뒤 daily를 거쳐 monthly로 돌아와도 day 12를 보존하고 저장한다.
- 모든 monthly surface는 선택 날짜가 없는 달은 건너뛰며 말일로 옮기지 않는다고 명시한다.
  31개 menu item은 expanded/ellipsis-safe이고 compact pseudo menu를 실제로 열어 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Chore domain/controller/widget suite | PASS, 86 tests total |
| monthly copy boundary day 1/31 and invalid 0/32/non-monthly/interval rejection | PASS |
| create due-date anchor and 6→8 date synchronization | PASS |
| future-series day 31 prefill and day 15 full-rule update | PASS |
| changed-to-monthly household-day initialization and day 12 frequency round-trip | PASS |
| monthDay command-key rotation and exact retry reuse | PASS |
| localized helper/live summary and compact EN-XA 200% dropdown menu | PASS |
| localization exact coverage and pseudo expansion | PASS, 4/4 |
| full Flutter regression | PASS, 1,000 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 574 files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 136/136 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, requirements 116×18; tests 73×11; time 37×12; MASTER embedded tests 66×11 |
| database/Edge regression | **NOT RUN BY DESIGN**; DB/API/RLS/Edge source와 signature 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test test/features/chores/chore_domain_test.dart test/features/chores/today_chore_series_controller_test.dart test/features/chores/one_time_chore_widget_test.dart
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
- Tests: Chore recurrence domain, future-series controller와 creation/series widget
- Contract/tracking: monthly-day contract, Phase 03 plan, requirement/test/time matrices, master
  spec와 changelog

새 migration, table, index, RLS, RPC/Edge signature, dependency, native permission, analytics,
log event 또는 persistent client data를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Authority

- month-day selector는 chore content나 identity를 새 route, log, analytics, storage 또는 error
  string에 복제하지 않는다.
- UI는 advisory validation만 제공하고 existing database recurrence validator와 create/update
  RPC가 최종 rule, expected version과 household-local boundary를 계속 강제한다.
- raw provider exception과 payload는 UI에 노출하지 않으며 기존 Chores runtime feature guard가
  command ID와 repository I/O보다 먼저 유지된다.
- 자동 검증은 fake repository와 synthetic household/chore만 사용했고 production project,
  실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 계정으로 monthly day 1/28/29/30/31 recurring create와 series edit
- hosted materializer가 29~31일의 missing month를 skip하고 count를 정확히 유지하는지 확인
- 두 기기의 monthDay 동시 편집, expected-version conflict와 Realtime reconciliation
- leap February, DST·자정과 device timezone travel 중 household-local month day 유지
- TalkBack disabled creation field/helper와 live summary announcement
- physical Android phone/tablet/split layout와 production-like release build

## Remaining Risks and Completion Boundary

1. 실제 screen reader가 disabled creation selector와 두 helper를 원하는 순서로 읽는지는
   physical-device 검증 전까지 완료 근거가 아니다.
2. server validator/materializer의 monthly day 31 SQL은 기존 구현을 사용하지만 이번 client
   control과의 hosted end-to-end 증적은 아직 없다.
3. “말일”, multiple month dates, ordinal weekday와 yearly/business-day recurrence는 지원하지
   않는다. 말일은 day 31 clamp와 다른 별도 rule이어야 한다.
4. guided exact-three setup은 활성화 속도를 위해 simple daily/weekly rule을 유지한다.
5. 따라서 WP03-16 local automated slice만 완료하며 Phase 03, release gate와 장기 기능 목표는
   `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- monthly dropdown과 creation/series month-day state/full-rule mapping을 함께 revert하면
  WP03-15의 due-date-derived create와 stored-anchor-preserving series UI로 돌아간다.
- monthly domain copy helper와 localized helper/summary를 해당 호출부와 함께 제거할 수 있다.
- DB/API 변경이 없어 migration rollback, data backfill 또는 server deployment rollback은 없다.

## Next Entry Condition

- 다음 기능 우선순위 후보는 Calendar monthly anchor UX 보강 또는 separate last-day recurrence
  schema다. last-day는 기존 strict JSON과 N-1 client compatibility를 먼저 설계해야 한다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히 진행된
  뒤 마지막 통합 Gate에 계속 유지한다.
