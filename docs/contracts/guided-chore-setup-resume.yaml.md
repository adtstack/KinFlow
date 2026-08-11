# 원본 파일 문서화: `contracts/guided-chore-setup-resume.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/guided-chore-setup-resume.yaml`
- 원본 형식: `yaml`
- 범위: WP03-12 process-death-safe resume of a submitted guided chore setup batch

```yaml
version: "2026-08-09-wp03-17"
requirements: [FR-CHORE-002, FR-CHORE-005, FR-CHORE-010, NFR-REL-01, NFR-PRIV-01, D-048, D-051]
scope:
  persisted: submitted and frozen exact-three guided setup batch
  notPersisted: unsubmitted selection or edit state
  databaseMigration: none
  apiShapeChange: none
storage:
  medium: platform secure storage
  namespace: dedicated per app environment and contract version
  androidBackup: false
  fixedKey: kinflow.guided_chore_setup.resume.v2
  maximumUtf8Bytes: 8192
  schema:
    exactKeys: [contractVersion, householdId, assigneeMemberId, startLocalDate, householdTimezone, entries, completedCount]
    contractVersion: 2
    householdId: strict HouseholdId
    assigneeMemberId: strict HouseholdMemberId
    startLocalDate: strict ChoreLocalDate
    householdTimezone: non-empty, maximum 255 characters
    entries:
      exactCount: 3
      exactKeys: [templateKey, title, recurrenceRule, commandId]
      templateKey: exact local ChoreTemplatePreset stable key
      title: strict RecurringChoreDraft title
      recurrenceRule: exact canonical ChoreRecurrenceRule JSON from guided-chore-advanced-recurrence.yaml
      commandId: strict ChoreCommandId
      uniqueTemplateKeys: true
      uniqueCommandIds: true
      order: immutable catalog order
    completedCount: integer 0 through 3
writeProtocol:
  beforeFirstMutation:
    generateThreeUniqueCommandIds: true
    freezeAndPersistWholeBatch: required
    storageFailure: sendNoServerRequest
  afterEachSuccessfulMutation:
    persistCompletedCountBeforeNextRequest: required
    storageFailure: stopBeforeNextRequest
  afterThirdSuccess:
    persistCompletedCountThree: required
    clearBeforeReportingSuccess: required
    clearFailure: retainSafeRetryState
resumeDiscovery:
  todayEntryPreflight:
    expectedScope: exact active household and adult member
    validPendingRecord: redirect /onboarding/chores before Today load
    absentInvalidCorruptOrMismatchedRecord: continue Today
    storageUnavailable: continue Today without mutation
  guidedRoute:
    requireAuthoritativeLoadToday: true
    cacheMetadataAllowed: false
    requireExactActiveHouseholdAndMember: true
    originalStartLocalDateAndPayload: immutable for idempotent replay
    action: automatically continue from completedCount with stored command IDs
retry:
  ordering: stored catalog order sequential
  resendCompletedEntries: false
  ambiguousCheckpointRecovery: replay same payload and command ID
  duplicateSubmit: coalesce
  draftControls: frozen
discard:
  entryPoints: [skip confirmation, partial-exit confirmation]
  clearBeforeNavigation: required
  clearFailure: remain on guided route with safe localized failure
  alreadyCreatedChores: preserve
validation:
  decode: exact JSON keys and types only
  domainRebuild: required
  unexpectedVersion: reject and clear
  oversizedPayload: reject and clear
  invalidCorruptOrScopeMismatch: clear and return no pending batch
  rawStorageOrProviderErrorVisible: false
  legacyV1: delete on read or clear and never replay
privacy:
  encryptedAtRest: true
  purgeOnLogoutAccountSwitchAndAccountDeletion: true
  forbiddenLogsAndTelemetry: [title, template key, command id, household id, member id, stored payload]
  serverAuthorityUnchanged: [authenticated active membership, household scope, active assignee, entitlement, recurrence]
rollback:
  removeTodayPreflightAndResumeStore: true
  restoreInMemoryOnlyGuidedBatch: true
  databaseOrApiRollback: none
  deleteCreatedChores: false
deferred:
  - persisted activation completion marker or analytics
  - server-managed or household-specific templates
  - invitation combined into the guided screen
  - real-account, remote Supabase, multi-device, and physical-device validation
```
