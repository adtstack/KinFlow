# 원본 파일 문서화: `contracts/timezone-date-time-preview.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/timezone-date-time-preview.yaml`
- 원본 형식: `yaml`
- 범위: WP07-06D profile regional date/time draft preview

```yaml
version: "2026-08-09-wp07-06d"
requirements: [FR-SET-002, FR-PLAT-001, NFR-I18N-01]
decisions: [D-036]
baseCatalogContract: docs/contracts/timezone-catalog.yaml.md
goal:
  showBeforeSave: true
  compareAtSameInstant:
    - personal profile timezone
    - active household timezone
draftInputs:
  language: en | ko
  personalTimezone: exact selected IANA identifier
  householdTimezone: exact selected or authoritative IANA identifier
  persistenceOnPreviewChange: false
snapshot:
  sourceInstant: client UTC clock at explicit catalog load or retry
  oneInstantForEveryRow: true
  refresh:
    explicit: true
    reloadsCatalogOffsets: true
    capturesNewInstant: true
  backgroundTimer: false
formatting:
  date: draft-language Material localization full date
  time: draft-language Material localization time
  respectsSystem24HourPreference: true
  timezoneMetadata:
    - exact IANA identifier
    - current UTC offset
    - current daylight-saving or standard-time label
catalog:
  source: bundled IANA 2025c
  networkRequired: false
  exactIdentifierLookup: true
  metadataAuthority: display-only snapshot
failure:
  catalogLoad:
    preserveEveryDraft: true
    allowRetry: true
    noDeviceTimezoneFallback: true
  missingIdentifier:
    showExactIdentifier: true
    markPreviewUnavailable: true
    noSilentSubstitution: true
saveBoundary:
  existingUpdateCommand: update_profile_preferences
  commandPayloadShape: unchanged
  validationAndAuthorization: unchanged
  householdImpactConfirmation: unchanged
privacy:
  networkRequest: false
  telemetry: false
  historyPersisted: false
  identifiersBeyondTimezone: none
accessibility:
  localized: [EN, KO, EN-XA]
  semanticRowSummary: true
  minimumRefreshTargetDp: 48
  compactTextScale: 200%
  scrollableParent: true
verification:
  - same UTC instant renders different personal and household wall times
  - draft language changes date and time formatting before save
  - timezone selection updates preview without repository mutation
  - load failure retry preserves draft and recovers
  - missing bundled identifier fails closed without device-time fallback
rollback:
  previewPanelCanBeRemoved: true
  profileAndHouseholdStoredValuesRemainCompatible: true
deferred:
  - hosted PostgreSQL and bundle catalog parity
  - actual device locale and 12/24-hour setting
  - real-account cross-device and process-restart validation
  - TalkBack VoiceOver and physical keyboard validation
```
