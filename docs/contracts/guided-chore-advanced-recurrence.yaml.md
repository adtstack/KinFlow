# 원본 파일 문서화: contracts/guided-chore-advanced-recurrence.yaml

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: contracts/guided-chore-advanced-recurrence.yaml
- 원본 형식: yaml
- 범위: WP03-17 first-household guided setup advanced recurrence and durable frozen-batch fidelity

```yaml
version: "2026-08-09-wp03-17"
requirements: [FR-CHORE-005, FR-CHORE-010, NFR-REL-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01]
decisions: [D-019, D-048, D-051]
entry:
  route: /onboarding/chores
  prerequisite: existing authoritative uncached Today context
  exactSelectionCount: 3
recurrence:
  serverSubset: [daily, weekly, monthly]
  interval: {minimum: 1, maximum: 30}
  end:
    modes: [never, count, until]
    count: {minimum: 1, maximum: 1000}
    until: not before frozen startLocalDate
  daily:
    weekdays: forbidden
    monthDay: forbidden
  weekly:
    weekdays: unique canonical ISO order
    minimumCount: 1
    maximumCount: 7
    frozenStartWeekdayRequired: true
  monthly:
    monthDay: frozen startLocalDate day
    editable: false
    missingDatePolicy: skip month and never clamp
draft:
  templateSuggestion: interval 1 and never ending daily or weekly
  userEditable: [frequency, interval, end, weekly weekdays]
  frequencyRoundTrip: preserve in-progress weekday selection
  monthlyAnchor: reset to frozen startLocalDate day
  invalidRule: block before command ID, secure write, repository, and network
  fingerprint: exact full recurrence rule
submission:
  existingRepository: ChoreRepository.createRecurringChore
  existingRequest: CreateRecurringChoreRequest
  sequentialExactThree: true
  duplicateSubmit: coalesce
  retry:
    sameFullRule: reuse frozen command ID
    changedFullRuleBeforeFreeze: new command IDs
    afterFreeze: controls locked
secureResume:
  contractVersion: 2
  key: kinflow.guided_chore_setup.resume.v2
  legacyV1:
    resume: forbidden
    cleanupOnReadOrClear: required
  entryExactKeys: [templateKey, title, recurrenceRule, commandId]
  recurrenceRule: exact existing ChoreRecurrenceRule JSON
  submittedFrozenBatchOnly: true
  unsubmittedDraftPersistence: forbidden
  maximumUtf8Bytes: 8192
  scope: exact environment, household, and adult member
  invalidCorruptOrMismatched: purge and return absent
ui:
  reuse: ChoreRecurrenceEditor
  localization: [EN, KO, EN-XA]
  progressAndResult: existing live regions
  minimumActionTargetDp: 48
  compactTextScale: 200 percent scrollable
privacy:
  newTelemetry: none
  forbiddenLogs: [title, recurrence payload, template key, command ID, household ID, member ID]
  rawStorageOrProviderErrorVisible: false
dbApiImpact:
  migration: none
  RLS: none
  RPC: none
  Edge: none
  remoteDTO: none
  runtimeDependency: none
rollback:
  hideAdvancedControls: true
  purgeV2FrozenBatchBeforeBasicFallback: required
  databaseOrApiRollback: none
deferred:
  - multiple month dates, last-day, ordinal-weekday, yearly, and business-day recurrence
  - individual occurrence recurrence changes
  - remote Supabase, real-account, multi-device, and physical-device validation
```
