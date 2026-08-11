# 원본 파일 문서화: `contracts/household-activation-progress.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/household-activation-progress.yaml`
- 원본 형식: `yaml`
- 범위: WP03-11 server-derived adult household activation progress on Today

```yaml
version: "2026-08-09-wp03-11"
requirements: [PRD-G01, FR-HH-003, FR-HH-005, FR-CHORE-001, FR-CHORE-004, FR-CHORE-009, NFR-SEC-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01, D-051]
definition:
  purpose: guide a household through the accepted two-adult activation slice
  milestones:
    - two distinct adult accounts have joined the household
    - three distinct chore series have been created
    - two distinct adult accounts have each completed at least one occurrence
    - Today evaluates the progress after the household creation local date
  semantics: historical milestone progress, not current plan usage or active-member readiness
authority:
  rpc: public.get_household_activation_progress
  parameters:
    p_household_id: uuid
  caller:
    authentication: required
    activeHouseholdMembership: required
    deletedHousehold: forbidden
  clock:
    source: database clock_timestamp captured once per invocation
    localDateZone: household IANA timezone
    clientClockAuthority: none
  sourceRows:
    adultParticipation: distinct household_members.auth_user_id including later-removed membership rows
    choreCreation: distinct app_private.chore_domain_events.aggregate_id where event_name is chore.series_created
    adultCompletion: distinct actor household_members.auth_user_id referenced by public.chore_completion_events where event_type is completed
    returnVisit: current household-local date is later than household created_at household-local date
  deletionBehavior:
    softDeletedChoreStillCounts: true
    reopenedCompletionStillCounts: true
    laterRemovedAdultStillCounts: true
projection:
  cardinality: exactly one row on authorized success
  fields:
    household_id: {type: uuid, exactRequestMatch: true}
    adult_participant_progress: {type: smallint, range: [0, 2], cappedAt: 2}
    chore_creation_progress: {type: smallint, range: [0, 3], cappedAt: 3}
    distinct_adult_completer_progress: {type: smallint, range: [0, 2], cappedAt: 2}
    return_after_first_day_reached: {type: boolean}
  forbiddenFields: [household name, member id, user id, display name, email, chore id, chore title, occurrence id, completion timestamp]
  activationComplete: all three capped counts reach their goals and return_after_first_day_reached is true
privacy:
  newTable: none
  newEvent: none
  persistedVisitLog: none
  analyticsEventAdded: false
  contentFreeAggregateOnly: true
  note: invoking this read from Today proves only the current after-date-boundary evaluation; it does not reconstruct a historical route visit
client:
  surface: Today view only
  loadPolicy:
    parallelWithToday: true
    persistentCache: none
    failureBlocksToday: false
    retry: explicit
  steps:
    adultParticipant:
      goal: 2
      incompleteAction: open household invite creation
    choreCreation:
      goal: 3
      incompleteAction: open normal chore creation
    adultCompletion:
      goal: 2
      incompleteAction: explain that each adult completes one item
    returnVisit:
      goal: true
      incompleteAction: explain return on a later household-local day
  mutationRefresh:
    completionSuccess: reload projection
    navigationReturn: Today reloads projection
  offline:
    projectionAvailableFromCache: false
    mutationActionsDisabledWhenTodayIsCached: true
  visibility:
    completedStateRetained: true
    dismissOrPersistedCollapse: none
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
errors:
  KFC01: unauthenticated
  KFC02: invalid input
  KFC03: household not found or forbidden
  malformedProjection: fail closed as invalid payload
rollback:
  dropRpc: public.get_household_activation_progress(uuid)
  removeClientSurface: true
  dataCleanup: none
deferred:
  - persisted activation analytics or funnel export
  - an exact historical day-two Today visit ledger
  - current-member readiness separate from historical milestone progress
  - process-death guided-setup resume
  - real-account, remote Supabase, multi-device, and physical-device validation
```
