# Phase 05 WP05-16 Notification Center Realtime Invalidation Workplan

## Status

- 상태: **LOCAL COMPLETED (2026-08-10)**
- 수직 조각: notification-visible DB change → content-free user watermark → Supabase Realtime → authoritative notification snapshot refetch → inbox/badge stale/reconnect UI
- 요구사항: `WP05-16`, `FR-NOTIF-007`, `FR-NOTIF-008`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `T-SYNC-02`
- 계약: `docs/contracts/notification-center-sync.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_16_EVIDENCE.md`

## Product boundary

- 다른 세션이나 worker가 생성·취소·읽음 처리한 inbox item과 다른 세션에서 변경한 category preference를 알림 센터가 수동 새로고침 없이 다시 읽는다.
- Realtime frame에는 알림 content나 household/member/item/source/category 식별자를 넣지 않고, 현재 auth user에게 변화가 있다는 generation만 전달한다.
- 화면은 연결 단절 중 마지막 성공 inbox·badge·preference를 유지하되 최신이 아닐 수 있음을 명시하고, 명시적 재연결을 제공한다.
- background 전역 구독, app-shell route badge, cursor/delta merge, Web Push, email/push provider 변경, hosted/실계정/두 기기/실기기 검증은 이번 범위가 아니다.

## Acceptance criteria

1. `notification_sync_watermarks`는 auth user당 한 행, exact 세 컬럼이며 self SELECT-only force-RLS다.
2. inbox insert/update, preference insert/update, household/member authorization update는 statement당 affected user generation을 최대 한 번 증가시킨다.
3. consumer는 exact auth user filter와 allowlisted projection만 구독하며 malformed payload를 disconnected로 닫는다.
4. connected/new generation/reconnect/resume은 현재 household snapshot의 first page를 authoritative refetch한다.
5. duplicate/older generation은 무시하고 in-flight load/action 중 변화는 최대 한 번의 후속 refetch로 합친다.
6. disconnect/transport failure는 content를 유지하지만 unauthenticated/not-found-or-forbidden은 즉시 폐기한다.
7. user/household switch와 dispose는 old channel을 제거하며 화면당 channel은 하나를 넘지 않는다.
8. EN/KO/EN-XA stale copy와 semantic reconnect action을 ready/empty inbox surface에 제공한다.

## DB/API impact

- forward migration: `supabase/migrations/20260810220000_notification_center_realtime_invalidation.sql`
- public read-only table: `public.notification_sync_watermarks(auth_user_id, generation, changed_at)`
- private writers/triggers only; 새 client RPC, content table, analytics event, cache slot, permission 또는 native dependency는 없다.
- `supabase_realtime` publication에 watermark를 추가한다. derived table은 client write grant가 없으므로 runtime-policy mutation surface에는 포함하지 않는다.
- existing notification snapshot/read/preference/snooze signatures와 optimistic-version/idempotency contract는 변경하지 않는다.

## Client design

- Notification domain/data port와 strict Supabase adapter를 Calendar/Chore sync와 동일한 계층 경계로 추가한다.
- `NotificationSyncSession`이 subscription 교체, generation ordering, refresh coalescing, stop/dispose를 담당한다.
- `NotificationCenterController`는 current user/household를 보존한 full snapshot refetch callback과 sync status를 소유한다.
- invalidation refetch는 pagination을 authoritative first page로 교체하며, local action의 즉시 결과는 기존 optimistic snapshot 규칙을 유지한다.
- nullable repository composition에서는 status가 disabled이고 resume/manual refresh는 계속 동작한다.

## Automated evidence plan

1. pgTAP schema/RLS/grant/publication/helper/trigger contract와 self/other/anonymous visibility
2. inbox/preference/member/household change generation과 statement-level user batching
3. strict payload parser, provider signal mapping, channel disposal
4. duplicate/out-of-order/in-flight drain, reconnect/resume/stop/dispose session tests
5. controller initial gap closure, remote refresh, authorization purge, transport retention, user/household switch and action race
6. provider composition and notification-center disconnected/reconnect widget, localization and 200% text-scale regression
7. focused/full DB and Flutter regression, analyzer, formatter, l10n drift, repository checks and production Web build

## Security and privacy

- published row에는 auth user id, generation, changed-at만 존재하며 household/member/item/source/category/content/command data를 저장하지 않는다.
- auth user id는 exact self RLS와 filtered subscription routing에만 사용하고 UI, log, analytics 또는 evidence에 표시하지 않는다.
- raw payload/provider exception을 state, UI, log, analytics 또는 evidence에 반영하지 않는다.
- authoritative refetch에서 active-household membership을 다시 적용하며 authorization loss는 retained notification content를 즉시 제거한다.

## Rollback

- client는 nullable `NotificationSyncRepository` wiring을 제거하거나 null로 두면 기존 initial/manual/resume query로 돌아간다.
- DB는 publication에서 watermark table을 제거한 뒤 producer triggers, private helpers, policy/table 순으로 제거한다.
- watermark는 content-free derived metadata이므로 제거해도 preferences, inbox items, provider queue 또는 delivery data는 손실되지 않는다.

## Completion boundary

- local deterministic DB/Flutter tests와 repository automated Gate가 green이면 WP05-16 local slice를 완료로 기록한다.
- 실제 hosted Realtime, 실계정, 두 기기 race, background/foreground/network physical-device UX와 provider delivery는 사용자 지시에 따라 기능 개발이 충분히 끝난 뒤 마지막 Gate에서 검증한다.
