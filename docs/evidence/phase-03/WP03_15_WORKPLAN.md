# Phase 03 WP03-15 Chore Weekly Multiple-Weekday Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP03/G3 완료는 아님
- 수직 조각: existing strict weekly weekday array → localized selector → recurring create or future-series update → authoritative reconciliation
- 요구사항: `FR-CHORE-005`, `FR-CHORE-008`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`
- 계약: `docs/contracts/chore-weekly-weekdays.yaml.md`
- 증거: `docs/evidence/phase-03/WP03_15_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- 반복 집안일 생성과 Today의 미래 시리즈 편집에서 weekly rule의 요일 1~7개를 선택할 수 있게 한다.
- 생성은 기존 RPC와 draft가 요구하는 start date 요일을 항상 포함하며 UI에서 해제할 수 없다.
- 미래 시리즈 편집은 server-authoritative household effective local date를 변경 경계로만 사용한다. active rule의 전체 요일을 prefill하고 어느 요일이든 편집할 수 있지만 최소 한 요일은 유지한다.
- changed-to-weekly는 household effective local date 요일 하나로 시작한다. wire 배열은 locale과 무관한 ISO 월요일~일요일 순서로 직렬화한다.
- daily/monthly, guided exact-three setup, occurrence exception model은 바꾸지 않는다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. weekly 전용 bounded copy factory가 frequency, unique 1..7, optional required start weekday, interval/end boundary를 모두 검증한다.
2. factory는 selected set을 ISO weekday order로 canonicalize하여 UI toggle 순서와 locale이 fingerprint를 흔들지 않게 한다.
3. create는 start weekday 하나로 시작하고 start date 변경 시 기존 선택을 유지하면서 새 anchor를 추가한다.
4. series edit은 active weekly rule의 full set을 prefill한다. frequency를 바꾸었다 돌아오면 in-progress set을 복원하고, changed-to-weekly 최초 진입은 effective-date weekday로 초기화한다.
5. recurring draft와 series update fingerprint가 weekdays를 포함하므로 같은 selected set retry는 command ID를 재사용하고 semantic set 변경은 새 ID를 받는다.
6. invalid empty, duplicate, missing creation anchor 또는 non-weekly weekday copy는 command ID와 repository 전에 차단한다.

## Presentation design

- weekly를 선택한 경우 ISO 순서의 localized weekday toggle 7개와 live selected-day summary를 표시한다.
- 생성 anchor chip은 잠그고 이유를 설명한다. 시리즈 편집은 마지막 selected chip만 잠가 최소 한 요일 조건을 설명한다.
- template 적용은 interval 1/never와 함께 current due-date weekday 하나로 재설정한다.
- 320×568 EN-XA 200%에서 chip wrap과 scrollable dialog를 자동 검증한다.
- 사용자 표시 문자열은 EN/KO/EN-XA ARB만 사용한다.

## Automated evidence plan

1. weekly factory accepts 1 and 7 weekdays, canonicalizes ISO order and rejects empty, duplicate, non-weekly and missing required anchor
2. recurring-create maps selected weekdays exactly to repository request and creation start anchor cannot be deselected
3. start-date change adds the new creation anchor while preserving prior selections
4. template application resets the weekday set to the current due-date anchor
5. future-series editor prefills multiple weekdays and saves additions/removals without requiring the effective-date weekday
6. changed-to-weekly initializes from household effective date and frequency round-trip preserves the in-progress set
7. weekday set change rotates idempotency key while exact retry reuses it
8. localized live summary and compact EN-XA 200% overflow/touch-target regression
9. full Flutter tests, analyzer, format, codegen, localization, secret and whitespace gates

## Stop conditions and rollback

- creation start weekday가 빠진 rule, empty/duplicate weekday 또는 locale string이 command ID나 repository에 도달하면 배포하지 않는다.
- weekday toggle 순서만으로 fingerprint가 바뀌거나 unchanged series가 active weekday set을 잃으면 배포하지 않는다.
- future-series boundary가 client device date authority로 바뀌거나 past/completed occurrence 의미가 바뀌면 배포하지 않는다.
- rollback은 selector와 weekly full-rule mapping을 제거하고 WP03-14의 start-date-only creation 및 saved-anchor-preserving series UI로 되돌린다. server rollback은 없다.

## Non-scope

- multiple month dates, ordinal weekday, yearly/business-day rule
- guided exact-three setup advanced controls와 individual occurrence recurrence 변경
- remote migration/provider/real-account/multi-device/physical-device evidence
