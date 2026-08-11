# Phase 05 WP05-15 Chore Realtime Invalidation Workplan

## Status

- 상태: **LOCAL COMPLETED (2026-08-10)**
- 수직 조각: Chore-visible DB change → content-free household watermark → Supabase Realtime → authoritative Chore list refetch → Today/Chores stale/reconnect UI
- 요구사항: `WP05-15`, `FR-TODAY-004`, `FR-TODAY-005`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `CAP-013`, `T-SYNC-02`
- 계약: `docs/contracts/chore-sync.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_15_EVIDENCE.md`

## Product boundary

- 다른 세션에서 생성·완료·다시 열기·건너뛰기·재배정·일정 변경·series 변경·삭제/복원된 Chore를 Today와 Chores Hub가 수동 새로고침 없이 다시 읽는다.
- Realtime frame 자체에는 Chore content나 구성원/대상/command 식별자를 넣지 않고, 변화가 있다는 household generation만 전달한다.
- 화면은 연결 단절 중 마지막 성공 목록을 유지하되 최신이 아닐 수 있음을 명시하고, 명시적 재연결을 제공한다.
- cursor/delta merge, background notification 대체, arbitrary offline write, hosted/실계정/두 기기/실기기 검증은 이번 범위가 아니다.

## Acceptance criteria

1. `chore_sync_watermarks`는 household당 한 행, exact 세 컬럼이며 active member SELECT-only force-RLS다.
2. occurrence insert/update, series update, household/member update는 statement당 affected household generation을 최대 한 번 증가시킨다.
3. consumer는 exact household filter와 allowlisted projection만 구독하며 malformed payload를 disconnected로 닫는다.
4. connected/new generation/reconnect/resume은 현재 query의 first page를 authoritative refetch한다.
5. duplicate/older generation은 무시하고 in-flight load/action 중 변화는 최대 한 번의 후속 refetch로 합친다.
6. disconnect/transport failure는 content를 유지하지만 unauthenticated/not-found-or-forbidden은 즉시 폐기한다.
7. household switch/dispose는 old channel을 제거하고 Today는 primary/overdue 각 하나를 넘지 않는다.
8. EN/KO/EN-XA stale copy와 semantic reconnect action을 Today/Chores ready/empty/partial surfaces에 제공한다.

## DB/API impact

- forward migration: `supabase/migrations/20260810210000_chore_realtime_invalidation.sql`
- public read-only table: `public.chore_sync_watermarks(household_id, generation, changed_at)`
- private writers/triggers only; 새 client RPC, content table, analytics event, cache slot, permission 또는 native dependency는 없다.
- `supabase_realtime` publication에 watermark를 추가한다. derived table은 client write grant가 없으므로 runtime-policy mutation surface에는 포함하지 않는다.
- existing Chore read/mutation signatures와 optimistic-version/idempotency contract는 변경하지 않는다.

## Client design

- Chore domain/data port와 strict Supabase adapter를 Calendar sync와 동일한 계층 경계로 추가한다.
- `ChoreSyncSession`이 subscription 교체, generation ordering, refresh coalescing, stop/dispose를 담당한다.
- `TodayChoresController`는 current query/actor를 보존한 full refetch callback과 sync status를 소유한다.
- Today primary와 overdue controller는 독립 source failure를 유지하며 화면은 둘 중 하나라도 disconnected면 하나의 Chore stale banner를 표시한다.
- nullable repository composition에서는 status가 disabled이고 resume/manual refresh는 계속 동작한다.

## Automated evidence plan

1. pgTAP schema/RLS/grant/publication/helper/trigger/runtime-policy contract와 member/outsider/removed visibility
2. effective create/update/member/household change generation과 statement-level household batching
3. strict payload parser, provider signal mapping, channel disposal
4. duplicate/out-of-order/in-flight drain, reconnect/resume/stop/dispose session tests
5. controller initial gap closure, remote refresh, authorization purge, transport retention, household switch and action race
6. provider composition and Today/Chores disconnected/reconnect widget, localization and 200% text-scale regression
7. focused/full DB and Flutter regression, analyzer, formatter, l10n drift, repository checks and production Web build

## Security and privacy

- published row에는 household id, generation, changed-at만 존재하며 title/description/member/series/occurrence/actor/command/correlation data를 저장하지 않는다.
- raw payload/provider exception을 state, UI, log, analytics 또는 evidence에 반영하지 않는다.
- RLS membership을 subscription과 authoritative refetch에서 모두 다시 적용한다.
- authorization loss는 ordinary stale state로 취급하지 않고 in-memory retained Chore content를 즉시 제거한다.

## Rollback

- client는 nullable `ChoreSyncRepository` wiring을 제거하거나 null로 두면 기존 initial/manual/resume query로 돌아간다.
- DB는 publication에서 watermark table을 제거한 뒤 producer/runtime-policy triggers, private helpers, policy/table 순으로 제거한다.
- watermark는 content-free derived metadata이므로 제거해도 Chore series/occurrence/command data는 손실되지 않는다.

## Completion boundary

- local deterministic DB/Flutter tests와 repository automated Gate가 green이면 WP05-15 local slice를 완료로 기록한다.
- 실제 hosted Realtime, 실계정, 두 기기 race, background/foreground/network physical-device UX는 사용자 지시에 따라 기능 개발이 충분히 끝난 뒤 마지막 Gate에서 검증한다.
