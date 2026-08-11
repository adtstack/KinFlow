# 원본 파일 문서화: `contracts/notification-app-shell.yaml`

> 이 파일은 인증된 앱 셸 수명 동안 유지되는 알림 동기화와 전역 unread badge 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/notification-app-shell.yaml`
- 원본 형식: `yaml`
- 선행 계약: `docs/contracts/notification-center-sync.yaml.md`
- 범위: WP05-17 local automated slice. hosted Realtime·실계정·두 기기·실기기 검증은 release 전 마지막 Gate로 보류한다.

```yaml
version: "2026-08-10"
name: notification-app-shell
authority:
  snapshot: notification-center authoritative first page
  invalidation: public.notification_sync_watermarks

lifetime:
  owner: one root NotificationCenter lifecycle host
  activeWhen:
    - authenticated session exists
    - active household exists
  inactiveWhen:
    - session is absent
    - active household is absent
  channelBound: at most one auth-user-filtered Realtime channel
  duplicateConsumers: forbidden

synchronization:
  firstActivation: load the active-household authoritative snapshot and subscribe
  sameContextRebuild: reuse the loaded snapshot and existing channel
  appResume: replace the channel and run one authoritative refetch
  householdSwitch:
    - immediately discard the previous household snapshot
    - cancel the previous channel
    - load and subscribe only for the new household
  userSwitch:
    - immediately discard the previous user's snapshot
    - dispose the previous controller and channel
    - load only after the new user has an active household
  deactivate:
    - invalidate any in-flight old-context result
    - clear unread count, inbox, and preferences from presentation state
    - cancel the channel deterministically
  transportFailure: retain the last authorized snapshot and mark it stale
  authorizationFailure: discard retained content and stop synchronization

presentation:
  surfaces:
    - Today primary destination
    - Chores primary destination
    - Calendar primary destination
    - Family primary destination
    - Settings primary destination
  action: open the durable Notification Center
  badge:
    authority: NotificationCenter snapshot unread_count
    zero: hide the visual count while retaining an accessible action
    positive: show a bounded count and localized unread semantics
    stale: retain the last count; Notification Center explains the disconnected state
    contextChange: show zero until the new household snapshot succeeds
  accessibility:
    - semantic button action
    - localized unread-count label
    - minimum platform IconButton target
    - usable at 200 percent text scale

compatibility:
  databaseChange: none
  rpcChange: none
  providerChange: none
  nativePermissionChange: none
  routeChange: none
  fallback:
    - screen-owned ensureLoaded remains safe when the root host is absent in isolated tests
    - app-shell action without the root unread scope renders an accessible zero badge without creating the auth graph

deferred:
  - operating-system background execution while the Flutter process is suspended
  - hosted Supabase propagation and token refresh timing
  - real-account and two-device concurrent changes
  - physical-device lifecycle and network transitions
  - external push and email delivery
```
