# Phase 03 WP03-06 Chore Agenda Filters and Resume Refresh Evidence

- Work Package: WP03-06 — Today/upcoming/overdue/completed, Everyone/Me, pagination and resume refresh
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D/E/F/G/H 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-06 | PASS FOR LOCAL AUTOMATED SLICE | active adult household member가 Today, upcoming, overdue, completed를 Everyone 또는 Me로 조회하고 bounded continuation, refresh와 stale recovery를 사용한다. |
| FR-CHORE-009 | PASS FOR LOCAL AUTOMATED SURFACE | 네 view와 assignee filter, view별 empty state, deterministic keyset pagination을 제공한다. 실제 기기·production-size 성능 gate는 남아 있다. |
| FR-TODAY-001 (CHORES) | PASS FOR CHORE SOURCE | 서버가 household IANA timezone으로 산출한 local date를 경계로 사용하고 timed-before-all-day total order를 유지한다. Calendar event 조합은 Phase 04 범위다. |
| FR-TODAY-002 (ADULT) | PASS FOR STORE MVP ADULT SURFACE | Everyone/Me는 서버 쿼리이며 active same-household assignee만 허용한다. D-013의 managed child 비범위를 변경하지 않았다. |
| FR-TODAY-003 | PASS FOR FILTERED CHORE SURFACE | quick complete/reopen과 occurrence mutation 후 현재 view/Me membership을 다시 평가하고 duplicate action coalescing 및 authoritative reconciliation을 유지한다. |
| FR-TODAY-004 | PARTIAL | 마지막 성공 `generated_at`과 content를 refresh 실패에도 보존하고 resume에서 authoritative refresh한다. 실기기 offline/reconnect와 action별 offline 설명은 남아 있다. |
| FR-TODAY-005 | DEFERRED | 이번 slice는 chore source만 구현했다. Calendar source와 source별 partial failure 조합은 Phase 04에서 완성한다. |
| NFR-SEC-01 | PASS FOR NEW READ SURFACE | active household member만 조회하며 anon, removed member, outsider, cross-household와 foreign assignee probing을 거부한다. |
| NFR-PRIV-01 | PASS FOR NEW READ SURFACE | 응답은 화면 content와 page metadata만 반환하며 auth user ID, command/correlation ID, private hash, token과 raw error를 포함하지 않는다. |
| NFR-REL-01 | PASS FOR READ PAGINATION | 1~100 bounded limit, query-bound opaque cursor, equal-key UUID tie와 strict client merge로 중복·역행 page를 거부한다. |
| NFR-A11Y-01 | PASS FOR AUTOMATED SURFACE | filter, stale, retry, empty, list와 load-more를 semantic control과 large-text-safe scroll 구조로 제공한다. |
| NFR-I18N-01 | PASS FOR NEW SURFACE | view/filter/stale/empty/page 문구는 en/ko/pseudo ARB를 사용하고 날짜·시각은 locale formatter로 표시한다. |

## Database and API Contract

- `20260807080000_chore_list_filters.sql`은 기존 occurrence/series/audit relation과 mutation을 변경하지 않고 `get_chore_list` stable read RPC와 두 composite read index를 추가한다.
- RPC는 `statement_timestamp()`를 household timezone으로 변환해 한 요청 안에서 동일한 `household_local_date`와 UTC `generated_at`을 사용한다.
- `today`는 local today의 scheduled/completed, `upcoming`은 미래 scheduled, `overdue`는 과거 scheduled, `completed`는 모든 completed occurrence다. skipped/cancelled는 제외한다.
- scheduled view는 soft-deleted series를 숨긴다. completed history는 series가 삭제되어도 display revision으로 보존하지만 series 관리 권한은 부여하지 않는다.
- Everyone은 assignee 조건을 생략하고 Me는 client의 active member ID를 전달한다. optional assignee가 요청 household의 active member가 아니면 존재 여부를 구분하지 않는 `KFC03`으로 거부한다.
- scheduled view는 local date와 due instant를 오름차순, completed는 내림차순으로 정렬한다. all-day `NULL`은 양쪽 모두 마지막이고 occurrence UUID가 total-order tie breaker다. 한 household/date 안에서 client는 local time을 우선 비교하고 같은 local time은 due instant로 다시 묶어 동일 순서를 검증한다.
- `p_limit + 1`로 `has_more`를 산출한다. 다음 cursor는 version, view, assignee, last date/due instant/occurrence ID를 hex-encoded JSON에 묶고 같은 page의 item metadata에 반복한다. 빈 결과는 metadata-only row 한 개다.
- cursor 길이·소문자 hex·exact JSON key/type·query binding과 UUID/date/timestamp parse를 검증한다. 다른 view/assignee cursor와 malformed cursor는 mutation 없이 `KFC02`로 거부한다.
- 함수는 empty search path의 `SECURITY DEFINER`, `STABLE`이고 `authenticated`만 execute할 수 있다. underlying table privilege나 기존 RLS/mutation 경로는 확장하지 않았다.

## Flutter Surface

- provider-free domain에 `ChoreListView`, strict opaque cursor, first/continuation request와 paged `TodayChores` query metadata를 추가했다.
- datasource는 RPC의 26개 exact keys, metadata-only/item shape, page-wide metadata consistency와 cursor/has-more pair를 검증한다.
- repository mapper는 household/query binding, UUID/date/time/UTC/status, assignee, page size, item uniqueness와 total order를 다시 검증한다. malformed provider cursor와 진행하지 않는 continuation은 fail closed다.
- controller는 현재 query를 보관하고 initial/filter load, content-preserving refresh, continuation coalescing/retry와 strict append를 지원한다. series-wide stale reconciliation도 현재 query의 first page를 다시 읽는다.
- completion/reopen, reschedule와 reassign 결과는 현재 view와 Me membership을 재평가해 replace, reorder 또는 remove한다. 구현 중 기존 same-day optimistic reschedule 회귀가 due instant placeholder만 비교해 잘못 정렬되는 것을 전체 회귀가 발견했고, local time 우선 및 due instant tie-break 방식으로 보정했다.
- 화면은 Today/Upcoming/Overdue/Completed와 Everyone/Me `ChoiceChip`, view별 heading/count/empty state, last sync/refreshing/stale banner, load-more/error/retry를 제공한다.
- `WidgetsBindingObserver`는 앱이 `resumed`가 되면 현재 filter를 authoritative refresh한다. 실패 시 성공 content와 last sync를 보존하고 ARB의 안전한 stale 문구만 표시한다.
- UI에는 Supabase SDK import와 raw provider error가 없고 기존 repository/provider 경계를 사용한다. Realtime channel, background sync와 offline outbox는 추가하지 않았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 16개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused chore-list pgTAP | PASS, 46/46 |
| full pgTAP/RLS regression | PASS, 18 files, 966 tests; predecessor 920 + 신규 46 |
| focused domain/repository/controller/parser/widget | PASS, 95/95 |
| same-day optimistic sorting regression | PASS, 1/1 after correction |
| full Flutter regression | PASS, 336 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 226 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow/actionlint | PASS, 47/47; 5 jobs, pinned action 17개, workflow lint pass |
| unchanged Edge unit regression | PASS, invite 22/22, member lifecycle 18/18 |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated drift 0/8 files |
| localization/adaptive | PASS, en/ko/pseudo exact keys와 expansion, ko/en-XA 200% automation 포함 |
| coverage | PASS, 6,431 / 8,185 lines = 78.57% |
| whitespace | PASS, `git diff --check` output 0 |

DB fixture는 exact signature/return columns/grant/search-path/index, household-local date, 네 view의 inclusion/exclusion, Everyone/Me, deleted/completed preservation, Owner/Admin 관리 metadata, member read, anon/removed/outsider/foreign-assignee denial, limit validation, malformed/query-bound cursor, equal-time/all-day ordering과 Today/Completed multi-page traversal을 포함한다.

Flutter fixture는 request/cursor/page invariant, exact payload parsing, repository query/order/cursor fail-closed, refresh stale preservation, load-more coalescing/merge/retry, filtered optimistic membership, view/Me controls, resume refresh와 stale banner, continuation UI, localization·semantics·large-text regression을 포함한다.

## Data, Security, and Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/content만 사용했다. production migration, 실제 계정, 실제 household 또는 고객 content는 사용하지 않았다.
- read projection은 authorized household/series/revision/occurrence/member IDs, title/description/current assignee display name, schedule/status/version와 최소 series management metadata만 반환한다.
- auth user ID, email, provider identity, command/correlation/idempotency ID, private request hash, token과 raw database/provider error는 response, UI와 evidence에 포함하지 않는다.
- cursor는 query key와 ordering key만 포함하고 개인정보·content를 넣지 않는다. client는 cursor를 해석해 UI에 표시하거나 persistent storage에 저장하지 않는다.
- 새 analytics event, mobile runtime dependency, native permission, persistent client cache, offline outbox 또는 secret-bearing external service를 추가하지 않았다.
- local Supabase stack은 다음 기능 개발에 재사용할 수 있도록 실행 상태를 유지했다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대의 cross-device filter/complete propagation, account switch, background/resume와 offline/reconnect 검증은 **NOT RUN**이다.
- production Supabase deploy, remote RLS/RPC, production-size query plan/index selectivity/latency와 forward rollback rehearsal은 **NOT RUN**이다.
- 실제 기기의 TalkBack/VoiceOver, dynamic type, tablet, locale/timezone 전환과 OS lifecycle 차이 검증은 **NOT RUN**이다.
- Calendar event source 조합, event source failure 시 chore content 보존과 통합 agenda pagination은 Phase 04 범위로 **NOT RUN**이다.
- 수동 simulator/device UI smoke는 **NOT RUN**이며 widget/semantics 자동 계약만 수행했다.

## Remaining Risks and Completion Boundary

1. local keyset traversal은 통과했지만 production cardinality에서의 index 선택, p75 latency와 cursor page churn은 remote performance gate 전까지 미확정이다.
2. resume refresh는 foreground lifecycle callback에 의존한다. OS process kill/restore, 장시간 background와 실제 network handover는 실기기에서 확인해야 한다.
3. stale banner는 마지막 성공 content를 보존하지만 generic connectivity 상태와 action별 offline 가능 여부를 선제적으로 설명하는 offline model/outbox는 없다.
4. Me는 Store MVP의 active adult member ID다. managed child self-scope는 D-013에 따라 비범위이며 P1 child safety gate 없이 확장하면 안 된다.
5. 현재 Today destination에는 chore source만 있다. Calendar가 추가되기 전에는 FR-TODAY-001의 통합 agenda와 FR-TODAY-005 partial-source failure가 완성되지 않는다.
6. 실제 계정·두 기기, remote deploy와 production 성능 evidence가 없으므로 WP03, Chores Value Gate 또는 전체 제품 목표를 완료로 표시하지 않는다.

WP03-06 자체는 local automated 기능 slice로 완료했다. 관련 Store MVP requirement와 release gate는 remote·real-account 및 Calendar 조합 검증 전까지 `IN_PROGRESS`를 유지한다.

## Rollback

- production 적용 전에는 WP03-06 migration/client/tests/evidence를 revert하고 clean reset으로 이전 15개 migration과 920-test baseline을 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. `get_chore_list` execute grant와 filter/resume UI entry를 먼저 회수하고 forward migration으로 projection/authorization/index/cursor contract를 교정한다.
- occurrence, series, revision과 audit data는 삭제하거나 재작성하지 않는다. 새 index는 query safety 확인 후 별도 forward migration으로만 제거한다.
- client rollback은 list query/domain/repository/controller/UI와 ARB keys를 함께 이전 Today-only `loadToday` path로 되돌린다. 기존 chore creation/mutation/history는 계속 동작한다.

## Next Entry Condition

- 다음 기능 우선순위는 notification-ready chore event hook/intent foundation이다. 기존 immutable occurrence/series audit를 content-free bounded intent 생성 경계에 연결하고 실제 push 발송과 permission prompt는 분리한다.
- Calendar 통합을 먼저 선택한다면 Phase 04 event schema와 Today source composition/partial failure contract를 하나의 vertical slice로 고정한다.
- 실제 계정·두 기기 및 remote Supabase gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
