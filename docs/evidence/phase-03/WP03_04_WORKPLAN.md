# Phase 03 WP03-04 Adult Chore Completion Work Plan

- 작성일: 2026-08-06
- 기준 commit: `a85f262` + current WP02-06 workspace
- 상태: LOCAL AUTOMATED PASS / LIVE DEFERRED
- 범위: Today occurrence의 성인용 complete/reopen command와 optimistic quick-complete vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP03-04 | expected version과 idempotency key를 모두 사용하는 occurrence complete/reopen transaction, actor audit와 duplicate/conflict 처리를 구현한다. |
| FR-CHORE-003 (PARTIAL) | physical `scheduled → completed → scheduled` 전이를 제공한다. 문서의 `reopened`는 audit event이며 현재 occurrence의 open physical state는 `scheduled`다. awaiting approval/approved/rejected는 Managed Child P1 범위로 남긴다. |
| FR-CHORE-004 | 완료 시 `completed_by_member_id`, `completed_by_user_id`, `completed_at`을 원자적으로 기록하고 reopen 시 함께 비운다. 모든 성공 전이를 append-only completion event로 남긴다. |
| FR-TODAY-003 (PARTIAL) | Today에서 즉시 optimistic status를 보이고 중복 탭을 coalesce한다. 서버 성공 결과의 status/version으로 조정하고 실패 시 이전 상태로 복구한다. offline outbox는 추가하지 않는다. |
| D-013/D-051 | adult session만 대상으로 하며 서로 다른 성인의 완료 행동까지 synthetic fixture로 검증한다. Managed Child acting/approval surface는 만들지 않는다. |
| D-018 | completion은 이번에도 online-only다. outbox는 Phase 05 Gate 전까지 구현하지 않는다. |
| D-048 | command UUID의 동일 요청 retry와 expected occurrence version의 stale-write 거부를 함께 적용한다. |

## Authorization / State Contract

1. caller identity와 actor member는 JWT `auth.uid()`와 active membership에서 서버가 계산한다.
2. Owner/Admin은 같은 household의 active occurrence를 complete/reopen할 수 있다.
3. Member는 `assignee_member_id`가 자기 member ID인 occurrence만 complete/reopen할 수 있다.
4. outsider, removed member, 다른 household ID/occurrence injection과 direct table mutation은 generic forbidden으로 닫는다.
5. complete는 `scheduled`에서만, reopen은 `completed`에서만 허용한다. skipped/cancelled와 같은 방향의 새 command는 invalid transition이다.
6. 동일 idempotency key·동일 request는 최초의 최소 결과를 재사용한다. 같은 key의 다른 request는 거부한다.
7. 동일 expected version의 서로 다른 command는 occurrence row lock 뒤 정확히 한 건만 성공하고 나머지는 stale version으로 실패한다.

## Data / API Boundary

1. 새 forward migration에서 `public.chore_completion_events`와 `app_private.chore_completion_command_requests`를 추가한다.
2. completion event에는 household/occurrence, actor user/member, event type, result version, correlation ID와 시각만 저장한다. title, notes, email, token과 자유형 payload는 저장하지 않는다.
3. authenticated client는 completion event를 same-household RLS로 읽을 수 있지만 insert/update/delete할 수 없다. private request table은 client에서 완전히 닫는다.
4. `set_chore_occurrence_completion(idempotency, household, occurrence, expected_version, completed)` RPC만 mutation 권한을 가진다.
5. RPC 결과는 household/occurrence ID, result status/version, completed member/time과 replay 여부만 반환한다. UI content를 idempotency record에 복제하지 않는다.

## Flutter Boundary

1. domain/application은 Flutter, Riverpod와 Supabase SDK에 독립적으로 completion request/result를 표현한다.
2. Supabase payload는 strict data record를 거쳐 expected household/occurrence, status/version과 completion-field 일관성을 검증한다.
3. Today controller는 한 번에 한 occurrence command만 허용하고 동일 pending tap은 같은 Future를 반환한다.
4. submit 직후 occurrence status를 optimistic하게 바꾸고 pending affordance를 표시한다.
5. 성공 시 server result status/version으로 조정한다. stale/invalid transition은 Today를 다시 읽고, 다른 실패는 이전 snapshot으로 복구한 뒤 localized safe error만 보여 준다.
6. logout/account/household route 전환 시 auto-disposed state 외 persistent completion cache는 남기지 않는다.

## Automated Validation

- clean migration reset, schema lint와 pgTAP schema/grant/RLS/role/state/idempotency/stale/cross-household/removed-member matrix
- completed fields와 append-only event exactness, replay no duplicate와 reopen history 보존
- completion DTO strict parsing과 provider error mapping
- controller optimistic success/reconcile, failure rollback, same-key retry와 duplicate-tap tests
- Today quick complete/reopen widget, EN/KO/pseudo와 200% text-scale regression
- exact Flutter analyzer/formatter/full suite, repository contract, dependency/secret checks

## Explicit Non-scope

- Managed Child, acting member, guardian approval/rejection
- offline outbox/cache, Realtime와 background sync
- edit/delete/cancel/detail, recurrence/materialization/exception
- completed history/detail screen과 filter
- production migration deploy와 actual Google 성인 2계정·Android 2기기 validation

## Stop / Rollback

- Member가 다른 사람의 항목을 완료하거나 outsider/removed member가 mutation/event read를 수행할 수 있으면 배포하지 않는다.
- stale command 두 건이 모두 성공하거나 replay가 event/version을 중복 생성하면 배포하지 않는다.
- remote 적용 전에는 새 migration과 Flutter completion surface를 revert한다.
- remote 적용 후에는 migration을 수정·삭제하지 않고 RPC execute grant를 회수한 뒤 교정 forward migration을 추가한다. UI rollback은 quick action을 숨기고 read-only Today를 유지한다.

## Completion Boundary

자동 검증이 green이어도 실제 성인 2인·기기 2대의 상대 항목 완료와 동기화 결과가 없으므로 Chores Value Gate 또는 실사용 activation을 완료로 표시하지 않는다. 이번 evidence는 local automated 범위와 마지막에 수행할 live gate를 분리한다.
