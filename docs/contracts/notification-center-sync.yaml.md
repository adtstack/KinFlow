# 원본 파일 문서화: `contracts/notification-center-sync.yaml`

> 이 파일은 알림 센터의 content-free Realtime invalidation 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/notification-center-sync.yaml`
- 원본 형식: `yaml`
- 적용 migration: `supabase/migrations/20260810220000_notification_center_realtime_invalidation.sql`
- 범위: WP05-16 local automated slice. 실제 Supabase 계정·두 기기·실기기 검증은 release 전 마지막 Gate로 보류한다.

```yaml
version: "2026-08-10"
name: notification-center-sync
authority:
  contentReadModel: get_notification_preferences + get_notification_inbox
  invalidationTable: public.notification_sync_watermarks

watermark:
  cardinality: one row per authenticated user after the first notification-visible change
  exactColumns:
    auth_user_id: UUID
    generation: positive monotonic bigint
    changed_at: ISO-8601 UTC timestamp
  forbiddenColumns:
    - household or member identifiers
    - inbox item, source event, subject, or aggregate identifiers
    - category, schedule, read state, or preference values
    - title, description, payload, command, or correlation data
  authorization:
    select: authenticated row owner only
    insertUpdateDelete: trusted database functions only
  producers:
    - notification inbox item insert or update
    - notification preference insert or update
    - household membership update affecting the user's authorization boundary
    - household update affecting notification-center authorization
  batching: each producer statement advances at most once per affected user
  publication: supabase_realtime

consumer:
  topology: one user-filtered channel while the notification center is mounted
  lifecycle:
    - run the authoritative initial snapshot query for the active household
    - subscribe with an exact auth_user_id filter and three-column projection
    - on connected, run a full first-page snapshot refetch to close the query/subscription gap
    - on a strictly newer generation, run a full first-page snapshot refetch
    - while a refetch or mutation is running, coalesce changes and drain one more refetch
    - on disconnect, retain the last successful snapshot and mark it stale
    - on reconnect or app resume, replace the channel and run a full refetch
    - on unauthenticated or household-forbidden refetch, discard retained content immediately
    - on dispose, user switch, or household switch, remove the old channel deterministically
  ordering:
    duplicateGeneration: ignore
    olderGeneration: ignore
    cursorOrDeltaRecovery: forbidden
  malformedPayload: disconnect without exposing raw provider details
  authorizationFailure: never retain a previously readable snapshot
  pagination: invalidation replaces the visible inbox with its authoritative first page

presentation:
  disconnected:
    content: retained and explicitly stale
    action: reconnect notification updates and authoritative full refetch
  connectingOrLive: no persistent banner
  unavailableRepository: manual, resume, and explicit refresh remain functional

deferred:
  - background subscription and app-shell badge outside the notification-center route
  - hosted Supabase propagation and RLS timing
  - real-account and two-device concurrent mutation
  - physical-device background, foreground, and network transitions
  - external push and email provider delivery
```
