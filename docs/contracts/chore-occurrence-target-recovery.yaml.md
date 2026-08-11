# 원본 파일 문서화: `contracts/chore-occurrence-target-recovery.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-occurrence-target-recovery.yaml`
- 원본 형식: `yaml`
- 범위: WP05-08 Android authenticated adult Chore inbox/push target recovery

```yaml
version: "2026-08-09-wp05-08"
requirements: [FR-NOTIF-005, FR-CHORE-009, NFR-SEC-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-002, D-006, D-013, D-018, D-036, D-051]
scope:
  platform: Android Store MVP phone and tablet
  principal: authenticated adult with an active household
  entryPoints: [durable inbox item, authorized Android push tap, fixed app route]
route:
  template: /chores/occurrence/:occurrenceId
  occurrenceId: canonical UUID
  householdIdInRoute: forbidden
  invalidIdentifierFallback: /notifications
  primaryNavigationVisible: false
targetRead:
  rpc: get_chore_occurrence_target
  arguments: [active household UUID, occurrence UUID]
  resultCardinality: exactly one or not-found-or-forbidden
  serverAuthority: latest committed occurrence and series state
  eligibleStatuses: [scheduled, completed]
  skippedOccurrence: unavailable
  deletedScheduledSeries: unavailable
  completedHistoricalOccurrence: available
  authorization:
    - authenticated session
    - active household supplied by trusted auth lifecycle state
    - active membership in that household
    - occurrence belongs to that household
  indistinguishableFailure: missing, deleted, skipped, and forbidden all use the same safe unavailable state
projection:
  fields:
    - occurrenceId
    - seriesId
    - title
    - description
    - assigneeMemberId
    - assigneeDisplayName
    - dueLocalDate
    - dueLocalTime
    - dueAt
    - status
    - version
    - recurrenceFrequency
    - seriesVersion
    - seriesDefaultAssigneeMemberId
    - seriesDueLocalTime
    - recurrenceRule
    - canManageSeries
  exactKeys: true
client:
  initialState: loading
  success: localized occurrence details and existing paginated activity history
  unavailable: generic localized message with Notifications and Chores recovery actions
  transientFailure: localized retry action without raw provider text
  resumeBehavior: authoritative target refetch
notificationRouting:
  choreCategories: [chore_due, chore_assignment]
  pushSafeDestination: chore_occurrence
  inboxDestination: route generated from the strict subject UUID
  calendarDestination: existing /calendar/event/:occurrenceId
  failClosedDestination: /notifications
  payloadChange: none
privacy:
  routeContains: [occurrence UUID]
  routeForbidden: [household UUID, title, description, member display name, email, auth subject]
  logsAndTelemetry: none
offline:
  authoritativeTargetCache: forbidden
  mutationOutbox: none
dbApiImpact:
  migration: additive function only
  tables: none
  indexes: none
  RLS: existing forced RLS remains unchanged
  authenticatedExecuteGrant: get_chore_occurrence_target only
  edgeFunction: none
  remoteDto: additive strict occurrence projection
rollback:
  client: route chore notifications back to /notifications
  server: revoke execute on get_chore_occurrence_target in a forward migration
  dataMigrationRequired: false
deferred:
  - real-account notification tap validation
  - physical Android foreground/background/terminated delivery validation
  - iOS/APNs and Web Push deep links
  - Managed Child route allowlist and guardian policy
```
