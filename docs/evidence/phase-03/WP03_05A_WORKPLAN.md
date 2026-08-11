# Phase 03 WP03-05A Repeating Chore Creation Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04 workspace
- 상태: LOCAL AUTOMATED SLICE COMPLETE (live/worker/edit gates deferred)
- 범위: canonical recurrence rule 생성, bounded initial occurrence materialization과 Today 반복 표시 vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | daily/weekly/monthly recurrence definition과 revision 분리, 생성 시 bounded occurrence materialization을 구현한다. single occurrence/future series edit는 후속 slice다. |
| FR-CHORE-005 (PARTIAL) | 서버는 interval 1~30과 never/count/until 종료 조건을 포함한 canonical daily/weekly/monthly subset을 검증한다. 앱의 첫 surface는 시작일에 anchor된 interval 1·never 규칙만 노출한다. |
| FR-CHORE-006 (PARTIAL) | 생성 transaction에서 시작일 포함 366일 이하 window를 materialize하고 stable series+local-date key와 conflict-ignore로 retry를 안전하게 만든다. 주기적 horizon worker는 후속 slice다. |
| D-019 | series identity, immutable revision rule과 materialized occurrence 상태를 분리한다. completion은 occurrence만 변경한다. |
| D-020 | 이번 slice에는 recurrence edit scope를 노출하지 않는다. 이번 회차/전체 시리즈 편집은 별도 plan에서 version/history 계약과 함께 구현한다. |

## Recurrence Contract

1. canonical repeat rule은 `frequency`, `interval`, frequency별 selector와 `end`만 허용한다. 알 수 없는 key/type/value는 서버에서 거부한다.
2. daily는 interval 1~30, weekly는 중복 없는 MO~SU 1~7개, monthly는 monthDay 1~31을 사용한다.
3. end는 never, count 1~1000 또는 start 이상인 until local date다.
4. 생성 form의 first due date는 첫 occurrence다. 따라서 weekly rule은 그 날짜의 weekday를 포함하고 monthly monthDay는 그 날짜의 day와 같아야 한다.
5. monthly day가 없는 달은 그 달을 건너뛴다. clamp하지 않는다.
6. timed occurrence는 series의 household IANA timezone과 local date/time으로 UTC instant를 계산한다. DST gap/fold의 최종 제품 정책과 cross-zone fixture는 Phase 04 dependency Gate 전까지 완료로 주장하지 않는다.
7. initial materialization window는 first due date부터 최대 365일 뒤까지 포함한다. end 조건이 먼저 끝나면 실제 마지막 occurrence에서 종료한다.

## Data / API Boundary

1. forward migration은 recurrence JSON validator, private bounded materializer, recurring-create idempotency record와 `create_repeating_chore` RPC를 추가한다.
2. series/revision/occurrence 기존 table을 재사용하며 recurrence rule constraint를 `once`와 canonical repeating subset 모두에 적용한다.
3. RPC는 JWT user와 active household/member/assignee를 서버에서 파생·검증하고 series, revision, occurrences, command result와 content-free domain event를 한 transaction에서 기록한다.
4. 동일 user+command UUID와 동일 normalized input은 최초 series/materialization summary를 반환한다. 같은 key의 다른 input은 거부한다.
5. 기존 `get_today_chores`는 N-1 호환을 위해 유지하고, recurrence frequency를 추가한 `get_today_chores_v2`를 새 앱이 사용한다.
6. private validator/materializer/idempotency table은 client에서 실행하거나 읽고 쓸 수 없다.

## Flutter Boundary

1. recurrence rule/draft/request/result는 Flutter, Riverpod와 Supabase SDK에 독립적인 domain type으로 둔다.
2. create 화면은 반복 안 함/매일/매주/매월을 선택하고 first due date에 anchor된 interval 1·never canonical rule을 만든다.
3. recurring controller는 one-time controller와 idempotency/retry/duplicate-submit 동작을 동일하게 유지한다.
4. Supabase adapter와 repository는 strict response key/type, request household/rule binding, materialized count/window와 generated IDs를 검증한다.
5. Today occurrence는 optional recurrence frequency를 표시한다. one-time occurrence는 기존 UI와 payload 의미를 유지한다.

## Automated Validation

- clean reset, lint와 pgTAP validator/schema/grant/RLS/role/idempotency matrix
- daily/weekly/monthly, never/count/until, monthly missing-day skip, timed/all-day와 bounded 366-day fixture
- materializer replay no duplicate, completion이 다른 occurrence와 recurrence definition을 변경하지 않는지 검증
- v1 Today 호환과 v2 recurrence metadata, outsider/removed member/direct mutation 거부
- Dart recurrence normalization/fingerprint/parser, strict repository/adapter mapping
- controller same-key retry/duplicate submit과 create form/Today recurrence widget
- EN/KO/pseudo, 200% text, exact analyzer/formatter/full regression

## Explicit Non-scope

- periodic cron/worker lease와 sliding horizon extension/repair command
- 이번 회차 edit/cancel/reschedule/reassign와 전체 시리즈 future revision
- custom interval/end/복수 weekday를 고르는 client UI; 서버 계약만 먼저 지원
- DST gap/fold 제품 정책 확정, timezone library 추가와 travel/device-timezone preview
- upcoming/completed list, recurrence detail/history screen, offline outbox와 Realtime
- production deploy와 actual Google account/two-device validation

## Stop / Rollback

- duplicate materialization, completed occurrence overwrite, cross-household read/write 또는 private function/table client 접근이 가능하면 배포하지 않는다.
- 기존 one-time create/Today v1 contract가 깨지거나 old one-time row가 새 recurrence constraint를 통과하지 못하면 migration을 교정한다.
- production 적용 전에는 새 migration과 recurring client surface를 revert한다.
- production 적용 후에는 migration을 수정·삭제하지 않고 recurring RPC execute grant를 회수한 뒤 forward fix를 추가한다. UI rollback은 repeat selector를 숨겨 one-time create만 유지한다.

## Completion Boundary

자동 검증이 green이어도 periodic horizon worker, recurrence edit/exception과 실제 성인 2계정·2기기 결과가 없으므로 WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
