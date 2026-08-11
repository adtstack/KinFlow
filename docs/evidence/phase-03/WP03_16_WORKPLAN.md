# Phase 03 WP03-16 Chore Monthly Day-of-Month Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP03/G3 완료는 아님
- 수직 조각: existing strict monthly `monthDay` → localized selector and skip policy → recurring create or future-series update → authoritative reconciliation
- 요구사항: `FR-CHORE-005`, `FR-CHORE-008`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`
- 계약: `docs/contracts/chore-monthly-month-day.yaml.md`
- 예정 증거: `docs/evidence/phase-03/WP03_16_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- 반복 집안일 생성과 Today의 미래 시리즈 편집에서 monthly rule의 월 기준일 1~31일을 명시적으로 보여 준다.
- 생성은 기존 RPC와 draft가 요구하는 start date day를 사용한다. 날짜 control은 읽기 전용이며 due date를 바꾸면 함께 바뀐다.
- 미래 시리즈 편집은 active monthly rule을 그대로 prefill하고 1~31일 중 하나로 바꿀 수 있다. changed-to-monthly는 server-authoritative household effective local date의 day로 시작한다.
- 해당 날짜가 없는 달은 건너뛰며 말일로 보정하지 않는다. 실제 생성된 날짜만 count 종료 횟수를 소비한다.
- daily/weekly, guided exact-three setup, occurrence exception model은 바꾸지 않는다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. monthly 전용 bounded copy factory가 frequency, monthDay `1..31`, interval/end boundary를 함께 검증한다.
2. create는 due date에서 monthDay를 파생하여 생성 anchor 불변식을 유지한다.
3. series edit은 active monthly monthDay를 prefill한다. frequency를 바꾸었다 돌아오면 in-progress 값을 복원하고, 처음 monthly로 바꿀 때는 household effective local date day를 사용한다.
4. future-series update draft는 effective boundary와 monthDay가 달라도 허용한다. server가 boundary 이후의 첫 matching local date부터 materialize한다.
5. recurring draft와 series update fingerprint가 monthDay를 포함하므로 같은 값 retry는 command ID를 재사용하고 값 변경은 새 ID를 받는다.
6. invalid non-monthly copy 또는 `0/32`는 command ID와 repository 전에 차단한다.

## Presentation design

- monthly를 선택한 경우 localized 1~31일 dropdown과 live summary를 표시한다.
- 생성 화면 dropdown은 비활성화하고 첫 예정일이 기준임을 설명한다. due date 변경은 control과 summary를 즉시 갱신한다.
- 미래 시리즈 dropdown은 활성화한다. 29~31일을 포함해 선택 날짜가 없는 달은 건너뛰고 말일로 이동하지 않음을 명시한다.
- 320×568 EN-XA 200%에서 dropdown, helper와 scrollable dialog overflow를 자동 검증한다.
- 사용자 표시 문자열은 EN/KO/EN-XA ARB만 사용한다.

## Automated evidence plan

1. monthly copy factory accepts 1 and 31 while preserving interval/end, and rejects 0, 32 and non-monthly input
2. recurring-create derives monthDay from the due date and updates it after due-date change
3. creation monthly selector is locked and explains the anchor and missing-date policy
4. future-series editor prefills the exact active monthDay and saves a changed day
5. changed-to-monthly initializes from household effective date and frequency round-trip preserves the in-progress day
6. monthDay change rotates idempotency key while exact retry reuses it
7. localized live summary and compact EN-XA 200% overflow regression
8. existing SQL monthly day-31 skip, no-clamp and future-series materialization evidence remains green
9. full Flutter tests, analyzer, format, codegen, localization, secret and whitespace gates

## Stop conditions and rollback

- creation rule의 monthDay가 start date day와 다르거나 `0/32`가 command ID 또는 repository에 도달하면 배포하지 않는다.
- monthly frequency round-trip이 in-progress day를 잃거나 unchanged series가 active monthDay를 잃으면 배포하지 않는다.
- missing-date 처리가 clamp-to-last-day로 바뀌거나 future-series boundary가 client device date authority로 바뀌면 배포하지 않는다.
- rollback은 month-day selector와 monthly copy mapping을 제거하고 WP03-15의 due-date-derived creation 및 saved-anchor-preserving series UI로 되돌린다. server rollback은 없다.

## Non-scope

- multiple month dates, last-day, ordinal weekday, yearly/business-day rule
- guided exact-three setup advanced controls와 individual occurrence recurrence 변경
- remote migration/provider/real-account/multi-device/physical-device evidence
