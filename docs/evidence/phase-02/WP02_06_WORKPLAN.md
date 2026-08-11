# Phase 02 WP02-06 Adult Activation Handoff Work Plan

- 작성일: 2026-08-06
- 기준 commit: `a85f262`
- 상태: IMPLEMENTED — LOCAL AUTOMATED PASS / LIVE PENDING
- 범위: 초대 수락 후 Today에서 첫 단건 집안일을 생성하고 같은 가구의 오늘 목록에서 확인하는 production vertical slice

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-06 | 이미 구현된 초대 수락→active household→Today 이동 뒤 실제 첫 집안일 생성으로 이어지는 handoff를 완성한다. |
| D-013/D-051 | 성인 계정과 성인 2인 Activation만 대상으로 하며 Managed Child surface는 만들지 않는다. |
| D-048 | 생성 command에 idempotency key를 사용하고 동일 key의 다른 입력 재사용을 거부한다. |
| FR-CHORE-001 (PARTIAL) | 제목, 선택적 설명, 담당자, household-local due date/time을 가진 단건 집안일 생성과 조회를 제공한다. 수정·삭제는 후속 범위다. |
| FR-CHORE-002 (PARTIAL) | 이번 Activation slice는 같은 가구의 active adult 한 명을 primary assignee로 반드시 지정한다. unassigned와 복수 담당자는 열지 않는다. |
| FR-CHORE-009 (PARTIAL) | active household의 현재 local date에 해당하는 집안일을 Today에 안정적으로 정렬해 표시한다. 필터·upcoming·overdue·completed는 후속 범위다. |

## Data / API Boundary

1. `chore_series`, `chore_series_revisions`, `chore_occurrences`를 accepted series/revision/occurrence 구조로 추가한다.
2. 단건 집안일도 `recurrence_rule={"type":"once"}`인 revision과 occurrence를 분리해 저장한다. 평면 `chores` table은 만들지 않는다.
3. `create_one_time_chore`는 JWT의 `auth.uid()`와 active membership을 서버에서 다시 확인한다. body의 user/role은 입력으로 받지 않는다.
4. assignee는 같은 household의 `removed_at is null`인 성인 member여야 한다. 다른 household UUID, removed member와 존재하지 않는 member는 같은 generic forbidden 결과로 거부한다.
5. client에는 table insert/update/delete 권한을 주지 않는다. same-household select와 authenticated RPC execute만 허용한다.
6. `get_today_chores`는 household timezone으로 서버가 계산한 현재 local date를 사용한다. client date를 권위값으로 받지 않는다.
7. `app_private.chore_command_requests`는 request hash와 최소 ID 결과만 저장한다.
8. `app_private.chore_domain_events`는 콘텐츠 없이 `chore.series_created`와 member별 최초 `activation.adult_first_chore_created`를 기록한다. 제목, 설명, email, auth token과 auth user ID는 event payload에 저장하지 않는다.

## Flutter Boundary

1. `features/chores`에 domain/application/data/presentation 경계를 추가한다.
2. Today는 loading/error/empty/list 상태를 명시하고 empty 상태의 primary CTA를 `첫 집안일 만들기`로 바꾼다. 가족 초대는 secondary action으로 유지한다.
3. 빠른 생성 form은 제목, active adult 담당자, due date와 선택적 time/notes만 노출한다.
4. 외부 payload는 data record parse 후 domain value object로 변환하며 SDK exception과 raw server message를 UI에 노출하지 않는다.
5. 생성 성공 후 Today를 서버에서 다시 읽는다. persistent local cache와 optimistic write는 이번 범위에 추가하지 않는다.

## Automated Validation

- clean migration reset과 pgTAP schema/grant/RLS/authority/idempotency/cross-household/removed-member matrix
- same-household create와 server-local Today query
- DTO payload negative tests와 provider failure mapping
- domain value object, repository, controller retry/idempotency tests
- empty→create→Today list widget flow, EN/KO/pseudo localization, 200% text-scale smoke
- architecture boundary, analyzer, format, codegen drift와 repository secret scan

## Explicit Non-scope

- edit/cancel/delete/detail, complete/reopen, approval, recurrence, exception와 materialization job
- overdue/upcoming/completed/filter, Realtime와 offline cache
- Managed Child/guardian/acting context
- actual Google 성인 2계정·Android 2기기 live gate
- production migration deploy

## Stop / Rollback

- outsider나 removed member가 chore row를 읽거나 만들 수 있으면 배포하지 않는다.
- 다른 household member를 assignee로 주입할 수 있거나 direct table mutation이 가능하면 배포하지 않는다.
- remote 적용 전에는 feature commit을 revert한다. remote 적용 후 migration은 수정·삭제하지 않고 생성 RPC/grant/policy를 차단하는 forward migration을 사용한다.
- UI rollback은 create route를 제거하고 기존 safe empty Today로 되돌린다. schema는 후속 Phase 03 호환 기반으로 유지할 수 있다.

## Completion Boundary

자동 검증이 green이어도 WP02-06과 Phase 02 전체를 완료로 표시하지 않는다. 실제 두 성인·두 기기 결과와 후속 완료 행동이 없으므로 이 slice의 evidence에는 automated 범위와 live 미실행을 분리한다.
