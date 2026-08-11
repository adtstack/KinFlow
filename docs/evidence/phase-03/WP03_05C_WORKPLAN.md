# Phase 03 WP03-05C Skipped-Occurrence Immediate Restore Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04/WP03-05A/WP03-05B workspace
- 상태: LOCAL AUTOMATED SLICE COMPLETE (persistent history/reschedule/reassign/live gates deferred)
- 범위: 방금 skip한 materialized repeating occurrence를 versioned/idempotent하게 `skipped → scheduled`로 복구하는 bounded Undo vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | single-occurrence skip을 series/revision 변경 없이 즉시 복구할 수 있게 한다. |
| FR-CHORE-007 (PARTIAL) | 한 회차 skip의 사용자 오류 복구를 추가한다. reschedule/reassign는 후속 slice다. |
| D-020 (PARTIAL) | “이번 회차” 상태 예외만 되돌리고 전체 시리즈나 다른 회차는 변경하지 않는다. |
| D-048 | expected occurrence version과 새 command UUID로 stale write와 중복 Undo를 안전하게 처리한다. |

## Command / State Contract

1. `restore_skipped_chore_occurrence(command, household, occurrence, expectedVersion)`은 repeating revision에 속한 `skipped` occurrence만 `scheduled`로 바꾼다.
2. scheduled/completed/cancelled와 one-time occurrence, version mismatch는 변경하지 않는다.
3. Owner/Admin은 같은 가구 occurrence를 복구할 수 있고 Member는 자기 담당 occurrence만 가능하다. caller role과 assignee는 JWT와 DB row에서 계산한다.
4. 동일 user+command UUID와 동일 normalized input은 최초 scheduled result version을 반환한다. 같은 key의 다른 input은 거부한다.
5. 성공은 occurrence version을 정확히 1 증가시키고 completion actor/time을 null로 유지한다.
6. baseline audit allowlist를 임의 확장하지 않는다. `skipped → scheduled` 복구는 기존 `reopened` event로 한 번 기록하며 직전 `skipped` event와 version sequence로 의미를 구분한다.
7. series, revision, recurrence rule, assignee, sibling occurrence와 과거 completion/skip audit는 변경하지 않는다.
8. materializer replay는 복구된 stable occurrence를 중복 생성하거나 overwrite하지 않는다.

## Flutter Boundary

1. restore draft/request/snapshot은 Flutter, Riverpod와 Supabase SDK에 독립적인 domain type으로 둔다.
2. adapter와 repository는 exact response key/type, request household/occurrence binding, literal `scheduled` status와 `expectedVersion + 1`을 fail-closed로 검증한다.
3. skip 성공 시 서버가 반환한 skipped version과 제거 전 occurrence/index를 메모리의 단일 `undoableSkip`으로 유지한다. 디스크에 저장하지 않는다.
4. 성공 SnackBar는 localized Undo action을 제공한다. 새 skip, 명시적 Today reload, app/session 재시작 뒤에는 이전 Undo를 보장하지 않는다.
5. Undo는 occurrence를 원래 위치에 optimistic하게 복원하고 pending 중 completion/skip/refresh를 막는다.
6. 성공하면 server version으로 reconcile하고 Undo token을 폐기한다. network 계열 실패는 optimistic row를 다시 제거하고 동일 command UUID로 재시도할 수 있게 한다.
7. stale/invalid transition은 authoritative Today를 재조회한다. 이미 scheduled row가 보이면 목표 달성으로 처리하고, 아니면 만료된 Undo token을 폐기한다.
8. 이전 client는 restore RPC를 호출하지 않으며 기존 skip/Today/create/complete 계약을 그대로 사용한다.

## Automated Validation

- clean reset, DB lint와 schema/grant/RLS/role matrix
- skipped→scheduled success, exact version/reopened audit와 Today 재등장
- command replay/different-input conflict, stale/invalid transition과 materializer replay
- Owner/Admin, assigned Member, 비담당 Member, outsider, removed member와 direct-write denial
- scheduled/completed/one-time 거부, sibling/series/revision/completion/skip history 보존
- Dart fingerprint/parser/repository/adapter/controller optimistic restore·retry·coalescing·reconcile
- Today skip SnackBar Undo success/failure retry, EN/KO/pseudo와 200% text/48dp action
- exact formatter/analyzer/full Flutter and pgTAP regression

## Explicit Non-scope

- 앱 재시작 후 skipped history/detail에서 복구하는 persistent surface
- 여러 과거 skip을 쌓는 Undo queue와 configurable grace period
- 이번 회차 reschedule/reassign 및 notes/title override
- 전체 시리즈 future revision/edit/cancel과 occurrence 재생성
- periodic horizon extension/repair worker
- offline outbox, Realtime/resume invalidation과 multi-client live reconciliation
- production deploy와 actual Google account/two-device validation

## Stop / Rollback

- restore가 one-time/non-skipped occurrence 또는 series/revision/sibling을 변경하면 배포하지 않는다.
- Member가 다른 담당자의 occurrence를 복구하거나 replay가 audit/version을 중복 증가시키면 배포하지 않는다.
- production 적용 전에는 새 migration과 SnackBar Undo wiring을 revert한다.
- production 적용 후에는 migration을 수정·삭제하지 않고 `restore_skipped_chore_occurrence` execute grant를 회수한 뒤 forward fix를 추가한다. UI-only rollback은 Undo action만 숨기고 skip/read/complete를 유지한다.

## Completion Boundary

자동 검증이 green이어도 persistent restore history, reschedule/reassign, future-series edit, horizon worker와 실제 성인 2계정·2기기 결과가 없으므로 FR-CHORE-007, WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
