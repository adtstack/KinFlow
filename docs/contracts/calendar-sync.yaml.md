# 원본 파일 문서화: `contracts/calendar-sync.yaml`

> 이 파일은 Calendar conflict recovery, occurrence deep link, Realtime invalidation의 normative 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-sync.yaml`
- 원본 형식: `yaml`
- 적용 migration: `supabase/migrations/20260808000000_calendar_conflict_realtime_and_locator.sql`
- 범위: WP04-06 local automated slice. 실제 Supabase 계정·두 기기·실기기 검증은 release 전 마지막 gate로 보류한다.

```yaml
version: "2026-08-08"
name: calendar-sync
authority:
  contentReadModel: get_calendar_event_page_v2
  occurrenceLocator: get_calendar_occurrence_locator
  invalidationTable: public.calendar_sync_watermarks

watermark:
  cardinality: one row per household after its first Calendar change
  exactColumns:
    household_id: UUID
    generation: positive monotonic bigint
    changed_at: ISO-8601 UTC timestamp
  forbiddenColumns:
    - title
    - description
    - participant identifiers
    - actor identifiers
    - command or correlation identifiers
  authorization:
    select: authenticated active member of the same household only
    insertUpdateDelete: trusted database functions only
  producers:
    - interactive Calendar audit insert
    - statement-level occurrence insert or update for horizon materialization
  replay:
    idempotent command replay does not create another audit row or generation
  publication: supabase_realtime

locator:
  inputExactKeys: [p_household_id, p_occurrence_id]
  outputExactKeys:
    - household_id
    - household_timezone
    - household_local_date
    - generated_at
    - series_id
    - occurrence_id
    - view_local_date
    - series_version
    - occurrence_version
  visibleOnlyWhen:
    - caller is an active member of the requested household
    - household and series are not deleted
    - occurrence status is scheduled
  failureBoundary:
    deletedCancelledUnauthorizedOrMissing: not-found-or-forbidden
    leaksTargetContentOrExistence: false

consumer:
  lifecycle:
    - run authoritative initial query
    - subscribe with an exact household_id filter and three-column projection
    - on connected, run a full refetch to close the query/subscription gap
    - on a strictly newer generation, run a full refetch
    - while a refetch is running, coalesce changes and drain one more refetch
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

deepLink:
  route: /calendar/event/:occurrenceId
  occurrenceId: UUID
  openDate: locator.view_local_date
  pageSize: 100
  maximumRowsInspected: 500
  deletedCancelledUnauthorizedOrMalformed: content-free unavailable screen

conflictRecovery:
  writesKeepExpectedVersion: true
  staleOrNotFoundMutation:
    - resolve the target through the content-free locator
    - refetch the authoritative current Calendar selection
    - show latest-reloaded when the target remains readable
    - show target-unavailable when it no longer does
  automaticLastWriteWins: forbidden
```
