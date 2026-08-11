# Phase 04 WP04-09 Persistent Today Calendar Cache Workplan

- 상태: `LOCAL AUTOMATED COMPLETE / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED`
- 범위: Android Store MVP에서 완성된 Today Calendar source snapshot을 기존 전용
  encrypted read-cache namespace에 bounded fixed slot으로 저장하고, provider가
  일시적으로 unavailable일 때 process restart 뒤 stale/read-only로 복구한다.
- 제외: Web/iOS persistent family-data cache, client-clock 날짜 판정, Calendar 전체
  agenda/history cache, offline mutation/outbox, background sync authority, 실제 계정·원격·
  두 기기·실기기 forensic 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-09 / FR-TODAY-004 / D-017 | server-authoritative Today Calendar snapshot을 최대 500 occurrence와 기존 slot당 196,608 encoded bytes 안에서 저장한다. initial load가 `temporarilyUnavailable`일 때만 exact cache를 복원하고 cached-at, reconnect와 read-only 이유를 표시한다. |
| FR-TODAY-001 / NFR-REL-01 | cache payload는 household ID, household timezone, server-local date, server `generatedAt`, participant member filter, truncation과 canonical event projection을 보존한다. 복원 시 기존 domain constructor로 exact context, occurrence uniqueness와 order를 다시 검증한다. |
| D-049 / NFR-SEC-01 | 기존 envelope의 exact contract/user/session/household/TTL 경계를 재사용한다. payload household 또는 member-filter mismatch, corrupt/expired/session-mismatched record는 표시하지 않는다. auth/household transition과 authorization loss는 cache를 삭제하거나 전체 read cache를 purge한다. |
| NFR-PRIV-01 / D-043 / D-045 | identifier 없는 `today_calendar_v1` fixed slot과 environment별 Android encrypted namespace만 사용한다. Web persistent cache, plaintext storage, 새 log/analytics, Drift/runtime dependency/native permission을 추가하지 않는다. |
| FR-CAL-001~007 | Calendar create/update/delete, recurring series와 single-occurrence mutation 성공은 Today Calendar slot을 invalidate한다. mutation failure를 성공으로 가장하지 않고 authorization loss는 모든 read slot을 clear한다. |
| NFR-A11Y-01 / NFR-I18N-01 | cached Calendar banner, last successful sync, read-only 설명과 retry를 EN/KO/EN-XA ARB로 제공한다. cached source가 하나라도 포함되면 Today query filter 변경을 막아 서로 다른 source context를 섞지 않는다. |

## Storage and Contract

- envelope contract와 TTL/size: 기존 `SecureReadCache`의 exact seven-key envelope,
  최대 24시간이되 current Supabase session expiry 이하, slot당 196,608 bytes
- fixed slot 추가: `today_calendar_v1`; key에 user/session/household/member/content 없음
- payload: exact version, household/timezone/server-local-date/generated-at,
  participant filter, truncated, 최대 500 canonical event projections
- write authority: 모든 Today Calendar page가 검증되고 한 snapshot으로 합성된 뒤의
  server `generatedAt`; 중간 page나 client clock은 쓰지 않음
- read fallback: `temporarilyUnavailable` initial read만 허용. retained in-memory/cache
  content의 refresh 실패는 같은 snapshot을 보존한다.
- invalid payload는 해당 slot 삭제, unauthenticated/not-found-or-forbidden은 전체 read
  cache clear, valid하지만 다른 member filter의 fixed-slot snapshot은 표시하지 않되
  원래 query의 재시도를 위해 보존한다.

## Implementation

1. `ReadCacheSlot.todayCalendar`와 Today snapshot cache application port/no-op을 추가한다.
2. infrastructure adapter가 exact JSON-compatible payload를 encode/decode하고 모든
   value object/domain invariant를 다시 통과시킨다.
3. Today Calendar controller가 online success를 best-effort write하고 transient initial
   failure에서 exact cached snapshot을 복원한다. state에 cache metadata/read-only를
   명시하고 authoritative refresh 성공 시 marker를 제거한다.
4. Calendar repository decorator가 모든 Calendar mutation success에서 slot을
   invalidate하고 authorization boundary failure에서 read cache 전체를 clear한다.
5. Android auth composition에서 같은 `SecureReadCache` instance를 adapter와 decorator에
   연결하고 bootstrap provider로 Today controller에 주입한다. unavailable/Web 경로는
   no-op을 유지한다.
6. Today Calendar section에 cache banner/read-only copy/retry를 추가하고 cached source가
   있는 동안 Everyone/Me와 view filter 변경을 UI에서 차단한다.

## Test Plan

- snapshot codec: timed/all-day/recurring/exception round-trip, exact keys, member-filter
  mismatch preservation, corrupt/order/duplicate/household mismatch deletion
- secure cache: 네 fixed slot clear/purge, session/household/expiry/size behavior 회귀
- controller: online write, process-restart transient fallback, non-transient no fallback,
  cached refresh recovery, query mismatch, authorization purge, superseded response
- mutation decorator: each create/update/delete/series/occurrence success invalidation,
  failure preservation와 authorization clear
- widget: cached event/last-sync/read-only/retry, filters disabled, authoritative recovery,
  empty cached snapshot, EN-XA 200% overflow
- auth composition/bootstrap, household transition purge와 기존 Chore cache 회귀
- focused/full Flutter tests, fatal analyzer, formatter, l10n/codegen, config/secret와
  whitespace checks

## DB and API Impact

- migration, table, index, RLS, RPC/Edge/OpenAPI signature 변경 없음
- Calendar/Chore server query와 Realtime contract 변경 없음
- 새 runtime dependency, platform permission, native source, analytics/log event 없음

## Security and Privacy

- payload는 기존 Android Keystore-backed AES-GCM secure-storage namespace 안에서만
  유지하며 backup migration은 disabled다.
- 복원은 authenticated session scope가 살아 있고 exact household가 일치할 때만
  가능하다. payload를 domain object로 직접 cast하지 않는다.
- cache 오류나 raw content를 UI/error/log에 포함하지 않는다.
- cached content에서는 Today Calendar mutation authority를 만들지 않으며 offline
  outbox를 추가하지 않는다.

## Rollback

- `today_calendar_v1` adapter/provider/controller/UI와 repository decorator를 제거하고
  composition contract v2로 되돌리면 기존 in-memory Calendar stale behavior로 복귀한다.
- Android runtime에서 persistent read cache flag를 끄면 기존 online-only Calendar
  repository와 no-op cache가 즉시 사용된다.
- 전용 read-cache namespace `deleteAll` 또는 새 slot delete로 family cache만 제거할 수
  있고 auth session/notification storage나 server data는 건드리지 않는다.
- DB/data migration이 없어 server rollback은 없다.

## Completion Boundary

- fake secure storage/provider와 deterministic clock으로 cold process cache, strict decode,
  source read-only UI, mutation invalidation과 auth/household purge가 모두 green이면
  WP04-09 local automated slice를 완료한다.
- 실제 Android Keystore large-value 성능, process death/airplane mode, remote membership
  removal, background/reconnect와 screen reader는 사용자 지시에 따라 기능 개발 뒤
  마지막 gate에 남긴다.
