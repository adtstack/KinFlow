# Phase 03 WP03-05E Single-Occurrence Reassign Work Plan

- 작성일: 2026-08-07
- 기준 commit: `a85f262` + current WP02-06/WP03-04/WP03-05A/B/C/D workspace
- 상태: COMPLETE — LOCAL AUTOMATED SLICE (real-account/two-device live deferred)
- 범위: materialized repeating chore의 scheduled 한 회차만 versioned/idempotent하게 다른 active adult member에게 재할당하는 bounded vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-05 (PARTIAL) | canonical recurrence와 stable occurrence identity를 유지한 채 한 회차의 effective assignee만 변경한다. |
| FR-CHORE-002 (PARTIAL) | 한 회차도 정확히 한 명의 active adult primary assignee를 유지한다. unassigned/multiple assignment는 열지 않는다. |
| FR-CHORE-007 (PARTIAL) | skip/restore/reschedule에 이어 한 회차 reassign을 추가한다. persistent exception recovery는 후속 slice다. |
| D-019 | recurrence definition의 default assignee와 materialized occurrence의 effective assignee를 분리한다. |
| D-020 (PARTIAL) | “이번 회차”만 변경하며 future-series 또는 전체 series mutation으로 확장하지 않는다. |
| D-048 | expected occurrence version과 새 command UUID로 stale write와 중복 제출을 안전하게 처리한다. |

## Command / State Contract

1. `reassign_chore_occurrence(command, household, occurrence, expectedVersion, assigneeMember)`은 repeating revision에 속한 `scheduled` occurrence만 변경한다.
2. completed/skipped/cancelled와 one-time occurrence, stale version, removed/cross-household target과 현재 담당자로의 no-op은 변경하지 않는다.
3. Owner/Admin은 같은 household occurrence를 변경할 수 있다. Member는 현재 자기 담당 occurrence만 다른 active household adult에게 넘길 수 있다. caller role, current assignee와 target availability는 JWT와 DB row에서 계산한다.
4. 동일 user+command UUID와 동일 normalized input은 최초 assignee/version을 반환한다. 같은 key의 다른 input은 거부한다.
5. 성공은 occurrence의 `assignee_member_id`, `updated_at`, `version`만 변경한다. `occurrence_key`, status, due fields, completion fields, series/revision/default assignee와 sibling occurrence는 보존한다.
6. materializer replay는 stable occurrence key conflict로 reassigned occurrence를 중복 생성하거나 revision default assignee로 overwrite하지 않는다.
7. 별도 immutable `public.chore_assignment_events`에 actor, 이전/새 assignee IDs, occurrence version과 correlation ID만 기록한다. 이름, title, notes, email과 provider payload는 기록하지 않는다.
8. Today v2는 occurrence의 effective assignee와 현재 display name을 반환하므로 한 회차만 새 담당자로 표시한다.

## Flutter Boundary

1. reassignment draft/request/snapshot은 Flutter, Riverpod와 Supabase SDK에 독립적인 domain type으로 둔다.
2. adapter/repository는 exact response key/type, household/occurrence/target binding, literal `scheduled`, normalized display name과 `expectedVersion + 1`을 fail-closed로 검증한다.
3. Today controller는 target ID/display name을 optimistic하게 적용한다. retryable failure는 원래 row를 복원하고 같은 command UUID로 같은 draft를 재시도한다.
4. pending 중 completion/skip/reschedule/reassign/refresh를 합치거나 차단한다. stale/invalid transition은 authoritative Today를 다시 읽고 conflict 메시지를 표시한다.
5. scheduled repeating row의 추가 메뉴에서 roster를 새로 읽은 뒤 localized “이번 회차 담당자 변경” dialog를 연다. active adult 한 명을 선택하고 현재 담당자 no-op은 제출하지 않는다.
6. 서버 snapshot의 display name으로 optimistic 값을 reconcile하고 성공은 localized SnackBar로 알린다.
7. EN/KO/pseudo와 320×568dp·200% text에서 3항목 popup scroll, dialog scroll, 최소 48dp action과 기존 reschedule/skip/Undo 흐름을 검증한다.

## Automated Validation

- clean reset, DB lint와 schema/grant/RLS/role matrix
- assigned Member/Owner/Admin success, active target validation과 current-assignee no-op
- exact occurrence version, immutable before/after assignment audit와 same-input replay
- different-input idempotency conflict, stale/non-scheduled/one-time denial
- non-assigned Member, outsider, removed actor/target와 direct/private mutation denial
- sibling, series/revision/default assignee, due/status/completion history와 materializer replay 보존
- Today effective assignee/display name 반영
- Dart fingerprint/reassign copy, parser/repository/adapter/controller optimistic/retry/reconcile
- roster load failure, selection/no-op/success, 기존 reschedule/skip/Undo 회귀와 200% text/48dp action
- exact formatter/analyzer/full Flutter and pgTAP regression

## Explicit Non-scope

- one-time chore의 일반 edit/delete와 series default assignee 변경
- unassigned 또는 multiple assignee 정책
- completed/skipped occurrence의 담당자 변경
- 앱 재시작 뒤 exception history 조회·복구 또는 이전 담당자로 Undo
- future-series edit/cancel과 occurrence 재생성
- periodic horizon extension/repair worker
- notification intent 재계산, offline outbox, Realtime/resume invalidation과 multi-client live reconciliation
- production deploy와 actual Google account/two-device validation

## Stop / Rollback

- reassign이 one-time/non-scheduled occurrence 또는 series/revision/default assignee/sibling/occurrence key를 변경하면 배포하지 않는다.
- Member가 다른 담당자의 occurrence를 변경하거나 removed/cross-household target을 지정하거나 replay가 audit/version을 중복 증가시키면 배포하지 않는다.
- production 적용 전에는 새 migration과 reassignment UI wiring을 revert한다.
- production 적용 후에는 migration을 수정·삭제하지 않고 `reassign_chore_occurrence` execute grant를 회수한 뒤 forward fix를 추가한다. UI-only rollback은 reassign 메뉴만 숨기고 기존 기능과 이미 변경된 occurrence/audit를 보존한다.

## Completion Boundary

자동 검증이 green이어도 persistent exception history/recovery, future-series edit, horizon worker와 실제 성인 2계정·2기기 결과가 없으므로 WP03-05 또는 Chores Value Gate 전체를 완료로 표시하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발 이후 마지막 gate로 유지한다.
