# Phase 04 WP04-05 Today Composition Workplan

- 상태: `LOCAL AUTOMATED COMPLETE` — remote·real-account·real-device gate deferred
- 범위: 기존 Chore와 Calendar source를 하나의 Today 화면에 합성하되 source별 loading/failure/stale 상태를 격리한다.
- 제외: Realtime, offline persistent cache/outbox, remote 성능 측정, 실제 계정·두 기기·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-05 / FR-TODAY-001 | Chore와 Calendar를 같은 화면의 결정적 section 순서로 표시하고, 두 응답의 household/timezone/server-local-date가 같을 때만 합성한다. |
| FR-TODAY-002 | Everyone/Me 선택이 chore assignee와 event participant에 각각 적용되며 권한 범위를 넓히지 않는다. |
| FR-TODAY-003 | 기존 optimistic quick-complete, duplicate coalescing, rollback 동작을 합성 화면에서도 유지한다. |
| FR-TODAY-004 | 각 source의 마지막 성공 content/generated-at을 refresh 실패 시 유지하고 source별 stale 상태와 retry를 표시한다. |
| FR-TODAY-005 | Calendar 실패가 Chore를 숨기지 않고 Chore 실패가 Calendar를 숨기지 않는다. 둘 다 실패한 경우에만 전체 오류 상태를 표시한다. |
| FR-CAL-007 | one-time/recurring/exception event projection을 Today day boundary에서 표시한다. |
| NFR-A11Y-01 / NFR-I18N-01 | section heading, source 상태, event metadata와 action을 semantic하고 ARB 기반으로 제공하며 200% text scale 회귀를 유지한다. |
| NFR-REL-01 | bounded Calendar pagination, duplicate identity rejection, cross-source context mismatch fail-closed와 concurrent initial load를 검증한다. |

## Data and API Impact

- 새 migration이나 table은 추가하지 않는다.
- Chore source는 `get_chore_list(..., p_view => 'today')`, Calendar source는 `get_calendar_event_page_v2(..., p_view => 'agenda', null range)`를 그대로 사용한다.
- 두 RPC 모두 서버 statement timestamp에서 household-local date를 반환한다. client clock을 day boundary에 사용하지 않는다.
- Today domain은 household id, timezone, local date가 모두 같은 snapshot만 합성한다. 자정 race 또는 malformed/mixed context는 Calendar source 오류로 격리하고 Chore content는 유지한다.
- Calendar source는 100개 page를 cursor로 이어 읽되 Today 범위를 벗어나는 첫 row에서 중지하고 최대 500개로 제한한다.

## Implementation

1. `features/today/domain`에 Calendar source snapshot과 cross-context composition invariant를 추가한다.
2. Calendar source controller는 initial load/refresh, participant filter, bounded pagination, stale-content retention을 제공한다.
3. Riverpod provider를 추가하고 기존 Today screen에서 Chore/Calendar를 동시에 시작·갱신한다.
4. Today view에는 Calendar와 Chore section을 표시하고, upcoming/overdue/completed view에는 기존 Chore UX를 유지한다.
5. source별 loading/error/stale/retry와 Calendar-only/Chore-only partial success를 표시한다.
6. event card는 all-day/timed, participant, recurring/exception metadata를 표시하고 Calendar 화면으로 이동할 수 있다.

## Verification

- Today domain invariant/order/filter unit tests
- Calendar source controller pagination, bounded cap, partial refresh, mismatch and participant filter tests
- combined widget happy path, 양방향 partial failure, context mismatch, retry/filter, empty and 200% pseudo-locale tests
- existing Chore quick actions and Calendar regression
- full Flutter tests with coverage, fatal analyzer, formatter, offline lock replay, l10n/codegen drift, config/secret/whitespace checks
- database migration 변경이 없으므로 full DB suite 대신 기존 WP04-04C clean-reset/full DB evidence를 의존하고 contract references만 갱신한다.

## Security and Privacy

- 두 source 모두 기존 authenticated RLS/security-definer boundary를 사용한다.
- Me filter는 이미 읽을 수 있는 household rows를 더 좁힐 뿐 가시성을 확장하지 않는다.
- 새 저장소, log, analytics, participant cache, native permission 또는 runtime dependency를 추가하지 않는다.
- raw provider exception이나 event/chore content를 error UI에 노출하지 않는다.

## Rollback

- Today Calendar provider/domain/widget/l10n/tests/docs를 함께 revert하면 WP03-06 Chore-only Today로 돌아간다.
- DB migration이 없으므로 data rollback은 없다. Calendar 화면과 Chore mutation은 독립적으로 계속 동작한다.
- 운영에서 Calendar source 문제가 생기면 Today Calendar section만 feature surface에서 제거하고 Chore-only fallback을 유지한다.

## Completion Boundary

- local automated composition까지 green이면 WP04-05 기능 slice를 완료한다.
- Realtime conflict/reconnect는 WP04-06, remote latency/query plan과 실제 계정·실기기 gate는 사용자 지시에 따라 기능 개발 이후 마지막 단계에 남긴다.

2026-08-07 local automated gate는 focused Today 15/15, full Flutter 447 tests(+ opt-in 1 skip), 79.56% line coverage, analyzer/formatter/lockfile/codegen/config/secret/whitespace checks를 모두 통과했다. 상세 범위와 남은 MASTER Today ordering, Realtime, persistent offline, remote·실계정·실기기 검증은 `WP04_05_EVIDENCE.md`에 기록한다.
