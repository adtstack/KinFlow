# Phase 04 WP04-10 Advanced Calendar Recurrence Editor Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP04/G4 완료는 아님
- 수직 조각: existing strict recurrence rule → interval/end editor → recurring create or whole-series update → authoritative reconciliation
- 요구사항: `FR-CAL-004`, `FR-CAL-006`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`
- 계약: `docs/contracts/calendar-advanced-recurrence.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_10_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Calendar 일정 생성과 전체 반복 시리즈 편집에서 기존 server-supported interval `1..30`과 `never|count|until` 종료 조건을 사용할 수 있게 한다.
- daily/weekly/monthly만 유지한다. 생성 또는 빈도 변경은 event local start date의 요일/월 일자를 anchor로 사용한다.
- 기존 시리즈에서 frequency를 바꾸지 않으면 저장된 weekday/month-day anchor를 보존한다. 현재 UI가 선택할 수 없는 다중 weekday도 interval/end만 바꿀 때 손실하지 않는다.
- 이번 회차 편집은 exception content만 수정하며 recurrence rule을 바꾸지 않는다. 임의의 “이번 이후” 분할도 추가하지 않는다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. `CalendarRecurrenceRule`에 bounded anchored factory와 same-anchor interval/end copy를 추가한다.
2. factory는 interval `1..30`, count `1..1000`, until minimum local date를 검증하며 invalid input을 nullable domain result로 닫는다.
3. create는 event local start date 이상, whole-series edit은 active revision start date와 server-returned household local date 중 늦은 날짜 이상만 until로 허용한다. 서버는 저장 시 household local today를 다시 계산한다.
4. recurring draft fingerprint가 interval/end를 이미 포함하므로 같은 입력 retry는 command ID를 재사용하고 변경된 advanced rule은 새 ID를 받는다.
5. series update의 expected-version, immutable revision, future rebuild, past/exception 보존과 authoritative refresh는 기존 경계를 그대로 사용한다.
6. overlap preview에는 편집 중인 full rule을 전달하고 invalid recurrence 입력은 one-time 후보로 약화하지 않고 preview 자체를 생략한다.

## Presentation design

- frequency를 recurring으로 선택한 경우 interval, end mode, count 또는 until date와 localized live summary를 표시한다.
- count는 `1..1000`, interval은 `1..30`이며 until picker의 최소 날짜는 해당 create/edit boundary다.
- start date 변경으로 until이 최소 날짜보다 이르면 즉시 안전한 최소 날짜로 올린다.
- whole-series editor는 현재 interval/end를 prefill하고 unchanged frequency anchor를 보존한다.
- event card는 interval 1의 기존 daily/weekly/monthly 문구를 유지하고 non-default interval을 locale-aware 복수형으로 표시한다.
- EN/KO/EN-XA ARB만 사용하고 320×568, 200% text, scroll, 48dp action과 keyboard validation을 자동 검증한다.

## Automated evidence plan

1. anchored rule factory interval/end bounds and exact JSON
2. same-frequency copy preserves multi-weekday/month-day anchors and rejects invalid bounds
3. recurring-create same-input retry key reuse and advanced-input key rotation
4. creation UI interval/count and interval/until request mapping
5. start-date until clamping and invalid interval/count command suppression
6. whole-series edit prefill, same-frequency anchor preservation and changed-frequency re-anchor
7. overlap preview receives the exact edited rule and invalid input does not issue a degraded preview
8. localized event card/live summary and compact EN-XA 200% overflow regression
9. full Flutter tests, analyzer, format, codegen, localization, secret and whitespace gates

## Stop conditions and rollback

- invalid range가 preview, command ID, repository 또는 network에 도달하거나 same-frequency edit이 기존 anchor를 잃으면 배포하지 않는다.
- changed recurrence fingerprint가 이전 idempotency key를 재사용하거나 retry가 같은 입력에 새 key를 만들면 배포하지 않는다.
- occurrence exception 편집이 source recurrence rule을 바꾸거나 series boundary가 client date authority로 바뀌면 배포하지 않는다.
- rollback은 advanced editor와 full-rule presentation mapping을 제거하고 기존 anchored interval 1/never UI로 되돌린다. server rollback은 없다.

## Non-scope

- weekly multiple weekday 선택 UI, ordinal/month multiple date, yearly/business-day rule
- arbitrary this-and-future split 또는 single-occurrence recurrence 변경
- remote migration/provider/real-account/multi-device/physical-device evidence
