# Phase 03 WP03-05D Single-Occurrence Reschedule Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04/WP03-05A/WP03-05B/WP03-05C workspace
- 상태: COMPLETE — local automated slice, live validation deferred
- 범위: materialized repeating chore의 scheduled 한 회차만 versioned/idempotent하게 다른 local date/time으로 이동하는 bounded vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | canonical recurrence와 stable occurrence identity를 유지한 채 한 회차의 유효 due schedule만 변경한다. |
| FR-CHORE-007 (PARTIAL) | skip/restore에 이어 한 회차 reschedule을 추가한다. reassign는 후속 slice다. |
| D-019 | recurrence definition, immutable revision과 materialized occurrence state를 분리한다. |
| D-020 (PARTIAL) | “이번 회차”만 변경하며 “이번 이후” 또는 전체 series mutation으로 확장하지 않는다. |
| D-048 | expected occurrence version과 새 command UUID로 stale write와 중복 제출을 안전하게 처리한다. |

## Command / State Contract

1. `reschedule_chore_occurrence(command, household, occurrence, expectedVersion, dueLocalDate, dueLocalTime)`은 repeating revision에 속한 `scheduled` occurrence만 변경한다.
2. completed/skipped/cancelled와 one-time occurrence, version mismatch, 현재와 같은 local date/time은 변경하지 않는다.
3. Owner/Admin은 같은 가구 occurrence를 변경할 수 있고 Member는 자기 담당 occurrence만 가능하다. caller role과 assignee는 JWT와 DB row에서 계산한다.
4. 동일 user+command UUID와 동일 normalized input은 최초 schedule/version을 반환한다. 같은 key의 다른 input은 거부한다.
5. 성공은 occurrence의 `due_local_date`, `due_at`, `updated_at`, `version`만 변경한다. `occurrence_key`, status, assignee, completion fields, series와 revision은 보존한다.
6. local time이 null이면 all-day로 `due_at`을 null 처리한다. timed schedule은 occurrence의 기존 IANA timezone과 PostgreSQL local-time 변환을 사용한다.
7. 기존 completion audit event allowlist는 확장하지 않는다. 별도 immutable `chore_reschedule_events`에 이전/새 local date/time, actor IDs, occurrence version과 correlation ID만 기록한다.
8. materializer replay는 stable occurrence key conflict로 rescheduled occurrence를 중복 생성하거나 원래 schedule로 overwrite하지 않는다.
9. Today v2는 occurrence의 effective `due_at`에서 local time을 계산한다. target date가 household Today가 아니면 목록에서 빠지고 같은 날짜면 새 due time 순서로 나타난다.

## Flutter Boundary

1. reschedule draft/request/snapshot은 Flutter, Riverpod와 Supabase SDK에 독립적인 domain type으로 둔다.
2. adapter/repository는 exact response key/type, household/occurrence binding, literal `scheduled`, requested date/time, UTC `dueAt`과 `expectedVersion + 1`을 fail-closed로 검증한다.
3. Today controller는 requested schedule을 optimistic하게 적용한다. Today 밖이면 대상만 제거하고 같은 날이면 effective local time(all-day nulls last), title, ID로 재정렬한다. 같은 household local date에서는 서버의 `due_at nulls last` 순서와 동치이며 optimistic/server UTC 표현을 섞지 않는다.
4. pending 중 completion/skip/reschedule/refresh를 합치거나 차단한다. retryable failure는 원래 row를 복원하고 동일 command UUID로 같은 draft를 재시도한다.
5. stale/invalid transition은 authoritative Today를 다시 읽고 안전한 conflict 메시지를 표시한다.
6. scheduled repeating row의 추가 메뉴에 localized “이번 회차 일정 변경”을 노출한다. dialog에서 날짜, optional time/all-day를 편집하고 현재와 같은 값은 제출하지 않는다.
7. 성공은 localized SnackBar로 알린다. EN/KO/pseudo와 320×568dp·200% text에서 dialog scroll, 48dp action과 기존 skip 흐름을 검증한다.

## Automated Validation

- clean reset, DB lint와 schema/grant/RLS/role matrix
- timed→timed, timed→all-day, date move, exact version과 immutable before/after audit
- command replay/different-input conflict, stale/no-op/invalid transition과 materializer replay
- Owner/Admin, assigned Member, 비담당 Member, outsider, removed member와 direct-write denial
- one-time/completed/skipped 거부, sibling/series/revision/status/assignee/completion history 보존
- Today source-date exclusion, target-date inclusion/effective time ordering 계약
- Dart fingerprint/reorder, parser/repository/adapter/controller optimistic removal·reorder·retry·reconcile
- Today reschedule dialog success/failure, 기존 skip/Undo 회귀, EN/KO/pseudo와 200% text/48dp action
- exact formatter/analyzer/full Flutter and pgTAP regression

## Explicit Non-scope

- one-time chore의 title/notes/due 수정과 삭제
- 한 회차 담당자 변경(reassign) 또는 title/notes override
- 앱 재시작 뒤 과거 exception을 조회·복구하는 history/detail surface
- 전체 series future revision/edit/cancel과 occurrence 재생성
- periodic horizon extension/repair worker
- notification intent 재계산, offline outbox, Realtime/resume invalidation과 multi-client live reconciliation
- production deploy와 actual Google account/two-device validation

## Stop / Rollback

- reschedule이 one-time/non-scheduled occurrence 또는 series/revision/sibling/occurrence key를 변경하면 배포하지 않는다.
- Member가 다른 담당자의 occurrence를 변경하거나 replay가 audit/version을 중복 증가시키면 배포하지 않는다.
- production 적용 전에는 새 migration과 reschedule UI wiring을 revert한다.
- production 적용 후에는 migration을 수정·삭제하지 않고 `reschedule_chore_occurrence` execute grant를 회수한 뒤 forward fix를 추가한다. UI-only rollback은 reschedule menu만 숨기고 create/read/complete/skip/restore를 유지한다.

## Completion Boundary

자동 검증이 green이어도 reassign, persistent exception history, future-series edit, horizon worker와 실제 성인 2계정·2기기 결과가 없으므로 FR-CHORE-007, WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
