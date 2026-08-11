# Phase 04 WP04-11 Calendar Weekly Multiple-Weekday Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP04/G4 완료는 아님
- 수직 조각: existing strict weekly weekday array → localized selector → recurring create or whole-series update → authoritative reconciliation
- 요구사항: `FR-CAL-004`, `FR-CAL-006`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`
- 계약: `docs/contracts/calendar-weekly-weekdays.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_11_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Calendar 일정 생성과 전체 반복 시리즈 편집에서 weekly rule의 요일 1~7개를 선택할 수 있게 한다.
- 편집 event local start date의 요일은 source anchor invariant 때문에 항상 포함하며 UI에서 해제할 수 없다.
- 다른 요일은 자유롭게 추가·해제한다. wire 배열은 locale과 무관한 ISO 월요일~일요일 순서로 직렬화한다.
- start date가 바뀌면 기존 선택을 유지하면서 새 start weekday를 추가한다. 이전 anchor는 일반 선택으로 남아 사용자가 해제할 수 있다.
- daily/monthly, single-occurrence recurrence, arbitrary this-and-future split은 바꾸지 않는다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. weekly 전용 bounded copy factory가 frequency, unique 1..7, source weekday 포함, interval/end boundary를 모두 검증한다.
2. factory는 selected set을 ISO weekday order로 canonicalize하여 UI toggle 순서와 locale이 fingerprint를 흔들지 않게 한다.
3. create는 start weekday 하나로 시작하고 series edit은 active rule의 full weekday set을 prefill한다.
4. changed-to-weekly는 active revision event local start weekday로 시작한다. editor 안에서 frequency를 왕복하면 in-progress weekday set을 복원하되 현재 anchor를 다시 강제한다.
5. recurring draft fingerprint가 weekdays를 포함하므로 같은 selected set retry는 command ID를 재사용하고 semantic set 변경은 새 ID를 받는다.
6. overlap preview에는 canonical full rule을 전달하고 invalid weekly selection은 preview 자체를 생략한다.

## Presentation design

- weekly를 선택한 경우 ISO 순서의 localized weekday toggle 7개, anchor helper와 live selected-day summary를 표시한다.
- anchor chip은 selected/disabled 의미를 명확히 제공하고 나머지 chip은 최소 48dp target을 유지한다.
- event card도 weekly rule의 선택 요일을 localized summary로 표시한다.
- 320×568 EN-XA 200%에서 chip wrap과 dialog scroll을 자동 검증한다.
- 사용자 표시 문자열은 EN/KO/EN-XA ARB만 사용한다.

## Automated evidence plan

1. weekly factory accepts 1 and 7 weekdays, canonicalizes ISO order and rejects empty, duplicate, non-weekly and missing anchor
2. recurring-create maps selected weekdays exactly to overlap preview and repository request
3. anchor weekday cannot be deselected; added weekday can be toggled off
4. start-date change adds the new anchor and keeps prior selections
5. whole-series editor prefills multiple weekdays and saves additions/removals
6. changed-to-weekly anchors to active event start and frequency round-trip preserves in-progress set
7. weekday set change rotates idempotency key while exact retry reuses it
8. localized editor/card summary and compact EN-XA 200% overflow regression
9. full Flutter tests, analyzer, format, codegen, localization, secret and whitespace gates

## Stop conditions and rollback

- source start weekday가 빠진 rule, duplicate/empty weekday 또는 locale string이 preview, command ID, repository에 도달하면 배포하지 않는다.
- weekday toggle 순서만으로 fingerprint가 바뀌거나 unchanged series가 weekday set을 잃으면 배포하지 않는다.
- occurrence exception 편집이 source recurrence rule을 바꾸거나 series boundary가 client date authority로 바뀌면 배포하지 않는다.
- rollback은 selector와 weekly full-rule mapping을 제거하고 WP04-10의 start-date-only weekly anchor UI로 되돌린다. server rollback은 없다.

## Non-scope

- multiple month dates, ordinal weekday, yearly/business-day rule
- arbitrary this-and-future split 또는 single-occurrence recurrence 변경
- remote migration/provider/real-account/multi-device/physical-device evidence
