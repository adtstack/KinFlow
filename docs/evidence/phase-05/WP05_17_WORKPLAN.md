# Phase 05 WP05-17 App-shell Notification Sync and Global Badge Workplan

## Status

- 상태: **LOCAL AUTOMATED PASS (2026-08-10)**
- 수직 조각: authenticated app lifecycle → one Notification Center owner → active-household authoritative snapshot → one user Realtime channel → five-destination unread badge
- 요구사항: `WP05-17`, `FR-NOTIF-007`, `FR-NOTIF-008`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `T-SYNC-02`
- 계약: `docs/contracts/notification-app-shell.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_17_EVIDENCE.md`

## Product boundary

- 인증 세션과 active household가 있는 동안 route와 무관하게 Notification Center provider 한 개를 유지해 worker·다른 세션의 변경을 현재 앱 셸 badge에 반영한다.
- Today, Chores, Calendar, Family, Settings의 공통 알림 action은 같은 server-authoritative unread count를 표시하고 durable Notification Center를 연다.
- 가구 전환·마지막 가구 이탈·logout·사용자 전환에서는 이전 snapshot과 badge를 즉시 폐기하고 old-context 응답이 뒤늦게 돌아와도 다시 노출하지 않는다.
- OS가 Flutter process를 suspend한 동안의 background execution, hosted transport, 실계정, 두 기기, 실기기와 외부 provider 전달은 이번 범위가 아니다.

## Acceptance criteria

1. root lifecycle host가 Notification Center controller/provider의 유일한 앱 셸 수명 owner이며 route 이동으로 channel이 추가·교체되지 않는다.
2. 첫 authenticated active-household activation은 snapshot을 읽고 user-filtered channel 하나를 시작한다.
3. 같은 user/household rebuild와 primary route 이동은 snapshot·channel을 재사용한다.
4. resume은 channel을 교체하고 full snapshot을 다시 읽으며 중복 resume 요청은 기존 session coalescing 경계를 벗어나지 않는다.
5. household/user/no-household 전환은 이전 content와 badge를 즉시 0으로 만들고 old channel을 취소한 뒤 새 context만 읽는다.
6. 전환 중 완료되는 이전 load/action 응답은 presentation state를 갱신하지 않는다.
7. 다섯 primary destination이 같은 unread badge semantics와 Notification Center route action을 제공한다.
8. zero/positive/stale/context-change badge가 EN/KO/EN-XA 및 200% text scale에서 안전하다.

## DB/API impact

- 새 migration, table, publication, RPC, Edge function 또는 payload key는 없다.
- WP05-16 `notification_sync_watermarks`와 기존 Notification Center snapshot/read/preference/snooze API를 그대로 재사용한다.
- 새 analytics event, cache slot, native dependency, permission 또는 deep link도 없다.

## Client design

- `NotificationCenterController`에 idempotent `ensureLoaded`와 context-invalidating `deactivate`를 추가한다.
- 모든 async result는 요청 household가 여전히 current context인지 확인한 뒤에만 state를 갱신한다.
- `NotificationCenterLifecycleHost`가 auth user/active household pair와 app resume을 관찰하고 provider를 root에서 keep-alive한다.
- screen-owned initial loads는 `ensureLoaded` fallback으로 축소하고 Today/Notification Center의 중복 resume 책임은 root host로 이동한다.
- root host가 `NotificationCenterReady.snapshot.unreadCount`를 read-only inherited scope로 투영하고 공용 `NotificationAppShellAction`이 다섯 primary 화면에서 같은 badge를 제공한다. root가 없는 격리 화면은 auth graph를 만들지 않고 접근 가능한 0 badge로 fail closed한다.

## Automated evidence plan

1. controller ensure-loaded idempotency, in-flight deactivate, old result suppression, no-household purge and household switch
2. root host first activation, same-context reuse, primary route stability, resume refetch and user/household deactivation
3. five primary destination badge presence, shared unread update, route action, zero/99+ and disconnected retention
4. EN/KO/EN-XA semantics and compact/rail 200% text-scale regression
5. existing WP05-16 session/adapter/controller/widget regression
6. full Flutter, analyzer, formatter, codegen, repository Gate and production Web build

## Security and privacy

- root host는 새 content를 저장하지 않고 기존 controller의 process-memory snapshot 수명만 명시한다.
- user/household/no-household 전환은 old-context result를 무시하고 content를 먼저 폐기한 후 새 권위 조회를 수행한다.
- badge에는 unread aggregate만 표시하며 household/member/item/category/content/provider detail을 추가로 노출하지 않는다.
- Realtime payload와 RLS 경계는 WP05-16 exact three-field self-user 계약을 변경하지 않는다.

## Rollback

- root `NotificationCenterLifecycleHost`와 공용 primary badge action을 제거하면 WP05-16의 Today/Notification Center 화면 수명 동기화로 돌아간다.
- `ensureLoaded` fallback을 기존 `load` 호출로 되돌릴 수 있으며 DB/API rollback은 필요 없다.
- `deactivate`는 additive client lifecycle API이므로 제거해도 server data나 notification history는 바뀌지 않는다.

## Completion boundary

- local controller/host/widget 자동화와 전체 repository Gate가 green이면 WP05-17 local slice를 완료로 기록한다.
- 실제 background suspension, hosted Realtime, 실계정, 두 기기 및 실기기 lifecycle은 사용자 지시에 따라 마지막 Gate에서 판정한다.
