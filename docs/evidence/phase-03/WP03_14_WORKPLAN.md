# Phase 03 WP03-14 Advanced Chore Recurrence Editor Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP03/G3 완료는 아님
- 수직 조각: existing strict recurrence rule → interval/end editor → create or future-series update → authoritative reconciliation
- 요구사항: `FR-CHORE-005`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`
- 계약: `docs/contracts/chore-advanced-recurrence.yaml.md`
- 증거: `docs/evidence/phase-03/WP03_14_EVIDENCE.md`
- 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- 반복 집안일 생성과 Today의 미래 시리즈 편집에서 기존 server-supported interval `1..30`과 `never|count|until` 종료 조건을 사용할 수 있게 한다.
- daily/weekly/monthly만 유지한다. weekly는 생성 start date의 요일, monthly는 start date의 일자를 anchor로 사용한다.
- 기존 시리즈에서 frequency를 바꾸지 않으면 저장된 weekday/month-day anchor를 보존한다. frequency를 바꾸면 server-authoritative household effective local date로 새 anchor를 만든다.
- guided exact-three setup은 빠른 activation 흐름이므로 daily/weekly, interval 1, never end로 유지한다.
- DB schema, migration, RPC, RLS, Edge, package와 native permission은 바꾸지 않는다.

## Domain and application design

1. `ChoreRecurrenceRule`에 bounded anchored factory와 same-anchor interval/end copy를 추가한다.
2. factory는 interval 범위와 count/until shape를 검증하며 invalid input을 nullable domain result로 닫는다.
3. creation controller는 frequency 대신 완성된 strict rule을 받아 start date/time과 함께 `RecurringChoreDraft`에서 다시 검증한다.
4. draft fingerprint가 interval/end를 포함하므로 retry 중 변경은 새 command ID를 받고 동일 입력 retry는 기존 ID를 재사용한다.
5. series update는 기존 expected-version/idempotency/controller와 authoritative Today reload를 그대로 사용한다.

## Presentation design

- 재사용 가능한 recurrence editor가 frequency, interval, end mode, count 또는 until date와 localized live summary를 제공한다.
- count는 `1..1000`, interval은 `1..30`, until은 start/effective date 이전을 허용하지 않는다.
- 생성 date 변경 시 invalid until을 새 start date로 올리고, template 적용은 simple interval 1/never로 명시적으로 재설정한다.
- series edit은 현재 interval/end를 prefill하고 unchanged frequency anchor를 보존한다.
- EN/KO/EN-XA ARB만 사용하고 320×568, 200% text, scroll, 48dp action과 keyboard validation을 자동 검증한다.

## Automated evidence plan

1. anchored rule factory interval/end bounds and exact JSON
2. same-frequency copy preserves weekly weekdays/month-day and rejects invalid bounds
3. creation controller same-input retry key reuse and advanced-input key rotation
4. creation UI interval/count and interval/until request mapping
5. template reset to interval 1/never and date-change until clamping
6. future-series edit prefill, same-frequency anchor preservation and changed-frequency re-anchor
7. invalid interval/count/until blocks request and exposes localized validation only
8. compact EN-XA 200% scroll/target/overflow regression
9. full Flutter tests, analyzer, format, codegen, localization, secret and whitespace gates

## Stop conditions and rollback

- invalid range가 command ID/repository/network에 도달하거나 same-frequency edit이 기존 anchor를 잃으면 배포하지 않는다.
- changed recurrence fingerprint가 이전 idempotency key를 재사용하거나 retry가 같은 입력에 새 key를 만들면 배포하지 않는다.
- rollback은 advanced editor와 full-rule creation parameter를 제거하고 기존 anchored interval 1/never UI로 되돌린다. server rollback은 없다.

## Non-scope

- weekly multiple weekday, ordinal/month multiple date, yearly/business-day rule
- individual occurrence editor와 exception model 변경
- guided setup advanced controls
- remote migration/provider/real-account/multi-device/physical-device evidence
