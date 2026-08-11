# WP03-06 Work Plan — Chore agenda filters and resume refresh

- 상태: LOCAL AUTOMATED COMPLETE / REMOTE·REAL-ACCOUNT LIVE DEFERRED
- 범위: 가구 현지 날짜를 기준으로 Today·Upcoming·Overdue·Completed와 Everyone·Me를 조회하고, bounded keyset pagination·stale 표시·앱 복귀 authoritative refresh를 제공한다.
- Calendar event 통합과 실제 성인 계정·2기기·remote Supabase 검증은 각각 Phase 04와 사용자 지시에 따른 마지막 gate로 유지한다.

## 요구사항과 결정

| ID | 이번 slice의 수용 기준 |
|---|---|
| FR-CHORE-009 | Today, upcoming, overdue, completed와 assignee filter를 제공한다. |
| FR-TODAY-001 (CHORES) | 서버가 계산한 household-local date를 모든 chore view의 경계로 사용하고 각 view를 안정적으로 정렬한다. Calendar event 조합은 Phase 04 범위다. |
| FR-TODAY-002 | Everyone과 현재 active adult member인 Me를 서버 쿼리로 제한한다. filter는 household read 권한을 확장하지 않는다. Managed Child는 D-013에 따라 Store MVP 비범위다. |
| FR-TODAY-003 | 기존 quick complete/reopen의 optimistic update, duplicate coalescing, authoritative reconciliation을 필터된 목록에서도 유지한다. |
| FR-TODAY-004 | 마지막 성공 응답 시각을 표시하고 refresh 실패 시 기존 목록을 stale로 보존한다. 앱 resume에서 authoritative refetch한다. offline outbox는 추가하지 않는다. |
| FR-TODAY-005 (BOUNDARY) | 이번 slice는 chore source만 구현하므로 partial calendar failure는 Phase 04에서 완성한다. 현재 chore 실패는 raw provider error 없이 독립적으로 표현한다. |
| D-019 | series/revision definition과 materialized occurrence 상태를 유지하고 read projection/index만 추가한다. |
| NFR-SEC-01 | active household member만 조회하며 anon/removed/outsider/cross-household와 다른 household assignee probing을 동일하게 거부한다. |
| NFR-PRIV-01 | 응답은 화면에 필요한 household/member/series/occurrence content와 page metadata만 포함하며 auth user ID, command/correlation ID, private hash와 raw error를 반환하지 않는다. |
| NFR-REL-01 | 1~100 bounded limit과 query-bound opaque cursor로 중복 없는 deterministic pagination을 제공한다. |
| NFR-A11Y-01 | filter, stale banner, empty/error/list/load-more를 semantics, 48dp action, large-text-safe scroll 구조로 제공한다. |
| NFR-I18N-01 | view/filter/stale/empty/page 문구와 날짜·시간은 en/ko/pseudo ARB 및 locale formatter만 사용한다. |

## Database와 API 계약

1. `get_chore_list(p_household_id, p_view, p_assignee_member_id, p_limit, p_after_cursor)` stable read RPC를 추가한다.
2. `p_view`는 `today`, `upcoming`, `overdue`, `completed`만 허용한다. limit은 1~100이다. optional assignee는 요청 household의 active member여야 한다.
3. 서버는 `statement_timestamp()`를 household IANA timezone으로 변환해 `household_local_date`를 한 번 계산한다.
4. `today`는 현지 날짜의 scheduled/completed, `upcoming`은 미래 scheduled, `overdue`는 과거 scheduled, `completed`는 모든 날짜의 completed occurrence를 반환한다. skipped/cancelled는 제외한다.
5. scheduled view는 soft-deleted series를 제외한다. completed view는 보존된 완료 이력을 계속 보여주되 관리 metadata는 active repeating series에만 허용한다.
6. Today/upcoming/overdue는 `(due_local_date ASC, timed-before-all-day, due_local_time ASC, occurrence_id ASC)`, completed는 `(due_local_date DESC, timed-before-all-day, due_local_time DESC, occurrence_id DESC)`로 정렬한다. title은 cursor/order key가 아니다.
7. opaque cursor는 view·assignee filter와 마지막 row의 date/time/id를 결속한다. 다른 query의 cursor, malformed cursor, boundary를 진행하지 않는 page는 fail closed다.
8. `p_limit + 1`로 `has_more`를 구하고 같은 page의 모든 item row에 동일한 다음 호출용 `page_cursor` metadata를 반복한다. 빈 결과도 metadata-only row 한 개를 반환한다.
9. 응답 metadata는 household ID/timezone/local date, generated-at UTC, view, optional assignee, limit과 has-more다. item은 기존 Today exact content contract와 실제 due local date를 반환한다.
10. 함수는 empty search path의 `SECURITY DEFINER`, `STABLE`이며 `authenticated`만 execute할 수 있다. 기반 table 권한과 mutation 경로는 변경하지 않는다.
11. 전체/assignee query를 위한 status·date·time·ID composite index를 추가하며 기존 index는 제거하지 않는다.

## Client 계약

1. provider-free domain에 view, request, opaque cursor와 paged chore snapshot을 추가하고 household/view/assignee/page/order/uniqueness invariant를 검증한다.
2. Supabase datasource는 exact response key, metadata consistency, item/empty shape, generated-at UTC, cursor/has-more contract를 검증한다. repository mapper는 UUID/date/time/status/query/order/page 진행성을 다시 검증한다.
3. 기존 `loadToday` 호환 entry point를 유지하되 Today controller는 current query를 보관하고 filter 변경, refresh, resume refresh와 load-more를 지원한다.
4. filter 변경은 incompatible content를 지운 initial load다. 수동/복귀 refresh는 현재 content를 보존하고 refreshing 상태를 표시한다. 실패하면 last successful `generatedAt`과 safe message를 stale banner에 남긴다.
5. continuation 실패는 기존 item과 cursor를 보존하고 같은 page를 retry한다. merge는 household/query metadata, unique ID, total order와 cursor advancement가 맞지 않으면 fail closed다.
6. optimistic completion/reopen, reschedule, reassign, skip/undo는 변이 뒤 occurrence가 현재 view/filter에 속하는지 평가해 replace 또는 remove한다. series-wide 성공·stale reconciliation은 현재 query 첫 page를 다시 읽는다.
7. 화면은 Today/Upcoming/Overdue/Completed와 Everyone/Me choice controls, view별 empty state, locale date/time, refresh/stale, load-more를 제공한다. provider SDK나 raw failure text를 UI에 노출하지 않는다.
8. `WidgetsBindingObserver`가 `resumed`에서 현재 query를 refresh한다. Realtime channel과 background/offline outbox는 이번 slice에 추가하지 않는다.

## 자동 검증

- RPC exact signature/columns, stable/security-definer/search-path/grant와 composite indexes
- household timezone date boundary, 네 view의 inclusion/exclusion, Everyone/Me, soft-delete/completed preservation
- deterministic ordering, equal-key UUID tie, bounded first/next page, cursor query binding과 invalid input denial
- anon/removed/outsider/cross-household/foreign assignee denial과 existing RLS/mutation regression
- Dart request/snapshot invariants, strict payload parser, repository mapping/order/cursor/page merge
- controller filter/refresh/stale/load-more/coalescing과 optimistic membership/reconciliation
- widget filter/empty/stale/resume/load-more, safe error, semantics, ko/en-XA 200% text
- exact formatter/analyzer, focused and full Flutter/pgTAP regression, coverage와 whitespace

## 배포 중단 조건과 rollback

- 다른 household의 content/member 존재 여부가 노출되거나 filter가 권한을 확장하면 배포하지 않는다.
- household date 경계, view membership, total order 또는 cursor continuation이 불안정하면 배포하지 않는다.
- refresh 실패가 기존 성공 content를 지우거나 raw provider error를 표시하면 배포하지 않는다.
- production 적용 전에는 migration/client/tests를 함께 revert하고 이전 WP03-05H baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정·삭제하지 않는다. 새 RPC execute grant와 filter UI를 먼저 회수하고 forward migration으로 함수/index를 교정한다. occurrence/series/audit data는 삭제하지 않는다.

## 완료 경계

이 slice가 green이어도 Calendar event 통합/partial failure, notification hooks, remote scheduler 운영, production-size latency와 실제 계정·2기기·timezone/resume 수동 검증이 남으므로 Phase 03과 전체 목표를 완료로 표시하지 않는다.
