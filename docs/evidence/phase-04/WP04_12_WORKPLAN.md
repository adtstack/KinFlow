# Phase 04 WP04-12 Calendar Monthly Start-Date Anchor Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP04/G4 완료는 아님
- 수직 조각: monthly event start date → locked day-of-month UI → overlap preview → recurring create or whole-series update → authoritative reconciliation
- 요구사항: `FR-CAL-004`, `FR-CAL-006`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`
- 계약: `docs/contracts/calendar-monthly-anchor.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_12_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Calendar 일정 생성과 전체 반복 시리즈 편집에서 monthly rule의 기준일을 event local start date의 일자로 명시하고 항상 동기화한다.
- 월간 기준일은 독립 선택값이 아니다. 기존 server validator와 create/update RPC가 `monthDay == local_start_date.day`를 요구하므로 UI에는 읽기 전용으로 표시한다.
- start date가 바뀌면 interval과 end는 보존하고 `monthDay`만 새 일자로 바꾼다.
- 선택한 일자가 없는 달은 마지막 날로 보정하지 않고 건너뛴다. count는 실제 생성된 occurrence만 센다.
- daily/weekly, single-occurrence recurrence, arbitrary this-and-future split은 바꾸지 않는다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. monthly 전용 bounded copy factory가 frequency, source local date, interval/end boundary를 검증하고 source date의 day를 canonical `monthDay`로 생성한다.
2. recurring create와 whole-series edit의 `_editedRecurrenceRule`은 monthly인 경우 현재 start date로 항상 factory를 호출한다.
3. 같은 monthly frequency의 whole-series start-date 변경도 active rule의 interval/end를 유지하면서 새 anchor로 재직렬화한다.
4. changed-to-monthly와 editor frequency round-trip은 현재 start date에서 파생하며 stale in-progress monthDay state를 만들지 않는다.
5. overlap preview와 save가 같은 full rule을 사용한다. invalid interval/end는 기존처럼 preview, command ID와 repository 이전에 차단한다.
6. recurring draft fingerprint가 event start date와 `monthDay`를 포함하므로 날짜 의미 변경은 command key를 회전하고 exact retry는 같은 key를 재사용한다.

## Presentation design

- monthly를 선택하면 1~31 localized option을 가진 disabled expanded dropdown으로 current start-date day를 표시한다.
- helper는 start date가 기준일을 소유한다는 점과 missing-date skip-not-clamp 정책을 각각 설명한다.
- editor live region과 recurring event card에 localized month-day summary를 표시한다.
- 날짜 변경 시 keyed control과 live summary가 즉시 새 일자로 갱신된다.
- 320×568 EN-XA 200%에서 dialog scroll, helper와 summary overflow를 자동 검증한다.
- 사용자 표시 문자열은 EN/KO/EN-XA ARB만 사용한다.

## Automated evidence plan

1. monthly factory re-anchors day 7 to 15 while preserving interval/end and rejects non-monthly or invalid end
2. recurring create shows a locked source day and maps a changed start date to exact overlap preview and create request
3. same-frequency whole-series monthly start-date edit replaces stale `monthDay` while preserving interval/end
4. changed-to-monthly and frequency round-trip derive from the current start date
5. localized editor/card summary and missing-date policy
6. start-date/month-day semantic change rotates idempotency key while exact retry reuses it
7. compact EN-XA 200% overflow regression
8. full Flutter tests, analyzer, format, codegen, localization, Node contract, secret and whitespace gates

## Stop conditions and rollback

- monthly rule의 `monthDay`가 edited event local start-date day와 다르게 preview, command ID 또는 repository에 도달하면 배포하지 않는다.
- start-date 변경이 interval/end를 잃거나 preview와 save가 서로 다른 rule을 보내면 배포하지 않는다.
- missing date를 month final day로 clamp하거나 occurrence count가 skipped month를 소비하면 배포하지 않는다.
- occurrence exception 편집이 source recurrence rule을 바꾸거나 series boundary가 client date authority로 바뀌면 배포하지 않는다.
- rollback은 month-day 표시와 summary를 숨기되 current-start-date re-anchor domain mapping은 유지한다. server rollback은 없다.

## Non-scope

- independently selectable/multiple month dates, last-day와 ordinal weekday
- yearly/business-day/exception-calendar rule
- arbitrary this-and-future split 또는 single-occurrence recurrence 변경
- remote migration/provider/real-account/multi-device/physical-device evidence
