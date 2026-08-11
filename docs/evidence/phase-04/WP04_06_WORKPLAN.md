# Phase 04 WP04-06 Conflict, Deep-link, and Realtime Recovery Workplan

- 상태: `LOCAL AUTOMATED COMPLETE` — remote·real-account·real-device gate deferred
- 범위: Calendar의 expected-version 충돌을 최신 snapshot으로 복구하고, 삭제·권한변경된 occurrence deep link를 안전하게 닫으며, Realtime 단절·재연결·중복·역순 신호를 결정적으로 처리한다.
- 제외: persistent offline cache/outbox, background push delivery, remote latency/query-plan 측정, 실제 계정·두 기기·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-06 / FR-CAL-005 / FR-CAL-006 | mutation은 기존 expected series/occurrence version을 유지하고, `VERSION_CONFLICT` 응답 시 현재 Calendar 범위를 authoritative refetch한 뒤 사용자가 최신 데이터로 다시 결정할 수 있게 한다. |
| WP04-06 / FR-CAL-007 | `/calendar/event/:occurrenceId` deep link는 서버가 반환한 household-local date로 대상을 연다. 삭제·취소·권한변경·잘못된 target은 내용이나 raw provider 오류를 노출하지 않는 unavailable 상태로 끝난다. |
| WP04-06 / FR-CAL-007 / NFR-REL-01 | initial query 뒤 household-scoped Realtime invalidation을 구독하고, 유효한 change마다 full refetch한다. duplicate/out-of-order generation은 무시하고 refresh 중 change는 한 번 더 drain한다. |
| WP04-06 / FR-TODAY-004 | channel disconnect 중 마지막 성공 content를 유지하고 stale 상태를 표시한다. reconnect와 app resume에서는 cursor/delta에 의존하지 않고 full refetch한다. |
| WP04-06 / FR-TODAY-005 | Today Calendar source도 같은 household invalidation과 reconnect 규칙으로 갱신하며 Chore source 상태는 독립적으로 유지한다. |
| NFR-SEC-01 / NFR-PRIV-01 | Realtime payload는 household id, monotonic generation, timestamp만 포함하고 active household member만 읽는다. event title·description·participant·actor·command id는 publication에 넣지 않는다. |
| NFR-A11Y-01 / NFR-I18N-01 | conflict resolution, live-disconnected, unavailable deep-link 상태와 action은 semantic하고 ARB 기반으로 제공한다. |
| NFR-REL-01 | initial-query/subscription gap, reconnect, duplicate/out-of-order signal, mutation-race, deleted target을 unit/widget/pgTAP으로 검증한다. |

## Data and API Impact

- `public.calendar_sync_watermarks`: household당 한 행만 유지하는 content-free invalidation table을 추가한다.
- `app_private.calendar_audit_events`의 interactive command audit insert 뒤 generation을 원자적으로 증가시키는 trigger를 추가한다. idempotent replay는 새 audit row를 만들지 않으므로 generation도 증가하지 않는다.
- interactive audit가 없는 rolling-horizon occurrence insert/update도 statement transition table로 household당 한 번 generation을 증가시킨다.
- RLS는 active household member의 `select`만 허용하고 client insert/update/delete는 허용하지 않는다. table을 `supabase_realtime` publication에 추가한다.
- `public.get_calendar_occurrence_locator(p_household_id, p_occurrence_id)`: target이 현재 읽기 가능한 경우에만 series/occurrence id, household-local view date와 current versions를 반환한다. contentful field는 반환하지 않는다.
- 기존 create/update/delete/cancel RPC shape와 expected-version contract는 변경하지 않는다.

## Implementation

1. Calendar domain/data port에 typed sync signal과 content-free occurrence locator를 추가한다.
2. Supabase adapter는 strict payload mapping, channel status mapping, household filter와 deterministic disposal을 제공한다.
3. 재사용 가능한 sync session은 subscribe/reconnect/full-refetch, monotonic generation dedupe, in-flight refresh drain을 담당한다.
4. Calendar controller는 conflict/not-found mutation 결과를 authoritative refetch하여 `latest reloaded` 또는 `target unavailable`로 분기하고 마지막 성공 content를 보존한다.
5. router와 Calendar screen은 UUID path deep link를 지원하고 target을 day range에서 연다. target이 사라지면 안전한 unavailable UI와 Calendar 복귀 action을 제공한다.
6. Today Calendar controller는 같은 sync session을 사용하고 disconnect 상태를 source-level stale banner로 표시한다.

## Verification

- locator/sync payload strict-mapping과 provider failure mapping unit tests
- sync session의 duplicate/out-of-order, in-flight drain, disconnect/reconnect, dispose tests
- Calendar controller stale/not-found authoritative recovery와 highlighted target disappearance tests
- Calendar/Today widget deep-link unavailable, conflict resolution, disconnected stale-content, retry/a11y/pseudo-locale tests
- pgTAP table shape, RLS membership lifecycle, client write denial, generation increment/replay, publication membership, locator authorization/deleted target tests
- clean local Supabase reset, full DB tests/lint, focused and full Flutter tests with coverage, analyzer, formatter, l10n/codegen, offline lock/config/secret/whitespace checks

## Security and Privacy

- Realtime은 content를 전송하지 않는 invalidation-only channel이며 실제 event content는 기존 authenticated RPC/RLS 경계에서 다시 읽는다.
- removed member는 RLS로 watermark와 locator 모두 읽지 못한다. deep-link target 존재 여부도 `not found or forbidden`으로 합친다.
- raw provider exception, token, event content, participant id, actor id, idempotency/correlation id를 log나 error UI에 노출하지 않는다.
- reconnect는 마지막 content를 보여주되 stale임을 명시하며, 권한을 추정해 로컬 content 범위를 확장하지 않는다.
- authenticated refetch가 unauthenticated 또는 household not-found/forbidden을 반환하면 stale content retention을 중단하고 이전 snapshot을 즉시 폐기한다.

## Rollback

- client sync/locator/controller/UI/l10n/tests를 함께 revert하면 기존 manual refresh + generic conflict banner로 돌아간다.
- DB rollback은 Realtime publication에서 `calendar_sync_watermarks`를 제거한 뒤 trigger/function/policy/table/locator RPC 순으로 제거한다. event source tables와 command data는 변경하지 않는다.
- 운영에서 channel 문제가 생기면 sync repository를 unavailable implementation으로 교체하여 기존 initial/resume/manual query만 유지할 수 있다.

## Completion Boundary

- local automated conflict/deep-link/reconnect 기능과 DB contract가 green이면 WP04-06 local slice를 완료한다.
- 실제 Supabase 계정의 channel reconnect, 두 기기 동시 편집, background/foreground 전환, remote query plan과 실기기 접근성은 사용자 지시에 따라 기능 개발 이후 마지막 gate에 남긴다.

2026-08-08 local automated gate는 clean 24-migration reset, focused 38/38와 full 1,565 pgTAP, DB lint, full Flutter 464 tests(+ opt-in 1 skip), 79.29% line coverage, analyzer/formatter/lock/codegen/config/secret checks를 통과했다. `FR-CAL-008`의 같은 구성원 일정 overlap 힌트는 expected-version 충돌과 다른 요구사항이므로 완료로 표시하지 않으며 후속 UI slice에 남긴다. 상세 결과는 `WP04_06_EVIDENCE.md`에 기록한다.
