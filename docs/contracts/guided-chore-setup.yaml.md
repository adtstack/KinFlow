# 원본 파일 문서화: `contracts/guided-chore-setup.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/guided-chore-setup.yaml`
- 원본 형식: `yaml`
- 범위: WP03-10 first-household guided creation of three recurring chores

```yaml
version: "2026-08-09-wp03-17"
requirements: [FR-HH-001, FR-CHORE-002, FR-CHORE-005, FR-CHORE-010, NFR-REL-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01, D-048, D-051]
entry:
  route: /onboarding/chores
  source: first household creation success only
  prerequisite: authenticated active household snapshot replaced successfully
  unauthenticated: sign-in
  noHousehold: household onboarding
catalog:
  authority: chore-templates.yaml version 2026-08-09-wp03-19
  exactSelectionCount: 3
  uniqueTemplateKeys: true
  requestOrder: immutable catalog order
  initialSelection: none
  maxSelectionBehavior: disable remaining unselected entries
draft:
  title:
    source: localized template title
    editable: true
    trim: true
    minLength: 1
    maxLength: 160
    controlCharacters: reject
  recurrence:
    source: template suggested cadence
    editableValues: [daily, weekly, monthly]
    advancedContract: guided-chore-advanced-recurrence.yaml version 2026-08-09-wp03-17
  assignee: current active adult member
  startLocalDate: authoritative loadToday.localDate
  dueLocalTime: null
  description: null
authority:
  load:
    repository: ChoreRepository.loadToday
    requireExactHouseholdId: true
    cacheMetadataAllowed: false
    cacheFailure: offlineReadOnly
  create:
    repository: ChoreRepository.createRecurringChore
    existingRequestOnly: CreateRecurringChoreRequest
    serverChecksRemain: [authenticated active membership, household scope, active assignee, entitlement, recurrence]
submission:
  atomicAcrossThree: false
  ordering: catalog order sequential
  duplicateSubmit: coalesce
  commandIds:
    count: 3
    unique: true
    generatedOncePerFrozenBatch: true
  retry:
    reuseSameCommandIdForFailedEntry: true
    resendSuccessfulEntries: false
    freezeDraftAfterFirstAttempt: true
    responseLossRecovery: existing server idempotent replay
  progress:
    completedCountRange: [0, 3]
    partialFailureVisible: true
    partialExitPreservesCreatedChores: true
  success:
    invalidateToday: true
    navigate: /today
persistence:
  databaseMigration: none
  apiShapeChange: none
  submittedFrozenBatch: guided-chore-setup-resume.yaml version 2026-08-09-wp03-17
  unsubmittedDraftStorage: none
  analyticsEventAdded: false
  templateStableKeySent: false
  catalogVersionSent: false
privacy:
  storedUserContent: confirmed editable chore title
  forbiddenTelemetry: [template key, catalog version, selection, title, household id, member id]
client:
  progressLiveRegion: true
  skipRequiresConfirmation: true
  partialExitRequiresConfirmation: true
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
rollback:
  restoreFirstHouseholdDestination: /today
  removeGuidedClientSurface: true
  databaseOrApiRollback: none
  deleteCreatedChores: false
deferred:
  - persisted activation completion marker or analytics
  - server-managed or household-specific templates
  - invitation combined into the guided screen
  - real-account, remote Supabase, multi-device, and physical-device validation
```
