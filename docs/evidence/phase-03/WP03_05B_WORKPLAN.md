# Phase 03 WP03-05B Single-Occurrence Skip Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04/WP03-05A workspace
- 상태: LOCAL AUTOMATED SLICE COMPLETE (reschedule/reassign/restore/live gates deferred)
- 범위: materialized repeating chore의 한 회차만 versioned/idempotent하게 skip하고 Today에서 확인하는 vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | 반복 series/revision을 변경하지 않고 하나의 materialized occurrence만 `scheduled → skipped`로 전이한다. |
| FR-CHORE-007 (PARTIAL) | 한 회차 skip과 audit를 구현한다. reschedule/reassign와 restore는 후속 slice다. |
| D-020 (PARTIAL) | Store MVP의 “이번 회차” 범위를 최초로 열되 전체 시리즈 변경 API는 열지 않는다. |
| D-048 | expected occurrence version과 command UUID를 모두 사용해 stale write와 중복 요청을 안전하게 처리한다. |

## Command / State Contract

1. `skip_chore_occurrence(command, household, occurrence, expectedVersion)`은 repeating revision에 속한 `scheduled` occurrence만 `skipped`로 바꾼다.
2. one-time occurrence, completed/skipped/cancelled occurrence와 version mismatch는 변경하지 않는다.
3. Owner/Admin은 같은 가구 occurrence를 skip할 수 있고 Member는 자기 담당 occurrence만 가능하다. caller role과 assignee는 JWT와 DB row에서 계산한다.
4. 동일 user+command UUID와 동일 normalized input은 최초 result version을 반환한다. 같은 key의 다른 input은 거부한다.
5. 성공은 occurrence version을 정확히 1 증가시키고 content-free `skipped` audit event를 한 번만 기록한다.
6. series, active revision, recurrence rule, sibling occurrence의 assignee/status/version과 과거 completion event는 변경하지 않는다.
7. materializer replay는 stable occurrence key conflict 때문에 skipped row를 새 scheduled row로 덮어쓰지 않는다.
8. Today v2는 기존 계약대로 `scheduled`/`completed`만 반환하므로 skipped occurrence는 목록에서 제외된다.

## Flutter Boundary

1. skip draft/request/snapshot은 Flutter, Riverpod와 Supabase SDK에 독립적인 domain type으로 둔다.
2. adapter와 repository는 exact response key/type, request household/occurrence binding, literal `skipped` status와 `expectedVersion + 1`을 fail-closed로 검증한다.
3. Today는 scheduled repeating occurrence에만 “이번 회차 건너뛰기” 메뉴를 제공한다. one-time과 completed occurrence에는 노출하지 않는다.
4. destructive intent를 설명하는 확인 dialog 후 command를 보낸다. pending 중에는 다른 completion/skip/refresh를 막는다.
5. 성공하면 현재 Today에서 해당 occurrence만 제거하고 localized confirmation을 표시한다.
6. network 계열 실패는 occurrence를 유지하고 동일 input 재시도에서 같은 command UUID를 재사용한다. stale/invalid transition은 authoritative Today를 재조회한다.

## Automated Validation

- clean reset, DB lint와 schema/grant/RLS/role matrix
- repeating scheduled success, exact version/audit, Today exclusion과 sibling/series isolation
- command replay/different-input conflict, materializer replay, stale/invalid transition
- Owner/Admin, assigned Member, 비담당 Member, outsider, removed member와 direct-write denial
- one-time/completed occurrence 거부와 completion history 보존
- Dart fingerprint/parser/repository/adapter/controller retry·coalescing·reconcile
- Today menu/confirmation/success/error widget, EN/KO/pseudo와 200% text
- exact formatter/analyzer/full Flutter and pgTAP regression

## Explicit Non-scope

- skipped occurrence restore/unskip UI와 skip 취소 유예
- 이번 회차 reschedule/reassign 및 notes/title override
- 전체 시리즈 future revision/edit/cancel과 occurrence 재생성
- periodic horizon extension/repair worker
- offline outbox, Realtime/resume invalidation과 multi-client live reconciliation
- production deploy와 actual Google account/two-device validation

## Stop / Rollback

- skip이 series/revision 또는 sibling occurrence를 변경하거나 materializer replay가 skipped 상태를 덮어쓰면 배포하지 않는다.
- one-time/completed occurrence가 skip되거나 Member가 다른 담당자의 occurrence를 변경하면 배포하지 않는다.
- production 적용 전에는 새 migration과 Today skip surface를 revert한다.
- production 적용 후에는 migration을 수정·삭제하지 않고 `skip_chore_occurrence` execute grant를 회수한 뒤 forward fix를 추가한다. UI-only rollback은 skip 메뉴를 숨기고 read/complete 기능을 유지한다.

## Completion Boundary

자동 검증이 green이어도 reschedule/reassign/restore, future-series edit, horizon worker와 실제 성인 2계정·2기기 결과가 없으므로 FR-CHORE-007, WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
