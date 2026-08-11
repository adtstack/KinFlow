# Phase 02 WP02-06 Adult Activation Handoff Evidence

- Work Package: WP02-06 Adult activation handoff — first one-time chore vertical slice
- 기준 commit: base `a85f262`; implementation은 2026-08-06 현재 workspace
- 검증일: 2026-08-06
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / TWO-ADULT·TWO-DEVICE LIVE PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-06 | PASS FOR AUTOMATED SLICE | 기존 invite accept와 active household 흐름의 빈 Today를 첫 단건 집안일 생성·재조회로 연결하고, member별 최초 독립 행동 event 계약을 추가했다. 실제 성인 2인·기기 2대 실행은 남아 있다. |
| FR-CHORE-001 | PARTIAL | 제목, 선택적 notes, 동일 가구 active adult 담당자와 household-local due date/time을 가진 단건 series/revision/occurrence 생성·조회가 동작한다. 수정·삭제·approval은 후속 범위다. |
| FR-CHORE-002 | PARTIAL | 이번 slice는 active adult 한 명을 primary assignee로 강제한다. unassigned와 복수 담당자는 열지 않았다. |
| FR-CHORE-009 | PARTIAL | 서버가 계산한 household local date의 Today 항목을 due instant·제목·ID로 안정 정렬한다. upcoming·overdue·completed filter는 후속 범위다. |
| D-013/D-051 | PASS | adult member만 생성·담당할 수 있고 Managed Child table, route와 acting context는 추가하지 않았다. |
| D-048/NFR-REL-01 | PASS FOR CREATE | command UUID와 normalized request hash를 사용한다. 동일 key·동일 요청은 최초 결과를 반환하고, 동일 key의 다른 요청은 거부한다. |
| NFR-SEC-01 | PASS FOR NEW TABLES | same-household active member read와 authenticated RPC만 허용하며 direct client mutation, outsider, removed member와 cross-household assignee를 거부한다. |

## Implementation

- `20260806000000_one_time_chore_activation.sql`이 accepted series/revision/occurrence 구조, RLS, private idempotency record와 content-free domain event를 추가한다.
- `create_one_time_chore`는 caller를 `auth.uid()`에서 파생하고 active membership, adult assignee, timezone-local date/time과 minute precision을 DB에서 검증한다.
- `get_today_chores`는 client date를 권위값으로 받지 않고 household timezone과 transaction-stable server time으로 Today date를 계산한다.
- Flutter `features/chores`는 SDK-independent domain/application, strict data mapping, Supabase adapter와 auto-disposed Riverpod presentation 경계로 구성된다.
- `/today`는 loading/error/empty/list를 표시한다. empty primary action은 첫 집안일 생성이고 가족 초대는 secondary action이다.
- `/chores/new?due=YYYY-MM-DD`는 서버가 반환한 Today date로만 진입하며 title, notes, active adult assignee, date와 선택적 time을 받는다. 성공 후 local optimistic row 대신 Today RPC를 다시 읽는다.
- 같은 form retry는 같은 idempotency key를 재사용하고 중복 tap을 coalesce한다. raw SDK/server error는 stable failure와 안전한 localized message로 변환한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 6개와 synthetic seed 적용 |
| DB schema lint | PASS, `public,app_private` error 0 |
| pgTAP/RLS | PASS, 신규 WP02-06 61 + predecessor 271 = 332 tests |
| Supabase HTTP health contract | PASS |
| chore target Flutter tests | PASS, domain/controller/repository/adapter/widget/localization 20 tests |
| full Flutter regression | PASS, 217 tests + 1 opt-in live skip |
| exact analyzer | PASS, issue 0 with Flutter 3.44.7 / Dart 3.12.2 |
| exact formatter | PASS, 203 files checked, changed 0 |
| repository CI self-test | PASS, 47/47 |
| workflow/supply-chain contract | PASS, 5 jobs, pinned action 17개, `contents:read` |
| dependency license / offline OSV | PASS, Pub 149 / npm 15, known vulnerability 0 |

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic seed만 사용했다. production migration, 실제 계정, household와 customer content는 사용하지 않았다.
- `chore_domain_events`에는 event name과 generated household/member/series ID만 있으며 title, notes, email, token과 auth user ID를 저장하지 않는다.
- idempotency table에는 normalized request hash와 generated result ID만 저장한다. authenticated client는 private table을 읽거나 쓸 수 없다.
- occurrence content는 same-household active membership RLS 아래에서만 읽힌다. anon, outsider, removed member와 direct insert/update/delete는 pgTAP에서 거부됐다.
- 새 runtime dependency, Android permission, persistent local user-data cache와 analytics SDK는 추가하지 않았다.
- 검증을 위해 시작한 로컬 Supabase stack은 완료 후 중지했다.

## Manual / Deferred Validation

- 실제 Google 성인 계정 2개와 Android 기기 2대의 invite accept → Today → 첫 chore 생성 → 상대 기기 재조회는 **NOT RUN**이다.
- 실제 두 번째 성인의 `activation.adult_first_chore_created` 발생과 재시도 시 단일 event 유지 관측은 **NOT RUN**이다.
- production Supabase deploy, remote query plan, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- representative-device Today p75, screen reader, keyboard, process death, offline/reconnect와 multi-client concurrency는 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. WP02-06의 automated slice는 green이지만 실제 성인 2인·기기 2대 activation 결과가 없으므로 Phase 02 Exit Gate는 완료가 아니다.
2. occurrence complete/reopen, edit/delete, recurrence, exception materialization과 approval은 아직 없다.
3. Today는 현재 날짜 목록만 제공하며 upcoming, overdue, completed section/filter와 Realtime/offline cache는 없다.
4. 첫 독립 행동 event는 DB 계약으로 검증했지만 production analytics/operations consumer는 연결하지 않았다.
5. 생성 migration은 fresh reset을 통과했지만 N-1 client와 production-size query 성능은 별도 검증이 필요하다.
6. DST gap/fold의 사용자 정책과 fixture는 Phase 04 시간 dependency gate 범위다. 현재 timed one-time chore는 PostgreSQL timezone 변환을 사용하므로 해당 경계 전에는 DST 전환 시각의 제품 의미를 완료로 간주하지 않는다.

## Rollback

- production 적용 전에는 이 workspace 변경을 revert하고 clean reset으로 기존 WP02-05 상태를 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. create RPC execute grant와 route를 먼저 닫고 schema/function/policy를 교정하는 forward migration을 추가한다.
- UI-only rollback은 `/chores/new` route와 Today create/list surface를 제거하고 기존 safe empty Today로 되돌린다.

## Next Entry Condition

- 기능 개발을 계속할 경우 다음 작은 vertical slice는 occurrence `complete/reopen` command와 Today quick-complete다. idempotency, stale version, 권한과 event 계약을 먼저 고정한다.
- 이후 WP02-07에서 새 chore table/RPC까지 outsider, removed member, household injection과 direct CRUD bypass matrix를 Phase 02 전체 권한 감사에 포함한다.
- 실제 성인 2인·기기 2대 gate가 green이 되기 전에는 WP02-06 또는 Phase 02 전체를 완료로 전환하지 않는다.
