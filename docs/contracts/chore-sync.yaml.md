# 원본 파일 문서화: `contracts/chore-sync.yaml`

> 이 파일은 Chores/Today의 content-free Realtime invalidation 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/chore-sync.yaml`
- 원본 형식: `yaml`
- 적용 migration: `supabase/migrations/20260810210000_chore_realtime_invalidation.sql`
- 범위: WP05-15 local automated slice. 실제 Supabase 계정·두 기기·실기기 검증은 release 전 마지막 Gate로 보류한다.

```yaml
version: "2026-08-10"
name: chore-sync
authority:
  contentReadModel: get_chore_list
  invalidationTable: public.chore_sync_watermarks

watermark:
  cardinality: one row per household after its first Chore-visible change
  exactColumns:
    household_id: UUID
    generation: positive monotonic bigint
    changed_at: ISO-8601 UTC timestamp
  forbiddenColumns:
    - title
    - description
    - assignee or actor identifiers
    - series or occurrence identifiers
    - command or correlation identifiers
  authorization:
    select: authenticated active member of the same household only
    insertUpdateDelete: trusted database functions only
  producers:
    - chore occurrence insert or update
    - chore series update
    - household member update affecting assignee copy or authorization
    - household update affecting timezone or authorization
  batching: each producer statement advances at most once per affected household
  publication: supabase_realtime

consumer:
  topology:
    choresHub: one channel for the active list query
    today: at most two channels for primary and overdue list queries
  lifecycle:
    - run the authoritative initial list query
    - subscribe with an exact household_id filter and three-column projection
    - on connected, run a full first-page refetch to close the query/subscription gap
    - on a strictly newer generation, run a full first-page refetch
    - while a refetch or mutation is running, coalesce changes and drain one more refetch
    - on disconnect, retain the last successful content and mark it stale
    - on reconnect or app resume, replace the channel and run a full refetch
    - on unauthenticated or household-forbidden refetch, discard retained content immediately
    - on dispose or household switch, remove the old channel deterministically
  ordering:
    duplicateGeneration: ignore
    olderGeneration: ignore
    cursorOrDeltaRecovery: forbidden
  malformedPayload: disconnect without exposing raw provider details
  authorizationFailure: never retain a previously readable snapshot
  pagination: invalidation replaces the visible query with its authoritative first page

presentation:
  disconnected:
    content: retained and explicitly stale
    action: reconnect Chore updates and full-refetch each visible Chore source
  connectingOrLive: no persistent banner
  unavailableRepository: manual, resume, and explicit refresh remain functional

deferred:
  - hosted Supabase propagation and RLS timing
  - real-account and two-device concurrent mutation
  - physical-device background, foreground, and network transitions
```
