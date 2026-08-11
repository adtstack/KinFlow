# 원본 파일 문서화: `contracts/household-weekly-report.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/household-weekly-report.yaml`
- 원본 형식: `yaml`
- 범위: WP03-18 authenticated adult household weekly report

```yaml
version: "2026-08-09-wp03-18"
requirements: [FR-CHORE-011, FR-TODAY-005, NFR-SEC-01, NFR-PRIV-01, NFR-PERF-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-002, D-006, D-013, D-017, D-019, D-036, D-043, D-047, D-049, D-057]
scope:
  phase: 03
  releaseClass: P1 local automated slice
  principal: authenticated active adult household member
  operation: read-only aggregate
  entryPoints: [Today summary card, weekly report detail sheet]
  historyWindow:
    latestClosedIsoWeekOffset: 0
    oldestAllowedOffset: 11
    weekStart: ISO Monday
    weekEnd: ISO Sunday
authority:
  clock: PostgreSQL statement timestamp
  timezone: current household IANA timezone
  weekSelection: server derives the latest fully closed week and subtracts the validated offset
  membership: active membership is revalidated on every RPC call
rpc:
  name: public.get_household_weekly_report
  arguments:
    p_household_id: uuid
    p_week_offset: integer 0..11
  errors:
    unauthenticated: KFC01
    invalidInput: KFC02
    forbiddenOrMissing: KFC03
  exactFields:
    - household_id
    - household_timezone
    - generated_at
    - week_offset
    - week_start
    - week_end
    - due_count
    - completed_count
    - completed_by_week_end_count
    - completed_after_week_end_count
    - open_count
    - skipped_count
    - viewer_completed_count
    - member_breakdown
    - other_member_completed_count
    - member_breakdown_truncated
population:
  include:
    - occurrence due_local_date falls inside the selected closed ISO week
    - scheduled and completed occurrences contribute to due_count
    - skipped occurrences contribute only to skipped_count
  exclude:
    - cancelled occurrences
  completionClassification:
    completedByWeekEnd: completed_at is before household-local Monday after week_end
    completedAfterWeekEnd: completed_at is at or after that instant
    invariant: completed_count equals completedByWeekEnd plus completedAfterWeekEnd
    invariant2: due_count equals completed_count plus open_count
memberBreakdown:
  maximumRows: 20
  include: currently active household members with at least one selected-week completion
  order: case-folded display name, then member UUID
  exactItemFields: [memberId, displayName, completedCount, completedByWeekEndCount, isViewer]
  viewerCount: server-derived from the authenticated caller membership
  otherBucket:
    includes: [removed members, deleted/tombstoned identities, active rows beyond maximumRows]
    exposes: count only
    forbidden: [member ID, auth user ID, display name]
  truncated: true only when an active contributing row is omitted by maximumRows
privacy:
  forbiddenResponseContent:
    - chore title or description
    - occurrence, series, revision or command ID
    - auth user ID, email or provider identity
    - event timestamp or raw audit row
  persistence: none
  clientPersistentCache: none
  analyticsAndLogging: none added
  localState: process-memory controller state scoped to one household
presentation:
  summaryCard:
    - never hides or blocks Today content
    - absent while initial loading or after a source-local failure
    - shows selected week, completed-by-week-end and due totals when ready
    - opens a detailed scrollable sheet
  detailSheet:
    - older and newer controls stay within offsets 0..11
    - loading, empty, ready and stable localized retry states
    - active-member rows are descriptive, not ranked
    - other member count never reveals a former identity
  refresh:
    - initial Today load and explicit Today refresh request offset 0
    - successful authoritative completion or reopen refreshes offset 0
    - detail navigation is latest-request-wins and source isolated
  accessibility:
    - semantic heading and live-region load/error/result status
    - Material minimum touch targets
    - compact 320x568 at 200 percent text remains scrollable
cacheAndOffline:
  persistent: forbidden
  cachedTodayFallback: do not derive or display a new weekly report from cached chore rows
  networkFailure: retain no cross-process data and keep Today usable
dbImpact:
  migration: additive RPC and bounded supporting index
  tableData: none
  rls: existing household relations unchanged; RPC performs active membership authorization
  edgeFunction: none
rollback:
  client: hide the summary card and detail entry while keeping core Chore and Today paths
  server: revoke authenticated execute, then replace or remove through a forward migration
  dataMigrationRequired: false
deferred:
  - leaderboard, badges, streaks, reminders, sharing and analytics
  - current partial week and custom week boundaries
  - hosted production-size query plan and latency
  - real-account, two-device, timezone-change and physical-device validation
```
