# 원본 파일 문서화: `contracts/today-calendar-cache.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/today-calendar-cache.yaml`
- 원본 형식: `yaml`
- 관련 범위: WP04-09, FR-TODAY-001, FR-TODAY-004, D-017, D-043, D-045, D-049

```yaml
version: "2026-08-08"
name: kinflow.today.calendar-cache.v1

platform:
  androidStoreMvp: enabled
  web: disabled
  ios: deferred

storage:
  implementation: existing environment-scoped encrypted SecureReadCache
  fixedSlot: today_calendar_v1
  keyContainsIdentifiersOrContent: false
  envelopeContract: 2026-08-08-wp05-06-v1
  envelopeExactKeys:
    - contractVersion
    - userId
    - sessionId
    - householdId
    - validatedAt
    - expiresAt
    - payload
  maximumAge: 24h bounded by current authenticated session expiry
  maximumEncodedBytes: 196608
  maximumOccurrences: 500
  plaintextFallback: forbidden

payload:
  exactKeys:
    - payloadVersion
    - householdId
    - householdTimezone
    - householdLocalDate
    - generatedAt
    - participantMemberId
    - truncated
    - projections
  payloadVersion: 1
  projections:
    canonicalOrderRequired: true
    duplicateOccurrenceId: forbidden
    exactProjectionKeys: [viewLocalDate, viewLocalTime, event]
    eventShape: strict existing OneTimeCalendarEvent fields
    maximumParticipantsPerEvent: 50
  domainRevalidation:
    - value object parsers
    - OneTimeCalendarEvent.tryCreate
    - CalendarEventProjection.tryCreate
    - TodayCalendarSnapshot.tryCreate

write:
  authority: completed validated TodayCalendarSnapshot
  validatedAt: snapshot server generatedAt
  partialPageWrite: forbidden
  clientClockForSourceDateOrNowNext: forbidden
  storageFailureEffect: online authoritative content remains usable

read:
  fallbackFailure: temporarilyUnavailable only
  exactMatches:
    - authenticated user ID
    - authenticated session ID
    - requested household ID
    - participant member filter
  dateAuthority: cached server householdLocalDate
  clientClockDateRollover: forbidden
  mismatchedValidMemberFilter: do_not_render_and_preserve_slot
  corruptOrExpired: delete_slot_and_fail_closed
  unauthenticatedOrForbidden: clear_all_read_cache
  nonTransientFailureFallback: forbidden

ui:
  mode: stale_read_only
  requiredDisclosure:
    - cached-at time
    - reconnect requirement
    - online-only modification explanation
  retry: authoritative same-query load
  cachedSourceBlocks:
    - Everyone-Me filter change
    - Chore view filter change while composing Today
  openOccurrenceRouteCarriesContent: false
  rawCacheOrProviderError: forbidden

invalidation:
  calendarMutationSuccess:
    - create one-time
    - create recurring
    - update one-time
    - delete one-time
    - update recurring series
    - cancel recurring series
    - update recurring occurrence
    - cancel recurring occurrence
  authorizationBoundaryFailure: clear_all_read_cache
  logoutAccountSessionTermination: existing sensitive-local-state purge
  noActiveHousehold: clear_all_read_cache
  householdChange: delete mismatched household slots before replacement

privacy:
  newRuntimeDependency: none
  newNativePermission: none
  newAnalytics: none
  newLogs: none
  offlineMutationOutbox: disabled
```
