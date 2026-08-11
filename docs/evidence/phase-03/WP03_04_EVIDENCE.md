# Phase 03 WP03-04 Adult Chore Completion Evidence

- Work Package: WP03-04 Completion — adult complete/reopen and Today quick action
- 기준 commit: base `a85f262`; implementation은 2026-08-06 현재 WP02-06 연속 workspace
- 검증일: 2026-08-06
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REAL-ACCOUNT·TWO-DEVICE LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-04 | PASS FOR LOCAL AUTOMATED SLICE | version과 command UUID를 함께 검증하는 adult complete/reopen transaction, append-only actor audit, duplicate/conflict 처리와 Today quick action을 연결했다. |
| FR-CHORE-003 | PARTIAL | Store MVP의 physical `scheduled → completed → scheduled` 전이와 `reopened` audit event를 구현했다. awaiting approval/approved/rejected는 P1 Managed Child 범위로 남긴다. |
| FR-CHORE-004 | PASS FOR LOCAL AUTOMATION | 완료 actor member/user/time을 원자적으로 기록하고 reopen에서 모두 비운다. 동일 요청 replay는 version/event를 늘리지 않으며 history는 보존된다. |
| FR-TODAY-003 | PASS FOR LOCAL AUTOMATION | 즉시 optimistic status, command 중 pending affordance, 중복 탭 coalescing, 성공 version 조정, 일반 실패 rollback, stale/invalid-transition refetch를 검증했다. |
| D-013/D-051 | PASS FOR SYNTHETIC ADULT BOUNDARY | Owner/Admin의 same-household 항목과 Member의 자기 담당 항목 완료를 synthetic adult fixture로 검증했다. child/acting/approval surface는 추가하지 않았다. |
| D-048/NFR-REL-01 | PASS | 동일 user+command UUID의 동일 request는 최초 최소 결과를 반환하고 다른 request는 거부한다. 다른 command의 stale expected version은 거부한다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | caller/actor/role은 `auth.uid()`와 active membership에서 계산한다. outsider, removed member, cross-household injection, unauthorized Member와 direct mutation을 닫았다. |

## Implementation

- `20260806010000_chore_completion.sql`이 content-free `chore_completion_events`, private command result와 `set_chore_occurrence_completion` RPC를 추가한다.
- RPC는 actor membership과 occurrence를 잠그고 Owner/Admin은 같은 가구의 모든 항목, Member는 자기 담당 항목만 complete/reopen하도록 강제한다.
- successful transition만 occurrence status, completed fields, version, audit event와 idempotency result를 한 transaction에서 변경한다.
- authenticated client는 같은 가구의 completion event만 RLS로 읽을 수 있다. event/client direct mutation과 private command table 접근은 허용하지 않는다.
- Flutter domain/application은 Supabase SDK와 독립적이다. adapter와 repository가 strict payload shape, household/occurrence binding, 요청 방향, 정확히 `expectedVersion + 1`, UTC completion time과 nullable-field 일관성을 검증한다.
- Today controller는 persistent cache/outbox 없이 현재 occurrence를 optimistic하게 바꾸며 한 번에 한 command만 처리한다. network 계열 실패는 원래 snapshot과 같은 idempotency key로 안전하게 재시도한다.
- stale version 또는 invalid transition은 Today RPC를 다시 읽어 authoritative status/version을 복원한다. UI에는 raw provider detail 대신 localized stable error만 표시한다.
- Today card는 완료 상태와 다시 열기 action을 노출하고 진행 중에는 48dp pending affordance로 추가 mutation과 refresh를 막는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 7개와 synthetic seed 적용 |
| DB schema lint | PASS, `public,app_private` error 0 |
| pgTAP/RLS | PASS, 신규 completion 56 + predecessor 332 = 388 tests |
| focused Flutter completion suite | PASS, domain/repository/adapter/controller/widget 23 tests |
| adaptive/i18n regression | PASS, 12 tests; Korean과 pseudo-locale의 200% text quick action 포함 |
| full Flutter regression | PASS, 230 tests + 1 opt-in live test skipped |
| exact formatter/analyzer | PASS, 209 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0 |
| coverage | PASS, 3,754 / 5,066 lines = 74.1% |
| dependency license / offline OSV | PASS, Pub 149 / npm 15, known vulnerability 0 |

## Data / API / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- completion audit에는 generated household/occurrence/user/member ID, allowlisted event type, version, correlation ID와 시각만 저장한다. title, notes, display name, email, token, JWT와 자유형 payload를 저장하지 않는다.
- private idempotency storage에는 request SHA-256, generated IDs와 최소 result status/version/member/time만 저장한다. authenticated client read/write 권한은 없다.
- 새 runtime dependency, Android permission, analytics event, persistent local completion cache와 offline outbox를 추가하지 않았다.
- 로컬 Supabase stack은 DB 검증 후 중지했다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대의 서로 다른 성인 complete/reopen 시나리오는 **NOT RUN**이며 기능 개발이 끝난 뒤 마지막 gate에서 수행한다.
- production Supabase deploy, remote migration smoke, backup/restore와 forward rollback rehearsal은 **NOT RUN**이다.
- 실제 두 client가 같은 occurrence/version을 동시에 변경하는 race와 Realtime/resume 반영은 **NOT RUN**이다. row lock과 sequential stale/replay 계약만 local DB에서 검증했다.
- TalkBack/VoiceOver 실제 기기, process death, offline/reconnect와 representative-device performance는 **NOT RUN**이다.

## Remaining Risks / Completion Boundary

1. local automated slice는 green이지만 real-account/two-device activation evidence가 없으므로 Chores Value Gate와 D-051 activation을 완료로 표시하지 않는다.
2. completion은 online-only다. offline outbox, last-sync/stale banner와 Realtime/resume invalidation은 FR-TODAY-004/Phase 05 전까지 남아 있다.
3. occurrence edit/delete/cancel/detail, recurrence/materialization/exception, upcoming/overdue/completed filter와 completion history 화면은 아직 없다.
4. Managed Child와 approval states는 D-013에 따라 P1 gate 전까지 production에 구현하거나 노출하지 않는다.
5. UI는 한 번에 한 completion command를 허용한다. 서로 다른 여러 항목의 병렬 optimistic mutation은 현재 제품 계약이 아니다.

## Rollback

- production 적용 전에는 WP03-04 Flutter surface와 migration을 revert하고 clean reset으로 read-only Today/create slice를 확인한다.
- production 적용 후에는 적용된 migration을 수정·삭제하지 않는다. completion RPC execute grant를 먼저 회수하고 policy/function/schema를 교정하는 forward migration을 추가한다.
- UI-only rollback은 Today quick action과 completion error/pending surface를 숨기고 기존 Today 목록 조회와 create flow를 유지한다.

## Next Entry Condition

- 기능 개발을 이어갈 때는 WP03-04 contract를 유지한 채 다음 한 vertical slice를 별도 work plan으로 시작한다. 우선순위 후보는 recurrence/materialization(WP03-05) 또는 occurrence edit/cancel/detail의 남은 WP03-02 범위다.
- 다음 slice에서도 실제 계정 gate는 마지막으로 유지하되, synthetic DB/RLS와 Flutter regression은 각 변경마다 계속 통과해야 한다.
