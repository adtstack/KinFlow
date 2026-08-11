# 원본 파일 문서화: `contracts/calendar-overlap-preview.yaml`

> 이 파일은 같은 구성원의 Calendar 일정 겹침을 저장 차단 없이 미리 보여주는 WP04-07 normative 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-overlap-preview.yaml`
- 원본 형식: `yaml`
- 적용 migration: `supabase/migrations/20260808150000_calendar_overlap_hints.sql`
- 범위: local automated read-only hint. hosted 규모 query plan, 실제 계정·두 기기·실기기는 마지막 gate로 보류한다.

```yaml
version: "2026-08-08-wp04-07"
name: calendar-overlap-preview
authority:
  rpc: public.preview_calendar_event_overlaps
  candidateHelper: app_private.calendar_overlap_candidate_dates
  mutationPrecondition: false
  blocksSave: false

request:
  exactKeys:
    - p_household_id
    - p_is_all_day
    - p_local_start_date
    - p_local_start_time
    - p_duration_minutes
    - p_all_day_end_date_exclusive
    - p_timezone
    - p_overlap_policy
    - p_recurrence_rule
    - p_window_start_date
    - p_participant_member_ids
    - p_excluded_series_id
    - p_excluded_occurrence_id
    - p_limit
  forbiddenContent:
    - title
    - description
    - actor or auth-user identity
    - command, idempotency, or correlation identifier
  participants:
    minimum: 1
    maximum: 50
    unique: true
    membership: active members of the requested household only
  exclusion:
    mutuallyExclusive: [p_excluded_series_id, p_excluded_occurrence_id]
    oneTimeOrWholeSeriesEdit: p_excluded_series_id
    recurringSingleOccurrenceEdit: p_excluded_occurrence_id
  detailLimit:
    minimum: 1
    maximum: 10
    clientValue: 10

schedule:
  timed:
    required: [local date, minute-precision local time, duration, IANA timezone, overlap policy]
    durationMinutes: 1..10080
    gapPolicy: reject through the canonical server resolver
    overlapPolicy: earlier | later
  allDay:
    required: [local start date, exclusive end date]
    forbidden: [local time, duration, timezone, overlap policy]
  ranges:
    timedTimed: canonical UTC half-open [starts_at, ends_at)
    allDayAllDay: date-only half-open [local_start_date, all_day_end_date_exclusive)
    mixed: convert the all-day boundaries to instants at household-timezone midnight
    touchingEndpointsConflict: false

recurrence:
  subset: [daily, weekly, monthly]
  end: [never, count, until]
  canonicalAnchor: p_local_start_date
  window:
    oneTime: p_window_start_date must equal p_local_start_date
    recurring: inclusive p_window_start_date through p_window_start_date + 365 days
    maximumCandidateOccurrences: 366
    maximumPastAnchorScanWhenWindowIsNotEarlier: 3660 days
    futureAnchorAfterWindowStart: allowed for whole-series edit previews
  dst: resolve every candidate independently with the existing Calendar resolver

conflict:
  requires:
    - existing occurrence is scheduled and its series is not deleted
    - candidate and existing half-open ranges intersect
    - at least one active participant member is shared
  countUnit: candidate occurrence by existing occurrence pair
  participantMultiplicityDoesNotIncreaseCount: true
  order:
    - candidate local start date ascending
    - existing household-local start date ascending
    - existing household-local start time nulls first then ascending
    - existing occurrence UUID ascending

response:
  metadataExactKeys:
    - household_id
    - household_timezone
    - household_local_date
    - generated_at
    - checked_from_local_date
    - checked_through_local_date
    - candidate_occurrence_count
    - total_conflict_count
    - truncated
  detailExactKeys:
    - candidate_local_start_date
    - conflicting_series_id
    - conflicting_occurrence_id
    - conflicting_title
    - conflicting_is_all_day
    - conflicting_view_local_start_date
    - conflicting_view_local_start_time
    - conflicting_duration_minutes
    - conflicting_all_day_end_date_exclusive
    - conflicting_participant_member_ids
    - conflicting_participant_display_names
  zeroResult: exactly one metadata-only row with all detail fields null
  maximumDetails: 10
  totalCountRetainedWhenTruncated: true
  forbiddenContent:
    - description
    - auth-user or actor identity
    - command, audit, provider, or correlation material

authorization:
  execute: authenticated only
  caller: server-derived auth.uid
  household: active membership required
  crossHouseholdOrRemovedMember: invalid or not-found-forbidden without content disclosure
  helperExecute: revoked from public, anon, authenticated, and service_role

client:
  refreshInputs: [schedule, recurrence, participants, edit exclusion]
  ignoredInputs: [title, description]
  debounceMilliseconds: 350
  lateResponse: discard by request generation
  states: [checking, no-conflict, conflict, unavailable]
  saveEnabledInEveryState: true
  rawProviderErrorVisible: false

errors:
  unauthenticated: KFE01
  invalidInputOrRecurrence: KFE02
  householdNotFoundOrForbidden: KFE03
  nonexistentLocalTime: KFE06

rollback:
  client: remove preview invocation and hint surface; Calendar mutations remain unchanged
  database: revoke authenticated execute, then drop the public RPC and private helper
  persistedUserDataChanged: false
```
