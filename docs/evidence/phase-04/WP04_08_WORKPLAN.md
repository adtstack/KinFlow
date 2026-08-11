# Phase 04 WP04-08 Detailed Today Feed Workplan

- 상태: `LOCAL AUTOMATED COMPLETE / REMOTE·REAL-ACCOUNT·TWO-DEVICE·REAL-DEVICE DEFERRED`
- 범위: 기존 Today Chore·Calendar 합성을 overdue → now/next → 오늘 할 일 → 나머지 일정 → 완료 접힘의 결정적 5-section feed로 세분한다.
- 제외: 새 DB/RPC, client clock 기반 날짜 판정, 과거 완료 전체 이력, remote 성능 측정, 실제 계정·두 기기·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-08 / FR-TODAY-001 | household/timezone/server-local-date/member filter가 일치하는 source만 합성하고, 비어 있지 않은 section을 overdue chores → now/next events → due-today scheduled chores → remaining events → due-today completed chores 순으로 표시한다. |
| FR-TODAY-001 / NFR-REL-01 | `now/next`는 Calendar의 server `generatedAt`을 기준으로 현재 local day와 겹치는 all-day event, `[startsAt, endsAt)`에 현재가 포함되는 timed event, 그리고 아직 시작하지 않은 timed event 중 첫 1건이다. Calendar occurrence는 now/next와 remaining 사이에 정확히 한 번만 나타나며 기존 canonical order를 보존한다. |
| FR-TODAY-001 / FR-TODAY-003 | overdue는 기존 `get_chore_list(view=overdue)`를 독립적으로 조회하고 optimistic quick-complete·duplicate coalescing·rollback을 유지한다. 오늘 할 일과 완료는 기존 `view=today` snapshot의 scheduled/completed partition이다. |
| FR-TODAY-004 / FR-TODAY-005 | overdue source의 initial/loading/failed/refresh stale 상태를 기존 Today·Calendar source와 격리한다. 한 source 실패가 다른 ready section을 숨기지 않으며 retry는 같은 query를 다시 사용한다. |
| NFR-A11Y-01 / NFR-I18N-01 | 5개 section heading, 완료 펼침/접힘 action, source 상태를 semantic하고 ARB 기반으로 제공하며 200% text scale과 pseudo locale에서 overflow하지 않는다. |

## Data and API Impact

- migration, table, index, RPC signature는 변경하지 않는다.
- 기본 Chore source는 기존 `get_chore_list(..., p_view => 'today')`, overdue source는 기존 `get_chore_list(..., p_view => 'overdue')`, Calendar source는 기존 `get_calendar_event_page_v2(..., p_view => 'agenda')`를 사용한다.
- overdue source도 기본 Today source와 같은 household id와 optional assignee member filter를 사용한다. 각 응답의 household id, household timezone, server-local date, member filter가 모두 같지 않으면 해당 source를 합성하지 않는다.
- 날짜 경계와 now/next 판정 시간은 server envelope만 authority로 사용한다. device/client clock은 source 분류에 사용하지 않는다.
- 완료 section은 `view=today` 응답에 포함된 due-today completed occurrence만 표시한다. 전체 과거 완료 이력은 기존 completed tab에 유지한다.

## Implementation

1. Today domain snapshot에 overdue Chore source와 5-section invariant를 추가한다.
2. Calendar snapshot에 all-day/ongoing/nearest-next partition과 remaining complement를 추가하고 occurrence 중복·순서 불변식을 검증한다.
3. overdue 전용 auto-dispose controller/provider를 추가해 main Today query와 독립적인 load/refresh/load-more/quick-complete 상태를 유지한다.
4. Today screen은 Today view에서 두 Chore query와 Calendar query를 함께 시작하고 app resume/filter change에서 모두 authoritative refresh한다.
5. UI를 5개 section으로 분리하고 completed section은 최초 접힘, 사용자 toggle 후에만 card를 렌더한다. non-Today tab은 기존 단일 Chore 목록을 유지한다.
6. overdue initial/refresh/load-more/action 실패를 section-local 상태로 표시하고 raw provider 오류나 content를 오류 메시지에 포함하지 않는다.

## Verification

- Today domain: exact source context, 5-section order, all-day/ongoing/nearest-next, no duplication, stable remaining order, boundary instant tests
- overdue provider/controller: independent request/filter, refresh preservation, pagination, optimistic complete success/rollback/coalescing tests
- Today widget: five-section order, completed default collapse/toggle, overdue quick-complete, partial failure/retry, Everyone/Me, app refresh, empty and 200% pseudo-locale tests
- focused Flutter tests 후 full Flutter suite, fatal analyzer, formatter, l10n/codegen drift, config/secret/whitespace checks
- DB/API 변경이 없으므로 destructive clean reset은 실행하지 않는다. 기존 full DB regression evidence에 의존하되 이번 contract/API 무변경을 evidence에 명시한다.

## Security and Privacy

- 두 Chore query와 Calendar query 모두 기존 authenticated household membership/RLS 경계를 그대로 사용한다.
- Me filter는 active actor member id로 이미 허용된 rows를 좁힐 뿐 visibility를 확장하지 않는다.
- 새 storage, analytics, logs, content cache, native permission, runtime dependency를 추가하지 않는다.
- source mismatch와 provider failure는 fail-closed하며 raw exception, title, participant/assignee content를 오류 문자열에 넣지 않는다.

## Rollback

- Today five-section domain/provider/widget/l10n/tests와 composition contract v2를 함께 revert하면 WP04-05의 Calendar → Chore 합성 화면으로 돌아간다.
- DB migration과 persisted data 변경이 없으므로 data rollback은 없다.
- 운영 중 supplemental overdue query 문제가 확인되면 overdue provider/section만 제거해도 기존 Today Chore·Calendar query와 mutations는 독립적으로 동작한다.

## Completion Boundary

- local automated 5-section composition과 source-isolated failure/action 회귀가 green이면 WP04-08 local slice를 완료한다.
- remote 규모 성능, 실제 계정 권한변경 race, 두 기기 동시 조작과 실기기 접근성은 사용자 지시에 따라 기능 개발 이후 마지막 gate에 남긴다.

2026-08-08 완료 결과: focused Today/overdue 23 tests, 기존 Chore widget 23 tests,
전체 Flutter 834 tests(+ opt-in 1 skip), fatal analyzer, formatter, localization/codegen,
public config, secret scan, Node CI 134/134와 workflow contract가 모두 통과했다. DB/API
변경이 없어 destructive reset과 DB suite는 다시 실행하지 않았고 WP04-07의 47 files /
2,422 pgTAP 전체 회귀를 기준선으로 유지한다. 상세 결과는 `WP04_08_EVIDENCE.md`에
기록한다.
