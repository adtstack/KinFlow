# 원본 파일 문서화: `contracts/timezone-picker-adoption.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/timezone-picker-adoption.yaml`
- 원본 형식: `yaml`
- 범위: WP07-06C Store MVP timezone editor adoption

```yaml
version: "2026-08-09-wp07-06c"
requirements: [FR-HH-002, FR-NOTIF-004, FR-SET-002]
baseCatalogContract: docs/contracts/timezone-catalog.yaml.md
goal:
  editableTimezoneFreeTextFields: 0
  sharedPickerFields:
    - first household default timezone
    - personal profile timezone
    - existing household default timezone
    - notification recipient timezone
component:
  field:
    readOnly: true
    opensPickerOnActivation: true
    showsExactSelectedIdentifier: true
    preservesFormValidation: true
    supportsExternalErrorText: true
    noKeyboardFreeTextFallback: true
  picker:
    implementation: shared app presentation widget
    catalog: bundled IANA 2025c
    behavior: docs/contracts/timezone-catalog.yaml.md
firstHousehold:
  initialSelection: Asia/Seoul
  selectionMutation: form draft only
  cancel: preserve prior draft
  submit:
    existingCommand: create_first_household
    serverTimezoneValidation: app_private.is_valid_iana_timezone
    idempotency: unchanged
    transaction: unchanged
notificationPreference:
  initialSelection: authoritative preference timezone
  selectionMutation: dialog draft only
  cancel: discard every dialog draft change
  save:
    existingCommand: update_notification_preference
    expectedVersion: unchanged
    serverTimezoneValidation: app_private.is_valid_iana_timezone
    quietHoursPairValidation: unchanged
    categoryAndHouseholdScope: unchanged
profilePreferences:
  behavior: unchanged from WP07-06B
failure:
  catalogLoad:
    preserveCurrentDraft: true
    allowRetry: true
    allowFreeTextFallback: false
  commandFailure:
    existingBoundedFailureAndRetry: unchanged
privacy:
  searchHistoryPersisted: false
  searchTelemetry: false
  remoteCatalogRequest: false
  newCollectedData: none
accessibility:
  localized: [EN, KO, EN-XA]
  selectedStateExposed: true
  minimumTargetDp: 48
  compactTextScale: 200%
  fullPickerScrollSurface: true
verification:
  widget:
    - first household search select submit
    - notification search select save
    - notification cancel preserves authoritative preference
    - profile personal and household selection regression
    - compact 200 percent pseudo layout
  static:
    - no remaining editable timezone TextField in Store MVP screens
rollback:
  sharedFieldCanRevertToCurrentValueDisplay: true
  serverCommandsAndStoredValuesRemainCompatible: true
deferred:
  - hosted PostgreSQL and bundled catalog parity
  - real-account onboarding and notification save
  - cross-device authoritative refresh
  - physical keyboard screen-reader DST and travel validation
```
