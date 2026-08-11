# 원본 파일 문서화: `contracts/today-composition.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/today-composition.yaml`
- 원본 형식: `yaml`
- 관련 범위: WP04-05, WP04-08, WP04-09, FR-TODAY-001~005, FR-CAL-007

```yaml
version: "2026-08-08"
name: kinflow.today.composition.v3

authority:
  choreSource: get_chore_list
  calendarSource: get_calendar_event_page_v2
  clientClock: forbidden for source day boundaries
  sourceGeneratedAt: server statement timestamp
  persistence: bounded Android encrypted Today source snapshots

request:
  required: [householdId, view, memberFilter]
  householdId: uuid
  view: today | upcoming | overdue | completed
  memberFilter: everyone | activeActorMemberId
  calendarIncludedWhen: view = today
  overdueChoresIncludedWhen: view = today
  todayViewQueries:
    - get_chore_list(view = today)
    - get_chore_list(view = overdue)
    - get_calendar_event_page_v2(view = agenda, null range)

calendarWindow:
  initialQuery: agenda with null range so the server resolves household-local today
  pageSize: 100
  maximumExaminedTodayEvents: 500
  stopWhen:
    - first projection after household-local today
    - source has no next cursor
    - maximumExaminedTodayEvents is reached
  truncatedDisclosure: required when more Today rows may exist

compositionInvariant:
  exactMatches:
    - householdId
    - householdTimezone
    - householdLocalDate
    - memberFilter
  mismatchBehavior:
    calendarSource: fail_closed
    choreSource: retain_if_valid
    mixedDateDisplay: forbidden
  duplicateCalendarOccurrenceId: invalid_payload
  outOfOrderCalendarProjection: invalid_payload
  overdueChoreSource:
    requiredView: overdue
    exactContextMatchWithTodayChores: required
    contextMismatch: fail_closed_for_overdue_section

ordering:
  sections:
    - overdueChores
    - nowAndNextEvents
    - dueTodayScheduledChores
    - remainingEvents
    - dueTodayCompletedChoresCollapsed
  calendar:
    - all-day before timed
    - household view local time ascending
    - occurrenceId ascending as stable tie-breaker
  nowAndNextSelection:
    authority: calendar sourceGeneratedAt
    include:
      - every all-day event intersecting the household-local today projection
      - every timed event where startsAt <= sourceGeneratedAt < endsAt
      - the first not-yet-started timed event in canonical source order
    duplicateOccurrence: forbidden
  remainingEvents:
    definition: canonical calendar events not selected by nowAndNextSelection
    sourceOrderPreserved: true
    droppingPastTimedEvents: forbidden
  chores:
    overdue: authoritative get_chore_list(view = overdue) order
    dueTodayScheduled: scheduled partition of get_chore_list(view = today)
    dueTodayCompleted: completed partition of get_chore_list(view = today)
  completedDisclosure:
    initiallyExpanded: false
    expansionStatePersistence: screen_lifetime_only

filtering:
  everyone:
    chores: no assignee predicate
    calendar: no participant predicate
  me:
    chores: server assignee predicate for active actor member
    calendar: participant membership predicate over already-authorized household events
  authorizationExpansion: forbidden

sourceState:
  variants: [initial, loading, ready, failed]
  refresh:
    retainLastSuccessfulContent: true
    retainGeneratedAt: true
    exposeStaleNotice: true
  initialFailure:
    retainOtherReadySource: true
    wholeScreenFailureOnlyWhenNoSourceContentIsAvailable: true
  overdue:
    independentLoadRefreshPaginationAndActionState: true
    failureScope: overdue_section
  rawProviderErrorInUi: forbidden

actions:
  choreQuickComplete:
    existingOptimisticController: retained
    duplicateTapCoalescing: retained
    serverReconciliation: retained
    calendarSourceInvalidation: not_required
    overdueSourceUsesIndependentController: true
  openCalendar:
    destination: /calendar
    eventContentInRoute: forbidden

cacheAndLifecycle:
  persistentTodayChoreCache: existing bounded encrypted first-page snapshot
  persistentTodayCalendarCache: see kinflow.today.calendar-cache.v1
  persistentCachePlatforms: [android]
  cachedSourceMode: stale_read_only
  cachedSourceBlocksFilterChange: true
  webPersistentFamilyCache: forbidden
  appResume: refreshTodayChoresOverdueChoresAndCalendarWhenViewIsToday
  filterChange: replaceAllThreeTodaySourceQueries
  concurrentCalendarLoads: coalesce exact query and latest different query wins
  lateSupersededResponse: discard
  calendarMutationReturn: routeReentryPerformsAuthoritativeReload

privacy:
  newStorage: one identifier-free fixed slot in existing encrypted read-cache namespace
  newAnalytics: none
  newLogs: none
  participantNames: renderOnlyFromAuthorizedCalendarProjection
```
